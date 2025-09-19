--!strict
local StorageSystem = {}

local RS = game:GetService("ReplicatedStorage")
local R  = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local SSS = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")
local PlayerData = require(Systems:WaitForChild("PlayerData"))
local Economy    = require(Systems:WaitForChild("Economy"))


type StockMap = {[string]: number}
type PriceMap = {[string]: number}

local DEFAULT_SEED: StockMap = {
	Milk = 10,
	Ice = 30,
	Syrup = 12,
	Bun = 12,
	PattyRaw = 12,
	Lettuce = 16,
}

local _stock: StockMap = {}
local _prices: PriceMap = {
	-- 你可自由調整單價（每單位進貨價）
	Milk=6, Ice=2, Syrup=4,
	Bun=4, PattyRaw=8, Lettuce=3,
}

local function _allStock(): StockMap
	local t: StockMap = {}
	for k,v in pairs(_stock) do t[k]=v end
	return t
end

local function _broadcastStock()
	if R and R.InventoryUpdated then
		R.InventoryUpdated:FireAllClients(_allStock())
	end
end

local function _getCash(plr: Player): number
	-- 嘗試從 Economy / PlayerData 取得餘額；沒有就 0
	local ok, val = pcall(function()
		if Economy and Economy.GetCash then
			return Economy.GetCash(plr)
		end
		if PlayerData and PlayerData.Get then
			local prof = PlayerData:Get(plr) or {}
			return tonumber(prof.Cash or prof.Money or 0) or 0
		end
		return 0
	end)
	return ok and (val or 0) or 0
end

local function _setCash(plr: Player, newCash: number)
	pcall(function()
		if Economy and Economy.SetCash then
			Economy.SetCash(plr, newCash)
		elseif PlayerData and PlayerData.Set then
			local prof = PlayerData:Get(plr) or {}
			prof.Cash = newCash
			PlayerData:Set(plr, prof)
		end
	end)
	if R and R.BalanceUpdated then
		R.BalanceUpdated:FireClient(plr, newCash)
	end
end

local function _tryCharge(plr: Player, cost: number): (boolean, number)
	cost = math.max(0, math.floor(cost))
	local bal = _getCash(plr)
	if bal < cost then return false, bal end
	_setCash(plr, bal - cost)
	return true, bal - cost
end

function StorageSystem.Init(seed: StockMap?)
	_stock = {}
	-- merge: provided seed overrides defaults; defaults fill any missing items
	local src: StockMap = {}
	for k,v in pairs(DEFAULT_SEED) do src[k] = v end
	for k,v in pairs(seed or {}) do src[k] = v end
	for k,v in pairs(src) do
		local n = tonumber(v) or 0
		if n ~= n or n < 0 then n = 0 end -- handle NaN/negative
		_stock[k] = math.floor(n)
	end
	_broadcastStock()
end

function StorageSystem.All(): StockMap
	return _allStock()
end

function StorageSystem.Prices(): PriceMap
	local t: PriceMap = {}
	for k,v in pairs(_prices) do t[k]=v end
	return t
end

function StorageSystem.Stock(item: string): number
	return _stock[item] or 0
end

function StorageSystem.Withdraw(player: Player, item: string): (boolean, string?)
	local n = _stock[item] or 0
	if n <= 0 then return false, "OUT_OF_STOCK" end
	_stock[item] = n - 1
	_broadcastStock()
	return true
end

-- 玩家下單（立即扣款，延遲到貨）
function StorageSystem.OrderForPlayer(plr: Player, item: string, qty: number, etaSec: number?): (boolean, string?, number?)
	if type(item) ~= "string" then return false, "BAD_ITEM" end
	qty = math.max(1, math.floor(qty))
	local unit = _prices[item]
	if not unit then return false, "NO_PRICE" end
	local cost = unit * qty
	local ok, newBal = _tryCharge(plr, cost)
	if not ok then return false, "NO_FUNDS", _getCash(plr) end

	local eta = tonumber(etaSec) or 10
	if eta < 1 then eta = 1 end
	task.delay(eta, function()
		_stock[item] = (_stock[item] or 0) + qty
		print(("[Storage] inbound %s x%d arrived; now=%d"):format(item, qty, _stock[item]))
		_broadcastStock()
	end)
	return true, nil, newBal
end

function StorageSystem.AddStock(item: string, qty: number)
	qty = math.max(1, math.floor(tonumber(qty) or 0))
	_stock[item] = (_stock[item] or 0) + qty
	_broadcastStock()
end

function StorageSystem.Refund(plr: Player, amount: number)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	local bal = _getCash(plr)
	_setCash(plr, bal + amount)
end

return StorageSystem