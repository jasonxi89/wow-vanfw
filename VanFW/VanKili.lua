if not _G.VanFW then
    print("|cFFFF0000[VanFW]|r VanKili requires VanFW to be loaded first")
    return
end

local VanFW = _G.VanFW
VanFW.VanKili = VanFW.VanKili or {}
local VanKili = VanFW.VanKili

VanKili.Config = {
    primaryDisplay = "Primary",
    aoeDisplay = "AOE",
    cooldownsDisplay = "Cooldowns",
    defensivesDisplay = "Defensives",
    interruptsDisplay = "Interrupts",
    queueDepth = 5,
    castDelayMin = 0.08,
    castDelayMax = 0.2,
    autoTarget = true,
    targetRange = 10,
    targetSwitchRange = 8,
    preferLowHealth = true,
    ignoreTargetsAbove = 100,
    targetScanInterval = 0.25,
    debug = false,
}


VanKili.State = {
    isAvailable = false,
    lastUpdate = 0,
    updateInterval = 0.1,

    currentRecommendation = nil,
    lastCastAbility = nil,
    lastCastTime = 0,
    lastCastStart = 0,

    queue = {},
    targetCache = {
        token = nil,
        pointer = nil,
        guid = nil,
        exists = false,
        dead = false,
        distance = 0,
        health = 0,
        lastUpdate = 0,
        updateInterval = 0.05,
    },

    playerCache = {
        x = 0,
        y = 0,
        z = 0,
        inCombat = false,
        casting = false,
        lastUpdate = 0,
        updateInterval = 0.05,
    },

    targetScanCache = {
        bestTarget = nil,
        bestTargetPointer = nil,
        bestTargetGUID = nil,
        lastScanTime = 0,
        potentialTargets = {},
    },
}


function VanKili:UpdateTargetCache()
    local currentTime = GetTime()
    local cache = self.State.targetCache

    if currentTime - cache.lastUpdate < cache.updateInterval then
        return
    end

    cache.lastUpdate = currentTime
    cache.exists = UnitExists("target")

    if not cache.exists then
        cache.token = nil
        cache.pointer = nil
        cache.guid = nil
        cache.dead = true
        cache.distance = 999
        cache.health = 0
        return
    end

    cache.token = "target"
    cache.guid = UnitGUID("target")
    cache.dead = UnitIsDead("target")

    if VanFW.target and VanFW.target.Distance then
        local dist = VanFW.target:Distance()
        if dist then
            cache.distance = dist
        end
    end

    local maxHealth = UnitHealthMax("target")
    if maxHealth and maxHealth > 0 then
        cache.health = (UnitHealth("target") / maxHealth) * 100
    end
end

function VanKili:UpdatePlayerCache()
    local currentTime = GetTime()
    local cache = self.State.playerCache

    if currentTime - cache.lastUpdate < cache.updateInterval then
        return
    end

    cache.lastUpdate = currentTime
    cache.inCombat = UnitAffectingCombat("player")
    cache.casting = UnitCastingInfo("player") ~= nil or UnitChannelInfo("player") ~= nil

    if VanFW.GetPlayerPosition then
        local x, y, z = VanFW.GetPlayerPosition()
        if x then
            cache.x = x
            cache.y = y
            cache.z = z
        end
    end
end

function VanKili:IsHekiliLoaded()
    return _G.Hekili ~= nil and _G.Hekili_GetRecommendedAbility ~= nil
end

function VanKili:Initialize()
    if not self:IsHekiliLoaded() then
        if self.Config.debug then
            print("|cFFFF0000[VanFW.VanKili]|r Hekili addon not detected")
        end
        self.State.isAvailable = false
        return false
    end

    self.State.isAvailable = true
    print("|cFF00FF00[VanFW.VanKili]|r Integration initialized successfully")

    return true
end

