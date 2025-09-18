--!strict
-- ServerScriptService/Systems/010_Bootstrap.server.luau
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- ========== Helpers ==========
local function findSystemsFolder(): Folder
	local sys = SSS:FindFirstChild("Systems")
	if not sys then
		local srv = SSS:FindFirstChild("Server")
		if srv then sys = srv:FindFirstChild("Systems") end
	end
	assert(sys, "[Bootstrap] 找不到 Systems 資料夾，請確認在 ServerScriptService 下有 Systems 或 Server/Systems")
	return sys :: Folder
end

-- Attempt to require; if recursive require is detected, wait a frame and retry once.
local function safeRequire(moduleScript: ModuleScript)
	local ok, res = pcall(require, moduleScript)
	if ok then return res end
	local msg = tostring(res)
	if string.find(msg, "required recursively") then
		warn(("[Bootstrap] Detected recursive require on %s, retrying once after a heartbeat…"):format(moduleScript:GetFullName()))
		task.wait() -- wait one frame
		local ok2, res2 = pcall(require, moduleScript)
		if ok2 then
			return res2
		else
			warn(("[Bootstrap] Retry failed for %s: %s"):format(moduleScript:GetFullName(), tostring(res2)))
			return nil
		end
	else
		warn(("[Bootstrap] require failed for %s: %s"):format(moduleScript:GetFullName(), msg))
		return nil
	end
end

-- ========== Locate Folders ==========
local Systems = findSystemsFolder()

-- ========== Ensure RemotesIndex is loaded (dual-path tolerant) ==========
do
	local RemotesIndex
	local sharedFolder = RS:FindFirstChild("Shared")
	if sharedFolder and sharedFolder:FindFirstChild("RemotesIndex") then
		RemotesIndex = require(sharedFolder:WaitForChild("RemotesIndex"))
	elseif RS:FindFirstChild("RemotesIndex") then
		RemotesIndex = require(RS:WaitForChild("RemotesIndex"))
	else
		sharedFolder = RS:WaitForChild("Shared", 5)
		if sharedFolder and sharedFolder:FindFirstChild("RemotesIndex") then
			RemotesIndex = require(sharedFolder:WaitForChild("RemotesIndex"))
		else
			RemotesIndex = require(RS:WaitForChild("RemotesIndex"))
		end
	end
end

-- ========== Require Systems (cycle-safe) ==========
local PrepSystem         = safeRequire(Systems:WaitForChild("PrepSystem"))
local OrderSystem      = require(Systems:WaitForChild("OrderSystem"))
local FlowDirector     = require(Systems:WaitForChild("FlowDirector"))
local StationServerObj   = Systems:WaitForChild("StationServer")
local StationServer      = (StationServerObj.ClassName == "ModuleScript") and safeRequire(StationServerObj) or nil
local Economy            = safeRequire(Systems:WaitForChild("Economy"))
local PlayerData         = safeRequire(Systems:WaitForChild("PlayerData"))
local DisasterController = safeRequire(Systems:WaitForChild("DisasterController"))

-- ========== Init order ==========
if PrepSystem and type(PrepSystem.Init) == "function" then
	PrepSystem.Init()
end

if FlowDirector and type(FlowDirector.Init) == "function" then
	FlowDirector.Init(OrderSystem)
end

if OrderSystem and type(OrderSystem.Init) == "function" then
	OrderSystem.Init(FlowDirector)
end

if Economy and type(Economy.Init) == "function" then
	Economy.Init()
end

if StationServer and type(StationServer.Init) == "function" then
	StationServer.Init()
end

-- ========== Start disasters (non-blocking) ==========
task.defer(function()
	if DisasterController and type(DisasterController.Start) == "function" then
		local ok, err = pcall(function() DisasterController:Start() end)
		if not ok then
			warn("[Bootstrap] DisasterController:Start() 失敗：", err)
		end
	end
end)

-- ========== Player flow ==========
local function currentMapId(): string
	return (workspace:GetAttribute("MapId") :: string) or "Beach"
end

Players.PlayerAdded:Connect(function(plr)
	if PlayerData and type(PlayerData.Ensure) == "function" then
		PlayerData:Ensure(plr)
	end
	task.delay(2, function()
		local profile = (PlayerData and type(PlayerData.Get) == "function" and PlayerData:Get(plr)) or { Level = 1 }
		if OrderSystem and type(OrderSystem.SpawnOrder) == "function" then
			local ok, err = pcall(function()
				OrderSystem.SpawnOrder(plr, profile, currentMapId())
			end)
			if not ok then
				warn("[Bootstrap] SpawnOrder 失敗：", err)
			end
		end
	end)
end)

print("[Bootstrap] OK。Systems 路徑 = " .. Systems:GetFullName())