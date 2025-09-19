--!strict
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

-- --- Per-station queue/lock shim（若 StationManager 不支援 station 參數）
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
end

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
			local newQ = {}
			for _, p in ipairs(st.queue) do
				if p ~= plr then table.insert(newQ, p) end
			end
			st.queue = newQ
		end
	end
	StationManager:Leave(plr)
	CarrySystem:Clear(plr)
end)

-- 確保有 Items 資料夾 & Tool；沒有就生成一把簡單 Tool
local function ensureItemTool(itemId: string)
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

local function giveToBackpack(player: Player, itemId: string, equip: boolean?)
	local src = ensureItemTool(itemId)
	local clone = src:Clone()
	local char = player.Character
	if equip and char then
		clone.Parent = char  -- 直接裝備在手上
	else
		clone.Parent = player:WaitForChild("Backpack")
	end
end

StationRF.OnServerInvoke = function(player: Player, payload: any)
	if type(payload) ~= "table" then return { ok=false } end

	-- 嘗試使用 StationManager 的新版簽名 (tag, player, station)；否則退回本地 shim
	local function sm_supports_station(): boolean
		if StationManager and type(StationManager.Request) == "function" then
			local ok = pcall(function()
				StationManager.Request(StationManager, payload.tag, player, payload.station)
			end)
			return ok
		end
		return false
	end

	if payload.op == "request" and payload.tag then
		if sm_supports_station() then
			return StationManager:Request(payload.tag, player, payload.station)
		end
		-- fallback：以 station 為單位鎖
		local inst = payload.station
		if not inst or not _stationHasTag(inst, payload.tag) then
			return { ok=false, err="invalid station" }
		end
		local st = _ensureState(inst)
		if not st.busyBy then
			st.busyBy = player
			st.lastTouch = os.clock()
			return { ok=true, granted=true }
		end
		for i, p in ipairs(st.queue) do
			if p == player then
				return { ok=true, granted=false, queueIndex=i }
			end
		end
		table.insert(st.queue, player)
		return { ok=true, granted=false, queueIndex=#st.queue }

	elseif payload.op == "finish" and payload.tag then
		if sm_supports_station() then
			return StationManager:Finish(payload.tag, player, payload.station)
		end
		local inst = payload.station
		if not inst or not _stationHasTag(inst, payload.tag) then
			return { ok=false, err="invalid station" }
		end
		local st = _ensureState(inst)
		if st.busyBy == player then
			_release(inst, player)
		else
			local newQ = {}
			for _, p in ipairs(st.queue) do
				if p ~= player then table.insert(newQ, p) end
			end
			st.queue = newQ
		end
		return { ok=true }
	end

	return { ok=false, reason="BAD_OP" }
end

InteractEV.OnServerEvent:Connect(function(player: Player, payload: any)
	if type(payload) ~= "table" then return end

	if payload.op == "pickup" and type(payload.item) == "string" then
		local ok = select(1, CarrySystem:Pickup(player, payload.item))
		if ok then giveToBackpack(player, payload.item, true) end

	elseif payload.op == "plateAdd" then
		-- 消耗手上/背包 Tool
		local st = CarrySystem:Get(player)
		if st and st.carry then
			local name = st.carry
			local char = player.Character
			local consumed = false
			if char then
				local tool = char:FindFirstChild(name)
				if tool and tool:IsA("Tool") then tool:Destroy(); consumed = true end
			end
			if not consumed then
				local bp = player:FindFirstChildOfClass("Backpack")
				if bp then
					local tool = bp:FindFirstChild(name)
					if tool and tool:IsA("Tool") then tool:Destroy(); consumed = true end
				end
			end
		end
		CarrySystem:PlaceOnPlate(player)

		-- Plate 步驟（帶 station 以通過 PrepSystem 驗證）
		PrepSystem.StartStep(player, "Plate", { station = payload.station })
		PrepSystem.CompleteStep(player)

		-- 集齊需求就給托盤屬性（沿用你的原邏輯）
		local order = OrderSystem:GetActiveFor(player)
		if order and CarrySystem:IsPlateComplete(player, order.recipe.ingredients) then
			if player.Character then player.Character:SetAttribute("Tray", true) end
		end

	elseif payload.op == "reset" then
		PrepSystem.ResetOnRespawn(player)
		CarrySystem:Clear(player)
	end

	-- 每次互動後更新可見站點
	FlowDirector:Push(player)
end)

print("[StationServer] ready (pickup+backpack+plate)")
