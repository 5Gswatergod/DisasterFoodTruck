-- ReplicatedStorage/Shared/Configs/Recipes.luau
-- 依地圖風情（theme）選菜單；支援權重、等級門檻與驗證

local Recipes = {}

-- 主題菜單（示例：盡量沿用你現有食材：Bun/Lettuce/PattyRaw、Milk/Ice/Syrup）
local POOLS = {
	Beach = {
		{ id="ShavedIce",   name="海風剉冰",    ingredients={"Milk","Ice","Syrup"}, tipBase=45, cuisine="Dessert", tier=1, weight=5 },
		{ id="SeasideBurger", name="海邊漢堡",  ingredients={"Bun","PattyRaw","Lettuce"}, tipBase=55, cuisine="Grill", tier=1, weight=4 },
	},
	City = {
		{ id="ClassicBurger", name="經典漢堡",  ingredients={"Bun","PattyRaw","Lettuce"}, tipBase=50, cuisine="Grill", tier=1, weight=6 },
		{ id="DoubleBurger",  name="雙層漢堡",  ingredients={"Bun","PattyRaw","PattyRaw","Lettuce"}, tipBase=80, cuisine="Grill", tier=2, weight=2 },
	},
	Forest = {
		{ id="GreenSalad",   name="森野沙拉",    ingredients={"Lettuce","Lettuce"}, tipBase=40, cuisine="Salad", tier=1, weight=4 },
		{ id="MushroomToast",name="菇菇吐司",    ingredients={"Bun","Lettuce"}, tipBase=42, cuisine="Basic", tier=1, weight=3 },
	},
	Snow = {
		{ id="HotCocoa",     name="熱可可",      ingredients={"Milk","Syrup"}, tipBase=45, cuisine="Dessert", tier=1, weight=5 },
		{ id="SnowBurger",   name="暖心堡",      ingredients={"Bun","PattyRaw"}, tipBase=48, cuisine="Grill", tier=1, weight=3 },
	},
	Desert = {
		{ id="SpicedMilkTea",name="香料奶茶",    ingredients={"Milk","Syrup"}, tipBase=40, cuisine="Basic", tier=1, weight=4 },
		{ id="DryBurger",    name="沙丘漢堡",    ingredients={"Bun","PattyRaw","Lettuce"}, tipBase=52, cuisine="Grill", tier=1, weight=3 },
	},
	-- 後備（地圖沒對上就用這組）
	Default = {
		{ id="HouseBurger",  name="招牌漢堡",    ingredients={"Bun","PattyRaw","Lettuce"}, tipBase=50, cuisine="Grill", tier=1, weight=6 },
		{ id="IcedMilk",     name="冰奶",        ingredients={"Milk","Ice","Syrup"}, tipBase=42, cuisine="Dessert", tier=1, weight=4 },
	}
}

-- 將 mapId/地圖名對應到主題；可自行擴充關鍵字
local function resolveTheme(mapId: any): string
	local s = string.lower(tostring(mapId or ""))
	if s:find("beach") or s:find("island")   then return "Beach"  end
	if s:find("city")  or s:find("urban")    then return "City"   end
	if s:find("forest")or s:find("wood")     then return "Forest" end
	if s:find("snow")  or s:find("ice")      then return "Snow"   end
	if s:find("desert")or s:find("sand")     then return "Desert" end
	return "Default"
end

-- 等級門檻：tier 1 全部可出； tier 2 建議 Lv≥4 才加入池子（你可調）
local function levelAllows(tier: number, level: number)
	level = level or 1
	if tier <= 1 then return true end
	return level >= (tier*3 + 1)  -- 例：tier2 需要 ~Lv4、tier3 需要 ~Lv7
end

-- 權重抽樣
local function weightedPick(list)
	local sum = 0
	for _, r in ipairs(list) do sum += (r.weight or 1) end
	local t = math.random() * sum
	local acc = 0
	for _, r in ipairs(list) do
		acc += (r.weight or 1)
		if t <= acc then return r end
	end
	return list[1]
end

function Recipes.GetPool(mapId: any)
	local theme = resolveTheme(mapId)
	return theme, POOLS[theme] or POOLS.Default
end

function Recipes.GetRandom(profile, mapId: any)
	local level = (profile and profile.Level) or 1
	local theme, pool = Recipes.GetPool(mapId)
	local candidates = {}
	for _, r in ipairs(pool) do
		if levelAllows(r.tier or 1, level) then
			table.insert(candidates, r)
		end
	end
	if #candidates == 0 then candidates = pool end
	local pick = weightedPick(candidates)
	-- 附帶 theme 方便 UI 想顯示
	local clone = table.clone(pick)
	clone.theme = theme
	return clone
end

-- 驗證：忽略順序，支援重複項（例如雙層肉）
local function countify(arr)
	local m = {}
	for _, v in ipairs(arr or {}) do m[v] = (m[v] or 0) + 1 end
	return m
end

function Recipes.Validate(recipe, ingredients)
	if not recipe or not recipe.ingredients then return false end
	local need = countify(recipe.ingredients)
	local have = countify(ingredients)
	for k, n in pairs(need) do
		if (have[k] or 0) < n then return false end
	end
	return true
end

return Recipes
