local RotationInfo = {
    name = "Affliction",
    class = "WARLOCK",
    spec = "Affliction",
    author = "VanFW",
    version = "1.0.0",
    description = "Affliction Warlock PVE - Hellcaller/Soul Harvester",
}

local function WaitForVanFW(callback)
    if VanFW and VanFW.loaded then
        callback()
    else
        C_Timer.After(0.5, function() WaitForVanFW(callback) end)
    end
end

WaitForVanFW(function()
    local GetTime = GetTime
    local UnitPower = UnitPower
    local UnitPowerMax = UnitPowerMax
    local UnitCastingInfo = UnitCastingInfo
    local UnitChannelInfo = UnitChannelInfo
    local UnitHealth = UnitHealth
    local UnitHealthMax = UnitHealthMax
    local IsPlayerSpell = IsPlayerSpell
    local VanFW = VanFW

    VanFW:Print("Loading Affliction Warlock Rotation...")

    ---------------------------------------------------------------------------
    -- Config
    ---------------------------------------------------------------------------
    local DefaultConfig = {
        -- AoE
        aoeThreshold = 3,
        maxDotTargets = 8,
        -- DoT durations (base, before haste)
        agonyDuration = 18,
        corruptionDuration = 14,
        uaDuration = 16,
        hauntDuration = 18,
        witherDuration = 18,
        -- Pandemic window (fraction of duration)
        pandemicWindow = 0.3,
        -- Soul Shards
        maxShards = 5,
        uaShardThreshold = 4,
        -- Cooldowns
        useDarkglare = true,
        useMalevolence = true,
        useSoulRot = true,
        usePhantomSingularity = true,
        useVileTaint = true,
        -- Defensive
        useDrainLife = true,
        drainLifeThreshold = 40,
        useUnendingResolve = true,
        unendingResolveThreshold = 25,
        -- Execute
        executeThreshold = 20,
    }

    local savedConfig = VanFW:LoadRotationConfig(RotationInfo.class, RotationInfo.spec, RotationInfo.name)
    local Config = {}
    for k, v in pairs(DefaultConfig) do
        Config[k] = v
    end
    if savedConfig then
        for k, v in pairs(savedConfig) do
            Config[k] = v
        end
        VanFW:Success("Loaded saved configuration!")
    else
        VanFW:Print("Using default configuration")
    end

    ---------------------------------------------------------------------------
    -- Spells (IDs verified via Wowhead 2026-03-10)
    ---------------------------------------------------------------------------
    local Spells = {}

    -- Core DoTs
    Spells.Agony          = VanFW:CreateSpell(980,    {priority = 2, name = "Agony"})
    Spells.Corruption     = VanFW:CreateSpell(172,    {priority = 2, name = "Corruption"})
    Spells.UnstableAffliction = VanFW:CreateSpell(316099, {priority = 3, name = "Unstable Affliction"})
    Spells.Wither         = VanFW:CreateSpell(445465, {priority = 2, name = "Wither", castMethod = 'name'})

    -- Core abilities
    Spells.Haunt          = VanFW:CreateSpell(48181,  {priority = 1, name = "Haunt"})
    Spells.DrainSoul      = VanFW:CreateSpell(198590, {priority = 10, name = "Drain Soul", castMethod = 'name'})
    Spells.ShadowBolt     = VanFW:CreateSpell(686,    {priority = 10, name = "Shadow Bolt"})

    -- Cooldowns
    Spells.SummonDarkglare = VanFW:CreateSpell(205180, {priority = 1, name = "Summon Darkglare"})
    Spells.Malevolence    = VanFW:CreateSpell(442726, {priority = 1, name = "Malevolence", castMethod = 'name'})
    Spells.SoulRot        = VanFW:CreateSpell(325640, {priority = 1, name = "Soul Rot"})
    Spells.DarkHarvest    = VanFW:CreateSpell(387016, {priority = 1, name = "Dark Harvest", castMethod = 'name'})
    Spells.PhantomSingularity = VanFW:CreateSpell(205179, {priority = 3, name = "Phantom Singularity"})
    Spells.VileTaint      = VanFW:CreateSpell(278350, {priority = 3, name = "Vile Taint"})

    -- AoE
    Spells.SeedOfCorruption = VanFW:CreateSpell(27243, {priority = 4, name = "Seed of Corruption"})

    -- Defensive
    Spells.DrainLife       = VanFW:CreateSpell(234153, {priority = 1, name = "Drain Life"})
    Spells.UnendingResolve = VanFW:CreateSpell(104773, {priority = 1, name = "Unending Resolve"})

    -- Buffs/Procs (aura IDs for tracking)
    local NIGHTFALL_BUFF       = 264571
    local SHARD_INSTABILITY    = 216457
    local HAUNT_DEBUFF         = 48181
    local DARKGLARE_BUFF       = 205180

    ---------------------------------------------------------------------------
    -- State Cache
    ---------------------------------------------------------------------------
    local StateCache = {
        lastUpdate = 0,
        updateInterval = 0.03,
        -- Player
        playerHP = 100,
        playerShards = 0,
        playerMaxShards = 5,
        playerInCombat = false,
        playerCasting = false,
        playerChanneling = false,
        -- Target
        targetExists = false,
        targetHP = 100,
        targetIsEnemy = false,
        targetIsDead = false,
        -- Target DoTs
        hasAgony = false,
        hasCorruption = false,
        hasUA = false,
        hasHaunt = false,
        hasWither = false,
        agonyRemaining = 0,
        corruptionRemaining = 0,
        uaRemaining = 0,
        hauntRemaining = 0,
        witherRemaining = 0,
        -- Procs
        hasNightfall = false,
        nightfallStacks = 0,
        hasShardInstability = false,
        -- Enemies
        enemiesInMelee = 0,
        enemiesIn10y = 0,
        enemiesIn40y = 0,
        -- Talents
        hasWitherTalent = false,
        hasDrainSoulTalent = false,
        hasMalevolenceTalent = false,
        hasDarkHarvestTalent = false,
        hasSoulRotTalent = false,
        hasPhantomSingularity = false,
        hasVileTaint = false,
    }

    local function IsDead(unit)
        if not unit or not unit:exists() then return true end
        local token = unit:GetToken()
        if not token then return true end
        if not UnitExists(token) then return true end
        return UnitIsDeadOrGhost(token) or false
    end

    local function IsEnemy(unit)
        return unit and unit:exists() and unit:enemy() and not IsDead(unit)
    end

    local function DetectTalents()
        StateCache.hasWitherTalent = IsPlayerSpell(445465)
        StateCache.hasDrainSoulTalent = IsPlayerSpell(198590)
        StateCache.hasMalevolenceTalent = IsPlayerSpell(442726)
        StateCache.hasDarkHarvestTalent = IsPlayerSpell(387016)
        StateCache.hasSoulRotTalent = IsPlayerSpell(325640)
        StateCache.hasPhantomSingularity = IsPlayerSpell(205179)
        StateCache.hasVileTaint = IsPlayerSpell(278350)
    end

    local talentsDetected = false

    local function UpdateStateCache()
        local currentTime = GetTime()
        if currentTime - StateCache.lastUpdate < StateCache.updateInterval then return end

        if not talentsDetected then
            DetectTalents()
            talentsDetected = true
        end

        local player = VanFW.player
        local target = VanFW.target

        -- Player state
        if player and player:exists() then
            StateCache.playerHP = player:hp()
            StateCache.playerShards = UnitPower("player", 7)
            StateCache.playerMaxShards = UnitPowerMax("player", 7)
            StateCache.playerInCombat = player:combat()
            StateCache.playerCasting = UnitCastingInfo("player") ~= nil
            StateCache.playerChanneling = UnitChannelInfo("player") ~= nil

            -- Procs
            local hasNF, nfStacks = player:HasBuff(NIGHTFALL_BUFF)
            StateCache.hasNightfall = hasNF or false
            StateCache.nightfallStacks = nfStacks or 0
            StateCache.hasShardInstability = player:HasBuff(SHARD_INSTABILITY) or false
        end

        -- Target state
        if target and target:exists() then
            StateCache.targetExists = true
            StateCache.targetHP = target:hp()
            StateCache.targetIsEnemy = target:enemy()
            StateCache.targetIsDead = IsDead(target)

            if not StateCache.targetIsDead then
                StateCache.agonyRemaining = target:DebuffRemaining(980) or 0
                StateCache.hasAgony = StateCache.agonyRemaining > 0

                if StateCache.hasWitherTalent then
                    StateCache.witherRemaining = target:DebuffRemaining(445465) or 0
                    StateCache.hasWither = StateCache.witherRemaining > 0
                    StateCache.corruptionRemaining = 0
                    StateCache.hasCorruption = false
                else
                    StateCache.corruptionRemaining = target:DebuffRemaining(172) or 0
                    StateCache.hasCorruption = StateCache.corruptionRemaining > 0
                    StateCache.witherRemaining = 0
                    StateCache.hasWither = false
                end

                StateCache.uaRemaining = target:DebuffRemaining(316099) or 0
                StateCache.hasUA = StateCache.uaRemaining > 0

                StateCache.hauntRemaining = target:DebuffRemaining(HAUNT_DEBUFF) or 0
                StateCache.hasHaunt = StateCache.hauntRemaining > 0
            else
                StateCache.hasAgony = false
                StateCache.hasCorruption = false
                StateCache.hasUA = false
                StateCache.hasHaunt = false
                StateCache.hasWither = false
                StateCache.agonyRemaining = 0
                StateCache.corruptionRemaining = 0
                StateCache.uaRemaining = 0
                StateCache.hauntRemaining = 0
                StateCache.witherRemaining = 0
            end
        else
            StateCache.targetExists = false
            StateCache.targetHP = 100
            StateCache.targetIsEnemy = false
            StateCache.targetIsDead = false
        end

        -- Enemy count
        StateCache.enemiesInMelee = 0
        StateCache.enemiesIn10y = 0
        StateCache.enemiesIn40y = 0
        if player and player:exists() then
            for _, enemy in ipairs(VanFW.objects.enemies) do
                if enemy:exists() and not IsDead(enemy) then
                    local dist = enemy:distance()
                    if dist then
                        if dist <= 40 then
                            StateCache.enemiesIn40y = StateCache.enemiesIn40y + 1
                            if dist <= 10 then
                                StateCache.enemiesIn10y = StateCache.enemiesIn10y + 1
                                if dist <= 5 then
                                    StateCache.enemiesInMelee = StateCache.enemiesInMelee + 1
                                end
                            end
                        end
                    end
                end
            end
        end

        StateCache.lastUpdate = currentTime
    end

    ---------------------------------------------------------------------------
    -- Helpers
    ---------------------------------------------------------------------------
    local function InPandemicWindow(remaining, duration)
        if not remaining or not duration then return true end
        return remaining <= duration * Config.pandemicWindow
    end

    local function GetCorruptionSpell()
        if StateCache.hasWitherTalent then
            return Spells.Wither
        end
        return Spells.Corruption
    end

    local function GetFillerSpell()
        if StateCache.hasDrainSoulTalent then
            return Spells.DrainSoul
        end
        return Spells.ShadowBolt
    end

    local function FaceTarget(target)
        if not target or not target:exists() then return end
        local playerFacing = WGG_GetFacing()
        local targetX, targetY = target:position()
        local playerX, playerY = VanFW.player:position()
        if not playerFacing or not targetX or not playerX then return end

        local dx = targetX - playerX
        local dy = targetY - playerY
        local angleToTarget = math.atan2(dy, dx)
        if angleToTarget < 0 then angleToTarget = angleToTarget + (2 * math.pi) end
        if playerFacing < 0 then playerFacing = playerFacing + (2 * math.pi) end

        local angleDiff = math.abs(angleToTarget - playerFacing)
        if angleDiff > math.pi then angleDiff = (2 * math.pi) - angleDiff end
        if angleDiff > (math.pi / 4) then
            WGG_SetFacingRaw(target)
        end
    end

    ---------------------------------------------------------------------------
    -- Defensive
    ---------------------------------------------------------------------------
    local function DefensiveRotation()
        local player = VanFW.player
        if not player or not player:exists() then return false end

        if Config.useUnendingResolve and StateCache.playerHP < Config.unendingResolveThreshold then
            if Spells.UnendingResolve:Castable() then
                return Spells.UnendingResolve:SelfCast()
            end
        end

        if Config.useDrainLife and StateCache.playerHP < Config.drainLifeThreshold then
            if StateCache.targetExists and not StateCache.targetIsDead then
                if Spells.DrainLife:Castable(VanFW.target) then
                    return Spells.DrainLife:Cast(VanFW.target)
                end
            end
        end

        return false
    end

    ---------------------------------------------------------------------------
    -- DoT Maintenance
    ---------------------------------------------------------------------------
    local function MaintainDots(target)
        if not IsEnemy(target) then return false end

        -- 1. Agony (highest priority DoT — stacks reset if dropped)
        local agonyRemaining = target:DebuffRemaining(980) or 0
        if agonyRemaining == 0 or InPandemicWindow(agonyRemaining, Config.agonyDuration) then
            if Spells.Agony:Castable(target) then
                return Spells.Agony:Cast(target)
            end
        end

        -- 2. Corruption / Wither
        local corruptionSpell = GetCorruptionSpell()
        local corruptionID = StateCache.hasWitherTalent and 445465 or 172
        local corruptionDuration = StateCache.hasWitherTalent and Config.witherDuration or Config.corruptionDuration
        local corruptionRemaining = target:DebuffRemaining(corruptionID) or 0
        if corruptionRemaining == 0 or InPandemicWindow(corruptionRemaining, corruptionDuration) then
            if corruptionSpell:Castable(target) then
                return corruptionSpell:Cast(target)
            end
        end

        -- 3. Haunt (if talented)
        if Spells.Haunt:IsKnown() then
            local hauntRemaining = target:DebuffRemaining(HAUNT_DEBUFF) or 0
            if hauntRemaining == 0 or InPandemicWindow(hauntRemaining, Config.hauntDuration) then
                if Spells.Haunt:Castable(target) then
                    return Spells.Haunt:Cast(target)
                end
            end
        end

        return false
    end

    ---------------------------------------------------------------------------
    -- Multi-DoT
    ---------------------------------------------------------------------------
    local function MultiDot()
        if StateCache.enemiesIn40y < 2 then return false end

        local dotted = 0
        for _, enemy in ipairs(VanFW.objects.enemies) do
            if dotted >= Config.maxDotTargets then break end
            if enemy:exists() and not IsDead(enemy) and IsEnemy(enemy) then
                local dist = enemy:distance()
                if dist and dist <= 40 then
                    local agonyRemaining = enemy:DebuffRemaining(980) or 0
                    if agonyRemaining == 0 then
                        if Spells.Agony:Castable(enemy) then
                            return Spells.Agony:Cast(enemy)
                        end
                    end
                    dotted = dotted + 1
                end
            end
        end

        return false
    end

    ---------------------------------------------------------------------------
    -- Single Target Rotation
    ---------------------------------------------------------------------------
    local function SingleTargetRotation(target)
        if not IsEnemy(target) then return false end

        local distance = target:distance()
        if not distance or distance > 40 then return false end

        FaceTarget(target)

        -- Skip if casting/channeling (unless standing in bad — stop cast and move)
        local BA = VanFW.BossAware
        if StateCache.playerCasting or StateCache.playerChanneling then
            if BA and BA:IsStandingInBad() then
                -- Standing in fire while casting → stop cast so player can move
                if _G.SpellStopCasting then
                    pcall(_G.SpellStopCasting)
                end
            else
                return false
            end
        end

        -- Defensive
        if DefensiveRotation() then return true end

        -- Maintain DoTs
        if MaintainDots(target) then return true end

        -- Nightfall proc — free instant Shadow Bolt
        if StateCache.hasNightfall then
            if Spells.ShadowBolt:Castable(target) then
                return Spells.ShadowBolt:Cast(target)
            end
        end

        -- Shard Instability proc — free UA
        if StateCache.hasShardInstability then
            if Spells.UnstableAffliction:Castable(target) then
                return Spells.UnstableAffliction:Cast(target)
            end
        end

        -- DBM: save CDs if phase transition coming within 10s
        local DBMI = VanFW.DBM
        local shouldSaveCDs = false
        if DBMI and DBMI:IsAvailable() and DBMI:InEncounter() then
            shouldSaveCDs = DBMI:ShouldSaveCooldowns(10)
        end

        -- Cooldowns: Malevolence (skip if saving for phase)
        if not shouldSaveCDs and Config.useMalevolence and StateCache.hasMalevolenceTalent then
            if Spells.Malevolence:Castable() then
                return Spells.Malevolence:SelfCast()
            end
        end

        -- Cooldowns: Darkglare (skip if saving for phase)
        if not shouldSaveCDs and Config.useDarkglare and StateCache.hasAgony and (StateCache.hasCorruption or StateCache.hasWither) and StateCache.hasUA then
            if Spells.SummonDarkglare:Castable() then
                return Spells.SummonDarkglare:SelfCast()
            end
        end

        -- Soul Rot
        if Config.useSoulRot and StateCache.hasSoulRotTalent then
            if Spells.SoulRot:Castable(target) then
                return Spells.SoulRot:Cast(target)
            end
        end

        -- Dark Harvest (when ≤ 2 shards)
        if StateCache.hasDarkHarvestTalent and StateCache.playerShards <= 2 then
            if StateCache.hasAgony or StateCache.hasCorruption or StateCache.hasWither or StateCache.hasUA then
                if Spells.DarkHarvest:Castable(target) then
                    return Spells.DarkHarvest:Cast(target)
                end
            end
        end

        -- Phantom Singularity
        if Config.usePhantomSingularity and StateCache.hasPhantomSingularity then
            if Spells.PhantomSingularity:Castable(target) then
                return Spells.PhantomSingularity:Cast(target)
            end
        end

        -- UA to avoid shard cap
        if StateCache.playerShards >= Config.uaShardThreshold then
            if Spells.UnstableAffliction:Castable(target) then
                return Spells.UnstableAffliction:Cast(target)
            end
        end

        -- UA if not on target
        if not StateCache.hasUA and StateCache.playerShards >= 1 then
            if Spells.UnstableAffliction:Castable(target) then
                return Spells.UnstableAffliction:Cast(target)
            end
        end

        -- Drain Soul execute (< 20% HP)
        if StateCache.hasDrainSoulTalent and StateCache.targetHP < Config.executeThreshold then
            if Spells.DrainSoul:Castable(target) then
                return Spells.DrainSoul:Cast(target)
            end
        end

        -- Filler
        local filler = GetFillerSpell()
        if filler:Castable(target) then
            return filler:Cast(target)
        end

        return false
    end

    ---------------------------------------------------------------------------
    -- AoE Rotation
    ---------------------------------------------------------------------------
    local function AoERotation(target)
        if not IsEnemy(target) then return false end

        local distance = target:distance()
        if not distance or distance > 40 then return false end

        FaceTarget(target)

        if StateCache.playerCasting or StateCache.playerChanneling then return false end

        -- Defensive
        if DefensiveRotation() then return true end

        -- Vile Taint (applies Agony to all)
        if Config.useVileTaint and StateCache.hasVileTaint then
            if Spells.VileTaint:Castable(target) then
                return Spells.VileTaint:AoECast(target)
            end
        end

        -- Soul Rot
        if Config.useSoulRot and StateCache.hasSoulRotTalent then
            if Spells.SoulRot:Castable(target) then
                return Spells.SoulRot:Cast(target)
            end
        end

        -- Seed of Corruption (AoE spread)
        if StateCache.enemiesIn10y >= Config.aoeThreshold and StateCache.playerShards >= 1 then
            if Spells.SeedOfCorruption:Castable(target) then
                return Spells.SeedOfCorruption:Cast(target)
            end
        end

        -- Multi-dot Agony
        if MultiDot() then return true end

        -- Maintain DoTs on primary target
        if MaintainDots(target) then return true end

        -- Cooldowns
        if Config.useMalevolence and StateCache.hasMalevolenceTalent then
            if Spells.Malevolence:Castable() then
                return Spells.Malevolence:SelfCast()
            end
        end

        if Config.useDarkglare and StateCache.hasAgony then
            if Spells.SummonDarkglare:Castable() then
                return Spells.SummonDarkglare:SelfCast()
            end
        end

        -- Phantom Singularity (AoE)
        if Config.usePhantomSingularity and StateCache.hasPhantomSingularity then
            if Spells.PhantomSingularity:Castable(target) then
                return Spells.PhantomSingularity:AoECast(target)
            end
        end

        -- UA to avoid cap
        if StateCache.playerShards >= Config.uaShardThreshold then
            if Spells.UnstableAffliction:Castable(target) then
                return Spells.UnstableAffliction:Cast(target)
            end
        end

        -- Filler
        local filler = GetFillerSpell()
        if filler:Castable(target) then
            return filler:Cast(target)
        end

        return false
    end

    ---------------------------------------------------------------------------
    -- Main Rotation
    ---------------------------------------------------------------------------
    local LastTargetGUID = nil

    local function MainRotation()
        local player = VanFW.player
        if not player or not player:exists() then return end

        -- Update target reference
        if UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target") then
            local currentGUID = UnitGUID("target")
            if currentGUID then
                local targetObj = VanFW:GetObjectByGUID(currentGUID)
                if targetObj and targetObj:exists() and not IsDead(targetObj) then
                    VanFW.target = targetObj
                end
            end
        end

        -- Reset state on target switch
        local currentTargetGUID = UnitExists("target") and UnitGUID("target") or nil
        if currentTargetGUID ~= LastTargetGUID then
            if LastTargetGUID ~= nil and VanFW.ClearSpellQueue then
                VanFW:ClearSpellQueue()
            end
            LastTargetGUID = currentTargetGUID
        end

        UpdateStateCache()

        -- Skip if casting/channeling
        if StateCache.playerCasting or StateCache.playerChanneling then return end

        -- Skip if spell pending (ground target)
        if WGG_IsSpellPending and WGG_IsSpellPending() then return end

        -- Find best target
        local bestTarget = nil

        if VanFW.target and VanFW.target:exists() and not IsDead(VanFW.target) and IsEnemy(VanFW.target) then
            bestTarget = VanFW.target
        end

        if not bestTarget and UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target") then
            local guid = UnitGUID("target")
            if guid then
                local obj = VanFW:GetObjectByGUID(guid)
                if obj and obj:exists() and not IsDead(obj) then
                    bestTarget = obj
                    VanFW.target = obj
                end
            end
        end

        if not bestTarget then return end

        -- Route to ST or AoE
        if StateCache.enemiesIn40y >= Config.aoeThreshold then
            AoERotation(bestTarget)
        else
            SingleTargetRotation(bestTarget)
        end
    end

    ---------------------------------------------------------------------------
    -- Start / Stop
    ---------------------------------------------------------------------------
    local function StartRotation()
        talentsDetected = false
        local success = VanFW:StartRotation(MainRotation, 0.075)
        if success then
            VanFW:Success("Affliction Warlock Rotation Started!")
        end
        return success
    end

    local function StopRotation()
        local success = VanFW:StopRotation()
        if success then
            VanFW:Success("Affliction Warlock Rotation Stopped!")
        end
        return success
    end

    -- Register with framework
    VanFW.Rota = {
        Start = StartRotation,
        Stop = StopRotation,
        Info = RotationInfo,
    }

    VanFW:Success("Affliction Warlock rotation loaded!")
    VanFW:Print("Use /rot to toggle rotation on/off")
end)
