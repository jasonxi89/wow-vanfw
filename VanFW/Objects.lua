local VanFW = VanFW
local GetTime = _G.GetTime
local UnitCastingInfo = _G.UnitCastingInfo
local UnitChannelInfo = _G.UnitChannelInfo

local C_UnitAuras = _G.C_UnitAuras
local C_UnitAuras_GetBuffDataByIndex = C_UnitAuras and C_UnitAuras.GetBuffDataByIndex
local C_UnitAuras_GetDebuffDataByIndex = C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex
local UnitAura = _G.UnitAura
local UnitDebuff = _G.UnitDebuff
local math_max = math.max
local math_min = math.min


local GetObjectCount = VanFW.GetObjectCount
local GetObjectWithIndex = VanFW.GetObjectWithIndex
local ObjectType = VanFW.ObjectType
local ObjectGUID = VanFW.ObjectGUID
local ObjectPos = VanFW.ObjectPos
local GetFacing = VanFW.GetFacing
local ObjectCombatReach = VanFW.ObjectCombatReach
local ObjectBoundingRadius = VanFW.ObjectBoundingRadius
local VisCheck = VanFW.VisCheck


VanFW.objects = {
  all = {},
  enemies = {},
  friends = {},
  players = {},
  npcs = {},
  units = {},
  byGUID = {},
}

VanFW.objectCount = 0
VanFW.lastObjectUpdate = 0


local Object = {}
Object.__index = Object

local ObjectPool = {}
local poolSize = 0

local function AcquireObject(pointer, token)
  local obj
  if poolSize > 0 then
    obj = ObjectPool[poolSize]
    ObjectPool[poolSize] = nil
    poolSize = poolSize - 1
    obj.pointer = pointer
    obj.token = token
    local success, guid = pcall(ObjectGUID, pointer)
    obj._guid = (success and guid) or ""
    local success2, objType = pcall(ObjectType, pointer)
    obj.type = (success2 and objType) or 0
    obj.cache.lastUpdate = 0
    obj.cache.lastHealthCheck = nil
    obj.cache.lastHealthMaxCheck = nil
  else
    obj = Object:New(pointer, token)
  end
  return obj
end

local function ReleaseObject(obj)
  poolSize = poolSize + 1
  ObjectPool[poolSize] = obj
end

function Object:New(pointer, token)
  if not pointer or pointer == 0 then return nil end

  local obj = setmetatable({}, Object)

  obj.pointer = pointer
  obj.token = token
  local success, guid = pcall(ObjectGUID, pointer)
  obj._guid = (success and guid) or ""

  local success2, objType = pcall(ObjectType, pointer)
  obj.type = (success2 and objType) or 0

  obj.cache = {
    position = {0, 0, 0},
    lastUpdate = 0,
    lastHealthUpdate = 0,
    health = 0,
    healthMax = 1,
  }

  return obj
end

function Object:GetToken()
  if self.token then
    return self.token
  end

  return VanFW:GetTokenByGUID(self._guid)
end

function Object:Exists()
  if not self.pointer then return false end
  if self._guid == "" then return false end

  local token = self:GetToken()
  if not token then return false end

  return UnitExists(token)
end

function Object:IsValid()
  return self:Exists() and self._guid ~= ""
end


function Object:Name()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return "Unknown" end
  return UnitName(token) or "Unknown"
end

function Object:GUID()
  return self._guid
end


function Object:Health()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return 0 end

  local currentTime = VanFW.time or GetTime()
  if self.cache.lastHealthCheck and (currentTime - self.cache.lastHealthCheck < 0.05) then
    return self.cache.health
  end

  local health = 0
  if _G.UnitHealth then
    health = _G.UnitHealth(token) or 0
  end
  self.cache.health = health
  self.cache.lastHealthCheck = currentTime

  return health
end

function Object:HealthMax()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return 1 end

  local currentTime = VanFW.time or GetTime()
  if self.cache.lastHealthMaxCheck and (currentTime - self.cache.lastHealthMaxCheck < 0.05) then
    return self.cache.healthMax
  end

  local healthMax = 1
  if _G.UnitHealthMax then
    healthMax = _G.UnitHealthMax(token) or 1
  end
  self.cache.healthMax = healthMax
  self.cache.lastHealthMaxCheck = currentTime

  return healthMax
end

function Object:HealthPercent()
  local max = self:HealthMax()
  if max == 0 then return 0 end
  return (self:Health() / max) * 100
end

function Object:Power(powerType)
  local token = self:GetToken()
  if not token or not UnitExists(token) then return 0 end
  powerType = powerType or 0

  if _G.UnitPower then
    return _G.UnitPower(token, powerType) or 0
  end
  return 0
end

function Object:PowerMax(powerType)
  local token = self:GetToken()
  if not token or not UnitExists(token) then return 1 end
  powerType = powerType or 0

  if _G.UnitPowerMax then
    return _G.UnitPowerMax(token, powerType) or 1
  end
  return 1
end

function Object:PowerPercent(powerType)
  local max = self:PowerMax(powerType)
  if max == 0 then return 0 end
  return (self:Power(powerType) / max) * 100
