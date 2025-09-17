local RS   = game:GetService("ReplicatedStorage")
local R    = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
local FlowHint = R.FlowHint

local SSS  = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")
local PrepSystem  = require(Systems:WaitForChild("PrepSystem"))
local OrderSystem = require(Systems:WaitForChild("OrderSystem"))

local FlowDirector = {}

-- 可調順序：優先顯示哪個步驟（預設：先煮→切→裝盤→送餐）
local PRIORITY = {"cook","cut","plate","deliver"}

local TAG_OF = {
	cut     = "Station_Cut",
	cook    = "Station_Cook",
	plate   = "Station_Plate",
	deliver = "Station_Deliver",
}

-- 計算目前只允許哪個站點（回傳 tags: { "Station_Cook" } 之類）
function FlowDirector:AllowedTagsFor(player)
	local order = OrderSystem:GetActiveFor(player)
	if not order then return {} end
	local st = (type(PrepSystem.Get)=="function" and PrepSystem.Get(PrepSystem, player))
           or {cut=false,cook=false,plate=false}

	for _,step in ipairs(PRIORITY) do
		if step == "cut"     and not st.cut   then return { TAG_OF.cut } end
		if step == "cook"    and not st.cook  then return { TAG_OF.cook } end
		if step == "plate"   and not st.plate then return { TAG_OF.plate } end
		if step == "deliver" and (st.cut and st.cook and st.plate) then
			return { TAG_OF.deliver }
		end
	end
	return {}
end

function FlowDirector:Push(player)
	local tags = self:AllowedTagsFor(player)
	FlowHint:FireClient(player, {allowed = tags})
end

return FlowDirector
