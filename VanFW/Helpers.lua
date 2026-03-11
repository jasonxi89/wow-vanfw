local VanFW = VanFW

function VanFW:GetBestAOEPosition(enemies, radius)
  local bestPos = nil
  local bestCount = 0
  
  for _, enemy in ipairs(enemies) do
    local x, y, z = enemy:Position()
    if x then
      local count = 0
      
      for _, other in ipairs(enemies) do
        if enemy ~= other then
          local dist = enemy:DistanceTo(other)
          if dist <= radius then
            count = count + 1
          end
        end
      end
      
      if count > bestCount then
        bestCount = count
        bestPos = {x, y, z}
      end
    end
  end
  
  return bestPos, bestCount + 1
end


function VanFW:HasTalent(spellID)
  if not spellID then return false end
  if IsPlayerSpell and IsPlayerSpell(spellID) then
    return true
  end
  if IsSpellKnown and IsSpellKnown(spellID) then
    return true
  end
  return false
end


function VanFW:FaceTarget(target)
  if not target then return end
  
  local x1, y1 = self:PlayerPosition()
  local x2, y2 = target:Position()
  
  if not x1 or not x2 then return end
  
  local angle = math.atan2(y2 - y1, x2 - x1)
  self.SetFacing(angle)
end


function VanFW:GetInterruptibleEnemy(range)
  range = range or 40
  
  for _, enemy in ipairs(self:GetEnemiesInRange(range)) do
    if enemy:IsCasting() or enemy:IsChanneling() then
      if enemy:IsInterruptible() then
        return enemy
      end
    end
  end
  
  return nil
end


function VanFW:TimeInCombat()
  return self.combatDuration
end

function VanFW:IsAOESituation(count, range)
  count = count or 3
  range = range or 8
  
  return self:GetEnemiesInRangeCount(range) >= count
end


function VanFW:IsPlayerFacing(target, angle)
  if not self.player or not target then return false end
  return self.player:IsFacing(target, angle or math.pi)
end


function VanFW:InMeleeRange(target)
  target = target or self.target
  if not target then return false end
  
  return self.player:MeleeRange(target)
end


function VanFW:PredictPosition(object, time)
  return object:PredictPosition(time)
end

function VanFW.Distance(x1, y1, z1, x2, y2, z2)
  if z1 and z2 then
    return VanFW:Distance3D(x1, y1, z1, x2, y2, z2)
  else
    return VanFW:Distance2D(x1, y1, x2, y2)
  end
end

function VanFW.AnglesBetween(x1, y1, z1, x2, y2, z2)
  return math.atan2(y2 - y1, x2 - x1)
end

function VanFW.PositionBetween(x1, y1, z1, x2, y2, z2, dist)
  local totalDist = VanFW:Distance3D(x1, y1, z1, x2, y2, z2)
  if totalDist == 0 then return x1, y1, z1 end

  local ratio = dist / totalDist
  return x1 + (x2 - x1) * ratio,
         y1 + (y2 - y1) * ratio,
         z1 + (z2 - z1) * ratio
end

function VanFW.GroundZ(x, y, z)
  -- needs Implement ground Z lookup
  return z
end

function VanFW.TraceLine(x1, y1, z1, x2, y2, z2, flags)
  flags = flags or VanFW.LOSFlags.Standard
  return VanFW.VisCheck(x1, y1, z1, x2, y2, z2, flags)
end

VanFW.healer = nil
VanFW.enemyHealer = nil

function VanFW.canBeInterrupted(elapsed)
  elapsed = elapsed or 0.5

  for _, enemy in ipairs(VanFW.objects.enemies or {}) do
    if enemy:casting() or enemy:channeling() then
      local remains = enemy:casting() and enemy:castRemains() or enemy:channelRemains()
      if remains > elapsed and enemy:castint() then
        return true, enemy
      end
    end
  end

  return false, nil
end

function VanFW.los(unit, otherUnit)
  if not unit or not otherUnit then return false end
  return unit:los(otherUnit)
end

function VanFW.losCoords(unit, x, y, z)
  if not unit then return false end

  local ux, uy, uz = unit:position()
  if not ux or not x then return false end

  return VanFW.TraceLine(ux, uy, uz + 2, x, y, z + 2) == 0
end

function VanFW.UnitIsFacingUnit(unit, otherUnit, angle)
  if not unit or not otherUnit then return false end
  return unit:facing(otherUnit, angle)
end

function VanFW.UnitIsFacingPosition(unit, x, y, z, angle)
  if not unit or not x then return false end

  local ux, uy, uz = unit:position()
  if not ux then return false end

  local facing = unit:rotation()
  local targetAngle = math.atan2(y - uy, x - ux)

  angle = angle or math.pi / 2
  local diff = math.abs(facing - targetAngle)

  if diff > math.pi then
    diff = 2 * math.pi - diff
  end

  return diff <= angle
end