end


function Object:IsDead()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return true end
  return UnitIsDead(token) or UnitIsDeadOrGhost(token)
end

function Object:InCombat()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return false end
  return UnitAffectingCombat(token)
end

function Object:IsPlayer()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return false end
  return UnitIsPlayer(token)
end

function Object:IsEnemy()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return false end

  if _G.UnitCanAttack then
    local canAttack = _G.UnitCanAttack("player", token)
    if canAttack ~= nil then
      return canAttack
    end
  end
  if _G.UnitReaction then
    local reaction = _G.UnitReaction("player", token)
    if reaction then
      return reaction <= 4  -- 1-4 = Hostile/Unfriendly
    end
  end

  return false
end

function Object:IsFriend()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return false end
  local reaction = UnitReaction("player", token)
  if reaction then
    return reaction >= 5  -- 5-8 = Neutral/Friendly
  end
  return UnitIsFriend("player", token)
end

function Object:IsMoving()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return false end
  local speed = GetUnitSpeed(token)
  return speed and speed > 0
end

function Object:GetSpeed()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return 0 end
  local speed = GetUnitSpeed(token)
  return speed or 0
end

function Object:Level()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return 0 end
  return UnitLevel(token) or 0
end

function Object:Classification()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return "normal" end
  return UnitClassification(token) or "normal"
end

function Object:IsBoss()
  local classification = self:Classification()
  return classification == "worldboss" or classification == "rareelite" or classification == "elite"
end

function Object:IsWorldBoss()
  local classification = self:Classification()
  return classification == "worldboss"
end

function Object:Position()
  if not self.pointer or self.pointer == 0 then return nil, nil, nil end

  if VanFW.time - self.cache.lastUpdate < 0.05 and #self.cache.position == 3 then
    return unpack(self.cache.position)
  end

  local success, x, y, z = pcall(ObjectPos, self.pointer)

  if success and x and y and z then
    self.cache.position[1] = x
    self.cache.position[2] = y
    self.cache.position[3] = z
    self.cache.lastUpdate = VanFW.time
    return x, y, z
  end

  return nil, nil, nil
end

function Object:Facing()
  if not self.pointer or self.pointer == 0 then return 0 end
  local success, facing = pcall(GetFacing, self.pointer)
  return (success and facing) or 0
end

function Object:DistanceTo(target)
  if not self.pointer or self.pointer == 0 then return 999 end
  if not target then return 999 end

  local x1, y1, z1 = self:Position()
  if not x1 then return 999 end

  local x2, y2, z2

  if type(target) == "table" and target.Position then
    x2, y2, z2 = target:Position()
  elseif type(target) == "number" then
    x2, y2, z2 = target, nil, nil
  else
    return 999
  end

  if not x2 then return 999 end

  if z2 then
    return VanFW:Distance3D(x1, y1, z1, x2, y2, z2)
  else
    return VanFW:Distance2D(x1, y1, x2, y2)
  end
end

function Object:Distance()
  if not VanFW.player then return 999 end
  return self:DistanceTo(VanFW.player)
end

function Object:DistanceSquared()
  local dist = self:Distance()
  return dist * dist
end

function Object:LineOfSight(target)
  target = target or VanFW.player
  if not target then return false end

  local x1, y1, z1 = self:Position()
  local x2, y2, z2 = target:Position()

  if not x1 or not x2 then return false end

  return VanFW:QuickLoS(x1, y1, z1, x2, y2, z2)
end

function Object:HasLoS(target)
  -- If called without argument, check LoS from player to this object
  -- target:HasLoS() -> checks player to target
  --player:HasLoS(target) -> checks player to target
  if not target then
    -- Called as target:HasLoS() -> check from player to self
    return VanFW.player and VanFW.player:LineOfSight(self) or false
  else
    -- Called as player:HasLoS(target) -> check from self to target
    return self:LineOfSight(target)
  end
end

function Object:IsFacing(target, angle)
  angle = angle or math.pi

  local x1, y1 = self:Position()
  local x2, y2

  if type(target) == "table" and target.Position then
    x2, y2 = target:Position()
  else
    return false
  end

  if not x1 or not x2 then return false end

  local facing = self:Facing()
  local angleToTarget = math.atan2(y2 - y1, x2 - x1)
  local diff = math.abs(facing - angleToTarget)

  while diff > math.pi * 2 do
    diff = diff - math.pi * 2
  end

  if diff > math.pi then
    diff = math.pi * 2 - diff
  end

  return diff <= (angle / 2)
end

function Object:IsFacingMe()
  if not VanFW.player then return false end
  return self:IsFacing(VanFW.player, math.pi)
end

function Object:PredictPosition(time)
  time = time or 0.5

  local x, y, z = self:Position()
  if not x then return nil, nil, nil end

  if not self:IsMoving() then
    return x, y, z
  end

  local token = self:GetToken()
  if not token then return x, y, z end

  local speed = GetUnitSpeed(token) or 0
  local facing = self:Facing()

  local distance = speed * time
  local newX = x + distance * math.cos(facing)
  local newY = y + distance * math.sin(facing)

  return newX, newY, z
