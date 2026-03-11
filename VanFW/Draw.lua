if not _G.VanFW then
    _G.VanFW = {}
end

local VanFW = _G.VanFW
VanFW.Draw = {}
local LibDraw = _G.LibDraw

if not LibDraw then
    print("|cFFFF0000[VanFW Draw]|r LibDraw not found! Make sure Libs/LibDraw.lua is loaded first.")
    return
end

VanFW.Draw.enabled = false
VanFW.Draw.updateTimer = nil
VanFW.Draw.debugMode = false
VanFW.Draw.callbacks = {}
VanFW.Draw.currentColor = {r = 0, g = 255, b = 0, a = 255}
VanFW.Draw.currentThickness = 1

local function CalculateSegments(radius)
    if not radius or radius <= 0 then
        return 128
    end

    local segments = math.floor(64 + (radius * 2))
    return math.min(256, math.max(64, segments))
end

VanFW.Draw.ColorPresets = {
    friendly = {r = 0, g = 255, b = 0, a = 255},      -- Green
    hostile = {r = 255, g = 0, b = 0, a = 255},       -- Red
    neutral = {r = 255, g = 255, b = 0, a = 255},     -- Yellow
    party = {r = 0, g = 150, b = 255, a = 255},       -- Blue
    raid = {r = 255, g = 165, b = 0, a = 255},        -- Orange
    dead = {r = 128, g = 128, b = 128, a = 255},      -- Gray
    player = {r = 0, g = 255, b = 0, a = 255},        -- Green
    target = {r = 255, g = 0, b = 0, a = 255},        -- Red
}
VanFW.Draw.ClassColors = {
    WARRIOR = {r = 199, g = 156, b = 110, a = 255},
    PALADIN = {r = 245, g = 140, b = 186, a = 255},
    HUNTER = {r = 171, g = 212, b = 115, a = 255},
    ROGUE = {r = 255, g = 245, b = 105, a = 255},
    PRIEST = {r = 255, g = 255, b = 255, a = 255},
    DEATHKNIGHT = {r = 196, g = 31, b = 59, a = 255},
    SHAMAN = {r = 0, g = 112, b = 222, a = 255},
    MAGE = {r = 105, g = 204, b = 240, a = 255},
    WARLOCK = {r = 148, g = 130, b = 201, a = 255},
    MONK = {r = 0, g = 255, b = 150, a = 255},
    DRUID = {r = 255, g = 125, b = 10, a = 255},
    DEMONHUNTER = {r = 163, g = 48, b = 201, a = 255},
    EVOKER = {r = 51, g = 147, b = 127, a = 255},
}
function VanFW.Draw.SetColor(r, g, b, a)
    VanFW.Draw.currentColor.r = r or 0
    VanFW.Draw.currentColor.g = g or 255
    VanFW.Draw.currentColor.b = b or 0
    VanFW.Draw.currentColor.a = a or 100
end

function VanFW.Draw.SetColorRaw(r, g, b, a)
    VanFW.Draw.currentColor.r = (r or 0) * 255
    VanFW.Draw.currentColor.g = (g or 1) * 255
    VanFW.Draw.currentColor.b = (b or 0) * 255
    VanFW.Draw.currentColor.a = (a or 1) * 255
end

function VanFW.Draw.SetWidth(w)
    VanFW.Draw.currentThickness = w or 1
end

function VanFW.Draw.SetColorPreset(presetName)
    local preset = VanFW.Draw.ColorPresets[presetName]
    if preset then
        VanFW.Draw.currentColor.r = preset.r
        VanFW.Draw.currentColor.g = preset.g
        VanFW.Draw.currentColor.b = preset.b
        VanFW.Draw.currentColor.a = preset.a
        return true
    end
    return false
end

function VanFW.Draw.ColorByHealth(hpPercent, alpha)
    alpha = alpha or 255
    local r, g, b

    if hpPercent > 75 then
        r, g, b = 0, 255, 0
    elseif hpPercent > 50 then
        local factor = (hpPercent - 50) / 25
        r = math.floor(255 * (1 - factor))
        g = 255
        b = 0
    elseif hpPercent > 25 then
        local factor = (hpPercent - 25) / 25
        r = 255
        g = math.floor(255 * factor)
        b = 0
    else
        r, g, b = 255, 0, 0
    end

    return r, g, b, alpha
