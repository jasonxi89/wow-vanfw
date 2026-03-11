local VanFW = VanFW or {}
_G.VanFW = VanFW


VanFW.MCP = VanFW.MCP or {}
local MCP = VanFW.MCP


MCP.config = {
  enabled = true,
  bufferSize = 2000,
  exportInterval = 0.1,
  exportPath = "c:\\WGG\\MCP\\logs\\",
  exportFile = "vanfw_realtime.json",
  autoExportOnError = true,
  autoExportOnCombatEnd = true,
  maxFileSize = 10 * 1024 * 1024,
}


MCP.categories = {
  combat = { enabled = true, color = "|cFFFF0000"},
  spell = { enabled = true, color = "|cFF00FFFF"},
  object = { enabled = false, color = "|cFFFFFF00"},
  rotation = { enabled = true, color = "|cFF00FF00"},
  targeting = { enabled = true, color = "|cFFFF8800"},
  hekili = { enabled = true, color = "|cFFFF00FF"},
  error = { enabled = true, color = "|cFFFF0000" },
  warning = { enabled = true, color = "|cFFFFFF00" },
  info = { enabled = true, color = "|cFFFFFFFF"},
  performance = { enabled = false, color = "|cFFAA00FF"},
  debug = { enabled = false, color = "|cFF888888"},
}


MCP.buffer = {}
MCP.bufferIndex = 1
MCP.bufferWrapped = false
MCP.totalEvents = 0
MCP.sessionStart = 0
MCP.frameCounter = 0

function MCP:InitializeBuffer()
  self.buffer = {}
  self.bufferIndex = 1
  self.bufferWrapped = false
  self.totalEvents = 0
  self.sessionStart = GetTime()
  self.frameCounter = 0

  for i = 1, self.config.bufferSize do
    self.buffer[i] = nil
  end
end


function MCP:Log(category, message, data)
  if not self.config.enabled then return end

  local catConfig = self.categories[category]
  if not catConfig or not catConfig.enabled then return end

  local entry = {
    timestamp = GetTime(),
    frame = self.frameCounter,
    category = category,
    message = message,
    data = data,
    sessionTime = GetTime() - self.sessionStart,
  }
  self.buffer[self.bufferIndex] = entry
  self.bufferIndex = self.bufferIndex + 1
  self.totalEvents = self.totalEvents + 1
  if self.bufferIndex > self.config.bufferSize then
    self.bufferIndex = 1
    self.bufferWrapped = true
  end
  if self.realtimeEnabled and self.exportQueue then
    table.insert(self.exportQueue, entry)
  end
end


function MCP:Combat(message, data)
  self:Log("combat", message, data)
end

function MCP:Spell(message, data)
  self:Log("spell", message, data)
end

function MCP:Object(message, data)
  self:Log("object", message, data)
end

function MCP:Rotation(message, data)
  self:Log("rotation", message, data)
end

function MCP:Targeting(message, data)
  self:Log("targeting", message, data)
end

function MCP:Hekili(message, data)
  self:Log("hekili", message, data)
end

function MCP:Error(message, data)
  self:Log("error", message, data)
  if self.config.autoExportOnError then
    C_Timer.After(0.1, function()
      self:ExportBuffer("error_dump")
    end)
  end
end

function MCP:Warning(message, data)
  self:Log("warning", message, data)
end

function MCP:Info(message, data)
  self:Log("info", message, data)
end

function MCP:Performance(message, data)
  self:Log("performance", message, data)
end

function MCP:Debug(message, data)
  self:Log("debug", message, data)
end


function MCP:GetRecentLogs(count, category)
  count = count or 100
  local result = {}
  local entries = 0

  local idx = self.bufferIndex - 1
  if idx < 1 then
    idx = self.bufferWrapped and self.config.bufferSize or 0
  end

  while entries < count and idx > 0 do
    local entry = self.buffer[idx]
    if entry then
      if not category or entry.category == category then
        table.insert(result, 1, entry)
        entries = entries + 1
      end
    end

    idx = idx - 1
    if idx < 1 then
      if self.bufferWrapped then
        idx = self.config.bufferSize
      else
        break
      end
    end

    if idx == self.bufferIndex - 1 then
      break
    end
  end

  return result
