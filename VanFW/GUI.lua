local VanFW = VanFW or {}

-- work in progress tbh its looks ugly but works xD
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local GameTooltip = _G.GameTooltip
local tinsert = table.insert
local tremove = table.remove
local pairs = pairs
local ipairs = ipairs
local type = type
local tostring = tostring
local math = math
local string = string
local unpack = _G.unpack or table.unpack

local GUI_CONFIG = {
    width = 450,
    height = 400,
    tabHeight = 35,
    tabWidth = 120,
    tabSpacing = 5,
    padding = 15,
    scrollSpeed = 20,

    colors = {
        background = {0.08, 0.08, 0.08, 0.95},
        tabActive = {0.15, 0.15, 0.15, 1},
        tabInactive = {0.10, 0.10, 0.10, 0.8},
        tabHover = {0.12, 0.12, 0.12, 0.9},
        accent = {1, 0.55, 0.08, 1},
        accentHover = {1, 0.65, 0.18, 1},
        text = {1, 1, 1, 1},
        textDim = {0.7, 0.7, 0.7, 1},
        border = {0.2, 0.2, 0.2, 1},
        elementBg = {0.12, 0.12, 0.12, 0.9},
        sliderBg = {0.08, 0.08, 0.08, 1},
        sliderFill = {1, 0.55, 0.08, 0.8},
        closeButton = {0.8, 0.2, 0.2, 0.9},
        closeButtonHover = {1, 0.3, 0.3, 1},
    },

    -- Class colors
    classColors = {
        DEATHKNIGHT = {0.77, 0.12, 0.23, 1},
        DEMONHUNTER = {0.64, 0.19, 0.79, 1},
        DRUID = {1.00, 0.49, 0.04, 1},
        EVOKER = {0.20, 0.58, 0.50, 1},
        HUNTER = {0.67, 0.83, 0.45, 1},
        MAGE = {0.25, 0.78, 0.92, 1},
        MONK = {0.00, 1.00, 0.59, 1},
        PALADIN = {0.96, 0.55, 0.73, 1},
        PRIEST = {1.00, 1.00, 1.00, 1},
        ROGUE = {1.00, 0.96, 0.41, 1},
        SHAMAN = {0.00, 0.44, 0.87, 1},
        WARLOCK = {0.53, 0.53, 0.93, 1},
        WARRIOR = {0.78, 0.61, 0.43, 1},
    },

    font = "Fonts\\ARIALN.TTF",
    fontBold = "Fonts\\ARIALN.TTF",
    fontSize = 12,
    fontSizeLarge = 15,
}


VanFW.GUI = VanFW.GUI or {}
VanFW.GUI.menus = {}


local function CreateBackdrop(frame, bgColor, borderColor, borderSize, rounded)
    if rounded then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = borderSize or 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
    else
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            tileSize = 16,
            edgeSize = borderSize or 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
    end

    if bgColor then
        frame:SetBackdropColor(unpack(bgColor))
    end

    if borderColor then
        frame:SetBackdropBorderColor(unpack(borderColor))
    end
end

local function GetClassColor(className)
    if not className then
        local _, class = UnitClass("player")
        className = class
    end
    return GUI_CONFIG.classColors[className] or GUI_CONFIG.colors.accent
end

local function CreateFontString(parent, text, size, color, isBold)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local fontPath = isBold and GUI_CONFIG.fontBold or GUI_CONFIG.font
    local fonts = {
        fontPath,
        "Fonts\\ARIALN.TTF",
        "Fonts\\FRIZQT__.TTF",
    }

    local fontSet = false
    for _, font in ipairs(fonts) do
        fs:SetFont(font, size or GUI_CONFIG.fontSize, "OUTLINE")
        local currentFont = fs:GetFont()
        if currentFont then
            fontSet = true
            break
        end
    end

    if not fontSet then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size or GUI_CONFIG.fontSize, "OUTLINE")
    end

    local textStr = text
    if type(text) == "table" then
        textStr = text.text or tostring(text)
    end
    fs:SetText(textStr or "")

    if color then
        fs:SetTextColor(unpack(color))
    else
        fs:SetTextColor(unpack(GUI_CONFIG.colors.text))
    end

    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)

    return fs
end


local Menu = {}
Menu.__index = Menu

function VanFW.GUI:CreateMenu(rotationName, options)
    if VanFW.GUI.menus[rotationName] then
        return VanFW.GUI.menus[rotationName]
    end

    local menu = setmetatable({}, Menu)
    menu.name = rotationName
    menu.options = options or {}
    menu.tabs = {}
    menu.currentTab = nil
    menu.config = options.config or {}

    local _, playerClass = UnitClass("player")
    menu.classColor = options.classColor or GetClassColor(playerClass)

    menu:Initialize()

    VanFW.GUI.menus[rotationName] = menu

    return menu
