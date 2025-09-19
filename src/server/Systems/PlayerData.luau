local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Central place to bump version if schema changes
local DATASTORE_NAME = "PlayerProfile_v1"
local ProfileStore = DataStoreService:GetDataStore(DATASTORE_NAME)

-- Default profile schema
local DEFAULT = {
	Cash = 0,
	Gems = 0,
	Level = 1,
	Exp = 0,
	RecipesUnlocked = {"Burger"},
	Cosmetics = { TruckSkins = {}, Emotes = {} },
	Stats = { PlatesServed = 0, PerfectQTE = 0, DisastersDodged = 0 },
	Inventory = { Slots = 12 },
}

local PlayerData = {}
local session: {[number]: any} = {}
local AUTOSAVE_SECS = 60 -- keep small while iterating; raise to 120–180 in prod
local MAX_RETRIES = 3

-- ===== helpers =====
local function deepClone(t)
	if typeof(t) ~= "table" then return t end
	local r = {}
	for k, v in pairs(t) do
		r[k] = deepClone(v)
	end
	return r
end

local function mergeDefaults(dst, src)
	-- ensure all DEFAULT keys exist in dst; do not remove unknown keys
	for k, v in pairs(src) do
		if typeof(v) == "table" then
			dst[k] = dst[k] or {}
			mergeDefaults(dst[k], v)
		else
			if dst[k] == nil then dst[k] = v end
		end
	end
end

local function safeUpdateAsync(key: string, updater)
	local tries = 0
	while tries < MAX_RETRIES do
		tries += 1
		local ok, result = pcall(function()
			return ProfileStore:UpdateAsync(key, function(old)
				local current = old or deepClone(DEFAULT)
				mergeDefaults(current, DEFAULT)
				return updater(current)
			end)
		end)
		if ok then return true, result end
		warn(string.format("[PlayerData] UpdateAsync failed (%d/%d): %s", tries, MAX_RETRIES, tostring(result)))
		task.wait(0.5 * tries)
	end
	return false, nil
end

local function safeGetAsync(key)
	local ok, data = pcall(function() return ProfileStore:GetAsync(key) end)
	if not ok then
		warn("[PlayerData] GetAsync failed:", data)
		return nil
	end
	return data
end

-- ===== lifecycle =====
local function initProfile(plr: Player)
	if not plr or not plr.UserId then return end
	if session[plr.UserId] then return end
	local key = "u:" .. plr.UserId

	local saved = safeGetAsync(key)
	local profile = saved and deepClone(saved) or deepClone(DEFAULT)
	mergeDefaults(profile, DEFAULT)
	session[plr.UserId] = profile

	-- reflect a couple of fields to attributes for easy debugging/UI
	pcall(function()
		plr:SetAttribute("Cash", profile.Cash or 0)
		plr:SetAttribute("Level", profile.Level or 1)
	end)
end

function PlayerData:Get(player: Player)
	return session[player.UserId]
end

function PlayerData:Ensure(player: Player)
	if not session[player.UserId] then initProfile(player) end
	return session[player.UserId]
end

-- ===== mutators =====
function PlayerData:AddCash(player: Player, amount: number)
	local p = self:Ensure(player); if not p then return end
	p.Cash = (p.Cash or 0) + (amount or 0)
	pcall(function() player:SetAttribute("Cash", p.Cash) end)
end

function PlayerData:AddGems(player: Player, amount: number)
	local p = self:Ensure(player); if not p then return end
	p.Gems = (p.Gems or 0) + (amount or 0)
end

function PlayerData:AddExp(player: Player, amount: number)
	local p = self:Ensure(player); if not p then return end
	local a = math.max(0, amount or 0)
	p.Exp = (p.Exp or 0) + a
	-- naive leveling curve (100 exp per level); adjust to your design
	while (p.Exp or 0) >= 100 do
		p.Exp -= 100
		p.Level = (p.Level or 1) + 1
	end
	pcall(function() player:SetAttribute("Level", p.Level) end)
end

function PlayerData:AddStat(player: Player, field: string, delta: number)
	local p = self:Ensure(player); if not p then return end
	p.Stats = p.Stats or {}
	p.Stats[field] = (p.Stats[field] or 0) + (delta or 0)
end

-- ===== persistence =====
function PlayerData:SaveNow(player: Player)
	local uid = player and player.UserId
	if not uid then return end
	local key = "u:" .. uid
	local data = session[uid]
	if not data then return end
	local ok = select(1, safeUpdateAsync(key, function(current)
		-- merge session data into the latest value from store
		for k, v in pairs(data) do current[k] = v end
		return current
	end))
	if not ok then warn("[PlayerData] SaveNow failed for", uid) end
end

local function saveAll()
	for _, plr in ipairs(Players:GetPlayers()) do
		PlayerData:SaveNow(plr)
	end
end

-- ===== wiring =====
Players.PlayerAdded:Connect(initProfile)
for _, plr in ipairs(Players:GetPlayers()) do initProfile(plr) end

Players.PlayerRemoving:Connect(function(plr)
	PlayerData:SaveNow(plr)
	session[plr.UserId] = nil
end)

game:BindToClose(function()
	-- Studio single-player also calls this; keep quick
	pcall(saveAll)
end)

-- lightweight autosave loop (server only)
if RunService:IsServer() then
	task.spawn(function()
		while task.wait(AUTOSAVE_SECS) do
			pcall(saveAll)
		end
	end)
end

return PlayerData