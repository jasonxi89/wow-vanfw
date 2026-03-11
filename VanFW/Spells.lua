local VanFW = VanFW
local WGG_Click = VanFW.Click

local GetTime = _G.GetTime
local IsSpellKnown = _G.IsSpellKnown
local IsPlayerSpell = _G.IsPlayerSpell
local GetSpellInfo = _G.GetSpellInfo

local CastSpellByID = _G.CastSpellByID
local CastSpellByName = _G.CastSpellByName

local C_Spell = _G.C_Spell
local C_Spell_GetSpellName = C_Spell and C_Spell.GetSpellName
local C_Spell_GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local C_Spell_GetSpellInfo = C_Spell and C_Spell.GetSpellInfo
local C_Spell_GetSpellCooldown = C_Spell and C_Spell.GetSpellCooldown
local C_Spell_GetSpellCharges = C_Spell and C_Spell.GetSpellCharges
local C_Spell_IsSpellUsable = C_Spell and C_Spell.IsSpellUsable

local GetSpellCooldown = _G.GetSpellCooldown
local GetSpellCharges = _G.GetSpellCharges
local IsUsableSpell = _G.IsUsableSpell

local C_Timer = _G.C_Timer
local C_Timer_After = C_Timer and C_Timer.After

local math_max = math.max
local math_min = math.min


local Spell = {}
Spell.__index = Spell

function VanFW:CreateSpell(spellIDOrName, options)
  options = options or {}

  local spell = setmetatable({}, Spell)

  if type(spellIDOrName) == "number" then
    spell.id = spellIDOrName
    spell.name = options.name or (C_Spell_GetSpellName and C_Spell_GetSpellName(spellIDOrName)) or "Unknown"
  elseif type(spellIDOrName) == "string" then
    spell.name = spellIDOrName
    spell.id = options.id or nil
    if not spell.id then
      local spellInfo = C_Spell_GetSpellInfo and C_Spell_GetSpellInfo(spellIDOrName)
      if spellInfo and spellInfo.spellID then
        spell.id = spellInfo.spellID
      end
    end
  else
    spell.id = nil
    spell.name = "Unknown"
  end

  spell.texture = C_Spell_GetSpellTexture and C_Spell_GetSpellTexture(spell.id or spell.name)

  spell.gcd = options.gcd ~= false
  spell.range = options.range or 40
  spell.priority = options.priority or 5  -- 1 = highest, 10 = lowest
  spell.callback = options.callback
  spell.castMethod = options.castMethod or 'auto'

  return spell
end

function VanFW:GetSpellByName(spellName)
  if not spellName then return nil end

  local spellInfo = C_Spell_GetSpellInfo and C_Spell_GetSpellInfo(spellName)
  if spellInfo and spellInfo.spellID then
    return self:CreateSpell(spellInfo.spellID)
  end

  return nil
end

function Spell:Cooldown()
  local start, duration = 0, 0

  if C_Spell_GetSpellCooldown then
    local info = C_Spell_GetSpellCooldown(self.id)
    if info then
      start = info.startTime or 0
      duration = info.duration or 0
    end
  elseif GetSpellCooldown then
    start, duration = GetSpellCooldown(self.id)
  end

  if not start or start == 0 then
    return 0
  end

  local remaining = duration - (GetTime() - start)
  return math_max(0, remaining)
end

function Spell:CooldownDuration()
  local duration = 0

  if C_Spell_GetSpellCooldown then
    local info = C_Spell_GetSpellCooldown(self.id)
    if info then
      duration = info.duration or 0
    end
  elseif GetSpellCooldown then
    local _, dur = GetSpellCooldown(self.id)
    duration = dur or 0
  end

  return duration
end

function Spell:IsOnCooldown()
  return self:Cooldown() > 0
end

function Spell:IsReady()
  return self:Cooldown() <= VanFW:GetGCD()
end