end

function Menu:Initialize()
    self.frame = CreateFrame("Frame", "VanFWMenu_" .. self.name, UIParent, "BackdropTemplate")
    self.frame:SetSize(GUI_CONFIG.width, GUI_CONFIG.height)
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.frame:SetFrameStrata("HIGH")
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:SetClampedToScreen(true)
    self.frame:Hide()
    -- Main frame with class-colored border
    CreateBackdrop(self.frame, GUI_CONFIG.colors.background, self.classColor, 2)
    self.frame:SetScript("OnMouseDown", function(frame, button)
        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)
    self.frame:SetScript("OnMouseUp", function(frame)
        frame:StopMovingOrSizing()
    end)

    self.titleBar = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    self.titleBar:SetSize(GUI_CONFIG.width - 4, 40)
    self.titleBar:SetPoint("TOP", self.frame, "TOP", 0, -2)

    self.titleText = CreateFontString(self.titleBar, self.name .. " Configuration", GUI_CONFIG.fontSizeLarge, self.classColor, true)
    self.titleText:SetPoint("LEFT", self.titleBar, "LEFT", GUI_CONFIG.padding, 0)

    self.closeButton = CreateFrame("Button", nil, self.titleBar, "BackdropTemplate")
    self.closeButton:SetSize(28, 28)
    self.closeButton:SetPoint("RIGHT", self.titleBar, "RIGHT", -8, 0)
    CreateBackdrop(self.closeButton, GUI_CONFIG.colors.closeButton, GUI_CONFIG.colors.border, 1)

    local closeIcon = self.closeButton:CreateTexture(nil, "OVERLAY")
    closeIcon:SetColorTexture(1, 1, 1, 0.9)
    closeIcon:SetSize(14, 2)
    closeIcon:SetPoint("CENTER")
    closeIcon:SetRotation(math.rad(45))

    local closeIcon2 = self.closeButton:CreateTexture(nil, "OVERLAY")
    closeIcon2:SetColorTexture(1, 1, 1, 0.9)
    closeIcon2:SetSize(14, 2)
    closeIcon2:SetPoint("CENTER")
    closeIcon2:SetRotation(math.rad(-45))

    self.closeButton:SetScript("OnEnter", function()
        CreateBackdrop(self.closeButton, GUI_CONFIG.colors.closeButtonHover, GUI_CONFIG.colors.border, 1)
    end)

    self.closeButton:SetScript("OnLeave", function()
        CreateBackdrop(self.closeButton, GUI_CONFIG.colors.closeButton, GUI_CONFIG.colors.border, 1)
    end)

    self.closeButton:SetScript("OnClick", function()
        self:Hide()
    end)

    self.tabContainer = CreateFrame("Frame", nil, self.frame)
    self.tabContainer:SetSize(GUI_CONFIG.width - 40, GUI_CONFIG.tabHeight)
    self.tabContainer:SetPoint("TOP", self.titleBar, "BOTTOM", 0, -10)

    local tabSpacer = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    tabSpacer:SetSize(GUI_CONFIG.width - 60, 2)
    tabSpacer:SetPoint("TOP", self.tabContainer, "BOTTOM", 0, -8)

    tabSpacer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = nil,
        tile = false,
        tileSize = 0,
        edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    tabSpacer:SetBackdropColor(self.classColor[1], self.classColor[2], self.classColor[3], 1)

    local spacerGlow = tabSpacer:CreateTexture(nil, "ARTWORK")
    spacerGlow:SetTexture("Interface\\GLUES\\MODELS\\UI_MainMenu\\UI-ModelGlow-Red")
    spacerGlow:SetPoint("CENTER", tabSpacer, "CENTER", 0, 0)
    spacerGlow:SetSize(tabSpacer:GetWidth(), 15)
    spacerGlow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 1)
    spacerGlow:SetBlendMode("ADD")

    self.contentFrame = CreateFrame("ScrollFrame", nil, self.frame)
    self.contentFrame:SetPoint("TOPLEFT", self.tabContainer, "BOTTOMLEFT", GUI_CONFIG.padding, -20)
    self.contentFrame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -GUI_CONFIG.padding - 25, GUI_CONFIG.padding)

    self.scrollChild = CreateFrame("Frame", nil, self.contentFrame)
    self.scrollChild:SetSize(GUI_CONFIG.width - 60, 1)
    self.contentFrame:SetScrollChild(self.scrollChild)

    local scrollBar = CreateFrame("Slider", nil, self.contentFrame, "BackdropTemplate")
    scrollBar:SetPoint("TOPRIGHT", self.contentFrame, "TOPRIGHT", 20, -16)
    scrollBar:SetPoint("BOTTOMRIGHT", self.contentFrame, "BOTTOMRIGHT", 20, 16)
    scrollBar:SetWidth(8)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(1)
    self.scrollBar = scrollBar

    local scrollBg = CreateFrame("Frame", nil, scrollBar, "BackdropTemplate")
    scrollBg:SetPoint("TOPLEFT", scrollBar, "TOPLEFT", -2, 0)
    scrollBg:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMRIGHT", 2, 0)
    scrollBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = nil,
        tile = false,
        tileSize = 0,
        edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    scrollBg:SetBackdropColor(0.08, 0.08, 0.08, 0.9)

    local trackGlow = scrollBg:CreateTexture(nil, "ARTWORK")
    trackGlow:SetTexture("Interface\\GLUES\\MODELS\\UI_MainMenu\\UI-ModelGlow-Red")
    trackGlow:SetPoint("CENTER", scrollBg, "CENTER", 0, 0)
    trackGlow:SetSize(scrollBg:GetWidth() + 20, scrollBg:GetHeight())
    trackGlow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.15)
    trackGlow:SetBlendMode("ADD")

    local thumbTex = scrollBar:CreateTexture(nil, "ARTWORK")
    thumbTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    thumbTex:SetSize(1, 1)
    thumbTex:SetColorTexture(0, 0, 0, 0)
    scrollBar:SetThumbTexture(thumbTex)

    local scrollThumb = CreateFrame("Frame", nil, scrollBar)
    scrollThumb:SetSize(12, 40)
    scrollThumb:SetPoint("CENTER", scrollBar:GetThumbTexture(), "CENTER", 0, 0)

    local scrollThumbBg = scrollThumb:CreateTexture(nil, "OVERLAY")
    scrollThumbBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    scrollThumbBg:SetAllPoints(scrollThumb)
    scrollThumbBg:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)

    local scrollThumbBorder = scrollThumb:CreateTexture(nil, "OVERLAY")
    scrollThumbBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    scrollThumbBorder:SetPoint("CENTER", scrollThumb, "CENTER")
    scrollThumbBorder:SetSize(14, 42)
    scrollThumbBorder:SetVertexColor(1, 1, 1, 0.3)

    local scrollThumbGlow = scrollThumb:CreateTexture(nil, "ARTWORK")
    scrollThumbGlow:SetTexture("Interface\\GLUES\\MODELS\\UI_MainMenu\\UI-ModelGlow-Red")
    scrollThumbGlow:SetPoint("CENTER", scrollThumb, "CENTER", 0, 0)
    scrollThumbGlow:SetSize(30, 60)
    scrollThumbGlow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.5)
    scrollThumbGlow:SetBlendMode("ADD")

    local upButton = CreateFrame("Button", nil, scrollBar, "BackdropTemplate")
    upButton:SetSize(16, 16)
    upButton:SetPoint("BOTTOM", scrollBar, "TOP", 0, 2)
    CreateBackdrop(upButton, {0.12, 0.12, 0.12, 0.9}, GUI_CONFIG.colors.border, 1, true)

    local upArrow = upButton:CreateTexture(nil, "OVERLAY")
    upArrow:SetTexture("Interface\\Buttons\\WHITE8X8")
    upArrow:SetSize(8, 8)
    upArrow:SetPoint("CENTER", upButton, "CENTER", 0, 1)
    upArrow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)
    upArrow:SetRotation(math.rad(45))

    local upArrow2 = upButton:CreateTexture(nil, "OVERLAY")
    upArrow2:SetTexture("Interface\\Buttons\\WHITE8X8")
    upArrow2:SetSize(2, 10)
    upArrow2:SetPoint("CENTER", upButton, "CENTER", 0, -2)
    upArrow2:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)

    upButton:SetScript("OnClick", function()
        local current = self.contentFrame:GetVerticalScroll()
        local newScroll = math.max(0, current - GUI_CONFIG.scrollSpeed)
        self.contentFrame:SetVerticalScroll(newScroll)
    end)

    upButton:SetScript("OnEnter", function()
        CreateBackdrop(upButton, {0.15, 0.15, 0.15, 1}, GUI_CONFIG.colors.border, 1, true)
        upArrow:SetVertexColor(math.min(1, self.classColor[1] + 0.2), math.min(1, self.classColor[2] + 0.2), math.min(1, self.classColor[3] + 0.2), 1)
        upArrow2:SetVertexColor(math.min(1, self.classColor[1] + 0.2), math.min(1, self.classColor[2] + 0.2), math.min(1, self.classColor[3] + 0.2), 1)
    end)

    upButton:SetScript("OnLeave", function()
        CreateBackdrop(upButton, {0.12, 0.12, 0.12, 0.9}, GUI_CONFIG.colors.border, 1, true)
        upArrow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)
        upArrow2:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)
    end)

    local downButton = CreateFrame("Button", nil, scrollBar, "BackdropTemplate")
    downButton:SetSize(16, 16)
    downButton:SetPoint("TOP", scrollBar, "BOTTOM", 0, -2)
    CreateBackdrop(downButton, {0.12, 0.12, 0.12, 0.9}, GUI_CONFIG.colors.border, 1, true)

    local downArrow = downButton:CreateTexture(nil, "OVERLAY")
    downArrow:SetTexture("Interface\\Buttons\\WHITE8X8")
    downArrow:SetSize(8, 8)
    downArrow:SetPoint("CENTER", downButton, "CENTER", 0, -1)
    downArrow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)
    downArrow:SetRotation(math.rad(45))

    local downArrow2 = downButton:CreateTexture(nil, "OVERLAY")
    downArrow2:SetTexture("Interface\\Buttons\\WHITE8X8")
    downArrow2:SetSize(2, 10)
    downArrow2:SetPoint("CENTER", downButton, "CENTER", 0, 2)
    downArrow2:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)

    downButton:SetScript("OnClick", function()
        local current = self.contentFrame:GetVerticalScroll()
        local maxScroll = self.contentFrame:GetVerticalScrollRange()
        local newScroll = math.min(maxScroll, current + GUI_CONFIG.scrollSpeed)
        self.contentFrame:SetVerticalScroll(newScroll)
    end)

    downButton:SetScript("OnEnter", function()
        CreateBackdrop(downButton, {0.15, 0.15, 0.15, 1}, GUI_CONFIG.colors.border, 1, true)
        downArrow:SetVertexColor(math.min(1, self.classColor[1] + 0.2), math.min(1, self.classColor[2] + 0.2), math.min(1, self.classColor[3] + 0.2), 1)
        downArrow2:SetVertexColor(math.min(1, self.classColor[1] + 0.2), math.min(1, self.classColor[2] + 0.2), math.min(1, self.classColor[3] + 0.2), 1)
    end)

    downButton:SetScript("OnLeave", function()
        CreateBackdrop(downButton, {0.12, 0.12, 0.12, 0.9}, GUI_CONFIG.colors.border, 1, true)
        downArrow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)
        downArrow2:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)
    end)

    scrollBar:SetScript("OnEnter", function()
        scrollThumbBg:SetVertexColor(math.min(1, self.classColor[1] + 0.2), math.min(1, self.classColor[2] + 0.2), math.min(1, self.classColor[3] + 0.2), 1)
        scrollThumbGlow:SetVertexColor(math.min(1, self.classColor[1] + 0.2), math.min(1, self.classColor[2] + 0.2), math.min(1, self.classColor[3] + 0.2), 0.8)
        scrollThumbBorder:SetVertexColor(1, 1, 1, 0.6)
    end)

    scrollBar:SetScript("OnLeave", function()
        scrollThumbBg:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)
        scrollThumbGlow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.5)
        scrollThumbBorder:SetVertexColor(1, 1, 1, 0.3)
    end)

    scrollBar:SetScript("OnValueChanged", function(self, value)
        self:GetParent():SetVerticalScroll(value)
    end)

    self.contentFrame:SetScript("OnScrollRangeChanged", function(frame, xrange, yrange)
        scrollBar:SetMinMaxValues(0, yrange)
    end)

    self.contentFrame:SetScript("OnVerticalScroll", function(frame, offset)
        scrollBar:SetValue(offset)
    end)

    self.contentFrame:EnableMouseWheel(true)
    self.contentFrame:SetScript("OnMouseWheel", function(frame, delta)
        local current = frame:GetVerticalScroll()
        local maxScroll = frame:GetVerticalScrollRange()
        local newScroll = math.max(0, math.min(maxScroll, current - (delta * GUI_CONFIG.scrollSpeed)))
        frame:SetVerticalScroll(newScroll)
    end)

    VanFW:Debug("GUI menu initialized for " .. self.name, "GUI")
