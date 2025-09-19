-- ServerScriptService/Systems/CookNetwork.server.luau
-- 安全轉接 CookStep RemoteFunction → CookSystem，加入參數檢查與錯誤保護

local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Remotes    = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local CookStepRF = Remotes.CookStep

local Systems     = SSS:WaitForChild("Systems")
local CookSystem  = require(Systems:WaitForChild("CookSystem"))

local function ok_or_err(call)
	local ok, a, b, c = pcall(call)
	if ok then return a, b, c end
	warn("[CookNetwork] exception:", a)
	return nil, "EXCEPTION"
end

CookStepRF.OnServerInvoke = function(player, payload)
	if type(payload) ~= "table" then return nil, "BAD_PAYLOAD" end
	local op = payload.op

	if op == "start" then
		-- payload.orderId: any; payload.recipe: table
		if type(payload.recipe) ~= "table" then return nil, "BAD_RECIPE" end
		return ok_or_err(function()
			return CookSystem:Start(player, { orderId = payload.orderId, recipe = payload.recipe })
		end)

	elseif op == "step" then
		-- payload.t: number in [0,1]（允許微出界，這裡做基本檢查）
		local t = tonumber(payload.t)
		if t == nil then return nil, "BAD_T" end
		--（若需要嚴格限制可啟用以下兩行）
		-- if t < 0 or t > 1 then return nil, "OUT_OF_RANGE" end
		return ok_or_err(function()
			return CookSystem:SubmitStep(player, t)
		end)

	elseif op == "cancel" then
		local ok, err = pcall(function()
			CookSystem:Clear(player)
		end)
		if not ok then
			warn("[CookNetwork] cancel exception:", err)
			return nil, "EXCEPTION"
		end
		return true
	end

	return nil, "BAD_OP"
end

print("[CookNetwork] ready")