end

function Object:IsCasting()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return false end

  local name = UnitCastingInfo(token)
  return name ~= nil
end

function Object:IsChanneling()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return false end

  local name = UnitChannelInfo(token)
  return name ~= nil
end

function Object:CastingInfo()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return nil end

  local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(token)

  if not name then return nil end

  local currentTime = VanFW.time or GetTime()

  return {
    name = name,
    spellID = spellID,
    texture = texture,
    startTime = startTime,
    endTime = endTime,
    remaining = (endTime - currentTime * 1000) / 1000,
    interruptible = not notInterruptible,
    castID = castID,
  }
end

function Object:ChannelInfo()
  local token = self:GetToken()
  if not token or not UnitExists(token) then return nil end

  local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(token)

  if not name then return nil end

  local currentTime = VanFW.time or GetTime()

  return {
    name = name,
    spellID = spellID,
    texture = texture,
    startTime = startTime,
    endTime = endTime,
    remaining = (endTime - currentTime * 1000) / 1000,
    interruptible = not notInterruptible,
  }
end

function Object:CastRemaining()
  local info = self:CastingInfo() or self:ChannelInfo()
  return info and info.remaining or 0
end

function Object:CastID()
  local info = self:CastingInfo() or self:ChannelInfo()
  return info and info.spellID or 0
end

function Object:IsInterruptible()
  local info = self:CastingInfo() or self:ChannelInfo()
  return info and info.interruptible or false
end

function Object:HasBuff(spellID)
  local token = self:GetToken()
  if not token or not UnitExists(token) then return false end

  local currentTime = VanFW.time or GetTime()

  if C_UnitAuras_GetBuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras_GetBuffDataByIndex(token, i)
      if not auraData then break end
      if auraData.spellId == spellID then
        return true, auraData.applications or 1, auraData.expirationTime and (auraData.expirationTime - currentTime) or 0
      end
    end
  elseif UnitAura then
    for i = 1, 40 do
      local name, _, count, _, _, expirationTime, _, _, _, id = UnitAura(token, i, "HELPFUL")
      if not name then break end
      if id == spellID then
        return true, count or 1, expirationTime and (expirationTime - currentTime) or 0
      end
    end
  end

  return false, 0, 0
end

function Object:BuffRemaining(spellID)
  local token = self:GetToken()
  if not token or not UnitExists(token) then return 0 end

  local currentTime = VanFW.time or GetTime()

  if C_UnitAuras_GetBuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras_GetBuffDataByIndex(token, i)
      if not auraData then break end
      if auraData.spellId == spellID then
        return auraData.expirationTime and math.max(0, auraData.expirationTime - currentTime) or 0
      end
    end
  elseif UnitAura then
    for i = 1, 40 do
      local name, _, _, _, _, expirationTime, _, _, _, id = UnitAura(token, i, "HELPFUL")
      if not name then break end
      if id == spellID then
        return math.max(0, expirationTime - currentTime)
      end
    end
  end

  return 0
end

function Object:BuffStacks(spellID)
  local token = self:GetToken()
  if not token or not UnitExists(token) then return 0 end

  if C_UnitAuras_GetBuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras_GetBuffDataByIndex(token, i)
      if not auraData then break end
      if auraData.spellId == spellID then
        return auraData.applications or 1
      end
    end
  elseif UnitAura then
    for i = 1, 40 do
      local name, _, count, _, _, _, _, _, _, id = UnitAura(token, i, "HELPFUL")
      if not name then break end
      if id == spellID then
        return count or 1
      end
    end
  end

  return 0
end

function Object:HasDebuff(spellID)
  local token = self:GetToken()
  if not token or not UnitExists(token) then return false end

  local currentTime = VanFW.time or GetTime()

  if C_UnitAuras_GetDebuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras_GetDebuffDataByIndex(token, i)
      if not auraData then break end
      if auraData.spellId == spellID then
        return true, auraData.applications or 1, auraData.expirationTime and (auraData.expirationTime - currentTime) or 0
      end
    end
  elseif UnitAura then
    for i = 1, 40 do
      local name, _, count, _, _, expirationTime, _, _, _, id = UnitAura(token, i, "HARMFUL")
      if not name then break end
      if id == spellID then
        return true, count or 1, expirationTime and (expirationTime - currentTime) or 0
      end
    end
  end

  return false, 0, 0
end

function Object:DebuffRemaining(spellID)
  local token = self:GetToken()
  if not token or not UnitExists(token) then return 0 end

  local currentTime = VanFW.time or GetTime()

  if C_UnitAuras_GetDebuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras_GetDebuffDataByIndex(token, i)
      if not auraData then break end
      if auraData.spellId == spellID then
        return auraData.expirationTime and math.max(0, auraData.expirationTime - currentTime) or 0
      end
    end
  elseif UnitAura then
    for i = 1, 40 do
      local name, _, _, _, _, expirationTime, _, _, _, id = UnitAura(token, i, "HARMFUL")
      if not name then break end
      if id == spellID then
        return math.max(0, expirationTime - currentTime)
      end
    end
  end

  return 0
