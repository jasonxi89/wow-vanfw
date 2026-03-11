local VanFW = VanFW
if not VanFW then
    print("|cFFFF0000[AutoTarget]|r VanFW not loaded!")
    return
end


VanFW.AutoTarget = VanFW.AutoTarget or {}
local AutoTarget = VanFW.AutoTarget

AutoTarget.version = "1.0.0"
AutoTarget.enabled = false
AutoTarget.lastSwap = 0
AutoTarget.currentTarget = nil
AutoTarget.nextTarget = nil
AutoTarget.lastUpdate = 0

local UPDATE_INTERVAL = 0.175

local scoreCache = {}
local scoreCacheTime = 0
local SCORE_CACHE_DURATION = 0.1
local ccCheckCache = {}
local ccCacheTime = 0
local CC_CACHE_DURATION = 0.2

local DefaultConfig = {
    enabled = false,
    swapThreshold = 0,
    swapDelay = 0.5,
    maxRange = 40,

    priorityWeightDistance = 1.0,
    priorityWeightHealth = 0.0,
    priorityWeightThreat = 0.0,

    showCurrentTarget = true,
    showNextTarget = true,
    circleSize = 2.0,

    requireLoS = true,
    ignoreCC = true,
    combatOnly = true,
}


local savedConfig = VanFW:LoadRotationConfig("SYSTEM", "AutoTarget", "AutoTarget")
local Config = {}

for k, v in pairs(DefaultConfig) do
    Config[k] = v
end

if savedConfig then
    for k, v in pairs(savedConfig) do
        Config[k] = v
    end
    VanFW:Success("AutoTarget: Loaded saved configuration")
else
    VanFW:Print("AutoTarget: Using default configuration")
end

local function SaveConfig()
    VanFW:SaveRotationConfig("SYSTEM", "AutoTarget", "AutoTarget", Config)
end


local ccDebuffs = {
    -- Disorients
    [331866] = true, [33786] = true, [105421] = true, [10326] = true, [8122] = true,
    [226943] = true, [605] = true, [2094] = true, [5782] = true, [118699] = true,
    [5484] = true, [6358] = true, [115268] = true, [5246] = true, [31661] = true,
    [198909] = true, [207167] = true, [360806] = true, [207685] = true, [209753] = true,
    [202274] = true, [1513] = true, [324263] = true,
    -- Incapacitates
    [203337] = true, [126819] = true, [9484] = true, [196942] = true, [197214] = true,
    [107079] = true, [2637] = true, [3355] = true, [187650] = true, [213691] = true,
    [118] = true, [28272] = true, [277792] = true, [161354] = true, [277787] = true,
    [161355] = true, [161353] = true, [120140] = true, [61305] = true, [61721] = true,
    [61780] = true, [28271] = true, [161372] = true, [391622] = true, [321395] = true,
    [383121] = true, [82691] = true, [123394] = true, [115078] = true, [20066] = true,
    [200196] = true, [1776] = true, [6770] = true, [51514] = true, [211015] = true,
    [210873] = true, [211010] = true, [211004] = true, [277784] = true, [277778] = true,
    [309328] = true, [269352] = true, [710] = true, [6789] = true, [217832] = true, [221527] = true,
    -- Silences
    [47476] = true, [31935] = true, [15487] = true, [1330] = true, [202933] = true, [356727] = true,
    -- Stuns
    [132168] = true, [132169] = true, [199085] = true, [46968] = true, [108194] = true,
    [221562] = true, [91800] = true, [91797] = true, [210141] = true, [334693] = true,
    [203123] = true, [5211] = true, [163505] = true, [24394] = true, [357021] = true,
    [117526] = true, [119392] = true, [119381] = true, [853] = true, [119072] = true,
    [205290] = true, [1833] = true, [408] = true, [202346] = true, [199804] = true,
    [118905] = true, [118345] = true, [287254] = true, [205630] = true, [208618] = true,
    [202244] = true, [305485] = true, [30283] = true, [89766] = true, [171017] = true,
    [171018] = true, [179057] = true, [191427] = true, [211881] = true, [200200] = true,
    [64044] = true, [20549] = true, [255723] = true, [287712] = true, [332423] = true,
    [372245] = true, [389831] = true,
    -- Roots
    [339] = true, [102359] = true, [136634] = true, [122] = true, [33395] = true,
    [111340] = true, [114404] = true, [64695] = true, [63685] = true, [107566] = true,
    [200108] = true, [116706] = true, [235963] = true, [117405] = true, [354051] = true,
    [355689] = true, [105771] = true, [12024] = true, [157997] = true, [162480] = true,
    [190925] = true, [199042] = true, [233395] = true, [356356] = true, [356738] = true,
    [370970] = true, [374020] = true, [374724] = true, [375671] = true, [377488] = true,
    [378760] = true, [385700] = true, [387657] = true, [387796] = true, [388920] = true,
    [389280] = true, [393456] = true, [393813] = true, [394391] = true, [394447] = true,
    [395956] = true, [396722] = true, [45334] = true, [91807] = true, [241887] = true, [285515] = true,
}