end

function Menu:Show()
    if not self.frame then return end

    if #self.tabs > 0 and (not self.tabButtons or #self.tabButtons == 0) then
        self:RenderTabs()
    end

    if #self.tabs > 0 and not self.currentTab then
        self:SelectTab(self.tabs[1])
    end

    self.frame:Show()

    if self.currentTab then
        self:RenderTabContent(self.currentTab)
    end
end

function Menu:Hide()
    if not self.frame then return end
    self.frame:Hide()
end

function Menu:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end


function Menu:AddTab(name)
    if not name then return end

    local tab = {
        name = name,
        elements = {},
        frame = nil,
    }

    tinsert(self.tabs, tab)

    if self.frame and self.frame:IsShown() then
        self:RenderTabs()
        if #self.tabs == 1 then
            self:SelectTab(tab)
        end
    end

    return tab
end

function Menu:RenderTabs()
    if self.tabButtons then
        for _, btn in ipairs(self.tabButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
    end

    self.tabButtons = {}

    local totalTabs = #self.tabs
    if totalTabs == 0 then return end

    local containerWidth = self.tabContainer:GetWidth()
    local availableWidth = containerWidth - (GUI_CONFIG.tabSpacing * (totalTabs + 1))

    local tabWidth = GUI_CONFIG.tabWidth
    local totalNeededWidth = (GUI_CONFIG.tabWidth * totalTabs) + (GUI_CONFIG.tabSpacing * (totalTabs - 1))

    if totalNeededWidth > containerWidth then
        tabWidth = math.floor(availableWidth / totalTabs)
    end

    local totalWidth = (tabWidth * totalTabs) + (GUI_CONFIG.tabSpacing * (totalTabs - 1))
    local startX = -(totalWidth / 2) + (tabWidth / 2)

    for i, tab in ipairs(self.tabs) do
        local btn = CreateFrame("Button", nil, self.tabContainer, "BackdropTemplate")
        btn:SetSize(tabWidth, GUI_CONFIG.tabHeight)

        local xPos = startX + ((i - 1) * (tabWidth + GUI_CONFIG.tabSpacing))
        btn:SetPoint("CENTER", self.tabContainer, "CENTER", xPos, 0)

        local isActive = (self.currentTab == tab)
        -- Tab buttons with class-colored border
        CreateBackdrop(btn,
            isActive and GUI_CONFIG.colors.tabActive or GUI_CONFIG.colors.tabInactive,
            self.classColor, 1)

        local text = CreateFontString(btn, tab.name, GUI_CONFIG.fontSize, GUI_CONFIG.colors.text)
        text:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.text = text

        btn:SetScript("OnEnter", function()
            if self.currentTab ~= tab then
                CreateBackdrop(btn, GUI_CONFIG.colors.tabHover, self.classColor, 1)
            end
        end)

        btn:SetScript("OnLeave", function()
            if self.currentTab ~= tab then
                CreateBackdrop(btn, GUI_CONFIG.colors.tabInactive, self.classColor, 1)
            end
        end)

        btn:SetScript("OnClick", function()
            self:SelectTab(tab)
        end)

        btn.tab = tab
        tinsert(self.tabButtons, btn)
    end
end

function Menu:SelectTab(tab)
    self.currentTab = tab

    if self.tabButtons then
        for _, btn in ipairs(self.tabButtons) do
            local isActive = (btn.tab == tab)
            CreateBackdrop(btn,
                isActive and GUI_CONFIG.colors.tabActive or GUI_CONFIG.colors.tabInactive,
                GUI_CONFIG.colors.border, 1)
        end
    end

    self:RenderTabContent(tab)
end

function Menu:RenderTabContent(tab)
    if self.scrollChild then
        for _, child in ipairs({self.scrollChild:GetChildren()}) do
            child:Hide()
            child:SetParent(nil)
        end
    end

    local yOffset = -10

    for _, element in ipairs(tab.elements) do
        if element.type == "checkbox" then
            yOffset = self:RenderCheckbox(element, yOffset)
        elseif element.type == "slider" then
            yOffset = self:RenderSlider(element, yOffset)
        elseif element.type == "dropdown" then
            yOffset = self:RenderDropdown(element, yOffset)
        elseif element.type == "text" then
            yOffset = self:RenderText(element, yOffset)
        end
    end
end

function Menu:RenderCheckbox(element, yOffset)
    local frame = CreateFrame("Frame", nil, self.scrollChild, "BackdropTemplate")
    frame:SetSize(GUI_CONFIG.width - 80, 35)
    frame:SetPoint("TOP", self.scrollChild, "TOP", 0, yOffset)

    CreateBackdrop(frame, GUI_CONFIG.colors.elementBg, GUI_CONFIG.colors.border, 1, true)

    local cbContainer = CreateFrame("Button", nil, frame, "BackdropTemplate")
    cbContainer:SetSize(20, 20)
    cbContainer:SetPoint("LEFT", frame, "LEFT", 10, 0)

    cbContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 2,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    cbContainer:SetBackdropColor(0.08, 0.08, 0.08, 1)
    cbContainer:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    local cbGlow = cbContainer:CreateTexture(nil, "BACKGROUND")
    cbGlow:SetTexture("Interface\\GLUES\\MODELS\\UI_MainMenu\\UI-ModelGlow-Red")
    cbGlow:SetPoint("CENTER", cbContainer, "CENTER", 0, 0)
    cbGlow:SetSize(35, 35)
    cbGlow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0)
    cbGlow:SetBlendMode("ADD")

    local checkmark = cbContainer:CreateTexture(nil, "OVERLAY")
    checkmark:SetTexture("Interface\\Buttons\\WHITE8X8")
    checkmark:SetSize(6, 2.5)
    checkmark:SetPoint("CENTER", cbContainer, "CENTER", -2.5, -1.5)
    checkmark:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 1)
    checkmark:SetRotation(math.rad(-45))
    checkmark:Hide()

    local checkmark2 = cbContainer:CreateTexture(nil, "OVERLAY")
    checkmark2:SetTexture("Interface\\Buttons\\WHITE8X8")
    checkmark2:SetSize(11, 2.5)
    checkmark2:SetPoint("CENTER", cbContainer, "CENTER", 1.5, 0.5)
    checkmark2:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 1)
    checkmark2:SetRotation(math.rad(45))
    checkmark2:Hide()

    local checkGlow = cbContainer:CreateTexture(nil, "ARTWORK")
    checkGlow:SetTexture("Interface\\GLUES\\MODELS\\UI_MainMenu\\UI-ModelGlow-Red")
    checkGlow:SetPoint("CENTER", cbContainer, "CENTER", 0, 0)
    checkGlow:SetSize(30, 30)
    checkGlow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.4)
    checkGlow:SetBlendMode("ADD")
    checkGlow:Hide()

    local isChecked = element.value or false

    local function UpdateCheckbox()
        if isChecked then
            checkmark:Show()
            checkmark2:Show()
            checkGlow:Show()
            cbContainer:SetBackdropColor(self.classColor[1] * 0.2, self.classColor[2] * 0.2, self.classColor[3] * 0.2, 1)
            cbContainer:SetBackdropBorderColor(self.classColor[1], self.classColor[2], self.classColor[3], 1)
        else
            checkmark:Hide()
            checkmark2:Hide()
            checkGlow:Hide()
            cbContainer:SetBackdropColor(0.08, 0.08, 0.08, 1)
            cbContainer:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        end
    end

    UpdateCheckbox()

    cbContainer:SetScript("OnClick", function()
        isChecked = not isChecked
        element.value = isChecked
        UpdateCheckbox()

        if element.callback then
            element.callback(isChecked)
        end
    end)

    cbContainer:SetScript("OnEnter", function()
        cbGlow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.3)
        cbContainer:SetBackdropBorderColor(
            math.min(1, self.classColor[1] + 0.2),
            math.min(1, self.classColor[2] + 0.2),
            math.min(1, self.classColor[3] + 0.2),
            1
        )

        if element.tooltip then
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:SetText(element.tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end
    end)

    cbContainer:SetScript("OnLeave", function()
        cbGlow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0)

        if isChecked then
            cbContainer:SetBackdropBorderColor(self.classColor[1], self.classColor[2], self.classColor[3], 1)
        else
            cbContainer:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        end

        if element.tooltip then
            GameTooltip:Hide()
        end
    end)

    local label = CreateFontString(frame, element.label or "Checkbox", GUI_CONFIG.fontSize)
    label:SetPoint("LEFT", cbContainer, "RIGHT", 10, 0)

    return yOffset - 40
