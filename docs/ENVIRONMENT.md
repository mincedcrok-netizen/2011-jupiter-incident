# Ship environment (Phase 3)

Deck A is a seamless single scene, `scenes/ship/deck_a.tscn`, generated once by `tools/gen_deck_a.py`
(re-running it overwrites hand edits) and then an ordinary scene you can open and edit in Godot.

```
                       N (-z)
        [ COMMAND BRIDGE  16x14 ]            z -34..-20  (cold blue, forward window onto Jupiter)
                  | door
  [CREW QUARTERS]--[ MAIN CORRIDOR 5x40 ]--[SUPPLY ROOM]     corridor z -20..20 (cyan trim)
   amber            |                        green
                    | door (locked until released at the bridge terminal)
        [ SECTION B, damaged 5x14 ]          red emergency light, sparks, Key shards
                  | door
        [ ENGINEERING ACCESS 4x16 ]          orange, steam, pipes -> sealed ENGINE CORE door
                       S (+z)
```

## Wayfinding without a minimap
Colour-coded zones and trim; floor route lines in the corridor (blue = bridge, orange = south, amber/green
stubs to side doors); a destination sign above every doorway; "LOCATION" tag and an entry banner for each room;
door prompts that name their destination ("Open: Command Bridge", "Locked: Section B"); a red/green status light
on every door; and an objective **waypoint** (diamond marker with name and distance) that pins to the screen
edge when the target is off-screen or behind you and hides on arrival or during dialogue/readers.

## Kit (all primitives, no imported art)
| Script | Role |
|---|---|
| `ship/room_shell.gd` | Builds a room's hull + collision from `size` and `openings` (doors/windows), door signs, trim, and a room trigger; validates its layout |
| `ship/ship_door.gd` | Sliding door: locks via flag `door_unlocked:<id>`, `sealed` doors never open, will not close on the player |
| `ship/ship_prop.gd` / `ship_props.gd` | Procedural set pieces (bunks, consoles, crates, pipes, shards, signs, ...) |
| `ship/ship_interactable.gd` | Interactable with terminal/footlocker/black-box/radio/pad/crystal/crate visuals |
| `ship/flicker_light.gd` | Steady / flicker / pulse / strobe / dying lights; switches off beyond `active_distance` |
| `ship/nav_target.gd` | Named waypoint for objectives |
| `ship/space_backdrop.gd` | Star sky, fog, Jupiter with the Great Red Spot |
| `ship/ship_audio.gd`, `spatial_emitter.gd`, `ship_ambience.gd`, `ship_announcer.gd` | Sound |
| `ui/waypoint_view.gd`, `ui/location_view.gd` | Navigation HUD |

## Adding to the ship
- **New room:** add a `RoomShell` (size, openings with labels) next to an existing one so their outer faces touch; put a
  `ShipDoor` on the shared plane; the validator and `tests/test_ship_layout.gd` will tell you if openings don't fit.
- **New interactive object:** a `ShipInteractable` with an `interaction_id`; wire it to content with a `data/events` entry
  (`open_document`, `open_recording`, `start_dialogue`, `notify`, ...). No code needed. Terminals use the existing dialogue,
  document and recording systems; the environment contains no narrative logic of its own.
- **Locked door:** set `locked_by_default`, then release it with a dialogue `set_flags {"door_unlocked:<id>": true}` or an event.
- **Real art later:** replace a builder in `ship_props.gd` with a scene; placement and collision contracts stay the same
  (front faces +Z; collision on the WORLD layer; interactables on the INTERACTABLE layer).

## Audio
`tools/gen_audio.py` synthesises 13 placeholder sounds into `assets/audio/` (hum, vents, crackle, analog alarm, clanks, door
servos, PA chime, static). Replace any file with a real recording of the same name. Buses: Ambience, SFX, PA (routed to Master).
