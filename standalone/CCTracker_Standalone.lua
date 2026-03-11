--[[
================================================================================
  CCTracker Standalone - WGG Native Crowd Control Detection
  Version: 1.0.0

  Zero dependencies. Only requires WGG API.
  Tracks breakable CC debuffs on all visible enemies using WGG memory reads
  -- NOT affected by Midnight 12.0 addon restrictions.
  Auto-updates during combat only; no manual Update() call needed.

  SETUP:
    1. Put this file in C:\WGG\
    2. In your script: local CC = _G.CCTracker
    3. Query: CC:IsUnitCCd(token), CC:IsTargetCCd(), etc.
       (auto-updates in combat via OnUpdate frame)

  QUICK EXAMPLE:
    local CC = _G.CCTracker

    -- In your rotation function:
    local function MyRotation()
        -- Don't attack CC'd target
        if CC:IsTargetCCd() then
            -- switch target or wait
        end

        -- Should I avoid this unit entirely?
        if CC:ShouldAvoidTarget("target") then
            -- find a different target
        end

        -- Get all CC'd enemies (for UI or decision making)
        local ccdEnemies = CC:GetCCdEnemies()
        for _, info in ipairs(ccdEnemies) do
            print(info.token, info.spellName, info.duration)
        end
    end

  FULL API:
    CC:IsUnitCCd(unitToken)         bool, spellId, duration
    CC:GetCCdEnemies()              table of {token, spellId, spellName, duration}
    CC:IsTargetCCd()                bool
    CC:ShouldAvoidTarget(unitToken) bool
    CC:GetCCSpellList()             table of spell IDs (reference, not copy)
    CC:AddCCSpell(spellId)          add custom CC spell
    CC:RemoveCCSpell(spellId)       remove a CC spell

  CONFIG (optional):
    CC.config.enabled = true
    CC.config.updateInterval = 0.1
    CC.config.debug = false
================================================================================
]]

local CC = {}
local VERSION = "1.0.0"

-- Conflict detection -- warn if replacing an older version
if _G.CCTracker and _G.CCTracker.VERSION then
    print("|cFFFFFF00[CCTracker]|r Replacing v" .. _G.CCTracker.VERSION .. " with v" .. VERSION)
end

CC.VERSION = VERSION

-- Environment validation -- bail out if WGG API is missing
local REQUIRED_WGG = {"WGG_GetObjectCount", "WGG_GetObjectWithIndex", "WGG_ObjectType", "WGG_ObjectToken"}
for _, fn in ipairs(REQUIRED_WGG) do
    if not _G[fn] then
        print("|cFFFF0000[CCTracker]|r Missing WGG function: " .. fn .. ". Module disabled.")
        return
    end
end

_G.CCTracker = CC

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------
CC.config = {
    enabled = true,
    updateInterval = 0.1,   -- 100ms scan interval
    debug = false,
}