local function IsEnemyCCd(enemy)
    if not Config.ignoreCC then return false end

    local currentTime = GetTime()
    local guid = enemy:guid()

    if ccCheckCache[guid] and (currentTime - ccCacheTime) < CC_CACHE_DURATION then
        return ccCheckCache[guid]
    end

    for spellID, _ in pairs(ccDebuffs) do
        if enemy:HasDebuff(spellID) then
            ccCheckCache[guid] = true
            return true
        end
    end

    ccCheckCache[guid] = false
    return false
end

local function ClearCaches()
    local currentTime = GetTime()

    if (currentTime - scoreCacheTime) > SCORE_CACHE_DURATION then
        scoreCache = {}
        scoreCacheTime = currentTime
    end

    if (currentTime - ccCacheTime) > CC_CACHE_DURATION then
        ccCheckCache = {}
        ccCacheTime = currentTime
    end
end

local function GetTargetScore(enemy)
    if not enemy or not enemy:exists() then return -999999 end
    if enemy:dead() then return -999999 end

    local guid = enemy:guid()
    local currentTime = GetTime()

    if scoreCache[guid] and (currentTime - scoreCacheTime) < SCORE_CACHE_DURATION then
        return scoreCache[guid]
    end

    if Config.requireLoS and not enemy:los() then
        scoreCache[guid] = -999999
        return -999999
    end

    if IsEnemyCCd(enemy) then
        scoreCache[guid] = -999999
        return -999999
    end
    local score = 0

    if Config.priorityWeightDistance > 0 then
        local dist = enemy:distanceTo(VanFW.player)
        local distScore = math.max(0, 1000 - dist)
        score = score + (distScore * Config.priorityWeightDistance)
    end

    if Config.priorityWeightHealth > 0 then
        local healthScore = 1000 - enemy:HealthPercent()
        score = score + (healthScore * Config.priorityWeightHealth)
    end

    if Config.priorityWeightThreat > 0 then
        local healthPool = enemy:Health()
        local threatScore = math.min(1000, healthPool * 0.001)
        score = score + (threatScore * Config.priorityWeightThreat)
    end

    if AutoTarget.currentTarget and enemy == AutoTarget.currentTarget then
        score = score + 100
    end

    scoreCache[guid] = score
    return score
end

local function SelectBestTarget()
    if not VanFW.player then return nil end
    if Config.combatOnly and not VanFW.inCombat then return nil end

    local enemies = VanFW:GetEnemiesInRange(Config.maxRange)
    if not enemies or #enemies == 0 then return nil end

    local bestTarget = nil
    local bestScore = -999999

    for _, enemy in ipairs(enemies) do
        local score = GetTargetScore(enemy)
        if score > bestScore then
            bestScore = score
            bestTarget = enemy
        end
    end

    return bestTarget
end

