--!strict
-- Interact.server.luau
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local R   = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local Interact = R.Interact

local Systems      = SSS:WaitForChild("Systems")
local CarrySystem  = require(Systems:WaitForChild("CarrySystem"))
local FlowDirector = require(Systems:WaitForChild("FlowDirector"))

-- 可選：若你還需要 PrepSystem，就保留 require；否則可以移除
local okPrep, PrepSystem = pcall(function()
	return require(Systems:WaitForChild("PrepSystem"))
end)

local function setTrayPlateFlag(player: Player, has: boolean)
	local char = player.Character
	if not char then return end
	local tool = char:FindFirstChildOfClass("Tool")
	if tool and tool.Name == "ServingTray" then
		tool:SetAttribute("HasPlate", has and true or false)
	end
end

Interact.OnServerEvent:Connect(function(player: Player, payload: any)
	if type(payload) ~= "table" then return end

	-- 切/煮這兩條把 carry 轉換
	if payload.op == "mark" and type(payload.field) == "string" then
		local field = string.lower(payload.field)
		local station = (typeof(payload.station) == "Instance" and payload.station:IsDescendantOf(workspace)) and payload.station or nil
		if field == "cut" then
			pcall(function() CarrySystem:ApplyCut(player) end)
			if okPrep then pcall(function() PrepSystem.StartStep(player, "Cut", {station = station}) end) end
			if okPrep then pcall(function() PrepSystem.CompleteStep(player) end) end
			FlowDirector:Push(player)
		elseif field == "cook" then
			pcall(function() CarrySystem:ApplyCook(player) end)
			if okPrep then pcall(function() PrepSystem.StartStep(player, "Cook", {station = station}) end) end
			if okPrep then pcall(function() PrepSystem.CompleteStep(player) end) end
			FlowDirector:Push(player)
		elseif field == "plate" then
			-- 這條保留給舊流程（現在上盤在 StationServer 做）
			setTrayPlateFlag(player, true)
			FlowDirector:Push(player)
		end

	elseif payload.op == "reset" then
		CarrySystem:Clear(player)
		if okPrep then pcall(function() PrepSystem.ResetOnRespawn(player) end) end
		setTrayPlateFlag(player, false)
		FlowDirector:Push(player)
	end
end)

print("[Interact] ready")