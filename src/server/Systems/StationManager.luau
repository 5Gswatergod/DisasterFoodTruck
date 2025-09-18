local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local R  = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local StationNet = R.StationNet

local StationManager = {}

-- 以「類型」管理的舊行為仍保留；同時新增「每一座台(instance)」的佇列與鎖
local CFG = {
	Station_Cut     = {useTime = 2.2, cooldown = 0.8},
	Station_Cook    = {useTime = 2.6, cooldown = 1.0},
	Station_Plate   = {useTime = 1.2, cooldown = 0.5},
	Station_Deliver = {useTime = 0.8, cooldown = 0.4},
	Station_Pickup  = {useTime = 0.3, cooldown = 0.2},
}

-- =========================
-- State
-- =========================
local S_TAG: {[string]: {userId: number?, busyUntil: number, queue: {number}}} = {}

-- 新：station(Instance) -> { userId?, busyUntil, queue = {Player} }
type StationState = { user: Player?, busyUntil: number, queue: {Player} }
local S_STATION: {[Instance]: StationState} = {}

local function st_tag(tag: string)
	S_TAG[tag] = S_TAG[tag] or {userId=nil, busyUntil=0, queue={}}
	return S_TAG[tag]
end

local function st_station(station: Instance): StationState
	local st = S_STATION[station]
	if not st then
		st = { user = nil, busyUntil = 0, queue = {} }
		S_STATION[station] = st
	end
	return st
end

local function inQueueUserId(t: {number}, uid: number?): number?
	if uid == nil then return nil end
	for i, v in ipairs(t) do if v == uid then return i end end
	return nil
end

local function inQueuePlayer(t: {Player}, plr: Player): number?
	for i, v in ipairs(t) do if v == plr then return i end end
	return nil
end

local function stationHasTag(station: Instance, tag: string): boolean
	if not station or not station:IsDescendantOf(workspace) then return false end
	if CollectionService:HasTag(station, tag) then return true end
	if station:IsA("Model") then
		local pp = station.PrimaryPart
		if pp and CollectionService:HasTag(pp, tag) then return true end
	end
	return false
end

-- =========================
-- Push next helpers
-- =========================

local function pushNext_tag(tag: string)
	local conf = CFG[tag]; if not conf then return end
	local ss = st_tag(tag)
	if ss.userId or os.clock() < ss.busyUntil then return end
	local uid = table.remove(ss.queue, 1)
	if not uid then return end
	ss.userId = uid
	StationNet:FireAllClients("STATE", { tag=tag, userId=uid, granted=true })
	task.delay(conf.useTime, function()
		if ss.userId == uid then
			ss.userId = nil
			ss.busyUntil = os.clock() + conf.cooldown
			StationNet:FireAllClients("STATE", { tag=tag, userId=uid, finished=true })
			task.delay(conf.cooldown, function() pushNext_tag(tag) end)
		end
	end)
end

local function pushNext_station(tag: string, station: Instance)
	local conf = CFG[tag]; if not conf then return end
	local ss = st_station(station)
	if ss.user or os.clock() < ss.busyUntil then return end
	local plr = table.remove(ss.queue, 1)
	if not plr then return end
	ss.user = plr
	StationNet:FireAllClients("STATE", { tag=tag, station=station, userId=plr.UserId, granted=true })
	task.delay(conf.useTime, function()
		if ss.user == plr then
			ss.user = nil
			ss.busyUntil = os.clock() + conf.cooldown
			StationNet:FireAllClients("STATE", { tag=tag, station=station, userId=plr.UserId, finished=true })
			task.delay(conf.cooldown, function() pushNext_station(tag, station) end)
		end
	end)
end

-- =========================
-- Public API
-- =========================

