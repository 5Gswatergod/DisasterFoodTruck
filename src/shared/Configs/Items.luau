-- ReplicatedStorage/Shared/Configs/Items.luau
--!strict
-- 定義各項物品流程屬性（是否需要切/煮、切/煮後的成品）
-- 也提供查詢輔助函式，方便其他系統（FlowDirector / CarrySystem / CookSystem）使用

export type ItemDef = {
	id: string,
	displayName: string?,
	category: string?,     -- "Veg","Meat","Dairy","Drink","Bread"...
	needCut: boolean?,
	needCook: boolean?,
	cutResult: string?,    -- 切完得到什麼
	cookResult: string?,   -- 煮完得到什麼
}

local Items: {[string]: ItemDef} = {
	-- === 蔬菜 ===
	Lettuce = {
		id = "Lettuce",
		displayName = "生菜",
		category = "Veg",
		needCut = true,
		cutResult = "LettuceChopped",
	},

	LettuceChopped = {
		id = "LettuceChopped",
		displayName = "切碎生菜",
		category = "Veg",
	},

	-- === 肉類 ===
	PattyRaw = {
		id = "PattyRaw",
		displayName = "生肉排",
		category = "Meat",
		needCook = true,
		cookResult = "Patty",
	},

	Patty = {
		id = "Patty",
		displayName = "熟肉排",
		category = "Meat",
	},

	-- === 麵包 ===
	Bun = {
		id = "Bun",
		displayName = "麵包",
		category = "Bread",
	},

	-- === 飲品材料 ===
	Milk = {
		id = "Milk",
		displayName = "牛奶",
		category = "Dairy",
	},

	Ice = {
		id = "Ice",
		displayName = "冰塊",
		category = "Drink",
	},

	Syrup = {
		id = "Syrup",
		displayName = "糖漿",
		category = "Drink",
	},
}

-- 讓 CarrySystem 能把切/煮流程轉成實際成品
Items.ResultAfterCut = {
	Lettuce   = "LettuceChopped",
	PattyRaw  = "PattyCut",
	-- 其他食材依你需求擴充
}

Items.ResultAfterCook = {
	PattyCut      = "PattyCooked",
	PattyRaw      = "PattyCooked", -- 若允許直接煎生肉
	LettuceChopped= "LettuceChopped", -- 不變也可省略
}

-- ===== Helpers =====

local M = {}

function M.Get(id: string): ItemDef?
	return Items[id]
end

function M.NeedsCut(id: string): boolean
	local def = Items[id]
	return (def and def.needCut) == true
end

function M.NeedsCook(id: string): boolean
	local def = Items[id]
	return (def and def.needCook) == true
end

function M.ResultAfterCut(id: string): string?
	local def = Items[id]
	return def and def.cutResult or nil
end

function M.ResultAfterCook(id: string): string?
	local def = Items[id]
	return def and def.cookResult or nil
end

-- 你之後也可以擴充：
-- function M.CanPlate(id: string): boolean ...（若有些東西不能直接上盤）
-- function M.DisplayName(id: string): string ...（處理預設顯示名）

return M