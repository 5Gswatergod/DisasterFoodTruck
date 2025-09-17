-- ServerScriptService/Systems/CookNetwork.server.lua
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Remotes    = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local CookStepRF = Remotes.CookStep

local Systems     = SSS:WaitForChild("Systems")
local CookSystem  = require(Systems:WaitForChild("CookSystem"))

CookStepRF.OnServerInvoke = function(player, payload)
	if type(payload) ~= "table" then return nil, "BAD_PAYLOAD" end
	local op = payload.op
	if op == "start" then
		return CookSystem:Start(player, { orderId = payload.orderId, recipe = payload.recipe })
	elseif op == "step" then
		return CookSystem:SubmitStep(player, tonumber(payload.t))
	elseif op == "cancel" then
		CookSystem:Clear(player); return true
	end
	return nil, "BAD_OP"
end

print("[CookNetwork] ready")