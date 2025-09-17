local RS   = game:GetService("ReplicatedStorage")
local R    = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local StationRF  = R.StationRF
local InteractEV = R.Interact

local SSS = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")
local StationManager = require(Systems:WaitForChild("StationManager"))
local PrepSystem    = require(Systems:WaitForChild("PrepSystem"))
local CarrySystem   = require(Systems:WaitForChild("CarrySystem"))
local OrderSystem   = require(Systems:WaitForChild("OrderSystem"))

game:GetService("Players").PlayerRemoving:Connect(function(plr)
	StationManager:Leave(plr)
	CarrySystem:Clear(plr)
end)

StationRF.OnServerInvoke = function(player, payload)
	if type(payload) ~= "table" then return { ok=false } end
	if payload.op == "request" and payload.tag then
		return StationManager:Request(payload.tag, player)
	elseif payload.op == "finish" and payload.tag then
		return StationManager:Finish(payload.tag, player)
	else
		return { ok=false, reason="BAD_OP" }
	end
end

-- 場景交互
InteractEV.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" then return end

	if payload.op == "pickup" and type(payload.item) == "string" then
		CarrySystem:Pickup(player, payload.item)

	elseif payload.op == "plateAdd" then
		-- 將手上食材放到盤子，並在集齊需求時自動標記完成 + 給托盤
		CarrySystem:PlaceOnPlate(player)
		local order = OrderSystem:GetActiveFor(player) -- {owner, recipe, ...} or nil
		if order and CarrySystem:IsPlateComplete(player, order.recipe.ingredients) then
			PrepSystem:Mark(player, "plate")
			if player.Character then player.Character:SetAttribute("Tray", true) end
		end

	elseif payload.op == "reset" then
		PrepSystem:Reset(player); CarrySystem:Clear(player)
	end
end)

print("[StationServer] ready (pickup + plate)")