# Architecture (Phase 1 foundation)

Engine: **Godot 4.4.x**, GDScript. Target: Windows PC first; single-player first,
co-op later. Platform-specific code will live in `platform/` (not created yet).

## Layout
| Path | Purpose |
|---|---|
| `core/` | Engine-agnostic services (autoloads): EventBus, Net, SaveSystem, GameState, Settings, SceneManager; plus `Events`, `InputActions`, `PhysicsLayers` |
| `gameplay/` | Actors, player controller, interaction, PlayerRegistry |
| `scenes/` | `boot.tscn` entry; `scenes/test/` holds the **foundation test room (harness only, not the Phase 3 ship environment)** |
| `tests/` | Headless test suites. `tools/run_tests.sh` runs them |
| `docs/` | This file and the development log |

Autoload order matters: EventBus, Net, SaveSystem, GameState, Settings, SceneManager, PlayerRegistry.

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
| Settings | Local | Never replicated |
| Scene changes | Local for now | Host-driven in Phase 7 |

## Save format
JSON at `user://saves/slot_N.json`: `{version, saved_at_unix, meta, data:{provider_key: {...}}}`.
Atomic write (temp + rename), previous save kept as `.bak` and used if the primary is corrupt,
saves from a newer version are refused, and a failed load rolls live state back.
Flag values are limited to bool/int/float/String; whole floats read back from JSON become ints.

## Physics layers
1 world, 2 interactable, 3 player, 4 enemy (see `core/physics_layers.gd`).
