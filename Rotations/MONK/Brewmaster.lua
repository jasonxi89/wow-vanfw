local RotationInfo = {
    name = "Brewmaster",
    class = "MONK",
    spec = "Brewmaster",
    author = "VanFW",
    version = "1.0.0",
    description = "Brewmaster Monk Tank PVE - Midnight 12.0.1",
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
    local UnitHealth = UnitHealth
    local UnitHealthMax = UnitHealthMax
    local UnitCastingInfo = UnitCastingInfo
    local UnitChannelInfo = UnitChannelInfo
    local IsPlayerSpell = IsPlayerSpell
    local UnitStagger = UnitStagger
    local VanFW = VanFW

    VanFW:Print("Loading Brewmaster Monk Rotation...")

    ---------------------------------------------------------------------------
    -- Config
    ---------------------------------------------------------------------------
    local DefaultConfig = {
        -- AoE
        aoeThreshold = 3,
        -- Defensive thresholds
        purifyHeavyStagger = true,
        purifyThreshold = 60,
        celestialBrewThreshold = 50,
        fortifyingBrewThreshold = 30,
        -- Cooldowns
        useExplodingKeg = true,
        useInvokeNiuzao = true,
        useTouchOfDeath = true,
        -- Stagger management
        autoManageStagger = true,
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

    -- Core rotation
    Spells.BlackoutKick     = VanFW:CreateSpell(100784, {priority = 1, name = "Blackout Kick"})
    Spells.KegSmash         = VanFW:CreateSpell(121253, {priority = 2, name = "Keg Smash"})
    Spells.BreathOfFire     = VanFW:CreateSpell(115181, {priority = 3, name = "Breath of Fire"})
    Spells.TigerPalm        = VanFW:CreateSpell(100780, {priority = 7, name = "Tiger Palm"})
    Spells.SpinningCraneKick = VanFW:CreateSpell(330901, {priority = 8, name = "Spinning Crane Kick"})
    Spells.RushingJadeWind  = VanFW:CreateSpell(261715, {priority = 5, name = "Rushing Jade Wind", castMethod = 'name'})
    Spells.ChiBurst         = VanFW:CreateSpell(460485, {priority = 4, name = "Chi Burst", castMethod = 'name'})

    -- Cooldowns
    Spells.ExplodingKeg     = VanFW:CreateSpell(214326, {priority = 1, name = "Exploding Keg"})
    Spells.InvokeNiuzao     = VanFW:CreateSpell(132578, {priority = 1, name = "Invoke Niuzao, the Black Ox", castMethod = 'name'})
    Spells.TouchOfDeath     = VanFW:CreateSpell(322109, {priority = 1, name = "Touch of Death"})

    -- Defensive
    Spells.PurifyingBrew    = VanFW:CreateSpell(119582, {priority = 1, name = "Purifying Brew"})
    Spells.CelestialBrew    = VanFW:CreateSpell(322507, {priority = 1, name = "Celestial Brew"})
    Spells.FortifyingBrew   = VanFW:CreateSpell(115203, {priority = 1, name = "Fortifying Brew"})

    -- Buff/Debuff aura IDs for tracking
    local SHUFFLE_BUFF         = 322120
    local BLACKOUT_COMBO_BUFF  = 228563
    local CHARRED_PASSIONS_BUFF = 338140
    local BREATH_OF_FIRE_DOT   = 123725
    local RUSHING_JADE_WIND_BUFF = 261715
    local EMPTY_BARREL_BUFF    = 1265129

    ---------------------------------------------------------------------------
    -- State Cache
    ---------------------------------------------------------------------------
    local StateCache = {
        lastUpdate = 0,
        updateInterval = 0.03,
        -- Player
        playerHP = 100,
        playerEnergy = 0,
        playerMaxEnergy = 100,
        playerInCombat = false,
        playerCasting = false,
        playerChanneling = false,
        -- Stagger
        staggerAmount = 0,
        staggerPercent = 0,
        isHeavyStagger = false,
        isMediumStagger = false,
        -- Buffs
        hasShuffle = false,
        shuffleRemaining = 0,
        hasBlackoutCombo = false,
        hasCharredPassions = false,
        hasRushingJadeWind = false,
        hasEmptyBarrel = false,
        -- Target
        targetExists = false,
        targetHP = 100,
        targetIsEnemy = false,
        targetIsDead = false,
        hasBreathOfFireDot = false,
        -- Enemies
        enemiesInMelee = 0,
        enemiesIn8y = 0,
        enemiesIn10y = 0,
        -- Talents
        hasBlackoutComboTalent = false,
        hasCharredPassionsTalent = false,
        hasChiBurstTalent = false,
        hasRushingJadeWindTalent = false,
        hasExplodingKegTalent = false,
        hasInvokeNiuzaoTalent = false,
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

    local talentsDetected = false

    local function DetectTalents()
        StateCache.hasBlackoutComboTalent = IsPlayerSpell(196736)
        StateCache.hasCharredPassionsTalent = IsPlayerSpell(338138)
        StateCache.hasChiBurstTalent = IsPlayerSpell(460485)
        StateCache.hasRushingJadeWindTalent = IsPlayerSpell(261715)
        StateCache.hasExplodingKegTalent = IsPlayerSpell(214326)
        StateCache.hasInvokeNiuzaoTalent = IsPlayerSpell(132578)
    end

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
            StateCache.playerEnergy = UnitPower("player", 3) -- Energy
            StateCache.playerMaxEnergy = UnitPowerMax("player", 3)
            StateCache.playerInCombat = player:combat()
            StateCache.playerCasting = UnitCastingInfo("player") ~= nil
            StateCache.playerChanneling = UnitChannelInfo("player") ~= nil

            -- Stagger
            local maxHP = UnitHealthMax("player") or 1
            if UnitStagger then
                StateCache.staggerAmount = UnitStagger("player") or 0
            end
            StateCache.staggerPercent = maxHP > 0 and (StateCache.staggerAmount / maxHP * 100) or 0
            StateCache.isHeavyStagger = StateCache.staggerPercent > 60
            StateCache.isMediumStagger = StateCache.staggerPercent > 30 and StateCache.staggerPercent <= 60

            -- Buffs
            StateCache.hasShuffle = player:HasBuff(SHUFFLE_BUFF) or false
            StateCache.shuffleRemaining = player:BuffRemaining(SHUFFLE_BUFF) or 0
            StateCache.hasBlackoutCombo = player:HasBuff(BLACKOUT_COMBO_BUFF) or false
            StateCache.hasCharredPassions = player:HasBuff(CHARRED_PASSIONS_BUFF) or false
            StateCache.hasRushingJadeWind = player:HasBuff(RUSHING_JADE_WIND_BUFF) or false
            StateCache.hasEmptyBarrel = player:HasBuff(EMPTY_BARREL_BUFF) or false
        end

        -- Target state
        if target and target:exists() then
            StateCache.targetExists = true
            StateCache.targetHP = target:hp()
            StateCache.targetIsEnemy = target:enemy()
            StateCache.targetIsDead = IsDead(target)

            if not StateCache.targetIsDead then
                StateCache.hasBreathOfFireDot = target:HasDebuff(BREATH_OF_FIRE_DOT) or false
            else
                StateCache.hasBreathOfFireDot = false
            end
        else
            StateCache.targetExists = false
            StateCache.targetHP = 100
            StateCache.targetIsEnemy = false
            StateCache.targetIsDead = false
            StateCache.hasBreathOfFireDot = false
        end

        -- Enemy count
        StateCache.enemiesInMelee = 0
        StateCache.enemiesIn8y = 0
        StateCache.enemiesIn10y = 0
        if player and player:exists() then
            for _, enemy in ipairs(VanFW.objects.enemies) do
                if enemy:exists() and not IsDead(enemy) then
                    local dist = enemy:distance()
                    if dist then
                        if dist <= 10 then
                            StateCache.enemiesIn10y = StateCache.enemiesIn10y + 1
                            if dist <= 8 then
                                StateCache.enemiesIn8y = StateCache.enemiesIn8y + 1
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
    -- Stagger & Defensive Management
    ---------------------------------------------------------------------------
    local function ManageDefensives()
        if not Config.autoManageStagger then return false end

        -- Fortifying Brew — emergency
        if StateCache.playerHP < Config.fortifyingBrewThreshold then
            if Spells.FortifyingBrew:Castable() then
                return Spells.FortifyingBrew:SelfCast()
            end
        end

        -- Celestial Brew — absorb shield
        if StateCache.playerHP < Config.celestialBrewThreshold then
            if Spells.CelestialBrew:Castable() then
                return Spells.CelestialBrew:SelfCast()
            end
        end

        -- Purifying Brew — clear heavy stagger
        if StateCache.isHeavyStagger then
            if Spells.PurifyingBrew:Castable() then
                return Spells.PurifyingBrew:SelfCast()
            end
        end

        -- Purifying Brew — medium stagger when HP getting low
        if StateCache.isMediumStagger and StateCache.playerHP < Config.purifyThreshold then
            if Spells.PurifyingBrew:Castable() then
                return Spells.PurifyingBrew:SelfCast()
            end
        end

        return false
    end

    ---------------------------------------------------------------------------
    -- Core Rotation
    ---------------------------------------------------------------------------
    local function CoreRotation(target)
        if not IsEnemy(target) then return false end

        local distance = target:distance()
        if not distance or distance > 8 then return false end

        FaceTarget(target)

        if StateCache.playerCasting or StateCache.playerChanneling then return false end

        -- Defensive management (woven between GCDs)
        if ManageDefensives() then return true end

        -- Touch of Death — execute
        if Config.useTouchOfDeath then
            local targetHP = UnitHealth("target") or 0
            local playerHP = UnitHealthMax("player") or 0
            if targetHP > 0 and targetHP < playerHP then
                if Spells.TouchOfDeath:Castable(target) then
                    return Spells.TouchOfDeath:Cast(target)
                end
            end
        end

        -- 1. Blackout Kick — highest priority, always on CD
        if Spells.BlackoutKick:Castable(target) then
            return Spells.BlackoutKick:Cast(target)
        end

        -- 2. Empty Barrel proc — use Keg Smash immediately when proc is active
        if StateCache.hasEmptyBarrel then
            if Spells.KegSmash:Castable(target) then
                return Spells.KegSmash:Cast(target)
            end
        end

        -- 3. Keg Smash — on cooldown
        if Spells.KegSmash:Castable(target) then
            return Spells.KegSmash:Cast(target)
        end

        -- 4. Breath of Fire — maintain debuff / trigger Charred Passions
        if not StateCache.hasBreathOfFireDot or not StateCache.hasCharredPassions then
            if Spells.BreathOfFire:Castable(target) then
                return Spells.BreathOfFire:Cast(target)
            end
        end

        -- 5. Exploding Keg — burst CD
        if Config.useExplodingKeg and StateCache.hasExplodingKegTalent then
            if Spells.ExplodingKeg:Castable(target) then
                return Spells.ExplodingKeg:Cast(target)
            end
        end

        -- 6. Invoke Niuzao — major CD
        if Config.useInvokeNiuzao and StateCache.hasInvokeNiuzaoTalent then
            if StateCache.isHeavyStagger or StateCache.isMediumStagger then
                if Spells.InvokeNiuzao:Castable() then
                    return Spells.InvokeNiuzao:SelfCast()
                end
            end
        end

        -- 7. Chi Burst (if talented, passive proc — just check if castable)
        if StateCache.hasChiBurstTalent then
            if Spells.ChiBurst:Castable(target) then
                return Spells.ChiBurst:Cast(target)
            end
        end

        -- 8. Rushing Jade Wind — maintain buff
        if StateCache.hasRushingJadeWindTalent and not StateCache.hasRushingJadeWind then
            if Spells.RushingJadeWind:Castable() then
                return Spells.RushingJadeWind:SelfCast()
            end
        end

        -- 9. Tiger Palm — Blackout Combo consumer / brew CD reduction / energy dump
        if StateCache.hasBlackoutComboTalent and StateCache.hasBlackoutCombo then
            if Spells.TigerPalm:Castable(target) then
                return Spells.TigerPalm:Cast(target)
            end
        end

        -- 10. Tiger Palm — filler when energy > 55 (avoid capping)
        if StateCache.playerEnergy > 55 then
            if Spells.TigerPalm:Castable(target) then
                return Spells.TigerPalm:Cast(target)
            end
        end

        -- 11. Spinning Crane Kick — AoE filler (3+ targets) or dead GCD
        if StateCache.enemiesIn8y >= Config.aoeThreshold then
            if Spells.SpinningCraneKick:Castable() then
                return Spells.SpinningCraneKick:SelfCast()
            end
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

        -- Reset on target switch
        local currentTargetGUID = UnitExists("target") and UnitGUID("target") or nil
        if currentTargetGUID ~= LastTargetGUID then
            if LastTargetGUID ~= nil and VanFW.ClearSpellQueue then
                VanFW:ClearSpellQueue()
            end
            LastTargetGUID = currentTargetGUID
        end

        UpdateStateCache()

        if StateCache.playerCasting or StateCache.playerChanneling then return end
        if WGG_IsSpellPending and WGG_IsSpellPending() then return end

        -- Defensive even without target
        if StateCache.playerInCombat and not StateCache.targetExists then
            ManageDefensives()
            return
        end

        -- Find target
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

        CoreRotation(bestTarget)
    end

    ---------------------------------------------------------------------------
    -- Start / Stop
    ---------------------------------------------------------------------------
    local function StartRotation()
        talentsDetected = false
        local success = VanFW:StartRotation(MainRotation, 0.075)
        if success then
            VanFW:Success("Brewmaster Monk Rotation Started!")
        end
        return success
    end

    local function StopRotation()
        local success = VanFW:StopRotation()
        if success then
            VanFW:Success("Brewmaster Monk Rotation Stopped!")
        end
        return success
    end

    VanFW.Rota = {
        Start = StartRotation,
        Stop = StopRotation,
        Info = RotationInfo,
    }

    VanFW:Success("Brewmaster Monk rotation loaded!")
    VanFW:Print("Use /rot to toggle rotation on/off")
end)
