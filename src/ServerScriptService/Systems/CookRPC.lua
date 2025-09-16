--!strict
local RS = game:GetService("ReplicatedStorage")
local CookStep: RemoteFunction = RS:WaitForChild("Remotes"):WaitForChild("CookStep") :: any
local CookSystem = require(script.Parent.CookSystem)
local Types = require(script.Parent.CookSystem) :: any

CookStep.OnServerInvoke = function(player: Player, stepData: Types.Step?, timing: number?): string
  return CookSystem:Evaluate(stepData, timing)
end

return {}
