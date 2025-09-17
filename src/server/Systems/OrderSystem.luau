local RS         = game:GetService("ReplicatedStorage")
local R          = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local MatchState = R.MatchState

local SSS        = game:GetService("ServerScriptService")
local Systems    = SSS:WaitForChild("Systems")
local Recipes    = require(RS.Shared.Configs.Recipes)
local CookSystem = require(Systems:WaitForChild("CookSystem"))
local PrepSystem = require(Systems:WaitForChild("PrepSystem"))

local OrderSystem = {}
local activeOrders  = {}
local activeByOwner = {}  -- uid -> orderId

function OrderSystem:SpawnOrder(forPlayer, profile, mapId)
	local uid = forPlayer.UserId
	if activeByOwner[uid] then
		MatchState:FireClient(forPlayer, "ORDER_HINT", { alreadyHas = true, id = activeByOwner[uid] })
		return activeByOwner[uid]
	end
	local r  = Recipes.GetRandom(profile or {Level=1}, mapId)
	local id = tostring(os.clock())..tostring(math.random(100,999))
	activeOrders[id]  = { owner = uid, recipe = r, expire = os.time()+60 }
	activeByOwner[uid]= id
	PrepSystem:SetOrder(forPlayer, id)
	MatchState:FireClient(forPlayer, "NEW_ORDER", { id = id, recipe = r })
	print(("[OrderSystem] NEW_ORDER %s for %s"):format(id, forPlayer.Name))
	return id
end

function OrderSystem:Submit(player, payload)
	if type(payload) ~= "table" then return false end
	local uid, id = player.UserId, payload.id
	local order = id and activeOrders[id]
	if not order or order.owner ~= uid then return false end

	-- 必須完成 QTE & 備料三步
	if not CookSystem:IsComplete(player, id) then
		MatchState:FireClient(player, "ORDER_HINT", { id = id, needCook = true }); return false
	end
	if not PrepSystem:IsReady(player, id) then
		MatchState:FireClient(player, "ORDER_HINT", { id = id, needPrep = true }); return false
	end
	-- ✅ 托盤檢查（角色屬性或裝備 Tool 名稱 "Tray"）
	local hasTray = (player.Character and player.Character:GetAttribute("Tray")) == true
	if not hasTray then
		local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
		if tool and tool.Name == "Tray" then hasTray = true end
	end
	if not hasTray then
		MatchState:FireClient(player, "ORDER_HINT", { id = id, needTray = true }); return false
	end

	if Recipes.Validate(order.recipe, payload.ingredients) then
		local score = CookSystem:GetScore(player, id) or 0
		local tip   = (order.recipe.tipBase or 0) + (score * 5)

		activeOrders[id] = nil
		if activeByOwner[uid] == id then activeByOwner[uid] = nil end
		CookSystem:Clear(player)
		PrepSystem:Reset(player)
		if player.Character then player.Character:SetAttribute("Tray", false) end

		print(("[OrderSystem] SUBMIT OK %s tip=%d score=%d"):format(id, tip, score))
		return true, tip
	end
	return false
end

function OrderSystem:GetActiveFor(player)
	local id = activeByOwner[player.UserId]
	return id and activeOrders[id] or nil
end

return OrderSystem