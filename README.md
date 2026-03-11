# VanFW - WGG Scripting Framework

Improved fork of VanFW v2.0. Framework only — bring your own rotations.

## Quick Start

```
1. Download or clone this repo
2. Copy everything to C:\WGG\
3. In-game press F3 to load
4. Click the on-screen button (or /rot) to toggle rotation
```

## Writing a Rotation

Create `Rotations/{CLASS}/{Spec}.lua`. The framework auto-detects your class/spec and loads the matching file.

### Minimal Example

```lua
local function WaitForVanFW(callback)
    if VanFW and VanFW.loaded then callback()
    else C_Timer.After(0.5, function() WaitForVanFW(callback) end) end
end

WaitForVanFW(function()
    -- 1. Define spells
    local Kick = VanFW:CreateSpell(123456, {name = "My Spell"})

    -- 2. Write rotation function
    local function MyRotation()
        local target = VanFW.target
        if not target or not target:exists() or target:dead() then return end

        if Kick:Castable(target) then
            Kick:Cast(target)
        end
    end

    -- 3. Register
    VanFW.Rota = {
        Start = function() VanFW:StartRotation(MyRotation, 0.075) end,
        Stop  = function() VanFW:StopRotation() end,
    }
end)
```

## Spell API

```lua
-- Create
local spell = VanFW:CreateSpell(spellID, {
    name = "Spell Name",
    priority = 5,              -- 1=highest, 10=lowest
    castMethod = 'auto',       -- 'auto', 'id', or 'name'
})

-- Check & Cast
spell:Castable(target)         -- checks known + usable + CD + range + LoS
spell:Cast(target)             -- cast on target
spell:SelfCast()               -- cast on self
spell:AoECast(target)          -- ground-target AoE (auto-clicks position)
spell:AoECast(x, y, z)        -- ground-target AoE at coordinates

-- Query
spell:Cooldown()               -- seconds remaining
spell:IsReady()                -- CD <= GCD
spell:IsKnown()                -- learned?
spell:IsUsable()               -- has resources?
spell:Charges()                -- current, max
spell:InRange(target)          -- within range?
```

## Object / Unit API

```lua
local player = VanFW.player
local target = VanFW.target

-- Health
target:hp()                    -- health percent (0-100)
target:Health()                -- current health
target:HealthMax()             -- max health

-- Position & Distance
target:Position()              -- x, y, z
target:Distance()              -- yards from player
target:DistanceTo(other)       -- yards between two objects

-- Status
target:exists()
target:dead()
target:enemy()
target:combat()
target:IsMoving()
target:IsBoss()                -- elite/rareelite/worldboss
target:IsWorldBoss()           -- worldboss only

-- Auras
target:HasBuff(spellID)        -- bool, stacks, remaining
target:BuffRemaining(spellID)  -- seconds
target:HasDebuff(spellID)
target:DebuffRemaining(spellID)

-- Casting
target:casting()               -- is casting?
target:channeling()            -- is channeling?
target:castint()               -- is interruptible?
```

## Framework Utilities

```lua
-- GCD
VanFW:GetGCD()                 -- GCD remaining
VanFW:IsGCDActive()            -- bool

-- Combat
VanFW:PlayerInCombat()
VanFW:TimeInCombat()

-- Enemies
VanFW.objects.enemies          -- table of enemy objects in range
VanFW:IsAOESituation(count, range)

-- Callbacks
VanFW:RegisterCallback("onTick", func)
VanFW:RegisterCallback("onCombatStart", func)
VanFW:RegisterCallback("onCombatEnd", func)
VanFW:RegisterCallback("onTargetChanged", func)
VanFW:UnregisterCallback("onTick", func)

-- Config (encrypted, persisted to C:\WGG\cfg\)
VanFW:SaveRotationConfig("CLASS", "Spec", "Name", configTable)
VanFW:LoadRotationConfig("CLASS", "Spec", "Name")
```

## Boss Awareness (WGG Native)

No DBM/BigWigs required. Uses WGG memory reads directly.

```lua
local BA = VanFW.BossAware

-- Unified threat check
local threat, reason = BA:GetThreatLevel()
-- "MOVE_NOW"   standing in ground effect
-- "MOVE_SOON"  missile incoming < 1.5s
-- "INTERRUPT"  boss interruptible cast < 2s
-- "DEBUFF"     dangerous debuff on player
-- "SAFE"       all clear

-- Individual checks
BA:IsStandingInBad()           -- in AreaTrigger?
BA:IsMissileIncoming()         -- projectile aimed at you?
BA:CanInterruptBoss()          -- bool, remaining seconds
BA:HasDangerousDebuff()        -- harmful aura on player?
BA:ShouldMove()                -- bad OR missile
BA:GetBossCast()               -- {isCasting, canInterrupt, remaining, spellId, spellName}
```

## DBM Integration (Optional)

Works if player has DBM installed. Falls back gracefully if not.

```lua
local DBMI = VanFW.DBM
if DBMI and DBMI:IsAvailable() then
    DBMI:IsBigDamageIncoming(3)      -- big hit within 3s?
    DBMI:ShouldSaveCooldowns(10)     -- phase transition in 10s?
    DBMI:GetTimerBySpellId(12345)    -- remaining, timerData
    DBMI:InEncounter()               -- in boss fight?
end
```

## Commands

| Command | Action |
|---------|--------|
| `/rot` | Toggle rotation on/off |
| `/rot start` | Start rotation |
| `/rot stop` | Stop rotation |
| `/rot status` | Show status |
| `/vanfw debug` | Toggle debug output |
| `/mcp status` | Logger statistics |

## File Structure

```
C:\WGG\
├── Init.lua                    # Entry point (F3 to load)
├── VanFW/
│   ├── Core.lua                # GCD, combat state, callbacks, config
│   ├── Objects.lua             # Object manager + object pool
│   ├── Units.lua               # player/target/focus/pet
│   ├── Spells.lua              # Spell system (cast/CD/range/LoS)
│   ├── RotationEngine.lua      # OnUpdate loop + circuit breaker
│   ├── Targeting.lua           # Smart target selection + CC detection
│   ├── BossAwareness.lua       # AreaTrigger/Missile/Cast detection
│   ├── DBMIntegration.lua      # Optional DBM hooks
│   ├── MCP.lua                 # Combat logger (JSON export)
│   ├── ToggleButton.lua        # On-screen start/stop button
│   ├── Helpers.lua             # HasTalent, AoE position, interrupts
│   ├── Environment.lua         # Sandbox whitelist
│   ├── Draw.lua                # 2D/3D drawing
│   ├── GUI.lua                 # UI components
│   └── ...
├── Rotations/
│   ├── WARLOCK/Affliction.lua  # Affliction Warlock PVE
│   ├── MONK/Brewmaster.lua     # Brewmaster Monk Tank
│   └── Utility/AutoTarget.lua
├── MCP/
│   └── server.py               # Python MCP server for log analysis
└── Libs/
    └── LibDraw.lua
```

## Midnight 12.0 Compatibility

WGG scripts are **not affected** by Blizzard's Midnight addon restrictions. WGG reads memory directly, bypassing the addon API sandbox. All spell casting, object positions, aura data, and combat events work normally inside instances.

| Feature | Normal Addons (12.0) | WGG Scripts |
|---------|---------------------|-------------|
| CastSpellByID | Blocked | Works |
| UnitHealth/Aura | Secret Values | Works |
| CLEU in instances | Blocked | Works |
| Object positions | Not available | Works |
| AreaTrigger data | Not available | Works |