---------------------------------------------------------------------------
-- Breakable CC spell IDs -- damage will cancel these effects
-- Only long/breakable CC here; short stuns (HoJ, Kidney Shot, etc.) are
-- excluded because damage does NOT break stuns and hitting stunned targets
-- is intended.
-- Verified against Wowhead 2026-03-10
---------------------------------------------------------------------------
local COMMON_CC_DEBUFFS = {
    -- Mage: Polymorph variants (all 60s, breakable)
    [118]    = true,  -- Polymorph (Sheep)
    [28271]  = true,  -- Polymorph (Turtle)
    [28272]  = true,  -- Polymorph (Pig)
    [61305]  = true,  -- Polymorph (Black Cat)
    [61721]  = true,  -- Polymorph (Rabbit)
    [61780]  = true,  -- Polymorph (Turkey)
    [126819] = true,  -- Polymorph (Porcupine)
    [161353] = true,  -- Polymorph (Polar Bear Cub)
    [161354] = true,  -- Polymorph (Monkey)
    [161355] = true,  -- Polymorph (Penguin)
    [161372] = true,  -- Polymorph (Peacock)
    [383121] = true,  -- Mass Polymorph (15s)
    [31661]  = true,  -- Dragon's Breath (4s disorient)
    [82691]  = true,  -- Ring of Frost (10s)
    -- Shaman: Hex variants (all 60s, breakable)
    [51514]  = true,  -- Hex (Frog)
    [210873] = true,  -- Hex (Compy)
    [211004] = true,  -- Hex (Spider)
    [211010] = true,  -- Hex (Snake)
    [211015] = true,  -- Hex (Cockroach)
    -- Paladin
    [20066]  = true,  -- Repentance (60s)
    [10326]  = true,  -- Turn Evil (40s fear)
    -- Rogue
    [6770]   = true,  -- Sap (60s)
    [2094]   = true,  -- Blind (60s)
    [1776]   = true,  -- Gouge (4s)
    -- Druid
    [2637]   = true,  -- Hibernate (40s)
    [339]    = true,  -- Entangling Roots (30s)
    [33786]  = true,  -- Cyclone (6s)
    [99]     = true,  -- Incapacitating Roar (3s)
    -- Warlock
    [5782]   = true,  -- Fear (20s)
    [118699] = true,  -- Fear (alternate ID)
    [710]    = true,  -- Banish (30s)
    -- Priest
    [8122]   = true,  -- Psychic Scream (8s)
    [9484]   = true,  -- Shackle Undead (50s)
    [605]    = true,  -- Mind Control (30s)
    -- Warrior
    [5246]   = true,  -- Intimidating Shout (8s)
    -- Hunter
    [3355]   = true,  -- Freezing Trap Effect (debuff aura)
    [187650] = true,  -- Freezing Trap (60s, retail ability ID)
    -- Monk
    [115078] = true,  -- Paralysis (60s)
    -- Demon Hunter
    [217832] = true,  -- Imprison (60s)
    -- Evoker
    [360806] = true,  -- Sleep Walk (20s disorient)
    -- Racial
    [107079] = true,  -- Quaking Palm (4s, Pandaren)
}

---------------------------------------------------------------------------
-- State (read-only from outside)
---------------------------------------------------------------------------
CC.state = {
    lastUpdate = 0,
    ccdEnemies = {},      -- {[guid] = {token, spellId, spellName, duration}}
    ccdTokens = {},       -- {[token] = true} quick lookup
}

---------------------------------------------------------------------------
-- Internal: check a single unit's debuffs for CC
-- Returns spellId, duration if CC'd, nil otherwise
---------------------------------------------------------------------------
local function CheckUnitCC(token)
    if not _G.WGG_GetUnitAuraCount or not _G.WGG_GetUnitAuraByIndex then
        return nil, nil
    end

    local count = _G.WGG_GetUnitAuraCount(token)
    if not count then return nil, nil end

    for i = 0, count - 1 do
        local spellId, stacks, duration, flags, instanceID, isHarmful = _G.WGG_GetUnitAuraByIndex(token, i)
        if spellId and COMMON_CC_DEBUFFS[spellId] then
            local totalDuration = duration or 0
            return spellId, totalDuration
        end
    end

    return nil, nil
end

---------------------------------------------------------------------------
-- Internal: scan all visible enemies via WGG object manager
---------------------------------------------------------------------------
local function ScanEnemies()
    if not _G.WGG_GetObjectCount or not _G.WGG_GetObjectWithIndex then return end
    if not _G.WGG_ObjectType or not _G.WGG_ObjectToken then return end

    local ccdEnemies = {}
    local ccdTokens = {}
    local count = _G.WGG_GetObjectCount()

    for i = 0, count - 1 do
        local obj = _G.WGG_GetObjectWithIndex(i)
        if obj and obj ~= 0 then
            local typeOk, objType = pcall(_G.WGG_ObjectType, obj)
            -- 5 = Unit (NPC), 6 = Player
            if typeOk and (objType == 5 or objType == 6) then
                local tokenOk, token = pcall(_G.WGG_ObjectToken, obj)
                if tokenOk and token and token ~= "" then
                    if UnitExists(token) and UnitCanAttack("player", token) and not UnitIsDead(token) then
                        local spellId, duration = CheckUnitCC(token)
                        if spellId then
                            local guid = UnitGUID(token)
                            local spellName = GetSpellInfo(spellId) or ("Spell#" .. spellId)
                            ccdEnemies[guid or token] = {
                                token = token,
                                spellId = spellId,
                                spellName = spellName,
                                duration = duration,
                            }
                            ccdTokens[token] = true
                        end
                    end
                end
            end
        end
    end

    CC.state.ccdEnemies = ccdEnemies
    CC.state.ccdTokens = ccdTokens
