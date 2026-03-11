local VanFW = VanFW or {}


VanFW.hasWGG = false

local function CheckWGGAPI()
  if not _G.WGG_GetObjectCount then
    return false
  end
  return true
end

VanFW.hasWGG = CheckWGGAPI()

if not VanFW.hasWGG then
  error("[VanFW] WGG API not found! Framework cannot load.")
  return
end


VanFW.GetObjectCount = _G.WGG_GetObjectCount
VanFW.GetObjectWithIndex = _G.WGG_GetObjectWithIndex
VanFW.ObjectType = _G.WGG_ObjectType
VanFW.ObjectGUID = _G.WGG_ObjectGUID
VanFW.ObjectToken = _G.WGG_ObjectToken
VanFW.ObjectPointer = _G.WGG_Object
VanFW.ObjectPos = _G.WGG_ObjectPos or _G.ObjectPosition
VanFW.GetFacing = _G.WGG_GetFacing
VanFW.SetFacing = _G.WGG_SetFacing
VanFW.GetPlayerPosition = _G.WGG_GetPlayerPosition
VanFW.GetTargetPosition = _G.WGG_GetTargetPosition
VanFW.ObjectDistance = _G.WGG_ObjectDistance
VanFW.ObjectCombatReach = _G.WGG_ObjectCombatReach
VanFW.ObjectBoundingRadius = _G.WGG_ObjectBoundingRadius
VanFW.ObjectHeight = _G.WGG_ObjectHeight
VanFW.Click = _G.WGG_Click
VanFW.ObjectInteract = _G.WGG_Click
VanFW.VisCheck = _G.WGG_VisCheck or _G.TraceLine
VanFW.TraceLine = VanFW.VisCheck
VanFW.W2S = _G.WGG_W2S
VanFW.NDCToScreen = _G.WGG_NDCToScreen
VanFW.WorldToScreen = function(wX, wY, wZ)
  local ndcX, ndcY, visible = VanFW.W2S(wX, wY, wZ)
  if not visible or visible == 0 or not ndcX or not ndcY then
    return false, false, false
  end
  local px, py = VanFW.NDCToScreen(ndcX, ndcY)
  return px, py, true
end

if not _G.WorldToScreen then
  _G.WorldToScreen = VanFW.WorldToScreen
end

VanFW.CameraPosition = _G.WGG_CameraPosition
VanFW.ObjectCastingTarget = _G.WGG_ObjectCastingTarget
VanFW.ObjectTarget = _G.WGG_ObjectTarget
VanFW.ObjectMovementFlag = _G.WGG_ObjectMovementFlag
VanFW.ObjectSpecID = _G.WGG_ObjectSpecID
VanFW.LOSFlags = {
  Standard = 0x111,
  LineOfSight = 0x111,
  Collision = 0x1,
  Liquid = 0x10,
  Model = 0x100,
  NoCollision = 0x110,
  AllFlags = 0x111,
}


function VanFW:QuickDistance(obj1, obj2)
  if not obj1 or not obj2 then return 999 end

  local ptr1 = obj1.pointer or obj1
  local ptr2 = obj2.pointer or obj2

  if not ptr1 or not ptr2 then return 999 end

  return self.ObjectDistance(ptr1, ptr2) or 999
end

function VanFW:QuickLoS(x1, y1, z1, x2, y2, z2, flags)
  flags = flags or self.LOSFlags.Standard
  local result = self.VisCheck(x1, y1, z1 + 2, x2, y2, z2 + 2, flags)
  -- WGG_VisCheck returns:
  --   0.0 = HIT (blocked, no LoS)
  --   1.0 = CLEAR (no hit, has LoS)
  return result == 1
end

function VanFW:FacingToPosition(fromX, fromY, toX, toY)
  return math.atan2(toY - fromY, toX - fromX)
end

function VanFW:FacePosition(x, y)
  local px, py = self.GetPlayerPosition()
  if not px or not x then return false end

  local angle = self:FacingToPosition(px, py, x, y)
  self.SetFacing(angle)
  return true
end

function VanFW:FaceObject(object)
  local x, y, z = object:Position()
  if not x then return false end

  return self:FacePosition(x, y)
end

local function VerifyAPI()
  local required = {
    "GetObjectCount",
    "GetObjectWithIndex",
    "ObjectType",
    "ObjectGUID",
    "ObjectToken",
    "ObjectPos",
    "GetFacing",
    "ObjectDistance",
    "Click",
    "VisCheck",
  }

  local missing = {}

  for _, funcName in ipairs(required) do
    if not VanFW[funcName] then
      table.insert(missing, funcName)
    end
  end

  if #missing > 0 then
    print("|cFFFF0000[VanFW] Missing WGG functions:|r")
    for _, func in ipairs(missing) do
      print("  - " .. tostring(func))
    end
    return false
  end

  return true
end

if not VerifyAPI() then
  error("[VanFW] Critical WGG API functions missing!")
end
