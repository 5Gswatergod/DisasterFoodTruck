local RS         = game:GetService("ReplicatedStorage")
local R          = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local MatchState = R.MatchState
local Recipes = require(RS:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("Recipes"))

local SSS        = game:GetService("ServerScriptService")
local Systems    = SSS:WaitForChild("Systems")
local CookSystem = require(Systems:WaitForChild("CookSystem"))
local PrepSystem = require(Systems:WaitForChild("PrepSystem"))
local PlayerData = require(Systems:WaitForChild("PlayerData"))
local FlowApi: any = nil

-- Optional guard helpers
local function safeCall(obj, method, ...): (boolean, any?)
	if obj and type(obj[method]) == "function" then
		local ok, res = pcall(obj[method], obj, ...)
		if not ok then warn("[OrderSystem] "..method.." failed:", res) end
		return ok, res
	end
	return false, nil
end

-- If your design no longer requires a tray, set to false
local REQUIRE_TRAY = false

local OrderSystem = {}
local activeOrders  = {}
local activeByOwner = {}  -- uid -> orderId

function OrderSystem.Init(flowDirectorApi: any)
	FlowApi = flowDirectorApi
end

function OrderSystem.SpawnOrder(forPlayer: Player, profile: any?, mapId: string?)
	-- 防呆：基礎參數
	profile = profile or { Level = 1 }
	if typeof(profile) ~= "table" then
		profile = { Level = tonumber(profile) or 1 }
	end
	profile.Level = profile.Level or 1
	mapId = tostring(mapId or (workspace:GetAttribute("MapId") or "Beach"))

	-- 使用 Recipes API 挑選配方（已內含權重/等級門檻/主題解析）
	local r = Recipes.GetRandom(profile, mapId)
	if not r then
		-- 萬一未來改壞也不會崩：退回池子直接抽
		local _, pool = Recipes.GetPool(mapId)
		if type(pool) == "table" and #pool > 0 then
			r = pool[math.random(1, #pool)]
		end
	end

	if not r then
		warn(("[OrderSystem] SpawnOrder: recipe is nil (mapId=%s, level=%s)"):format(mapId, tostring(profile.Level)))
		return nil
	end


	-- 產生訂單 id
	local HttpService = game:GetService("HttpService")
	local id = r.id or ("ORD_" .. HttpService:GenerateGUID(false))

	-- 註冊訂單到活躍表
	activeOrders[id] = {
		id = id,
		owner = forPlayer.UserId,
		recipe = r,
		mapId = mapId,
		level = profile.Level,
		created = os.clock(),
	}
	activeByOwner[forPlayer.UserId] = id

	-- 綁定到 PrepSystem（若有對應 API）
	safeCall(PrepSystem, "SetOrder", forPlayer, id)

	-- 發送給 UI
	if MatchState then
		MatchState:FireClient(forPlayer, "NEW_ORDER", { id = id, recipe = r })
	end

	print(("[OrderSystem] NEW_ORDER %s for %s (map=%s, level=%s)"):format(id, forPlayer.Name, mapId, tostring(profile.Level)))

	-- 通知流程（依注入 API，兼容 Push / PushNext）
	if FlowApi then
		if type(FlowApi.Push) == "function" then
			FlowApi:Push(forPlayer)
		elseif type(FlowApi.PushNext) == "function" then
			FlowApi:PushNext(forPlayer)
		end
	end

	return id
end

function OrderSystem:Submit(player, payload)
	if type(payload) ~= "table" then return false end
	local uid, id = player.UserId, payload.id
	local order = id and activeOrders[id]
	if not order or order.owner ~= uid then return false end

	-- 必須完成 QTE & 備料三步（若對應 API 缺失則視為通過）
	local okCook, cookComplete = safeCall(CookSystem, "IsComplete", player, id)
	if okCook and not cookComplete then
		MatchState:FireClient(player, "ORDER_HINT", { id = id, needCook = true }); return false
	end

	local okPrep, prepReady = safeCall(PrepSystem, "IsReady", player, id)
	if okPrep and not prepReady then
		MatchState:FireClient(player, "ORDER_HINT", { id = id, needPrep = true }); return false
	end

	-- ✅ 托盤檢查（根據旗標允不允許）
	if REQUIRE_TRAY then
		local hasTray = (player.Character and player.Character:GetAttribute("Tray")) == true
		if not hasTray then
			local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
			if tool and tool.Name == "Tray" then hasTray = true end
		end
		if not hasTray then
			MatchState:FireClient(player, "ORDER_HINT", { id = id, needTray = true }); return false
		end
	end

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
	if FlowApi then
		if type(FlowApi.Push) == "function" then
			FlowApi:Push(player)
		elseif type(FlowApi.PushNext) == "function" then
			FlowApi:PushNext(player)
		end
	end
	return false
end

function OrderSystem:GetActiveFor(player)
	local id = activeByOwner[player.UserId]
	return id and activeOrders[id] or nil
end

return OrderSystem