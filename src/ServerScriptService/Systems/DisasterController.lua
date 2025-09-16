--!nonstrict
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")
local ShakeCam = Remotes:WaitForChild("ShakeCam")
local MatchState = Remotes:WaitForChild("MatchState")
local Disasters = require(RS.Shared.Configs.Disasters)
local DisasterController, running = {}, false
function DisasterController:Start()
  if running then return end
  running = true
  task.spawn(function()
    while running do
      task.wait(50)
      local d = Disasters.GetRandom()
      MatchState:FireAllClients("DISASTER_BEGIN", {id=d.id, name=d.name, duration=d.duration})
      ShakeCam:FireAllClients({type="QUAKE", dur=1.2})
      task.wait(18)
      MatchState:FireAllClients("DISASTER_END", {id=d.id})
    end
  end)
end
return DisasterController