-- Request: 兼容舊簽名 (tag, player)；新簽名為 (tag, player, station)
function StationManager:Request(tag: string, player: Player, station: Instance?)
	local conf = CFG[tag]; if not conf then return { ok=false, reason="BAD_TAG" } end
	local now = os.clock()

	-- 新：若提供了有效的 station instance，使用「每座台」模式
	if station and stationHasTag(station, tag) then
		local ss = st_station(station)
		-- 可立即取得
		if (not ss.user) and now >= ss.busyUntil then
			ss.user = player
			StationNet:FireAllClients("STATE", { tag=tag, station=station, userId=player.UserId, granted=true })
			return { ok=true, granted=true, useTime=conf.useTime, queueIndex=0, cooldownLeft=0 }
		end
		-- 入隊（去重）
		local idx = inQueuePlayer(ss.queue, player)
		if not idx then
			table.insert(ss.queue, player)
			idx = #ss.queue
		end
		-- 提示玩家目前排隊位置
		StationNet:FireClient(player, "QUEUE", { tag=tag, station=station, index=idx })
		return { ok=true, granted=false, queueIndex=idx, cooldownLeft=math.max(0, ss.busyUntil-now) }
	end

	-- 舊：沒有 station 就維持原本「以類型(tag)共用一個鎖」的行為
	local ss = st_tag(tag)
	-- 可立即取得
	if (not ss.userId) and now >= ss.busyUntil then
		ss.userId = player.UserId
		StationNet:FireAllClients("STATE", { tag=tag, userId=player.UserId, granted=true })
		return { ok=true, granted=true, useTime=conf.useTime, queueIndex=0, cooldownLeft=0 }
	end
	-- 入隊（去重）
	local q = ss.queue
	local idx = inQueueUserId(q, player.UserId)
	if not idx then
		table.insert(q, player.UserId)
		idx = #q
	end
	StationNet:FireClient(player, "QUEUE", { tag=tag, index=idx })
	return { ok=true, granted=false, queueIndex=idx, cooldownLeft=math.max(0, ss.busyUntil-now) }
end

-- Finish: 兼容舊簽名 (tag, player)；新簽名為 (tag, player, station)
function StationManager:Finish(tag: string, player: Player, station: Instance?)
	local conf = CFG[tag]; if not conf then return { ok=false } end

	-- 新：每座台
	if station and stationHasTag(station, tag) then
		local ss = st_station(station)
		if ss.user ~= player then
			-- 允許退出隊列
			local i = inQueuePlayer(ss.queue, player)
			if i then table.remove(ss.queue, i) end
			return { ok=false }
		end
		-- 結束使用，進冷卻，並安排下一位（同台）
		ss.user = nil
		ss.busyUntil = os.clock() + conf.cooldown
		StationNet:FireAllClients("STATE", { tag=tag, station=station, userId=player.UserId, finished=true })
		task.delay(conf.cooldown, function() pushNext_station(tag, station) end)
		return { ok=true }
	end

	-- 舊：以類型共用
	local ss = st_tag(tag)
	if ss.userId ~= player.UserId then
		local i = inQueueUserId(ss.queue, player.UserId)
		if i then table.remove(ss.queue, i) end
		return { ok=false }
	end
	ss.userId = nil
	ss.busyUntil = os.clock() + conf.cooldown
	StationNet:FireAllClients("STATE", { tag=tag, userId=player.UserId, finished=true })
	task.delay(conf.cooldown, function() pushNext_tag(tag) end)
	return { ok=true }
end

function StationManager:Leave(player: Player)
	-- 舊：以 tag 清理
	for tag, ss in pairs(S_TAG) do
		if ss.userId == player.UserId then
			ss.userId = nil
			ss.busyUntil = os.clock() + (CFG[tag] and CFG[tag].cooldown or 0.5)
			task.delay(CFG[tag] and CFG[tag].cooldown or 0.5, function() pushNext_tag(tag) end)
		end
		local i = inQueueUserId(ss.queue, player.UserId)
		if i then table.remove(ss.queue, i) end
	end

	-- 新：以 station 清理
	for inst, ss in pairs(S_STATION) do
		if ss.user == player then
			ss.user = nil
			local tagToUse = nil
			-- 嘗試推測這座台屬於哪個 tag（第一個匹配就用）
			for tag in pairs(CFG) do
				if stationHasTag(inst, tag) then
					tagToUse = tag
					break
				end
			end
			local cd = (tagToUse and CFG[tagToUse] and CFG[tagToUse].cooldown) or 0.5
			ss.busyUntil = os.clock() + cd
			task.delay(cd, function()
				if tagToUse then pushNext_station(tagToUse, inst) end
			end)
		end
		local i = inQueuePlayer(ss.queue, player)
		if i then table.remove(ss.queue, i) end
	end
end

return StationManager