function VanKili:GetRecommendation(display, position)
    if not self.State.isAvailable then
        return nil
    end

    display = display or self.Config.primaryDisplay
    position = position or 1

    local abilityID, empowerLevel, payload = _G.Hekili_GetRecommendedAbility(display, position)

    if not abilityID then
        return nil
    end

    local spellName = nil
    if C_Spell and C_Spell.GetSpellName then
        spellName = C_Spell.GetSpellName(abilityID)
    end

    if not spellName and abilityID < 0 then
        spellName = "Virtual Ability " .. math.abs(abilityID)
    end
    local targetUnit = nil
    local targetGUID = nil
    if payload then
        if type(payload) == "table" then
            targetUnit = payload.unit or payload.target_unit
            targetGUID = payload.guid or payload.target_guid
        end
    end

    return {
        abilityID = abilityID,
        spellName = spellName,
        empowerLevel = empowerLevel,
        payload = payload,
        display = display,
        position = position,
        timestamp = GetTime(),
        targetUnit = targetUnit,
        targetGUID = targetGUID,
    }
end

function VanKili:GetCurrentRecommendation()
    return self:GetRecommendation(self.Config.primaryDisplay, 1)
end

function VanKili:CanCastNow()
    local currentTime = GetTime()
    local delay = self.Config.castDelayMin
    if _G.WGG_Rand then
        delay = _G.math.random(self.Config.castDelayMin, self.Config.castDelayMax)
    end

    return (currentTime - self.State.lastCastTime) >= delay
end

function VanKili:IsTargetInRange()
    local cache = self.State.targetCache

    if not cache.exists or cache.dead then
        return false
    end

    local maxCastRange = self.Config.targetRange + 35

    if cache.distance > maxCastRange then
        return false
    end

    return true
end

function VanKili:StopCasting()
    if _G.SpellStopCasting then
        pcall(_G.SpellStopCasting)
        if self.Config.debug then
            print("|cFFFFFF00[VanKili]|r Stopped casting - target out of range")
        end
        return true
    end
    return false
end

function VanKili:CastRecommendation(recommendation)
    if not recommendation then
        return false
    end

    local spellName = recommendation.spellName or "Unknown"
    local abilityID = recommendation.abilityID or 0
    local failureReasons = {}

    if not self:CanCastNow() then
        table.insert(failureReasons, "cannot_cast_now")
        if _G.VanFW.MCP then
            _G.VanFW.MCP:Spell("VanKili cast BLOCKED", {
                spellName = spellName,
                abilityID = abilityID,
                reason = "cannot_cast_now"
            })
        end
        return false
    end

    self:UpdateTargetCache()
    if self.State.targetCache.exists and not self:IsTargetInRange() then
        if self.Config.debug then
            print("|cFFFF0000[VanKili]|r Cannot cast - target out of range")
        end
        self:StopCasting()
        if _G.VanFW.MCP then
            _G.VanFW.MCP:Spell("VanKili cast BLOCKED", {
                spellName = spellName,
                abilityID = abilityID,
                reason = "target_out_of_range",
                targetDistance = self.State.targetCache.distance or 999
            })
        end
        return false
    end

    if not spellName or spellName == "Unknown" then
        return false
    end
    local spellKey = spellName .. (abilityID or "")
    if self.State.lastCastAbility == spellKey then
        local timeSinceLastCast = GetTime() - self.State.lastCastTime
        if timeSinceLastCast < 0.3 then
            if _G.VanFW.MCP then
                _G.VanFW.MCP:Spell("VanKili cast BLOCKED", {
                    spellName = spellName,
                    abilityID = abilityID,
                    reason = "duplicate_prevention",
                    timeSinceLast = timeSinceLastCast
                })
            end
            return false
        end
    end

    self.State.lastCastTime = GetTime()
    self.State.lastCastAbility = spellKey

    if not _G.CastSpellByName then
        return false
    end
    if VanFW.MCP then
        VanFW.MCP:Spell("VanKili cast SUCCESS", {
            spellName = spellName,
            abilityID = abilityID,
            targetExists = self.State.targetCache.exists or false,
            targetDistance = self.State.targetCache.distance or 999
        })
    end

    CastSpellByName(spellName)
    if SpellIsTargeting() then
        if VanFW.target and VanFW.target.Position then
            local x, y, z = VanFW.target:Position()
            if x and y and z and _G.WGG_Click then
                _G.WGG_Click(x, y, z)
            end
        end
    end

    return true
