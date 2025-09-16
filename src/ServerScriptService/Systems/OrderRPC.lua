--!strict
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")
local SubmitOrder: RemoteEvent = Remotes:WaitForChild("SubmitOrder") :: any
local MatchState: RemoteEvent = Remotes:WaitForChild("MatchState") :: any

local OrderSystem = require(script.Parent.OrderSystem)
type SubmitPayload = OrderSystem.SubmitPayload

local PlayerData = require(script.Parent.PlayerData)

local function asPayload(v: any): SubmitPayload?
  if typeof(v) == "table" and typeof(v.id) == "string" and typeof(v.ingredients) == "table" then
    return v :: SubmitPayload
  end
  return nil
end

SubmitOrder.OnServerEvent:Connect(function(player: Player, payload: any)
  local p = asPayload(payload)
  if p == nil then
    MatchState:FireClient(player, "ORDER_FAIL", {id = ""})
    return
  end
  local ok, tip = OrderSystem:Submit(player, p)
  if ok then
    local profile = PlayerData:Get(player)
    if profile ~= nil then
      profile.Cash = (profile.Cash or 0) + (tip or 0)
    end
    MatchState:FireClient(player, "ORDER_COMPLETE", {id = p.id, tip = tip or 0})
  else
    MatchState:FireClient(player, "ORDER_FAIL", {id = p.id})
  end
end)

return {}
