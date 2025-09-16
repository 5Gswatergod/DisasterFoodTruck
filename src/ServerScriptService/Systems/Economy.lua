local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PurchaseItem = Remotes:WaitForChild("PurchaseItem")
local PreauthPurchase = Remotes:WaitForChild("PreauthPurchase")

local PlayerData = require(script.Parent.PlayerData)

local Economy = {}

Economy.Catalog = {
  ["BackpackSlots_+4"] = {price=500, currency="coins", grant={"INV","Slots",4}},
  ["CookSpeed_+10p"] = {gem=80, currency="gems", grant={"BUFF","CookSpeed",0.1, duration=180}},
  ["TruckSkin_Neon"] = {price=1200, currency="coins", grant={"COS","TruckSkin_Neon"}},
  ["Emote_PoseA"] = {price=300, currency="coins", grant={"EMOTE","Emote_PoseA"}},
}

local TOKENS = {} -- token -> {userId, sku, expire}

local function makeToken(userId, sku)
  local token = HttpService:GenerateGUID(false).."-"..tostring(userId)
  TOKENS[token] = {userId=userId, sku=sku, expire=os.clock()+30}
  return token
end

function Economy:Preauthorize(player, sku)
  local cat = self.Catalog[sku]
  if not cat then return nil, "SKU_NOT_FOUND" end
  return makeToken(player.UserId, sku)
end

local function grant(player, sku, cat)
  local profile = PlayerData:Get(player)
  if not profile then return false, "NO_PROFILE" end
  if cat.currency=="coins" then
    if (profile.Cash or 0) < (cat.price or 0) then return false, "NO_FUNDS" end
    profile.Cash = (profile.Cash or 0) - (cat.price or 0)
  elseif cat.currency=="gems" then
    if (profile.Gems or 0) < (cat.gem or 0) then return false, "NO_FUNDS" end
    profile.Gems = (profile.Gems or 0) - (cat.gem or 0)
  end
  local kind = cat.grant[1]
  if kind=="INV" then
    profile.Inventory = profile.Inventory or {Slots=12}
    profile.Inventory.Slots = (profile.Inventory.Slots or 12) + (cat.grant[3] or 0)
  elseif kind=="BUFF" then
    profile.Buffs = profile.Buffs or {}
    profile.Buffs.CookSpeed = {value=cat.grant[3], expire=os.time()+(cat.grant.duration or 180)}
  elseif kind=="COS" then
    profile.Cosmetics = profile.Cosmetics or {TruckSkins={}, Emotes={}}
    profile.Cosmetics.TruckSkins = profile.Cosmetics.TruckSkins or {}
    table.insert(profile.Cosmetics.TruckSkins, cat.grant[2])
  elseif kind=="EMOTE" then
    profile.Cosmetics = profile.Cosmetics or {TruckSkins={}, Emotes={}}
    table.insert(profile.Cosmetics.Emotes, cat.grant[2])
  end
  return true
end

PreauthPurchase.OnServerInvoke = function(player, sku)
  return Economy:Preauthorize(player, sku)
end

PurchaseItem.OnServerEvent:Connect(function(player, payload)
  if type(payload)~="table" then return end
  local entry = TOKENS[payload.token]
  if not entry then return end
  if entry.userId ~= player.UserId then TOKENS[payload.token]=nil return end
  if os.clock() > entry.expire then TOKENS[payload.token]=nil return end
  local cat = Economy.Catalog[entry.sku]
  if not cat then TOKENS[payload.token]=nil return end
  local ok, err = grant(player, entry.sku, cat)
  TOKENS[payload.token]=nil
end)

return Economy