end

function VanKili:GetBestTarget(ignoreHealthThreshold, forceScan, maxRange, nearPosition)
    if not self.Config.autoTarget then
        return nil
    end

    local currentTime = GetTime()
    local searchRange = maxRange or self.Config.targetRange
    if not forceScan and not ignoreHealthThreshold and not nearPosition then
        local timeSinceLastScan = currentTime - self.State.targetScanCache.lastScanTime
        if timeSinceLastScan < self.Config.targetScanInterval then
            local cached = self.State.targetScanCache.bestTarget
            if cached and UnitExists(cached) and not UnitIsDead(cached) and UnitCanAttack("player", cached) then
                return cached, self.State.targetScanCache.bestTargetPointer
            end
        end
    end

    local bestTarget = nil
    local bestTargetPointer = nil
    local bestScore = -1
    local potentialTargets = {}
    local centerX, centerY, centerZ
    if nearPosition then
        centerX, centerY, centerZ = nearPosition.x, nearPosition.y, nearPosition.z
    else
        centerX, centerY, centerZ = self.State.playerCache.x, self.State.playerCache.y, self.State.playerCache.z
    end

    if not centerX then
        return nil
    end
    if VanFW.GetObjectCount and VanFW.GetObjectWithIndex then
        local count = VanFW.GetObjectCount()

        for i = 1, count do
            local pointer = VanFW.GetObjectWithIndex(i)
            if pointer and pointer ~= 0 then
                local objectType = VanFW.ObjectType(pointer)

                if objectType == 5 or objectType == 6 then
                    local unitId = _G.WGG_ObjectToken(pointer)

                    if unitId and type(unitId) == "string" and unitId ~= "" then
                        if UnitExists(unitId) and UnitCanAttack("player", unitId) and not UnitIsDead(unitId) then
                            local ux, uy, uz = VanFW.ObjectPos(pointer)

                            if ux then
                                local dx, dy, dz = ux - centerX, uy - centerY, uz - centerZ
                                local distance = math.sqrt(dx*dx + dy*dy + dz*dz)

                                if distance <= searchRange then
                                    local healthMax = UnitHealthMax(unitId)
                                    local healthPercent = healthMax > 0 and ((UnitHealth(unitId) / healthMax) * 100) or 0
                                    local isValidTarget = true
                                    if not ignoreHealthThreshold and self.Config.ignoreTargetsAbove < 100 then
                                        if healthPercent > self.Config.ignoreTargetsAbove then
                                            isValidTarget = false
                                        end
                                    end

                                    if isValidTarget then
                                        local score = 0

                                        if self.Config.preferLowHealth then
                                            score = score + (100 - healthPercent)
                                        end

                                        score = score + (searchRange - distance) * 2

                                        if UnitIsUnit(unitId .. "target", "player") then
                                            score = score + 50
                                        end

                                        local classification = UnitClassification(unitId)
                                        if classification == "worldboss" then
                                            score = score + 200
                                        elseif classification == "rareelite" then
                                            score = score + 60
                                        elseif classification == "elite" then
                                            score = score + 30
                                        end
                                        if score > bestScore then
                                            bestScore = score
                                            bestTarget = unitId
                                            bestTargetPointer = pointer
                                        end

                                        if distance <= self.Config.targetSwitchRange then
                                            table.insert(potentialTargets, {
                                                token = unitId,
                                                pointer = pointer,
                                                score = score,
                                                distance = distance,
                                            })
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for i = 1, 5 do
        local unit = "boss" .. i
        if UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsDead(unit) then
            local healthMax = UnitHealthMax(unit)
            local healthPercent = healthMax > 0 and ((UnitHealth(unit) / healthMax) * 100) or 0
            local score = 500

            if self.Config.preferLowHealth then
                score = score + (100 - healthPercent)
            end

            if score > bestScore then
                bestScore = score
                bestTarget = unit
                bestTargetPointer = nil
            end
        end
    end

    if not ignoreHealthThreshold then
        self.State.targetScanCache.bestTarget = bestTarget
        self.State.targetScanCache.bestTargetPointer = bestTargetPointer
        self.State.targetScanCache.lastScanTime = currentTime
        self.State.targetScanCache.potentialTargets = potentialTargets
    end

    return bestTarget, bestTargetPointer