end

function MCP:GetLogsByTimeRange(startTime, endTime)
  local result = {}

  for i = 1, self.config.bufferSize do
    local entry = self.buffer[i]
    if entry and entry.timestamp >= startTime and entry.timestamp <= endTime then
      table.insert(result, entry)
    end
  end

  table.sort(result, function(a, b) return a.timestamp < b.timestamp end)

  return result
end

function MCP:GetLogsByCategory(category, count)
  return self:GetRecentLogs(count or 100, category)
end

function MCP:GetStatistics()
  local stats = {
    totalEvents = self.totalEvents,
    bufferSize = self.config.bufferSize,
    bufferUsed = self.bufferWrapped and self.config.bufferSize or self.bufferIndex - 1,
    sessionDuration = GetTime() - self.sessionStart,
    frameCount = self.frameCounter,
    realtimeEnabled = self.realtimeEnabled or false,
    categories = {},
  }


  for i = 1, self.config.bufferSize do
    local entry = self.buffer[i]
    if entry then
      local cat = entry.category
      stats.categories[cat] = (stats.categories[cat] or 0) + 1
    end
  end

  return stats
end


function MCP:ExportBuffer(filename)
  if not _G.WGG_FileWrite then
    VanFW:Error("[MCP] WGG_FileWrite not available!")
    return false
  end

  filename = filename or "buffer_dump"
  local timestamp = date("%Y%m%d_%H%M%S")
  local fullPath = self.config.exportPath .. filename .. "_" .. timestamp .. ".json"
  if not _G.WGG_FileExists(self.config.exportPath) then
    VanFW:Warning("[MCP] Export path does not exist: " .. self.config.exportPath)
  end
  local logs = {}
  local startIdx = self.bufferWrapped and self.bufferIndex or 1
  local count = 0

  for i = 0, self.config.bufferSize - 1 do
    local idx = startIdx + i
    if idx > self.config.bufferSize then
      idx = idx - self.config.bufferSize
    end

    local entry = self.buffer[idx]
    if entry then
      table.insert(logs, entry)
      count = count + 1
    end
  end

  local export = {
    meta = {
      exportTime = GetTime(),
      sessionStart = self.sessionStart,
      totalEvents = self.totalEvents,
      exportedEvents = count,
      version = VanFW.version or "unknown",
    },
    statistics = self:GetStatistics(),
    logs = logs,
  }

  local json = self:EncodeJSON(export)
  local success = _G.WGG_FileWrite(fullPath, json)

  if success then
    VanFW:Success("[MCP] Exported " .. count .. " logs to: " .. fullPath)
    return true, fullPath
  else
    VanFW:Error("[MCP] Failed to export logs!")
    return false
  end
end

MCP.realtimeEnabled = false
MCP.exportQueue = {}
MCP.lastExport = 0
MCP.persistentLogs = {}

function MCP:EnableRealtime()
  if self.realtimeEnabled then
    VanFW:Warning("[MCP] Realtime logging already enabled")
    return
  end

  self.realtimeEnabled = true
  self.exportQueue = {}
  self.persistentLogs = {}
  self.lastExport = GetTime()

  VanFW:Success("[MCP] Realtime logging enabled")
end

function MCP:DisableRealtime()
  if not self.realtimeEnabled then
    return
  end

  self.realtimeEnabled = false
  self.exportQueue = {}

  VanFW:Success("[MCP] Realtime logging disabled")
end