end

function Menu:RenderSlider(element, yOffset)
    local frame = CreateFrame("Frame", nil, self.scrollChild, "BackdropTemplate")
    frame:SetSize(GUI_CONFIG.width - 80, 65)
    frame:SetPoint("TOP", self.scrollChild, "TOP", 0, yOffset)

    CreateBackdrop(frame, GUI_CONFIG.colors.elementBg, GUI_CONFIG.colors.border, 1, true)

    local label = CreateFontString(frame, element.label or "Slider", GUI_CONFIG.fontSize)
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    local valueText = CreateFontString(frame, tostring(element.value or element.min or 0), GUI_CONFIG.fontSize, self.classColor)
    valueText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)

    local sliderBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sliderBg:SetSize(frame:GetWidth() - 30, 4)
    sliderBg:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)

    sliderBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = nil,
        tile = false,
        tileSize = 0,
        edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    sliderBg:SetBackdropColor(0.08, 0.08, 0.08, 1)

    local bgLeft = sliderBg:CreateTexture(nil, "BACKGROUND")
    bgLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    bgLeft:SetVertexColor(0.08, 0.08, 0.08, 1)
    bgLeft:SetSize(2, 4)
    bgLeft:SetPoint("LEFT", sliderBg, "LEFT", 0, 0)

    local bgRight = sliderBg:CreateTexture(nil, "BACKGROUND")
    bgRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    bgRight:SetVertexColor(0.08, 0.08, 0.08, 1)
    bgRight:SetSize(2, 4)
    bgRight:SetPoint("RIGHT", sliderBg, "RIGHT", 0, 0)

    local sliderGlow = sliderBg:CreateTexture(nil, "ARTWORK")
    sliderGlow:SetTexture("Interface\\GLUES\\MODELS\\UI_MainMenu\\UI-ModelGlow-Red")
    sliderGlow:SetPoint("CENTER", sliderBg, "CENTER", 0, 0)
    sliderGlow:SetSize(sliderBg:GetWidth() + 20, sliderBg:GetHeight() + 20)
    sliderGlow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.2)
    sliderGlow:SetBlendMode("ADD")

    local sliderFill = CreateFrame("Frame", nil, sliderBg)
    sliderFill:SetPoint("LEFT", sliderBg, "LEFT", 0, 0)
    sliderFill:SetHeight(4)

    local fillTexture = sliderFill:CreateTexture(nil, "OVERLAY")
    fillTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
    fillTexture:SetAllPoints(sliderFill)
    fillTexture:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)

    local fillLeft = sliderFill:CreateTexture(nil, "OVERLAY")
    fillLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    fillLeft:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)
    fillLeft:SetSize(2, 4)
    fillLeft:SetPoint("LEFT", sliderFill, "LEFT", 0, 0)

    local fillRight = sliderFill:CreateTexture(nil, "OVERLAY")
    fillRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    fillRight:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.9)
    fillRight:SetSize(2, 4)
    fillRight:SetPoint("RIGHT", sliderFill, "RIGHT", 0, 0)

    local fillDot = sliderFill:CreateTexture(nil, "ARTWORK")
    fillDot:SetTexture("Interface\\GLUES\\MODELS\\UI_MainMenu\\UI-ModelGlow-Red")
    fillDot:SetPoint("RIGHT", sliderFill, "RIGHT", 0, 0)
    fillDot:SetSize(16, 16)
    fillDot:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.8)
    fillDot:SetBlendMode("ADD")

    local slider = CreateFrame("Slider", nil, frame)
    slider:SetPoint("LEFT", sliderBg, "LEFT", 0, 0)
    slider:SetPoint("RIGHT", sliderBg, "RIGHT", 0, 0)
    slider:SetHeight(20)
    slider:SetMinMaxValues(element.min or 0, element.max or 100)
    slider:SetValue(element.value or element.min or 0)
    slider:SetValueStep(element.step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetOrientation("HORIZONTAL")

    local thumbTex = slider:CreateTexture(nil, "ARTWORK")
    thumbTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    thumbTex:SetSize(1, 1)
    thumbTex:SetColorTexture(0, 0, 0, 0)
    slider:SetThumbTexture(thumbTex)

    local thumb = CreateFrame("Frame", nil, slider)
    thumb:SetSize(10, 10)
    thumb:SetPoint("CENTER", slider:GetThumbTexture(), "CENTER", 0, 0)

    local thumbBg = thumb:CreateTexture(nil, "BACKGROUND")
    thumbBg:SetTexture("Interface\\AddOns\\Blizzard_ChallengesUI\\ChallengeModeTimerFill")
    thumbBg:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    thumbBg:SetAllPoints(thumb)
    thumbBg:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 1)

    local thumbBorder = thumb:CreateTexture(nil, "ARTWORK")
    thumbBorder:SetTexture("Interface\\AddOns\\Blizzard_ChallengesUI\\ChallengeModeTimerFill")
    thumbBorder:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    thumbBorder:SetPoint("CENTER", thumb, "CENTER")
    thumbBorder:SetSize(12, 12)
    thumbBorder:SetVertexColor(1, 1, 1, 0.5)

    local thumbGlow = thumb:CreateTexture(nil, "OVERLAY")
    thumbGlow:SetTexture("Interface\\GLUES\\MODELS\\UI_MainMenu\\UI-ModelGlow-Red")
    thumbGlow:SetPoint("CENTER", thumb, "CENTER", 0, 0)
    thumbGlow:SetSize(22, 22)
    thumbGlow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.6)
    thumbGlow:SetBlendMode("ADD")

    local function UpdateSliderFill(value)
        local min, max = slider:GetMinMaxValues()
        local percent = (value - min) / (max - min)
        local fillWidth = math.max(10, sliderBg:GetWidth() * percent)
        sliderFill:SetWidth(fillWidth)

        fillTexture:SetAllPoints(sliderFill)

        fillDot:ClearAllPoints()
        fillDot:SetPoint("RIGHT", sliderFill, "RIGHT", 0, 0)

    end

    UpdateSliderFill(slider:GetValue())

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        element.value = value
        valueText:SetText(tostring(value))
        UpdateSliderFill(value)

        if element.callback then
            element.callback(value)
        end
    end)

    slider:SetScript("OnEnter", function()
        local hoverColor = {
            math.min(1, self.classColor[1] + 0.2),
            math.min(1, self.classColor[2] + 0.2),
            math.min(1, self.classColor[3] + 0.2),
            1
        }
        thumbBg:SetVertexColor(hoverColor[1], hoverColor[2], hoverColor[3], 1)
        thumbBorder:SetVertexColor(1, 1, 1, 0.8)
        thumbGlow:SetVertexColor(hoverColor[1], hoverColor[2], hoverColor[3], 0.9)
        thumbGlow:SetSize(28, 28)

        if element.tooltip then
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:SetText(element.tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end
    end)

    slider:SetScript("OnLeave", function()
        thumbBg:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 1)
        thumbBorder:SetVertexColor(1, 1, 1, 0.5)
        thumbGlow:SetVertexColor(self.classColor[1], self.classColor[2], self.classColor[3], 0.6)
        thumbGlow:SetSize(22, 22)

        if element.tooltip then
            GameTooltip:Hide()
        end
    end)

    return yOffset - 75