end

function VanKili:FaceTarget(unitToken, pointer)
    if not _G.WGG_SetFacing then
        return false
    end

    local tx, ty, tz

    if pointer and _G.WGG_ObjectPosition then
        local posSuccess, x, y, z = pcall(_G.WGG_ObjectPosition, pointer)
        if posSuccess and x then
            tx, ty, tz = x, y, z
        end
    end

    if not tx and unitToken and _G.WGG_SetFacingRaw then
        local faceSuccess = pcall(_G.WGG_SetFacingRaw, unitToken, 0)
        return faceSuccess or false
    end

    if tx then
        local faceSuccess = pcall(_G.WGG_SetFacing, tx, ty, tz, 0)
        return faceSuccess or false
    end

    return false
end

function VanKili:SetTarget(unitToken, pointer)
    if pointer and _G.WGG_ObjectGUID then
        local success, guid = pcall(_G.WGG_ObjectGUID, pointer)
        if success and guid and guid ~= "0:0" then
            local validToken = VanFW:GetTokenByGUID(guid)
            if validToken and UnitExists(validToken) then
                local targetSuccess = pcall(TargetUnit, validToken)
                if targetSuccess then
                    if not UnitIsVisible(validToken) then
                        self:FaceTarget(validToken, pointer)
                    end
                end
                return targetSuccess
            end
        end
    end
    if unitToken and UnitExists(unitToken) then
        local success = pcall(TargetUnit, unitToken)
        if success then
            if not UnitIsVisible(unitToken) then
                self:FaceTarget(unitToken, pointer)
            end
        end
        return success
    end

    return false
end

function VanKili:AutoTarget()
    if not self.Config.autoTarget then
        return false
    end

    self:UpdateTargetCache()
    local cache = self.State.targetCache
    if cache.exists and cache.dead then
        local lastTargetPos = nil
        if VanFW.target and VanFW.target.position then
            local tx, ty, tz = VanFW.target:position()
            if tx then
                lastTargetPos = {x = tx, y = ty, z = tz}
            end
        end

        local bestTarget, bestPointer = self:GetBestTarget(true, true, self.Config.targetSwitchRange, lastTargetPos)

        if bestTarget then
            self:SetTarget(bestTarget, bestPointer)
            return true
        else
            bestTarget, bestPointer = self:GetBestTarget(true, true)
            if bestTarget then
                self:SetTarget(bestTarget, bestPointer)
                return true
            end
        end
    end
    if not cache.exists or (cache.exists and not UnitCanAttack("player", "target")) then
        local bestTarget, bestPointer = self:GetBestTarget(true, true)
        if bestTarget then
            self:SetTarget(bestTarget, bestPointer)
            return true
        end
        return false
    end
    if cache.distance > self.Config.targetRange then
        local bestTarget, bestPointer = self:GetBestTarget(true, true)
        if bestTarget then
            self:SetTarget(bestTarget, bestPointer)
            return true
        end
        return false
    end
    local bestTarget, bestPointer = self:GetBestTarget(false, false)  -- Use cache if available
    if bestTarget and not UnitIsUnit(bestTarget, "target") then
        local newHealthPercent = (UnitHealth(bestTarget) / UnitHealthMax(bestTarget)) * 100

        if self.Config.preferLowHealth then
            local shouldSwitch = false
            if newHealthPercent <= self.Config.ignoreTargetsAbove and cache.health > self.Config.ignoreTargetsAbove then
                shouldSwitch = true
            elseif newHealthPercent < (cache.health - 10) then
                shouldSwitch = true
            end

            if shouldSwitch then
                self:SetTarget(bestTarget, bestPointer)
                return true
            end
        end
    end

    return false
end

VanKili.AutoRotation = {
    enabled = false,
    frame = nil,
    timeSinceLastUpdate = 0,
}

