
local LibDraw = {}
local pi = math.pi
local sin = math.sin
local cos = math.cos

local function ColorToFloat(r, g, b, a)
    return (r or 255) / 255, (g or 255) / 255, (b or 255) / 255, (a or 255) / 255
end

local WorldToScreen
if _G.WGG_W2S and _G.WGG_NDCToScreen then
    WorldToScreen = function(wX, wY, wZ)
        local ndcX, ndcY, visible = _G.WGG_W2S(wX, wY, wZ)

        if not visible or visible == 0 or not ndcX or not ndcY then
            return false, false, false
        end
        local px, py = _G.WGG_NDCToScreen(ndcX, ndcY)

        return px, py, true
    end
    if not _G.WorldToScreen then
        _G.WorldToScreen = WorldToScreen
    end
elseif _G.WorldToScreen then
    WorldToScreen = _G.WorldToScreen
else
    WorldToScreen = function() return false, false, false end
    print("|cFFFF0000[LibDraw]|r WorldToScreen not available!")
end

function LibDraw.Draw2DLine(x1, y1, x2, y2, r, g, b, a, thickness, rainbow, r2, g2, b2, a2)
    if _G.WGG_Draw2DLine then
        r, g, b, a = ColorToFloat(r or 0, g or 255, b or 0, a or 255)
        r2, g2, b2, a2 = ColorToFloat(r2 or 0, g2 or 0, b2 or 0, a2 or 0)
        _G.WGG_Draw2DLine(x1, y1, x2, y2, r, g, b, a, thickness or 1, rainbow and 1 or 0, r2, g2, b2, a2)
    end
end

function LibDraw.Draw2DCircle(x, y, radius, r, g, b, a, thickness, filled, rainbow, r2, g2, b2, a2)
    if _G.WGG_Draw2DCircle then
        r, g, b, a = ColorToFloat(r or 0, g or 255, b or 0, a or 255)
        r2, g2, b2, a2 = ColorToFloat(r2 or 0, g2 or 0, b2 or 0, a2 or 0)
        _G.WGG_Draw2DCircle(x, y, radius, r, g, b, a, thickness or 1, filled and 1 or 0, rainbow and 1 or 0, r2, g2, b2, a2)
    end
end

function LibDraw.Draw2DRect(x1, y1, x2, y2, r, g, b, a, thickness, filled, rainbow, r2, g2, b2, a2)
    if _G.WGG_Draw2DRectangle then
        r, g, b, a = ColorToFloat(r or 0, g or 255, b or 0, a or 255)
        r2, g2, b2, a2 = ColorToFloat(r2 or 0, g2 or 0, b2 or 0, a2 or 0)
        _G.WGG_Draw2DRectangle(x1, y1, x2, y2, r, g, b, a, thickness or 1, filled and 1 or 0, rainbow and 1 or 0, r2, g2, b2, a2)
    end
end

function LibDraw.Draw2DCorneredBox(x1, y1, x2, y2, r, g, b, a, thickness, rainbow, r2, g2, b2, a2)
    if _G.WGG_Draw2DCorneredBox then
        r, g, b, a = ColorToFloat(r or 0, g or 255, b or 0, a or 255)
        r2, g2, b2, a2 = ColorToFloat(r2 or 0, g2 or 0, b2 or 0, a2 or 0)
        _G.WGG_Draw2DCorneredBox(x1, y1, x2, y2, r, g, b, a, thickness or 1, rainbow and 1 or 0, r2, g2, b2, a2)
    end
end

function LibDraw.Draw2DText(text, x, y, r, g, b, a, fontSize, outlined)
    if not text or text == "" then return end
    if _G.WGG_Draw2DText then
        r, g, b, a = ColorToFloat(r or 255, g or 255, b or 255, a or 255)
        _G.WGG_Draw2DText(text, x, y, r, g, b, a, fontSize or 0, outlined and 1 or 0)
    end
end


