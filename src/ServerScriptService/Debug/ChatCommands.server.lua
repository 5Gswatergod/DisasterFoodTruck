local Players = game:GetService("Players")
local OrderSystem = require(script.Parent.Parent.Systems.OrderSystem)
Players.PlayerAdded:Connect(function(plr)
  plr.Chatted:Connect(function(msg)
    if msg == "/spawnorder" then OrderSystem:SpawnOrder(plr, {Level=1}, "Beach") end
  end)
end)
