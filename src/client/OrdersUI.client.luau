local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")
local MatchState = Remotes:WaitForChild("MatchState") :: RemoteEvent
local SubmitOrder = Remotes:WaitForChild("SubmitOrder") :: RemoteEvent

local player = Players.LocalPlayer
local Gui = Instance.new("ScreenGui"); Gui.Name = "OrdersMini"; Gui.ResetOnSpawn = false; Gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(340, 200)
frame.Position = UDim2.fromOffset(20, 80)
frame.BackgroundTransparency = 0.2
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
frame.BorderSizePixel = 0
frame.Parent = Gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.fromOffset(8, 6)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "🧾 訂單"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.BackgroundTransparency = 1
title.Parent = frame

local body = Instance.new("TextLabel")
body.Size = UDim2.new(1, -16, 0, 96)
body.Position = UDim2.fromOffset(8, 36)
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextWrapped = true
body.TextColor3 = Color3.fromRGB(220,220,220)
body.BackgroundTransparency = 1
body.Font = Enum.Font.Gotham
body.TextSize = 14
body.Text = "等待訂單…"
body.Parent = frame

local btn = Instance.new("TextButton")
btn.Size = UDim2.fromOffset(150, 36)
btn.Position = UDim2.fromOffset(8, 140)
btn.Text = "✅ 交付（測試）"
btn.TextColor3 = Color3.fromRGB(15,15,15)
btn.BackgroundColor3 = Color3.fromRGB(255,221,87)
btn.AutoButtonColor = true
btn.Parent = frame
btn.Active = false

-- 右上 Cash
local cashLabel = Instance.new("TextLabel")
cashLabel.Size = UDim2.fromOffset(220, 34)
cashLabel.Position = UDim2.new(1, -240, 0, 20)
cashLabel.BackgroundTransparency = 0.2
cashLabel.BackgroundColor3 = Color3.fromRGB(25,25,25)
cashLabel.BorderSizePixel = 0
cashLabel.TextColor3 = Color3.fromRGB(255,255,255)
cashLabel.TextXAlignment = Enum.TextXAlignment.Center
cashLabel.Font = Enum.Font.GothamSemibold
cashLabel.TextSize = 16
cashLabel.Text = "💰 Cash: 0"
cashLabel.Parent = Gui

local current, busy
local lastCash = 0

local function setIdle()
	current = nil
	busy = false
	btn.Active = false
	btn.Text = "✅ 交付（測試）"
	body.Text = "等待訂單…"
end

-- Debug：列現有 Remotes
task.defer(function()
	for _,c in ipairs(Remotes:GetChildren()) do
		print("[Remotes child]", c.Name, c.ClassName)
	end
end)

MatchState.OnClientEvent:Connect(function(kind, payload)
	if kind == "NEW_ORDER" then
		current = payload
		local r = payload.recipe
		body.Text = string.format("菜品：%s\n需求：%s\n小費基礎：%d",
			r.name or r.id, table.concat(r.ingredients, ", "), r.tipBase or 0)
		btn.Active = true

	elseif kind == "ORDER_RESULT" then
		print("[ORDER_RESULT] ok=", payload and payload.ok, " before=", payload and payload.cashBefore, " after=", payload and payload.cashAfter, " tip=", payload and payload.tip)

		if payload.ok then
			-- 以 after 優先，其次用 before+tip
			local newCash = tonumber(payload.cashAfter)
			if not newCash and tonumber(payload.cashBefore) and tonumber(payload.tip) then
				newCash = tonumber(payload.cashBefore) + tonumber(payload.tip)
			end
			if newCash then
				lastCash = newCash
				cashLabel.Text = ("💰 Cash: %d"):format(newCash)
			end

			body.Text = (body.Text .. ("\n\n✅ 交付成功！小費 +%d"):format(payload.tip or 0))
			-- 清掉目前訂單，等待伺服端 2 秒後派新單
			setIdle()
			busy = false
		else
			body.Text = (body.Text .. "\n\n❌ 驗證失敗")
			busy = false
			btn.Active = true
			btn.Text = "✅ 重試交付"
		end
	end
end)

btn.MouseButton1Click:Connect(function()
	if busy or not current then return end
	busy = true
	btn.Active = false
	btn.Text = "…交付中"
	SubmitOrder:FireServer({ id = current.id, ingredients = current.recipe.ingredients })
end)

setIdle()
