local SSS = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")
local PlayerData = require(Systems:WaitForChild("PlayerData"))
local Players = game:GetService("Players")

local CookSystem = {}
-- userId -> session
local sessions = {}

local CUISINE_FACTOR = {
	Basic=0.00, Salad=0.10, Dessert=0.05,
	Asian=-0.05, Grill=-0.04, French=-0.08
}
local function scaleWindow(base, level, cuisine)
	-- 等級越高越難（窗口縮小），菜系調整正負
	local lvl = tonumber(level) or 1
	local lvlHard = math.clamp((lvl-1)*0.02, 0, 0.30) -- 最高縮小 30%
	local cf = CUISINE_FACTOR[cuisine or "Basic"] or 0
	local scale = math.clamp(1.0 + cf - lvlHard, 0.6, 1.2)
	return math.max(0.12, (tonumber(base) or 0.30) * scale)
end

local function gradeStep(step, timing)
	if type(timing) ~= "number" then return "Fail", 0 end
	local window = tonumber(step.window) or 0.30
	local diff = math.abs(timing - 0.5)
	if diff <= window * 0.30 then return "Perfect", 2
	elseif diff <= window then return "Good", 1
	else return "Fail", 0 end
end

function CookSystem:Start(player, payload)
	if not player or type(payload) ~= "table" or (type(payload.orderId) ~= "string" and type(payload.orderId) ~= "number") or type(payload.recipe) ~= "table" then
		return nil, "BAD_PAYLOAD"
	end
	local orderIdStr = tostring(payload.orderId)
	local prof = PlayerData:Get(player) or {Level=1}
	local cuisine = payload.recipe.cuisine or "Basic"
	local rawSteps = payload.recipe.steps
	if type(rawSteps) ~= "table" or #rawSteps == 0 then
		rawSteps = { {name="切菜",window=0.32}, {name="翻面",window=0.30}, {name="裝盤",window=0.28} }
	end

	local steps = {}
	for _, s in ipairs(rawSteps) do
		table.insert(steps, { name=s.name, window=scaleWindow(s.window or 0.30, prof.Level, cuisine) })
	end

	sessions[player.UserId] = {
		orderId   = orderIdStr,
		recipeId  = payload.recipe.id or payload.recipe.name or "?",
		steps     = steps,
		idx       = 1,
		startedAt = os.clock(),
		results   = {},
		score     = 0,
	}
	return { idx = 1, step = steps[1] }
end

function CookSystem:SubmitStep(player, timing)
	local sess = player and sessions[player.UserId]
	if not sess then return nil, "NO_SESSION" end
	local i, step = sess.idx, sess.steps[sess.idx]
	if not step then return nil, "ALREADY_DONE" end
	local grade, pts = gradeStep(step, timing)
	sess.results[i] = grade
	sess.score = sess.score + pts
	sess.idx = sess.idx + 1
	local nextStep = sess.steps[sess.idx]
	local done = (nextStep == nil)
	if done then
		self:Clear(player)
	end
	return {
		done       = done,
		grade      = grade,
		stepIndex  = i,
		next       = nextStep and { idx = sess.idx, step = nextStep } or nil,
		totalScore = sess.score,
	}
end

function CookSystem:IsComplete(player, orderId)
	local s = player and sessions[player.UserId]
	if not s then return false end
	if orderId and s.orderId ~= orderId then return false end
	return (s.idx or 1) > #(s.steps or {})
end

function CookSystem:GetScore(player, orderId)
	local s = player and sessions[player.UserId]
	if not s then return 0 end
	if orderId and s.orderId ~= orderId then return 0 end
	return s.score or 0
end

function CookSystem:Clear(player)
	if player then sessions[player.UserId] = nil end
end

Players.PlayerRemoving:Connect(function(p)
	sessions[p.UserId] = nil
end)

return CookSystem