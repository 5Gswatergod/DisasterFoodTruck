local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShakeCam = Remotes:WaitForChild("ShakeCam")

local Disasters = require(ReplicatedStorage.Shared.Configs.Disasters)

local DisasterController = {}
local running = false

-- 執行期間狀態（用於清理）
local state = {
	origGravity = nil,
	windConn = nil,
	lavaFolder = nil,
	meteors = {},
	activeId = nil,
}

-- === LowGravity ===
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

-- === StrongWind ===
local function applyStrongWind()
	local dir = Vector3.new(1, 0, 0) * 35
	if state.windConn then state.windConn:Disconnect() end
	state.windConn = RunService.Heartbeat:Connect(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.AssemblyLinearVelocity += dir
			end
		end
	end)
end
local function clearStrongWind()
	if state.windConn then state.windConn:Disconnect() end
	state.windConn = nil
end

-- === FloorIsLava ===
local function applyFloorIsLava()
	state.lavaFolder = Instance.new("Folder")
	state.lavaFolder.Name = "_LavaRuntime"
	state.lavaFolder.Parent = workspace

	local base = workspace:FindFirstChild("Baseplate")
	if not base or not base:IsA("BasePart") then
		warn("[Disaster] FloorIsLava: no Baseplate found; skipping hazard geometry.")
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

-- === MeteorShower ===
local function applyMeteorShower()
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

	local refPos = Vector3.new(0, 10, 0)
	local any = Players:GetPlayers()[1]
	local hrp = any and any.Character and any.Character:FindFirstChild("HumanoidRootPart")
	if hrp then refPos = hrp.Position end

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

-- === dispatcher ===
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

function DisasterContr