end

function VanFW.Draw.ColorByThreat(threatStatus, alpha)
    alpha = alpha or 255
    -- threatStatus: 0 = no threat, 1 = have threat but losing, 2 = have solid threat, 3 = have high threat

    if threatStatus == 0 then
        return 128, 128, 128, alpha  -- Gray: No threat
    elseif threatStatus == 1 then
        return 255, 255, 0, alpha    -- Yellow: Losing threat
    elseif threatStatus == 2 then
        return 255, 165, 0, alpha    -- Orange: Solid threat
    elseif threatStatus == 3 then
        return 255, 0, 0, alpha      -- Red: High threat
    else
        return 255, 255, 255, alpha  -- White: Unknown
    end
end

function VanFW.Draw.ColorByClass(classFilename, alpha)
    alpha = alpha or 255
    local classColor = VanFW.Draw.ClassColors[classFilename]

    if classColor then
        return classColor.r, classColor.g, classColor.b, alpha
    end

    return 255, 255, 255, alpha
end

function VanFW.Draw.GetUnitColor(unit, alpha)
    alpha = alpha or 255

    if not unit then
        return 255, 255, 255, alpha
    end
    if type(unit) == "table" and unit.dead and unit:dead() then
        local preset = VanFW.Draw.ColorPresets.dead
        return preset.r, preset.g, preset.b, alpha
    end
    if type(unit) == "table" then
        if unit.enemy and unit:enemy() then
            local preset = VanFW.Draw.ColorPresets.hostile
            return preset.r, preset.g, preset.b, alpha
        elseif unit.friend and unit:friend() then
            local preset = VanFW.Draw.ColorPresets.friendly
            return preset.r, preset.g, preset.b, alpha
        end
    end
    local preset = VanFW.Draw.ColorPresets.neutral
    return preset.r, preset.g, preset.b, alpha
end

function VanFW.Draw.Line(sx, sy, sz, ex, ey, ez, r, g, b, a, thickness, rainbow)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness
    rainbow = rainbow or false
    LibDraw.Line(sx, sy, sz, ex, ey, ez, r, g, b, a, thickness, rainbow)
end

function VanFW.Draw.Circle(x, y, z, size, r, g, b, a, thickness, rainbow)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness
    rainbow = rainbow or false
    LibDraw.Circle(x, y, z, size, r, g, b, a, thickness, rainbow)
end

function VanFW.Draw.GroundCircle(x, y, z, size, r, g, b, a, thickness, rainbow)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness
    rainbow = rainbow or false
    LibDraw.GroundCircle(x, y, z, size, r, g, b, a, thickness, rainbow)
end

function VanFW.Draw.Arc(x, y, z, size, facing, arcAngle, r, g, b, a, thickness)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness
    LibDraw.Arc(x, y, z, size, facing, arcAngle, r, g, b, a, thickness)
end

function VanFW.Draw.Box(x, y, z, width, height, r, g, b, a, thickness, filled)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness
    LibDraw.Rectangle(x, y, z, width, height, r, g, b, a, thickness, filled)
end


function VanFW.Draw.Text(text, x, y, z, r, g, b, a)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    LibDraw.Text(text, x, y, z, r, g, b, a)
end

