local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local InitRemotes = require(script.Parent.InitRemotes)
InitRemotes.Setup()

local PlayerData = require(script.Parent.Systems.PlayerData)
local OrderSystem = require(script.Parent.Systems.OrderSystem)
local DisasterController = require(script.Parent.Systems.DisasterController)
local Economy = require(script.Parent.Systems.Economy)

task.defer(function()
  DisasterController:Start()
end)

Players.PlayerAdded:Connect(function(plr)
  task.delay(5, function()
    local profile = PlayerData:Get(plr) or {Level=1}
    OrderSystem:SpawnOrder(plr, profile, "Beach")
  end)
end)
