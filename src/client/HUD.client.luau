-- StarterPlayerScripts/HUD.client.lua
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")
local MatchState = Remotes:WaitForChild("MatchState")

local player = Players.LocalPlayer
local Gui = Instance.new("ScreenGui"); Gui.Name = "HUD"; Gui.ResetOnSpawn = false; Gui.Parent = player:WaitForChild("PlayerGui")

local cash = 0
local cashLabel = Instance.new("TextLabel")
cashLabel.Size = UDim2.fromOffset(220, 38)
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

local toast = Instance.new("TextLabel")
toast.Size = UDim2.fromOffset(300, 40)
toast.Position = UDim2.new(0.5, -150, 0, -50)
toast.BackgroundTransparency = 0.2
toast.BackgroundColor3 = Color3.fromRGB(30,30,30)
toast.BorderSizePixel = 0
toast.TextColor3 = Color3.fromRGB(255,255,255)
toast.Font = Enum.Font.GothamSemibold
toast.TextSize = 16
toast.Visible = false
toast.Parent = Gui

local function showToast(text)
	toast.Text = text
	toast.Visible = true
	toast:TweenPosition(UDim2.new(0.5,-150,0,20), "Out", "Quad", 0.25, true)
	task.delay(1.8, function()
		toast:TweenPosition(UDim2.new(0.5,-150,0,-50), "In", "Quad", 0.25, true)
		task.delay(0.3, function() toast.Visible = false end)
	end)
end

MatchState.OnClientEvent:Connect(function(kind, payload)
	if kind == "ORDER_RESULT" and payload.ok then
		cash = payload.cash or cash
		cashLabel.Text = ("💰 Cash: %d"):format(cash)
		showToast(("小費 +%d"):format(payload.tip or 0))
	end
end)
