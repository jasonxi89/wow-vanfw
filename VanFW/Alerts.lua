local VanFW = VanFW or {}
local GetTime = _G.GetTime
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local tinsert = table.insert
local tremove = table.remove
local tContains = _G.tContains
local C_Spell = _G.C_Spell
local WorldFrame = _G.WorldFrame
local unpack = _G.unpack or table.unpack

local alerts = {
    normal = {},
    big = {}
}

local frame_cache = {}
local tickerCallbacks = {}
local function addTickerCallback(callback)
    tinsert(tickerCallbacks, callback)
end

local function removeTickerCallback(callback)
    for index, existing in ipairs(tickerCallbacks) do
        if callback == existing then
            tremove(tickerCallbacks, index)
            break
        end
    end
end

C_Timer.NewTicker(0.05, function()
    for _, callback in ipairs(tickerCallbacks) do
        callback()
    end
end)
local function lerp(a, b, t)
    return a + (b - a) * t
end
local function cubicBezier(t, x1, y1, x2, y2)
    local t2 = t * t
    local t3 = t2 * t
    local mt = 1 - t
    local mt2 = mt * mt
    local mt3 = mt2 * mt

    return 3 * mt2 * t * y1 + 3 * mt * t2 * y2 + t3
end

local function deepCompare(t1, t2)
    if type(t1) ~= type(t2) then return false end
    if type(t1) ~= "table" then return t1 == t2 end

    for k, v in pairs(t1) do
        if not deepCompare(v, t2[k]) then return false end
    end

    for k, v in pairs(t2) do
        if not deepCompare(v, t1[k]) then return false end
    end

    return true
end
local anchors = {
    big = CreateFrame("Frame"),
    normal = CreateFrame("Frame"),
}

VanFW.alertAnchors = anchors
anchors.normal:SetPoint("CENTER", WorldFrame, "CENTER", 0, 210)
anchors.normal:SetHeight(15)
anchors.normal:SetWidth(200)
anchors.normal:SetFrameStrata("HIGH")
anchors.normal:SetMovable(true)
anchors.normal:Hide()
anchors.big:SetPoint("CENTER", WorldFrame, "CENTER", 0, 195)
anchors.big:SetHeight(15)
anchors.big:SetWidth(200)
anchors.big:SetFrameStrata("HIGH")
anchors.big:SetMovable(true)
anchors.big:Hide()

local moveEnd = {
    big = GetTime() + 0.2,
    normal = GetTime() + 0.2
}

local moveAnimationTime = {
    big = 0.2,
    normal = 0.2
}

local bigGap = 14
local gap = 10

local function updateMoveInits(list, big)
    for i=#list, 1, -1 do
        local alert = list[i]
        if alert then
            alert.startY = select(5, alert:GetPoint()) + (big and -bigGap or gap)
        end
    end
end