local function SelectNextBestTarget(excludeCurrent)
    if not VanFW.player then return nil end
    if Config.combatOnly and not VanFW.inCombat then return nil end

    local enemies = VanFW:GetEnemiesInRange(Config.maxRange)
    if not enemies or #enemies == 0 then return nil end

    local bestTarget = nil
    local bestScore = -999999

    for _, enemy in ipairs(enemies) do
        if not (excludeCurrent and AutoTarget.currentTarget and enemy == AutoTarget.currentTarget) then
            local score = GetTargetScore(enemy)
            if score > bestScore then
                bestScore = score
                bestTarget = enemy
            end
        end
    end

    return bestTarget
end


local function ShouldSwapTarget()
    if not Config.enabled then return false end
    if not VanFW.inCombat and Config.combatOnly then return false end

    local timeSinceSwap = GetTime() - AutoTarget.lastSwap
    if timeSinceSwap < Config.swapDelay then return false end

    if not AutoTarget.currentTarget or not AutoTarget.currentTarget:exists() or AutoTarget.currentTarget:dead() then
        return true
    end

    if Config.swapThreshold > 0 and Config.swapThreshold < 100 then
        local currentHP = AutoTarget.currentTarget:HealthPercent()
        if currentHP <= Config.swapThreshold then
            return true
        end
    end

    if Config.requireLoS and not AutoTarget.currentTarget:los() then
        return true
    end

    local bestTarget = SelectBestTarget()
    if bestTarget and bestTarget ~= AutoTarget.currentTarget then
        local currentScore = GetTargetScore(AutoTarget.currentTarget)
        local bestScore = GetTargetScore(bestTarget)

        if bestScore > currentScore * 1.2 then
            return true
        end
    end

    return false
end

local function PerformTargetSwap(newTarget)
    if not newTarget or not newTarget:exists() then return false end
    local success = VanFW:SwapTarget(newTarget)
    if success then
        AutoTarget.currentTarget = newTarget
        AutoTarget.lastSwap = GetTime()
        return true
    end
    return false
end


function AutoTarget:Update()
    if not Config.enabled then return end

    local currentTime = GetTime()
    if currentTime - self.lastUpdate < UPDATE_INTERVAL then
        return
    end
    self.lastUpdate = currentTime

    ClearCaches()

    if VanFW.target and VanFW.target:exists() and not VanFW.target:dead() then
        self.currentTarget = VanFW.target
    elseif self.currentTarget and (not self.currentTarget:exists() or self.currentTarget:dead()) then
        self.currentTarget = nil
    end

    self.nextTarget = SelectNextBestTarget(true)

    if ShouldSwapTarget() then
        local bestTarget = SelectBestTarget()
        if bestTarget then
            PerformTargetSwap(bestTarget)
        end
    end
end

function AutoTarget:Draw()
    if not Config.enabled or not VanFW.Draw then return end

    if Config.showCurrentTarget and self.currentTarget and self.currentTarget:exists() then
        local x, y, z = self.currentTarget:position()
        if x then
            VanFW.Draw.Circle(x, y, z, Config.circleSize, 255, 0, 0, 255)
        end
    end

    if Config.showNextTarget and self.nextTarget and self.nextTarget:exists() then
        if not self.currentTarget or self.nextTarget ~= self.currentTarget then
            local x, y, z = self.nextTarget:position()
            if x then
                VanFW.Draw.Circle(x, y, z, Config.circleSize, 204, 0, 255, 255)
            end
        end
    end
end

function AutoTarget:Enable()
    Config.enabled = true
    SaveConfig()
    VanFW:Success("AutoTarget: Enabled")
end

function AutoTarget:Disable()
    Config.enabled = false
    SaveConfig()
    VanFW:Print("AutoTarget: Disabled")
end

function AutoTarget:Toggle()
    if Config.enabled then
        self:Disable()
    else
        self:Enable()
    end
end

function AutoTarget:IsEnabled()
    return Config.enabled
end

function AutoTarget:GetCurrentTarget()
    return self.currentTarget
