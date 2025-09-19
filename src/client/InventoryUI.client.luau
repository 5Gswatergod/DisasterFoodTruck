--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local R  = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))

-- Remotes (容錯：若 RemotesIndex 尚未宣告，避免直接索引 nil)
local InventoryQuery  = R.InventoryQuery
local InventoryUpdated= R.InventoryUpdated
local BalanceUpdated  = R.BalanceUpdated
local SupplyOrder     = R.SupplyOrder

local lp = Players.LocalPlayer

-- ── UI
local sg = Instance.new("ScreenGui")
sg.Name = "InventoryUI"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = lp:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(1,0)
frame.Position = UDim2.fromScale(0.985, 0.12)
frame.Size = UDim2.fromOffset(320, 320)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = sg

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,28)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "冰箱庫存 (B 開/關)"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.TextScaled = true
title.Parent = frame

local balanceL = Instance.new("TextLabel")
balanceL.Size = UDim2.new(1, -12, 0, 18)
balanceL.Position = UDim2.new(0, 6, 0, 28)
balanceL.BackgroundTransparency = 1
balanceL.Font = Enum.Font.GothamMedium
balanceL.TextXAlignment = Enum.TextXAlignment.Left
balanceL.TextColor3 = Color3.fromRGB(230,230,180)
balanceL.TextScaled = true
balanceL.Parent = frame

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(8, 50)
list.Size = UDim2.new(1, -16, 1, -110)
list.ScrollBarThickness = 6
list.BackgroundTransparency = 1
list.CanvasSize = UDim2.new(0,0,0,0)
list.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0,4)
layout.SortOrder = Enum.SortOrder.Name
layout.Parent = list

local orderPanel = Instance.new("Frame")
orderPanel.Size = UDim2.new(1, -16, 0, 52)
orderPanel.Position = UDim2.new(0, 8, 1, -56)
orderPanel.BackgroundColor3 = Color3.fromRGB(35,35,35)
orderPanel.BackgroundTransparency = 0.1
orderPanel.Parent = frame

local selLabel = Instance.new("TextLabel")
selLabel.BackgroundTransparency = 1
selLabel.Size = UDim2.new(0.48, -8, 1, 0)
selLabel.Position = UDim2.new(0, 8, 0, 0)
selLabel.Font = Enum.Font.GothamMedium
selLabel.TextXAlignment = Enum.TextXAlignment.Left
selLabel.TextColor3 = Color3.fromRGB(230,230,230)
selLabel.TextScaled = true
selLabel.Text = "未選擇"
selLabel.Parent = orderPanel

local qtyBox = Instance.new("TextBox")
qtyBox.Size = UDim2.new(0.18, 0, 0.7, 0)
qtyBox.Position = UDim2.new(0.50, 0, 0.15, 0)
qtyBox.Text = "5"
qtyBox.Font = Enum.Font.Gotham
qtyBox.TextScaled = true
qtyBox.ClearTextOnFocus = false
qtyBox.BackgroundColor3 = Color3.fromRGB(45,45,45)
qtyBox.TextColor3 = Color3.fromRGB(230,230,230)
qtyBox.Parent = orderPanel

local etaBox = Instance.new("TextBox")
etaBox.Size = UDim2.new(0.18, -6, 0.7, 0)
etaBox.Position = UDim2.new(0.69, 0, 0.15, 0)
etaBox.Text = "10" -- 秒
etaBox.Font = Enum.Font.Gotham
etaBox.TextScaled = true
etaBox.ClearTextOnFocus = false
etaBox.BackgroundColor3 = Color3.fromRGB(45,45,45)
etaBox.TextColor3 = Color3.fromRGB(230,230,230)
etaBox.Parent = orderPanel

local orderBtn = Instance.new("TextButton")
orderBtn.Size = UDim2.new(0.14, -6, 0.7, 0)
orderBtn.Position = UDim2.new(0.86, 0, 0.15, 0)
orderBtn.Text = "下單"
orderBtn.Font = Enum.Font.GothamBold
orderBtn.TextScaled = true
orderBtn.BackgroundColor3 = Color3.fromRGB(70,110,70)
orderBtn.TextColor3 = Color3.fromRGB(255,255,255)
orderBtn.AutoButtonColor = true
orderBtn.Parent = orderPanel

local toast = Instance.new("TextLabel")
toast.BackgroundTransparency = 1
toast.Size = UDim2.new(1, -16, 0, 18)
toast.Position = UDim2.new(0, 8, 1, -78)
toast.Font = Enum.Font.Gotham
toast.TextXAlignment = Enum.TextXAlignment.Left
toast.TextColor3 = Color3.fromRGB(200,200,200)
toast.TextScaled = true
toast.Text = ""
toast.Parent = frame

