local RS = game:GetService("ReplicatedStorage")
local CookStep = RS.Remotes:WaitForChild("CookStep")
local CookSystem = require(script.Parent.CookSystem)

local PlayerProgress = {} -- [userId] = { [orderId] = stepIndex }

CookStep.OnServerInvoke = function(player, stepData, timing)
  local result = CookSystem:Evaluate(stepData, timing) -- "Perfect"/"Good"/"Fail"
  return result
end
