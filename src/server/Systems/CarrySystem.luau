--!strict
-- CarrySystem.luau
-- 管玩家「手上拿著什麼」的最小系統，並支援切/煮後的食材轉換

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local Items   = require(RS:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("Items"))

export type CarryState = {
	carry: string?, -- 例：Lettuce / PattyRaw / PattyCut / PattyCooked ...
}

local CarrySystem = {}
local _byPlayer: {[Player]: CarryState} = {}

local function ensure(p: Player): CarryState
	local st = _byPlayer[p]
	if not st then
		st = { carry = nil }
		_byPlayer[p] = st
	end
	return st
end

-- ===== 外部介面 =====

function CarrySystem:Get(p: Player): CarryState
	return ensure(p)
end

function CarrySystem:Peek(p: Player): string?
	local st = _byPlayer[p]
	return st and st.carry or nil
end

function CarrySystem:Pickup(p: Player, itemId: string): (boolean, string?)
	if type(itemId) ~= "string" or itemId == "" then
		return false, "BAD_ITEM"
	end
	local st = ensure(p)
	st.carry = itemId
	return true, itemId
end

function CarrySystem:PlaceOnPlate(p: Player): (string?)
	local st = ensure(p)
	local prev = st.carry
	st.carry = nil
	return prev
end

function CarrySystem:Clear(p: Player): ()
	local st = ensure(p)
	st.carry = nil
end

function CarrySystem:ApplyCut(p: Player): (boolean, string?, boolean)
	local st = ensure(p)
	if not st.carry then return false, nil, false end
	local out = Items.ResultAfterCut and Items.ResultAfterCut[st.carry]
	if out and type(out) == "string" then
		st.carry = out
		return true, out, true
	end
	return true, st.carry, false
end

function CarrySystem:ApplyCook(p: Player): (boolean, string?, boolean)
	local st = ensure(p)
	if not st.carry then return false, nil, false end
	local out = Items.ResultAfterCook and Items.ResultAfterCook[st.carry]
	if out and type(out) == "string" then
		st.carry = out
		return true, out, true
	end
	return true, st.carry, false
end

Players.PlayerRemoving:Connect(function(p)
	_byPlayer[p] = nil
end)

return CarrySystem