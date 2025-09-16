local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShakeCam = Remotes:WaitForChild("ShakeCam")

local Disasters = require(ReplicatedStorage.Shared.Configs.Disasters)

local DisasterController = {}
local running = false

function DisasterController:Start()
	if running then return end
	running = true
	task.spawn(function()
		while running do
			task.wait(math.random(45,60))
			local d = Disasters.GetRandom()
			-- TODO: apply server effects
			ShakeCam:FireAllClients({type="QUAKE", dur=1.5})
			task.wait(math.random(15,25))
			-- TODO: clear server effects
		end
	end)
end

return DisasterController
