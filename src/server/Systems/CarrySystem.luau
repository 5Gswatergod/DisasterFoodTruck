local Carry = {}
local S = {}  -- uid -> { carry:string?, plate:{string}, started:boolean }

local function ensure(uid)
	if not S[uid] then S[uid] = { carry=nil, plate={}, started=false } end
	return S[uid]
end

function Carry:Pickup(player, itemId:string)
	local st = ensure(player.UserId)
	if st.carry then return false, "HANDS_FULL" end
	st.carry = itemId
	return true
end

function Carry:StartPlate(player)
	local st = ensure(player.UserId); st.started = true; return true
end

function Carry:PlaceOnPlate(player)
	local st = ensure(player.UserId)
	if not st.started then st.started = true end
	if not st.carry then return false, "NO_CARRY" end
	table.insert(st.plate, st.carry)
	st.carry = nil
	return true
end

local function countify(list:{string})
	local t = {}
	for _,v in ipairs(list or {}) do t[v] = (t[v] or 0) + 1 end
	return t
end

function Carry:IsPlateComplete(player, required:{string})
	local st = S[player.UserId]; if not st or not st.started then return false end
	local need = countify(required or {})
	local have = countify(st.plate or {})
	for k,n in pairs(need) do if (have[k] or 0) < n then return false end end
	return true
end

function Carry:Get(player) return S[player.UserId] end
function Carry:Clear(player) S[player.UserId] = nil end

return Carry