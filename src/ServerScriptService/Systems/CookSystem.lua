local CookSystem = {}

function CookSystem:Evaluate(step, timing)
	if not step or not timing then return "Fail" end
	local center = 0.5
	local window = step.window or 0.3
	local diff = math.abs(timing - center)
	if diff <= window * 0.3 then return "Perfect"
	elseif diff <= window then return "Good"
	else return "Fail" end
end

return CookSystem
