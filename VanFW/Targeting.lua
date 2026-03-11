local VanFW = VanFW

VanFW.targeting = {
  preferLowHealth = true,
  preferCasting = true,
  preferBoss = true,
  maxRange = 40,
  ignoreCC = true,
}

-- Broad list of common CC spell IDs used as fallback when aura API is unavailable
local COMMON_CC_DEBUFFS = {
  -- Polymorph variants
  118, 28271, 28272, 61305, 61721, 61780, 126819, 161353, 161354, 161355, 161372,
  -- Hex
  51514, 210873, 211004, 211010, 211015,
  -- Repentance
  20066,
  -- Sap
  6770,
  -- Hibernate
  2637,
  -- Entangling Roots
  339,
  -- Fear
  5782, 118699,
  -- Psychic Scream
  8122,
  -- Intimidating Shout
  5246,
  -- Freezing Trap
  3355,
  -- Paralysis
  115078,
  -- Blind
  2094,
  -- Banish
  710,
  -- Cyclone
  33786,
  -- Ring of Frost
  82691,
  -- Imprison
  217832,
  -- Incapacitating Roar
  99,
}

local function CalculateTargetPriority(enemy)
  if not enemy or not enemy:IsValid() then
    return 0
  end
  
  local score = 100
  
  if enemy:IsDead() then
    return 0
  end
  
  local distance = enemy:Distance()
  if distance > VanFW.targeting.maxRange then
    return 0
  end
  score = score - (distance * 0.5)
  
  if VanFW.targeting.preferLowHealth then
    local healthPercent = enemy:HealthPercent()
    score = score + (100 - healthPercent) * 0.5
  end
  
  if VanFW.targeting.preferCasting then
    if enemy:IsCasting() or enemy:IsChanneling() then
      score = score + 50
      
      if enemy:IsInterruptible() then
        score = score + 30
      end
    end
  end
  
  if VanFW.targeting.preferBoss then
    if enemy:IsBoss() then
      score = score + 100
    end
  end
  
  if enemy:InCombat() then
    score = score + 20
  end
  
  if not enemy:HasLoS() then
    score = score - 50
  end
  
  if VanFW.targeting.ignoreCC then
    local isCC = false
    for _, debuffID in ipairs(COMMON_CC_DEBUFFS) do
      if enemy:HasDebuff(debuffID) then
        isCC = true
        break
      end
    end

    if isCC then
      score = score - 80
    end
  end
  
  return score
end

function VanFW:GetBestTarget()
  local enemies = self:GetEnemies()
  
  if #enemies == 0 then
    return nil
  end
  
  local bestTarget = nil
  local bestScore = 0
  
  for _, enemy in ipairs(enemies) do
    local score = CalculateTargetPriority(enemy)
    
    if score > bestScore then
      bestScore = score
      bestTarget = enemy
    end
  end
  
  return bestTarget
end

function VanFW:ShouldSwapTarget()
  if not self.config.targetSwap then
    return false
  end
  
  if self.time - self.lastTargetSwap < self.config.targetSwapDelay then
    return false
  end
  
  local currentTarget = self.target
  
  if not currentTarget or not currentTarget:IsValid() then
    return true
  end
  
  if currentTarget:IsDead() then
    return true
  end
  
  local bestTarget = self:GetBestTarget()
  
  if not bestTarget then
    return false
  end
  
  local currentScore = CalculateTargetPriority(currentTarget)
  local bestScore = CalculateTargetPriority(bestTarget)
  
  if bestScore > currentScore * 1.2 then
    return true, bestTarget
  end
  
  return false
end

function VanFW:SwapTarget(target)
  if not target then
    return false
  end

  -- CRITICAL: Don't swap if ground spell is pending
  -- This prevents canceling AoE spell casts like Shadow Crash
  if WGG_IsSpellPending and WGG_IsSpellPending() then
    self:Debug("Blocking target swap - ground spell pending", "Targeting")
    return false
  end

  local token = target:GetToken()
  if not token then
    return false
  end

  -- Protect TargetUnit call as it's a protected function
  local success, err = pcall(TargetUnit, token)
  if not success then
    self:Debug("Failed to swap target (protected function): " .. tostring(err), "Targeting")
    return false
  end

  -- Force target update after brief delay to let WoW process the target change
  -- We need to update objects first, then special units
  C_Timer.After(0.05, function()
    if self.UpdateObjects then
      self:UpdateObjects()
    end
    if self.UpdateSpecialUnits then
      self:UpdateSpecialUnits()
      self:Debug("Force updated target reference after swap", "Targeting")
    end
  end)

  -- Clear spell queue after target swap to prevent casting spells on wrong target
  if self.ClearSpellQueue then
    self:ClearSpellQueue()
    self:Debug("Cleared spell queue after target swap", "Targeting")
  end

  -- Cancel any pending spell cursor
  if WGG_IsSpellPending and WGG_IsSpellPending() then
    if WGG_Click and self.player then
      local x, y, z = self.player:position()
      if x and y and z then
        WGG_Click(x, y, z, 4)  -- Right-click to cancel pending spell
        self:Debug("Cancelled pending spell cursor after target swap", "Targeting")
      end
    end
  end

  -- Reset spell pending check timer
  self.lastSpellPendingCheck = nil

  self.lastTargetSwap = self.time

  self:Debug("Target swapped to: " .. tostring(target:Name()), "Targeting")

  return true
