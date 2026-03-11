-- VanFW Boss Awareness Module
-- Uses WGG native APIs to detect boss mechanics without relying on DBM/BigWigs
-- Detects: ground effects (AreaTriggers), incoming missiles, boss casts, dangerous debuffs

local VanFW = VanFW
if not VanFW then return end

VanFW.BossAware = VanFW.BossAware or {}
local BA = VanFW.BossAware

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------
BA.config = {
    enabled = true,
    -- Ground effect detection
    detectAreaTriggers = true,
    areaTriggerDangerRadius = 5,
    -- Missile detection
    detectMissiles = true,
    missileDangerRadius = 4,
    -- Boss cast detection
    detectBossCasts = true,
    interruptableOnly = false,
    -- Dangerous debuff detection
    detectDangerousDebuffs = true,
    -- Update rate
    updateInterval = 0.05,
    -- Debug
    debug = false,
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
BA.state = {
    lastUpdate = 0,
    -- Ground effects near player
    dangerousGroundEffects = {},
    isStandingInBad = false,
    nearestGroundEffectDist = 999,
    -- Incoming missiles
    incomingMissiles = {},
    missileIncoming = false,
    missileETA = 999,
    -- Boss casts
    bossCasts = {},
    bossIsCasting = false,
    bossCanBeInterrupted = false,
    bossCastRemaining = 0,
    bossCastSpellId = nil,
    bossCastSpellName = nil,
    -- Dangerous debuffs on player
    dangerousDebuffs = {},
    hasDangerousDebuff = false,
}

---------------------------------------------------------------------------
-- Known dangerous AreaTrigger spellIds (expandable per raid/dungeon)
-- Empty = treat ALL AreaTriggers near player as potentially dangerous
---------------------------------------------------------------------------
local KNOWN_SAFE_AREATRIGGERS = {
    -- Add spellIds of AreaTriggers that are safe (e.g., healing circles)
    -- Example: [12345] = true,
}

---------------------------------------------------------------------------
-- Ground Effect Detection (AreaTriggers)
---------------------------------------------------------------------------
local function UpdateGroundEffects()
    if not BA.config.detectAreaTriggers then return end
    if not _G.WGG_AreaTrigger then return end

    local effects = {}
    local playerX, playerY, playerZ = VanFW:PlayerPosition()
    if not playerX then
        BA.state.dangerousGroundEffects = {}
        BA.state.isStandingInBad = false
        BA.state.nearestGroundEffectDist = 999
        return
    end

    local isInDanger = false
    local nearestDist = 999

    local count = VanFW.GetObjectCount and VanFW.GetObjectCount() or 0

    for i = 0, count - 1 do
        local obj = VanFW.GetObjectWithIndex(i)
        if obj and obj ~= 0 then
            local objType = VanFW.ObjectType(obj)

            -- ObjectType 11 = AreaTrigger
            if objType == 11 then
                local success, data = pcall(_G.WGG_AreaTrigger, obj)
                if success and data then
                    local atX, atY, atZ = data.x, data.y, data.z
                    local radius = (data.radius and data.radius > 0) and data.radius or 3
                    local spellId = data.spellId

                    -- Check if the caster is friendly (heals, barriers, etc.)
                    local casterIsFriendly = false
                    if data.casterGUID then
                        local resolveToken = UnitTokenFromGUID or (VanFW.GetTokenByGUID and function(guid) return VanFW:GetTokenByGUID(guid) end)
                        if resolveToken then
                            local casterUnit = resolveToken(data.casterGUID)
                            if casterUnit and UnitIsFriend("player", casterUnit) then
                                casterIsFriendly = true
                            end
                        end
                    end

                    if atX and not KNOWN_SAFE_AREATRIGGERS[spellId] and not casterIsFriendly then
                        local dx = playerX - atX
                        local dy = playerY - atY
                        local dz = playerZ - atZ
                        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

                        local effectiveRadius = radius + BA.config.areaTriggerDangerRadius

                        if dist < effectiveRadius then
                            local effect = {
                                x = atX, y = atY, z = atZ,
                                radius = radius,
                                distance = dist,
                                spellId = spellId,
                                casterGUID = data.casterGUID,
                                duration = data.duration,
                                isInside = dist <= radius,
                            }
                            table.insert(effects, effect)

                            -- Hysteresis: once flagged, require radius + 1 to clear
                            local standingThreshold = radius
                            if BA.state.isStandingInBad then
                                standingThreshold = radius + 1
                            end

                            if dist <= standingThreshold then
                                isInDanger = true
                            end

                            if dist < nearestDist then
                                nearestDist = dist
                            end
                        end
                    end
                end
            end
        end
    end

    BA.state.dangerousGroundEffects = effects
    BA.state.isStandingInBad = isInDanger
    BA.state.nearestGroundEffectDist = nearestDist
end

---------------------------------------------------------------------------
-- Missile Detection
---------------------------------------------------------------------------
local function UpdateMissiles()
    if not BA.config.detectMissiles then return end
    if not _G.WGG_GetMissileCount then return end

    local missiles = {}
    local playerX, playerY, playerZ = VanFW:PlayerPosition()
    if not playerX then
        BA.state.incomingMissiles = {}
        BA.state.missileIncoming = false
        BA.state.missileETA = 999
        return
    end

    local playerGUID = UnitGUID("player")
    local hasDanger = false
    local nearestETA = 999

    local missileCount = _G.WGG_GetMissileCount()
    for i = 1, missileCount do
        local spellID, _, mx, my, mz, srcGUID, sx, sy, sz, tgtGUID, tx, ty, tz = _G.WGG_GetMissileWithIndex(i)

        if spellID and tx then
            -- Check if missile is heading toward player (3D distance)
            local dx = playerX - tx
            local dy = playerY - ty
            local dz = playerZ - tz
            local impactDist = math.sqrt(dx * dx + dy * dy + dz * dz)

            if impactDist < BA.config.missileDangerRadius or tgtGUID == playerGUID then
                -- Estimate ETA based on missile travel
                local travelDist = 0
                if mx and sx then
                    local tdx = tx - mx
                    local tdy = ty - my
                    travelDist = math.sqrt(tdx * tdx + tdy * tdy)
                end

                -- Rough ETA: assume ~30 yards/sec missile speed
                local eta = travelDist > 0 and (travelDist / 30) or 0.5

                local missile = {
                    spellID = spellID,
                    targetX = tx, targetY = ty, targetZ = tz,
                    missileX = mx, missileY = my, missileZ = mz,
                    sourceGUID = srcGUID,
                    targetGUID = tgtGUID,
                    impactDist = impactDist,
                    eta = eta,
                    targetingPlayer = tgtGUID == playerGUID,
                }
                table.insert(missiles, missile)
                hasDanger = true

                if eta < nearestETA then
                    nearestETA = eta
                end
            end
        end
    end

    BA.state.incomingMissiles = missiles
    BA.state.missileIncoming = hasDanger
    BA.state.missileETA = nearestETA
end

---------------------------------------------------------------------------
-- Boss Cast Detection
---------------------------------------------------------------------------
local function UpdateBossCasts()
    if not BA.config.detectBossCasts then return end

    local casts = {}
    local hasCast = false
    local shortestRemaining = 999
    local shortestSpellId = nil
    local shortestSpellName = nil
    -- Track interruptible casts separately from overall shortest cast
    local shortestInterruptRemaining = 999
    local shortestInterruptSpellId = nil
    local shortestInterruptSpellName = nil

    -- Check boss1-boss5 unit tokens
    for i = 1, 5 do
        local bossUnit = "boss" .. i
        if UnitExists(bossUnit) and not UnitIsDead(bossUnit) then
            -- Check casting
            local castName, castText, castTexture, castStartTime, castEndTime, _, _, notInterruptible, spellId = UnitCastingInfo(bossUnit)
            if castName then
                local remaining = castEndTime and ((castEndTime / 1000) - GetTime()) or 0
                local isInterruptible = not notInterruptible

                if not BA.config.interruptableOnly or isInterruptible then
                    local cast = {
                        unit = bossUnit,
                        spellName = castName,
                        spellId = spellId,
                        remaining = remaining,
                        isInterruptible = isInterruptible,
                        isCasting = true,
                        isChanneling = false,
                    }
                    table.insert(casts, cast)
                    hasCast = true

                    if remaining < shortestRemaining then
                        shortestRemaining = remaining
                        shortestSpellId = spellId
                        shortestSpellName = castName
                    end

                    if isInterruptible and remaining < shortestInterruptRemaining then
                        shortestInterruptRemaining = remaining
                        shortestInterruptSpellId = spellId
                        shortestInterruptSpellName = castName
                    end
                end
            end

            -- Check channeling
            local chanName, chanText, chanTexture, chanStartTime, chanEndTime, _, notInterruptibleCh, spellIdCh = UnitChannelInfo(bossUnit)
            if chanName then
                local remaining = chanEndTime and ((chanEndTime / 1000) - GetTime()) or 0
                local isInterruptible = not notInterruptibleCh

                if not BA.config.interruptableOnly or isInterruptible then
                    local cast = {
                        unit = bossUnit,
                        spellName = chanName,
                        spellId = spellIdCh,
                        remaining = remaining,
                        isInterruptible = isInterruptible,
                        isCasting = false,
                        isChanneling = true,
                    }
                    table.insert(casts, cast)
                    hasCast = true

                    if remaining < shortestRemaining then
                        shortestRemaining = remaining
                        shortestSpellId = spellIdCh
                        shortestSpellName = chanName
                    end

                    if isInterruptible and remaining < shortestInterruptRemaining then
                        shortestInterruptRemaining = remaining
                        shortestInterruptSpellId = spellIdCh
                        shortestInterruptSpellName = chanName
                    end
                end
            end
        end
    end

    -- Also check via WGG object manager for non-boss dangerous casts
    for _, enemy in ipairs(VanFW.objects.enemies or {}) do
        if enemy:exists() and not enemy:dead() then
            local casting = enemy:casting and enemy:casting()
            local channeling = enemy:channeling and enemy:channeling()
            if casting or channeling then
                local interruptible = enemy:castint and enemy:castint()
                local castRemains = casting and (enemy.castRemains and enemy:castRemains() or 0) or 0
                local chanRemains = channeling and (enemy.channelRemains and enemy:channelRemains() or 0) or 0
                local remains = casting and castRemains or chanRemains

                if remains > 0 and remains < shortestRemaining then
                    shortestRemaining = remains
                end

                if interruptible and remains > 0 and remains < shortestInterruptRemaining then
                    shortestInterruptRemaining = remains
                end
            end
        end
    end

    local canInterrupt = shortestInterruptRemaining < 999
    BA.state.bossCasts = casts
    BA.state.bossIsCasting = hasCast
    BA.state.bossCanBeInterrupted = canInterrupt
    BA.state.bossCastRemaining = shortestInterruptRemaining < 999 and shortestInterruptRemaining or (shortestRemaining < 999 and shortestRemaining or 0)
    BA.state.bossCastSpellId = shortestInterruptSpellId or shortestSpellId
    BA.state.bossCastSpellName = shortestInterruptSpellName or shortestSpellName
end

---------------------------------------------------------------------------
-- Dangerous Debuff Detection on Player
---------------------------------------------------------------------------
local function UpdateDangerousDebuffs()
    if not BA.config.detectDangerousDebuffs then return end

    local debuffs = {}
    local hasDanger = false
    local player = VanFW.player
    if not player or not player:exists() then return end

    -- Use WGG aura API for accurate data
    if _G.WGG_GetUnitAuraCount and _G.WGG_GetUnitAuraByIndex then
        local auraCount = _G.WGG_GetUnitAuraCount("player")
        for i = 0, auraCount - 1 do
            local spellId, stacks, duration, flags, instanceID, isHarmful = _G.WGG_GetUnitAuraByIndex("player", i)
            if isHarmful and spellId then
                local debuff = {
                    spellId = spellId,
                    stacks = stacks or 0,
                    duration = duration or 0,
                    isActive = duration > 1,
                }
                table.insert(debuffs, debuff)
                if duration > 1 then
                    hasDanger = true
                end
            end
        end
    end

    BA.state.dangerousDebuffs = debuffs
    BA.state.hasDangerousDebuff = hasDanger
end

---------------------------------------------------------------------------
-- Main Update
---------------------------------------------------------------------------
local function UpdateBossAwareness()
    if not BA.config.enabled then return end
    if not VanFW.inCombat then return end

    local currentTime = GetTime()
    if currentTime - BA.state.lastUpdate < BA.config.updateInterval then return end
    BA.state.lastUpdate = currentTime

    UpdateGroundEffects()
    UpdateMissiles()
    UpdateBossCasts()
    UpdateDangerousDebuffs()
end

---------------------------------------------------------------------------
-- Query API (for Rotation scripts)
---------------------------------------------------------------------------

-- Am I standing in a ground effect?
function BA:IsStandingInBad()
    return self.state.isStandingInBad
end

-- How far is the nearest ground effect?
function BA:NearestGroundEffectDistance()
    return self.state.nearestGroundEffectDist
end

-- Get all nearby ground effects
function BA:GetGroundEffects()
    return self.state.dangerousGroundEffects
end

-- Is a missile heading toward me?
function BA:IsMissileIncoming()
    return self.state.missileIncoming
end

-- ETA of nearest missile
function BA:GetMissileETA()
    return self.state.missileETA
end

-- Get all incoming missiles
function BA:GetMissiles()
    return self.state.incomingMissiles
end

-- Is any boss currently casting?
function BA:IsBossCasting()
    return self.state.bossIsCasting
end

-- Can the current boss cast be interrupted?
function BA:CanInterruptBoss()
    return self.state.bossCanBeInterrupted, self.state.bossCastRemaining
end

-- Get boss cast details
function BA:GetBossCast()
    return {
        isCasting = self.state.bossIsCasting,
        canInterrupt = self.state.bossCanBeInterrupted,
        remaining = self.state.bossCastRemaining,
        spellId = self.state.bossCastSpellId,
        spellName = self.state.bossCastSpellName,
    }
end

-- Get all active boss casts
function BA:GetAllBossCasts()
    return self.state.bossCasts
end

-- Do I have a dangerous debuff?
function BA:HasDangerousDebuff()
    return self.state.hasDangerousDebuff
end

-- Get all dangerous debuffs
function BA:GetDangerousDebuffs()
    return self.state.dangerousDebuffs
end

-- Should I move? (standing in bad OR missile incoming)
function BA:ShouldMove()
    return self.state.isStandingInBad or self.state.missileIncoming
end

-- Comprehensive danger check: returns highest priority threat
function BA:GetThreatLevel()
    if self.state.isStandingInBad then
        return "MOVE_NOW", "Standing in ground effect"
    end
    if self.state.missileIncoming and self.state.missileETA < 1.5 then
        return "MOVE_SOON", "Missile impact in " .. string.format("%.1f", self.state.missileETA) .. "s"
    end
    if self.state.bossCanBeInterrupted and self.state.bossCastRemaining > 0 and self.state.bossCastRemaining < 2 then
        return "INTERRUPT", "Interruptible cast: " .. (self.state.bossCastSpellName or "Unknown")
    end
    if self.state.hasDangerousDebuff then
        return "DEBUFF", "Dangerous debuff active"
    end
    return "SAFE", nil
end

---------------------------------------------------------------------------
-- Hook into VanFW update loop
---------------------------------------------------------------------------
if VanFW.RegisterCallback then
    VanFW:RegisterCallback("onTick", UpdateBossAwareness)
end

VanFW:Debug("Boss Awareness module loaded", "BossAware")
