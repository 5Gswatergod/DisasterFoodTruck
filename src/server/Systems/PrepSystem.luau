--!strict
-- PrepSystem.lua
-- 管理前置準備（洗/切/拿取等）階段的玩家狀態與清理
-- 只在伺服器端運作

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

export type PrepStep = "Pickup" | "Cut" | "Cook" | "Plate" | "Deliver"

export type PrepRecord = {
	player: Player,
	currentStep: PrepStep?,
	itemId: string?,         -- 目前在處理的物件/食材ID（你可用GUID或ItemName）
	station: Instance?,      -- 正在互動的工作站（BasePart或Model.PrimaryPart）
	startTick: number?,      -- 記錄開始時間，方便做超時/統計
	qteActive: boolean?,     -- 若切菜/烹飪需要QTE
	meta: {[string]: any}?,  -- 彈性欄位（例如難度、配方驗證中間值）
}

local PrepSystem = {}
PrepSystem.__index = PrepSystem

-- 玩家 -> PrepRecord
local stateByPlayer: {[Player]: PrepRecord} = {}

-- 可選：超時秒數（例如切菜90秒內未完成就自動中止）
local DEFAULT_TIMEOUT = 90

-- ===== 公用查詢 =====
function PrepSystem.GetState(player: Player): PrepRecord?
	return stateByPlayer[player]
end

-- 確保初始狀態（玩家進場時呼叫）
local function ensureState(player: Player)
	if not stateByPlayer[player] then
		stateByPlayer[player] = {
			player = player,
			currentStep = nil,
			itemId = nil,
			station = nil,
			startTick = nil,
			qteActive = false,
			meta = {},
		}
	end
	return stateByPlayer[player] :: PrepRecord
end

-- ===== 介面：開始一個Prep步驟 =====
-- 由 StationServer / FlowDirector 在工作站觸發時呼叫
function PrepSystem.StartStep(player: Player, step: PrepStep, args: {[string]: any}?): boolean
	local st = ensureState(player)

	-- 流程保護：不允許同時開始兩個步驟
	if st.currentStep ~= nil then
		warn(("[PrepSystem] Player %s already in step %s"):format(player.Name, st.currentStep))
		return false
	end

	-- 驗證工作站（可選：必須帶tag且與step匹配）
	local station = if args and args.station then args.station :: Instance else nil
	if station and not station:IsDescendantOf(workspace) then
		warn("[PrepSystem] Invalid station")
		return false
	end
	-- 例如：Station_Cut 只能處理 step="Cut"
	if station then
		local okTag = "Station_" .. step
		if not CollectionService:HasTag(station, okTag) then
			warn(("[PrepSystem] Station missing tag %s"):format(okTag))
			return false
		end
	end

	-- 設定狀態
	st.currentStep = step
	st.itemId = if args and args.itemId then tostring(args.itemId) else nil
	st.station = station
	st.startTick = os.clock()
	st.qteActive = args and args.qteActive == true or false
	st.meta = args and args.meta or {}

	-- TODO：可在此通知 FlowHint 只顯示下一步可互動站點
	-- game.ReplicatedStorage.Remotes.FlowHint:FireClient(player, { allow = { "Station_"..step } })

	return true
end

-- ===== 介面：完成步驟 =====
-- 成功時回傳 true，並清空/或保留部分狀態（視設計）
function PrepSystem.CompleteStep(player: Player, result: {[string]: any}?): boolean
	local st = stateByPlayer[player]
	if not st or not st.currentStep then
		return false
	end

	-- 超時檢查（可選）
	if st.startTick and (os.clock() - st.startTick) > DEFAULT_TIMEOUT then
		warn(("[PrepSystem] Player %s step %s timed out"):format(player.Name, st.currentStep :: string))
		PrepSystem.AbortStep(player, "timeout")
		return false
	end

	-- 例：若是Cut完成，可能要給切好的食材、或標示進入下一步
	-- 這裡不直接做給物流程，交給 StationServer / CarrySystem 實作
	-- 但可把需要的訊息透過 result/meta 回傳上層
	if result then
		-- 你可以在這裡寫入統計或觸發下一個系統
		-- e.g., result.grantItem = "SlicedOnion"
	end

	-- 清理由本步占用但需要保留的資訊（依你流程調整）
	local keep: {[string]: any} = {
		itemId = st.itemId,  -- 例如切完後仍是同一個itemId繼續烹飪
	}
	PrepSystem._clearStep(player)
	-- 保留 itemId 以供下一步使用
	local newSt = ensureState(player)
	newSt.itemId = keep.itemId

	return true
end

-- ===== 介面：中止步驟 =====
function PrepSystem.AbortStep(player: Player, reason: string?): ()
	local st = stateByPlayer[player]
	if not st then return end
	-- 依需求：若中止要丟棄物品、扣錢、播放音效等，通知其它系統
	-- game.ReplicatedStorage.Remotes.ShakeCam:FireClient(player)

	PrepSystem._clearStep(player)
end

-- 實際清空步驟佔用狀態（保留玩家記錄容器）
function PrepSystem._clearStep(player: Player)
	local st = stateByPlayer[player]
	if not st then return end
	st.currentStep = nil
	st.station = nil
	st.startTick = nil
	st.qteActive = false
	st.meta = {}
	-- 注意：是否清掉 itemId 由 CompleteStep 決策；這裡不動它
end

-- ===== 介面：玩家重生時重置（可選） =====
function PrepSystem.ResetOnRespawn(player: Player): ()
	local st = stateByPlayer[player]
	if not st then return end
	-- 依你想要的嚴格程度，重生是否應該中止當前步驟
	PrepSystem._clearStep(player)
	-- 通常重生時會清掉 itemId，避免卡死
	st.itemId = nil
end

-- ===== 玩家進出場事件 =====
local function onPlayerAdded(player: Player)
	ensureState(player)
	-- 監看角色重生來做重置（可選）
	player.CharacterAdded:Connect(function()
		PrepSystem.ResetOnRespawn(player)
	end)
end

local function onPlayerRemoving(player: Player)
	-- 重要：乾淨清掉所有引用，避免記憶體/狀態殘留
	stateByPlayer[player] = nil
end

-- ===== 初始化 =====
function PrepSystem.Init(): ()
	-- 防重複初始化
	if RunService:IsClient() then
		error("[PrepSystem] Do not require on client")
	end
	-- 綁事件
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- 先建立已在場玩家狀態（Studio play solo 時常用）
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayerAdded(p)
	end
end

return PrepSystem
