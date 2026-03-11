-- VanFW Toggle Button
-- Draggable on-screen button to start/stop rotation
-- No slash commands needed

local VanFW = VanFW
if not VanFW then return end

local BUTTON_SIZE = 48
local ICON_PADDING = 6

local f = CreateFrame("Button", "VanFWToggleButton", UIParent, "BackdropTemplate")
f:SetSize(BUTTON_SIZE, BUTTON_SIZE)
f:SetPoint("TOPRIGHT", -20, -200)
f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
f:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetClampedToScreen(true)

-- Status indicator (colored circle)
local indicator = f:CreateTexture(nil, "OVERLAY")
indicator:SetSize(12, 12)
indicator:SetPoint("TOPRIGHT", -4, -4)
indicator:SetColorTexture(1, 0, 0, 1) -- red = off

-- Icon text (spec icon placeholder)
local icon = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
icon:SetPoint("CENTER", 0, 0)
icon:SetText("R")

-- Tooltip
local function ShowTooltip()
    GameTooltip:SetOwner(f, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cFF00FFFFVanFW Rotation|r")
    if VanFW.Rota and VanFW.Rota.Info then
        GameTooltip:AddLine(VanFW.Rota.Info.class .. " - " .. VanFW.Rota.Info.spec, 1, 1, 1)
    end
    local isRunning = VanFW.IsRotationRunning and VanFW:IsRotationRunning()
    if isRunning then
        GameTooltip:AddLine("|cFF00FF00Running|r")
    else
        GameTooltip:AddLine("|cFFFF0000Stopped|r")
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("|cFFFFFFFFLeft-click|r", "Toggle on/off")
    GameTooltip:AddDoubleLine("|cFFFFFFFFRight-click|r", "Drag to move")
    GameTooltip:Show()
end

-- Dragging
local isDragging = false

f:SetScript("OnDragStart", function(self)
    isDragging = true
    self:StartMoving()
end)

f:SetScript("OnDragStop", function(self)
    isDragging = false
    self:StopMovingOrSizing()
end)

-- Click handler
f:SetScript("OnClick", function(self, button)
    if button == "LeftButton" and not isDragging then
        if not VanFW.Rota then
            VanFW:Error("No rotation loaded!")
            return
        end

        local isRunning = VanFW.IsRotationRunning and VanFW:IsRotationRunning()
        if isRunning then
            VanFW.Rota.Stop()
        else
            VanFW.Rota.Start()
        end
    end
end)

f:SetScript("OnEnter", ShowTooltip)
f:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Update indicator color based on rotation state
local updateFrame = CreateFrame("Frame")
local updateElapsed = 0

updateFrame:SetScript("OnUpdate", function(self, elapsed)
    updateElapsed = updateElapsed + elapsed
    if updateElapsed < 0.25 then return end
    updateElapsed = 0

    local isRunning = VanFW.IsRotationRunning and VanFW:IsRotationRunning()

    if isRunning then
        indicator:SetColorTexture(0, 1, 0, 1)  -- green
        f:SetBackdropBorderColor(0, 0.8, 0, 1)
    else
        indicator:SetColorTexture(1, 0, 0, 1)  -- red
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end

    -- Update icon text with spec initial
    if VanFW.Rota and VanFW.Rota.Info then
        local specName = VanFW.Rota.Info.spec or "R"
        icon:SetText(specName:sub(1, 1))
    end
end)

VanFW:Debug("Toggle button initialized", "UI")