function Spell:Charges()
  local charges, maxCharges = 0, 1

  if C_Spell_GetSpellCharges then
    local info = C_Spell_GetSpellCharges(self.id)
    if info then
      charges = info.currentCharges or 0
      maxCharges = info.maxCharges or 1
    end
  elseif GetSpellCharges then
    charges, maxCharges = GetSpellCharges(self.id)
  end

  return charges or 0, maxCharges or 1
end

function Spell:HasCharges()
  local charges = self:Charges()
  return charges > 0
end

function Spell:IsKnown()
  if self.castMethod == 'name' or not self.id then
    return true
  end

  if self.id then
    return IsSpellKnown(self.id, false) or (IsPlayerSpell and IsPlayerSpell(self.id))
  end

  return false
end

function Spell:IsUsable()
  local useNameInstead = (self.castMethod == 'name') or (not self.id and self.name)
  local spellIdentifier = useNameInstead and self.name or self.id

  if not spellIdentifier then
    return false
  end

  if C_Spell_IsSpellUsable then
    local usable, notEnoughMana = C_Spell_IsSpellUsable(spellIdentifier)
    return usable == true
  elseif IsUsableSpell then
    local usable, notEnoughMana = IsUsableSpell(spellIdentifier)
    return usable == true
  end
  return false
end

function Spell:InRange(target)
  if not target then return false end

  local spellInfo = C_Spell_GetSpellInfo and C_Spell_GetSpellInfo(self.id)
  if spellInfo and spellInfo.maxRange then
    local range = spellInfo.maxRange
    if range == 0 then
      local distance = target:distance()
      return distance and distance <= 5 or false
    end
    local distance = target:distance()
    if distance then
      return distance <= range
    end
  end

  return true
end

function Spell:HasLoS(target)
  if not target or not target.HasLoS then
    return true
  end
  return target:HasLoS()
end

function Spell:Castable(target)
  if not self:IsKnown() then
    return false, "not_known"
  end

  if not self:IsUsable() then
    return false, "not_usable"
  end

  if self:IsOnCooldown() and not self:HasCharges() then
    return false, "on_cooldown"
  end

  if target then
    if not self:InRange(target) then
      return false, "out_of_range"
    end

    if not self:HasLoS(target) then
      return false, "no_los"
    end
  end

  return true, nil
end

function Spell:CanCast(target)
  local castable, reason = self:Castable(target)
  return castable, reason
end

function Spell:WillBeCastable(target)
  if not self:IsKnown() then
    return false, "not_known"
  end

  if not self:IsUsable() then
    return false, "not_usable"
  end

  if self:IsOnCooldown() and not self:HasCharges() then
    return false, "on_cooldown"
  end

  if target then
    if not self:InRange(target) then
      return true, "waiting_range"
    end

    if not self:HasLoS(target) then
      return true, "waiting_los"
    end
  end

  return true, nil
end

-- Internal: check anti-detection delay, return false if too soon since last cast
local function _checkCastDelay()
  if not VanFW.lastSpellCastTime then
    return true
  end
  local timeSinceLastCast = GetTime() - VanFW.lastSpellCastTime
  local minDelay = _G.math.random(0.08, 0.18)
  return timeSinceLastCast >= minDelay
end

-- Internal: execute the actual spell cast via castMethod branching
-- token: unit token for targeted casts, or nil for AoE (no target arg)
-- Returns true if cast succeeded, false otherwise
local function _executeCast(spell, token)
  local castMethod = spell.castMethod or 'auto'
  local hasToken = token ~= nil

  if castMethod == 'name' then
    if CastSpellByName and spell.name then
      if hasToken then
        CastSpellByName(spell.name, token)
      else
        CastSpellByName(spell.name)
      end
      return true
    end
  elseif castMethod == 'id' then
    if CastSpellByID and spell.id then
      if hasToken then
        CastSpellByID(spell.id, token)
      else
        CastSpellByID(spell.id)
      end
      return true
    end
  else -- auto: try ID first, fallback to name
    if CastSpellByID and spell.id then
      if hasToken then
        CastSpellByID(spell.id, token)
      else
        CastSpellByID(spell.id)
      end
      return true
    elseif CastSpellByName and spell.name then
      if hasToken then
        CastSpellByName(spell.name, token)
      else
        CastSpellByName(spell.name)
      end
      return true
    end
  end

  return false