local function CreateAlert(...)
    local args = {...}
    local options, texture, big = ...
    local duplicateAlert
    for _, list in pairs(alerts) do
        for _, alert in ipairs(list) do
            if deepCompare(alert.args, args) then
                duplicateAlert = duplicateAlert or alert
            end
        end
    end

    local message

    if type(options) == "string" then
        message = options
        options = {}
    end

    local time = GetTime()

    message = message or options.message or options.msg
    texture = texture or options.texture or options.id
    local fadeOut = options.fadeOut or 0.3
    local fadeIn = options.fadeIn or 0.175
    big = big or options.big
    local duration = options.duration and options.duration + fadeIn + fadeOut or 1 + fadeIn + fadeOut + (big and 0.4 or 0)
    local highlight = options.highlight
    local imgScale = options.imgScale or 1
    local imgX = options.imgX or 0
    local imgY = options.imgY or 0
    local targetAlpha = options.targetAlpha or 1
    local startAlpha = options.startAlpha or 0
    local scaleIn = options.scaleIn or fadeIn / 1.5
    local targetScale = options.targetScale or 1
    local startScale = options.startScale or 0.1
    local bgColor = options.bgColor
    local height = options.height or (38 + (big and 4 or 0))
    local width = 350
    local fontSize = options.fontSize or big and 17 or 15
    local listKey = big and "big" or "normal"
    if duplicateAlert then
        duplicateAlert.alpha = targetAlpha
        duplicateAlert:SetAlpha(targetAlpha)
        duplicateAlert.endTime = time + duration + fadeOut
        return duplicateAlert
    end
    if type(message) == "string" then
        for _, v in ipairs(alerts[listKey]) do
            if v.text == message and v.id == texture then
                v.alpha = targetAlpha
                v:SetAlpha(targetAlpha)
                v.endTime = time + duration
                return true
            end
        end
    end

    local existingHeight = big and -bigGap or gap

    local alert = CreateFrame("Frame", nil, nil, "BackdropTemplate")

    alert.startY = existingHeight
    alert:SetPoint("CENTER", anchors[listKey], "CENTER", 0, alert.startY)
    alert:SetHeight(height)
    alert:SetWidth(width)
    alert.id = texture
    alert.args = {...}

    updateMoveInits(alerts[listKey], big)
    moveEnd[listKey] = time + (fadeIn * 0.3)
    moveAnimationTime[listKey] = fadeIn * 0.3

    local r, g, b, a, defaultColor = 0, 0, 0, 0.4, true
    if bgColor then
        local givenA
        if type(bgColor) == "table" then
            r, g, b, givenA = unpack(bgColor)
            defaultColor = false
        end
        if givenA then
            a = givenA
        end
    end

    alert:SetAlpha(startAlpha)
    alert:SetScale(startScale)
    alert.currentScale = startScale
    alert.currentAlpha = startAlpha
    alert:SetClampedToScreen(true)
    alert.fontString = alert:CreateFontString('VanFWAlertTxt', "OVERLAY")
    alert.fontString:SetFont("Fonts/OpenSans-Bold.ttf", fontSize, options.outline or '')
    local currentFont, currentSize = alert.fontString:GetFont()
    if not currentFont or currentSize == 0 then
        alert.fontString:SetFont("Fonts/FRIZQT__.TTF", fontSize, '')
    end
    alert.fontString:SetShadowOffset(2, -3)
    alert.fontString:SetShadowColor(0.01, 0.01, 0.01, 0.57)
    alert.fontString:SetPoint("CENTER", alert, "CENTER", 0, 0)
    alert.fontString:SetJustifyV("MIDDLE")
    alert.fontString:SetJustifyH("LEFT")
    alert.fontString:SetText(message)

    alert.text = message

    if texture or options.textureLiteral then
        local t = options.textureLiteral or C_Spell.GetSpellTexture(texture)
        if t then
            local tWidth = alert:GetHeight() + 2 - gap
            local tHeight = alert:GetHeight() + 2 - gap

            if highlight then
                tWidth = tWidth * 0.8
                tHeight = tHeight * 0.8
            end

            alert.texture = alert:CreateTexture(nil, "OVERLAY")
            alert.texture:SetTexture(t)
            alert.texture:ClearAllPoints()
            alert.texture:SetWidth(tWidth * imgScale)
            alert.texture:SetHeight(tHeight * imgScale)
            alert.texture:SetPoint("LEFT", alert.fontString, "LEFT", -(tWidth + gap - 2) + imgX - (highlight and 4 or 0), 0 + imgY)
            alert.texture:SetRotation(-0.05)

            local p1, f, p2, x, y = alert.texture:GetPoint()
            x = x - imgX
            y = y - imgY

            local circleW, circleH = tWidth - 6, tHeight - 6

            if not highlight then
                alert.textureCircle = alert:CreateTexture('VanFWAlertTextureBackdrop', "ARTWORK")
                alert.textureCircle:SetTexture(t)
                alert.textureCircle:SetWidth(circleW + 3)
                alert.textureCircle:SetHeight(circleH + 3)
                alert.textureCircle:SetColorTexture(r, g, b, a)
                alert.textureCircle:SetPoint(p1, f, p2, x + 1.25, y)

                alert.textureCircleMask = alert:CreateMaskTexture()
                alert.textureCircleMask:SetAllPoints(alert.textureCircle)
                alert.textureCircleMask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                alert.textureCircle:AddMaskTexture(alert.textureCircleMask)

                alert.mask2 = alert:CreateMaskTexture()
                alert.mask2:SetPoint(p1, f, p2, x + 2.5, y)
                alert.mask2:SetWidth(circleW)
                alert.mask2:SetHeight(circleH)
                alert.mask2:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                alert.texture:AddMaskTexture(alert.mask2)
            else
                alert.border = alert:CreateTexture(nil, "OVERLAY")
                alert.border:SetPoint("CENTER", alert.texture, "CENTER", 0, 0)
                alert.border:SetWidth(tWidth * imgScale * 2)
                alert.border:SetHeight(tHeight * imgScale * 2)
                alert.border:SetTexture("Interface/BUTTONS/CheckButtonHilight-Blue")

                if not defaultColor then
                    alert.border:SetVertexColor(r, g, b, 1)
                end
            end
        end
    end

    local function callback()
        local function deleteSelf()
            removeTickerCallback(callback)
        end
        if not tContains(alerts[listKey], alert) then
            alert:SetAlpha(0)
            alert:Hide()
            deleteSelf()
        end
    end

    addTickerCallback(callback)
    alert.fadeInStart = time
    alert.fadeInEnd = time + fadeIn
    alert.scaleInStart = time
    alert.scaleInEnd = time + scaleIn
    alert.endTime = time + duration
    alert.fadeOutEnd = function() return alert.endTime + fadeOut end
    function alert:fadeOut()
                if alert.currentAlpha <= 0 then return end
        local timePct = 1 - ((self.fadeOutEnd() - GetTime()) / fadeOut)
        local completion = cubicBezier(timePct, 0, .11, .35, .9)
        if timePct < 1.35 and timePct > -0.25 then
            local alpha = lerp(targetAlpha, 0, completion)
            if alpha < 0 then alpha = 0 end
            if alert.currentAlpha == alpha then return end
            self:SetAlpha(alpha)
            self.currentAlpha = alpha
        end
    end

    function alert:fadeIn()
        if alert.currentAlpha >= targetAlpha then return end
        local timePct = 1 - ((self.fadeInEnd - GetTime()) / fadeIn)
        local completion = math.max(math.min(1, cubicBezier(timePct, 0, .25, .65, 1)), 0)
        if timePct < 1.35 and timePct > -0.25 then
            local alpha = lerp(startAlpha, targetAlpha, completion)
            if targetAlpha == 0 and alpha < 0 then alpha = 0 end
            if targetAlpha ~= 0 and alpha > targetAlpha then alpha = targetAlpha end
            if alert.currentAlpha == alpha then return end
            self:SetAlpha(alpha)
            self.currentAlpha = alpha
        end
    end

    function alert:scaleIn()
        local timePct = 1 - ((self.scaleInEnd - GetTime()) / scaleIn)
        if timePct >= 1 then
            self:SetScale(1)
            self.currentScale = 1
            return
        end
        local completion = cubicBezier(timePct, .11, .8, 1.2, 1)
        if timePct < 1.5 and timePct > -0.25 then
            local scale = lerp(startScale, targetScale, completion)
            if targetScale == 0 and scale < 0 then scale = 0 end
            self:SetScale(scale)
            self.currentScale = scale
        end
    end

    function alert:move(targetY)
        local p1, p2, p3, x, y = self:GetPoint()
        local timePct = 1 - ((moveEnd[listKey] - GetTime()) / moveAnimationTime[listKey])
        if timePct >= 1 then
            self:SetPoint(p1, p2, p3, x, targetY)
            return
        end
        local completion = cubicBezier(timePct, 0, .11, .49, .3)
        local thisY = lerp(self.startY, targetY, completion)
        self:SetPoint(p1, p2, p3, x, thisY)
    end

    tinsert(alerts[listKey], alert)

    return alert
