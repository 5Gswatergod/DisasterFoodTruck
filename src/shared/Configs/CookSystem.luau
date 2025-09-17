local CookSystem = {}

-- 伺服端權威的 QTE 佔位實作：
-- Start(player, {orderId, recipe})  建立一個烹調流程
-- SubmitStep(player, timing)         timing ∈ [0,1]，回傳本步評分與下一步
-- Cancel / IsComplete                管理流程生命週期
--
-- 未來可直接替換此模組以導入更完整的步驟/計分模型。

local sessions = {}  -- userId -> {orderId, recipeId, steps, idx, startedAt, results, score}

local function gradeStep(step, timing)
	-- timing ∈ [0,1]；以 0.5 為中心，step.window 控制寬容度（預設 0.30）
	if type(timing) ~= "number" then return "Fail", 0 end
	local center = 0.5
	local window = tonumber(step.window) or 0.30
	local diff = math.abs(timing - center)
	if diff <= window * 0.30 then
		return "Perfect", 2
	elseif diff <= window then
		return "Good", 1
	else
		return "Fail", 0
	end
end

function CookSystem:Start(player, payload)
	-- payload: {orderId=string, recipe={id=..., steps={...}}}
	if not player or type(payload) ~= "table" or type(payload.orderId) ~= "string" or type(payload.recipe) ~= "table" then
		return nil, "BAD_PAYLOAD"
	end
	local uid = player.UserId
	local steps = payload.recipe.steps or {}
	sessions[uid] = {
		orderId = payload.orderId,
		recipeId = payload.recipe.id or payload.recipe.name or "?",
		steps = steps,
		idx = 1,
		startedAt = os.clock(),
		results = {},
		score = 0,
	}
	return { idx = 1, step = steps[1] }
end

function CookSystem:SubmitStep(player, timing)
	local uid = player and player.UserId
	local sess = uid and sessions[uid]
	if not sess then return nil, "NO_SESSION" end

	local idx = sess.idx
	local step = sess.steps[idx]
	if not step then return nil, "ALREADY_DONE" end

	local grade, pts = gradeStep(step, timing)
	sess.results[idx] = grade
	sess.score = sess.score + pts
	sess.idx = sess.idx + 1

	local nextStep = sess.steps[sess.idx]
	return {
		done = (nextStep == nil),
		grade = grade,
		stepIndex = idx,
		next = nextStep and { idx = sess.idx, step = nextStep } or nil,
		totalScore = sess.score,
	}
end

function CookSystem:Cancel(player)
	if player then sessions[player.UserId] = nil end
end

function CookSystem:IsComplete(player)
	local sess = player and sessions[player.UserId]
	if not sess then return false end
	return sess.idx > #sess.steps
end

return CookSystem
