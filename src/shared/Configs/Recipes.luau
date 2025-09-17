local Recipes = {}

Recipes.list = {
  Burger = {
    id='Burger', name='漢堡', level=1, map=nil, tipBase=50,
    ingredients={'Bun','Lettuce','PattyRaw'},
    steps={
      {kind='Grab', item='Bun'},
      {kind='Chop', item='Lettuce', time=1.2, window=0.35},
      {kind='Cook', item='PattyRaw', to='Patty', time=3.0, window=0.4},
      {kind='Assemble', items={'Bun','Lettuce','Patty'}}
    }
  },
  Hotdog = {
    id='Hotdog', name='熱狗', level=1, tipBase=40,
    ingredients={'Bun','SausageRaw'},
    steps={
      {kind='Cook', item='SausageRaw', to='Sausage', time=2.4, window=0.45},
      {kind='Assemble', items={'Bun','Sausage'}}
    }
  },
  Fries = {
    id='Fries', name='薯條', level=2, tipBase=35,
    ingredients={'PotatoRaw','Oil'},
    steps={
      {kind='Chop', item='PotatoRaw', to='PotatoCuts', time=1.0, window=0.3},
      {kind='Fry', item='PotatoCuts', to='Fries', oil='Oil', time=2.2, window=0.3}
    }
  },
  Milkshake = {
    id='Milkshake', name='奶昔', level=2, tipBase=45,
    ingredients={'Milk','Ice','Syrup'},
    steps={{kind='Mix', items={'Milk','Ice','Syrup'}, time=1.6, window=0.35}}
  },
  Takoyaki = {
    id='Takoyaki', name='章魚燒', level=3, map='NightMarket', tipBase=80,
    ingredients={'Batter','Octopus','Sauce'},
    steps={
      {kind='Pour', item='Batter'},
      {kind='Cook', item='Batter', to='TakoyakiBalls', time=6.0, window=0.3},
      {kind='Top', item='Sauce'}
    }
  },
  Yakisoba = {
    id='Yakisoba', name='炒麵', level=3, map='NightMarket', tipBase=70,
    ingredients={'Noodles','Cabbage','Sauce'},
    steps={
      {kind='Stirfry', items={'Noodles','Cabbage'}, time=3.2, window=0.35},
      {kind='Top', item='Sauce'}
    }
  }
}

-- 依玩家等級及地圖權重挑食譜
function Recipes.GetRandom(profile, mapId)
  local pool = {}
  for _, r in pairs(Recipes.list) do
    if (not r.map or r.map==mapId) and r.level <= (profile.Level or 1)+1 then
      table.insert(pool, r)
    end
  end
  if #pool==0 then pool = {Recipes.list.Burger} end
  return pool[math.random(1,#pool)]
end

-- 驗證配方與 QTE（簡化版）
function Recipes.Validate(recipe, submitted)
  local need = {}
  for _,v in ipairs(recipe.ingredients) do need[v]=true end
  for _,v in ipairs(submitted) do need[v]=nil end
  for _,v in pairs(need) do if v then return false end end
  return true
end

return Recipes