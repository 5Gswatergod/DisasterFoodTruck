local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local R  = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local MatchState = R.MatchState

local player = Players.LocalPlayer
local Gui = Instance.new("ScreenGui"); Gui.Name="OrdersMini"; Gui.ResetOnSpawn=false; Gui.Parent=player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame"); frame.Size=UDim2.fromOffset(360,180); frame.Position=UDim2.fromOffset(20,80)
frame.BackgroundColor3=Color3.fromRGB(25,25,25); frame.BackgroundTransparency=0.2; frame.BorderSizePixel=0; frame.Parent=Gui

local title = Instance.new("TextLabel"); title.Size=UDim2.new(1,-16,0,28); title.Position=UDim2.fromOffset(8,6)
title.TextXAlignment=Enum.TextXAlignment.Left; title.Text="🧾 訂單"; title.TextColor3=Color3.fromRGB(255,255,255); title.BackgroundTransparency=1; title.Parent=frame

local body = Instance.new("TextLabel"); body.Size=UDim2.new(1,-16,0,120); body.Position=UDim2.fromOffset(8,36)
body.TextXAlignment=Enum.TextXAlignment.Left; body.TextYAlignment=Enum.TextYAlignment.Top; body.TextWrapped=true
body.TextColor3=Color3.fromRGB(220,220,220); body.BackgroundTransparency=1; body.Font=Enum.Font.Gotham; body.TextSize=14; body.Text="等待訂單…"; body.Parent=frame

local cashLabel = Instance.new("TextLabel"); cashLabel.Size=UDim2.fromOffset(220,34); cashLabel.Position=UDim2.new(1,-240,0,20)
cashLabel.BackgroundColor3=Color3.fromRGB(25,25,25); cashLabel.BackgroundTransparency=0.2; cashLabel.BorderSizePixel=0
cashLabel.TextColor3=Color3.fromRGB(255,255,255); cashLabel.TextXAlignment=Enum.TextXAlignment.Center
cashLabel.Font=Enum.Font.GothamSemibold; cashLabel.TextSize=16; cashLabel.Text="💰 Cash: 0"; cashLabel.Parent=Gui

local current

local function setCash(v) cashLabel.Text=("💰 Cash: %d"):format(v or 0) end

MatchState.OnClientEvent:Connect(function(kind, payload)
	if kind=="NEW_ORDER" then
		current = payload
		local r = payload.recipe
		body.Text = string.format("菜品：%s\n需求：%s\n小費基礎：%d", r.name or r.id, table.concat(r.ingredients, ", "), r.tipBase or 0)
	elseif kind=="ORDER_RESULT" then
		if payload.ok then
			setCash(tonumber(payload.cashAfter) or tonumber(payload.cash) or 0)
			body.Text = (body.Text .. ("\n\n✅ 交付成功！小費 +%d"):format(payload.tip or 0))
			current = nil
		else
			body.Text = (body.Text .. "\n\n❌ 尚未完成烹調/備料")
		end
	elseif kind=="ORDER_HINT" then
		body.Text = body.Text .. "\nℹ️ 請在工作站完成步驟（切→煮→裝盤）"
	end
end)