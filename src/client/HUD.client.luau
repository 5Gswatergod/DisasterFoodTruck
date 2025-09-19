-- src/server/Systems/OrderSystem.luau
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local Systems = script.Parent
local Recipes = require(RS:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("Recipes"))
local CookSystem = require(Systems:WaitForChild("CookSystem"))
local PrepSystem = require(Systems:WaitForChild("PrepSystem"))
local PlayerData = require(Systems:WaitForChild("PlayerData"))

function OrderSystem:Submit(player, payload)
	local id = payload.id
	local order = activeOrders[id]
	if not order then return false end

	if Recipes.Validate(order.recipe, payload.ingredients) then
		local score = CookSystem:GetScore(player, id) or 0
		local tip   = (order.recipe.tipBase or 0) + (score * 5)

		-- ★ 發錢：更新玩家現金
		local profile = (PlayerData.Ensure and PlayerData:Ensure(player)) or PlayerData:Get(player)
		if profile then
			profile.Cash = (profile.Cash or 0) + tip
		end

		-- 清理活躍訂單與暫存狀態
		activeOrders[id] = nil
		if activeByOwner[uid] == id then activeByOwner[uid] = nil end
		safeCall(CookSystem, "Clear", player)
		local didReset = select(1, safeCall(PrepSystem, "Reset", player))
		if not didReset then
			-- 舊版 PrepSystem 沒有 Reset，嘗試 ResetOnRespawn 略過角色參數
			safeCall(PrepSystem, "ResetOnRespawn", player)
		end
		if player.Character then player.Character:SetAttribute("Tray", false) end

		-- 回傳給 HUD / UI
		if MatchState then
			local cashNow = (profile and profile.Cash) or 0
			MatchState:FireClient(player, "ORDER_RESULT", { ok = true, id = id, tip = tip, cash = cashNow })
		end

		-- 推進流程（可續出下一張等）
		if FlowApi then
			if type(FlowApi.Push) == "function" then
				FlowApi:Push(player)
			elseif type(FlowApi.PushNext) == "function" then
				FlowApi:PushNext(player)
			end
		end

		print(("[OrderSystem] SUBMIT OK %s tip=%d score=%d"):format(id, tip, score))
		return true, tip
	end

	-- other code...
end

-- src/client/HUD.client.luau
-- 輕量 HUD：顯示現金；接收 ORDER_RESULT 顯示小費提示
--!strict

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Remotes
local R = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local MatchState = R.MatchState

-- 額外廣播：餘額更新（非訂單來源的變動）
local BalanceUpdated = R.BalanceUpdated
if BalanceUpdated then
    BalanceUpdated.OnClientEvent:Connect(function(newCash)
        if typeof(newCash) == "number" then
            LocalPlayer:SetAttribute("Cash", newCash)
        end
    end)
end

-- ========= UI 基礎 =========
local function ensureGui(): (ScreenGui, TextLabel, TextLabel)
	local pgui = LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local hud = pgui:FindFirstChild("HUD") :: ScreenGui
	if not hud then
		hud = Instance.new("ScreenGui")
		hud.Name = "HUD"
		hud.ResetOnSpawn = false
		hud.IgnoreGuiInset = true
		hud.Parent = pgui
	end

	local cashLabel = hud:FindFirstChild("CashLabel") :: TextLabel
	if not cashLabel then
		cashLabel = Instance.new("TextLabel")
		cashLabel.Name = "CashLabel"
		cashLabel.Size = UDim2.fromOffset(220, 36)
		cashLabel.Position = UDim2.new(0, 12, 0, 12)
		cashLabel.BackgroundTransparency = 0.35
		cashLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		cashLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		cashLabel.Font = Enum.Font.GothamBold
		cashLabel.TextScaled = true
		cashLabel.Parent = hud
	end

	local tipToast = hud:FindFirstChild("TipToast") :: TextLabel
	if not tipToast then
		tipToast = Instance.new("TextLabel")
		tipToast.Name = "TipToast"
		tipToast.Size = UDim2.fromOffset(260, 34)
		tipToast.AnchorPoint = Vector2.new(0.5, 0)
		tipToast.Position = UDim2.new(0.5, 0, 0, 60)
		tipToast.BackgroundTransparency = 0.25
		tipToast.BackgroundColor3 = Color3.fromRGB(20, 90, 40)
		tipToast.TextColor3 = Color3.fromRGB(255, 255, 255)
		tipToast.Font = Enum.Font.GothamSemibold
		tipToast.TextScaled = true
		tipToast.Visible = false
		tipToast.Parent = hud
	end

	return hud, cashLabel, tipToast
end

local function fmtCash(n: number?): string
	n = math.floor(tonumber(n or 0))
	return string.format("$%d", n :: number)
end

local function updateCashLabel(label: TextLabel)
	label.Text = "Cash: " .. fmtCash(LocalPlayer:GetAttribute("Cash"))
end

local hud, cashLabel, tipToast = ensureGui()
updateCashLabel(cashLabel)

-- 監聽屬性改變（Economy 會同步 Cash 到屬性）
LocalPlayer:GetAttributeChangedSignal("Cash"):Connect(function()
	updateCashLabel(cashLabel)
end)

-- 收到訂單結果 → 顯示小費提示
if MatchState then
    MatchState.OnClientEvent:Connect(function(kind, payload)
        if kind == "ORDER_RESULT" and type(payload) == "table" then
            if payload.ok then
                -- 更新金額（保險）
                if typeof(payload.cash) == "number" then
                    LocalPlayer:SetAttribute("Cash", payload.cash)
                end
                -- Toast 小費
                tipToast.Text = string.format("+ Tip %s", fmtCash(payload.tip))
                tipToast.Visible = true
                task.delay(1.2, function()
                    tipToast.Visible = false
                end)
            end
        end
    end)
end