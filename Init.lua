print("|cFF00FFFF    VanFW - Developer Framework v2.0     |r")
print("|cFF00FFFF    Rotation Developer Playground        |r")

local UnitClass = _G.UnitClass
local GetSpecialization = _G.GetSpecialization
local GetSpecializationInfo = _G.GetSpecializationInfo
local C_Timer = _G.C_Timer

local basePath = ""

if _G.WGG_FileExists then
    local testPaths = {
        "c:\\WGG\\",
        "C:\\WGG\\",
    }

    for _, testPath in ipairs(testPaths) do
        if _G.WGG_FileExists(testPath .. "Init.lua") then
            basePath = testPath
            break
        end
    end

    if basePath == "" then
        print("|cFFFF0000[VanFW]|r Could not auto-detect addon path, using fallback...")
        basePath = "c:\\WGG\\"
    end
else
    print("|cFFFF0000[VanFW]|r WGG_FileExists not available")
    basePath = "c:\\WGG\\"
end

local loadOrder = {
    "Libs\\LibDraw.lua",
    "VanFW\\Core.lua",
    "VanFW\\Environment.lua",
    "VanFW\\depends.lua",
    "VanFW\\GUID.lua",
    "VanFW\\Objects.lua",
    "VanFW\\Units.lua",
    "VanFW\\Spells.lua",
    "VanFW\\RotationEngine.lua",
    "VanFW\\Targeting.lua",
    "VanFW\\Helpers.lua",
    "VanFW\\Draw.lua",
    "VanFW\\GUI.lua",
    "VanFW\\Alerts.lua",
    "VanFW\\MCP.lua",
    "VanFW\\DBMIntegration.lua",
    "VanFW\\BossAwareness.lua",
    -- "VanFW\\VanKili.lua",  -- DEPRECATED: Hekili killed by Midnight 12.0 addon restrictions
    "VanFW\\ToggleButton.lua",

}

local FileAPI = {}

if _G.WGG_FileExists and _G.WGG_FileRead then
    FileAPI.Exists = function(path)
        return _G.WGG_FileExists(path)
    end

    FileAPI.Read = function(path)
        return _G.WGG_FileRead(path)
    end
else
    print("|cFFFF0000[VanFW]|r WGG File API not available!")
    FileAPI.Exists = nil
    FileAPI.Read = nil
end

local function executeFile(content, filePath)
    if not content or content == "" then
        print("|cFFFF0000[VanFW]|r Empty content: " .. filePath)
        return false
    end

    local func, loadError = loadstring(content, "@" .. filePath)
    if not func then
        print("|cFFFF0000[VanFW]|r Load error: " .. filePath)
        print("|cFFFF0000[VanFW]|r " .. tostring(loadError))
        return false
    end

    local function errorHandler(err)
        print("|cFFFF0000[VanFW]|r Execution error in: " .. filePath)
        print("|cFFFF0000[VanFW]|r " .. tostring(err))
        if debugstack then
            print(debugstack(2))
        end
        return err
    end

    local success = xpcall(func, errorHandler)
    return success
end

local function loadFiles(filesToLoad, onComplete)
    local total = #filesToLoad

    if total == 0 then
        print("|cFFFF0000[VanFW]|r No files to load!")
        return
    end

    print("|cFF00FFFF[VanFW]|r Loading framework modules...")
    print(" ")

    local loaded = {}
    local completed = 0
    local execIndex = 1
    local success_count = 0
    local fail_count = 0

    local function executeNext()
        while execIndex <= total do
            local data = loaded[execIndex]

            if not data then
                return
            end

            local filePath = filesToLoad[execIndex]
            local fileName = filePath and (filePath:match("([^/\\]+)$") or filePath) or "unknown"

            if data.success and data.content then
                local ok = executeFile(data.content, (basePath or "") .. (filePath or ""))

                if ok then
                    success_count = success_count + 1
                else
                    fail_count = fail_count + 1
                end
            else
                fail_count = fail_count + 1
                print("|cFFFF0000[VanFW]|r Failed to read: " .. (fileName or "unknown"))
            end

            execIndex = execIndex + 1
        end

        if execIndex > total then
            print(" ")

            if fail_count == 0 then
            else
                print("|cFFFFFF00[VanFW]|r Loaded with errors")
                print("|cFFFFFF00[VanFW]|r Success: " .. success_count .. " | Failed: " .. fail_count)
            end

            print(" ")

            if onComplete then
                onComplete()
            end
        end
    end

    for i = 1, total do
        local filePath = filesToLoad[i]
        local fullPath = basePath .. filePath

        local function readFile()
            if not FileAPI.Exists(fullPath) then
                loaded[i] = { success = false, content = nil }
                completed = completed + 1
                executeNext()
                return
            end

            local content = FileAPI.Read(fullPath)

            loaded[i] = {
                success = (content ~= nil and content ~= ""),
                content = content
            }

            completed = completed + 1
            executeNext()
        end

        readFile()
    end
end


