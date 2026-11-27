# Development log

## Phase 0: audit (done)
Repo contained only the README and the Lore Bible PDF. Decisions approved: Godot 4;
original archetype stand-in characters; campaign set during the 2011 siege (2012-2024 via
found footage); proposed lore must be marked `PROPOSED` and approved before use.

## Phase 1: technical foundation (done, approved)

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

## Phase 2: narrative foundation (done, approved)

### Delivered
Dialogue graphs with conditions/choices/flag effects; character profiles with voice, relationships and
progression states; recordings (cassette / dashcam / black-box) with timed transcript playback; five
document kinds with a reader; data-defined events (interaction, area trigger, flag change, dialogue end,
scene entry, ...); objectives; story-flag-backed discovery/read tracking; save/load of all narrative progress;
and a retro-styled interface (dialogue box, recording player, document reader, archive on Tab, objectives
HUD, toasts). See `docs/NARRATIVE_ARCHITECTURE.md`.

### Decisions made while building (flagged for review)
- **Characters are the approved original stand-ins**, not named real people (Phase 0 decision #2), even though the Phase 2 brief names the real people. All names/voices/relationships are PROPOSED (`docs/CHARACTER_STANDINS.md`).
- The Phase 1 linear-lines dialogue format and its cassette/dashcam/report/personal-record recording kinds were **replaced** (nothing consumed them): dialogue is a node graph, recordings use timed segments, and reports/notes moved to the document system.
- `EventBus` gained permanent subscriptions so system listeners survive `clear()`.
- Demo content is `canon: "test"` and is excluded from release builds. No Section 4 or Zero-G material was written; nothing here defines an unresolved mystery or a character outcome.

### How it was verified (cold `.godot` cache)
| Check | Result |
|---|---|
| Headless suites, 572 checks (data validation, dialogue, state, events, recording player, UI behaviour + layout, saves) | 0 failed, no script errors |
| Rendered playthrough in a real window, real key presses, screenshots, 73 checks (talk, choose, conditional re-visit, terminal, archive, recording, document, area trigger, save, wipe, load, pause) | 0 failed |
| Fresh-process persistence (settings, rebinding, flags, recordings, documents, character state, objectives, completed events) + negative control | OK |
| Mutation checks: dialogue ignoring conditions, saves dropping events, events ignoring conditions, zero-size overlay bug | each caught |
| Full logs of the real main scene (windowed + headless) | no game errors |

Bugs found by looking at screenshots / hostile tests and fixed: all overlays had zero size
(`set_anchors_preset` vs `set_anchors_and_offsets_preset`), toasts hidden behind reader panels,
HUD prompt ghosting through modals, `set_flag` crash when a flag changed type (Phase 1 code, fixed then).

### NOT verified
- **Windows**, **Forward+ renderer**, **performance**, **audio** (no audio files exist; the audio path is only tested for the missing-file fallback), **real mouse feel**, and the **Godot editor UI** (all as in Phase 1).
- Fonts: the retro look relies on a system monospace font; on a machine without one it will fall back to Godot's default font.
- The look is placeholder: scanlines and neon-green panels, no VHS distortion, chromatic aberration or CRT curvature (Phase 8).

### Known limitations
- Content: only the four crew profiles and clearly marked demo content exist; no campaign dialogue/recordings/documents, no Section 4 / Zero-G proposals yet.
- A conversation in progress is not saved (a load discards it). No mid-conversation autosave/skip/backlog/history.
- Choice keys 1-6 are fixed (not rebindable); no settings screen for key bindings.
- Dialogue text has no flag interpolation, no portraits or per-line mood, and no localisation.
- Recording corruption effects (the O. Algo text/audio glitching) are not implemented; corrupted segments are just text.
- Toasts overlap the right edge of reader panels on narrow windows; no gamepad support in any view.
- Co-op: state is authority-only and flag-based (replication-ready), but nothing is networked; per-player UI state for shared conversations is undecided.
- Event data can reference ids that do not exist; this is warned at load and reported at runtime, not blocked.

## Phase 3: playable environment (implemented and tested; awaiting approval)

### Delivered
A seamless Deck A vertical slice (`scenes/ship/deck_a.tscn`): main corridor, command bridge, crew quarters, supply room,
damaged Section B, engineering access corridor with a sealed engine core door. Procedural kit (room shells, doors, props,
interactables, flicker/emergency lights, star sky + Jupiter), 13 synthesized placeholder sounds with positional ambience,
PA announcements and door/console sounds, wayfinding (colour zones, floor route lines, door signs, location tag, objective
waypoint), and 21 data-driven narrative events wiring every terminal, footlocker, recorder and door to the Phase 2 dialogue,
document, recording, event and objective systems. No new dialogue/document/recording system was created.
See `docs/ENVIRONMENT.md`.

### Decisions made while building (flagged for review)
- **Characters stay the approved original stand-ins.** The Phase 3 brief asks for the four real-person names; I did not write
  fiction in real people's names. Every in-world mention resolves through character ids (`{name:commander}`, `{callsign:...}`)
  from `data/characters/crew.json`, so names live in exactly one file. Please confirm the stand-ins or decide otherwise.
- **PROPOSED lore is separate** (`docs/PROPOSED_LORE.md`): Zero-G hazard, layout conventions, lead-lined shelters. The Zero-G
  hazard is not implemented anywhere and a test fails if shipped text mentions it. That document also **corrects an earlier
  claim of mine**: Section 4 is not blank; the Zero-G description and the ship layout are what the Lore Bible lacks.
- Phase 2 formats were extended, not replaced: `set_objective` gained an optional `target`; text gained `{name:id}` tokens;
  `Interactable` gained an `_on_interacted` hook; `PlayerInteractor` republishes the prompt after use.
- Level is generated by `tools/gen_deck_a.py` into a normal scene; regeneration overwrites hand edits.
- Boot now starts on the ship; the Phase 1/2 test room is still covered by its own rendered run.
- Two dead events were removed after testing showed they could never fire.

### How it was verified (cold `.godot` cache)
| Check | Result |
|---|---|
| Headless suites, 1145 checks (Phase 1+2 unchanged, plus 3: layout/validation, doors, physics navigation incl. a capsule flood-fill proving every room, interactable and waypoint is reachable, narrative integration, lighting/audio/backdrop/HUD) | 0 failed |
| Rendered ship walkthrough, 67 checks: real key presses boot the game, walk the corridor, open every door, use terminals/dialogue, play the black box, read documents, trigger Section B, meet the sealed door, archive, pause, save/wipe/load | 0 failed |
| Phase 1/2 rendered room run (regression), 73 checks | 0 failed |
| Two-process restart persistence + negative control | OK |
| Audio mixer carries signal on the Ambience bus (dummy driver); no errors recorded during the walkthrough | OK |

Bugs found by testing/screenshots and fixed: low interactables could not be focused at normal eye height (focus volumes enlarged);
ambience crashed when no current scene existed; steam rendered as hard squares; signs overflowed their plates; a redundant sign
overlapped a door label; the corridor drew 618 calls (now 266 with distance culling); plus several test-driver mistakes.

### NOT verified
- **Windows**, **Forward+ renderer**, and the **Godot editor UI** (as before).
- **Real frame rate.** Software GL (llvmpipe) runs the slice at roughly 10-25 fps at 640x360; that says nothing about a GPU.
  Measured scene cost (software run): ~270 draw calls and ~385 objects at the heaviest viewpoint, 510 meshes, 2 shadowed lights max.
- **Hearing the audio.** Placeholder sounds are verified to load, loop, route to buses and produce mixer signal, not judged by ear.
- **Real mouse feel**, and how comfortable low-object targeting is for a real player.
- Visual taste: placeholder primitives with a consistent look, no real models/textures, no VHS/CRT post-process (Phase 8).

### Known limitations
- Primitive geometry and procedural audio; no voice acting (PA is caption + chime).
- No occlusion culling (Compatibility renderer): large worlds will need portals/room streaming; distance culling is used now.
- Door open/closed state and the PA/ambience timers are not saved; doors reset to closed when the scene reloads.
- Nothing resolves any lore mystery; Key shards are visual only; the engine core is a sealed door with no source named.
- No enemies, hazards (radiation, decompression, Zero-G, corrupted-terminal puzzles), scavenging or repair; the slice ends at the sealed engine core door.
- Single-player only; doors/triggers are authority-gated but nothing is networked.
- `RoomShell` assumes axis-aligned rectangular rooms.
