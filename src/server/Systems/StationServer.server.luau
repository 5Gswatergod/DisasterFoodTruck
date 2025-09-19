-- ServerScriptService/Systems/StationServer.server.luau
--!strict

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local R       = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local StationRF  = R.StationRF
local InteractEV = R.Interact

local SSS = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")
local StationManager = require(Systems:WaitForChild("StationManager"))
local CarrySystem    = require(Systems:WaitForChild("CarrySystem"))
local OrderSystem    = require(Systems:WaitForChild("OrderSystem"))
local FlowDirector   = require(Systems:WaitForChild("FlowDirector"))

local CollectionService = game:GetService("CollectionService")

-- ============================================================
-- Utilities: Items / Tools
-- ============================================================

local function ensureItemTool(itemId: string): Tool
	local folder = RS:FindFirstChild("Items")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Items"
		folder.Parent = RS
	end
	local tool = folder:FindFirstChild(itemId)
	if not tool then
		tool = Instance.new("Tool")
		tool.Name = itemId
		tool.RequiresHandle = true
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.8, 0.4, 0.8)
		handle.Color = Color3.fromRGB(240,240,240)
		handle.Anchored = false
		handle.CanCollide = false
		handle.Parent = tool
		tool.Parent = folder
	end
	return tool :: Tool
end

local function giveToBackpack(player: Player, itemId: string, equip: boolean?)
	local src = ensureItemTool(itemId)
	local clone = src:Clone()
	local char = player.Character
	if equip and char then
		clone.Parent = char -- 直接裝備
	else
		clone.Parent = player:WaitForChild("Backpack")
	end
end

-- ============================================================
-- Station fallback lock (only if StationManager new API fails)
-- ============================================================

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
		-- deep scan model descendants so tags on inner parts are detected
		for _, d in ipairs(station:GetDescendants()) do
			if d:IsA("BasePart") and CollectionService:HasTag(d, tag) then
				return true
			end
		end
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

Players.PlayerRemoving:Connect(function(plr)
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
	if StationManager and StationManager.Leave then
		StationManager:Leave(plr)
	end
	CarrySystem:Clear(plr)
end)

-- ============================================================
-- RemoteFunction: StationRF
-- ============================================================

StationRF.OnServerInvoke = function(player: Player, payload: any)
	if type(payload) ~= "table" then
		return { ok=false, reason="BAD_PAYLOAD" }
	end

	-- ---------- Request / Finish（優先用 StationManager 的新版簽名） ----------
	if payload.op == "request" and payload.tag then
		local ok, res = pcall(function()
			return StationManager:Request(payload.tag, player, payload.station)
		end)
		if ok and res then return res end

		-- fallback 本地鎖
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
	end

	if payload.op == "finish" and payload.tag then
		local ok, res = pcall(function()
			return StationManager:Finish(payload.tag, player, payload.station)
		end)
		if ok and res then return res end

		-- fallback 本地鎖
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

	-- ---------- 可選：Storage / 訂購（若之後接入再開） ----------
	-- if payload.op == "order" then ... end

	return { ok=false, reason="BAD_OP" }
end

-- ============================================================
-- RemoteEvent: InteractEV（拿料、上盤、切換拿/放盤子、重置）
-- ============================================================

InteractEV.OnServerEvent:Connect(function(player: Player, payload: any)
	if type(payload) ~= "table" then return end

	if payload.op == "pickup" then
		-- 允許 client 明傳 item（已用站上屬性），也可直接從站讀 ItemId 做保險
		local station: Instance? = payload.station
		local item: string? = nil

		if typeof(payload.item) == "string" and payload.item ~= "" then
			item = payload.item
		elseif station then
			-- read ItemId from station (Model or BasePart), with robust fallbacks
			local src: Instance = if station:IsA("Model") then (station.PrimaryPart or station) else station
			local raw = src and src:GetAttribute("ItemId")
			if typeof(raw) ~= "string" or raw == "" then
				local m = station:IsA("Model") and station or station:FindFirstAncestorOfClass("Model")
				if m then
					raw = m:GetAttribute("ItemId")
				end
			end
			if typeof(raw) == "string" and raw ~= "" then
				item = raw :: string
			end
		end

		if not item then
			warn(("[Pickup] Station has no ItemId; player=%s"):format(player.Name))
			return
		end

		-- 真正拿取：給 Carry 狀態 + Tool（直接裝備）
		local ok = select(1, CarrySystem:Pickup(player, item))
		if ok then
			giveToBackpack(player, item, true)
		end

		-- 更新一步提示
		FlowDirector:Push(player)

	elseif payload.op == "plateAdd" then
		-- Plate system temporarily removed; ignore for now to avoid errors.
		return

	elseif payload.op == "reset" then
		-- 清空玩家狀態
		CarrySystem:Clear(player)
		FlowDirector:Push(player)
	end
end)

print("[StationServer] ready (pickup+backpack+plate)")