function VanFW.Draw.Array(vectors, x, y, z, r, g, b, a, thickness, closed)
    if not vectors or #vectors < 2 then return end
    if not x or not y or not z then return end

    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness
    closed = closed or false
    for i = 1, #vectors - 1 do
        local v1 = vectors[i]
        local v2 = vectors[i + 1]

        if v1 and v2 and v1.x and v1.y and v2.x and v2.y then
            local x1 = x + (v1.x or 0)
            local y1 = y + (v1.y or 0)
            local z1 = z + (v1.z or 0)

            local x2 = x + (v2.x or 0)
            local y2 = y + (v2.y or 0)
            local z2 = z + (v2.z or 0)

            LibDraw.Line(x1, y1, z1, x2, y2, z2, r, g, b, a, thickness, false)
        end
    end
    if closed and #vectors > 2 then
        local v1 = vectors[#vectors]
        local v2 = vectors[1]

        if v1 and v2 and v1.x and v1.y and v2.x and v2.y then
            local x1 = x + (v1.x or 0)
            local y1 = y + (v1.y or 0)
            local z1 = z + (v1.z or 0)

            local x2 = x + (v2.x or 0)
            local y2 = y + (v2.y or 0)
            local z2 = z + (v2.z or 0)

            LibDraw.Line(x1, y1, z1, x2, y2, z2, r, g, b, a, thickness, false)
        end
    end
end

function VanFW.Draw.ArrayRotated(vectors, x, y, z, rotationZ, r, g, b, a, thickness, closed)
    if not vectors or #vectors < 2 then return end
    if not x or not y or not z then return end
    if not rotationZ then rotationZ = 0 end

    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness
    closed = closed or false

    local cos = math.cos(rotationZ)
    local sin = math.sin(rotationZ)

    local rotatedVectors = {}
    for i, v in ipairs(vectors) do
        if v and v.x and v.y then
            local rx = v.x * cos - v.y * sin
            local ry = v.x * sin + v.y * cos
            rotatedVectors[i] = {x = rx, y = ry, z = v.z or 0}
        end
    end

    VanFW.Draw.Array(rotatedVectors, x, y, z, r, g, b, a, thickness, closed)
end

function VanFW.Draw.RegisterCallback(name, callback)
    if type(callback) ~= "function" then
        print("|cFFFF0000[VanFW Draw]|r RegisterCallback: callback must be a function")
        return false
    end

    VanFW.Draw.callbacks[name] = callback
    return true
end

function VanFW.Draw.UnregisterCallback(name)
    VanFW.Draw.callbacks[name] = nil
end

local function ExecuteCallbacks()
    if not VanFW.Draw.enabled then return end
    for name, callback in pairs(VanFW.Draw.callbacks) do
        local success, err = pcall(callback)
        if not success then
            print("|cFFFF0000[VanFW Draw]|r Error in callback '" .. name .. "': " .. tostring(err))
        end
    end
end

function VanFW.Draw.Enable(interval)
    if VanFW.Draw.enabled then
        print("|cFFFFFF00[VanFW Draw]|r Already enabled")
        return
    end
    if not VanFW.Draw.updateFrame then
        VanFW.Draw.updateFrame = CreateFrame("Frame")
        VanFW.Draw.updateFrame:SetScript("OnUpdate", function(self, elapsed)
            if VanFW.Draw.enabled then
                ExecuteCallbacks()
            end
        end)
    end

    VanFW.Draw.enabled = true

end

function VanFW.Draw.Disable()
    if not VanFW.Draw.enabled then
        print("|cFFFFFF00[VanFW Draw]|r Already disabled")
        return
    end

    VanFW.Draw.enabled = false
    print("|cFF00FF00[VanFW Draw]|r Drawing disabled")
end

function VanFW.Draw.Toggle()
    if VanFW.Draw.enabled then
        VanFW.Draw.Disable()
    else
        VanFW.Draw.Enable()
    end
end

local function GetPositionFromUnitOrPointer(unitOrPointer)
    local x, y, z

    if type(unitOrPointer) == "number" then
        if VanFW.ObjectPos then
            x, y, z = VanFW.ObjectPos(unitOrPointer)
        end
    else

        if not UnitExists(unitOrPointer) then return nil, nil, nil end

        if unitOrPointer == "player" and VanFW.GetPlayerPosition then
            x, y, z = VanFW.GetPlayerPosition()
        else
            if VanFW.ObjectPointer and VanFW.ObjectPos then
                local pointer = VanFW.ObjectPointer(unitOrPointer)
                if pointer then
                    x, y, z = VanFW.ObjectPos(pointer)
                end
            end
        end
    end

    return x, y, z
end

function VanFW.Draw.CircleAroundUnit(unit, size, r, g, b, a, thickness, rainbow)
    local x, y, z = GetPositionFromUnitOrPointer(unit)

    if not x or not y or not z then return end

    VanFW.Draw.Circle(x, y, z, size, r, g, b, a, thickness, rainbow)
end

function VanFW.Draw.CircleAroundPlayer(size, r, g, b, a, thickness, rainbow)
    VanFW.Draw.CircleAroundUnit("player", size, r, g, b, a, thickness, rainbow)
end

function VanFW.Draw.CircleAroundTarget(size, r, g, b, a, thickness, rainbow)
    VanFW.Draw.CircleAroundUnit("target", size, r, g, b, a, thickness, rainbow)
end

function VanFW.Draw.LineBetweenUnits(unit1, unit2, r, g, b, a, thickness, rainbow)
    local x1, y1, z1 = GetPositionFromUnitOrPointer(unit1)
    local x2, y2, z2 = GetPositionFromUnitOrPointer(unit2)

    if not x1 or not x2 then return end

    VanFW.Draw.Line(x1, y1, z1, x2, y2, z2, r, g, b, a, thickness, rainbow)
end

function VanFW.Draw.ToggleDebug()
    VanFW.Draw.debugMode = not VanFW.Draw.debugMode
    if VanFW.Draw.debugMode then
        print("|cFF00FF00[VanFW Draw]|r Debug mode enabled")
    else
        print("|cFF00FF00[VanFW Draw]|r Debug mode disabled")
    end
end

function VanFW.Draw.DrawAllObjects()
    if not VanFW.GetPlayerPosition then
        if VanFW.Draw.debugMode then
            print("[VanFW Draw] GetPlayerPosition not available")
        end
        return
    end

    local px, py, pz = VanFW.GetPlayerPosition()
    if not px then
        if VanFW.Draw.debugMode then
            print("[VanFW Draw] Could not get player position")
        end
        return
    end

    local playerGUID = UnitGUID("player")
    local targetGUID = UnitGUID("target")

    local count = VanFW.GetObjectCount and VanFW.GetObjectCount() or 0
    if count == 0 then
        if VanFW.Draw.debugMode then
            print("[VanFW Draw] Object count is 0")
        end
        return
    end

    if VanFW.Draw.debugMode then
        print(string.format("[VanFW Draw] Processing %d objects", count))
    end

    local objectsDrawn = 0
    local objectsWithPosition = 0
    for i = 1, count do
        local success, pointer = pcall(VanFW.GetObjectWithIndex, i)
        if success and pointer and pointer ~= 0 then
            local sx, sy, sz
            if VanFW.ObjectPos then
                local posSuccess
                posSuccess, sx, sy, sz = pcall(VanFW.ObjectPos, pointer)
                if not posSuccess then
                    sx, sy, sz = nil, nil, nil
                end
            end

            if sx and sy and sz then
                objectsWithPosition = objectsWithPosition + 1
                local guid = ""
                if VanFW.ObjectGUID then
                    local guidSuccess, objGUID = pcall(VanFW.ObjectGUID, pointer)
                    if guidSuccess and objGUID then
                        guid = objGUID
                    end
                end
                local r, g, b, a = 135, 206, 250, 100
                local drawLine = true

                if guid == playerGUID then
                    r, g, b = 0, 255, 0
                    drawLine = false
                elseif guid == targetGUID then
                    r, g, b = 255, 0, 0
                end
                VanFW.Draw.Circle(sx, sy, sz, 2, r, g, b, a, 2.5)
                if drawLine then
                    VanFW.Draw.Line(px, py, pz, sx, sy, sz, r, g, b, a, 2.5)
                end

                objectsDrawn = objectsDrawn + 1
            end
        end
    end

    if VanFW.Draw.debugMode then
        print(string.format("[VanFW Draw] Drew %d objects (%d had positions)", objectsDrawn, objectsWithPosition))
        local greenCount = (playerGUID and 1 or 0)
        local redCount = (targetGUID and 1 or 0)
        local blueCount = objectsDrawn - greenCount - redCount
        print(string.format("[VanFW Draw] Colors - Green:%d Red:%d Blue:%d", greenCount, redCount, blueCount))
    end
end

function VanFW.Draw.InitDrawAllObjects()
    print("|cFF00FFFF[VanFW Draw]|r InitDrawAllObjects called")
    local success = VanFW.Draw.RegisterCallback("draw_all_objects", VanFW.Draw.DrawAllObjects)
    print("|cFF00FFFF[VanFW Draw]|r draw_all_objects registered: " .. tostring(success))
    return success
end


function VanFW.Draw.FilledCircle(x, y, z, radius, r, g, b, a)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    local segments = CalculateSegments(radius)
    LibDraw.FilledCircle(x, y, z, radius, r, g, b, a, segments)
end

function VanFW.Draw.SolidCircle(x, y, z, radius, r, g, b, a)
    VanFW.Draw.FilledCircle(x, y, z, radius, r, g, b, a)
end

function VanFW.Draw.Ring(x, y, z, outerRadius, innerRadius, r, g, b, a, thickness)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness
    local segments = CalculateSegments(outerRadius)
    LibDraw.Circle(x, y, z, outerRadius, r, g, b, a, thickness, false, segments)
    LibDraw.Circle(x, y, z, innerRadius, r, g, b, a, thickness, false, segments)
end

function VanFW.Draw.Donut(x, y, z, outerRadius, innerRadius, r, g, b, a)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    local segments = CalculateSegments(outerRadius)

    local angleStep = (2 * math.pi) / segments
    for i = 0, segments - 1 do
        local angle1 = i * angleStep
        local angle2 = (i + 1) * angleStep

        local ox1 = x + math.cos(angle1) * outerRadius
        local oy1 = y + math.sin(angle1) * outerRadius
        local ox2 = x + math.cos(angle2) * outerRadius
        local oy2 = y + math.sin(angle2) * outerRadius

        local ix1 = x + math.cos(angle1) * innerRadius
        local iy1 = y + math.sin(angle1) * innerRadius
        local ix2 = x + math.cos(angle2) * innerRadius
        local iy2 = y + math.sin(angle2) * innerRadius

        LibDraw.Line(ox1, oy1, z, ix1, iy1, z, r, g, b, a, 1, false)
        LibDraw.Line(ox2, oy2, z, ix2, iy2, z, r, g, b, a, 1, false)
        LibDraw.Line(ox1, oy1, z, ox2, oy2, z, r, g, b, a, 1, false)
        LibDraw.Line(ix1, iy1, z, ix2, iy2, z, r, g, b, a, 1, false)
    end
end

function VanFW.Draw.Polygon(x, y, z, radius, sides, r, g, b, a, thickness, rotation)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness
    rotation = rotation or 0
    sides = sides or 6

    local angleStep = (2 * math.pi) / sides

    local lx, ly
    for i = 0, sides do
        local angle = (i * angleStep) + rotation
        local wx = x + math.cos(angle) * radius
        local wy = y + math.sin(angle) * radius

        if lx and ly then
            LibDraw.Line(lx, ly, z, wx, wy, z, r, g, b, a, thickness, false)
        end
        lx, ly = wx, wy
    end
end

function VanFW.Draw.Triangle(x1, y1, z1, x2, y2, z2, x3, y3, z3, r, g, b, a, thickness, filled)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness

    if filled then
        local cx = (x1 + x2 + x3) / 3
        local cy = (y1 + y2 + y3) / 3
        local cz = (z1 + z2 + z3) / 3

        LibDraw.Line(cx, cy, cz, x1, y1, z1, r, g, b, a, 1, false)
        LibDraw.Line(cx, cy, cz, x2, y2, z2, r, g, b, a, 1, false)
        LibDraw.Line(cx, cy, cz, x3, y3, z3, r, g, b, a, 1, false)
    end

    LibDraw.Line(x1, y1, z1, x2, y2, z2, r, g, b, a, thickness, false)
    LibDraw.Line(x2, y2, z2, x3, y3, z3, r, g, b, a, thickness, false)
    LibDraw.Line(x3, y3, z3, x1, y1, z1, r, g, b, a, thickness, false)
end

function VanFW.Draw.Cylinder(x, y, z, radius, height, r, g, b, a, thickness)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness
    local segments = CalculateSegments(radius)

    LibDraw.Circle(x, y, z, radius, r, g, b, a, thickness, false, segments)
    LibDraw.Circle(x, y, z + height, radius, r, g, b, a, thickness, false, segments)
    local angleStep = (2 * math.pi) / segments
    for i = 0, segments - 1 do
        local angle = i * angleStep
        local wx = x + math.cos(angle) * radius
        local wy = y + math.sin(angle) * radius

        LibDraw.Line(wx, wy, z, wx, wy, z + height, r, g, b, a, thickness, false)
    end
end

function VanFW.Draw.Sphere(x, y, z, radius, r, g, b, a, thickness)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness
    local segments = CalculateSegments(radius)

    LibDraw.Sphere(x, y, z, radius, r, g, b, a, thickness, false, segments)
end

function VanFW.Draw.Cone(x, y, z, facing, length, angle, r, g, b, a, thickness)
    r = r or VanFW.Draw.currentColor.r
    g = g or VanFW.Draw.currentColor.g
    b = b or VanFW.Draw.currentColor.b
    a = a or VanFW.Draw.currentColor.a
    thickness = thickness or VanFW.Draw.currentThickness
    local segments = CalculateSegments(length)

    local halfAngle = angle / 2
    local startAngle = facing - halfAngle
    local endAngle = facing + halfAngle
    local angleStep = angle / segments
    LibDraw.Arc(x, y, z, length, facing, angle, r, g, b, a, thickness, false, segments)

    local x1 = x + math.cos(startAngle) * length
    local y1 = y + math.sin(startAngle) * length
    local x2 = x + math.cos(endAngle) * length
    local y2 = y + math.sin(endAngle) * length

    LibDraw.Line(x, y, z, x1, y1, z, r, g, b, a, thickness, false)
    LibDraw.Line(x, y, z, x2, y2, z, r, g, b, a, thickness, false)
end


function VanFW.Draw.FilledCircleAroundUnit(unit, radius, presetOrR, g, b, a)
    local x, y, z = GetPositionFromUnitOrPointer(unit)
    if not x or not y or not z then return end

    local r = presetOrR
    if type(presetOrR) == "string" then
        r, g, b, a = VanFW.Draw.GetUnitColor(unit, a or 255)
    end

    VanFW.Draw.FilledCircle(x, y, z, radius, r, g, b, a)
end

function VanFW.Draw.RingAroundUnit(unit, outerRadius, innerRadius, r, g, b, a, thickness)
    local x, y, z = GetPositionFromUnitOrPointer(unit)
    if not x or not y or not z then return end

    VanFW.Draw.Ring(x, y, z, outerRadius, innerRadius, r, g, b, a, thickness)
end

function VanFW.Draw.ConeFromUnit(unit, facing, length, angle, r, g, b, a, thickness)
    local x, y, z = GetPositionFromUnitOrPointer(unit)
    if not x or not y or not z then return end

    VanFW.Draw.Cone(x, y, z, facing, length, angle, r, g, b, a, thickness)
end

function VanFW.Draw.AreaTrigger(x, y, z, radius, options)
    options = options or {}
    local filled = options.filled or false
    local r = options.r or VanFW.Draw.currentColor.r
    local g = options.g or VanFW.Draw.currentColor.g
    local b = options.b or VanFW.Draw.currentColor.b
    local a = options.a or VanFW.Draw.currentColor.a
    local thickness = options.thickness or VanFW.Draw.currentThickness
    local rainbow = options.rainbow or false    if options.preset then
        local preset = VanFW.Draw.ColorPresets[options.preset]
        if preset then
            r = preset.r
            g = preset.g
            b = preset.b
            a = options.a or preset.a
        end
    end
    if filled then
        VanFW.Draw.FilledCircle(x, y, z, radius, r, g, b, a)
    else
        VanFW.Draw.Circle(x, y, z, radius, r, g, b, a, thickness, rainbow)
    end
end

VanFW.Draw.Missiles = {
    tracked = {},
    maxDistance = 50,
    updateInterval = 0.01,
    lastUpdate = 0,
    spellRadiusOverrides = {
        -- Add spell-specific radiuses here
        -- Example: [12345] = 3.5,  -- Fireball has 3.5 yard radius
    },

    debugMode = false,
    showPrediction = true,
}
VanFW.Draw.MissileShapes = {
    FIREBALL = "oval",      -- Oval shape for fireballs
    GROUND = "ring",        -- Ring on ground
    LINEAR = "cylinder",    -- Cylinder for linear projectiles
    ARC = "sphere",         -- Sphere for arcing projectiles
}

function VanFW.Draw.Missiles:GetMissileShapeFromPosition(mx, my, mz, sx, sy, sz, tx, ty, tz)
    if not mx or not my or not mz then
        return VanFW.Draw.MissileShapes.OVAL
    end

    local px, py, pz = VanFW.GetPlayerPosition()
    if not pz then
        return VanFW.Draw.MissileShapes.OVAL
    end
    if sx and sz and tx and tz then
        local sourceHeight = sz - pz
        local targetHeight = tz - pz
        local missileHeight = mz - pz

        if math.abs(sourceHeight) < 0.5 and math.abs(targetHeight) < 0.5 and math.abs(missileHeight) < 0.5 then
            return VanFW.Draw.MissileShapes.GROUND
        end
    end

    return VanFW.Draw.MissileShapes.OVAL
end

function VanFW.Draw.Missiles:UpdateTracking()
    local currentTime = GetTime()

    if currentTime - self.lastUpdate < self.updateInterval then
        return
    end

    self.lastUpdate = currentTime

    for missileId, data in pairs(self.tracked) do
        if currentTime > data.expiresAt then
            self.tracked[missileId] = nil
        end
    end

    if not _G.WGG_GetMissileCount or not _G.WGG_GetMissileWithIndex then
        return
    end

    local px, py, pz = VanFW.GetPlayerPosition()
    if not px then return end

    local missileCount = _G.WGG_GetMissileCount()
    if not missileCount or missileCount == 0 then
        return
    end

    for i = 1, missileCount do
        local spellId, _, mx, my, mz, sourceGuid, sx, sy, sz, targetGuid, tx, ty, tz = _G.WGG_GetMissileWithIndex(i)

        if spellId and spellId > 0 and mx and my and mz then
            local distance = VanFW.Distance(px, py, pz, mx, my, mz)

            if distance and distance <= self.maxDistance then
                local missileId = string.format("%d_%.1f_%.1f_%.1f", spellId, sx or 0, sy or 0, sz or 0)
                local travelDist = 0
                local estimatedDuration = 10

                if sx and sy and sz and tx and ty and tz then
                    travelDist = VanFW.Distance(sx, sy, sz, tx, ty, tz)
                    estimatedDuration = math.max(0.5, travelDist / 30)
                end

                local spellName
                if C_Spell and C_Spell.GetSpellName then
                    spellName = C_Spell.GetSpellName(spellId)
                end

                local shape = self:GetMissileShapeFromPosition(mx, my, mz, sx, sy, sz, tx, ty, tz)
                local radius = self.spellRadiusOverrides[spellId]

                if not radius and tx and ty and tz then
                    if VanFW.GetObjectCount and VanFW.GetObjectWithIndex and VanFW.ObjectType then
                        local objectCount = VanFW.GetObjectCount()
                        for j = 1, objectCount do
                            local pointer = VanFW.GetObjectWithIndex(j)
                            if pointer and pointer ~= 0 then
                                local objType = VanFW.ObjectType(pointer)
                                if objType == 11 then
                                    local posSuccess, ax, ay, az = pcall(VanFW.ObjectPos, pointer)
                                    if posSuccess and ax and ay and az then
                                        local dist = VanFW.Distance(tx, ty, tz, ax, ay, az)
                                        if dist and dist < 3 then
                                            local scaleSuccess, scale = pcall(VanFW.ObjectScale, pointer)
                                            if scaleSuccess and scale and scale > 0 then
                                                radius = scale
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                radius = radius or 1.5

                if not self.tracked[missileId] then
                    self.tracked[missileId] = {
                        missileId = missileId,
                        spellId = spellId,
                        spellName = spellName or "Unknown",
                        x = mx,
                        y = my,
                        z = mz,
                        sourceX = sx,
                        sourceY = sy,
                        sourceZ = sz,
                        targetX = tx,
                        targetY = ty,
                        targetZ = tz,
                        sourceGuid = sourceGuid,
                        targetGuid = targetGuid,
                        radius = radius,
                        shape = shape,
                        travelDistance = travelDist,
                        createdAt = currentTime,
                        expiresAt = currentTime + estimatedDuration,
                        duration = estimatedDuration,
                    }

                    if self.debugMode then
                        print("|cFF00FFFF[VanFW Missiles]|r New missile:", spellName or spellId, "Shape:", shape, "Duration:", string.format("%.2f", estimatedDuration), "Distance:", string.format("%.1f", travelDist))
                    end
                else
                    self.tracked[missileId].x = mx
                    self.tracked[missileId].y = my
                    self.tracked[missileId].z = mz

                    if tx and ty and tz then
                        local remainingDist = VanFW.Distance(mx, my, mz, tx, ty, tz)
                        local remainingTime = math.max(0.1, remainingDist / 30)
                        self.tracked[missileId].expiresAt = currentTime + remainingTime
                    end
                end
            end
        end
    end
end

function VanFW.Draw.Missiles:DrawMissile(data)
    local currentTime = GetTime()
    local timeAlive = currentTime - data.createdAt
    local timeRemaining = data.expiresAt - currentTime
    local progressPercent = (timeAlive / data.duration) * 100

    if timeRemaining <= 0 then
        return
    end

    local alpha = 200
    if timeRemaining < 1 then
        alpha = math.floor(200 * timeRemaining)
    end
    alpha = math.max(20, alpha)

    local r, g, b = 255, 150, 0  -- Orange
    if progressPercent > 50 then
        local factor = (progressPercent - 50) / 50
        g = math.floor(150 * (1 - factor))  -- Fade green to make it more red
    end

    if self.showPrediction and data.x and data.y and data.z and data.targetX and data.targetY and data.targetZ then
        VanFW.Draw.Line(
            data.x, data.y, data.z,
            data.targetX, data.targetY, data.targetZ,
            r, g, b,
            math.floor(alpha * 0.25),  -- Lower alpha
            data.radius * 1.2
        )

        VanFW.Draw.Circle(
            data.x, data.y, data.z,
            data.radius * 0.3,
            r, g, b,
            math.floor(alpha * 0.5),
            1.5,
            false
        )

        VanFW.Draw.Circle(
            data.targetX, data.targetY, data.targetZ,
            data.radius * 0.6,
            255, 0, 0,
            math.floor(alpha * 0.3),
            1.8,
            false
        )
    end

    if data.shape == VanFW.Draw.MissileShapes.GROUND then
        VanFW.Draw.Circle(
            data.x, data.y, data.z,
            data.radius,
            r, g, b,
            alpha,
            2.5,
            false
        )

        local filledRadius = data.radius * (1 - (timeRemaining / data.duration))
        VanFW.Draw.FilledCircle(
            data.x, data.y, data.z,
            filledRadius,
            r, g, b,
            math.floor(alpha * 0.4)
        )

    elseif data.shape == VanFW.Draw.MissileShapes.OVAL then
        VanFW.Draw.Circle3D(
            data.x, data.y, data.z,
            data.radius,
            r, g, b,
            alpha,
            2.5,
            false
        )

        local filledRadius = data.radius * (1 - (timeRemaining / data.duration))
        VanFW.Draw.FilledCircle3D(
            data.x, data.y, data.z,
            filledRadius,
            r, g, b,
            math.floor(alpha * 0.5)
        )

    else
        VanFW.Draw.Circle3D(
            data.x, data.y, data.z,
            data.radius,
            r, g, b,
            alpha,
            2.5,
            false
        )

        local filledRadius = data.radius * (1 - (timeRemaining / data.duration))
        VanFW.Draw.FilledCircle3D(
            data.x, data.y, data.z,
            filledRadius,
            r, g, b,
            math.floor(alpha * 0.5)
        )
    end
end

function VanFW.Draw.Missiles:DrawAll()
    self:UpdateTracking()

    for guid, data in pairs(self.tracked) do
        self:DrawMissile(data)
    end
end

function VanFW.Draw.Circle3D(x, y, z, radius, r, g, b, a, thickness, rainbow)
    if not LibDraw then return end

    thickness = thickness or 2
    a = a or 255

    if rainbow then
        r, g, b = nil, nil, nil
    end

    LibDraw.Circle(x, y, z, radius, r, g, b, a, thickness, rainbow)
end

function VanFW.Draw.FilledCircle3D(x, y, z, radius, r, g, b, a)
    if not LibDraw then return end

    a = a or 100

    LibDraw.FilledCircle(x, y, z, radius, r, g, b, a)
end

print("|cFF00FFFF[VanFW Draw]|r Module loaded successfully")