function LibDraw.Line(x1, y1, z1, x2, y2, z2, r, g, b, a, thickness, rainbow, r2, g2, b2, a2)
    if not _G.WGG_Draw3DLine then return end
    local sx1, sy1, vis1 = WorldToScreen(x1, y1, z1)
    if not vis1 then return end
    local sx2, sy2, vis2 = WorldToScreen(x2, y2, z2)
    if not vis2 then return end
    r, g, b, a = ColorToFloat(r or 0, g or 255, b or 0, a or 255)
    r2, g2, b2, a2 = ColorToFloat(r2 or 0, g2 or 0, b2 or 0, a2 or 0)
    _G.WGG_Draw3DLine(sx1, sy1, 0, sx2, sy2, 0, r, g, b, a, thickness or 1, rainbow and 1 or 0, r2, g2, b2, a2)
end

function LibDraw.Circle(x, y, z, size, r, g, b, a, thickness, rainbow, segments, r2, g2, b2, a2)
    if not size or size == 0 then return end
    if not _G.WGG_Draw3DCircle then return end
    if not x or not y or not z then return end
    local segmentCount = segments or 32
    local angleStep = (2 * pi) / segmentCount

    local points = {}
    for i = 0, segmentCount do
        local angle = i * angleStep
        local wx = x + cos(angle) * size
        local wy = y + sin(angle) * size
        local wz = z

        if wx and wy and wz then
            points[i] = {x = wx, y = wy, z = wz}
        end
    end

    for i = 1, segmentCount do
        local p1 = points[i - 1]
        local p2 = points[i]
        if p1 and p2 then
            LibDraw.Line(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, r, g, b, a, thickness, rainbow, r2, g2, b2, a2)
        end
    end
end

function LibDraw.FilledCircle(x, y, z, size, r, g, b, a, segments, r2, g2, b2, a2)
    if not size or size == 0 then return end
    if not x or not y or not z then return end

    local segmentCount = segments or 32
    local angleStep = (2 * pi) / segmentCount

    local points = {}
    for i = 0, segmentCount do
        local angle = i * angleStep
        local wx = x + cos(angle) * size
        local wy = y + sin(angle) * size
        local wz = z

        if wx and wy and wz then
            points[i] = {x = wx, y = wy, z = wz}
        end
    end

    for i = 1, segmentCount do
        local p1 = points[i - 1]
        local p2 = points[i]
        if p1 and p2 then
            LibDraw.Line(x, y, z, p2.x, p2.y, p2.z, r, g, b, a, 1, false, r2, g2, b2, a2)
            LibDraw.Line(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, r, g, b, a, 1, false, r2, g2, b2, a2)
        end
    end
end

function LibDraw.GroundCircle(x, y, z, size, r, g, b, a, thickness, rainbow, segments, r2, g2, b2, a2)
    LibDraw.Circle(x, y, z, size, r, g, b, a, thickness, rainbow, segments, r2, g2, b2, a2)
end

function LibDraw.Sphere(x, y, z, radius, r, g, b, a, thickness, rainbow, segments, r2, g2, b2, a2)
    if not x or not y or not z then return end
    if not radius or radius == 0 then return end

    local segmentCount = segments or 16

    LibDraw.Circle(x, y, z, radius, r, g, b, a, thickness, rainbow, segmentCount, r2, g2, b2, a2)

    local angleStep = (2 * pi) / segmentCount
    local points = {}
    for i = 0, segmentCount do
        local angle = i * angleStep
        local wx = x + cos(angle) * radius
        local wy = y
        local wz = z + sin(angle) * radius

        if wx and wy and wz then
            points[i] = {x = wx, y = wy, z = wz}
        end
    end

    for i = 1, segmentCount do
        local p1 = points[i - 1]
        local p2 = points[i]
        if p1 and p2 then
            LibDraw.Line(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, r, g, b, a, thickness, rainbow, r2, g2, b2, a2)
        end
    end

    points = {}
    for i = 0, segmentCount do
        local angle = i * angleStep
        local wx = x
        local wy = y + cos(angle) * radius
        local wz = z + sin(angle) * radius

        if wx and wy and wz then
            points[i] = {x = wx, y = wy, z = wz}
        end
    end

    for i = 1, segmentCount do
        local p1 = points[i - 1]
        local p2 = points[i]
        if p1 and p2 then
            LibDraw.Line(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, r, g, b, a, thickness, rainbow, r2, g2, b2, a2)
        end
    end
end

