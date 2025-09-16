local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchState = Remotes:WaitForChild("MatchState")

local Recipes = require(ReplicatedStorage.Shared.Configs.Recipes)

local OrderSystem = {}
local activeOrders = {}

function OrderSystem:SpawnOrder(forPlayer, profile, mapId)
	local r = Recipes.GetRandom(profile or {Level=1}, mapId)
	local id = tostring(os.clock())..tostring(math.random(100,999))
	activeOrders[id] = {owner=forPlayer.UserId, recipe=r, expire=os.time()+30}
	MatchState:FireClient(forPlayer, "NEW_ORDER", {id=id, recipe=r})
end

function OrderSystem:Submit(player, payload)
	local order = activeOrders[payload.id]
	if not order or order.owner ~= player.UserId then return false end
	if Recipes.Validate(order.recipe, payload.ingredients) then
		activeOrders[payload.id] = nil
		return true, order.recipe.tipBase
	end
	return false
end

return OrderSystem