function MCP:ProcessRealtimeExport()
  if not self.realtimeEnabled then return end

  local currentTime = GetTime()
  if currentTime - self.lastExport < self.config.exportInterval then
    return
  end

  if #self.exportQueue == 0 then
    return
  end
  local fullPath = self.config.exportPath .. self.config.exportFile
  if _G.WGG_FileWrite then
    for _, log in ipairs(self.exportQueue) do
      table.insert(self.persistentLogs, log)
    end
    if #self.persistentLogs > 2000 then
      local newLogs = {}
      local startIdx = #self.persistentLogs - 2000 + 1
      for i = startIdx, #self.persistentLogs do
        table.insert(newLogs, self.persistentLogs[i])
      end
      self.persistentLogs = newLogs
    end
    local export = {
      timestamp = currentTime,
      totalLogs = #self.persistentLogs,
      logs = self.persistentLogs,
    }

    local json = self:EncodeJSON(export)
    _G.WGG_FileWrite(fullPath, json)
  end
  self.exportQueue = {}
  self.lastExport = currentTime
end

function MCP:EncodeJSON(tbl, indent)
  indent = indent or 0
  local indentStr = string.rep("  ", indent)
  local result = {}

  if type(tbl) ~= "table" then
    if type(tbl) == "string" then
      return '"' .. tbl:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
    elseif type(tbl) == "number" or type(tbl) == "boolean" then
      return tostring(tbl)
    elseif tbl == nil then
      return "null"
    else
      return '""'
    end
  end
  local isArray = true
  local count = 0
  for k, v in pairs(tbl) do
    count = count + 1
    if type(k) ~= "number" or k ~= count then
      isArray = false
      break
    end
  end

  if isArray then
    table.insert(result, "[")
    for i, v in ipairs(tbl) do
      if i > 1 then table.insert(result, ",") end
      table.insert(result, "\n" .. indentStr .. "  ")
      table.insert(result, self:EncodeJSON(v, indent + 1))
    end
    if #tbl > 0 then
      table.insert(result, "\n" .. indentStr)
    end
    table.insert(result, "]")
  else
    table.insert(result, "{")
    local first = true
    for k, v in pairs(tbl) do
      if not first then table.insert(result, ",") end
      first = false
      table.insert(result, "\n" .. indentStr .. "  ")
      table.insert(result, '"' .. tostring(k) .. '": ')
      table.insert(result, self:EncodeJSON(v, indent + 1))
    end
    if not first then
      table.insert(result, "\n" .. indentStr)
    end
    table.insert(result, "}")
  end

  return table.concat(result)
end

function MCP:HookCombatEvents()
  if not VanFW.RegisterCallback then return end

  VanFW:RegisterCallback("onCombatStart", function()
    self:Combat("Combat started", {
      playerHP = UnitHealth("player") or 0,
      playerMaxHP = UnitHealthMax("player") or 0,
      enemies = VanFW.objects and #VanFW.objects.enemies or 0,
    })
  end)

  VanFW:RegisterCallback("onCombatEnd", function()
    local duration = VanFW.combatDuration or 0
    self:Combat("Combat ended", {
      duration = duration,
      playerHP = UnitHealth("player") or 0,
    })

    if self.config.autoExportOnCombatEnd then
      C_Timer.After(0.5, function()
        self:ExportBuffer("combat_log")
      end)
    end
  end)

  VanFW:RegisterCallback("onTargetChanged", function(guid)
    if not guid then return end

    self:Targeting("Target changed", {
      guid = guid,
      name = UnitName("target") or "Unknown",
      health = UnitHealth("target") or 0,
    })
  end)
end

function MCP:HookSpellCasts()
  local originalAddToQueue = VanFW.AddToSpellQueue
  if originalAddToQueue then
    VanFW.AddToSpellQueue = function(self, queueEntry)
      if queueEntry and queueEntry.spell then
        MCP:Spell("Spell queued", {
          spellID = queueEntry.spell.id,
          spellName = queueEntry.spell.name,
          priority = queueEntry.priority,
          target = queueEntry.target and queueEntry.target:GetName() or "none",
          queueSize = #VanFW.spellQueue,
        })
      end
      return originalAddToQueue(self, queueEntry)
    end
  end

  local originalProcessQueue = VanFW.ProcessSpellQueue
  if originalProcessQueue then
    VanFW.ProcessSpellQueue = function(self)
      local result = originalProcessQueue(self)
      if result then
        local spell = self.spellQueue[1]
        if spell then
          MCP:Spell("Spell cast from queue", {
            spellID = spell.spell.id,
            spellName = spell.spell.name,
            success = true,
          })
        end
      end
      return result
    end
  end
