local RS = game:GetService("ReplicatedStorage")
local R  = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local Systems = game:GetService("ServerScriptService"):WaitForChild("Systems")
local StorageSystem = require(Systems:WaitForChild("StorageSystem"))
local PlayerData = require(Systems:WaitForChild("PlayerData"))
local Economy    = require(Systems:WaitForChild("Economy"))

-- 查庫存 + 價格 + 餘額
R.InventoryQuery.OnServerInvoke = function(plr)
	local stock  = StorageSystem.All()
	local prices = StorageSystem.Prices()
	local balance
	if Economy and Economy.GetCash then
		balance = Economy.GetCash(plr)
	else
		local prof = PlayerData:Get(plr) or {}
		balance = tonumber(prof.Cash or prof.Money or 0) or 0
	end
	return { stock = stock, prices = prices, balance = balance }
end

-- 下單（帶伺服器端參數檢查）
R.SupplyOrder.OnServerInvoke = function(plr, payload)
	if type(payload) ~= "table" then return { ok=false, err="BAD_PAYLOAD" } end
	local item = typeof(payload.item) == "string" and payload.item or nil
	if not item or #item == 0 then return { ok=false, err="BAD_ITEM" } end
	local qty = tonumber(payload.qty) or 1
	local eta = tonumber(payload.eta) or 10
	-- 伺服器安全：合理上限/下限
	qty = math.clamp(math.floor(qty), 1, 99)
	eta = math.clamp(math.floor(eta), 5, 120)

	local ok, err, newBal
	local success, perr = pcall(function()
		ok, err, newBal = StorageSystem.OrderForPlayer(plr, item, qty, eta)
	end)
	if not success then
		warn("[SupplyOrder] pcall failed:", perr)
		return { ok=false, err="INTERNAL" }
	end
	return { ok = ok, err = err, newBalance = newBal }
end

-- 餘額查詢（可選，UI 初次打開會用 InventoryQuery 取 balance，這只是保留）
R.BalanceQuery.OnServerInvoke = function(plr)
	if Economy and Economy.GetCash then
		return Economy.GetCash(plr)
	end
	local prof = PlayerData:Get(plr) or {}
	return tonumber(prof.Cash or prof.Money or 0) or 0
end