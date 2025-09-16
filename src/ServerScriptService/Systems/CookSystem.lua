--!strict
export type Step = { window: number? }
local CookSystem = {}
function CookSystem:Evaluate(step: Step?, timing: number?): string
  if step == nil or timing == nil then return "Fail" end
  timing = math.clamp(timing, 0, 1)
  local center, window = 0.5, (step.window or 0.3)
  local diff = math.abs(timing - center)
  if diff <= window * 0.3 then return "Perfect"
  elseif diff <= window then return "Good"
  else return "Fail" end
end
return CookSystem