end


function MCP:HookRotationSystem()
  if VanFW.Rota then
    local originalStart = VanFW.Rota.Start
    local originalStop = VanFW.Rota.Stop

    if originalStart then
      VanFW.Rota.Start = function()
        MCP:Rotation("Rotation started", {
          class = CurrentLoadedSpec and CurrentLoadedSpec.class or "unknown",
          spec = CurrentLoadedSpec and CurrentLoadedSpec.spec or "unknown",
        })
        return originalStart()
      end
    end

    if originalStop then
      VanFW.Rota.Stop = function()
        MCP:Rotation("Rotation stopped", {
          class = CurrentLoadedSpec and CurrentLoadedSpec.class or "unknown",
          spec = CurrentLoadedSpec and CurrentLoadedSpec.spec or "unknown",
        })
        return originalStop()
      end
    end
  end
end

function MCP:HookErrorHandling()
  local originalError = VanFW.Error
  if originalError then
    VanFW.Error = function(self, msg)
      MCP:Error("VanFW Error", {
        message = msg,
        stack = debugstack and debugstack(2) or "no stack",
      })
      return originalError(self, msg)
    end
  end

  local originalOnError = geterrorhandler()
  seterrorhandler(function(msg)
    MCP:Error("Lua Error", {
      message = tostring(msg),
      stack = debugstack and debugstack(2) or "no stack",
    })
    return originalOnError(msg)
  end)
end

function MCP:HookTargetingSystem()
  if VanFW.RegisterCallback then
    VanFW:RegisterCallback("onTargetChanged", function(guid)
      if not guid then return end

      local target = VanFW.target
      MCP:Targeting("Target changed", {
        guid = guid,
        name = UnitName("target") or "Unknown",
        health = UnitHealth("target") or 0,
        healthPercent = target and target.hp or 0,
        distance = target and target.distance or 999,
        inCombat = UnitAffectingCombat("target") or false,
      })
    end)
  end
end

function MCP:CapturePlayerStats()
  local playerStats = {
    name = UnitName("player") or "Unknown",
    class = UnitClass("player") or "Unknown",
    level = UnitLevel("player") or 0,
    hp = UnitHealth("player") or 0,
    hpMax = UnitHealthMax("player") or 0,
    hpPercent = (UnitHealth("player") or 0) / math.max((UnitHealthMax("player") or 1), 1) * 100,
    power = UnitPower("player") or 0,
    powerMax = UnitPowerMax("player") or 0,
    powerType = UnitPowerType("player") or 0,
    powerPercent = (UnitPower("player") or 0) / math.max((UnitPowerMax("player") or 1), 1) * 100,
    comboPoints = UnitPower("player", 4) or 0,
    soulShards = UnitPower("player", 7) or 0,
    holyPower = UnitPower("player", 9) or 0,
    insanity = UnitPower("player", 13) or 0,
    x = 0, y = 0, z = 0,
    facing = 0,
    moving = false,
    inCombat = UnitAffectingCombat("player") or false,
    casting = false,
    channeling = false,
    dead = UnitIsDead("player") or false,
    mounted = IsMounted() or false,
  }

  if VanFW.player then
    playerStats.x = VanFW.player.x or 0
    playerStats.y = VanFW.player.y or 0
    playerStats.z = VanFW.player.z or 0
    playerStats.facing = VanFW.player.facing or 0
    playerStats.moving = VanFW.player.moving or false
    playerStats.casting = VanFW.player.casting or false
  end

  return playerStats
