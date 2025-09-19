-- ServerScriptService/Systems/Economy.luau
-- 掌管金流：發錢、扣錢、查餘額；內部使用 PlayerData 做持久化
--!strict

local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")

local PlayerData = require(Systems:WaitForChild("PlayerData"))

export type Balance = number

local Economy = {}

local function ensureProfile(player: Player)
	local profile = (PlayerData.Ensure and PlayerData:Ensure(player)) or PlayerData:Get(player)
	if not profile then
		-- 建立一個最低限度 profile，避免 nil 錯誤
		profile = { Cash = 0, Level = 1, Exp = 0 }
		if PlayerData.Set then PlayerData:Set(player, profile) end
	end
	return profile
end

local function syncAttr(player: Player, profile)
	if player and player.Character then
		player:SetAttribute("Cash", profile.Cash or 0)
		player:SetAttribute("Level", profile.Level or 1)
	end
end

-- 取得目前餘額
function Economy.GetBalance(player: Player): Balance
	local profile = ensureProfile(player)
	return (profile.Cash or 0) :: number
end

-- 發錢（正數加、負數也可用來扣）
function Economy.GrantCash(player: Player, amount: number): Balance
	amount = math.floor(tonumber(amount) or 0)
	if amount == 0 then return Economy.GetBalance(player) end
	local profile = ensureProfile(player)
	profile.Cash = math.max(0, (profile.Cash or 0) + amount)
	syncAttr(player, profile)
	return profile.Cash
end

-- 扣錢（若不足，回傳 false, 餘額）
function Economy.SpendCash(player: Player, amount: number): (boolean, Balance)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return true, Economy.GetBalance(player) end
	local profile = ensureProfile(player)
	local cur = profile.Cash or 0
	if cur < amount then return false, cur end
	profile.Cash = cur - amount
	syncAttr(player, profile)
	return true, profile.Cash
end

-- 小費語義包裝（方便之後加成就/統計）
function Economy.GrantTip(player: Player, tip: number): Balance
	return Economy.GrantCash(player, tip)
end

-- 經驗值與升級（可選）
function Economy.AddExp(player: Player, delta: number): (number, number)
	delta = math.floor(tonumber(delta) or 0)
	local profile = ensureProfile(player)
	profile.Exp = math.max(0, (profile.Exp or 0) + delta)
	-- 簡單升級曲線：每 100 EXP 升 1 等
	local levelFromExp = 1 + math.floor((profile.Exp or 0) / 100)
	if levelFromExp > (profile.Level or 1) then
		profile.Level = levelFromExp
	end
	syncAttr(player, profile)
	return profile.Level or 1, profile.Exp or 0
end

return Economy