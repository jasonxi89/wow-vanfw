local VanFW = VanFW or {}

local VanFWEnv = {
    _G = _G,
    pairs = pairs,
    ipairs = ipairs,
    next = next,
    type = type,
    tostring = tostring,
    tonumber = tonumber,
    pcall = pcall,
    xpcall = xpcall,
    error = error,
    assert = assert,
    debugstack = _G.debugstack,
    geterrorhandler = _G.geterrorhandler,
    seterrorhandler = _G.seterrorhandler,
    select = select,
    unpack = unpack,
    setmetatable = setmetatable,
    getmetatable = getmetatable,
    rawget = rawget,
    rawset = rawset,
    rawequal = rawequal,
    loadstring = loadstring,
    loadfile = loadfile,
    setfenv = setfenv,
    getfenv = getfenv,

    string = string,
    table = table,
    math = math,
    bit = bit,

    GetTime = _G.GetTime,
    CastSpellByID = _G.CastSpellByID,
    CastSpellByName = _G.CastSpellByName,
    IsSpellKnown = _G.IsSpellKnown,
    IsPlayerSpell = _G.IsPlayerSpell,
    GetSpellInfo = _G.GetSpellInfo,
    GetSpellCooldown = _G.GetSpellCooldown,
    GetSpellCharges = _G.GetSpellCharges,
    IsUsableSpell = _G.IsUsableSpell,
    SpellIsTargeting = _G.SpellIsTargeting,
    UnitExists = _G.UnitExists,
    UnitName = _G.UnitName,
    UnitGUID = _G.UnitGUID,
    UnitHealth = _G.UnitHealth,
    UnitHealthMax = _G.UnitHealthMax,
    UnitPower = _G.UnitPower,
    UnitPowerMax = _G.UnitPowerMax,
    UnitIsPlayer = _G.UnitIsPlayer,
    UnitIsUnit = _G.UnitIsUnit,
    UnitIsDead = _G.UnitIsDead,
    UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost,
    UnitAffectingCombat = _G.UnitAffectingCombat,
    UnitCanAttack = _G.UnitCanAttack,
    UnitCanAssist = _G.UnitCanAssist,
    UnitIsFriend = _G.UnitIsFriend,
    UnitIsEnemy = _G.UnitIsEnemy,
    UnitReaction = _G.UnitReaction,
    UnitLevel = _G.UnitLevel,
    UnitRace = _G.UnitRace,
    UnitClass = _G.UnitClass,
    UnitCreatureType = _G.UnitCreatureType,
    UnitClassification = _G.UnitClassification,
    UnitCastingInfo = _G.UnitCastingInfo,
    UnitChannelInfo = _G.UnitChannelInfo,
    GetUnitSpeed = _G.GetUnitSpeed,
    TargetUnit = _G.TargetUnit,
    IsMounted = _G.IsMounted,
    IsFalling = _G.IsFalling,
    IsFlying = _G.IsFlying,
    UnitOnTaxi = _G.UnitOnTaxi,
    UnitInVehicle = _G.UnitInVehicle,
    UnitAura = _G.UnitAura,
    GetPlayerInfoByGUID = _G.GetPlayerInfoByGUID,

    C_Spell = _G.C_Spell,
    C_UnitAuras = _G.C_UnitAuras,
    C_Timer = _G.C_Timer,
    C_SpecializationInfo = _G.C_SpecializationInfo,
    GetSpecialization = _G.GetSpecialization,
    GetSpecializationInfo = _G.GetSpecializationInfo,

    WorldFrame = _G.WorldFrame,
    UIParent = _G.UIParent,
    CreateFrame = _G.CreateFrame,
    SlashCmdList = _G.SlashCmdList,

    -- DBM integration
    DBM = _G.DBM,

    print = print,

    WGG_GetObjectCount = _G.WGG_GetObjectCount,
    WGG_GetObjectWithIndex = _G.WGG_GetObjectWithIndex,
    WGG_Objects = _G.WGG_Objects,
    WGG_GetAllObjects = _G.WGG_GetAllObjects,
    WGG_GetAllUnits = _G.WGG_GetAllUnits,
    WGG_GetUnitsInRange = _G.WGG_GetUnitsInRange,
    WGG_GetHostileUnitsInRange = _G.WGG_GetHostileUnitsInRange,
    WGG_GetPlayersInRange = _G.WGG_GetPlayersInRange,
    WGG_GetClosestHostileUnit = _G.WGG_GetClosestHostileUnit,
    WGG_GetClosestUnit = _G.WGG_GetClosestUnit,
    WGG_ObjectType = _G.WGG_ObjectType,
    WGG_ObjectGUID = _G.WGG_ObjectGUID,
    WGG_ObjectToken = _G.WGG_ObjectToken,
    WGG_Object = _G.WGG_Object,
    WGG_ObjectPos = _G.WGG_ObjectPos,
    WGG_GetFacing = _G.WGG_GetFacing,
    WGG_SetFacing = _G.WGG_SetFacing,
    WGG_SetFacingRaw = _G.WGG_SetFacingRaw,
    WGG_GetPlayerPosition = _G.WGG_GetPlayerPosition,
    WGG_GetTargetPosition = _G.WGG_GetTargetPosition,
    WGG_ObjectDistance = _G.WGG_ObjectDistance,
    WGG_ObjectCombatReach = _G.WGG_ObjectCombatReach,
    WGG_ObjectBoundingRadius = _G.WGG_ObjectBoundingRadius,
    WGG_ObjectHeight = _G.WGG_ObjectHeight,
    WGG_Click = _G.WGG_Click,
    WGG_VisCheck = _G.WGG_VisCheck,
    WGG_W2S = _G.WGG_W2S,
    WGG_CameraPosition = _G.WGG_CameraPosition,
    WGG_ObjectCastingTarget = _G.WGG_ObjectCastingTarget,
    WGG_ObjectTarget = _G.WGG_ObjectTarget,
    WGG_ObjectMovementFlag = _G.WGG_ObjectMovementFlag,
    WGG_ObjectSpecID = _G.WGG_ObjectSpecID,
    WGG_IsSpellPending = _G.WGG_IsSpellPending,
    WGG_GetWoWDirectory = _G.WGG_GetWoWDirectory,
    WGG_JsonEncode = _G.WGG_JsonEncode,
    WGG_JsonDecode = _G.WGG_JsonDecode,
    WGG_FileExists = _G.WGG_FileExists,
    WGG_FileRead = _G.WGG_FileRead,
    WGG_FileWrite = _G.WGG_FileWrite,
    WGG_DirExists = _G.WGG_DirExists,
    WGG_CreateDir = _G.WGG_CreateDir,
    WGG_AESEncrypt = _G.WGG_AESEncrypt,
    WGG_AESDecrypt = _G.WGG_AESDecrypt,
}

