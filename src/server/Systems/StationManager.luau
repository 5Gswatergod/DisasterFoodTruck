local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local R  = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local StationNet = R.StationNet

local StationManager = {}

-- 以「類型」管理（每種站點共用一個隊列/冷卻即可；之後要細到每一座台可擴展到 per-part）
local CFG = {
	Station_Cut     = {useTime = 2.2, cooldown = 0.8},
	Station_Cook    = {useTime = 2.6, cooldown = 1.0},
	Station_Plate   = {useTime = 1.2, cooldown = 0.5},
	Station_Deliver = {useTime = 0.8, cooldown = 0.4},
	Station_Pickup  = {useTime = 0.3, cooldown = 0.2},
}

-- 狀態：tag -> { userId?, busyUntil, queue = {userId,...} }
local S = {}

local function st(tag)
	S[tag] = S[tag] or {userId=nil, busyUntil=0, queue={}}
	return S[tag]
end

local function inQueue(t, uid)
	for i, v in ipairs(t) do if v == uid then return i end end
	return nil
end

local function pushNext(tag)
	local conf = CFG[tag]; if not conf then return end
	local ss = st(tag)
	if ss.userId or os.clock() < ss.busyUntil then return end
	local uid = table.remove(ss.queue, 1)
	if not uid then return end
	ss.userId = uid
	StationNet:FireAllClients("STATE", { tag=tag, userId=uid, granted=true })
	task.delay(conf.useTime, function()
		-- 如果使用者卡住沒 finish，就自動釋放進入冷卻
		if ss.userId == uid then
			ss.userId = nil
			ss.busyUntil = os.clock() + conf.cooldown
			StationNet:FireAllClients("STATE", { tag=tag, userId=uid, finished=true })
			task.delay(conf.cooldown, function() pushNext(tag) end)
		end
	end)
end

function StationManager:Request(tag, player)
	local conf = CFG[tag]; if not conf then return { ok=false, reason="BAD_TAG" } end
	local ss = st(tag)
	local now = os.clock()

	-- 可立即取得
	if not ss.userId and now >= ss.busyUntil then
		ss.userId = player.UserId
		StationNet:FireAllClients("STATE", { tag=tag, userId=player.UserId, granted=true })
		return { ok=true, granted=true, useTime=conf.useTime, queueIndex=0, cooldownLeft=0 }
	end

	-- 進入隊列
	local q = ss.queue
	if not inQueue(q, player.UserId) then table.insert(q, player.UserId) end
	local idx = inQueue(q, player.UserId)
	StationNet:FireClient(player, "QUEUE", { tag=tag, index=idx })
	return { ok=true, granted=false, queueIndex=idx, cooldownLeft=math.max(0, ss.busyUntil-now) }
end

function StationManager:Finish(tag, player)
	local conf = CFG[tag]; if not conf then return { ok=false } end
	local ss = st(tag)
	if ss.userId ~= player.UserId then
		-- 若在隊列中，允許放棄排隊
		local i = inQueue(ss.queue, player.UserId)
		if i then table.remove(ss.queue, i) end
		return { ok=false }
	end
	-- 結束使用，進冷卻，並安排下一位
	ss.userId = nil
	ss.busyUntil = os.clock() + conf.cooldown
	StationNet:FireAllClients("STATE", { tag=tag, userId=player.UserId, finished=true })
	task.delay(conf.cooldown, function() pushNext(tag) end)
	return { ok=true }
end

function StationManager:Leave(player)
	for tag, ss in pairs(S) do
		if ss.userId == player.UserId then
			ss.userId = nil
			ss.busyUntil = os.clock() + (CFG[tag] and CFG[tag].cooldown or 0.5)
			task.delay(CFG[tag] and CFG[tag].cooldown or 0.5, function() pushNext(tag) end)
		end
		local i = inQueue(ss.queue, player.UserId)
		if i then table.remove(ss.queue, i) end
	end
end

return StationManager