end

function MCP:CaptureTargetStats()
  if not UnitExists("target") then
    return nil
  end

  local targetStats = {
    name = UnitName("target") or "Unknown",
    guid = UnitGUID("target") or "none",
    class = UnitClass("target") or "Unknown",
    level = UnitLevel("target") or 0,
    classification = UnitClassification("target") or "normal",
    hp = UnitHealth("target") or 0,
    hpMax = UnitHealthMax("target") or 0,
    hpPercent = (UnitHealth("target") or 0) / math.max((UnitHealthMax("target") or 1), 1) * 100,
    distance = 999,
    x = 0, y = 0, z = 0,
    inCombat = UnitAffectingCombat("target") or false,
    casting = false,
    canAttack = UnitCanAttack("player", "target") or false,
    isPlayer = UnitIsPlayer("target") or false,
    isBoss = UnitClassification("target") == "worldboss",
    dead = UnitIsDead("target") or false,
    isVisible = UnitIsVisible("target") or false,
    inLineOfSight = false,
    castingSpell = nil,
    castingSpellID = nil,
    castTimeLeft = 0,
    isInterruptible = false,
  }
  if VanFW.target then
    targetStats.distance = VanFW.target.distance or 999
    targetStats.x = VanFW.target.x or 0
    targetStats.y = VanFW.target.y or 0
    targetStats.z = VanFW.target.z or 0
    targetStats.casting = VanFW.target.casting or false
  end
  if targetStats.distance == 999 and VanFW.player and targetStats.x ~= 0 and targetStats.y ~= 0 then
    local px, py = VanFW.player.x or 0, VanFW.player.y or 0
    if px ~= 0 and py ~= 0 then
      local dx = targetStats.x - px
      local dy = targetStats.y - py
      targetStats.distance = math.sqrt(dx * dx + dy * dy)
    end
  end

  if _G.WGG_TraceLine and VanFW.player and targetStats.x ~= 0 then
    local px, py, pz = VanFW.player.x or 0, VanFW.player.y or 0, VanFW.player.z or 0
    if px ~= 0 and py ~= 0 then
      local playerEyeZ = pz + 2
      local targetEyeZ = targetStats.z + 2

      local hasLoS = _G.WGG_TraceLine(px, py, playerEyeZ, targetStats.x, targetStats.y, targetEyeZ, 0x100111)
      targetStats.inLineOfSight = not hasLoS
    end
  end

  local castingSpell, _, _, _, startTime, endTime, _, _, notInterruptible = UnitCastingInfo("target")
  if castingSpell then
    targetStats.castingSpell = castingSpell
    if type(endTime) == "number" then
      targetStats.castTimeLeft = (endTime - GetTime() * 1000) / 1000
    else
      targetStats.castTimeLeft = 0
    end
    targetStats.isInterruptible = not notInterruptible
  else
    local channelingSpell, _, _, _, startTimeCh, endTimeCh, _, notInterruptibleCh = UnitChannelInfo("target")
    if channelingSpell then
      targetStats.castingSpell = channelingSpell
      if type(endTimeCh) == "number" then
        targetStats.castTimeLeft = (endTimeCh - GetTime() * 1000) / 1000
      else
        targetStats.castTimeLeft = 0
      end
      targetStats.isInterruptible = not notInterruptibleCh
    end
  end

  return targetStats
end