end

---------------------------------------------------------------------------
-- Main Update (called automatically during combat)
---------------------------------------------------------------------------
function CC:Update()
    if not self.config.enabled then return end

    local now = GetTime()
    self.state.lastUpdate = now

    ScanEnemies()
end

---------------------------------------------------------------------------
-- Query API
---------------------------------------------------------------------------

--- Is a specific enemy CC'd?
--- @param unitToken string Unit token (e.g. "target", "nameplate3")
--- @return boolean isCCd
--- @return number|nil spellId CC spell ID if CC'd
--- @return number|nil duration Total duration if CC'd
function CC:IsUnitCCd(unitToken)
    if not unitToken then return false, nil, nil end

    -- Check cached results first (fast path)
    if self.state.ccdTokens[unitToken] then
        local guid = UnitGUID(unitToken)
        local entry = guid and self.state.ccdEnemies[guid]
        if entry then
            return true, entry.spellId, entry.duration
        end
    end

    -- Fallback: live check for units not in the last scan
    local spellId, duration = CheckUnitCC(unitToken)
    if spellId then
        return true, spellId, duration
    end

    return false, nil, nil
end

--- Get all CC'd enemies currently in range
--- @return table List of {token, spellId, spellName, duration}
function CC:GetCCdEnemies()
    local result = {}
    for _, entry in pairs(self.state.ccdEnemies) do
        result[#result + 1] = {
            token = entry.token,
            spellId = entry.spellId,
            spellName = entry.spellName,
            duration = entry.duration,
        }
    end
    return result
end

--- Is the current target CC'd? (quick check for rotation scripts)
--- @return boolean
function CC:IsTargetCCd()
    return (self:IsUnitCCd("target"))
end

--- Should I avoid attacking this unit? (returns true if CC'd)
--- @param unitToken string Unit token
--- @return boolean
function CC:ShouldAvoidTarget(unitToken)
    return (self:IsUnitCCd(unitToken))
end

--- Get the CC spell list (reference table -- keys are spell IDs, values are true)
--- @return table CC spell lookup table
function CC:GetCCSpellList()
    return COMMON_CC_DEBUFFS
end

--- Add a custom CC spell ID to the list
--- @param spellId number Spell ID to add
function CC:AddCCSpell(spellId)
    if not spellId then return end
    COMMON_CC_DEBUFFS[spellId] = true
    if self.config.debug then
        local name = GetSpellInfo(spellId) or "Unknown"
        print("|cFF00CCFF[CCTracker]|r Added CC spell: " .. name .. " (" .. spellId .. ")")
    end
end

--- Remove a CC spell ID from the list
--- @param spellId number Spell ID to remove
function CC:RemoveCCSpell(spellId)
    if not spellId then return end
    COMMON_CC_DEBUFFS[spellId] = nil
    if self.config.debug then
        print("|cFF00CCFF[CCTracker]|r Removed CC spell: " .. spellId)
    end
end

---------------------------------------------------------------------------
-- Auto-update: combat-aware OnUpdate frame
---------------------------------------------------------------------------
local inCombat = false
local frame = CreateFrame("Frame")
local elapsed = 0

frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        -- Reset state on combat end
        CC.state.ccdEnemies = {}
        CC.state.ccdTokens = {}
    end
end)

frame:SetScript("OnUpdate", function(self, dt)
    if not inCombat then return end
    elapsed = elapsed + dt
    if elapsed >= CC.config.updateInterval then
        elapsed = 0
        CC:Update()
    end
end)

if CC.config.debug then
    print("|cFF00FF00[CCTracker]|r Standalone v" .. VERSION .. " loaded")
end
