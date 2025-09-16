local Items = {}

Items.Ingredients = {
  Bun={stack=8}, Lettuce={stack=6}, PattyRaw={}, SausageRaw={}, PotatoRaw={}, Oil={},
  Milk={}, Ice={}, Syrup={}, Batter={}, Octopus={}, Sauce={}, Noodles={}, Cabbage={}
}

Items.Appliances = {
  Grill={id='Grill', speed=1.0, upgradable=true},
  Fryer={id='Fryer', speed=1.0, upgradable=true},
  Mixer={id='Mixer', speed=1.0, upgradable=false}
}

Items.Upgrades = {
  BackpackSlots_+4={id='BackpackSlots_+4', kind='INV', value=4, price=500},
  CookSpeed_+10p={id='CookSpeed_+10p', kind='BUFF', value=0.1, duration=180, gem=80},
  TruckSkin_Neon={id='TruckSkin_Neon', kind='COS', price=1200},
  Emote_PoseA={id='Emote_PoseA', kind='EMOTE', price=300}
}

return Items
