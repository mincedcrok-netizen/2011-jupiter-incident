# The 2011 Jupiter Incident

First-person 3D sci-fi survival adventure / horror-comedy. Godot 4.4, GDScript.
Canon source: `2011-Jupiter-Incident-Lore-Bible.pdf`.

## Run
Open the folder in Godot 4.4+ and press Play (main scene: `scenes/boot.tscn`).
WASD move, Shift sprint, mouse look, E interact / continue dialogue, 1-6 choose, Tab archive, Esc pause or close a reader.

## Test
- `GODOT=/path/to/godot tools/run_tests.sh` headless suites (non-zero exit on any failure or script error)
- `GODOT=/path/to/godot tools/run_e2e.sh [dir] [room|ship|all]` real-window end-to-end runs with screenshots (needs a display or Xvfb; the ship run takes ~3 min under software rendering)
- `GODOT=/path/to/godot tools/restart_check.sh` persistence across separate processes

## Docs
- `docs/ARCHITECTURE.md` layout, game flow, rules, ownership and save format
- `docs/ENVIRONMENT.md` the ship deck, kit and wayfinding
- `docs/PROPOSED_LORE.md` **PROPOSED** lore awaiting approval (not canon)
- `docs/NARRATIVE_ARCHITECTURE.md` narrative systems overview
- `docs/DATA_FORMATS.md` narrative JSON formats
- `docs/CHARACTER_STANDINS.md` what is established vs PROPOSED for the crew
- `docs/DEVELOPMENT_LOG.md` phase status, what is and is not verified
