local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ProfileStore = DataStoreService:GetDataStore("PlayerProfile_v1")

local DEFAULT = {
	Cash=0, Gems=0, Level=1, Exp=0,
	RecipesUnlocked={"Burger"},
	Cosmetics={TruckSkins={}, Emotes={}},
	Stats={PlatesServed=0, PerfectQTE=0, DisastersDodged=0},
	Inventory={Slots=12}
}

local PlayerData = {}
local session = {}

local function safeGetAsync(key)
	local ok, data = pcall(function() return ProfileStore:GetAsync(key) end)
	return ok and data or nil
end
local function safeSetAsync(key, value)
	pcall(function() ProfileStore:SetAsync(key, value) end)
end

local function cloneDefault()
	return table.clone and table.clone(DEFAULT) or {
		Cash=0, Gems=0, Level=1, Exp=0,
		RecipesUnlocked={"Burger"},
		Cosmetics={TruckSkins={}, Emotes={}},
		Stats={PlatesServed=0, PerfectQTE=0, DisastersDodged=0},
		Inventory={Slots=12}
	}
end

local function initProfile(plr)
	if not plr or not plr.UserId then return end
	if session[plr.UserId] then return end
	local key = "u:"..plr.UserId
	local saved = safeGetAsync(key)
	session[plr.UserId] = saved or cloneDefault()
end

function PlayerData:Get(player)
	return session[player.UserId]
end

function PlayerData:Ensure(player)
	if not session[player.UserId] then initProfile(player) end
	return session[player.UserId]
end

function PlayerData:AddCash(player, amount)
	local p = self:Ensure(player); if not p then return end
	p.Cash = (p.Cash or 0) + (amount or 0)
end

function PlayerData:AddGems(player, amount)
	local p = self:Ensure(player); if not p then return end
	p.Gems = (p.Gems or 0) + (amount or 0)
end

function PlayerData:SaveNow(player)
	local key = "u:"..player.UserId
	local data = session[player.UserId]
	if data then safeSetAsync(key, data) end
end

Players.PlayerAdded:Connect(function(plr)
	initProfile(plr)
end)

for _, plr in ipairs(Players:GetPlayers()) do
	initProfile(plr)
end

Players.PlayerRemoving:Connect(function(plr)
	local key = "u:"..plr.UserId
	local data = session[plr.UserId]
	if data then safeSetAsync(key, data) end
	session[plr.UserId] = nil
end)

return PlayerData