function MCP:CaptureVanKiliState()
  if not VanFW.VanKili then
    return nil
  end

  local kiliState = {
    isAvailable = VanFW.VanKili.isAvailable or false,
    currentRecommendation = nil,
    queueSize = 0,
    queueDepth = VanFW.VanKili.config and VanFW.VanKili.config.queueDepth or 3,
    config = {
      autoTarget = VanFW.VanKili.config and VanFW.VanKili.config.autoTarget or false,
      targetRange = VanFW.VanKili.config and VanFW.VanKili.config.targetRange or 40,
    },
  }
  if VanFW.VanKili.currentRecommendation then
    local rec = VanFW.VanKili.currentRecommendation
    kiliState.currentRecommendation = {
      spellID = rec.spellID or 0,
      spellName = rec.spellName or "Unknown",
      priority = rec.priority or 0,
      target = rec.target or "none",
    }
  end
  if VanFW.VanKili.queue then
    kiliState.queueSize = #VanFW.VanKili.queue
    kiliState.queue = {}
    for _, entry in ipairs(VanFW.VanKili.queue) do
      table.insert(kiliState.queue, {
        spellID = entry.spellID or 0,
        spellName = entry.spellName or "Unknown",
        priority = entry.priority or 0,
      })
    end
  end

  return kiliState
end

function MCP:CaptureCombatState()
  if not VanFW.inCombat then return end
  local player = VanFW.player
  if not player then return end
  local playerStats = self:CapturePlayerStats()
  local targetStats = self:CaptureTargetStats()
  local kiliState = self:CaptureVanKiliState()
  local allDisplayRecs = nil
  if self.frameCounter % 10 == 0 then
    allDisplayRecs = self:CaptureAllDisplayRecommendations()
  end
  self:Debug("Combat state", {
    player = {
      hp = playerStats.hp,
      hpMax = playerStats.hpMax,
      hpPercent = playerStats.hpPercent,
      power = playerStats.power,
      powerMax = playerStats.powerMax,
      powerType = playerStats.powerType,
      powerPercent = playerStats.powerPercent,
      comboPoints = playerStats.comboPoints,
      casting = playerStats.casting,
      moving = playerStats.moving,
      position = { x = playerStats.x, y = playerStats.y, z = playerStats.z },
    },
    target = targetStats and {
      name = targetStats.name,
      hp = targetStats.hp,
      hpMax = targetStats.hpMax,
      hpPercent = targetStats.hpPercent,
      distance = targetStats.distance,
      casting = targetStats.casting,
      classification = targetStats.classification,
      isBoss = targetStats.isBoss,
      isVisible = targetStats.isVisible,
      inLineOfSight = targetStats.inLineOfSight,
      castingSpell = targetStats.castingSpell,
      castTimeLeft = targetStats.castTimeLeft,
      isInterruptible = targetStats.isInterruptible,
    } or nil,
    vankili = kiliState,
    displayRecommendations = allDisplayRecs,
    spellQueue = {
      size = #VanFW.spellQueue,
      gcdActive = VanFW:IsGCDActive(),
    },
    combatDuration = VanFW.combatDuration or 0,
  })
end

function MCP:CaptureAllDisplayRecommendations()
  if not VanFW.VanKili or not VanFW.VanKili.State.isAvailable then
    return nil
  end

  local displays = {
    "Interrupts",
    "Defensives",
    "Cooldowns",
    "Primary",
    "AOE",
  }

  local allRecommendations = {}
  local hasInterrupt = false
  local hasDefensive = false
  local hasCooldown = false
  local targetStats = self:CaptureTargetStats()
  for _, display in ipairs(displays) do
    local rec = VanFW.VanKili:GetRecommendation(display, 1)
    if rec and rec.abilityID then
      local recData = {
        display = display,
        abilityID = rec.abilityID,
        spellName = rec.spellName or "Unknown",
        empowerLevel = rec.empowerLevel,
      }
      table.insert(allRecommendations, recData)
      if display == "Interrupts" then
        hasInterrupt = true
        if targetStats and targetStats.castingSpell then
          self:Warning("Interrupt available!", {
            interruptSpell = rec.spellName,
            interruptID = rec.abilityID,
            targetCasting = targetStats.castingSpell,
            targetCastTimeLeft = targetStats.castTimeLeft,
            targetInterruptible = targetStats.isInterruptible,
            targetDistance = targetStats.distance,
            targetLoS = targetStats.inLineOfSight,
          })
        end
      elseif display == "Defensives" then
        hasDefensive = true
      elseif display == "Cooldowns" then
        hasCooldown = true
      end
    end
  end

  if hasInterrupt or hasDefensive or hasCooldown then
    self:Hekili("Display overview", {
      hasInterrupt = hasInterrupt,
      hasDefensive = hasDefensive,
      hasCooldown = hasCooldown,
      totalDisplays = #allRecommendations,
      recommendations = allRecommendations,
      targetCasting = targetStats and targetStats.castingSpell or nil,
      targetInterruptible = targetStats and targetStats.isInterruptible or false,
    })
  end

  return allRecommendations