setmetatable(VanFWEnv, {
    __index = function(t, k)
        if k == "VanFW" then
            return _G.VanFW
        end
        return rawget(t, k)
    end,
    __newindex = function(t, k, v)
        rawset(t, k, v)
    end,
})

function VanFW:GetEnvironment()
    return VanFWEnv
end

function VanFW:RunInEnvironment(func)
    if not func or type(func) ~= "function" then
        error("VanFW:RunInEnvironment requires a function")
        return nil
    end
    setfenv(func, VanFWEnv)

    local success, result = pcall(func)
    if not success then
        self:Error("Environment execution error: " .. tostring(result))
        return nil
    end

    return result
end

function VanFW:LoadInEnvironment(filePath)
    if not _G.WGG_FileRead then
        self:Error("WGG File API not available")
        return false, "WGG File API not available"
    end

    local content = _G.WGG_FileRead(filePath)
    if not content or content == "" then
        self:Error("Failed to read file: " .. filePath)
        return false, "Failed to read file"
    end
    local func, loadErr = _G.loadstring(content, "@" .. filePath)
    if not func then
        self:Error("Failed to load file content: " .. tostring(loadErr))
        return false, tostring(loadErr)
    end

    _G.setfenv(func, VanFWEnv)

    local success, result = _G.pcall(func)
    if not success then
        self:Error("File execution error: " .. tostring(result))
        return false, tostring(result)
    end

    return true, result
end

_G.VanFWEnv = VanFWEnv
VanFW:Debug("Environment isolation initialized", "Environment")
return VanFWEnv
