local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local PrepSystem = require(script.Parent.PrepSystem)
local Systems = getSystems()
local PlayerData         = require(Systems:WaitForChild("PlayerData"))
local OrderSystem        = require(Systems:WaitForChild("OrderSystem"))
local DisasterController = require(Systems:WaitForChild("DisasterController"))
local Economy            = require(Systems:WaitForChild("Economy"))
local function getSystems()
	local sys = SSS:FindFirstChild("Systems")
	if not sys then
		local srv = SSS:FindFirstChild("Server")
		if srv then sys = srv:FindFirstChild("Systems") end
	end
	assert(sys, "[Bootstrap] 找不到 Systems 資料夾，請確認在 ServerScriptService 下有 Systems 或 Server/Systems")
	return sys
end

do
	local mod = Systems:FindFirstChild("AntiExploit")
	if mod and mod:IsA("ModuleScript") then
		require(mod)
	end
end

-- 啟動災難輪替
task.defer(function()
	local ok, err = pcall(function() DisasterController:Start() end)
	if not ok then warn("[Bootstrap] DisasterController:Start() 失敗：", err) end
end)

-- 玩家進房 5 秒派第一張訂單（示範）
Players.PlayerAdded:Connect(function(plr)
	task.delay(5, function()
		local profile = PlayerData:Get(plr) or {Level=1}
		OrderSystem:SpawnOrder(plr, profile, "Beach")
	end)
end)

local function currentMapId()
	return workspace:GetAttribute("MapId") or "Beach"
end

Players.PlayerAdded:Connect(function(plr)
	PlayerData:Ensure(plr)
	task.delay(2, function()
		local profile = PlayerData:Get(plr) or {Level=1}
		OrderSystem:SpawnOrder(plr, profile, currentMapId())
	end)
end)

PrepSystem.Init()
OrderSystem.Init()
StationServer.Init()

-- 調試提示
print("[Bootstrap] OK。Systems 路徑 = " .. Systems:GetFullName())
