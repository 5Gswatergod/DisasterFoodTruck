-- StarterPlayer/StarterPlayerScripts/ProximityStations.client.luau
-- 原生 ProximityPrompt 交互（支援 Tag 打在 Model 或 BasePart），含除錯訊息
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local R = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local FlowHint = R.FlowHint
local allowed = {}  -- 由事件決定；預設空，初始掃描時不會禁用
local TAGS = {"Station_Pickup","Station_Cut","Station_Cook","Station_Plate","Station_Deliver"}

local function refreshPrompts()
	for _, tag in ipairs(TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			local part = (inst:IsA("BasePart") and inst)
				or (inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)))
			if part then
				local pr = part:FindFirstChild("_StationPrompt")
				if pr then
					pr.Enabled = (allowed[tag] == true)
				end
			end
		end
	end
end

FlowHint.OnClientEvent:Connect(function(payload)
	-- 兼容三種：純陣列 / {allow={}} / {allowed={}}
	local list
	if typeof(payload) == "table" then
		if #payload > 0 then
			list = payload
		else
			list = payload.allow or payload.allowed or payload.tags
		end
	end

	-- 重新建立 allowed：永遠開放拿取站
	local newAllowed = { Station_Pickup = true }
	if type(list) == "table" then
		for _, tag in ipairs(list) do
			newAllowed[tag] = true
		end
	end
	allowed = newAllowed
	refreshPrompts()
end)


local MatchState = R.MatchState
local CookStep   = R.CookStep
local Interact   = R.Interact
local StationRF  = R.StationRF
local StationNet = R.StationNet
local SubmitOrder= R.SubmitOrder

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local TAGS = {"Station_Pickup","Station_Cut","Station_Cook","Station_Plate","Station_Deliver"}

-- 當前訂單
local currentOrder
MatchState.OnClientEvent:Connect(function(kind, payload)
	if kind=="NEW_ORDER" then currentOrder = payload
	elseif kind=="ORDER_RESULT" and payload.ok then currentOrder = nil end
end)

-- 取得可掛 Prompt 的 BasePart（支援 Model）
local function resolvePart(inst)
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function actionTextFor(inst, tag)
	if tag == "Station_Pickup" then
		local item = (inst:GetAttribute("ItemId") or (inst:IsA("BasePart") and inst:GetAttribute("ItemId")) or inst.Name)
		return ("Pick up %s"):format(item)
	elseif tag == "Station_Cut" then return "Cut"
	elseif tag == "Station_Cook" then return "Cook"
	elseif tag == "Station_Plate" then return "Plate"
	elseif tag == "Station_Deliver" then return "Deliver"
	else return "Use" end
end

local function ensurePrompt(holderInst, tag)
	local part = resolvePart(holderInst)
	if not part then
		warn(("[Prompt] ❌ %s 沒有可用 BasePart：%s"):format(tag, holderInst:GetFullName()))
		return nil
	end
	local prompt = part:FindFirstChild("_StationPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "_StationPrompt"
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 12
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.UIOffset = Vector2.new(0, -8)
		prompt.ObjectText = "" -- 只顯示動作字
		prompt.Parent = part
		print(("[Prompt] ✅ 掛上 %s → %s"):format(tag, part:GetFullName()))
	end
	prompt.ActionText = actionTextFor(holderInst, tag)
	return prompt
end

-- 小型 QTE
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

-- 觸發一次動作
local function handle(tag, inst)
    -- request
	local res = StationRF:InvokeServer({ op = "request", tag = tag, station = inst })

    if not (res and res.ok) then return end
    if not res.granted then
        -- ✅ 修正拼字 & 顯示排隊序
        local p = resolvePart(inst)
        if p then
            local pr = p:FindFirstChild("_StationPrompt")
            if pr then pr.ActionText = ("Queued #%d"):format(res.queueIndex or 0) end
        end
        return
    end
	
	if tag == "Station_Pickup" then
		local item = (inst:GetAttribute("ItemId") or inst.Name)
		Interact:FireServer({op="pickup", item=item})
		StationRF:InvokeServer({ op = "finish", tag = tag, station = inst })
	elseif tag == "Station_Cut" then
		startQTE("cut")
	elseif tag == "Station_Cook" then
		startQTE("cook")
	elseif tag == "Station_Plate" then
		Interact:FireServer({op="plateAdd"})
		StationRF:InvokeServer({ op = "finish", tag = tag, station = inst })
	elseif tag == "Station_Deliver" then
		if currentOrder then
			SubmitOrder:FireServer({ id = currentOrder.id, ingredients = currentOrder.recipe.ingredients })
		end
		StationRF:InvokeServer({ op = "finish", tag = tag, station = inst })
	end
end

-- 伺服端回報完成後，把 ActionText 還原
StationNet.OnClientEvent:Connect(function(kind, payload)
	if kind=="STATE" and payload and payload.finished and payload.userId == localPlayer.UserId then
		for _, tag in ipairs(TAGS) do
			for _, inst in ipairs(CollectionService:GetTagged(tag)) do
				local p = resolvePart(inst)
				if p then
					local pr = p:FindFirstChild("_StationPrompt")
					if pr then pr.ActionText = actionTextFor(inst, tag) end
				end
			end
		end
	end
end)

-- 1) 掛上現有的
for _, tag in ipairs(TAGS) do
	local found = CollectionService:GetTagged(tag)
	if #found == 0 then
		warn(("[Prompt] ⚠️ 場景目前找不到 Tag '%s' 的物件"):format(tag))
	end
	for _, inst in ipairs(found) do
		local pr = ensurePrompt(inst, tag)
		if pr then
			pr.Triggered:Connect(function(plr)
				if plr == localPlayer then handle(tag, inst) end
			end)
		end
	end
end

-- 2) 監聽之後新增的
for _, tag in ipairs(TAGS) do
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
		local pr = ensurePrompt(inst, tag)
		if pr then
			pr.Triggered:Connect(function(plr)
				if plr == localPlayer then handle(tag, inst) end
			end)
		end
	end)
end

-- 角色重生保險
localPlayer.CharacterAdded:Connect(function(c)
	character = c
	hrp = c:WaitForChild("HumanoidRootPart")
end)