end

function AutoTarget:GetNextTarget()
    return self.nextTarget
end

function AutoTarget:ForceSwap()
    local bestTarget = SelectBestTarget()
    if bestTarget then
        PerformTargetSwap(bestTarget)
    end
end

local function CreateGUI()
    if not VanFW.GUI then
        VanFW:Error("AutoTarget: GUI system not available")
        return
    end

    local menu = VanFW.GUI:CreateMenu("AutoTarget", {
        title = "AutoTarget - Smart Targeting System",
        width = 550,
        height = 600,
        config = Config,
    })

    local generalTab = menu:AddTab("General")

    VanFW.GUI:AddCheckbox(menu, generalTab, {
        label = "Enable AutoTarget",
        tooltip = "Enable automatic target selection and swapping",
        value = Config.enabled,
        callback = function(value)
            Config.enabled = value
            SaveConfig()
            if value then
                VanFW:Success("AutoTarget: Enabled")
            else
                VanFW:Print("AutoTarget: Disabled")
            end
        end,
    })

    VanFW.GUI:AddCheckbox(menu, generalTab, {
        label = "Combat Only",
        tooltip = "Only auto-target while in combat",
        value = Config.combatOnly,
        callback = function(value)
            Config.combatOnly = value
            SaveConfig()
        end,
    })

    VanFW.GUI:AddSlider(menu, generalTab, {
        label = "Swap Threshold (%)",
        tooltip = "Target HP% to swap to next target (0 = on death, 100 = never swap)",
        min = 0,
        max = 100,
        step = 5,
        value = Config.swapThreshold,
        callback = function(value)
            Config.swapThreshold = value
            SaveConfig()
        end,
    })

    VanFW.GUI:AddSlider(menu, generalTab, {
        label = "Swap Delay (seconds)",
        tooltip = "Minimum time between target swaps",
        min = 0.1,
        max = 2.0,
        step = 0.1,
        value = Config.swapDelay,
        callback = function(value)
            Config.swapDelay = value
            SaveConfig()
        end,
    })

    VanFW.GUI:AddSlider(menu, generalTab, {
        label = "Max Range",
        tooltip = "Maximum range for target selection",
        min = 10,
        max = 50,
        step = 5,
        value = Config.maxRange,
        callback = function(value)
            Config.maxRange = value
            SaveConfig()
        end,
    })

    local priorityTab = menu:AddTab("Priority")

    VanFW.GUI:AddText(menu, priorityTab, {
        text = "Weighted Priority System (0.0 = disabled, higher = more important)",
    })

    VanFW.GUI:AddSlider(menu, priorityTab, {
        label = "Distance Weight",
        tooltip = "Weight for targeting closer enemies (0.0 - 10.0)",
        min = 0,
        max = 10,
        step = 0.1,
        value = Config.priorityWeightDistance,
        callback = function(value)
            Config.priorityWeightDistance = value
            SaveConfig()
        end,
    })

    VanFW.GUI:AddSlider(menu, priorityTab, {
        label = "Low Health Weight",
        tooltip = "Weight for targeting low HP enemies (0.0 - 10.0)",
        min = 0,
        max = 10,
        step = 0.1,
        value = Config.priorityWeightHealth,
        callback = function(value)
            Config.priorityWeightHealth = value
            SaveConfig()
        end,
    })

    VanFW.GUI:AddSlider(menu, priorityTab, {
        label = "Threat/HP Pool Weight",
        tooltip = "Weight for targeting high HP pool enemies (0.0 - 10.0)",
        min = 0,
        max = 10,
        step = 0.1,
        value = Config.priorityWeightThreat,
        callback = function(value)
            Config.priorityWeightThreat = value
            SaveConfig()
        end,
    })

    VanFW.GUI:AddCheckbox(menu, priorityTab, {
        label = "Require Line of Sight",
        tooltip = "Only target enemies with LoS",
        value = Config.requireLoS,
        callback = function(value)
            Config.requireLoS = value
            SaveConfig()
        end,
    })

    VanFW.GUI:AddCheckbox(menu, priorityTab, {
        label = "Ignore CC'd Targets",
        tooltip = "Don't swap to crowd-controlled enemies",
        value = Config.ignoreCC,
        callback = function(value)
            Config.ignoreCC = value
            SaveConfig()
        end,
    })

    local visualTab = menu:AddTab("Visual")

    VanFW.GUI:AddCheckbox(menu, visualTab, {
        label = "Show Current Target",
        tooltip = "Draw red circle around current target",
        value = Config.showCurrentTarget,
        callback = function(value)
            Config.showCurrentTarget = value
            SaveConfig()
        end,
    })

    VanFW.GUI:AddCheckbox(menu, visualTab, {
        label = "Show Next Target",
        tooltip = "Draw purple circle around next best target",
        value = Config.showNextTarget,
        callback = function(value)
            Config.showNextTarget = value
            SaveConfig()
        end,
    })

    VanFW.GUI:AddSlider(menu, visualTab, {
        label = "Circle Size",
        tooltip = "Size of target circles",
        min = 0.5,
        max = 5.0,
        step = 0.5,
        value = Config.circleSize,
        callback = function(value)
            Config.circleSize = value
            SaveConfig()
        end,
    })

    VanFW.GUI.menus["AutoTarget"] = menu
    return menu
