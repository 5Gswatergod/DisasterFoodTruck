local Recipes = {}
Recipes.list = {
  Burger = { id='Burger', name='漢堡', level=1, tipBase=50,
    ingredients={'Bun','Lettuce','PattyRaw'},
    steps={ {kind='Grab', item='Bun', window=0.35},
            {kind='Chop', item='Lettuce', time=1.2, window=0.35},
            {kind='Cook', item='PattyRaw', to='Patty', time=3.0, window=0.4},
            {kind='Assemble', items={'Bun','Lettuce','Patty'}, window=0.4} } },
  Hotdog = { id='Hotdog', name='熱狗', level=1, tipBase=40,
    ingredients={'Bun','SausageRaw'},
    steps={ {kind='Cook', item='SausageRaw', to='Sausage', time=2.4, window=0.45},
            {kind='Assemble', items={'Bun','Sausage'}, window=0.4} } },
}
function Recipes.GetRandom(profile, mapId) return Recipes.list.Burger end
function Recipes.Validate(recipe, submitted)
  local need = {}
  for _,v in ipairs(recipe.ingredients) do need[v]=true end
  for _,v in ipairs(submitted) do need[v]=nil end
  for _,v in pairs(need) do if v then return false end end
  return true
end
return Recipes
