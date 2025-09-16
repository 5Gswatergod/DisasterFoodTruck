local Disasters = {}

Disasters.pool = {
  {id='MeteorShower', name='流星雨', duration=18, weight=2, noRepeat=true,
   serverEffects={spawnMeteors=14, damage=25}, clientFX={shake=1.2, warn='SFX/Meteor'}},
  {id='LowGravity', name='低重力', duration=20, weight=3,
   serverEffects={gravityScale=0.45}, clientFX={post='LowSat'}},
  {id='StrongWind', name='逆風', duration=22, weight=3,
   serverEffects={windForce=35}, clientFX={vfx='WindLines'}},
  {id='FloorIsLava', name='地板熔岩', duration=16, weight=2,
   serverEffects={safeIslands=6}, clientFX={vfx='Heat'}},
}

local lastId = nil
function Disasters.GetRandom()
  local pool = {}
  for _,d in ipairs(Disasters.pool) do
    if not(d.noRepeat and d.id==lastId) then
      for i=1,(d.weight or 1) do table.insert(pool, d) end
    end
  end
  local pick = pool[math.random(1,#pool)]
  lastId = pick.id
  return pick
end

function Disasters.ApplyServerEffects(d)
  -- TODO: implement per disaster
end
function Disasters.ClearServerEffects(d)
  -- TODO: restore scene
end

return Disasters
