local PrepSystem = {}

-- 訂單為核心（支援多人分工）
-- orders[orderId] = { cut=false,cook=false,plate=false, team = { [uid]=true, ... } }
local orders = {}
local orderByPlayer = {} -- uid -> orderId

local function ensureOrder(orderId)
    orders[orderId] = orders[orderId] or { cut=false, cook=false, plate=false, team = {} }
    return orders[orderId]
end

function PrepSystem:SetOrder(player, orderId)
    local uid = player.UserId
    orderByPlayer[uid] = orderId
    local o = ensureOrder(orderId)
    o.team[uid] = true
    return o
end

function PrepSystem:Mark(player, orderId, field)
    local uid = player.UserId
    orderId = orderId or orderByPlayer[uid]; if not orderId then return nil, "NO_ORDER" end
    local o = ensureOrder(orderId)
    o.team[uid] = true
    if field == "cut" then o.cut = true
    elseif field == "cook" then o.cook = true
    elseif field == "plate" then o.plate = true end
    return o
end

function PrepSystem:IsReadyById(orderId)
    local o = orders[orderId]; if not o then return false end
    return o.cut and o.cook and o.plate
end

function PrepSystem:IsReady(player, orderId)
    orderId = orderId or orderByPlayer[player.UserId]
    if not orderId then return false end
    return self:IsReadyById(orderId)
end

function PrepSystem:Reset(player)
    local uid = player.UserId
    orderByPlayer[uid] = nil
end

function PrepSystem:ClearOrder(orderId)
    orders[orderId] = nil
    for uid, oid in pairs(orderByPlayer) do if oid == orderId then orderByPlayer[uid] = nil end end
end

return PrepSystem