--!strict
-- ServerScriptService/Systems/FlowDirector.luau
-- 依玩家目前進度決定允許互動的站點，並把允許的 tags 推給用戶端 (FlowHint)

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

-- Remotes
local RemotesIndex = (function()
	local shared = RS:FindFirstChild("Shared")
	if shared and shared:FindFirstChild("RemotesIndex") then
		return require(shared:WaitForChild("RemotesIndex"))
	end
	return require(RS:WaitForChild("RemotesIndex"))
end)()

local FlowHint: RemoteEvent? = RemotesIndex and RemotesIndex.FlowHint or nil

-- 其他系統（僅在需要時 require，避免循環）
local PrepSystem = require(SSS:WaitForChild("Systems"):WaitForChild("PrepSystem"))

local FlowDirector = {}
local OrderApi: any = nil  -- 由 Bootstrap 注入：OrderSystem

-- 站點優先順序與對應 tag 名
local PRIORITY = { "cut", "cook", "plate", "deliver" }
local TAG_OF = {
	cut     = "Station_Cut",
	cook    = "Station_Cook",
	plate   = "Station_Plate",
	deliver = "Station_Deliver",
}

-- 初始化：由 010_Bootstrap 傳入 OrderSystem 的 API
function FlowDirector.Init(orderSystemApi: any)
	OrderApi = orderSystemApi
end

-- 將玩家目前應該顯示/允許的站點 tags
function FlowDirector:AllowedTagsFor(player: Player): {string}
	-- 1) 沒訂單：至少允許拿取站
	local order = nil
	if OrderApi and type(OrderApi.GetActiveFor) == "function" then
		order = OrderApi:GetActiveFor(player)
	end
	if not order then
		return { "Station_Pickup" }
	end

	-- 2) 讀 Prep 進度旗標（預設都未完成）
	local st = { cut = false, cook = false, plate = false }
	if type(PrepSystem.GetState) == "function" then
		local ps = PrepSystem.GetState(player)
		if ps and ps.meta then
			st.cut   = ps.meta.cutDone   == true
			st.cook  = ps.meta.cookDone  == true
			st.plate = ps.meta.plateDone == true
		end
	elseif type(PrepSystem.Get) == "function" then
		local ps = PrepSystem.Get(PrepSystem, player)
		if ps then
			if ps.cut   ~= nil then st.cut   = ps.cut   end
			if ps.cook  ~= nil then st.cook  = ps.cook  end
			if ps.plate ~= nil then st.plate = ps.plate end
		end
	end

	-- 3) 允許列表：永遠包含 Pickup，再加上下一步
	local allowed = { "Station_Pickup" }

	-- 若三步都完成 → 準許交付
	if (st.cut and st.cook and st.plate) then
		table.insert(allowed, "Station_Deliver")
		return allowed
	end

	-- 否則依優先順序補一個「下一步」
	if not st.cut  then table.insert(allowed, "Station_Cut");   return allowed end
	if not st.cook then table.insert(allowed, "Station_Cook");  return allowed end
	if not st.plate then table.insert(allowed, "Station_Plate"); return allowed end

	return allowed
end

-- 推送給用戶端（純陣列，符合你的前端 Handler）
function FlowDirector:Push(player: Player)
	if FlowHint then
		local tags = self:AllowedTagsFor(player)
		FlowHint:FireClient(player, tags)
	end
end

function FlowDirector:PushNext(player: Player)
	return self:Push(player)
end

return FlowDirector