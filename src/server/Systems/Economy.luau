local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PurchaseItem = Remotes:WaitForChild("PurchaseItem")        -- C→S：提交一次性權杖
local PreauthPurchase = Remotes:WaitForChild("PreauthPurchase")  -- C→S：向伺服器索取一次性權杖

local PlayerData = require(script.Parent.PlayerData)
local Items = require(ReplicatedStorage.Shared.Configs.Items)

local Economy = {}

-- 目錄（SKU → 價格/貨幣/發放規則）
Economy.Catalog = {
	["BackpackSlots_+4"] = {price=500, currency="coins", grant={"INV","Slots",4}},
	["CookSpeed_+10p"]   = {gem=80, currency="gems", grant={"BUFF","CookSpeed",0.1, duration=180}},
	["TruckSkin_Neon"]   = {price=1200, currency="coins", grant={"COS","TruckSkin_Neon"}},
	["Emote_PoseA"]      = {price=300, currency="coins", grant={"EMOTE","Emote_PoseA"}},
}

-- 權杖表：token → {userId, sku, expire}
local TOKENS = {}

local function makeToken(userId, sku)
	local token = HttpService:GenerateGUID(false).."-"..tostring(userId)
	TOKENS[token] = {userId=userId, sku=sku, expire=os.clock()+30} -- 30 秒有效
	return token
end

function Economy:Preauthorize(player, sku)
	local cat = self.Catalog[sku]
	if not cat then return nil, "SKU_NOT_FOUND" end
	-- 可在此加入：等級限制/重複購買限制...
	return makeToken(player.UserId, sku)
end

local function grant(player, sku, cat)
	local profile = PlayerData:Get(player)
	if not profile then return false, "NO_PROFILE" end

	-- 扣款
	if cat.currency == "coins" then
		if (profile.Cash or 0) < (cat.price or 0) then return false, "NO_FUNDS" end
		profile.Cash = (profile.Cash or 0) - (cat.price or 0)
	elseif cat.currency == "gems" then
		if (profile.Gems or 0) < (cat.gem or 0) then return false, "NO_FUNDS" end
		profile.Gems = (profile.Gems or 0) - (cat.gem or 0)
	end

	-- 發放
	local kind = cat.grant[1]
	if kind == "INV" then
		profile.Inventory = profile.Inventory or {Slots=12}
		profile.Inventory.Slots = (profile.Inventory.Slots or 12) + (cat.grant[3] or 0)
	elseif kind == "BUFF" then
		profile.Buffs = profile.Buffs or {}
		profile.Buffs.CookSpeed = {value = cat.grant[3], e
