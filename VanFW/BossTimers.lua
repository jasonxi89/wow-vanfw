-- VanFW Boss Timers Module
-- Auto-learns boss ability intervals + supports preset tables
-- Uses UnitCastingInfo/UnitChannelInfo polling on boss frames (no CLEU dependency)

local VanFW = VanFW
if not VanFW then return end

VanFW.BossTimers = VanFW.BossTimers or {}
local BT = VanFW.BossTimers

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------
BT.config = {
    enabled = true,
    autoLearn = true,
    saveLearnedData = true,
    dataPath = "c:\\WGG\\cfg\\boss_timers.json",
    -- How many casts to observe before trusting the learned interval
    minSamples = 3,
    -- Tolerance for interval variation (if interval varies > this, it's not periodic)
    intervalTolerance = 3.0,
    debug = false,
}

---------------------------------------------------------------------------
-- Preset Boss Timers (fill per encounter)
-- Format: [encounterKey] = { [spellId] = { interval, name, dangerLevel } }
---------------------------------------------------------------------------
BT.presets = {
    -- =====================================================================
    -- THE VOIDSPIRE (Midnight Season 1)
    -- =====================================================================
    -- Boss 1: Imperator Averzian
    -- Boss 2: Vorasius
    -- Boss 3: Fallen-King Salhadaar
    -- Boss 4: Vaelgor & Ezzorak
    -- Boss 5: Lightblinded Vanguard
    -- Boss 6: Crown of the Cosmos

    -- =====================================================================
    -- TEMPLATE — copy and fill for each boss:
    -- ["BossName"] = {
    --     [spellId] = { interval = 30, name = "Ability Name", danger = "high" },
    --     [spellId] = { interval = 45, name = "Other Ability", danger = "medium" },
    -- },
    -- =====================================================================

    -- Example (placeholder, replace with real data):
    -- ["Vaelgor & Ezzorak"] = {
    --     [000001] = { interval = 25, name = "Midnight Flames",   danger = "critical" },
    --     [000002] = { interval = 15, name = "Dread Breath",      danger = "high" },
    --     [000003] = { interval = 20, name = "Void Howl",         danger = "medium" },
    --     [000004] = { interval = 30, name = "Nullbeam",          danger = "high" },
    -- },
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
BT.state = {
    inEncounter = false,
    encounterName = nil,
    encounterStart = 0,

    -- Observed casts: [spellId] = { lastCast, times = {t1, t2, ...}, count }
    observed = {},

    -- Learned intervals: [spellId] = { interval, name, samples, reliable }
    learned = {},

    -- Active timers: [spellId] = { expiresAt, name, danger, source }
    activeTimers = {},

    -- Cast history for analysis
    castHistory = {},
    maxHistory = 200,
}

---------------------------------------------------------------------------
-- Encounter Detection
---------------------------------------------------------------------------
function BT:StartEncounter(bossName)
    self.state.inEncounter = true
    self.state.encounterName = bossName
    self.state.encounterStart = GetTime()
    self.state.observed = {}
    self.state.learned = {}
    self.state.activeTimers = {}
    self.state.castHistory = {}

    -- Load presets for this boss
    if self.presets[bossName] then
        for spellId, data in pairs(self.presets[bossName]) do
            self.state.learned[spellId] = {
                interval = data.interval,
                name = data.name,
                danger = data.danger or "medium",
                samples = 99,
                reliable = true,
                source = "preset",
            }
        end
        if self.config.debug then
            VanFW:Print("[BossTimers] Loaded presets for " .. bossName)
        end
    end

    -- Load previously learned data
    self:LoadLearnedData(bossName)

    if self.config.debug then
        VanFW:Print("[BossTimers] Encounter started: " .. bossName)
    end
end

function BT:EndEncounter()
    if self.state.inEncounter and self.config.saveLearnedData then
        self:SaveLearnedData()
    end
    self.state.inEncounter = false

    if self.config.debug then
        VanFW:Print("[BossTimers] Encounter ended: " .. (self.state.encounterName or "Unknown"))
    end
end

---------------------------------------------------------------------------
-- Cast Detection (called from onTick polling)
---------------------------------------------------------------------------
function BT:OnBossCast(spellId, spellName, sourceGUID)
    if not self.state.inEncounter then return end
    if not spellId or spellId == 0 then return end

    local now = GetTime()
    local obs = self.state.observed[spellId]

    if not obs then
        -- First time seeing this spell
        self.state.observed[spellId] = {
            lastCast = now,
            times = { now },
            count = 1,
            name = spellName or "Unknown",
        }
    else
        -- Record interval
        local interval = now - obs.lastCast

        -- Ignore very short intervals (< 3s = probably same cast or GCD overlap)
        if interval < 3 then return end

        obs.lastCast = now
        obs.count = obs.count + 1
        table.insert(obs.times, now)
        if #obs.times > 20 then
            table.remove(obs.times, 1)
        end

        -- Auto-learn: calculate average interval
        if self.config.autoLearn and obs.count >= self.config.minSamples then
            self:LearnInterval(spellId, obs)
        end
    end

    -- Record in history
    table.insert(self.state.castHistory, {
        spellId = spellId,
        spellName = spellName or "Unknown",
        time = now,
        encounterTime = now - self.state.encounterStart,
        sourceGUID = sourceGUID,
    })
    while #self.state.castHistory > self.state.maxHistory do
        table.remove(self.state.castHistory, 1)
    end

    -- Start countdown timer for next cast
    local learnedData = self.state.learned[spellId]
    if learnedData and learnedData.reliable then
        self.state.activeTimers[spellId] = {
            expiresAt = now + learnedData.interval,
            name = learnedData.name or spellName or "Unknown",
            danger = learnedData.danger or "medium",
            source = learnedData.source or "learned",
            interval = learnedData.interval,
        }
    end

    -- Log to MCP
    if VanFW.MCP then
        VanFW.MCP:Combat("BossTimer cast", {
            spellId = spellId,
            spellName = spellName,
            hasTimer = learnedData and learnedData.reliable or false,
            nextIn = learnedData and learnedData.interval or nil,
        })
    end

    if self.config.debug then
        local nextStr = learnedData and learnedData.reliable and string.format(" (next in %.1fs)", learnedData.interval) or ""
        VanFW:Print(string.format("[BossTimers] Cast: %s (%d)%s", spellName or "?", spellId, nextStr))
    end
end

---------------------------------------------------------------------------
-- Auto-Learn
---------------------------------------------------------------------------
function BT:LearnInterval(spellId, obs)
    if obs.count < 2 then return end

    local intervals = {}
    for i = 2, #obs.times do
        local diff = obs.times[i] - obs.times[i - 1]
        if diff >= 3 then
            table.insert(intervals, diff)
        end
    end

    if #intervals == 0 then return end

    -- Calculate average
    local sum = 0
    for _, v in ipairs(intervals) do sum = sum + v end
    local avg = sum / #intervals

    -- Check consistency (standard deviation)
    local variance = 0
    for _, v in ipairs(intervals) do
        local diff = v - avg
        variance = variance + diff * diff
    end
    local stddev = math.sqrt(variance / #intervals)

    local isReliable = stddev <= self.config.intervalTolerance and #intervals >= self.config.minSamples

    self.state.learned[spellId] = {
        interval = avg,
        name = obs.name,
        samples = #intervals,
        reliable = isReliable,
        stddev = stddev,
        source = "learned",
        danger = self.state.learned[spellId] and self.state.learned[spellId].danger or "medium",
    }

    if self.config.debug and isReliable then
        VanFW:Print(string.format("[BossTimers] Learned: %s = %.1fs (stddev=%.1f, n=%d)",
            obs.name, avg, stddev, #intervals))
    end
end

-- Boss frame polling via onTick
if VanFW.RegisterCallback then
    VanFW:RegisterCallback("onTick", function()
        if BT.state.inEncounter then
            -- Safety net: auto-end encounter after 45 minutes
            if BT:GetEncounterDuration() > 2700 then
                if BT.config.debug then
                    VanFW:Print("[BossTimers] Encounter timeout (45m), auto-ending")
                end
                BT:EndEncounter()
                return
            end

            -- Process via boss unit casting/channeling detection
            for i = 1, 5 do
                local unit = "boss" .. i
                if UnitExists(unit) and not UnitIsDead(unit) then
                    local guid = UnitGUID(unit)
                    local now = GetTime()

                    -- Check casts
                    local castName, _, _, _, _, _, _, _, _, spellId = UnitCastingInfo(unit)
                    if castName and spellId then
                        local obs = BT.state.observed[spellId]
                        if not obs or (now - obs.lastCast) > 3 then
                            BT:OnBossCast(spellId, castName, guid)
                        end
                    end

                    -- Check channels
                    local chanName, _, _, _, _, _, _, _, chanSpellId = UnitChannelInfo(unit)
                    if chanName and chanSpellId then
                        local obs = BT.state.observed[chanSpellId]
                        if not obs or (now - obs.lastCast) > 3 then
                            BT:OnBossCast(chanSpellId, chanName, guid)
                        end
                    end
                end
            end

            -- Cleanup expired timers
            BT:CleanupTimers()
        end
    end)

    -- Auto-detect encounter start/end
    VanFW:RegisterCallback("onCombatStart", function()
        -- Detect all boss names for multi-boss encounters
        local names = {}
        for i = 1, 5 do
            local unit = "boss" .. i
            if UnitExists(unit) then
                local name = UnitName(unit)
                if name then
                    local isDuplicate = false
                    for _, existing in ipairs(names) do
                        if existing == name then
                            isDuplicate = true
                            break
                        end
                    end
                    if not isDuplicate then
                        table.insert(names, name)
                    end
                end
            end
        end
        if #names > 0 then
            BT:StartEncounter(table.concat(names, " & "))
            return
        end
        -- Fallback: use target name for world bosses
        if UnitExists("target") then
            local classification = UnitClassification("target")
            if classification == "worldboss" then
                BT:StartEncounter(UnitName("target") or "Unknown")
            end
        end
    end)

    VanFW:RegisterCallback("onCombatEnd", function()
        if BT.state.inEncounter then
            BT:EndEncounter()
        end
    end)
end

---------------------------------------------------------------------------
-- Timer Queries (for Rotation scripts)
---------------------------------------------------------------------------

-- Get time until next cast of a specific spell
function BT:GetTimeUntil(spellId)
    local timer = self.state.activeTimers[spellId]
    if not timer then return 999 end
    local remaining = timer.expiresAt - GetTime()
    return remaining > 0 and remaining or 0
end

-- Get the next upcoming boss ability (any spell, sorted by time)
function BT:GetNextAbility()
    local now = GetTime()
    local shortest = nil
    local shortestRemaining = 999

    for spellId, timer in pairs(self.state.activeTimers) do
        local remaining = timer.expiresAt - now
        if remaining > 0 and remaining < shortestRemaining then
            shortestRemaining = remaining
            shortest = {
                spellId = spellId,
                name = timer.name,
                remaining = remaining,
                danger = timer.danger,
                interval = timer.interval,
            }
        end
    end

    return shortest, shortestRemaining
end

-- Get all upcoming abilities sorted by time
function BT:GetAllUpcoming()
    local now = GetTime()
    local result = {}

    for spellId, timer in pairs(self.state.activeTimers) do
        local remaining = timer.expiresAt - now
        if remaining > 0 then
            table.insert(result, {
                spellId = spellId,
                name = timer.name,
                remaining = remaining,
                danger = timer.danger,
                interval = timer.interval,
            })
        end
    end

    table.sort(result, function(a, b) return a.remaining < b.remaining end)
    return result
end

-- Is a dangerous ability coming within N seconds?
function BT:IsDangerousAbilityIn(seconds)
    seconds = seconds or 3
    local now = GetTime()

    for spellId, timer in pairs(self.state.activeTimers) do
        if timer.danger == "critical" or timer.danger == "high" then
            local remaining = timer.expiresAt - now
            if remaining > 0 and remaining <= seconds then
                return true, remaining, timer
            end
        end
    end

    return false, 999, nil
end

-- Get learned data for a spell (for debugging/display)
function BT:GetLearnedData(spellId)
    return self.state.learned[spellId]
end

-- Get all learned spells for current encounter
function BT:GetAllLearned()
    return self.state.learned
end

-- Is encounter active?
function BT:InEncounter()
    return self.state.inEncounter
end

-- Get encounter duration
function BT:GetEncounterDuration()
    if not self.state.inEncounter then return 0 end
    return GetTime() - self.state.encounterStart
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------
function BT:SaveLearnedData()
    if not _G.WGG_FileWrite then return end
    if not self.state.encounterName then return end

    -- Only save reliable learned data
    local toSave = {}
    for spellId, data in pairs(self.state.learned) do
        if data.reliable and data.source == "learned" then
            toSave[tostring(spellId)] = {
                interval = data.interval,
                name = data.name,
                samples = data.samples,
                danger = data.danger,
            }
        end
    end

    -- Load existing file
    local allData = {}
    if _G.WGG_FileExists(self.config.dataPath) then
        local content = _G.WGG_FileRead(self.config.dataPath)
        if content and content ~= "" then
            local ok, parsed = pcall(function()
                return VanFW:DecodeJSON(content)
            end)
            if ok and parsed then allData = parsed end
        end
    end

    allData[self.state.encounterName] = toSave

    local json = VanFW:EncodeJSON(allData)
    _G.WGG_FileWrite(self.config.dataPath, json)

    if self.config.debug then
        VanFW:Print("[BossTimers] Saved learned data for " .. self.state.encounterName)
    end
end

function BT:LoadLearnedData(bossName)
    if not _G.WGG_FileRead or not _G.WGG_FileExists then return end
    if not _G.WGG_FileExists(self.config.dataPath) then return end

    local content = _G.WGG_FileRead(self.config.dataPath)
    if not content or content == "" then return end

    local ok, allData = pcall(function()
        return VanFW:DecodeJSON(content)
    end)
    if not ok or not allData then return end

    local bossData = allData[bossName]
    if not bossData then return end

    local loaded = 0
    for spellIdStr, data in pairs(bossData) do
        local spellId = tonumber(spellIdStr)
        if spellId and not self.state.learned[spellId] then
            self.state.learned[spellId] = {
                interval = data.interval,
                name = data.name,
                samples = data.samples or 0,
                reliable = true,
                source = "saved",
                danger = data.danger or "medium",
            }
            loaded = loaded + 1
        end
    end

    if loaded > 0 and self.config.debug then
        VanFW:Print(string.format("[BossTimers] Loaded %d saved timers for %s", loaded, bossName))
    end
end

---------------------------------------------------------------------------
-- Timer Cleanup
---------------------------------------------------------------------------
function BT:CleanupTimers()
    local now = GetTime()
    for spellId, timer in pairs(self.state.activeTimers) do
        -- Remove timers that are way past due (missed cast or phase skip)
        local grace = math.max(15, (timer.interval or 30) * 0.5)
        if now - timer.expiresAt > grace then
            self.state.activeTimers[spellId] = nil
        end
    end
end

---------------------------------------------------------------------------
-- Slash Command
---------------------------------------------------------------------------
SLASH_BOSSTIMERS1 = "/bt"
SlashCmdList["BOSSTIMERS"] = function(msg)
    local cmd = msg and msg:lower():trim() or ""

    if cmd == "learn" or cmd == "status" then
        if not BT.state.inEncounter then
            VanFW:Print("[BossTimers] Not in encounter")
            return
        end
        print(" ")
        VanFW:Print("[BossTimers] Learned abilities for: " .. (BT.state.encounterName or "Unknown"))
        for spellId, data in pairs(BT.state.learned) do
            local status = data.reliable and "|cFF00FF00OK|r" or "|cFFFFFF00learning|r"
            print(string.format("  [%d] %s = %.1fs (%s, n=%d, src=%s)",
                spellId, data.name, data.interval, status, data.samples or 0, data.source or "?"))
        end
        print(" ")

    elseif cmd == "timers" then
        local upcoming = BT:GetAllUpcoming()
        if #upcoming == 0 then
            VanFW:Print("[BossTimers] No active timers")
            return
        end
        print(" ")
        VanFW:Print("[BossTimers] Upcoming abilities:")
        for _, timer in ipairs(upcoming) do
            local color = timer.danger == "critical" and "|cFFFF0000" or
                          timer.danger == "high" and "|cFFFF8800" or "|cFFFFFF00"
            print(string.format("  %s%.1fs|r - %s [%s]", color, timer.remaining, timer.name, timer.danger))
        end
        print(" ")

    elseif cmd == "debug" then
        BT.config.debug = not BT.config.debug
        VanFW:Print("[BossTimers] Debug: " .. (BT.config.debug and "ON" or "OFF"))

    else
        print(" ")
        VanFW:Print("[BossTimers] Commands:")
        print("  /bt status  - Show learned abilities")
        print("  /bt timers  - Show upcoming ability timers")
        print("  /bt debug   - Toggle debug mode")
        print(" ")
    end
end

VanFW:Debug("Boss Timers module loaded", "BossTimers")