end

-- Internal: record cast time and queue GCD/last-cast tracking
local function _recordCast(spell, target)
  VanFW.lastSpellCastTime = GetTime()

  if spell.gcd and VanFW.QueueSpell then
    VanFW:QueueSpell(spell.id or spell.name, 0.4, spell.priority or 5)
  end

  if VanFW.UpdateLastCast then
    VanFW:UpdateLastCast(spell.id or spell.name, target)
  end
end

-- Internal: safely invoke spell callback
local function _invokeCallback(spell, cb, callbackTarget)
  if not cb or type(cb) ~= "function" then
    return
  end
  local success, err = pcall(cb, spell, callbackTarget, true)
  if not success and VanFW.Debug then
    VanFW:Debug("Spell callback error: " .. tostring(err), "Spells")
  end
end

function Spell:Cast(target, callback)
  if not self:Castable(target) then
    return false
  end

  local token = ""
  if target then
    if type(target) == "table" then
      token = target:GetToken() or ""
    else
      token = target
    end
  end

  if not _checkCastDelay() then
    return false
  end

  if not _executeCast(self, token) then
    if VanFW and VanFW.Debug then
      VanFW:Debug("ERROR: No cast method available or spell data missing! (ID: " .. tostring(self.id) .. ", Name: " .. tostring(self.name) .. ")", "Spells")
    end
    return false
  end

  _recordCast(self, target)
  _invokeCallback(self, callback or self.callback, target)

  return true
end

function Spell:SelfCast(callback)
  if not self:Castable() then
    return false
  end

  if not _checkCastDelay() then
    return false
  end

  if not _executeCast(self, "player") then
    VanFW:Debug("ERROR: No cast method available or spell data missing!", "Spells")
    return false
  end

  _recordCast(self, VanFW.player)
  _invokeCallback(self, callback or self.callback, VanFW.player)

  VanFW:Debug("SelfCast: " .. tostring(self.name), "Spells")

  return true
end

function Spell:AoECast(x, y, z, callback)
  if not self:Castable() then
    return false
  end

  if not _checkCastDelay() then
    return false
  end

  local spellKey = self.id or self.name
  if VanFW.pendingAoECasts and VanFW.pendingAoECasts[spellKey] then
    -- If no spell is pending (cursor gone), clear immediately
    if WGG_IsSpellPending and not WGG_IsSpellPending() then
      VanFW.pendingAoECasts[spellKey] = nil
      VanFW:Debug(string.format("Cleared pending AoE (no cursor): %s", spellKey), "Spells")
    else
      local timeSinceCast = GetTime() - VanFW.pendingAoECasts[spellKey]
      if timeSinceCast < 1.0 then
        return false
      end
    end
  end

  if type(x) == "table" then
    if x.Position then
      x, y, z = x:Position()
    elseif type(x[1]) == "number" then
      x, y, z = x[1], x[2], x[3]
    end
  end

  if not x or not y or not z then
    VanFW:Debug("AoECast: Invalid position", "Spells")
    return false
  end

  if not _executeCast(self, nil) then
    VanFW:Debug("ERROR: No cast method available or spell data missing!", "Spells")
    return false
  end

  _recordCast(self, nil)

  if not VanFW.pendingAoECasts then
    VanFW.pendingAoECasts = {}
  end
  VanFW.pendingAoECasts[spellKey] = GetTime()

  local cb = callback or self.callback

  C_Timer_After(0.15, function()
    -- Try SpellIsTargeting first, fallback to WGG_IsSpellPending if available
    local shouldClick = false
    if SpellIsTargeting and SpellIsTargeting() then
      shouldClick = true
    elseif WGG_IsSpellPending and WGG_IsSpellPending() then
      shouldClick = true
      VanFW:Debug("SpellIsTargeting false, but WGG_IsSpellPending true - clicking anyway", "Spells")
    end

    if shouldClick then
      WGG_Click(x, y, z)
      VanFW:Debug(string.format("Clicked at: %.1f, %.1f, %.1f", x, y, z), "Spells")
    else
      VanFW:Debug("No spell cursor detected - skipping click", "Spells")
    end

    -- Clear pending AoE cast after click (or attempted click)
    if VanFW.pendingAoECasts and VanFW.pendingAoECasts[spellKey] then
      VanFW.pendingAoECasts[spellKey] = nil
      VanFW:Debug(string.format("Cleared pending AoE cast: %s", spellKey), "Spells")
    end

    _invokeCallback(self, cb, {x=x, y=y, z=z})
  end)

  VanFW:Debug(string.format("AoECast: %s at %.1f, %.1f, %.1f", self.name, x, y, z), "Spells")

  return true
