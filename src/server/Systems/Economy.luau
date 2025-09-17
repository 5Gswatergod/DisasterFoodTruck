-- ServerScriptService/Systems/Economy.lua  （ModuleScript）
local RS           = game:GetService("ReplicatedStorage")
local HttpService  = game:GetService("HttpService")

-- Remotes 走集中索引，避免 WaitForChild 競態
local R            = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local PurchaseItem = R.PurchaseItem        -- RemoteEvent
local PreauthRF    = R.PreauthPurchase     -- RemoteFunction

local PlayerData   = require(script.Parent.PlayerData)

local Economy = {}

-- 目錄（SKU → 價格/貨幣/發放規則）
Economy.Catalog = {
	["BackpackSlots_+4"] = { price = 500,  currency = "coins", grant = {"INV",  "Slots",      4} },
	["CookSpeed_+10p"]   = { gem   = 80,   currency = "gems",  grant = {"BUFF", "CookSpeed",  0.1, duration = 180} },
	["TruckSkin_Neon"]   = { price = 1200, currency = "coins", grant = {"COS",  "TruckSkin_Neon"} },
	["Emote_PoseA"]      = { price = 300,  currency = "coins", grant = {"EMOTE","Emote_PoseA"} },
}

-- 單次權杖（防重放）
local TOKENS = {}  -- token → {userId, sku, expire}

local function makeToken(userId, sku)
	local token = HttpService:GenerateGUID(false) .. "." .. tostring(userId)
	TOKENS[token] = { userId = userId, sku = sku, expire = os.clock() + 30 }
	return token
end

function Economy:Preauthorize(player, sku)
	local cat = self.Catalog[sku]
	if not cat then
		return nil, "SKU_NOT_FOUND"
	end
	return makeToken(player.UserId, sku)
end

-- 發放邏輯
local function grant(player, sku, cat)
	-- 確保一定有 profile（相容舊版 PlayerData）
	local profile = (PlayerData.Ensure and PlayerData:Ensure(player)) or PlayerData:Get(player)
	if not profile then return false, "NO_PROFILE" end

	-- 扣款
	if cat.currency == "coins" then
		local price = cat.price or 0
		if (profile.Cash or 0) < price then return false, "NO_FUNDS" end
		profile.Cash = (profile.Cash or 0) - price
	elseif cat.currency == "gems" then
		local gem = cat.gem or 0
		if (profile.Gems or 0) < gem then return false, "NO_FUNDS" end
		profile.Gems = (profile.Gems or 0) - gem
	end

	-- 發放內容
	local kind = cat.grant[1]
	if kind == "INV" then
		profile.Inventory = profile.Inventory or { Slots = 12 }
		local add = cat.grant[3] or 0
		profile.Inventory.Slots = (profile.Inventory.Slots or 12) + add

	elseif kind == "BUFF" then
		profile.Buffs = profile.Buffs or {}
		local value = cat.grant[3] or 0
		local dur   = cat.grant.duration or 180
		profile.Buffs.CookSpeed = { value = value, expire = os.time() + dur }

	elseif kind == "COS" then
		profile.Cosmetics = profile.Cosmetics or { TruckSkins = {}, Emotes = {} }
		profile.Cosmetics.TruckSkins = profile.Cosmetics.TruckSkins or {}
		table.insert(profile.Cosmetics.TruckSkins, cat.grant[2])

	elseif kind == "EMOTE" then
		profile.Cosmetics = profile.Cosmetics or { TruckSkins = {}, Emotes = {} }
		table.insert(profile.Cosmetics.Emotes, cat.grant[2])
	end

	return true
end

-- Remote handlers
PreauthRF.OnServerInvoke = function(player, sku)
	return Economy:Preauthorize(player, sku)
end

PurchaseItem.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" then return end
	local token = payload.token
	if type(token) ~= "string" then return end

	local entry = TOKENS[token]
	if not entry then return end
	if entry.userId ~= player.UserId then TOKENS[token] = nil return end
	if os.clock() > entry.expire then TOKENS[token] = nil return end

	local cat = Economy.Catalog[entry.sku]
	if not cat then TOKENS[token] = nil return end

	local ok, err = grant(player, entry.sku, cat)
	TOKENS[token] = nil  -- 單次消耗
	-- TODO: 這裡可上報 analytics（player.UserId, entry.sku, ok, err）
end)

return Economy