end


local function SlashHandler(msg)
    msg = msg:lower():trim()

    if msg == "" or msg == "toggle" then
        AutoTarget:Toggle()
    elseif msg == "on" or msg == "enable" then
        AutoTarget:Enable()
    elseif msg == "off" or msg == "disable" then
        AutoTarget:Disable()
    elseif msg == "gui" or msg == "config" or msg == "menu" then
        local menu = VanFW.GUI.menus["AutoTarget"]
        if not menu then
            menu = CreateGUI()
        end
        if menu then
            menu:Toggle()
        end
    elseif msg == "status" then
        VanFW:Print("Enabled: " .. tostring(Config.enabled))
        VanFW:Print("Priority Weights:")
        VanFW:Print("  Distance: " .. string.format("%.1f", Config.priorityWeightDistance))
        VanFW:Print("  Health: " .. string.format("%.1f", Config.priorityWeightHealth))
        VanFW:Print("  Threat: " .. string.format("%.1f", Config.priorityWeightThreat))
        VanFW:Print("Swap Threshold: " .. Config.swapThreshold .. "%")
        VanFW:Print("Current Target: " .. tostring(AutoTarget.currentTarget and AutoTarget.currentTarget:Name() or "None"))
        VanFW:Print("Next Target: " .. tostring(AutoTarget.nextTarget and AutoTarget.nextTarget:Name() or "None"))
    elseif msg == "swap" or msg == "force" then
        AutoTarget:ForceSwap()
    else
        VanFW:Print("AutoTarget Commands:")
        VanFW:Print("  /at - Toggle AutoTarget")
        VanFW:Print("  /at gui - Open settings")
        VanFW:Print("  /at status - Show current status")
        VanFW:Print("  /at swap - Force target swap")
    end
end

if VanFW.RegisterSlashCommand then
    VanFW:RegisterSlashCommand("at", SlashHandler)
    VanFW:RegisterSlashCommand("autotarget", SlashHandler)
end


VanFW:OnUpdate(function(elapsed)
    AutoTarget:Update()
end)

if VanFW.Draw and VanFW.Draw.RegisterCallback then
    VanFW.Draw.RegisterCallback("AutoTarget", function()
        AutoTarget:Draw()
    end)
    if not VanFW.Draw.enabled then
        VanFW.Draw.Enable(0.032)
    end
end

C_Timer.After(0.5, function()
    CreateGUI()
end)


VanFW:Success("AutoTarget v" .. AutoTarget.version .. " loaded!")
VanFW:Print("  Commands: /at, /autotarget")
VanFW:Print("  GUI: /at gui")