end

function MCP:HookVanKili()
  if not VanFW.VanKili then
    self:Warning("VanKili not loaded, skipping hook")
    return
  end
  local originalGetRecommendation = VanFW.VanKili.GetRecommendation
  if originalGetRecommendation then
    VanFW.VanKili.GetRecommendation = function(kiliSelf, display, position)
      local recommendation = originalGetRecommendation(kiliSelf, display, position)

      if recommendation then
        local targetCache = kiliSelf.State and kiliSelf.State.targetCache or {}

        MCP:Rotation("VanKili recommendation", {
          display = display or "Primary",
          position = position or 1,
          abilityID = recommendation.abilityID or 0,
          spellName = recommendation.spellName or "Unknown",
          empowerLevel = recommendation.empowerLevel,
          targetUnit = recommendation.targetUnit or "none",
          targetGUID = recommendation.targetGUID or "none",
          timestamp = recommendation.timestamp or 0,
          targetExists = targetCache.exists or false,
          targetDead = targetCache.dead or false,
          targetDistance = targetCache.distance or 999,
        })
      end

      return recommendation
    end
  end

  local originalCastRecommendation = VanFW.VanKili.CastRecommendation
  if originalCastRecommendation then
    VanFW.VanKili.CastRecommendation = function(kiliSelf, recommendation)
      if recommendation then
        local targetStats = MCP:CaptureTargetStats()
        local canCastNow = kiliSelf:CanCastNow()
        local isTargetInRange = kiliSelf:IsTargetInRange()

        MCP:Spell("VanKili casting", {
          display = recommendation.display or "Unknown",
          abilityID = recommendation.abilityID or 0,
          spellName = recommendation.spellName or "Unknown",
          empowerLevel = recommendation.empowerLevel,
          targetUnit = recommendation.targetUnit or "none",
          canCastNow = canCastNow,
          isTargetInRange = isTargetInRange,
          targetDistance = targetStats and targetStats.distance or 999,
          targetVisible = targetStats and targetStats.isVisible or false,
          targetLoS = targetStats and targetStats.inLineOfSight or false,
        })
      end

      local result = originalCastRecommendation(kiliSelf, recommendation)

      if result then
        MCP:Spell("VanKili cast success", {
          spellName = recommendation.spellName or "Unknown",
          abilityID = recommendation.abilityID or 0,
          display = recommendation.display or "Unknown",
        })
      else
        local targetStats = MCP:CaptureTargetStats()
        local failureReasons = {}

        if not kiliSelf:CanCastNow() then
          table.insert(failureReasons, "cast_delay_active")
        end

        if not kiliSelf:IsTargetInRange() then
          table.insert(failureReasons, "target_out_of_range")
        end

        if targetStats then
          if not targetStats.isVisible then
            table.insert(failureReasons, "target_not_visible")
          end
          if not targetStats.inLineOfSight then
            table.insert(failureReasons, "no_line_of_sight")
          end
          if targetStats.dead then
            table.insert(failureReasons, "target_dead")
          end
        else
          table.insert(failureReasons, "no_target")
        end

        MCP:Debug("VanKili cast failed", {
          spellName = recommendation.spellName or "Unknown",
          abilityID = recommendation.abilityID or 0,
          display = recommendation.display or "Unknown",
          reasons = failureReasons,
          targetDistance = targetStats and targetStats.distance or 999,
          targetVisible = targetStats and targetStats.isVisible or false,
          targetLoS = targetStats and targetStats.inLineOfSight or false,
        })
      end

      return result
    end
  end
  local originalPushToQueue = VanFW.VanKili.PushToQueue
  if originalPushToQueue then
    VanFW.VanKili.PushToQueue = function(kiliSelf, entry)
      if entry then
        MCP:Rotation("VanKili queue push", {
          spellID = entry.spellID or 0,
          spellName = entry.spellName or "Unknown",
          priority = entry.priority or 0,
          queueSize = #(kiliSelf.queue or {}),
        })
      end

      return originalPushToQueue(kiliSelf, entry)
    end
  end

  self:Info("VanKili hooks installed (with display tracking)")