end

function Menu:RenderDropdown(element, yOffset)
    local frame = CreateFrame("Frame", nil, self.scrollChild, "BackdropTemplate")
    frame:SetSize(GUI_CONFIG.width - 80, 45)
    frame:SetPoint("TOP", self.scrollChild, "TOP", 0, yOffset)

    CreateBackdrop(frame, GUI_CONFIG.colors.elementBg, GUI_CONFIG.colors.border, 1, true)

    local label = CreateFontString(frame, element.label or "Dropdown", GUI_CONFIG.fontSize)
    label:SetPoint("LEFT", frame, "LEFT", 10, 8)

    local dropdown = CreateFrame("Button", nil, frame, "BackdropTemplate")
    dropdown:SetSize(150, 25)
    dropdown:SetPoint("RIGHT", frame, "RIGHT", -10, -5)

    CreateBackdrop(dropdown, {0.1, 0.1, 0.1, 1}, GUI_CONFIG.colors.border, 1)

    local dropdownText = CreateFontString(dropdown, element.value or element.options[1] or "Select", GUI_CONFIG.fontSize - 1)
    dropdownText:SetPoint("LEFT", dropdown, "LEFT", 10, 0)
    dropdown:SetScript("OnClick", function()
        VanFW:Print("Dropdown functionality - Coming soon!")
    end)

    return yOffset - 55