end

function Object:DebuffStacks(spellID)
  local token = self:GetToken()
  if not token or not UnitExists(token) then return 0 end

  if C_UnitAuras_GetDebuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras_GetDebuffDataByIndex(token, i)
      if not auraData then break end
      if auraData.spellId == spellID then
        return auraData.applications or 1
      end
    end
  elseif UnitAura then
    for i = 1, 40 do
      local name, _, count, _, _, _, _, _, _, id = UnitAura(token, i, "HARMFUL")
      if not name then break end
      if id == spellID then
        return count or 1
      end
    end
  end

  return 0
end

function Object:CombatReach()
  if not self.pointer then return 1.5 end
  return ObjectCombatReach(self.pointer) or 1.5
end

function Object:BoundingRadius()
  if not self.pointer then return 1 end
  return ObjectBoundingRadius(self.pointer) or 1
end

function Object:MeleeRange(target)
  target = target or VanFW.player
  if not target then return false end

  local distance = self:DistanceTo(target)
  local reach = self:CombatReach() + target:CombatReach() + 1.5

  return distance <= reach
end

function VanFW:InitializeObjects()
  self:Debug("Object system initialized", "Objects")
end

function VanFW:UpdateObjects()
  if self.time - self.lastObjectUpdate < self.config.objectUpdateRate then
    return
  end

  self.lastObjectUpdate = self.time

  -- Release old objects back to the pool
  for _, obj in ipairs(self.objects.all) do
    ReleaseObject(obj)
  end

  self.objects.all = {}
  self.objects.enemies = {}
  self.objects.friends = {}
  self.objects.players = {}
  self.objects.npcs = {}
  self.objects.units = {}

  local objectTable = nil
  if _G.WGG_Objects then
    objectTable = _G.WGG_Objects()
  else
    return
  end

  if not objectTable then
    return
  end

  self.objectCount = 0

  for _, pointer in ipairs(objectTable) do
    local objType = _G.WGG_ObjectType and _G.WGG_ObjectType(pointer) or 0
    if objType == 5 or objType == 6 then
      local token = _G.WGG_ObjectToken and _G.WGG_ObjectToken(pointer) or nil
      local obj = AcquireObject(pointer, token)

      if obj and obj:IsValid() then
        self.objectCount = self.objectCount + 1
        table.insert(self.objects.all, obj)
        self.objects.byGUID[obj._guid] = obj

        if obj:IsPlayer() then
          table.insert(self.objects.players, obj)
        else
          table.insert(self.objects.npcs, obj)
        end

        if obj:IsEnemy() and not obj:IsDead() then
          table.insert(self.objects.enemies, obj)
        elseif obj:IsFriend() and not obj:IsDead() then
          table.insert(self.objects.friends, obj)
        end

        if not obj:IsDead() then
          table.insert(self.objects.units, obj)
        end
      end
    end
  end
end

function VanFW:GetObjectByGUID(guid)
  if not self.objects or not self.objects.byGUID then
    return nil
  end
  return self.objects.byGUID[guid]
end

function VanFW:GetEnemies()
  return self.objects.enemies
end

function VanFW:GetFriends()
  return self.objects.friends
end

function VanFW:GetEnemiesInRange(range)
  local enemies = {}
  for _, enemy in ipairs(self.objects.enemies) do
    if enemy:Distance() <= range then
      table.insert(enemies, enemy)
    end
  end
  return enemies
end

function VanFW:GetEnemiesInRangeCount(range)
  local count = 0
  for _, enemy in ipairs(self.objects.enemies) do
    if enemy:Distance() <= range then
      count = count + 1
    end
  end
  return count
end

function VanFW:GetClosestEnemy(range)
  local closest = nil
  local closestDist = range or 999

  for _, enemy in ipairs(self.objects.enemies) do
    local dist = enemy:Distance()
    if dist < closestDist then
      closest = enemy
      closestDist = dist
    end
  end

  return closest
end

function VanFW:GetEnemiesByHealth(ascending)
  local enemies = {}

  for _, enemy in ipairs(self.objects.enemies) do
    table.insert(enemies, enemy)
  end

  table.sort(enemies, function(a, b)
    if ascending then
      return a:HealthPercent() < b:HealthPercent()
    else
      return a:HealthPercent() > b:HealthPercent()
    end
  end)

  return enemies
end

function VanFW:GetLowestHealthEnemy(range)
  local enemies = self:GetEnemiesByHealth(true)

  if range then
    for _, enemy in ipairs(enemies) do
      if enemy:Distance() <= range then
        return enemy
      end
    end
  else
    return enemies[1]
  end

  return nil
end


function Object:position()
  return self:Position()
end

function Object:distance(target)
  if not target then
    return self:Distance()
  end

  if type(target) == "string" then
    target = VanFW:GetObjectByToken(target)
    if not target then return 999 end
  end

  return self:DistanceTo(target)
end

function Object:distanceTo(target)
  return self:DistanceTo(target)
end

