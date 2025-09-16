--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchState: RemoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MatchState") :: any
local Recipes = require(ReplicatedStorage.Shared.Configs.Recipes)

export type Recipe = { id: string, name: string, steps: {any}, tipBase: number? }
export type ActiveOrder = { owner: number, recipe: Recipe, expire: number, tipBase: number }

local OrderSystem = {}
local activeOrders: {[string]: ActiveOrder} = {}

function OrderSystem:SpawnOrder(forPlayer: Player, profile: {[string]: any}?, mapId: string?)
  local r: Recipe = Recipes.GetRandom(profile or {Level=1}, mapId)
  local id = tostring(os.clock())..tostring(math.random(100,999))
  activeOrders[id] = {owner=forPlayer.UserId, recipe=r, expire=os.time()+40, tipBase=r.tipBase or 30}
  MatchState:FireClient(forPlayer, "NEW_ORDER", {id=id, recipe=r, expireAt=os.time()+40})
end

export type SubmitPayload = { id: string, ingredients: {string} }

function OrderSystem:Submit(player: Player, payload: SubmitPayload): (boolean, number?)
  local order = activeOrders[payload.id]
  if order == nil or order.owner ~= player.UserId then
    return false, nil
  end
  if Recipes.Validate(order.recipe, payload.ingredients) then
    activeOrders[payload.id] = nil
    return true, order.tipBase
  end
  return false, nil
end

function OrderSystem:Get(orderId: string): ActiveOrder?
  return activeOrders[orderId]
end

return OrderSystem
