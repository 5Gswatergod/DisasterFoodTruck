--!strict
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local R   = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local Interact = R.Interact

local Systems    = SSS:WaitForChild("Systems")
local PrepSystem = require(Systems:WaitForChild("PrepSystem"))

local function setTrayPlateFlag(player: Player, has: boolean)
	local char = player.Character
	if not char then return end
	local tool = char:FindFirstChildOfClass("Tool")
	if tool and tool.Name == "ServingTray" then
		tool:SetAttribute("HasPlate", has and true or false)
	end
end

local function toStepName(field: string?): string?
	if not field then return nil end
	local f = string.lower(field)
	if f == "pickup" then return "Pickup" end
	if f == "cut"    then return "Cut"    end
	if f == "cook"   then return "Cook"   end
	if f == "plate"  then return "Plate"  end
	if f == "deliver"then return "Deliver"end
	return nil
end

Interact.OnServerEvent:Connect(function(player: Player, payload: any)
	if type(payload) ~= "table" then return end

	if payload.op == "mark" then
		local step = toStepName(payload.field)
		if not step then return end
		-- 長按已在用戶端完成，這裡直接開始→完成
		PrepSystem.StartStep(player, step, { station = payload.station })
		PrepSystem.CompleteStep(player)
		if step == "Plate" then
			setTrayPlateFlag(player, true)
		end

	elseif payload.op == "reset" then
		PrepSystem.ResetOnRespawn(player)
		setTrayPlateFlag(player, false)
	end
end)

print("[Interact] ready")
