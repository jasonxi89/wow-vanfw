# Changelog / 更新日志

All notable changes to VanFW will be documented in this file.
所有 VanFW 的重要变更都记录在此文件中。

## [1.1.0] - 2026-03-10

### Fixed / 修复

- **Spells.lua**: Extracted `_executeCast()` to eliminate copy-paste across `Cast()`, `SelfCast()`, `AoECast()`
  提取 `_executeCast()` 公共方法，消除三个施法函数的重复代码

- **Core.lua**: Replaced hand-rolled JSON encoder/decoder with WGG native `JsonEncode`/`JsonDecode`
  用 WGG 原生 JSON API 替换手写的 JSON 编解码器（原版不支持数组、转义字符）

- **Core.lua**: Added `UnregisterCallback()` to allow removing registered callbacks
  新增 `UnregisterCallback()` 方法，支持移除已注册的回调（原版只能注册不能移除）

- **Core.lua**: Cleaned up unused SpellQueue dead code
  清理未使用的 SpellQueue 死代码，`ProcessSpellQueue` 简化为仅清理过期条目

- **Objects.lua**: Eliminated redundant `Exists()` + `GetToken()` double-lookup in every method
  消除每个方法中 `Exists()` + `GetToken()` 的重复查找（原版每次属性查询做两次 token 查找）

- **Objects.lua**: Added object pool to reuse Object instances instead of creating new ones each tick
  新增对象池复用机制，避免每 tick 创建新对象实例（减少 GC 压力）

- **Objects.lua**: Fixed position cache to update in-place instead of allocating new table each time
  位置缓存改为原地更新，不再每 50ms 创建新 table

- **Objects.lua**: Added `IsWorldBoss()` for strict worldboss-only check; `IsBoss()` retains original behavior (elite + rareelite + worldboss)
  新增 `IsWorldBoss()` 严格判定世界 Boss；`IsBoss()` 保持原版行为（elite + rareelite + worldboss）

- **RotationEngine.lua**: Added circuit breaker — auto-stops rotation after 10 consecutive errors
  新增熔断机制 — 连续报错 10 次后自动停止循环（防止刷屏）

- **Helpers.lua**: Replaced deprecated `GetTalentInfo(tier, column)` with `IsPlayerSpell()` for TWW compatibility
  用 `IsPlayerSpell()` 替换已废弃的 `GetTalentInfo(tier, column)`（适配 TWW 天赋系统）

- **Environment.lua**: Added missing API whitelist entries (`SpellIsTargeting`, `GetUnitSpeed`, `TargetUnit`, `debugstack`, `GetSpecialization`, `GetSpecializationInfo`, `WGG_JsonEncode`, `WGG_JsonDecode`, and more)
  补全沙箱环境缺失的 API 白名单（16 个新条目）

- **Targeting.lua**: Replaced hardcoded 6-spell CC list with comprehensive 30+ spell ID list (`COMMON_CC_DEBUFFS`)
  将硬编码的 6 个 CC 技能 ID 替换为 30+ 个全面的 CC 列表

## [1.0.0] - 2026-03-10

### Added / 新增

- Initial fork from AsohkaAIO VanFW v2.0
  从 AsohkaAIO VanFW v2.0 fork

- Framework-only extraction (no rotation scripts)
  仅提取框架部分，不含循环脚本
