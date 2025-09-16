--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PurchaseItem = Remotes:WaitForChild("PurchaseItem")
local PreauthPurchase = Remotes:WaitForChild("PreauthPurchase")
local PlayerData = require(script.Parent.PlayerData)
local Economy = {}
Economy.Catalog = { ["BackpackSlots_+4"] = {price=500, currency="coins", grant={"INV","Slots",4}} }
local TOKENS = {}
local function makeToken(userId, sku) local t=HttpService:GenerateGUID(false).."-"..userId; TOKENS[t]={userId=userId, sku=sku, expire=os.clock()+30}; return t end
function Economy:Preauthorize(player, sku) if not self.Catalog[sku] then return nil,"SKU_NOT_FOUND" end return makeToken(player.UserId, sku) end
local function grant(player, sku, cat) local profile=PlayerData:Get(player); if not profile then return false end; profile.Cash=(profile.Cash or 0)-(cat.price or 0); return true end
PreauthPurchase.OnServerInvoke = function(player, sku) return Economy:Preauthorize(player, sku) end
PurchaseItem.OnServerEvent:Connect(function(player, payload) local e=TOKENS[(payload or {}).token]; if not e or e.userId~=player.UserId or os.clock()>e.expire then return end; local cat=Economy.Catalog[e.sku]; if not cat then return end; grant(player, e.sku, cat); TOKENS[(payload or {}).token]=nil end)
return Economy
