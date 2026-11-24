# Development log

## Phase 0: audit (done)
Repo contained only the README and the Lore Bible PDF. Decisions approved: Godot 4;
original archetype stand-in characters; campaign set during the 2011 siege (2012-2024 via
found footage); proposed lore must be marked `PROPOSED` and approved before use.

## Phase 1: technical foundation (implemented and tested; awaiting approval)

### Delivered
Core services (EventBus, Net authority shim, GameState flags, SaveSystem, Settings with
rebindable/persistent keys, SceneManager, GameManager with pause + mouse policy + error log),
PlayerRegistry, first-person Player with per-player input, interaction framework, HUD
(crosshair + prompt), pause menu, enclosed foundation test room, narrative DATA architecture
(validated dialogue + recording formats, `NarrativeDatabase`, unlock-as-flag), boot-failure handling.

### How it was verified
| Check | Command | Result |
|---|---|---|
| Headless suites (249 checks) | `GODOT=... tools/run_tests.sh` | 0 failed, no script errors |
| Real window + software GL, synthetic keyboard/mouse through the engine input pipeline, screenshots (28 checks) | `GODOT=... tools/run_e2e.sh` | 0 failed |
| Fresh-process persistence (settings, key rebind, save, unlocked recording) + negative control | `GODOT=... tools/restart_check.sh` | OK |
| Cold start (`.godot` deleted) import + main scene, windowed and headless; full log read | manual | no game errors/warnings |

Bugs found by these tests and fixed during Phase 1: keycode validator accepted arbitrary
integers; `StringName` sort was not alphabetical (unstable unlock ordering); HUD crashed on a
non-string prompt payload; `GameState.set_flag` crashed when a flag changed type;
`is_unlocked` could error on a wrongly-typed flag from a hand-edited save; `DirAccess` on a
missing data folder logged an engine error every launch.

### NOT verified
- **Windows.** Everything ran on Linux. Save-file replacement (rename over existing) and window/fullscreen behavior need a Windows run.
- **Forward+ renderer.** The project is configured for Forward+, which needs Vulkan; the sandbox has none, so all rendered runs used the Compatibility renderer (OpenGL, llvmpipe). Renderer choice is an open decision (see below).
- **Performance** (software rendering says nothing about frame rate), **audio output**, **real mouse hardware feel** (sensitivity tuning), and **fullscreen/resolution switching** (`Settings.apply_all` is skipped headless; windowed run used defaults only).
- Opening the project in the Godot **editor UI** (verified via CLI import and runtime only).

### Known limitations
- Remote interaction requests are refused until Phase 7; only the Master audio bus is applied.
- No dialogue runner/UI, collectible log UI, mission system, or in-world recording pickups (Phase 2). The data pipeline is real; shipped `data/` is empty and tests use fixtures.
- No settings UI; rebinding is API-only. Key conflicts are refused rather than swapped.
- Focus-loss pause relies on the OS delivering the focus notification (not testable headless beyond calling the handler).
- SceneManager loads synchronously; no loading screen.
- The foundation room is a test harness with primitive geometry.
- Exported builds must include `*.json` under `data/` (Phase 8).
