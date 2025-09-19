-- ServerScriptService/Systems/FlowDirector.luau
--!strict

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local R = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local FlowHint = R.FlowHint

local SSS = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")
local CarrySystem = require(Systems:WaitForChild("CarrySystem"))

local Items = require(RS:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("Items"))

local FlowDirector = {}

export type AllowedList = {string}

local function hasTray(p: Player): boolean
	local char = p.Character
	return (char and char:GetAttribute("Tray") == true) or false
end

function FlowDirector.ComputeAllowed(player: Player): AllowedList
	local allowed: AllowedList = { "Station_Pickup" }

	local st = CarrySystem:Get(player)
	local carry = st and st.carry or nil
	if type(carry) == "string" and carry ~= "" then
		-- 嚴格流程：必須先切、再煮、最後上盤
		local needCut  = Items.NeedsCut(carry) == true
		local needCook = Items.NeedsCook(carry) == true

		if needCut then
			-- 需要切就只開放切
			table.insert(allowed, "Station_Cut")
		elseif needCook then
			-- 不需要切但需要煮 → 只開放煮
			table.insert(allowed, "Station_Cook")
		else
			-- 可直接上盤
			table.insert(allowed, "Station_Plate")
		end
	else
		-- 手上沒東西：允許去拿盤 / 操作盤子
		table.insert(allowed, "Station_Plate")
	end

	if hasTray(player) then
		table.insert(allowed, "Station_Deliver")
	end

	return allowed
end

-- 用冒號定義，搭配 FlowDirector:Push(player) 呼叫
function FlowDirector:Push(player: Player)
	if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then
		warn("[FlowDirector] Push called with non-player:", tostring(player))
		return
	end
	local list = FlowDirector.ComputeAllowed(player)
	FlowHint:FireClient(player, { allowed = list })
end

function FlowDirector:PushAll()
	for _, p in ipairs(Players:GetPlayers()) do
		self:Push(p)
	end
end

return FlowDirector