function VanKili.AutoRotation:Start()
    if self.enabled then
        print("|cFFFFFF00[VanKili]|r Already running")
        return
    end

    if not VanKili:IsHekiliLoaded() then
        print("|cFFFF0000[VanKili]|r Hekili addon not loaded")
        return
    end

    self.enabled = true
    self.timeSinceLastUpdate = 0

    if not self.frame then
        self.frame = CreateFrame("Frame")
    end

    self.frame:SetScript("OnUpdate", function(frame, elapsed)
        VanKili.AutoRotation:OnUpdate(elapsed)
    end)

    print("|cFF00FF00[VanKili]|r Auto-rotation started")
end

function VanKili.AutoRotation:Stop()
    if not self.enabled then
        print("|cFFFFFF00[VanKili]|r Already stopped")
        return
    end

    self.enabled = false
    self.timeSinceLastUpdate = 0

    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
    end

    print("|cFFFFFF00[VanKili]|r Auto-rotation stopped")
end

function VanKili.AutoRotation:Toggle()
    if self.enabled then
        self:Stop()
    else
        self:Start()
    end
end

function VanKili.AutoRotation:OnUpdate(elapsed)
    if not self.enabled then
        return
    end
    VanKili:UpdatePlayerCache()
    if not VanKili.State.playerCache.inCombat then
        return
    end
    if VanKili.State.playerCache.casting then
        return
    end

    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed

    if self.timeSinceLastUpdate < VanKili.State.updateInterval then
        return
    end

    self.timeSinceLastUpdate = 0
    VanKili:AutoTarget()
    VanKili:UpdateTargetCache()

    if VanKili.State.targetCache.exists and not VanKili.State.targetCache.dead then
        local displays = {
            VanKili.Config.interruptsDisplay,
            VanKili.Config.defensivesDisplay,
            VanKili.Config.cooldownsDisplay,
            VanKili.Config.primaryDisplay,
            VanKili.Config.aoeDisplay,
        }

        for _, display in ipairs(displays) do
            local rec = VanKili:GetRecommendation(display, 1)
            if rec and rec.abilityID then
                if VanFW.MCP then
                    VanFW.MCP:Spell("VanKili cast attempt", {
                        display = display,
                        spellName = rec.spellName or "Unknown",
                        abilityID = rec.abilityID or 0,
                    })
                end

                if VanKili:CastRecommendation(rec) then
                    if VanFW.MCP then
                        VanFW.MCP:Spell("VanKili cast SUCCESS", {
                            display = display,
                            spellName = rec.spellName or "Unknown",
                            abilityID = rec.abilityID or 0,
                        })
                    end
                    return
                else
                    if VanFW.MCP then
                        VanFW.MCP:Spell("VanKili cast FAILED", {
                            display = display,
                            spellName = rec.spellName or "Unknown",
                            abilityID = rec.abilityID or 0,
                        })
                    end
                end
            else
                if VanKili.Config.debug then
                    print(string.format("[VanKili] Display '%s' is empty (no recommendation)", display))
                end
            end
        end
    end
end


VanKili.Drawing = {
    enabled = false,
    playerCircleSize = 1.5,
    targetCircleSize = 2.0,
    lineThickness = 2.5,
}

function VanKili.Drawing:DrawCallback()
    if not VanKili.State.playerCache.inCombat then
        return
    end

    local px, py, pz = VanKili.State.playerCache.x, VanKili.State.playerCache.y, VanKili.State.playerCache.z

    if not px then
        return
    end

    VanFW.Draw.CircleAroundPlayer(
        self.playerCircleSize,
        nil, nil, nil, 200,
        2.5,
        true
    )

    if VanKili.State.targetCache.exists and not VanKili.State.targetCache.dead then
        VanFW.Draw.CircleAroundTarget(
            self.targetCircleSize,
            nil, nil, nil, 200,
            2.5,
            true
        )

        VanFW.Draw.LineBetweenUnits(
            "player",
            "target",
            nil, nil, nil, 200,
            self.lineThickness,
            true
        )
    end

    local potentialTargets = VanKili.State.targetScanCache.potentialTargets or {}
    for _, targetData in ipairs(potentialTargets) do
        local token = targetData.token

        if token and UnitExists(token) and not UnitIsUnit(token, "target") then
            local tx, ty, tz = UnitPosition(token)
            if tx then
                VanFW.Draw.Circle(
                    tx, ty, tz,
                    self.targetCircleSize,
                    0, 150, 255,
                    150,
                    2.0,
                    false
                )

                VanFW.Draw.FilledCircle(
                    tx, ty, tz,
                    self.targetCircleSize * 0.7,
                    0, 150, 255,
                    50
                )
            end
        end
    end
    if VanFW.Draw.Missiles then
        VanFW.Draw.Missiles:DrawAll()
    end