function Object:distanceToLiteral(x, y, z)
  local sx, sy, sz = self:Position()
  if not sx or not x then return 999 end
  return VanFW:Distance3D(sx, sy, sz, x, y, z)
end

function Object:predictPosition(elapsed)
  local x, y, z = self:Position()
  if not x or not self:IsMoving() then return x, y, z end

  local speed = self:GetSpeed()
  local facing = self:Facing()

  local dx = math.cos(facing) * speed * elapsed
  local dy = math.sin(facing) * speed * elapsed

  return x + dx, y + dy, z
end

function Object:predictDistance(elapsed)
  if not VanFW.player then return 999 end
  local px, py, pz = self:predictPosition(elapsed)
  if not px then return 999 end

  local tx, ty, tz = VanFW.player:Position()
  if not tx then return 999 end

  return VanFW:Distance3D(px, py, pz, tx, ty, tz)
end

function Object:facing(target, angle)
  if not target then return false end

  angle = angle or 180
  local pi = math.pi

  local x, y, z = self:Position()
  if not x then return false end

  local tX, tY, tZ
  if type(target) == "table" and target.Position then
    tX, tY, tZ = target:Position()
  else
    return false
  end

  if not tX then return false end

  local rotation = self:Facing()
  if not rotation then return false end

  local angleToUnit = math.atan2(tY - y, tX - x)
  local angleDifference = rotation > angleToUnit and rotation - angleToUnit or angleToUnit - rotation
  local shortestAngle = angleDifference < pi and angleDifference or pi * 2 - angleDifference
  local finalAngle = shortestAngle / (pi / 180)

  if finalAngle < angle / 2 then
    return true
  end

  local distance = self:distanceTo(target)
  if distance < 1.5 then
    return true
  end

  return false
end

function Object:rotation()
  return self:Facing()
end

function Object:hp()
  return self:HealthPercent()
end

function Object:hpa()
  local health = self:HealthPercent()
  local token = self:GetToken()
  if not token then return health end

  local totalAbsorb = 0

  local absorbSpells = {
    17, -- Power Word: Shield (Priest)
    47753, -- Divine Aegis (Priest)
    114908, -- Spirit Shell (Priest)
    81782, -- Power Word: Barrier (Priest)
    11426, -- Ice Barrier (Mage)
    235313, -- Blazing Barrier (Mage)
    198111, -- Temporal Shield (Mage)
    108416, -- Sacrificial Pact (Warlock)
    104773, -- Unending Resolve (Warlock)
    108366, -- Soul Leech (Warlock)
    209584, -- Zen Meditation (Monk)
    120954, -- Fortifying Brew (Monk)
    6940, -- Blessing of Sacrifice (Paladin)
    --386396, -- Ignore Pain (Warrior) - This is damage reduction, not absorb
  }

  if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras.GetBuffDataByIndex(token, i)
      if not auraData then break end

      for _, absorbId in ipairs(absorbSpells) do
        if auraData.spellId == absorbId then
          if auraData.points and auraData.points[1] then
            totalAbsorb = totalAbsorb + math.abs(auraData.points[1])
          end
        end
      end
    end
  end

  local maxHealth = self:HealthMax()
  if maxHealth > 0 and totalAbsorb > 0 then
    local currentHealth = self:Health()
    local totalEffectiveHealth = currentHealth + totalAbsorb
    return (totalEffectiveHealth / maxHealth) * 100
  end

  return health
end

function Object:health()
  return self:Health()
end

function Object:healthMax()
  return self:HealthMax()
end

function Object:hpDeficit()
  return self:HealthMax() - self:Health()
end

function Object:power(powerType)
  return self:Power(powerType)
end

function Object:powerMax(powerType)
  return self:PowerMax(powerType)
end

function Object:dead()
  local token = self:GetToken()
  if not token then return false end
  if not UnitExists(token) then return false end
  if UnitIsDeadOrGhost(token) then
    if C_UnitAuras then
      for i = 1, 40 do
        local buffData = C_UnitAuras.GetBuffDataByIndex(token, i)
        if buffData and buffData.spellId then
          if buffData.spellId == 5384 then
            return false
          end
        else
          break
        end
      end
    else
      local AuraUtil = _G.AuraUtil
      if AuraUtil and AuraUtil.FindAuraBySpellID then
        if AuraUtil.FindAuraBySpellID(5384, token, "HELPFUL") then
          return false  -- Feign Death
        end
      end
    end
    return true
  end
  return false
end

function Object:los(target)
  if not target then
    target = VanFW.player
  end
  if not target then return false end
  return self:LineOfSight(target)
end

function Object:combat()
  return self:InCombat()
end

