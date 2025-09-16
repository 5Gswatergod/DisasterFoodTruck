local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ProfileStore = DataStoreService:GetDataStore("PlayerProfile_v1")

local DEFAULT = {Cash=0, Gems=0, Level=1, Exp=0, RecipesUnlocked={"Burger"}, Cosmetics={TruckSkins={}, Emotes={}}, Stats={PlatesServed=0, PerfectQTE=0, DisastersDodged=0}, Inventory={Slots=12}}

local PlayerData = {}
local session = {}

local function safeGetAsync(key)
	local ok, data = pcall(function() return ProfileStore:GetAsync(key) end)
	return ok and data or nil
end

local function safeSetAsync(key, value)
	pcall(function() ProfileStore:SetAsync(key, value) end)
end

function PlayerData:Get(player)
	return session[player.UserId]
end

Players.PlayerAdded:Connect(function(plr)
	local key = "u:"..plr.UserId
	local saved = safeGetAsync(key)
	session[plr.UserId] = saved or table.clone(DEFAULT)
end)

Players.PlayerRemoving:Connect(function(plr)
	local key = "u:"..plr.UserId
	local data = session[plr.UserId]
	if data then safeSetAsync(key, data) end
	session[plr.UserId] = nil
end)

return PlayerData
