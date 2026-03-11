local VanFW = VanFW

VanFW.player = nil
VanFW.target = nil
VanFW.focus = nil
VanFW.pet = nil

function VanFW:InitializeUnits()
  self:UpdatePlayerObject()
  
  self:OnTick(function()
    self:UpdateSpecialUnits()
  end)
  
  self:Debug("Unit system initialized", "Units")
end

function VanFW:UpdatePlayerObject()
  local playerPointer = self.ObjectPointer("player")
  if playerPointer then
    self.player = VanFW.Object:New(playerPointer, "player")
  end
end

function VanFW:UpdateSpecialUnits()
  -- Update Target
  if UnitExists("target") then
    local guid = UnitGUID("target")
    self.target = self:GetObjectByGUID(guid)

    if not self.target then
      local pointer = self.ObjectPointer("target")
      if pointer then
        self.target = VanFW.Object:New(pointer, "target")
      end
    end
  else
    self.target = nil
  end

  -- Update Focus
  if UnitExists("focus") then
    local guid = UnitGUID("focus")
    self.focus = self:GetObjectByGUID(guid)

    if not self.focus then
      local pointer = self.ObjectPointer("focus")
      if pointer then
        self.focus = VanFW.Object:New(pointer, "focus")
      end
    end
  else
    self.focus = nil
  end

  -- Update Pet
  if UnitExists("pet") then
    local guid = UnitGUID("pet")
    self.pet = self:GetObjectByGUID(guid)

    if not self.pet then
      local pointer = self.ObjectPointer("pet")
      if pointer then
        self.pet = VanFW.Object:New(pointer, "pet")
      end
    end
  else
    self.pet = nil
  end
end

function VanFW:PlayerHealth()
  return self.player and self.player:Health() or 0
end

function VanFW:PlayerHealthPercent()
  return self.player and self.player:HealthPercent() or 0
end

function VanFW:PlayerPower(powerType)
  return self.player and self.player:Power(powerType) or 0
end

function VanFW:PlayerPowerPercent(powerType)
  return self.player and self.player:PowerPercent(powerType) or 0
end

function VanFW:PlayerPosition()
  if not self.player then return nil, nil, nil end
  return self.player:Position()
end

function VanFW:PlayerInCombat()
  return self.inCombat
end

function VanFW:PlayerMoving()
  return self.player and self.player:IsMoving() or false
end