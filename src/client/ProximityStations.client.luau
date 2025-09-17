-- 用原生 ProximityPrompt 做交互（E鍵泡泡）
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local R = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local MatchState = R.MatchState
local CookStep   = R.CookStep
local Interact   = R.Interact
local StationRF  = R.StationRF
local StationNet = R.StationNet
local SubmitOrder= R.SubmitOrder

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

-- 當前訂單
local currentOrder
MatchState.OnClientEvent:Connect(function(kind, payload)
	if kind=="NEW_ORDER" then currentOrder = payload
	elseif kind=="ORDER_RESULT" and payload.ok then currentOrder = nil end
end)

-- 依標籤產生提示文案
local function actionTextFor(part, tag)
	if tag == "Station_Pickup" then
		local item = part:GetAttribute("ItemId") or part.Name
		return ("Pick up %s"):format(item)
	elseif tag == "Station_Cut" then
		return "Cut"
	elseif tag == "Station_Cook" then
		return "Cook"
	elseif tag == "Station_Plate" then
		return "Plate"
	elseif tag == "Station_Deliver" then
		return "Deliver"
	end
	return "Use"
end

-- 建立/取得 ProximityPrompt
local function ensurePrompt(part, tag)
	local prompt = part:FindFirstChild("_StationPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "_StationPrompt"
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 12
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.UIOffset = Vector2.new(0, -8)
		prompt.ObjectText = "" -- 僅顯示動作字
		prompt.Parent = part
	end
	prompt.ActionText = actionTextFor(part, tag)
	return prompt
end

-- 小型 QTE：單圈點擊/空白鍵送一次
local function startQTE(kind)
	if not currentOrder then return end
	local steps = (kind=="cut")
		and { {name="切菜",window=0.34},{name="切絲",window=0.32},{name="收刀",window=0.30} }
		or  { {name="下鍋",window=0.32},{name="翻面",window=0.30},{name="起鍋",window=0.28} }
	local ok = CookStep:InvokeServer({op="start", orderId=currentOrder.id, recipe={id=string.upper(kind), cuisine="Basic", steps=steps}})
	if not ok then return end
	local t0, period = os.clock(), 1.6
	local UIS = game:GetService("UserInputService")
	local conn; conn = UIS.InputBegan:Connect(function(input,gp)
		if gp then return end
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.KeyCode==Enum.KeyCode.Space then
			local k = ((os.clock()-t0)%period)/period
			local result = CookStep:InvokeServer({op="step", t=k})
			if result and result.done then
				conn:Disconnect()
				Interact:FireServer({op="mark", field = (kind=="cut" and "cut" or "cook")})
				StationRF:InvokeServer({op="finish", tag = (kind=="cut" and "Station_Cut" or "Station_Cook")})
			end
		end
	end)
end

-- 真正的互動處理
local function handle(tag, part)
	-- 先向伺服端申請使用權（處理排隊/冷卻）
	local res = StationRF:InvokeServer({op="request", tag=tag})
	if not (res and res.ok) then return end
	if not res.granted then
		-- 顯示排隊資訊在 ActionText 上（暫時）
		local p = part:FindFirstChild("_StationPrompt")
		if p then p.ActionText = ("Queued #%d"):format(res.queueIndex or 0) end
		return
	end

	if tag == "Station_Pickup" then
		local item = part:GetAttribute("ItemId") or part.Name
		Interact:FireServer({op="pickup", item=item})
		StationRF:InvokeServer({op="finish", tag="Station_Pickup"})

	elseif tag == "Station_Cut" then
		startQTE("cut")

	elseif tag == "Station_Cook" then
		startQTE("cook")

	elseif tag == "Station_Plate" then
		Interact:FireServer({op="plateAdd"})
		StationRF:InvokeServer({op="finish", tag="Station_Plate"})

	elseif tag == "Station_Deliver" then
		if currentOrder then
			SubmitOrder:FireServer({ id = currentOrder.id, ingredients = currentOrder.recipe.ingredients })
		end
		StationRF:InvokeServer({op="finish", tag="Station_Deliver"})
	end
end

-- 監聽伺服端狀態（可把提示更新回來）
StationNet.OnClientEvent:Connect(function(kind, payload)
	if kind=="STATE" and payload and payload.finished and payload.userId == localPlayer.UserId then
		-- 冷卻完成後還原文案
		for _, tag in ipairs({"Station_Pickup","Station_Cut","Station_Cook","Station_Plate","Station_Deliver"}) do
			for _, inst in ipairs(CollectionService:GetTagged(tag)) do
				local p = inst:FindFirstChild("_StationPrompt")
				if p then p.ActionText = actionTextFor(inst, tag) end
			end
		end
	end
end)

-- 掛上所有站點的 Prompt
local TAGS = {"Station_Pickup","Station_Cut","Station_Cook","Station_Plate","Station_Deliver"}

for _, tag in ipairs(TAGS) do
	-- 已有的
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		if inst:IsA("BasePart") then
			local prompt = ensurePrompt(inst, tag)
			prompt.Triggered:Connect(function(plr)
				if plr == localPlayer then handle(tag, inst) end
			end)
		end
	end
	-- 之後加入的
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
		if inst:IsA("BasePart") then
			local prompt = ensurePrompt(inst, tag)
			prompt.Triggered:Connect(function(plr)
				if plr == localPlayer then handle(tag, inst) end
			end)
		end
	end)
end

-- 角色重生時確保 hrp 有值
localPlayer.CharacterAdded:Connect(function(c)
	character = c
	hrp = c:WaitForChild("HumanoidRootPart")
end)