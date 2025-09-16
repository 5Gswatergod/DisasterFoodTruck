local Missions = {}

Missions.daily = {
  {id='D_Serve10', text='上菜 10 份', req=10, reward={coins=150}},
  {id='D_Perfect5', text='完美 QTE 5 次', req=5, reward={coins=120}},
  {id='D_Dodge3', text='成功躲避災難 3 次', req=3, reward={gems=5}},
}

Missions.weekly = {
  {id='W_MapMaster_Beach', text='海灘地圖完成 5 局', req=5, reward={gems=20}},
  {id='W_NoHit', text='無受傷完成 1 局', req=1, reward={coins=500}},
}

Missions.seasonPass = {
  tiers=50,
  rewards={
    [1]={free={coins=200}, paid={cos='Sticker_Star'}},
    [10]={free={gems=10}, paid={cos='TruckSkin_Neon'}},
    [25]={free={coins=800}, paid={emote='Emote_PoseA'}},
    [50]={free={title='餐車新星'}, paid={title='災難主廚'}}
  }
}

return Missions
