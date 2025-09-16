--!nonstrict
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local IS_STUDIO = RunService:IsStudio()
local STORE_NAME = IS_STUDIO and "PlayerProfile_DEV" or "PlayerProfile_v1"

-- 嘗試測試一次 GetAsync；若被擋，改用記憶體 fallback
local dsOk, _ = pcall(function()
    return DataStoreService:GetDataStore(STORE_NAME):GetAsync("__ping")
end)
local Store = dsOk and DataStoreService:GetDataStore(STORE_NAME) or nil
local MemStore = {}  -- Studio fallback（關遊戲就清空）

if IS_STUDIO and not Store then
    warn("[PlayerData] Studio 未啟用 API Services，將使用記憶體存檔（關遊戲即清）。")
end

local DEFAULT = {
    Cash=0, Gems=0, Level=1, Exp=0, RecipesUnlocked={"Burger"},
    Cosmetics={TruckSkins={}, Emotes={}},
    Stats={PlatesServed=0, PerfectQTE=0, DisastersDodged=0},
    Inventory={Slots=12}
}

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k,v in pairs(t) do c[k] = deepCopy(v) end
    return c
end

local PlayerData = {}
local session = {}

local function safeGetAsync(key)
    if Store then
        local ok, data = pcall(function() return Store:GetAsync(key) end)
        if ok then return data end
        warn("[PlayerData] GetAsync 失敗，使用預設值。")
        return nil
    else
        return MemStore[key]
    end
end

local function safeSetAsync(key, value)
    if Store then
        pcall(function() Store:SetAsync(key, value) end)
    else
        MemStore[key] = value
    end
end

function PlayerData:Get(player)
    return session[player.UserId]
end

Players.PlayerAdded:Connect(function(plr)
    local key = "u:"..plr.UserId
    local saved = safeGetAsync(key)
    session[plr.UserId] = saved or (table.clone and table.clone(DEFAULT) or deepCopy(DEFAULT))
end)

Players.PlayerRemoving:Connect(function(plr)
    local key = "u:"..plr.UserId
    local data = session[plr.UserId]
    if data then safeSetAsync(key, data) end
    session[plr.UserId] = nil
end)

return PlayerData
