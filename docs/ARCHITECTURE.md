# Architecture (Phase 1 foundation)

Engine: **Godot 4.4.x**, GDScript. Target: Windows PC first; single-player first,
co-op later. Platform-specific code will live in `platform/` (not created yet).

## Layout
Deliberately feature-first rather than the suggested `scripts/` mirror tree: each system's
script sits next to its scene/data, which keeps related files together and scripts small.
| Path | Purpose |
|---|---|
| `core/` | Autoload services: EventBus, Net, SaveSystem, GameState, GameManager, Settings, SceneManager; plus `Events`, `InputActions`, `PhysicsLayers` |
| `gameplay/` | Actors, player controller + scene, interaction, PlayerRegistry |
| `narrative/` | Narrative data classes, `NarrativeDatabase`, `NarrativeState`, `DialogueManager`, `EventDirector`, `RecordingPlayer` (see `docs/NARRATIVE_ARCHITECTURE.md`) |
| `ship/` | Environment kit: `RoomShell`, `ShipDoor`, props/interactables, lights, nav targets, space backdrop, audio (see `docs/ENVIRONMENT.md`) |
| `ui/` | HUD (crosshair, prompt, objective waypoint, location tag), pause menu, and the narrative interface (`narrative_ui.gd` + dialogue/recording/document/archive/objectives/toast views, `retro_style.gd`) |
| `scenes/` | `boot.tscn` entry (loads `scenes/ship/deck_a.tscn`); `scenes/core/gameplay_scene.gd` (root script for playable scenes); `scenes/test/` = **foundation test room (harness only, not the Phase 3 ship)** |
| `data/` | Narrative JSON: `characters/` (proposed crew stand-ins) plus `dialogue/ recordings/ documents/ events/` (demo content, `canon: test`, debug builds only) |
| `assets/` | `models/ textures/ audio/ materials/` (empty; created for later phases) |
| `tests/` | Headless suites, rendered end-to-end drivers (`e2e_rendered.gd` room, `e2e_ship.gd` ship), two-process restart check, fixtures |
| `tools/` | `run_tests.sh`, `run_e2e.sh`, `restart_check.sh`, `gen_deck_a.py` (level), `gen_audio.py` (placeholder sounds) |
| `docs/` | Architecture, data formats, development log |

No `resources/` folder yet (nothing needs it). Autoload order matters: EventBus, Net,
SaveSystem, GameState, GameManager, Settings, SceneManager, PlayerRegistry, NarrativeDatabase, NarrativeState, DialogueManager, EventDirector, NarrativeUI.

## Game flow
`boot.tscn` -> `SceneManager.change_scene(first_scene)` (on failure: on-screen message + error log)
-> a scene whose root uses `GameplayScene` calls `GameManager.enter_gameplay()` (state PLAYING,
mouse captured). Esc toggles pause (`tree.paused`, mouse released, pause menu shown); losing window
focus pauses; leaving the scene while paused unpauses. `GameManager.report_error()` is the central
non-fatal error log (capped, published as an event). Mouse capture policy lives only in GameManager.

## Input
Actions are registered in code (`InputActions`) and are rebindable with persistence
(`Settings.set_binding`): invalid keys, unknown actions and keys already used by another action are refused.
Defaults: WASD, Shift sprint, E interact, Tab archive, Esc pause (Esc first closes an open reader). Mouse sensitivity and invert-Y are settings.

## Rules every system follows
1. **No singletons for "the player".** Use `PlayerRegistry` (keyed by peer id). Enemies/hazards target via `PlayerRegistry.nearest_to()`.
2. **Ask `Net.is_authority()`**, never the multiplayer API directly. Single-player is "host with one local peer".
3. **Input goes through `PlayerInput`.** `Player` never reads global `Input` directly, so remote players can be fed state later.
4. **Events over direct calls.** Publish on `EventBus` using constants from `core/events.gd`.
5. **State is serializable.** Persistent systems register a provider (`serialize/deserialize/reset`) with `SaveSystem`.

## Ownership (who may change what)
| System | Owner | Notes |
|---|---|---|
| Story flags (`GameState`) | Authority | Non-authority `set_flag` is refused |
| Saves (`SaveSystem`) | Authority | Host writes campaign saves |
| Interactions (`Interactable`) | Authority performs | Remote requests are **not implemented** (Phase 7); they are refused with a warning |
| Player movement/camera | The controlling peer | Remote players are not simulated locally |
| Narrative state/events (`NarrativeState`, `EventDirector`, `DialogueManager`) | Authority | Mutators refuse on non-authority peers; views are local |
| Doors (`ShipDoor`) | Authority performs | Lock state = story flag; open/closed state is local and not saved |
| Pause / mouse capture / modals (`GameManager`) | Local | Co-op must not freeze the host's simulation; revisit in Phase 7 |
| Narrative data (`NarrativeDatabase`) | Read-only everywhere | Unlocking recordings is authority-only (stored as flags) |
| Settings | Local | Never replicated |
| Scene changes | Local for now | Host-driven in Phase 7 |

## Save format
JSON at `user://saves/slot_N.json`: `{version, saved_at_unix, meta, data:{provider_key: {...}}}`.
Atomic write (temp + rename), previous save kept as `.bak` and used if the primary is corrupt,
saves from a newer version are refused, and a failed load rolls live state back.
Flag values are limited to bool/int/float/String; whole floats read back from JSON become ints.

## Physics layers
1 world, 2 interactable, 3 player, 4 enemy (see `core/physics_layers.gd`).
