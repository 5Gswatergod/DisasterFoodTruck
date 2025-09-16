--!nonstrict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")
local MatchState = Remotes:WaitForChild("MatchState")
local CookStep = Remotes:WaitForChild("CookStep")
local SubmitOrder = Remotes:WaitForChild("SubmitOrder")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local function new(class, props, parent) local i=Instance.new(class); for k,v in pairs(props or {}) do i[k]=v end; i.Parent=parent; return i end
local gui = new("ScreenGui", {Name="MainHUD", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, playerGui)
local top = new("Frame", {Name="TopHUD", Size=UDim2.new(0,420,0,42), Position=UDim2.new(1,-440,0,12), BackgroundTransparency=0.3, BackgroundColor3=Color3.fromRGB(30,30,30)}, gui)
new("UICorner", {CornerRadius=UDim.new(0,12)}, top)
local topLbl = new("TextLabel", {Text="💰 0   💎 0   Lv.1   ⏱ 00:00", TextColor3=Color3.new(1,1,1), BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=18, Size=UDim2.new(1,-16,1,0), Position=UDim2.new(0,8,0,0), TextXAlignment=Enum.TextXAlignment.Left}, top)
local banner = new("TextLabel", {Name="DisasterBanner", Size=UDim2.new(0.6,0,0,44), Position=UDim2.new(0.5,0,0,10), AnchorPoint=Vector2.new(0.5,0), BackgroundColor3=Color3.fromRGB(200,60,60), TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBlack, TextScaled=true, Visible=false, Text="DISASTER!"}, gui)
new("UICorner", {CornerRadius=UDim.new(0,12)}, banner)
local orderFrame = new("Frame", {Name="OrderList", Size=UDim2.new(0.3,0,0.5,0), Position=UDim2.new(0,12,0.15,0), BackgroundTransparency=0.15, BackgroundColor3=Color3.fromRGB(25,25,25)}, gui)
new("UICorner", {CornerRadius=UDim.new(0,12)}, orderFrame)
local orderTitle = new("TextLabel", {Text="訂單 Orders", BackgroundTransparency=1, TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=20, Size=UDim2.new(1,-16,0,28), Position=UDim2.new(0,8,0,6), TextXAlignment=Enum.TextXAlignment.Left}, orderFrame)
local list = new("ScrollingFrame", {Size=UDim2.new(1,-16,1,-40), Position=UDim2.new(0,8,0,36), CanvasSize=UDim2.new(0,0,0,0), ScrollBarThickness=6, BackgroundTransparency=1}, orderFrame)
new("UIListLayout", {Padding=UDim.new(0,8)}, list)
local qte = new("Frame", {Name="QTEBar", Size=UDim2.new(0.5,0,0,56), Position=UDim2.new(0.5,0,1,-72), AnchorPoint=Vector2.new(0.5,1), BackgroundColor3=Color3.fromRGB(30,30,30), Visible=false}, gui)
new("UICorner", {CornerRadius=UDim.new(0,14)}, qte)
local bar = new("Frame", {Size=UDim2.new(1,-20,0,10), Position=UDim2.new(0,10,0.5,-5), BackgroundColor3=Color3.fromRGB(60,60,60)}, qte)
new("UICorner", {CornerRadius=UDim.new(0,5)}, bar)
local perfect = new("Frame", {Size=UDim2.new(0.22,0,1,0), Position=UDim2.new(0.39,0,0,0), BackgroundColor3=Color3.fromRGB(255,200,0)}, bar)
local marker = new("Frame", {Size=UDim2.new(0,6,0,22), Position=UDim2.new(0,0,0.5,-11), BackgroundColor3=Color3.fromRGB(255,255,255)}, qte)
new("UICorner", {CornerRadius=UDim.new(0,3)}, marker)
local tapBtn = new("TextButton", {Text="TAP / 空白鍵", Size=UDim2.new(0,160,0,36), Position=UDim2.new(0.5,0,0,-42), AnchorPoint=Vector2.new(0.5,1), BackgroundColor3=Color3.fromRGB(70,70,70), TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=16}, qte)
new("UICorner", {CornerRadius=UDim.new(0,10)}, tapBtn)
local serveBtn = new("TextButton", {Text="SERVE", Size=UDim2.new(0,130,0,46), Position=UDim2.new(1,-150,1,-80), BackgroundColor3=Color3.fromRGB(0,140,120), TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=20, Visible=false}, gui)
new("UICorner", {CornerRadius=UDim.new(0,12)}, serveBtn)
local toast = new("TextLabel", {BackgroundTransparency=0.2, BackgroundColor3=Color3.fromRGB(20,20,20), TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=20, Text="", Visible=false, Size=UDim2.new(0,320,0,40), Position=UDim2.new(0.5,0,0.1,0), AnchorPoint=Vector2.new(0.5,0)}, gui)
new("UICorner", {CornerRadius=UDim.new(0,10)}, toast)
local function showToast(msg, color) toast.Text=msg; toast.TextColor3=color or Color3.new(1,1,1); toast.Visible=true; toast.BackgroundTransparency=0.2; TweenService:Create(toast, TweenInfo.new(0.25), {BackgroundTransparency=0.05}):Play(); task.delay(1.5, function() TweenService:Create(toast, TweenInfo.new(0.3), {BackgroundTransparency=1}):Play(); task.wait(0.3); toast.Visible=false end) end
local orders, currentId, currentStep = {}, nil, 1
local function newUI(class, props, parent) local i=Instance.new(class); for k,v in pairs(props or {}) do i[k]=v end; i.Parent=parent; return i end
local function createOrderCard(payload)
  local card = newUI("Frame", {Size=UDim2.new(1,-4,0,86), BackgroundColor3=Color3.fromRGB(35,35,35)}, list)
  newUI("UICorner", {CornerRadius=UDim.new(0,10)}, card)
  local _title = newUI("TextLabel", {Text=payload.recipe.name.."  (#"..string.sub(payload.id, -3)..")", BackgroundTransparency=1, TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=18, Size=UDim2.new(1,-8,0,22), Position=UDim2.new(0,8,0,6), TextXAlignment=Enum.TextXAlignment.Left}, card)
  local steps = {}; local stepRow = newUI("Frame", {Size=UDim2.new(1,-16,0,14), Position=UDim2.new(0,8,0,34), BackgroundTransparency=1}, card)
  newUI("UIListLayout", {Padding=UDim.new(0,6), FillDirection=Enum.FillDirection.Horizontal}, stepRow)
  for i,_ in ipairs(payload.recipe.steps) do local dot=newUI("Frame",{Size=UDim2.new(0,14,0,14), BackgroundColor3=Color3.fromRGB(90,90,90)}, stepRow); newUI("UICorner",{CornerRadius=UDim.new(1,0)}, dot); steps[i]=dot end
  local startBtn = newUI("TextButton", {Text="開始製作", Size=UDim2.new(0,110,0,30), Position=UDim2.new(0,8,0,56), BackgroundColor3=Color3.fromRGB(70,100,220), TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=16}, card)
  newUI("UICorner", {CornerRadius=UDim.new(0,8)}, startBtn)
  local serve = newUI("TextButton", {Text="上菜", Size=UDim2.new(0,80,0,30), Position=UDim2.new(0,130,0,56), BackgroundColor3=Color3.fromRGB(0,140,120), TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold, TextSize=16, Visible=false}, card)
  newUI("UICorner", {CornerRadius=UDim.new(0,8)}, serve)
  return {widget=card, steps=steps, startBtn=startBtn, serveBtn=serve}
end
local activeTween
local function startCooking(orderId)
  local ord = orders[orderId]; if not ord then return end
  currentId=orderId; currentStep=1; qte.Visible=true; serveBtn.Visible=false
  local s=ord.recipe.steps[currentStep]; local half=(s.window or 0.3)/2
  perfect.Position=UDim2.new(0.5-half,0,0,0); perfect.Size=UDim2.new((s.window or 0.3),0,1,0)
  if activeTween then activeTween:Cancel() end
  marker.Position=UDim2.new(0,0,0.5,-11)
  activeTween=TweenService:Create(marker, TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {Position=UDim2.new(1,-6,0.5,-11)}); activeTween:Play()
  for i,dot in ipairs(ord.card.steps) do dot.BackgroundColor3 = i<currentStep and Color3.fromRGB(0,180,120) or Color3.fromRGB(90,90,90) end
end
local function nextStep()
  local ord=orders[currentId]; if not ord then return end
  currentStep = currentStep + 1
  if currentStep > #ord.recipe.steps then
    qte.Visible=false; serveBtn.Visible=true; ord.card.serveBtn.Visible=true; showToast("完成！可以上菜", Color3.fromRGB(0,200,150)); if activeTween then activeTween:Cancel() end; return
  end
  local s=ord.recipe.steps[currentStep]; local half=(s.window or 0.3)/2
  perfect.Position=UDim2.new(0.5-half,0,0,0); perfect.Size=UDim2.new((s.window or 0.3),0,1,0)
  for i,dot in ipairs(ord.card.steps) do dot.BackgroundColor3 = i<currentStep and Color3.fromRGB(0,180,120) or Color3.fromRGB(90,90,90) end
end
local function evaluateCurrent()
  local ord=orders[currentId]; if not ord then return end
  local s=ord.recipe.steps[currentStep]
  local t=(marker.AbsolutePosition.X - bar.AbsolutePosition.X)/math.max(1, bar.AbsoluteSize.X)
  t = math.clamp(t, 0, 1)
  local result = CookStep:InvokeServer(s, t)
  if result=="Perfect" then showToast("Perfect!", Color3.fromRGB(255,210,0)); ord.card.steps[currentStep].BackgroundColor3=Color3.fromRGB(255,210,0); nextStep()
  elseif result=="Good" then showToast("Good!", Color3.fromRGB(0,200,150)); ord.card.steps[currentStep].BackgroundColor3=Color3.fromRGB(0,180,120); nextStep()
  else showToast("Fail!", Color3.fromRGB(230,80,80)) end
end
tapBtn.MouseButton1Click:Connect(evaluateCurrent)
game:GetService("UserInputService").InputBegan:Connect(function(input,gpe) if gpe then return end; if input.KeyCode==Enum.KeyCode.Space then evaluateCurrent() end end)
serveBtn.MouseButton1Click:Connect(function() local ord=orders[currentId]; if not ord then return end; SubmitOrder:FireServer({id=currentId, ingredients=ord.recipe.ingredients}) end)
local function hookServe(card, orderId) card.serveBtn.MouseButton1Click:Connect(function() local ord=orders[orderId]; if not ord then return end; SubmitOrder:FireServer({id=orderId, ingredients=ord.recipe.ingredients}) end) end
MatchState.OnClientEvent:Connect(function(kind, payload)
  if kind=="NEW_ORDER" then
    local cardUI = createOrderCard(payload)
    orders[payload.id] = {recipe=payload.recipe, card=cardUI}
    cardUI.startBtn.MouseButton1Click:Connect(function() startCooking(payload.id) end)
    hookServe(cardUI, payload.id)
  elseif kind=="ORDER_COMPLETE" then
    local id=payload.id; if orders[id] and orders[id].card then orders[id].card.widget:Destroy() end; orders[id]=nil; serveBtn.Visible=false; qte.Visible=false; showToast("+ 小費 "..tostring(payload.tip), Color3.fromRGB(255,210,0))
  elseif kind=="ORDER_FAIL" then showToast("交付失敗", Color3.fromRGB(230,80,80))
  elseif kind=="DISASTER_BEGIN" then banner.Text = "⚠ "..(payload.name or "災難").."  ("..tostring(payload.duration or 0).."s)"; banner.Visible=true
  elseif kind=="DISASTER_END" then banner.Visible=false end
end)