local function validateFiles()
    if not FileAPI.Exists then
        print("|cFFFFFF00[VanFW]|r Skipping file validation")
        return true
    end

    local missing = {}

    for _, fileName in ipairs(loadOrder) do
        local fullPath = basePath .. fileName
        if not FileAPI.Exists(fullPath) then
            table.insert(missing, fileName)
        end
    end

    if #missing > 0 then
        print("|cFFFF0000[VanFW]|r Missing files:")
        for _, fileName in ipairs(missing) do
            print("|cFFFF0000[VanFW]|r   - " .. fileName)
        end
        return false
    end

    return true
end

local SpecIDToName = {
    -- Death Knight
    [250] = "Blood",
    [251] = "Frost",
    [252] = "Unholy",

    -- Demon Hunter
    [577] = "Havoc",
    [581] = "Vengeance",

    -- Druid
    [102] = "Balance",
    [103] = "Feral",
    [104] = "Guardian",
    [105] = "Restoration",

    -- Evoker
    [1467] = "Devastation",
    [1468] = "Preservation",
    [1473] = "Augmentation",

    -- Hunter
    [253] = "Beast Mastery",
    [254] = "Marksmanship",
    [255] = "Survival",

    -- Mage
    [62] = "Arcane",
    [63] = "Fire",
    [64] = "Frost",

    -- Monk
    [268] = "Brewmaster",
    [270] = "Mistweaver",
    [269] = "Windwalker",

    -- Paladin
    [65] = "Holy",
    [66] = "Protection",
    [70] = "Retribution",

    -- Priest
    [256] = "Discipline",
    [257] = "Holy",
    [258] = "Shadow",

    -- Rogue
    [259] = "Assassination",
    [260] = "Outlaw",
    [261] = "Subtlety",

    -- Shaman
    [262] = "Elemental",
    [263] = "Enhancement",
    [264] = "Restoration",

    -- Warlock
    [265] = "Affliction",
    [266] = "Demonology",
    [267] = "Destruction",

    -- Warrior
    [71] = "Arms",
    [72] = "Fury",
    [73] = "Protection",
}

local CurrentLoadedSpec = {
    class = nil,
    spec = nil,
    specID = nil,
    rotationActive = false,
}

local function GetCurrentSpec()
    local _, playerClass = UnitClass("player")

    if not playerClass or playerClass == "" then
        return nil, nil, nil
    end

    local specID = nil
    local specName = nil

    if _G.WGG_ObjectSpecID then
        local playerGUID = UnitGUID("player")
        if playerGUID and playerGUID ~= "" then
            specID = _G.WGG_ObjectSpecID(playerGUID)
            if specID and specID > 0 then
                specName = SpecIDToName[specID]
                if specName then
                    return playerClass, specName, specID
                end
            end
        end
    end

    local specIndex = GetSpecialization()
    if specIndex and specIndex > 0 then
        specName = select(2, GetSpecializationInfo(specIndex))
        if specName and specName ~= "" then
            return playerClass, specName, specIndex
        end
    end

    return nil, nil, nil
end

local function UnloadCurrentRotation()
    if not _G.VanFW then return end
    if _G.VanFW.rotationActive then
        print("|cFFFFFF00[VanFW]|r Stopping active rotation...")
        if _G.VanFW.StopRotation then
            _G.VanFW:StopRotation()
        end
        CurrentLoadedSpec.rotationActive = false
    end
    if CurrentLoadedSpec.class and CurrentLoadedSpec.spec then
        local rotationKey = CurrentLoadedSpec.class .. CurrentLoadedSpec.spec .. CurrentLoadedSpec.spec
        if _G.VanFW[rotationKey] then
            print("|cFFFFFF00[VanFW]|r Unloading rotation: " .. CurrentLoadedSpec.class .. " - " .. CurrentLoadedSpec.spec)
            _G.VanFW[rotationKey] = nil
        end
    end
    _G.VanFW.Rota = nil
end

local function LoadRotationsForClass(force)
    if not _G.VanFW then
        print("|cFFFF0000[VanFW]|r VanFW not initialized, cannot load rotations")
        return
    end
    local playerClass, specName, specID = GetCurrentSpec()
    if not playerClass or not specName then
        print("|cFFFF0000[VanFW]|r Could not detect class/spec")
        return
    end
    if not force and CurrentLoadedSpec.class == playerClass and CurrentLoadedSpec.spec == specName then
        return
    end

    if CurrentLoadedSpec.spec then
        print("|cFFFFFF00[VanFW]|r Spec Changed: " .. CurrentLoadedSpec.spec .. " -> " .. specName)
        UnloadCurrentRotation()
    end
    print("|cFF00FFFF[VanFW]|r Detected: " .. playerClass .. " - " .. specName)
    CurrentLoadedSpec.class = playerClass
    CurrentLoadedSpec.spec = specName
    CurrentLoadedSpec.specID = specID
    local rotationPath = basePath .. "Rotations\\" .. playerClass .. "\\" .. specName .. ".lua"
    if FileAPI.Exists(rotationPath) then
        local success, err = _G.VanFW:LoadInEnvironment(rotationPath)
        if success then
            print("|cFF00FF00[VanFW]|r Rotation loaded successfully!")
        else
            print("|cFFFF0000[VanFW]|r Failed to load rotation: " .. tostring(err))
        end
    else
        print("|cFFFFFF00[VanFW]|r No rotation found for " .. playerClass .. " - " .. specName)
    end
