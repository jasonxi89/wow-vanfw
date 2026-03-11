# Changelog

All notable changes to VanFW will be documented in this file.

## [1.2.0] - 2026-03-10

### Deprecated

- **VanKili.lua**: Removed from default load order. Hekili was killed by Blizzard's Midnight 12.0 "Secret Values" addon restrictions — real-time combat APIs (CLEU, UnitAura, etc.) are blocked inside instances. Use hand-written Rotation scripts instead.

### Note

WGG scripts are NOT affected by Midnight addon restrictions. WGG operates via memory injection, not the addon API, so `CastSpellByID`, `ObjectPos`, `GetCurrentEventInfo`, `UnitHealth` etc. all still work. Only Hekili (a normal addon) was killed.

## [1.1.1] - 2026-03-10

### Fixed

- **Targeting.lua**: Added 8 missing CC spell IDs verified via Wowhead: Sleep Walk (360806), Shackle Undead (9484), Turn Evil (10326), Mind Control (605), Dragon's Breath (31661), Gouge (1776), Quaking Palm (107079), Mass Polymorph (383121), Freezing Trap retail ID (187650). Total CC list now 47 spell IDs.

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

------

# 更新日志

所有 VanFW 的重要变更都记录在此文件中。

## [1.2.0] - 2026-03-10

### 弃用

- **VanKili.lua**: 从默认加载列表移除。Hekili 被暴雪 Midnight 12.0 的 "Secret Values" 插件限制杀死 — CLEU、UnitAura 等实时战斗 API 在副本内被封锁。请使用手写 Rotation 脚本替代。

### 说明

WGG 脚本不受 Midnight 插件限制影响。WGG 通过内存注入运行，不走暴雪插件 API，所以 `CastSpellByID`、`ObjectPos`、`GetCurrentEventInfo`、`UnitHealth` 等全部正常工作。只有 Hekili（普通插件）被杀死。

## [1.1.1] - 2026-03-10

### 修复

- **Targeting.lua**: 通过 Wowhead 验证并补充 8 个缺失的 CC 技能 ID：Sleep Walk (360806)、Shackle Undead (9484)、Turn Evil (10326)、Mind Control (605)、Dragon's Breath (31661)、Gouge (1776)、Quaking Palm (107079)、Mass Polymorph (383121)、Freezing Trap 零售版 ID (187650)。CC 列表总计 47 个技能 ID。

## [1.1.0] - 2026-03-10

### 修复

- **Spells.lua**: 提取 `_executeCast()` 公共方法，消除三个施法函数的重复代码
- **Core.lua**: 用 WGG 原生 JSON API 替换手写的 JSON 编解码器（原版不支持数组、转义字符）
- **Core.lua**: 新增 `UnregisterCallback()` 方法，支持移除已注册的回调（原版只能注册不能移除）
- **Core.lua**: 清理未使用的 SpellQueue 死代码，`ProcessSpellQueue` 简化为仅清理过期条目
- **Objects.lua**: 消除每个方法中 `Exists()` + `GetToken()` 的重复查找（原版每次属性查询做两次 token 查找）
- **Objects.lua**: 新增对象池复用机制，避免每 tick 创建新对象实例（减少 GC 压力）
- **Objects.lua**: 位置缓存改为原地更新，不再每 50ms 创建新 table
- **Objects.lua**: 新增 `IsWorldBoss()` 严格判定世界 Boss；`IsBoss()` 保持原版行为（elite + rareelite + worldboss）
- **RotationEngine.lua**: 新增熔断机制 — 连续报错 10 次后自动停止循环（防止刷屏）
- **Helpers.lua**: 用 `IsPlayerSpell()` 替换已废弃的 `GetTalentInfo(tier, column)`（适配 TWW 天赋系统）
- **Environment.lua**: 补全沙箱环境缺失的 API 白名单（16 个新条目）
- **Targeting.lua**: 将硬编码的 6 个 CC 技能 ID 替换为 30+ 个全面的 CC 列表

## [1.0.0] - 2026-03-10

### 新增

- 从 AsohkaAIO VanFW v2.0 fork
- 仅提取框架部分，不含循环脚本
