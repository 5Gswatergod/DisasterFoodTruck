local Disasters = {}

-- 權重越高越常出現；noRepeat 防止連續相同
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

local lastId: string? = nil
local rng = Random.new(os.clock())

function Disasters.GetRandom()
  local function buildPool(blockId: string?): {any}
    local pool = {}
    for _, d in ipairs(Disasters.pool) do
      local skip = (blockId ~= nil) and d.noRepeat and (d.id == blockId)
      if not skip then
        local w = math.max(1, math.floor(d.weight or 1))
        for i = 1, w do table.insert(pool, d) end
      end
    end
    return pool
  end

  -- 第一次嘗試：遵守 noRepeat
  local pool = buildPool(lastId)
  -- 若因 noRepeat 造成空池，放寬限制再抽
  if #pool == 0 then
    pool = buildPool(nil)
  end
  assert(#pool > 0, "[Disasters] pool is empty")

  local pick = pool[rng:NextInteger(1, #pool)]
  lastId = pick.id
  return table.clone(pick)
end

function Disasters.ApplyServerEffects(d)
  -- TODO: 依 d.serverEffects 觸發伺服端效果（如改變重力/生成流星）
end
function Disasters.ClearServerEffects(d)
  -- TODO: 還原場景狀態與物理參數
end

return Disasters