function Object:cc()
  local token = self:GetToken()
  if not token then return false end

  local ccSpells = {
    -- Stuns
    408, -- Kidney Shot (Rogue)
    853, -- Hammer of Justice (Paladin)
    5211, -- Mighty Bash (Druid)
    19577, -- Intimidation (Hunter)
    20066, -- Repentance (Paladin)
    47481, -- Gnaw (Death Knight pet)
    107570, -- Storm Bolt (Warrior)
    119381, -- Leg Sweep (Monk)
    171017, -- Meteor Strike (Warlock)
    179057, -- Chaos Nova (Demon Hunter)
    221562, -- Asphyxiate (Death Knight)
    255723, -- Bull Rush (Highmountain Tauren)
    408, -- Cheap Shot (Rogue)
    1833, -- Cheap Shot (Rogue)

    -- Incapacitates
    2094, -- Blind (Rogue)
    6770, -- Sap (Rogue)
    20066, -- Repentance (Paladin)
    51514, -- Hex (Shaman)
    82691, -- Ring of Frost (Mage)
    88625, -- Holy Word: Chastise (Priest)
    115078, -- Paralysis (Monk)
    217832, -- Imprison (Demon Hunter)

    -- Disorients
    118, -- Polymorph (Mage)
    605, -- Mind Control (Priest)
    2637, -- Hibernate (Druid)
    5484, -- Howl of Terror (Warlock)
    8122, -- Psychic Scream (Priest)
    31661, -- Dragon's Breath (Mage)
    61305, -- Black Ox Statue (Monk)

    -- Fear
    5246, -- Intimidating Shout (Warrior)
    5782, -- Fear (Warlock)
    8122, -- Psychic Scream (Priest)
    130616, -- Fear (Warlock pet)

    -- Horror
    64044, -- Psychic Horror (Priest)
    207685, -- Sigil of Misery (Demon Hunter)

    -- Cyclone
    33786, -- Cyclone (Druid)

    -- Banish
    710, -- Banish (Warlock)

    -- Sleep
    1776, -- Gouge (Rogue)
    20549, -- War Stomp (Tauren)
  }

  if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras.GetDebuffDataByIndex(token, i)
      if not auraData then break end

      local spellId = auraData.spellId
      for _, ccId in ipairs(ccSpells) do
        if spellId == ccId then
          return true
        end
      end
    end
  end

  if UnitIsCharmed then
    return UnitIsCharmed(token) or false
  end

  return false
end

function Object:bcc()
  return self:cc()
end

function Object:stunned()
  local token = self:GetToken()
  if not token then return false end

  local stunSpells = {
    408, -- Kidney Shot (Rogue)
    853, -- Hammer of Justice (Paladin)
    1833, -- Cheap Shot (Rogue)
    5211, -- Mighty Bash (Druid)
    19577, -- Intimidation (Hunter)
    20066, -- Repentance (Paladin)
    47481, -- Gnaw (Death Knight pet)
    89766, -- Axe Toss (Warlock pet)
    107570, -- Storm Bolt (Warrior)
    119381, -- Leg Sweep (Monk)
    171017, -- Meteor Strike (Warlock)
    179057, -- Chaos Nova (Demon Hunter)
    221562, -- Asphyxiate (Death Knight)
    255723, -- Bull Rush (Highmountain Tauren)
    408, -- Cheap Shot (Rogue)
    46968, -- Shockwave (Warrior)
    118905, -- Static Charge (Shaman - Capacitor Totem)
    287712, -- Haymaker (Kul Tiran)
    385149, -- Shattering Star (Shaman)
  }

  if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras.GetDebuffDataByIndex(token, i)
      if not auraData then break end

      local spellId = auraData.spellId
      for _, stunId in ipairs(stunSpells) do
        if spellId == stunId then
          return true
        end
      end
    end
  end

  return false
end

function Object:rooted()
  local token = self:GetToken()
  if not token then return false end

  local rootSpells = {
    339, -- Entangling Roots (Druid)
    117526, -- Binding Shot (Hunter)
    122, -- Frost Nova (Mage)
    33395, -- Freeze (Mage pet)
    198121, -- Frostbite (Mage)
    198111, -- Temporal Shield (Mage)
    204085, -- Deathchill (Death Knight)
    233395, -- Frozen Center (Mage)
    157997, -- Ice Nova (Mage)
    342375, -- Tormenting Backlash (Priest)
    64695, -- Earthgrab Totem (Shaman)
    285515, -- Surge of Power (Shaman)
    356738, -- Earth Unleashed (Shaman)
    356356, -- Warbringer (Warrior)
    199042, -- Thunderstruck (Shaman)
    45334, -- Immobilized (Warrior)
    212792, -- Cone of Cold (Mage)
    386770, -- Freezing Cold (Death Knight)
    199786, -- Spring Blossoms (Druid)
  }

  if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras.GetDebuffDataByIndex(token, i)
      if not auraData then break end

      local spellId = auraData.spellId
      for _, rootId in ipairs(rootSpells) do
        if spellId == rootId then
          return true
        end
      end
    end
  end

  return false
end