end

function VanKili.Drawing:Enable()
    if self.enabled then
        return
    end

    self.enabled = true

    if not VanFW.Draw.enabled then
        VanFW.Draw.Enable()
    end

    VanFW.Draw.RegisterCallback("vankili_drawings", function()
        VanKili.Drawing:DrawCallback()
    end)

    print("|cFF00FF00[VanKili]|r Drawings enabled")
end

function VanKili.Drawing:Disable()
    if not self.enabled then
        return
    end

    self.enabled = false
    VanFW.Draw.UnregisterCallback("vankili_drawings")

    print("|cFFFFFF00[VanKili]|r Drawings disabled")
end

function VanKili.Drawing:Toggle()
    if self.enabled then
        self:Disable()
    else
        self:Enable()
    end
end

SLASH_VANKILI1 = "/vk"
SLASH_VANKILI2 = "/vankili"

SlashCmdList["VANKILI"] = function(msg)
    local cmd = msg and msg:lower():trim() or ""

    if cmd == "start" then
        VanKili.AutoRotation:Start()

    elseif cmd == "stop" then
        VanKili.AutoRotation:Stop()

    elseif cmd == "debug" then
        VanKili.Config.debug = not VanKili.Config.debug
        local status = VanKili.Config.debug and "|cFF00FF00ON|r" or "|cFFFFFF00OFF|r"
        print("|cFF00FFFF[VanKili]|r Debug mode:", status)

    elseif cmd == "target" or cmd == "autotarget" then
        VanKili.Config.autoTarget = not VanKili.Config.autoTarget
        local status = VanKili.Config.autoTarget and "|cFF00FF00ON|r" or "|cFFFFFF00OFF|r"
        print("|cFF00FFFF[VanKili]|r Auto-targeting:", status)

    elseif cmd == "draw" or cmd == "drawings" then
        VanKili.Drawing:Toggle()

    elseif cmd == "status" then
        print("|cFF00FFFF[VanKili]|r Status:")
        print("  Auto-rotation:", VanKili.AutoRotation.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r")
        print("  Auto-targeting:", VanKili.Config.autoTarget and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r")
        print("  Drawings:", VanKili.Drawing.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r")
        print("  Debug mode:", VanKili.Config.debug and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r")
        print("  Target range:", VanKili.Config.targetRange .. " yards")
        print("  Hekili loaded:", VanKili:IsHekiliLoaded() and "|cFF00FF00YES|r" or "|cFFFF0000NO|r")

    else
        print("|cFF00FFFF[VanKili]|r Commands:")
        print("  |cFFFFFFFF/vk start|r - Start auto-rotation")
        print("  |cFFFFFFFF/vk stop|r - Stop auto-rotation")
        print("  |cFFFFFFFF/vk target|r - Toggle auto-targeting")
        print("  |cFFFFFFFF/vk draw|r - Toggle drawings")
        print("  |cFFFFFFFF/vk debug|r - Toggle debug output")
        print("  |cFFFFFFFF/vk status|r - Show current status")
    end
end

C_Timer.After(1, function()
    VanKili:Initialize()
    if VanKili:IsHekiliLoaded() then
        VanKili.Drawing:Enable()
    end
end)

print("|cFF00FF00[VanFW]|r VanKili module loaded (Optimized)")
