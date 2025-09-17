local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local p = Players.LocalPlayer
local char = p.Character or p.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

local TAGS = {
	Station_Cut = {icon="🔪", color=Color3.fromRGB(80,180,120)},
	Station_Cook = {icon="🍳", color=Color3.fromRGB(255,180,80)},
	Station_Plate = {icon="🍽️", color=Color3.fromRGB(180,180,220)},
	Station_Deliver = {icon="📦", color=Color3.fromRGB(180,140,90)},
}
local MAX_DIST = 40

local function ensureUI(part, meta)
	if part:FindFirstChild("_StationBillboard") then return end

	-- Highlight
	local H = Instance.new("Highlight")
	H.Name = "_StationHL"
	H.OutlineTransparency = 1
	H.FillTransparency = 0.6
	H.FillColor = meta.color
	H.Adornee = part
	H.Enabled = false
	H.Parent = part

	-- Billboard
	local bb = Instance.new("BillboardGui")
	bb.Name = "_StationBillboard"
	bb.Size = UDim2.fromOffset(120, 36)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = part

	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency = 0.2
	txt.BackgroundColor3 = Color3.fromRGB(25,25,25)
	txt.TextColor3 = Color3.fromRGB(255,255,255)
	txt.Font = Enum.Font.GothamSemibold
	txt.TextSize = 14
	txt.Size = UDim2.fromScale(1,1)
	txt.Text = meta.icon .. " 0m"
	txt.Parent = bb
end

local function update(part, meta)
	local bb = part:FindFirstChild("_StationBillboard"); if not bb then return end
	local hl = part:FindFirstChild("_StationHL")

	local d = (part.Position - hrp.Position).Magnitude
	local show = d <= MAX_DIST
	bb.Enabled = show
	if hl then hl.Enabled = d <= 18 end

	local txt = bb:FindFirstChildOfClass("TextLabel")
	if txt then
		txt.Text = string.format("%s  %.1fm", meta.icon, d)
	end
end

-- 監聽每個標籤
for tag, meta in pairs(TAGS) do
	for _, part in ipairs(CollectionService:GetTagged(tag)) do
		if part:IsA("BasePart") then ensureUI(part, meta) end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
		if inst:IsA("BasePart") then ensureUI(inst, meta) end
	end)
end

RunService.Heartbeat:Connect(function()
	for tag, meta in pairs(TAGS) do
		for _, part in ipairs(CollectionService:GetTagged(tag)) do
			if part:IsA("BasePart") then update(part, meta) end
		end
	end
end)