end

function MCP:OnUpdate(elapsed)
  self.frameCounter = self.frameCounter + 1
  self:ProcessRealtimeExport()
end

function MCP:RegisterCommands()
  SLASH_MCP1 = "/mcp"

  SlashCmdList["MCP"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
      table.insert(args, string.lower(word))
    end

    local cmd = args[1] or "status"

    if cmd == "start" or cmd == "on" then
      self.config.enabled = true
      self:EnableRealtime()
      VanFW:Success("[MCP] Logging started (realtime enabled)")

    elseif cmd == "stop" or cmd == "off" then
      self:DisableRealtime()
      self.config.enabled = false
      print("[MCP] Logging stopped")

    elseif cmd == "status" or cmd == "info" or cmd == "" then
      local stats = self:GetStatistics()
      print(" ")
      VanFW:Print("MCP Logger Statistics:")
      print("  Total Events: " .. stats.totalEvents)
      print("  Buffer Used: " .. stats.bufferUsed .. "/" .. stats.bufferSize)
      print("  Session Duration: " .. string.format("%.1f", stats.sessionDuration) .. "s")
      print("  Frame Count: " .. stats.frameCount)
      print("  Realtime: " .. (stats.realtimeEnabled and "ON" or "OFF"))
      print(" ")
      print("  Events by Category:")
      for cat, count in pairs(stats.categories) do
        local cfg = self.categories[cat]
        local icon = cfg and cfg.icon or "·"
        print("    " .. icon .. " " .. cat .. ": " .. count)
      end
      print(" ")

    else
      print(" ")
      VanFW:Print("MCP Logger Commands:")
      print("  /mcp start  - Start logging (enable realtime)")
      print("  /mcp stop   - Stop logging")
      print("  /mcp status - Show status (default)")
      print(" ")
    end
  end
end

function MCP:Initialize()
  VanFW:Print("Initializing MCP Logger...")
  self:InitializeBuffer()
  self:RegisterCommands()
  self:HookCombatEvents()
  self:HookSpellCasts()
  self:HookErrorHandling()
  self:HookTargetingSystem()
  C_Timer.After(2.0, function()
    self:HookRotationSystem()
    self:HookVanKili()
  end)
  if VanFW.RegisterCallback then
    VanFW:RegisterCallback("onUpdate", function(elapsed)
      self:OnUpdate(elapsed)
    end)
  end

  self.categories.debug.enabled = true

  -- Auto-enable realtime logging on init
  self:EnableRealtime()

  self:Info("MCP Logger initialized", {
    bufferSize = self.config.bufferSize,
    exportPath = self.config.exportPath,
    hooks = {
      combat = true,
      spells = true,
      errors = true,
      targeting = true,
      rotation = "delayed",
      vankili = "delayed",
    },
    features = {
      playerStats = true,
      targetStats = true,
      vanKiliIntegration = true,
      realtimeHP = true,
      hekiliDisplayTracking = true,
      interruptDetection = true,
    },
    categories = {
      combat = true,
      spell = true,
      rotation = true,
      targeting = true,
      hekili = true,
      debug = true,
    },
  })

  VanFW:Success("MCP Logger ready! /mcp start to begin logging")
end