end
local SpecChangeDetector = {
    lastCheck = 0,
    checkInterval = 1.0,
    enabled = false,
}

function SpecChangeDetector:Start()
    if self.enabled then return end
    self.enabled = true
    self.lastCheck = GetTime()
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnUpdate", function()
            SpecChangeDetector:OnUpdate()
        end)
    end
end

function SpecChangeDetector:Stop()
    self.enabled = false
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
    end
end
function SpecChangeDetector:OnUpdate()
    if not self.enabled then return end

    local currentTime = GetTime()
    if currentTime - self.lastCheck < self.checkInterval then
        return
    end
    self.lastCheck = currentTime
    local playerClass, specName, specID = GetCurrentSpec()
    if not playerClass or not specName then
        return
    end
    if CurrentLoadedSpec.class and CurrentLoadedSpec.spec then
        if CurrentLoadedSpec.class ~= playerClass or CurrentLoadedSpec.spec ~= specName then
            LoadRotationsForClass(false)
        end
    end
end

if not FileAPI.Exists or not FileAPI.Read then
    print("|cFFFF0000[VanFW]|r ERROR: WGG File API not available!")
    print("|cFFFF0000[VanFW]|r Cannot load framework without file access.")
    return
end

if not validateFiles() then
    print("|cFFFF0000[VanFW]|r Cannot load: Missing required files!")
    print("|cFFFF0000[VanFW]|r Check your VanFW/ directory")
    return
end
loadFiles(loadOrder, function()
    if not _G.VanFW then
        print("|cFFFF0000[VanFW]|r ERROR: VanFW global not created!")
        return
    end

    if _G.VanFW.UpdatePlayerObject then
        _G.VanFW:UpdatePlayerObject()
        if _G.VanFW.player then
        else
            print("|cFFFF0000[VanFW]|r  Failed to initialize player object")
        end
    end

    C_Timer.After(0.1, function()
        if _G.VanFW.Initialize then
            _G.VanFW:Initialize()
        end

        if _G.VanFW.Draw then
            if not _G.LibDraw then
                print("|cFFFF0000[VanFW]|r  ERROR: LibDraw not loaded!")
            else
            end
        else
            print("|cFFFF0000[VanFW]|r  ERROR: VanFW.Draw module not loaded!")
        end


        print("|cFF00FFFF[VanFW]|r Loading Utility Modules...")

        local utilityPath = basePath .. "Rotations\\Utility\\"
        local utilityModules = {
            "AutoTarget.lua",
        }

        local utilityLoaded = 0
        for _, moduleName in ipairs(utilityModules) do
            local modulePath = utilityPath .. moduleName
            if FileAPI.Exists(modulePath) then
                local success, err = _G.VanFW:LoadInEnvironment(modulePath)
                if success then
                    utilityLoaded = utilityLoaded + 1
                    print("|cFF00FF00[VanFW]|r  ✓ " .. moduleName:gsub("%.lua$", ""))
                else
                    print("|cFFFF0000[VanFW]|r  ✗ " .. moduleName .. ": " .. tostring(err))
                end
            else
                print("|cFFFFFF00[VanFW]|r  - " .. moduleName .. " (not found)")
            end
        end

        if utilityLoaded > 0 then
            print("|cFF00FF00[VanFW]|r Loaded " .. utilityLoaded .. " utility module(s)")
        end

        print(" ")
        print("|cFFFFFFFF[VanFW]|r Commands:")
        print("  |cFF00FFFF/vanfw|r - Framework info")
        print("  |cFF00FFFF/rot|r - Start/stop rotation")
        print("  |cFF00FFFF/rot help|r - Rotation commands")
        print(" ")

        local loadAttempts = 0
        local maxAttempts = 5

        local function TryLoadRotation()
            loadAttempts = loadAttempts + 1

            print("|cFF00FFFF[VanFW]|r Auto-loading rotations...")

            local playerClass, specName = GetCurrentSpec()

            if playerClass and specName then
                LoadRotationsForClass(true)
                C_Timer.After(2.0, function()
                    SpecChangeDetector:Start()
                end)

                print("|cFF00FF00[VanFW]|r Framework Ready!")
                print(" ")
            else
                if loadAttempts < maxAttempts then
                    print("|cFFFFFF00[VanFW]|r Retrying in 1 second...")
                    C_Timer.After(1.0, TryLoadRotation)
                else
                    print("|cFFFF0000[VanFW]|r Failed to detect class/spec after " .. maxAttempts .. " attempts!")
                    print("|cFFFF0000[VanFW]|r Make sure you are logged in and in-game")
                    print(" ")
                end
            end
        end

        C_Timer.After(1.0, TryLoadRotation)
    end)
end)
