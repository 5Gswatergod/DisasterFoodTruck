-- StarterPlayer/StarterPlayerScripts/ProximityStations.client.luau
-- 以原生 ProximityPrompt 的 Hold 模式實作交互：長按完成指定秒數後才觸發

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local R = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local FlowHint   = R.FlowHint
local MatchState = R.MatchState
local Interact   = R.Interact
local StationRF  = R.StationRF
local StationNet = R.StationNet
local SubmitOrder= R.SubmitOrder

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local TAGS = {"Station_Pickup","Station_Cut","Station_Cook","Station_Plate","Station_Deliver"}

-- 與伺服端 StationManager.CFG 對齊的長按秒數
local HOLD = {
	Station_Pickup  = 0.3,
	Station_Cut     = 2.2,
	Station_Cook    = 2.6,
	Station_Plate   = 1.2,
	Station_Deliver = 0.8,
}

-- 允許互動的 tag：由 FlowHint 控制
local allowed = {}

local function resolvePart(inst: Instance)
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function actionTextFor(inst: Instance, tag: string)
	if tag == "Station_Pickup" then
		local item = (inst:GetAttribute("ItemId") or (inst:IsA("BasePart") and inst:GetAttribute("ItemId")) or inst.Name)
		return ("Pick up %s"):format(item)
	elseif tag == "Station_Cut" then return "Cut"
	elseif tag == "Station_Cook" then return "Cook"
	elseif tag == "Station_Plate" then return "Plate"
	elseif tag == "Station_Deliver" then return "Deliver"
	else return "Use" end
end

local function ensurePrompt(holderInst: Instance, tag: string)
	local part = resolvePart(holderInst)
	if not part then
		warn(('[Prompt] ❌ %s 沒有可用 BasePart：%s'):format(tag, holderInst:GetFullName()))
		return nil
	end
	local prompt = part:FindFirstChild("_StationPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "_StationPrompt"
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 12
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = HOLD[tag] or 0 -- ✅ 長按時間
		prompt.UIOffset = Vector2.new(0, -8)
		prompt.ObjectText = "" -- 只顯示動作字
		prompt.Parent = part
		print(('[Prompt] ✅ 掛上 %s → %s'):format(tag, part:GetFullName()))
	else
		prompt.HoldDuration = HOLD[tag] or 0 -- 重新掛上時也更新
	end
	prompt.ActionText = actionTextFor(holderInst, tag)
	return prompt
end

-- FlowHint：支援純陣列與 {allow/allowed/tags}
local function refreshPrompts()
	for _, tag in ipairs(TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			local part = resolvePart(inst)
			if part then
				local pr = part:FindFirstChild("_StationPrompt")
				if pr then pr.Enabled = (allowed[tag] == true) end
			end
		end
	end
end

FlowHint.OnClientEvent:Connect(function(payload)
	local list
	if typeof(payload) == "table" then
		if #payload > 0 then
			list = payload
		else
			list = payload.allow or payload.allowed or payload.tags
		end
	end

	local newAllowed = { Station_Pickup = true } -- 永遠開放拿取
	if type(list) == "table" then
		for _, tag in ipairs(list) do newAllowed[tag] = true end
	end
	allowed = newAllowed
	refreshPrompts()
end)

-- 當前訂單
local currentOrder
MatchState.OnClientEvent:Connect(function(kind, payload)
	if kind=="NEW_ORDER" then currentOrder = payload
	elseif kind=="ORDER_RESULT" and payload.ok then currentOrder = nil end
end)

-- 觸發一次動作（長按完成後才會進來）
local function handle(tag: string, inst: Instance)
	local res = StationRF:InvokeServer({ op = "request", tag = tag, station = inst })
	if not (res and res.ok) then return end
	if not res.granted then
		local p = resolvePart(inst)
		if p then
			local pr = p:FindFirstChild("_StationPrompt")
			if pr then pr.ActionText = ("Queued #%d"):format(res.queueIndex or 0) end
		end
		return
	end

	-- 已授權 → 執行對應動作
	if tag == "Station_Pickup" then
		local item = (inst:GetAttribute("ItemId") or inst.Name)
		Interact:FireServer({op="pickup", item=item})
	elseif tag == "Station_Cut" then
		Interact:FireServer({op="mark", field="cut", station = inst})
	elseif tag == "Station_Cook" then
		Interact:FireServer({op="mark", field="cook", station = inst})
	elseif tag == "Station_Plate" then
		Interact:FireServer({op="plateAdd", station = inst})
	elseif tag == "Station_Deliver" then
		if currentOrder then
			SubmitOrder:FireServer({ id = currentOrder.id, ingredients = currentOrder.recipe.ingredients })
		end
	end

	-- 完成後釋放此座台
	StationRF:InvokeServer({ op = "finish", tag = tag, station = inst })
end

-- 伺服端回報完成後，把 ActionText 還原
StationNet.OnClientEvent:Connect(function(kind, payload)
	if kind=="STATE" and payload and payload.finished and payload.userId == localPlayer.UserId then
		for _, tag in ipairs(TAGS) do
			for _, inst in ipairs(CollectionService:GetTagged(tag)) do
				local p = resolvePart(inst)
				if p then
					local pr = p:FindFirstChild("_StationPrompt")
					if pr then pr.ActionText = actionTextFor(inst, tag) end
				end
			end
		end
	end
end)

-- 1) 掛上現有的
for _, tag in ipairs(TAGS) do
	local found = CollectionService:GetTagged(tag)
	if #found == 0 then
		warn(('[Prompt] ⚠️ 場景目前找不到 Tag %q 的物件'):format(tag))
	end
	for _, inst in ipairs(found) do
		local pr = ensurePrompt(inst, tag)
		if pr then
			pr.Triggered:Connect(function(plr)
				if plr == localPlayer then handle(tag, inst) end
			end)
		end
	end
end

-- 2) 監聽之後新增的
for _, tag in ipairs(TAGS) do
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
		local pr = ensurePrompt(inst, tag)
		if pr then
			pr.Triggered:Connect(function(plr)
				if plr == localPlayer then handle(tag, inst) end
			end)
		end
	end)
end

-- 角色重生保險
localPlayer.CharacterAdded:Connect(function(c)
	character = c
	hrp = c:WaitForChild("HumanoidRootPart")
end)
