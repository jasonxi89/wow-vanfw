# Changelog

All notable changes to VanFW will be documented in this file.

## [1.1.0] - 2026-03-10

### Fixed
- **Spells.lua**: Extracted `_executeCast()` to eliminate copy-paste across `Cast()`, `SelfCast()`, `AoECast()`
- **Core.lua**: Replaced hand-rolled JSON encoder/decoder with WGG native `JsonEncode`/`JsonDecode`
- **Core.lua**: Added `UnregisterCallback()` to allow removing registered callbacks
- **Core.lua**: Cleaned up unused SpellQueue dead code
- **Objects.lua**: Eliminated redundant `Exists()` + `GetToken()` double-lookup in every method
- **Objects.lua**: Added object pool to reuse Object instances instead of creating new ones each tick
- **Objects.lua**: Fixed position cache to update in-place instead of allocating new table each time
- **Objects.lua**: Added `IsWorldBoss()` for strict worldboss-only check; `IsBoss()` retains original behavior (elite + rareelite + worldboss)
- **RotationEngine.lua**: Added circuit breaker — auto-stops rotation after 10 consecutive errors
- **Helpers.lua**: Replaced deprecated `GetTalentInfo(tier, column)` with `IsPlayerSpell()` for TWW compatibility
- **Environment.lua**: Added missing API whitelist entries (`SpellIsTargeting`, `GetUnitSpeed`, `TargetUnit`, `debugstack`, `GetSpecialization`, `GetSpecializationInfo`, `WGG_JsonEncode`, `WGG_JsonDecode`, and more)
- **Targeting.lua**: Replaced hardcoded 6-spell CC list with comprehensive 30+ spell ID list (`COMMON_CC_DEBUFFS`)

## [1.0.0] - 2026-03-10

### Added
- Initial fork from AsohkaAIO VanFW v2.0
- Framework-only extraction (no rotation scripts)
