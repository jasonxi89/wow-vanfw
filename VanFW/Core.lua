local VanFW = VanFW or {}
_G.VanFW = VanFW

local GetTime = _G.GetTime
local UnitExists = _G.UnitExists
local UnitGUID = _G.UnitGUID
local C_Timer = _G.C_Timer
local CastSpellByID = _G.CastSpellByID
local C_Spell = _G.C_Spell
local C_Spell_GetSpellCooldown = C_Spell and C_Spell.GetSpellCooldown
local GetSpellCooldown = _G.GetSpellCooldown

-- Filter out Blizzard's CastingBarFrame errors (not caused by our addon)
local oldErrorHandler = geterrorhandler()
seterrorhandler(function(msg)
  -- Suppress CastingBarFrame SetValue errors (Blizzard bug with nameplate casting bars)
  if msg and type(msg) == "string" then
    if msg:find("CastingBarFrame%.lua") and msg:find("SetValue") then
      return -- Silently ignore this error
    end
    if msg:find("ADDON_ACTION_FORBIDDEN") and msg:find("<name>") then
      return -- Silently ignore generic addon forbidden errors
    end
  end
  -- Pass all other errors to the original handler
  return oldErrorHandler(msg)
end)

local math_sqrt = math.sqrt
local math_atan2 = math.atan2
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local math_abs = math.abs

VanFW.version = "1.0.0"
VanFW.name = "VanFW"
VanFW.loaded = false


VanFW.config = {
  tickRate = 0.1,
  cacheRefresh = 0.1,
  debug = false,
  objectUpdateRate = 0.05,
  targetSwap = false,
  targetSwapDelay = 0.5,
  spellCastDelay = 0.05,  -- 50ms
}


VanFW.time = GetTime()
VanFW.lastTick = 0
VanFW.deltaTime = 0
VanFW.lastSpellCastTime = 0


VanFWDB = VanFWDB or {}
VanFW.saved = VanFWDB


VanFW.colors = {
  red = "|cFFFF0000",
  green = "|cFF00FF00",
  blue = "|cFF0099FF",
  yellow = "|cFFFFFF00",
  orange = "|cFFFF8800",
  purple = "|cFFAA00FF",
  white = "|cFFFFFFFF",
  cyan = "|cFF00FFFF",
  reset = "|r"
}


function VanFW:Print(msg, color)
  color = color or self.colors.cyan
  print(color .. "[VanFW]" .. self.colors.reset .. " " .. msg)
end

function VanFW:Debug(msg, category)
  if not self.config.debug then return end
  category = category and "[" .. category .. "] " or ""
  print(self.colors.yellow .. "[Debug] " .. category .. self.colors.reset .. msg)
end

function VanFW:Error(msg)
  self:Print(msg, self.colors.red)
end

function VanFW:Success(msg)
  self:Print(msg, self.colors.green)
end


function VanFW:Distance3D(x1, y1, z1, x2, y2, z2)
  local dx = x2 - x1
  local dy = y2 - y1
  local dz = z2 - z1
  return math_sqrt(dx*dx + dy*dy + dz*dz)
end

