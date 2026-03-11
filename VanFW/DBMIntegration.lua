-- VanFW DBM Integration
-- Hooks into Deadly Boss Mods callbacks to provide boss mechanic awareness
-- Rotation scripts can query DBM state to make smarter decisions

local VanFW = VanFW
if not VanFW then return end

VanFW.DBM = VanFW.DBM or {}
local DBMI = VanFW.DBM

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------
DBMI.config = {
    enabled = true,
    debug = false,
    -- Auto-defensive: trigger defensive CDs before big boss abilities
    autoDefensive = true,
    defensiveLeadTime = 3.0,
    -- Auto-interrupt awareness
    trackInterrupts = true,
    -- Phase tracking
    trackPhases = true,
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
DBMI.state = {
    isLoaded = false,
    inEncounter = false,
    -- Active timers: key = timerID, value = timer data
    activeTimers = {},
    -- Recent announcements
    recentAnnounces = {},
    maxAnnounces = 20,
    -- Boss info
    bossName = nil,
    pullTime = 0,
    encounterDuration = 0,
    -- Upcoming abilities (sorted by time remaining)
    upcomingAbilities = {},
    -- Flags for rotation to query
    bigDamageIncoming = false,
    bigDamageTimer = 0,
    shouldInterrupt = false,
    interruptSpellId = nil,
    phaseChanged = false,
    currentPhase = 0,
}

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
function DBMI:Initialize()
    if not _G.DBM then
        if self.config.debug then
            VanFW:Print("[DBM] Deadly Boss Mods not detected")
        end
        self.state.isLoaded = false
        return false
    end

    if not _G.DBM.RegisterCallback then
        VanFW:Error("[DBM] DBM found but RegisterCallback not available")
        self.state.isLoaded = false
        return false
    end

    self.state.isLoaded = true
    self:RegisterCallbacks()
    VanFW:Success("[DBM] Integration initialized")
    return true
end

---------------------------------------------------------------------------
-- Register DBM Callbacks
---------------------------------------------------------------------------
function DBMI:RegisterCallbacks()
    local DBM = _G.DBM

    -- Pull
    DBM:RegisterCallback("DBM_Pull", function(event, mod, delay)
        DBMI:OnPull(mod, delay)
    end)

    -- Kill
    DBM:RegisterCallback("DBM_Kill", function(event, mod)
        DBMI:OnKill(mod)
    end)

    -- Wipe
    DBM:RegisterCallback("DBM_Wipe", function(event, mod)
        DBMI:OnWipe(mod)
    end)

    -- Timer Start
    DBM:RegisterCallback("DBM_TimerStart", function(event, id, msg, timer, icon, timerType, spellId, colorId, modId, keep, fade, spellName, mobGUID)
        DBMI:OnTimerStart(id, msg, timer, icon, timerType, spellId, spellName)
    end)

    -- Timer Stop
    DBM:RegisterCallback("DBM_TimerStop", function(event, id)
        DBMI:OnTimerStop(id)
    end)

    -- Announce
    DBM:RegisterCallback("DBM_Announce", function(event, msg, icon, announceType, spellId, modId)
        DBMI:OnAnnounce(msg, icon, announceType, spellId)
    end)

    if self.config.debug then
        VanFW:Print("[DBM] All callbacks registered")
    end
end

---------------------------------------------------------------------------
-- Callback Handlers
---------------------------------------------------------------------------
function DBMI:OnPull(mod, delay)
    self.state.inEncounter = true
    self.state.pullTime = GetTime() + (delay or 0)
    self.state.encounterDuration = 0
    self.state.bossName = mod and mod.localization and mod.localization.general and mod.localization.general.name or "Unknown"
    self.state.currentPhase = 1
    self.state.phaseChanged = true
    self:ClearTimers()

    if VanFW.MCP then
        VanFW.MCP:Combat("DBM Pull", {
            boss = self.state.bossName,
            delay = delay,
        })
    end

    if self.config.debug then
        VanFW:Print("[DBM] Pull: " .. self.state.bossName)
    end
end

function DBMI:OnKill(mod)
    self.state.inEncounter = false
    self.state.encounterDuration = GetTime() - self.state.pullTime
    self:ClearTimers()

    if VanFW.MCP then
        VanFW.MCP:Combat("DBM Kill", {
            boss = self.state.bossName,
            duration = self.state.encounterDuration,
        })
    end

    if self.config.debug then
        VanFW:Print("[DBM] Kill: " .. (self.state.bossName or "Unknown"))
    end
end

function DBMI:OnWipe(mod)
    self.state.inEncounter = false
    self.state.encounterDuration = GetTime() - self.state.pullTime
    self:ClearTimers()

    if VanFW.MCP then
        VanFW.MCP:Combat("DBM Wipe", {
            boss = self.state.bossName,
            duration = self.state.encounterDuration,
        })
    end

    if self.config.debug then
        VanFW:Print("[DBM] Wipe: " .. (self.state.bossName or "Unknown"))
    end
end

function DBMI:OnTimerStart(id, msg, timer, icon, timerType, spellId, spellName)
    if not id then return end

    local timerData = {
        id = id,
        msg = msg,
        duration = timer,
        startTime = GetTime(),
        expiresAt = GetTime() + (timer or 0),
        icon = icon,
        timerType = timerType,  -- "cd", "cast", "target", "stage", "break", "pull", "berserk"
        spellId = spellId,
        spellName = spellName,
    }

    self.state.activeTimers[id] = timerData

    -- Detect phase changes
    if timerType == "stage" and self.config.trackPhases then
        self.state.currentPhase = self.state.currentPhase + 1
        self.state.phaseChanged = true
    end

    -- Detect big incoming damage (cast timers with short duration)
    if self.config.autoDefensive and timerType == "cast" and timer and timer <= self.config.defensiveLeadTime then
        self.state.bigDamageIncoming = true
        self.state.bigDamageTimer = timerData.expiresAt
    end

    -- Log to MCP
    if VanFW.MCP then
        VanFW.MCP:Combat("DBM Timer", {
            id = id,
            msg = msg,
            timer = timer,
            timerType = timerType,
            spellId = spellId,
        })
    end

    if self.config.debug then
        VanFW:Print(string.format("[DBM] Timer: %s (%.1fs, type=%s)", msg or id, timer or 0, timerType or "?"))
    end
end

function DBMI:OnTimerStop(id)
    if id and self.state.activeTimers[id] then
        self.state.activeTimers[id] = nil
    end
end

function DBMI:OnAnnounce(msg, icon, announceType, spellId)
    local announce = {
        msg = msg,
        icon = icon,
        announceType = announceType,
        spellId = spellId,
        timestamp = GetTime(),
    }

    table.insert(self.state.recentAnnounces, announce)

    -- Trim old announces
    while #self.state.recentAnnounces > self.config.maxAnnounces do
        table.remove(self.state.recentAnnounces, 1)
    end

    if VanFW.MCP then
        VanFW.MCP:Combat("DBM Announce", {
            msg = msg,
            announceType = announceType,
            spellId = spellId,
        })
    end
end

---------------------------------------------------------------------------
-- Query Functions (for Rotation scripts)
---------------------------------------------------------------------------

-- Is DBM loaded and available?
function DBMI:IsAvailable()
    return self.state.isLoaded
end

-- Are we in a boss encounter?
function DBMI:InEncounter()
    return self.state.inEncounter
end

-- Get time remaining on a specific timer by partial message match
function DBMI:GetTimerRemaining(searchText)
    local currentTime = GetTime()
    for _, timer in pairs(self.state.activeTimers) do
        if timer.msg and timer.msg:find(searchText) then
            local remaining = timer.expiresAt - currentTime
            if remaining > 0 then
                return remaining, timer
            end
        end
    end
    return 0, nil
end

-- Get time remaining on a timer by spell ID
function DBMI:GetTimerBySpellId(spellId)
    local currentTime = GetTime()
    for _, timer in pairs(self.state.activeTimers) do
        if timer.spellId == spellId then
            local remaining = timer.expiresAt - currentTime
            if remaining > 0 then
                return remaining, timer
            end
        end
    end
    return 0, nil
end

-- Get the next upcoming ability (shortest remaining timer)
function DBMI:GetNextAbility()
    local currentTime = GetTime()
    local shortest = nil
    local shortestRemaining = 999

    for _, timer in pairs(self.state.activeTimers) do
        if timer.timerType == "cd" or timer.timerType == "cast" then
            local remaining = timer.expiresAt - currentTime
            if remaining > 0 and remaining < shortestRemaining then
                shortestRemaining = remaining
                shortest = timer
            end
        end
    end

    return shortest, shortestRemaining
end

-- Is big damage coming soon? (within N seconds)
function DBMI:IsBigDamageIncoming(withinSeconds)
    withinSeconds = withinSeconds or self.config.defensiveLeadTime
    if not self.state.bigDamageIncoming then return false end

    local remaining = self.state.bigDamageTimer - GetTime()
    if remaining <= 0 then
        self.state.bigDamageIncoming = false
        return false
    end

    return remaining <= withinSeconds, remaining
end

-- Should we save CDs? (e.g., boss phase transition coming)
function DBMI:ShouldSaveCooldowns(withinSeconds)
    withinSeconds = withinSeconds or 10
    local currentTime = GetTime()

    for _, timer in pairs(self.state.activeTimers) do
        if timer.timerType == "stage" then
            local remaining = timer.expiresAt - currentTime
            if remaining > 0 and remaining <= withinSeconds then
                return true, remaining
            end
        end
    end

    return false, 0
end

-- Did we just change phase? (returns true once, then resets)
function DBMI:DidPhaseChange()
    if self.state.phaseChanged then
        self.state.phaseChanged = false
        return true, self.state.currentPhase
    end
    return false, self.state.currentPhase
end

-- Get all active timers of a specific type
function DBMI:GetTimersByType(timerType)
    local result = {}
    local currentTime = GetTime()

    for _, timer in pairs(self.state.activeTimers) do
        if timer.timerType == timerType then
            local remaining = timer.expiresAt - currentTime
            if remaining > 0 then
                timer._remaining = remaining
                table.insert(result, timer)
            end
        end
    end

    table.sort(result, function(a, b) return a._remaining < b._remaining end)
    return result
end

-- Get encounter duration
function DBMI:GetEncounterDuration()
    if not self.state.inEncounter then return 0 end
    return GetTime() - self.state.pullTime
end

---------------------------------------------------------------------------
-- Utility
---------------------------------------------------------------------------
function DBMI:ClearTimers()
    self.state.activeTimers = {}
    self.state.recentAnnounces = {}
    self.state.bigDamageIncoming = false
    self.state.shouldInterrupt = false
    self.state.phaseChanged = false
end

-- Cleanup expired timers (called periodically)
function DBMI:CleanupExpiredTimers()
    local currentTime = GetTime()
    for id, timer in pairs(self.state.activeTimers) do
        if timer.expiresAt < currentTime then
            self.state.activeTimers[id] = nil
        end
    end
end

---------------------------------------------------------------------------
-- Update Hook
---------------------------------------------------------------------------
if VanFW.RegisterCallback then
    VanFW:RegisterCallback("onTick", function()
        if DBMI.state.isLoaded and DBMI.state.inEncounter then
            DBMI:CleanupExpiredTimers()
        end
    end)
end

-- Delayed init (wait for DBM to fully load)
C_Timer.After(3.0, function()
    DBMI:Initialize()
end)

VanFW:Debug("DBM Integration module loaded", "DBM")