function Object:slowed()
  local token = self:GetToken()
  if not token then return false end

  local slowSpells = {
    116, -- Frostbolt (Mage)
    205708, -- Chilled (Mage)
    212792, -- Cone of Cold (Mage)
    31589, -- Slow (Mage)
    1715, -- Hamstring (Warrior)
    185763, -- Piercing Shot (Hunter)
    3409, -- Crippling Poison (Rogue)
    206760, -- Night Terrors (Shadow Priest)
    212332, -- Smolder (Mage)
    157981, -- Blast Wave (Mage)
    228354, -- Flurry (Mage)
    228358, -- Winter's Chill (Mage)
    205021, -- Ray of Frost (Mage)
    382106, -- Cauterizing Flames (Mage)
    386770, -- Freezing Cold (Death Knight)
    196840, -- Frost Shock (Shaman)
    342375, -- Tormenting Backlash (Priest)
    6343, -- Thunder Clap (Warrior)
    8034, -- Frostbrand Attack (Shaman)
    378760, -- Earthbind (Shaman - Earthbind Totem)
  }

  if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras.GetDebuffDataByIndex(token, i)
      if not auraData then break end

      local spellId = auraData.spellId
      for _, slowId in ipairs(slowSpells) do
        if spellId == slowId then
          return true
        end
      end
    end
  end

  return false
end

function Object:silenced()
  local token = self:GetToken()
  if not token then return false end

  local silenceSpells = {
    15487, -- Silence (Priest)
    1330, -- Garrote (Rogue)
    47476, -- Strangulate (Death Knight)
    81261, -- Solar Beam (Druid)
    202137, -- Sigil of Silence (Demon Hunter)
    204490, -- Sigil of Silence (Demon Hunter)
    31117, -- Unstable Affliction (Warlock)
    196364, -- Unstable Affliction (Warlock)
    354489, -- Unstable Affliction (Warlock)
    356356, -- Warbringer (Warrior)
    410065, -- Reactive Resin (Druid)
    356727, -- Spider Venom (Hunter)
    377048, -- Absolute Zero (Mage)
  }

  if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras.GetDebuffDataByIndex(token, i)
      if not auraData then break end

      local spellId = auraData.spellId
      for _, silenceId in ipairs(silenceSpells) do
        if spellId == silenceId then
          return true
        end
      end
    end
  end

  return false
end

function Object:disarmed()
  local token = self:GetToken()
  if not token then return false end

  local disarmSpells = {
    236077, -- Disarm (Warrior)
    209749, -- Faerie Swarm (Druid)
    207777, -- Dismantle (Rogue)
    233759, -- Grapple Weapon (Death Knight)
    356356, -- Warbringer (Warrior)
    198909, -- Song of Chi-Ji (Monk)
  }

  if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras.GetDebuffDataByIndex(token, i)
      if not auraData then break end

      local spellId = auraData.spellId
      for _, disarmId in ipairs(disarmSpells) do
        if spellId == disarmId then
          return true
        end
      end
    end
  end

  return false
end

function Object:casting()
  return self:IsCasting()
end

function Object:channeling()
  return self:IsChanneling()
end

function Object:castID()
  return self:CastID()
end

function Object:channelID()
  local info = self:ChannelInfo()
  return info and info.spellID or nil
end

function Object:castRemains()
  return self:CastRemaining()
end

function Object:channelRemains()
  local info = self:ChannelInfo()
  return info and info.remaining or 0
end

function Object:castTime()
  local info = self:CastingInfo()
  if not info then return 0 end
  return (info.endTime - info.startTime) / 1000
end

function Object:castTimeComplete()
  local info = self:CastingInfo()
  if not info then return 0 end
  local currentTime = VanFW.time or GetTime()
  return (currentTime * 1000 - info.startTime) / 1000
end

function Object:channelTimeComplete()
  local info = self:ChannelInfo()
  if not info then return 0 end
  local currentTime = VanFW.time or GetTime()
  return (currentTime * 1000 - info.startTime) / 1000
end

function Object:castTarget()
  if not self.pointer then return nil end

  if VanFW.ObjectCastingTarget then
    local targetPointer = VanFW.ObjectCastingTarget(self.pointer)
    if targetPointer and targetPointer ~= 0 then
      return Object:New(targetPointer)
    end
  end

  if VanFW.ObjectTarget then
    local targetPointer = VanFW.ObjectTarget(self.pointer)
    if targetPointer and targetPointer ~= 0 then
      if self:IsCasting() or self:IsChanneling() then
        return Object:New(targetPointer)
      end
    end
  end

  return nil
end

function Object:castint()
  local token = self:GetToken()
  if not token then return true end
  local _, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(token)
  if notInterruptible == nil then
    _, _, _, _, _, _, notInterruptible = UnitChannelInfo(token)
  end
  return not notInterruptible
end

function Object:class()
  local token = self:GetToken()
  if not token then return "Unknown" end
  local _, className = UnitClass(token)
  return className or "Unknown"
end

function Object:class2()
  local token = self:GetToken()
  if not token then return "UNKNOWN" end
  local _, classFile = UnitClass(token)
  return classFile or "UNKNOWN"
end

function Object:GetSpecID()
  local token = self:GetToken()
  if not token then return 0 end

  if token == "player" then
    local specIndex = GetSpecialization()
    if specIndex then
      local specID = GetSpecializationInfo(specIndex)
      return specID or 0
    end
    return 0
  end

  return 0
end

function Object:spec()
  local token = self:GetToken()
  if not token then return "Unknown" end
  local specID = self:GetSpecID()
  if not specID or specID == 0 then return "Unknown" end
  local _, specName = GetSpecializationInfoByID(specID)
  return specName or "Unknown"