end

function Spell:PredictAoECast(target, time, leadTime, callback)
  if not target then
    VanFW:Debug("PredictAoECast: No target provided", "Spells")
    return false
  end

  time = time or 0.5
  leadTime = leadTime or 0

  local totalPrediction = time + leadTime

  local x, y, z = target:PredictPosition(totalPrediction)

  if not x then
    VanFW:Debug("PredictAoECast: Could not predict position", "Spells")
    return false
  end

  VanFW:Debug(string.format("Predicting %.2fs ahead for %s", totalPrediction, target:Name()), "Spells")

  return self:AoECast(x, y, z, callback)
end

function Spell:QueueCast(target, callback, priority)
  local queueEntry = {
    spell = self,
    target = target,
    callback = callback or self.callback,
    priority = priority or self.priority or 5,
    timestamp = VanFW.time,
  }

  VanFW:AddToSpellQueue(queueEntry)
  VanFW:Debug(string.format("Queued spell: %s (priority: %d)", self.name, queueEntry.priority), "SpellQueue")

  return true
end

function Spell:SetPriority(priority)
  self.priority = priority or 5
  return self
end

function Spell:SetCallback(callback)
  self.callback = callback
  return self
end

function Spell:GetPriority()
  return self.priority or 5
end


VanFW.lastCast = {
  spellID = 0,
  time = 0,
  target = nil,
}

function VanFW:UpdateLastCast(spellID, target)
  self.lastCast.spellID = spellID
  self.lastCast.time = self.time
  self.lastCast.target = target
end

function VanFW:TimeSinceLastCast(spellID)
  if spellID and self.lastCast.spellID ~= spellID then
    return 999
  end
  return self.time - self.lastCast.time
end

function VanFW:RecentlyCast(spellID, within)
  within = within or 0.5
  return self:TimeSinceLastCast(spellID) < within
end

function VanFW:InitializeSpells()
  self:Debug("Spell system initialized", "Spells")
end


function Spell:cd()
  return self:Cooldown()
end

function Spell:charges()
  local charges = self:Charges()
  return charges
end

function Spell:cooldown()
  return self:Cooldown()
end

function Spell:gcd()
  return VanFW:GetGCD()
end

function Spell:castTime()
  local _, _, _, castTime = GetSpellInfo(self.id)
  return (castTime or 0) / 1000
end

function Spell:range()
  return self.range or 40
end

function Spell:known()
  return IsSpellKnown(self.id, false) or IsPlayerSpell(self.id)
end

function Spell:usable()
  if C_Spell_IsSpellUsable then
    local usable, notEnoughMana = C_Spell_IsSpellUsable(self.id)
    return usable == true and not notEnoughMana
  elseif IsUsableSpell then
    local usable, noMana = IsUsableSpell(self.id)
    return usable and not noMana
  end
  return false
end
VanFW.Spell = Spell
