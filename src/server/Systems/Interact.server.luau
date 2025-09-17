local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local R   = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local Interact = R.Interact

local Systems     = SSS:WaitForChild("Systems")
local PrepSystem  = require(Systems:WaitForChild("PrepSystem"))

local function setTrayPlateFlag(player, has)
    local char = player.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and tool.Name == "ServingTray" then
        tool:SetAttribute("HasPlate", has and true or false)
    end
end

Interact.OnServerEvent:Connect(function(player, payload)
    if type(payload) ~= "table" then return end
    if payload.op == "mark" then
        local field, orderId = payload.field, payload.orderId
        local o = PrepSystem:Mark(player, orderId, field)
        if field == "plate" then
            setTrayPlateFlag(player, true)
        end
    elseif payload.op == "reset" then
        PrepSystem:Reset(player)
        setTrayPlateFlag(player, false)
    end
end)

print("[Interact] ready")