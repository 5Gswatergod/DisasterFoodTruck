local RS   = game:GetService("ReplicatedStorage")
local R    = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local StationRF  = R.StationRF
local InteractEV = R.Interact

local SSS = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")
local StationManager = require(Systems:WaitForChild("StationManager"))
local PrepSystem    = require(Systems:WaitForChild("PrepSystem"))
local CarrySystem   = require(Systems:WaitForChild("CarrySystem"))
local OrderSystem   = require(Systems:WaitForChild("OrderSystem"))
local FlowDirector  = require(Systems:WaitForChild("FlowDirector"))

local CollectionService = game:GetService("CollectionService")

-- --- Per-station queue/lock shim (當 StationManager 沒支援 station instance 時使用) ---
type StationState = { busyBy: Player?, queue: {Player}, lastTouch: number }
local _stateByStation: {[Instance]: StationState} = {}
local _BUSY_TIMEOUT = 20

local function _ensureState(station: Instance): StationState
	local st = _stateByStation[station]
	if not st then
		st = { busyBy = nil, queue = {}, lastTouch = os.clock() }
		_stateByStation[station] = st
	end
	return st
end

local function _stationHasTag(station: Instance, tag: string): boolean
	if not station or not station:IsDescendantOf(workspace) then return false end
	if CollectionService:HasTag(station, tag) then return true end
	if station:IsA("Model") then
		local pp = station.PrimaryPart
		if pp and CollectionService:HasTag(pp, tag) then return true end
	end
	return false
end

local function _release(station: Instance, who: Player?)
	local st = _ensureState(station)
	if who and st.busyBy ~= who then return end
	st.busyBy = nil
	st.lastTouch = os.clock()
	-- 可選：通知客戶端完成一次（你已有 StationNet 的 STATE 事件，可保持簡單）
end

-- 逾時釋放，避免鎖死
task.spawn(function()
	while true do
		task.wait(5)
		local now = os.clock()
		for inst, st in pairs(_stateByStation) do
			if st.busyBy and (now - st.lastTouch) > _BUSY_TIMEOUT then
				_release(inst, st.busyBy)
			end
		end
	end
end)

game:GetService("Players").PlayerRemoving:Connect(function(plr)
	for inst, st in pairs(_stateByStation) do
		if st.busyBy == plr then
			_release(inst, plr)
		else
			-- 從 queue 移除
			local newQ = {}
			for _, p in ipairs(st.queue) do
				if p ~= plr then table.insert(newQ, p) end
			end
			st.queue = newQ
		end
	end
end)

-- 確保有 Items 資料夾 & Tool；沒有就生成一把簡單 Tool
local function ensureItemTool(itemId:string)
	local folder = RS:FindFirstChild("Items")
	if not folder then folder = Instance.new("Folder"); folder.Name="Items"; folder.Parent = RS end
	local tool = folder:FindFirstChild(itemId)
	if not tool then
		tool = Instance.new("Tool"); tool.Name = itemId; tool.RequiresHandle = true
		local handle = Instance.new("Part"); handle.Name="Handle"; handle.Size = Vector3.new(0.8,0.4,0.8)
		handle.Color = Color3.fromRGB(240,240,240); handle.Anchored=false; handle.CanCollide=false
		handle.Parent = tool
		tool.Parent = folder
	end
	return tool
end

local function giveToBackpack(player, itemId:string, equip:boolean?)
	local src = ensureItemTool(itemId)
	local clone = src:Clone()
	local char = player.Character
	if equip and char then
		clone.Parent = char  -- 直接裝備在手上
	else
		clone.Parent = player:WaitForChild("Backpack")
	end
end

game:GetService("Players").PlayerRemoving:Connect(function(plr)
	StationManager:Leave(plr)
	CarrySystem:Clear(plr)
end)

StationRF.OnServerInvoke = function(player, payload)
	if type(payload) ~= "table" then return { ok=false } end
	if payload.op == "request" and payload.tag then
		return StationManager:Request(payload.tag, player, payload.station)
	elseif payload.op == "finish" and payload.tag then
		return StationManager:Finish(payload.tag, player, payload.station)
	else
		return { ok=false, reason="BAD_OP" }
	end
end

InteractEV.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" then return end
	if payload.op == "pickup" and type(payload.item) == "string" then
		-- ✅ 給背包 Tool + Carry 狀態
		local ok = select(1, CarrySystem:Pickup(player, payload.item))
		if ok then giveToBackpack(player, payload.item, true) end

	elseif payload.op == "plateAdd" then
		-- ✅ 把「手上/背包」對應 Tool 消耗掉
		local st = CarrySystem:Get(player)
		if st and st.carry then
			local name = st.carry
			local char = player.Character
			local consumed = false
			if char then
				local tool = char:FindFirstChild(name)
				if tool and tool:IsA("Tool") then tool:Destroy(); consumed=true end
			end
			if not consumed then
				local bp = player:FindFirstChildOfClass("Backpack")
				if bp then
					local tool = bp:FindFirstChild(name)
					if tool and tool:IsA("Tool") then tool:Destroy(); consumed=true end
				end
			end
		end
		CarrySystem:PlaceOnPlate(player)

		-- 集齊需求就給托盤屬性（跟你現有邏輯一致）
		local order = OrderSystem:GetActiveFor(player)
		if order and CarrySystem:IsPlateComplete(player, order.recipe.ingredients) then
			local fn = PrepSystem and PrepSystem.Mark
			if type(fn) == "function" then
				local ok = pcall(fn, PrepSystem, player, nil, "plate")
				if not ok then pcall(fn, player, nil, "plate") end
			else
				warn("[StationServer] PrepSystem.Mark missing (plate)")
			end
		end

	elseif payload.op == "mark" then
		-- 來自 QTE 完成後的 cut / cook
		local f = payload.field
		if f == "cut" or f == "cook" or f == "plate" then
			local fn = PrepSystem and PrepSystem.Mark
			if type(fn) == "function" then
				local ok = pcall(fn, PrepSystem, player, nil, f)
				if not ok then pcall(fn, player, nil, f) end
			else
				warn("[StationServer] PrepSystem.Mark missing (generic)")
			end
		end

	elseif payload.op == "reset" then
		PrepSystem:Reset(player); CarrySystem:Clear(player)
	end

	-- ✅ 每次互動後都重算「只允許」的站點並推送
	FlowDirector:Push(player)
end)

print("[StationServer] ready (pickup+backpack+plate)")