end

function Object:role()
  local token = self:GetToken()
  if not token then return "NONE" end
  return UnitGroupRolesAssigned(token) or "NONE"
end

function Object:isPlayer()
  return self:IsPlayer()
end

function Object:enemy()
  return self:IsEnemy()
end

function Object:friend()
  return self:IsFriend()
end

function Object:pet()
  local token = self:GetToken()
  if not token then return false end
  return UnitIsUnit(token, "pet")
end

function Object:melee()
  local class = self:class2()
  return class == "WARRIOR" or class == "ROGUE" or class == "DEATHKNIGHT" or
         class == "MONK" or class == "DEMONHUNTER" or class == "PALADIN"
end

function Object:ranged()
  return not self:melee()
end

function Object:pointer()
  return self.pointer
end

function Object:guid()
  return self:GUID()
end

function Object:name()
  return self:Name()
end

function Object:level()
  return self:Level()
end

function Object:combatReach()
  if not self.pointer or self.pointer == 0 then return 1.5 end
  local success, reach = pcall(ObjectCombatReach, self.pointer)
  return (success and reach) or 1.5
end

function Object:boundingRadius()
  if not self.pointer or self.pointer == 0 then return 1 end
  local success, radius = pcall(ObjectBoundingRadius, self.pointer)
  return (success and radius) or 1
end

function Object:exists()
  return self:Exists()
end

function Object:visible()
  return self:Exists()
end

function Object:x()
  local x, y, z = self:Position()
  return x or 0
end

function Object:y()
  local x, y, z = self:Position()
  return y or 0
end

function Object:z()
  local x, y, z = self:Position()
  return z or 0
end

function Object:race()
  local token = self:GetToken()
  if not token then return "Unknown" end
  local raceName = UnitRace(token)
  return raceName or "Unknown"
end

function Object:raceID()
  local token = self:GetToken()
  if not token then return 0 end
  local _, _, raceID = UnitRace(token)
  return raceID or 0
end

function Object:classification()
  return self:Classification()
end

function Object:falling()
  local token = self:GetToken()
  if not token then return false end

  if token == "player" then
    if IsFalling then
      return IsFalling()
    end
  end
  return false
end

function Object:meleerange(target)
  if not target then target = VanFW.player end
  if not target then return false end

  local dist = self:DistanceTo(target)
  local reach = self:combatReach() + target:combatReach()
  return dist <= (reach + 5)
end

function Object:immunePhysical()
  local token = self:GetToken()
  if not token then return false end

  local physicalImmunitySpells = {
    642, -- Divine Shield (Paladin)
    45438, -- Ice Block (Mage)
    186265, -- Aspect of the Turtle (Hunter)
    212295, -- Nether Ward (Warlock)
    1022, -- Blessing of Protection (Paladin)
    204018, -- Blessing of Spellwarding (Paladin)
    118038, -- Die by the Sword (Warrior)
    871, -- Shield Wall (Warrior)
    23920, -- Spell Reflection (Warrior)
    198819, -- Primal Rage (Shaman)
  }

  if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras.GetBuffDataByIndex(token, i)
      if not auraData then break end

      local spellId = auraData.spellId
      for _, immuneId in ipairs(physicalImmunitySpells) do
        if spellId == immuneId then
          return true
        end
      end
    end
  end

  return false
end

function Object:immuneMagic()
  local token = self:GetToken()
  if not token then return false end

  local magicImmunitySpells = {
    642, -- Divine Shield (Paladin)
    45438, -- Ice Block (Mage)
    186265, -- Aspect of the Turtle (Hunter)
    204018, -- Blessing of Spellwarding (Paladin)
    212295, -- Nether Ward (Warlock)
    198111, -- Temporal Shield (Mage)
    47585, -- Dispersion (Priest)
    31224, -- Cloak of Shadows (Rogue)
  }

  if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras.GetBuffDataByIndex(token, i)
      if not auraData then break end

      local spellId = auraData.spellId
      for _, immuneId in ipairs(magicImmunitySpells) do
        if spellId == immuneId then
          return true
        end
      end
    end
  end

  return false
end

function Object:immuneHealing()
  local token = self:GetToken()
  if not token then return false end

  local healingImmunitySpells = {
    8122, -- Psychic Scream (prevents healing sometimes)
    -- Most healing immunity is actually from healing absorption (Mindgames, etc)
    -- This would need to check for specific auras that prevent healing
  }

  if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
    for i = 1, 40 do
      local auraData = C_UnitAuras.GetDebuffDataByIndex(token, i)
      if not auraData then break end

      local spellId = auraData.spellId
      for _, immuneId in ipairs(healingImmunitySpells) do
        if spellId == immuneId then
          return true
        end
      end
    end
  end

  return false
end

function Object:target()
  if not self.pointer then return nil end
  local targetPointer = VanFW.ObjectTarget and VanFW.ObjectTarget(self.pointer)
  if not targetPointer then return nil end
  return Object:New(targetPointer)
end
VanFW.Object = Object
