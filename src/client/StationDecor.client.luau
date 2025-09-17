local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local R  = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local FlowHint = R.FlowHint

local p = Players.LocalPlayer
local allowed = { Station_Cut=true, Station_Cook=true, Station_Plate=true, Station_Deliver=true } -- 初始允許全部；收到推播後覆寫

FlowHint.OnClientEvent:Connect(function(payload)
	allowed = {}
	for _,tag in ipairs(payload.allowed or {}) do allowed[tag] = true end
end)

local META = {
	Station_Cut    = {icon="🔪", color=Color3.fromRGB(80,180,120)},
	Station_Cook   = {icon="🍳", color=Color3.fromRGB(255,180,80)},
	Station_Plate  = {icon="🍽️", color=Color3.fromRGB(180,180,220)},
	Station_Deliver= {icon="📦", color=Color3.fromRGB(180,140,90)},
	Station_Pickup = {icon="📦", color=Color3.fromRGB(120,160,220)}, -- 雖然預設不顯
}
local MAX_DIST = 40

local function ensureUI(part, meta)
	if part:FindFirstChild("_StationBillboard") then return end
	local H = Instance.new("Highlight")
	H.Name = "_StationHL"; H.OutlineTransparency=1; H.FillTransparency=0.6
	H.FillColor = meta.color; H.Adornee = part; H.Enabled = false; H.Parent = part

	local bb = Instance.new("BillboardGui")
	bb.Name = "_StationBillboard"; bb.Size = UDim2.fromOffset(120, 36)
	bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true; bb.Enabled = false; bb.Parent = part

	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency = 0.2; txt.BackgroundColor3 = Color3.fromRGB(25,25,25)
	txt.TextColor3 = Color3.fromRGB(255,255,255); txt.Font = Enum.Font.GothamSemibold; txt.TextSize = 14
	txt.Size = UDim2.fromScale(1,1); txt.Text = meta.icon .. " 0m"; txt.Parent = bb
end

local function setVisible(part, tag, meta)
	local show = allowed[tag] == true
	local bb = part:FindFirstChild("_StationBillboard")
	local hl = part:FindFirstChild("_StationHL")
	if bb then bb.Enabled = show end
	if hl then hl.Enabled = show end
end

game:GetService("RunService").Heartbeat:Connect(function()
	for tag, meta in pairs(META) do
		for _,inst in ipairs(CollectionService:GetTagged(tag)) do
			if inst:IsA("BasePart") then
				ensureUI(inst, meta)
				setVisible(inst, tag, meta)
			end
		end
	end
end)