end

function Menu:RenderText(element, yOffset)
    local frame = CreateFrame("Frame", nil, self.scrollChild)
    frame:SetSize(GUI_CONFIG.width - 80, 25)
    frame:SetPoint("TOP", self.scrollChild, "TOP", 0, yOffset)

    local text = CreateFontString(frame, element.text or "", GUI_CONFIG.fontSize, element.color or GUI_CONFIG.colors.textDim)
    text:SetPoint("LEFT", frame, "LEFT", 10, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)

    return yOffset - 30
end


function VanFW.GUI:AddCheckbox(menu, tab, options)
    if type(menu) == "string" then
        menu = VanFW.GUI.menus[menu]
    end

    if not menu or not tab then return end

    local element = {
        type = "checkbox",
        label = options.label or options.name,
        value = options.value or options.default or false,
        tooltip = options.tooltip,
        callback = options.callback,
    }

    tinsert(tab.elements, element)

    return element
end

function VanFW.GUI:AddSlider(menu, tab, options)
    if type(menu) == "string" then
        menu = VanFW.GUI.menus[menu]
    end

    if not menu or not tab then return end

    local element = {
        type = "slider",
        label = options.label or options.name,
        min = options.min or 0,
        max = options.max or 100,
        step = options.step or 1,
        value = options.value or options.default or options.min or 0,
        tooltip = options.tooltip,
        callback = options.callback,
    }

    tinsert(tab.elements, element)

    return element
end

function VanFW.GUI:AddDropdown(menu, tab, options)
    if type(menu) == "string" then
        menu = VanFW.GUI.menus[menu]
    end

    if not menu or not tab then return end

    local element = {
        type = "dropdown",
        label = options.label or options.name,
        options = options.options or {},
        value = options.value or options.default,
        tooltip = options.tooltip,
        callback = options.callback,
    }

    tinsert(tab.elements, element)

    return element
end

function VanFW.GUI:AddText(menu, tab, text, color)
    if type(menu) == "string" then
        menu = VanFW.GUI.menus[menu]
    end

    if not menu or not tab then return end

    local element = {
        type = "text",
        text = text,
        color = color,
    }

    tinsert(tab.elements, element)

    return element
end
VanFW:Debug("GUI system initialized", "GUI")