function LibDraw.Box(x1, y1, z1, x2, y2, z2, r, g, b, a, thickness, filled, rainbow, r2, g2, b2, a2)
    if not _G.WGG_Draw3DBox then return end

    local sx1, sy1, vis1 = WorldToScreen(x1, y1, z1)
    if not vis1 then return end

    local sx2, sy2, vis2 = WorldToScreen(x2, y2, z2)
    if not vis2 then return end

    r, g, b, a = ColorToFloat(r or 0, g or 255, b or 0, a or 255)
    r2, g2, b2, a2 = ColorToFloat(r2 or 0, g2 or 0, b2 or 0, a2 or 0)
    _G.WGG_Draw3DBox(sx1, sy1, 0, sx2, sy2, 0, r, g, b, a, thickness or 1, filled and 1 or 0, rainbow and 1 or 0, r2, g2, b2, a2)
end

function LibDraw.Rectangle(x, y, z, width, height, r, g, b, a, thickness, filled, rainbow, r2, g2, b2, a2)
    local x1, y1, z1 = x - width/2, y - height/2, z
    local x2, y2, z2 = x + width/2, y + height/2, z
    LibDraw.Box(x1, y1, z1, x2, y2, z2, r, g, b, a, thickness, filled, rainbow, r2, g2, b2, a2)
end

function LibDraw.Text(text, x, y, z, r, g, b, a, fontSize, outlined)
    if not text or text == "" then return end
    if not _G.WGG_Draw3DText then return end

    local sx, sy, vis = WorldToScreen(x, y, z)
    if not vis then return end

    r, g, b, a = ColorToFloat(r or 255, g or 255, b or 255, a or 255)
    _G.WGG_Draw3DText(text, sx, sy, 0, r, g, b, a, fontSize or 0, outlined and 1 or 0)
end

function LibDraw.Arc(x, y, z, size, facing, arcAngle, r, g, b, a, thickness, rainbow, segments, r2, g2, b2, a2)
    if not size or size == 0 or not arcAngle then return end
    if not x or not y or not z then return end

    local startAngle = facing - (arcAngle / 2)
    local endAngle = facing + (arcAngle / 2)
    local segmentCount = segments or 24
    local angleStep = arcAngle / segmentCount

    local points = {}
    local idx = 0
    for angle = startAngle, endAngle, angleStep do
        local wx = x + cos(angle) * size
        local wy = y + sin(angle) * size
        local wz = z

        if wx and wy and wz then
            points[idx] = {x = wx, y = wy, z = wz}
            idx = idx + 1
        end
    end

    for i = 1, idx - 1 do
        local p1 = points[i - 1]
        local p2 = points[i]
        if p1 and p2 then
            LibDraw.Line(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, r, g, b, a, thickness, rainbow, r2, g2, b2, a2)
        end
    end
end

function LibDraw.DrawMissile(index, enemyOnly)
    if not _G.WGG_DrawMissile then return end
    _G.WGG_DrawMissile(index, enemyOnly)
end

function LibDraw.DrawAllMissiles(enemyOnly)
    if not _G.WGG_DrawMissiles then return 0 end
    return _G.WGG_DrawMissiles(enemyOnly)
end

function LibDraw.GetMissileCount()
    if not _G.WGG_GetMissileCount then return 0 end
    return _G.WGG_GetMissileCount()
end

function LibDraw.GetMissileInfo(index)
    if not index or index < 1 or not _G.WGG_GetMissileWithIndex then return nil end

    local spellId, _, mx, my, mz, sourceGuid, msX, msY, msZ, targetGuid, tx, ty, tz =
        _G.WGG_GetMissileWithIndex(index)

    if not spellId or spellId == 0 then return nil end

    return {
        index = index,
        spellId = spellId,
        spellName = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId)) or "Unknown",
        position = { x = mx, y = my, z = mz },
        source = { x = msX, y = msY, z = msZ },
        target = { x = tx, y = ty, z = tz },
        sourceGuid = sourceGuid or "",
        targetGuid = targetGuid or "",
    }
end

function LibDraw.Clear()
    if _G.WGG_ClearDrawings then
        _G.WGG_ClearDrawings()
    end
end

_G.LibDraw = LibDraw
if _G.WGG_Draw3DLine and _G.WGG_Draw3DCircle and _G.WGG_W2S and _G.WGG_NDCToScreen then
else
    print("|cFFFF0000[LibDraw]|r WARNING: WGG drawing functions not available!")
end

return LibDraw