function VanFW:Distance2D(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return math_sqrt(dx*dx + dy*dy)
end

function VanFW:AngleBetween(x1, y1, x2, y2)
  return math_atan2(y2 - y1, x2 - x1)
end

function VanFW:Clamp(value, min, max)
  return math_max(min, math_min(max, value))
end

function VanFW:Round(num, decimals)
  local mult = 10 ^ (decimals or 0)
  return math_floor(num * mult + 0.5) / mult
end


function VanFW:TableCount(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

function VanFW:TableCopy(tbl)
  local copy = {}
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      copy[k] = self:TableCopy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

function VanFW:TableContains(tbl, value)
  for _, v in pairs(tbl) do
    if v == value then return true end
  end
  return false
end


VanFW.callbacks = {
  onTick = {},
  onUpdate = {},
  onCombatStart = {},
  onCombatEnd = {},
  onTargetChanged = {},
}

function VanFW:RegisterCallback(event, callback)
  if not self.callbacks[event] then
    self:Error("Unknown callback event: " .. tostring(event))
    return
  end
  table.insert(self.callbacks[event], callback)
end

function VanFW:UnregisterCallback(event, callback)
  if not self.callbacks[event] then return end
  for i = #self.callbacks[event], 1, -1 do
    if self.callbacks[event][i] == callback then
      table.remove(self.callbacks[event], i)
      return true
    end
  end
  return false
end

function VanFW:FireCallbacks(event, ...)
  if not self.callbacks[event] then return end
  for _, callback in ipairs(self.callbacks[event]) do
    local success, err = pcall(callback, ...)
    if not success then
      self:Error("Callback error in " .. event .. ": " .. tostring(err))
    end
  end
end

function VanFW:OnTick(callback)
  self:RegisterCallback("onTick", callback)
end

function VanFW:OnUpdate(callback)
  self:RegisterCallback("onUpdate", callback)
end

function VanFW:OnCombatStart(callback)
  self:RegisterCallback("onCombatStart", callback)
end

function VanFW:OnCombatEnd(callback)
  self:RegisterCallback("onCombatEnd", callback)
end

function VanFW:OnTargetChanged(callback)
  self:RegisterCallback("onTargetChanged", callback)
end


VanFW.inCombat = false
VanFW.combatStart = 0
VanFW.combatDuration = 0

function VanFW:UpdateCombatState()
  local wasInCombat = self.inCombat
  self.inCombat = UnitAffectingCombat("player")

  if self.inCombat and not wasInCombat then
    self.combatStart = self.time
    self:FireCallbacks("onCombatStart")
  elseif not self.inCombat and wasInCombat then
    self.combatDuration = self.time - self.combatStart
    self:FireCallbacks("onCombatEnd")
  end

  if self.inCombat then
    self.combatDuration = self.time - self.combatStart
  end
end


VanFW.lastTarget = nil
VanFW.lastTargetSwap = 0

function VanFW:UpdateTarget()
  local currentTarget = UnitGUID("target")

  if currentTarget ~= self.lastTarget then
    self.lastTarget = currentTarget
    self.lastTargetSwap = self.time
    self:FireCallbacks("onTargetChanged", currentTarget)
  end
end


VanFW.gcdStart = 0
VanFW.gcdDuration = 0

function VanFW:GetGCD()
  local start, duration = 0, 0

  if C_Spell_GetSpellCooldown then
    local info = C_Spell_GetSpellCooldown(61304)  -- GCD spell ID
    if info then
      start = info.startTime or 0
      duration = info.duration or 0
    end
  elseif GetSpellCooldown then
    start, duration = GetSpellCooldown(61304)
  end

  if start and start > 0 then
    local remaining = duration - (GetTime() - start)
    return math_max(0, remaining)
  end
  return 0
end

function VanFW:IsGCDActive()
  return self:GetGCD() > 0
end

--procs
function VanFW:ProcActive(auraID, target)
  target = target or self.player
  if not target or not target.HasBuff then return false end

  local hasBuff, stacks, remaining = target:HasBuff(auraID)
  return hasBuff
end

function VanFW:ProcRemaining(auraID, target)
  target = target or self.player
  if not target or not target.BuffRemaining then return 0 end

  return target:BuffRemaining(auraID)
end

function VanFW:ProcStacks(auraID, target)
  target = target or self.player
  if not target or not target.BuffStacks then return 0 end

  return target:BuffStacks(auraID)
end

function VanFW:DebuffActive(auraID, target)
  target = target or self.target
  if not target or not target.HasDebuff then return false end

  local hasDebuff, stacks, remaining = target:HasDebuff(auraID)
  return hasDebuff
end

function VanFW:DebuffRemaining(auraID, target)
  target = target or self.target
  if not target or not target.DebuffRemaining then return 0 end

  return target:DebuffRemaining(auraID)
end

function VanFW:DebuffStacks(auraID, target)
  target = target or self.target
  if not target or not target.DebuffStacks then return 0 end

  return target:DebuffStacks(auraID)
end



VanFW.queuedSpell = nil
VanFW.queueTime = 0

function VanFW:QueueSpell(spellID, duration, priority)
  self.queuedSpell = spellID
  self.queueTime = self.time + (duration or 0.4)

  if priority then
    self:AddToSpellQueue({
      spell = { id = spellID, priority = priority },
      priority = priority,
      timestamp = self.time,
      duration = duration or 0.4,
    })
  end
end

function VanFW:ClearQueue()
  self.queuedSpell = nil
  self.queueTime = 0
end

function VanFW:IsSpellQueued()
  return self.queuedSpell ~= nil and self.time < self.queueTime
end

-- =============================================================================
-- LEGACY: SpellQueue System
-- This system is retained for backward compatibility. Rotation scripts may call
-- ClearSpellQueue() and IsSpellInQueue() but the full queue-driven casting
-- pipeline is no longer actively used. ProcessSpellQueue only clears expired
-- entries; it does not attempt to cast spells.
-- =============================================================================

VanFW.spellQueue = {}
VanFW.lastSpellCast = 0

function VanFW:AddToSpellQueue(queueEntry)
  if not queueEntry or not queueEntry.spell then
    self:Debug("Invalid queue entry", "SpellQueue")
    return false
  end

  for i, entry in ipairs(self.spellQueue) do
    if entry.spell.id == queueEntry.spell.id then
      if queueEntry.priority < entry.priority then
        entry.priority = queueEntry.priority
        entry.timestamp = self.time
        self:Debug(string.format("Updated queue entry priority: %s (priority: %d)",
          entry.spell.name or "Unknown", entry.priority), "SpellQueue")
      else
        self:Debug(string.format("Spell already in queue: %s", entry.spell.name or "Unknown"), "SpellQueue")
      end
      return false
    end
  end
  local inserted = false
  for i, entry in ipairs(self.spellQueue) do
    if queueEntry.priority < entry.priority then
      table.insert(self.spellQueue, i, queueEntry)
      inserted = true
      break
    end
  end

  if not inserted then
    table.insert(self.spellQueue, queueEntry)
  end

  self:Debug(string.format("Added to queue (position: %d, priority: %d)",
    self:GetQueuePosition(queueEntry), queueEntry.priority), "SpellQueue")

  return true
end

function VanFW:RemoveFromSpellQueue(index)
  if index and self.spellQueue[index] then
    local entry = table.remove(self.spellQueue, index)
    self:Debug(string.format("Removed from queue: %s", entry.spell.name or entry.spell.id), "SpellQueue")
    return entry
  end
  return nil
end

function VanFW:GetQueuePosition(queueEntry)
  for i, entry in ipairs(self.spellQueue) do
    if entry == queueEntry then
      return i
    end
  end
  return -1
end

function VanFW:GetNextQueuedSpell()
  if #self.spellQueue == 0 then
    return nil
  end
  return self.spellQueue[1]
end

function VanFW:IsSpellInQueue(spellID)
  if not spellID then return false end
  for _, entry in ipairs(self.spellQueue) do
    if entry.spell and entry.spell.id == spellID then
      return true
    end
  end
  return false
end

function VanFW:ClearSpellQueue()
  local count = #self.spellQueue
  self.spellQueue = {}
  self:Debug(string.format("Cleared spell queue (%d entries)", count), "SpellQueue")
end

function VanFW:ProcessSpellQueue()
  if #self.spellQueue == 0 then return false end

  -- Only clear expired entries; no longer attempts to cast spells
  for i = #self.spellQueue, 1, -1 do
    local entry = self.spellQueue[i]
    local maxAge = entry.maxAge or 5.0
    if (self.time - entry.timestamp) > maxAge then
      self:Debug(string.format("Queue entry expired: %s",
        entry.spell.name or entry.spell.id), "SpellQueue")
      table.remove(self.spellQueue, i)
    end
  end

  return false
end

function VanFW:GetSpellQueueSize()
  return #self.spellQueue
end
function VanFW:GetSpellQueueContents()
  local contents = {}
  for i, entry in ipairs(self.spellQueue) do
    table.insert(contents, {
      position = i,
      spellID = entry.spell.id,
      spellName = entry.spell.name,
      priority = entry.priority,
      age = self.time - entry.timestamp,
    })
  end
  return contents
end

function VanFW:PrintSpellQueue()
  if #self.spellQueue == 0 then
    self:Print("Spell queue is empty")
    return
  end

  self:Print(string.format("Spell Queue (%d entries):", #self.spellQueue))
  for i, entry in ipairs(self.spellQueue) do
    local age = self.time - entry.timestamp
    self:Print(string.format("  %d. %s (priority: %d, age: %.2fs)",
      i, entry.spell.name or entry.spell.id, entry.priority, age))
  end
end

function VanFW:SetSpellCastDelay(delay)
  delay = delay or 0.05
  self.config.spellCastDelay = delay
  self:Print(string.format("Spell cast delay set to %.0fms (taint protection)", delay * 1000))
end

VanFW.PowerTypes = {
  Mana = 0,
  Rage = 1,
  Focus = 2,
  Energy = 3,
  ComboPoints = 4,
  Runes = 5,
  RunicPower = 6,
  SoulShards = 7,
  LunarPower = 8,
  HolyPower = 9,
  Maelstrom = 11,
  Chi = 12,
  Insanity = 13,
  ArcaneCharges = 16,
  Fury = 17,
  Pain = 18,
}

SLASH_VANFW1 = "/vanfw"
SLASH_VANFW2 = "/vfw"

SlashCmdList["VANFW"] = function(msg)
  msg = string.lower(msg or "")

  if msg == "debug" then
    VanFW.config.debug = not VanFW.config.debug
    VanFW:Print("Debug: " .. (VanFW.config.debug and "ON" or "OFF"))

  elseif msg == "target" or msg == "targeting" then
    VanFW.config.targetSwap = not VanFW.config.targetSwap
    VanFW:Print("Smart Targeting: " .. (VanFW.config.targetSwap and "ON" or "OFF"))

  elseif msg == "guid" then
    VanFW:PrintGUIDCache()

  elseif msg == "info" then
    print(" ")
    VanFW:Print("Framework Info:")
    print("  Version: " .. tostring(VanFW.version))
    print("  Objects: " .. tostring(VanFW.objectCount))
    print("  Enemies: " .. tostring(#VanFW.objects.enemies))
    print("  Friends: " .. tostring(#VanFW.objects.friends))
    print("  In Combat: " .. tostring(VanFW.inCombat))
    print("  GUID Cache: " .. tostring(VanFW:TableCount(VanFW.guidToToken)) .. " units")
    print(" ")

  elseif msg == "help" then
    print(" ")
    VanFW:Print("Commands:")
    print("  /vanfw debug - Toggle debug mode")
    print("  /vanfw target - Toggle smart targeting")
    print("  /vanfw guid - Show GUID cache")
    print("  /vanfw info - Show framework info")
    print("  /vanfw help - Show this help")
    print(" ")
  else
    VanFW:Print("Type /vanfw help for commands")
  end
end

SLASH_ROT1 = "/rot"
SLASH_ROT2 = "/rotation"

SlashCmdList["ROT"] = function(msg)
  msg = string.lower(msg or "")

  if msg == "start" then
    if VanFW.Rota and VanFW.Rota.Start then
      VanFW.Rota.Start()
    else
      VanFW:Error("No rotation loaded! Use /reload to auto-detect your class/spec")
    end

  elseif msg == "stop" then
    if VanFW.Rota and VanFW.Rota.Stop then
      VanFW.Rota.Stop()
    else
      VanFW:Error("No rotation loaded!")
    end

  elseif msg == "" then
    -- Toggle rotation on/off
    if VanFW.Rota then
      if VanFW:IsRotationRunning() then
        VanFW.Rota.Stop()
      else
        VanFW.Rota.Start()
      end
    else
      VanFW:Error("No rotation loaded! Use /reload to auto-detect your class/spec")
    end

  elseif msg == "status" or msg == "info" then
    if VanFW.Rota then
      local running = VanFW:IsRotationRunning()
      print(" ")
      VanFW:Print("Rotation Status:")
      print("  Running: " .. (running and "YES" or "NO"))
      print("  Spell Cast Delay: " .. (VanFW.config.spellCastDelay * 1000) .. "ms")
      print("  Queue Size: " .. VanFW:GetSpellQueueSize())
      print(" ")
    else
      VanFW:Error("No rotation loaded!")
    end

  elseif msg:match("^delay%s+(%d+)") then
    local delayMs = tonumber(msg:match("^delay%s+(%d+)"))
    if delayMs then
      VanFW:SetSpellCastDelay(delayMs / 1000)
    end

  elseif msg == "help" then
    print(" ")
    VanFW:Print("Rotation Commands:")
    print("  /rot - Start rotation")
    print("  /rot start - Start rotation")
    print("  /rot stop - Stop rotation")
    print("  /rot status - Show rotation status")
    print("  /rot delay <ms> - Set cast delay (e.g. /rot delay 50)")
    print("  /rot help - Show this help")
    print(" ")
  else
    VanFW:Print("Type /rot help for commands")
  end
end

VanFW.registeredSlashCommands = {}

function VanFW:RegisterSlashCommand(command, handler)
  if not command or type(command) ~= "string" then
    self:Error("RegisterSlashCommand: Invalid command name")
    return false
  end

  if not handler or type(handler) ~= "function" then
    self:Error("RegisterSlashCommand: Invalid handler function")
    return false
  end

  local slashCmdName = "VANFW_" .. string.upper(command)
  _G["SLASH_" .. slashCmdName .. "1"] = "/" .. string.lower(command)
  _G.SlashCmdList[slashCmdName] = handler
  self.registeredSlashCommands[command] = true
  self:Debug("Registered slash command: /" .. command, "SlashCmd")
  return true
end


VanFW.configSystem = {
  encryptionKey = "VanFW_Secure_Key_2024",
  configPath = nil,
}

function VanFW:InitializeConfigSystem()
  local success, error = pcall(function()
    self:Print("Initializing config system...")
    local cfgDir = "C:\\WGG\\cfg"
    if not WGG_DirExists(cfgDir) then
      self:Print("Creating cfg directory...")
      if not WGG_CreateDir(cfgDir) then
        self:Error("Failed to create cfg directory!")
        return false
      end
    end

    self.configSystem.configPath = cfgDir .. "\\rotations.cfg"
    self:Print("Config path: " .. self.configSystem.configPath)
    if not WGG_FileExists(self.configSystem.configPath) then
      self:Print("Creating new config file...")
      local emptyConfig = WGG_AESEncrypt("{}", self.configSystem.encryptionKey)
      if not WGG_FileWrite(self.configSystem.configPath, emptyConfig) then
        self:Error("Failed to create config file!")
        return false
      end
      self:Print("Created new config file")
    end

    self:Success("Config system initialized!")
    return true
  end)

  if not success then
    self:Error("Config system error: " .. tostring(error))
    return false
  end

  return true
end

function VanFW:LoadRotationConfig(class, spec, rotation)
  if not self.configSystem.configPath then
    self:Debug("Config system not initialized", "Config")
    return nil
  end

  local configKey = class .. "_" .. spec .. "_" .. rotation

  local encryptedData = WGG_FileRead(self.configSystem.configPath)
  if not encryptedData or encryptedData == "" then
    self:Debug("Config file is empty", "Config")
    return nil
  end

  local decryptedData = WGG_AESDecrypt(encryptedData, self.configSystem.encryptionKey)
  if not decryptedData then
    self:Error("Failed to decrypt config file!")
    return nil
  end

  local success, configs = pcall(function()
    return self:DecodeJSON(decryptedData)
  end)

  if not success or not configs then
    self:Error("Failed to parse config JSON: " .. tostring(configs))
    return nil
  end

  return configs[configKey]
end

function VanFW:SaveRotationConfig(class, spec, rotation, config)
  if not self.configSystem.configPath then
    self:Debug("Config system not initialized", "Config")
    return false
  end

  local configKey = class .. "_" .. spec .. "_" .. rotation

  local configs = {}
  local encryptedData = WGG_FileRead(self.configSystem.configPath)
  if encryptedData and encryptedData ~= "" then
    local decryptedData = WGG_AESDecrypt(encryptedData, self.configSystem.encryptionKey)
    if decryptedData then
      local success, parsed = pcall(function()
        return self:DecodeJSON(decryptedData)
      end)
      if success and parsed then
        configs = parsed
      end
    end
  end

  configs[configKey] = config

  local jsonData = self:EncodeJSON(configs)
  if not jsonData then
    self:Error("Failed to encode config to JSON!")
    return false
  end

  local encrypted = WGG_AESEncrypt(jsonData, self.configSystem.encryptionKey)
  if not WGG_FileWrite(self.configSystem.configPath, encrypted) then
    self:Error("Failed to write config file!")
    return false
  end

  self:Debug("Saved config for " .. configKey, "Config")
  return true
end

function VanFW:EncodeJSON(data)
  return WGG_JsonEncode(data)
end

function VanFW:DecodeJSON(str)
  local tableStr = WGG_JsonDecode(str)
  if not tableStr then return nil end
  local fn, err = loadstring("return " .. tableStr)
  if not fn then
    self:Error("DecodeJSON loadstring failed: " .. tostring(err))
    return nil
  end
  return fn()
end


function VanFW:Initialize()
  if self.loaded then
    self:Debug("Already initialized")
    return
  end

  self:Print("Initializing v" .. tostring(self.version))

  if not self.hasWGG then
    self:Error("WGG API not found! Framework cannot initialize.")
    return
  end

  self:InitializeObjects()
  self:InitializeSpells()
  self:InitializeUnits()
  self:InitializeTargeting()
  self:InitializeConfigSystem()

  self:StartUpdateLoop()

  self.loaded = true
  self:Success("Framework loaded successfully!")

  if self.MCP and self.MCP.Initialize then
    C_Timer.After(0.1, function()
      self.MCP:Initialize()
    end)
  end
end


VanFW.updateFrame = CreateFrame("Frame")

function VanFW:StartUpdateLoop()
  self.updateFrame:SetScript("OnUpdate", function(_, elapsed)
    self:OnUpdateFrame(elapsed)
  end)
end

function VanFW:OnUpdateFrame(elapsed)
  self.time = GetTime()
  self.deltaTime = elapsed

  -- Process spell queue every frame for responsive spell casting
  self:ProcessSpellQueue()

  if self.time - self.lastTick >= self.config.tickRate then
    self.lastTick = self.time

    self:UpdateCombatState()
    self:UpdateTarget()
    self:UpdateObjects()
    self:UpdateSmartTargeting()

    self:FireCallbacks("onTick")
  end

  self:FireCallbacks("onUpdate", elapsed)
end