-- ── model
local stock = {}
local prices = {}
local balance = 0
local selectedItem: string? = nil

local function formatCash(n: number)
	return ("$%d"):format(math.floor(n))
end

local function setBalance(n: number)
	balance = n
	balanceL.Text = ("餘額：%s"):format(formatCash(balance))
end

local function row(item: string, qty: number, unitPrice: number)
	local row = Instance.new("Frame")
	row.Name = item -- 讓 UIListLayout 的 Name 排序生效
	row.Size = UDim2.new(1, -4, 0, 28)
	row.BackgroundColor3 = Color3.fromRGB(35,35,35)
	row.BackgroundTransparency = 0.08
	row.Parent = list

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(0.5,0,1,0)
	name.Position = UDim2.new(0,8,0,0)
	name.Font = Enum.Font.Gotham
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = item
	name.TextColor3 = Color3.fromRGB(230,230,230)
	name.TextScaled = true
	name.Parent = row

	local qtyL = Instance.new("TextLabel")
	qtyL.BackgroundTransparency = 1
	qtyL.Size = UDim2.new(0.2,0,1,0)
	qtyL.Position = UDim2.new(0.5,0,0,0)
	qtyL.Font = Enum.Font.Gotham
	qtyL.Text = tostring(qty)
	qtyL.TextColor3 = Color3.fromRGB(180,230,180)
	qtyL.TextScaled = true
	qtyL.Parent = row

	local priceL = Instance.new("TextLabel")
	priceL.BackgroundTransparency = 1
	priceL.Size = UDim2.new(0.25, -8, 1, 0)
	priceL.Position = UDim2.new(0.7,0,0,0)
	priceL.Font = Enum.Font.Gotham
	priceL.TextXAlignment = Enum.TextXAlignment.Right
	priceL.Text = (unitPrice and unitPrice > 0) and ("$"..unitPrice) or "-"
	priceL.TextColor3 = Color3.fromRGB(220,200,160)
	priceL.TextScaled = true
	priceL.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.05, 0, 1, 0)
	btn.Position = UDim2.new(0.95, 0, 0, 0)
	btn.Text = "選"
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.BackgroundColor3 = Color3.fromRGB(70,90,120)
	btn.TextColor3 = Color3.fromRGB(255,255,255)
	btn.Parent = row
	btn.Activated:Connect(function()
		selectedItem = item
		selLabel.Text = ("選擇：%s（$%d/個）"):format(item, unitPrice or 0)
	end)
end

local function rebuild()
	for _,child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local keys = {}
	for k in pairs(stock) do table.insert(keys, k) end
	table.sort(keys)
	for _,k in ipairs(keys) do
		row(k, stock[k] or 0, prices[k])
	end
	list.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 8)
end

-- 初次拉取
do
	local ok, res
	if InventoryQuery then
		ok, res = pcall(function() return InventoryQuery:InvokeServer() end)
	else
		ok, res = false, nil
		warn("[InventoryUI] InventoryQuery remote missing")
	end
	if ok and type(res) == "table" then
		stock   = res.stock  or {}
		prices  = res.prices or {}
		setBalance(tonumber(res.balance or 0) or 0)
		rebuild()
	end
end

-- 推播
if InventoryUpdated then
	InventoryUpdated.OnClientEvent:Connect(function(newStock)
		if type(newStock) == "table" then
			stock = newStock
			rebuild()
		end
	end)
end

if BalanceUpdated then
	BalanceUpdated.OnClientEvent:Connect(function(newBal)
		if typeof(newBal) == "number" then setBalance(newBal) end
	end)
end

-- 下單按鈕
orderBtn.Activated:Connect(function()
	if not selectedItem then
		toast.Text = "請先選擇品項"
		return
	end
	local qty = tonumber(qtyBox.Text) or 0
	local eta = tonumber(etaBox.Text) or 10
	if qty <= 0 then
		toast.Text = "數量必須 > 0"
		return
	end
	if not SupplyOrder then
		toast.Text = "下單失敗：遠端尚未就緒"
		return
	end
	local ok, res = pcall(function()
		return SupplyOrder:InvokeServer({ item = selectedItem, qty = qty, eta = eta })
	end)
	if ok and type(res)=="table" then
		if res.ok then
			toast.Text = ("已下單 %s x%d，%d 秒後到貨"):format(selectedItem, qty, eta)
			if typeof(res.newBalance) == "number" then setBalance(res.newBalance) end
		else
			toast.Text = ("下單失敗：%s"):format(res.err or "?")
		end
	else
		toast.Text = "下單失敗：連線錯誤"
	end
end)

-- 熱鍵顯示/隱藏
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.B then
		frame.Visible = not frame.Visible
	end
end)