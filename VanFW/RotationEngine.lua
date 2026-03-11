local VanFW = VanFW

local CreateFrame = _G.CreateFrame
local IsMounted = _G.IsMounted
local IsFalling = _G.IsFalling
local IsFlying = _G.IsFlying
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitOnTaxi = _G.UnitOnTaxi
local UnitInVehicle = _G.UnitInVehicle
local GetTime = _G.GetTime

local RotationFrame = CreateFrame("Frame")
local rotationFunction = nil
local isRunning = false
local tickRate = 0.1
local lastTick = 0
local consecutiveErrors = 0
local MAX_CONSECUTIVE_ERRORS = 10

local function CanRunRotation()
    if IsMounted() then
        return false, "mounted"
    end

    if UnitOnTaxi("player") then
        return false, "taxi"
    end

    if UnitInVehicle("player") then
        return false, "vehicle"
    end

    if UnitIsDeadOrGhost("player") then
        return false, "dead"
    end

    if IsFalling() then
        return false, "falling"
    end

    return true, nil
end

RotationFrame:SetScript("OnUpdate", function(self, elapsed)
    if not isRunning or not rotationFunction then return end

    lastTick = lastTick + elapsed

    if lastTick >= tickRate then
        lastTick = 0

        local canRun, reason = CanRunRotation()
        if not canRun then
            return
        end

        local success, err = pcall(rotationFunction)
        if success then
            consecutiveErrors = 0
        else
            consecutiveErrors = consecutiveErrors + 1
            VanFW:Error("Rotation error: " .. tostring(err))

            if consecutiveErrors >= MAX_CONSECUTIVE_ERRORS then
                VanFW:Error("Rotation auto-stopped: " .. MAX_CONSECUTIVE_ERRORS .. " consecutive errors")
                VanFW:StopRotation()
                return
            end
        end
    end
end)


function VanFW:StartRotation(rotFunc, rate)
    if not rotFunc or type(rotFunc) ~= "function" then
        self:Error("StartRotation requires a function")
        return false
    end

    if isRunning then
        self:Print("Rotation already running!")
        return false
    end

    rotationFunction = rotFunc
    tickRate = rate or 0.1
    lastTick = 0
    consecutiveErrors = 0
    isRunning = true
    self.rotationActive = true

    self:Success("Rotation started")
    return true
end

function VanFW:StopRotation()
    if not isRunning then
        self:Print("Rotation not running!")
        return false
    end

    isRunning = false
    rotationFunction = nil
    self.rotationActive = false
    self:ClearSpellQueue()

    self:Success("stopping...")
    return true
end

function VanFW:IsRotationRunning()
    return isRunning
end

function VanFW:SetRotationTickRate(rate)
    tickRate = rate or 0.1
    self:Debug("Rotation tick rate set to: " .. tostring(tickRate), "Rotation")
end

VanFW:Debug("Rotation engine initialized (OnUpdate-based)", "Rotation")
