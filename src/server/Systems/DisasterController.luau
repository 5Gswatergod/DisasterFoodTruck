-- ServerScriptService/Systems/DisasterController.lua
local RS          = game:GetService("ReplicatedStorage")
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Debris      = game:GetService("Debris")

-- Remotes 用集中索引，避免 WaitForChild 卡住
local Remotes     = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local ShakeCam    = Remotes.ShakeCam

-- 讀取災難設定；若沒有就用後備
local cfgFolder = RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Configs")
local ok, Disasters = pcall(function()
	if cfgFolder and cfgFolder:FindFirstChild("Disasters") then
		return require(cfgFolder.Disasters)
	end
	return nil
end)

-- 後備清單（如果你的 Configs/Disasters 沒準備好）
if not ok or type(Disasters) ~= "table" or type(Disasters.GetRandom) ~= "function" then
	local Fallback = {
		list = {
			{id="LowGravity"},
			{id="StrongWind"},
			{id="FloorIsLava"},
			{id="MeteorShower"},
		}
	}
	function Fallback.GetRandom()
		return Fallback.list[math.random(1, #Fallback.list)]
	end
	Disasters = Fallback
end

local DisasterController = {}
local running = false

-- 執行期狀態（用於清理）
local state = {
	origGravity = nil,
	windConn    = nil,
	lavaFolder  = nil,
	meteors     = {},
	activeId    = nil,
}

-- === 具體效果 ===
local function applyLowGravity()
	state.origGravity = workspace.Gravity
	workspace.Gravity = math.max(10, (state.origGravity or 196.2) * 0.45)
end
local function clearLowGravity()
	if state.origGravity then
		workspace.Gravity = state.origGravity
		state.origGravity = nil
	end
end

local function applyStrongWind()
	-- 心跳推力（X 正向）
	local dir = Vector3.new(1, 0, 0) * 35
	if state.windConn then state.windConn:Disconnect() end
	state.windConn = RunService.Heartbeat:Connect(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + dir
			end
		end
	end)
end
local function clearStrongWind()
	if state.windConn then state.windConn:Disconnect() end
	state.windConn = nil
end

local function applyFloorIsLava()
	-- 在 Baseplate 上鋪一層薄熔岩
	state.lavaFolder = Instance.new("Folder")
	state.lavaFolder.Name = "_LavaRuntime"
	state.lavaFolder.Parent = workspace

	local base = workspace:FindFirstChild("Baseplate")
	if not base or not base:IsA("BasePart") then
		warn("[Disaster] FloorIsLava: no Baseplate; skip geometry.")
		return
	end

	local lava = Instance.new("Part")
	lava.Name = "Lava"
	lava.Anchored = true
	lava.CanCollide = true
	lava.Material = Enum.Material.Neon
	lava.Color = Color3.fromRGB(255, 102, 64)
	lava.Size = Vector3.new(base.Size.X, 0.2, base.Size.Z)
	lava.CFrame = base.CFrame * CFrame.new(0, 0.11, 0)
	lava.Parent = state.lavaFolder

	lava.Touched:Connect(function(hit)
		local hum = hit and hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hum then hum:TakeDamage(10) end
	end)
end
local function clearFloorIsLava()
	if state.lavaFolder then
		state.lavaFolder:Destroy()
		state.lavaFolder = nil
	end
end

local function applyMeteorShower()
	-- 在玩家附近隨機丟流星
	local refPos = Vector3.new(0, 10, 0)
	local any = Players:GetPlayers()[1]
	local hrp = any and any.Character and any.Character:FindFirstChild("HumanoidRootPart")
	if hrp then refPos = hrp.Position end

	local function spawnMeteor(origin)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(2,2,2)
		p.Color = Color3.fromRGB(255, 170, 64)
		p.Material = Enum.Material.Neon
		p.Anchored = false
		p.CanCollide = true
		p.Position = origin + Vector3.new(math.random(-40,40), math.random(40,60), math.random(-40,40))
		p.Parent = workspace
		table.insert(state.meteors, p)
		p.Touched:Connect(function(hit)
			local hum = hit and hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
			if hum then hum:TakeDamage(15) end
		end)
		Debris:AddItem(p, 10)
	end

	for _ = 1, 14 do
		spawnMeteor(refPos)
	end
end
local function clearMeteorShower()
	for i = #state.meteors, 1, -1 do
		local m = state.meteors[i]
		if m and m.Parent then m:Destroy() end
		state.meteors[i] = nil
	end
end

-- === 切換器 ===
local function applyEffect(id)
	state.activeId = id
	if id == "LowGravity" then
		applyLowGravity()
	elseif id == "StrongWind" then
		applyStrongWind()
	elseif id == "FloorIsLava" then
		applyFloorIsLava()
	elseif id == "MeteorShower" then
		applyMeteorShower()
	end
end

local function clearEffect(id)
	if id == "LowGravity" then
		clearLowGravity()
	elseif id == "StrongWind" then
		clearStrongWind()
	elseif id == "FloorIsLava" then
		clearFloorIsLava()
	elseif id == "MeteorShower" then
		clearMeteorShower()
	end
	state.activeId = nil
end

-- === 介面 ===
function DisasterController:Start()
	if running then return end
	running = true
	task.spawn(function()
		while running do
			task.wait(math.random(45, 60))
			local d = Disasters.GetRandom()
			if d then
				applyEffect(d.id)
				if ShakeCam then
					ShakeCam:FireAllClients({type="QUAKE", dur=1.2})
				end
				task.wait(math.random(15, 25))
				clearEffect(d.id)
			end
		end
	end)
end

function DisasterController:Stop()
	running = false
	if state.activeId then clearEffect(state.activeId) end
	clearLowGravity(); clearStrongWind(); clearFloorIsLava(); clearMeteorShower()
end

return DisasterController