end


function VanFW:UpdateSmartTargeting()
  if not self.config.targetSwap then
    return
  end
  
  if not self.inCombat then
    return
  end
  
  local shouldSwap, newTarget = self:ShouldSwapTarget()
  
  if shouldSwap then
    if newTarget then
      self:SwapTarget(newTarget)
    else
      local bestTarget = self:GetBestTarget()
      if bestTarget then
        self:SwapTarget(bestTarget)
      end
    end
  end
end


function VanFW:TargetLowestHealth(range)
  local enemy = self:GetLowestHealthEnemy(range)
  if enemy then
    self:SwapTarget(enemy)
    return true
  end
  return false
end

function VanFW:TargetClosest(range)
  local enemy = self:GetClosestEnemy(range)
  if enemy then
    self:SwapTarget(enemy)
    return true
  end
  return false
end

function VanFW:TargetCasting(range)
  range = range or 40
  
  local enemies = self:GetEnemiesInRange(range)
  local bestCastingTarget = nil
  local bestCastRemaining = 0
  
  for _, enemy in ipairs(enemies) do
    if enemy:IsCasting() or enemy:IsChanneling() then
      local castRemaining = enemy:CastRemaining()
      
      if castRemaining > bestCastRemaining then
        bestCastRemaining = castRemaining
        bestCastingTarget = enemy
      end
    end
  end
  
  if bestCastingTarget then
    self:SwapTarget(bestCastingTarget)
    return true
  end
  
  return false
end

function VanFW:InitializeTargeting()
  self:Debug("Targeting system initialized", "Targeting")
end

function VanFW:GetBestHealTarget(range, hpThreshold)
    range = range or 40
    hpThreshold = hpThreshold or 100

    local bestTarget = nil
    local lowestHP = 100
    local highestPriority = 999

    -- Priority system:
    -- 1. Critical HP (< 35%) = Priority 1
    -- 2. Low HP (< 60%) = Priority 2
    -- 3. Medium HP (< 80%) = Priority 3
    -- 4. Topping off (< 95%) = Priority 4

    local function GetHealPriority(hp)
        if hp < 35 then return 1 end
        if hp < 60 then return 2 end
        if hp < 80 then return 3 end
        if hp < 95 then return 4 end
        return 999
    end

    local player = self.player
    if player and player:exists() and not player:dead() then
        local hp = player:hp()
        if hp < hpThreshold then
            local priority = GetHealPriority(hp)
            if priority < highestPriority or (priority == highestPriority and hp < lowestHP) then
                bestTarget = player
                lowestHP = hp
                highestPriority = priority
            end
        end
    end

    for _, ally in ipairs(self.objects.friends) do
        if ally:exists() and not ally:dead() and ally:distance() <= range then
            local hp = ally:hp()
            if hp < hpThreshold then
                local priority = GetHealPriority(hp)
                if priority < highestPriority or (priority == highestPriority and hp < lowestHP) then
                    bestTarget = ally
                    lowestHP = hp
                    highestPriority = priority
                end
            end
        end
    end

    return bestTarget, lowestHP, highestPriority
end


function VanFW:GetBestDamageTarget(range, skipCC)
    range = range or 40
    skipCC = skipCC ~= false  -- Default true

    local bestTarget = nil
    local lowestHP = 100

    -- Priority system:
    -- 1. Current target (if valid and not CC'd)
    -- 2. Lowest HP enemy (execute priority < 20%)
    -- 3. Closest enemy

    local target = self.target
    if target and target:exists() and target:enemy() and not target:dead() and target:distance() < range then
        if not skipCC or not target:cc() then
            return target
        end
    end

    for _, enemy in ipairs(self.objects.enemies) do
        if enemy:exists() and not enemy:dead() and enemy:distance() < range then
            -- Skip CC'd enemies if requested
            local shouldSkip = skipCC and enemy:cc()

            if not shouldSkip then
                local hp = enemy:hp()

                if hp < 20 then
                    if not bestTarget or hp < lowestHP then
                        bestTarget = enemy
                        lowestHP = hp
                    end
                elseif not bestTarget or (lowestHP >= 20 and enemy:distance() < bestTarget:distance()) then
                    bestTarget = enemy
                    lowestHP = hp
                end
            end
        end
    end

    return bestTarget
end

function VanFW:SelectSmartTarget(mode)
    mode = mode or "auto"  -- "auto", "heal", "damage"

    if mode == "heal" then
        return self:GetBestHealTarget(40, 95)
    elseif mode == "damage" then
        return self:GetBestDamageTarget(40, true)
    else
        -- Auto mode: Prioritize healing if someone is low
        local healTarget, hp, priority = self:GetBestHealTarget(40, 80)
        if healTarget and priority <= 2 then
            return healTarget, "heal"
        end
        local damageTarget = self:GetBestDamageTarget(40, true)
        if damageTarget then
            return damageTarget, "damage"
        end
        return healTarget, "heal"
    end
end