end


local function convertOptions(...)
    local options, texture, big = ...
    if type(options) == "string" then
        options = {
            message = options,
            texture = texture,
            big = big
        }
    end
    return options
end


VanFW.Alert = setmetatable({
    -- Short duration alert
    Short = function(...)
        local options = convertOptions(...)
        options.duration = 0.05
        return CreateAlert(options)
    end,

    -- Red alert (emergency)
    Red = function(...)
        local options = convertOptions(...)
        options.bgColor = {245/255, 60/255, 60/255, 0.9}
        return CreateAlert(options)
    end,

    -- Yellow alert (warning)
    Yellow = function(...)
        local options = convertOptions(...)
        options.bgColor = {225/255, 195/255, 30/255, 0.9}
        return CreateAlert(options)
    end,

    -- Blue alert (info)
    Blue = function(...)
        local options = convertOptions(...)
        options.bgColor = {144/255, 144/255, 255/255, 0.95}
        return CreateAlert(options)
    end,

    -- Big alert
    Big = function(...)
        local options = convertOptions(...)
        options.big = true
        return CreateAlert(options)
    end,
}, {
    __call = function(_, ...) return CreateAlert(...) end
})

local function updateAlerts(list, big)
    local time = GetTime()

    for i=#list, 1, -1 do
        local alert = list[i]
        if alert then
            if time > alert.fadeOutEnd() then
                alert:SetAlpha(0)
                alert:Hide()
                tremove(list, i)
            elseif time > alert.endTime then
                alert:fadeOut()
            elseif time > alert.fadeInStart then
                alert:fadeIn()
                alert:scaleIn()
            end
        end
    end

    local totalHeight = big and -bigGap or gap
    for i=#list, 1, -1 do
        local alert = list[i]
        if alert then
            alert:move(totalHeight)
            totalHeight = totalHeight + (big and -(alert:GetHeight() / 2) or alert:GetHeight() / 2) + (big and -bigGap or gap)
        end
    end
    if big then
        if #list >= 4 then
            for i=1, #list - 4 do
                list[i]:SetAlpha(0)
                list[i]:Hide()
                tremove(list, i)
            end
        end
    end
end

CreateFrame("Frame"):SetScript("OnUpdate", function()
    updateAlerts(alerts.normal)
    updateAlerts(alerts.big, true)
end)
VanFW:Debug("Alert system initialized", "Alerts")
