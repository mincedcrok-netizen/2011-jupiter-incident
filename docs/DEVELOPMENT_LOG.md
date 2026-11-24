# Development log

## Phase 0: audit (done)
Repo contained only the README and the Lore Bible PDF. Decisions approved: Godot 4;
original archetype stand-in characters; campaign set during the 2011 siege (2012-2024 via
found footage); proposed lore must be marked `PROPOSED` and approved before use.

## Phase 1: technical foundation (implemented, tested headless)
Delivered: EventBus, Net authority shim, GameState flags, SaveSystem, Settings,
InputActions, SceneManager, PlayerRegistry, Actor/Player/PlayerInput, Interactable +
PlayerInteractor, boot scene and a foundation test room, 123-check headless test suite.

### Verified (headless, Godot 4.4.1, Linux)
Run `GODOT=/path/to/godot tools/run_tests.sh`. Covers normal and invalid input for every
core service, save corruption/backup/rollback/version refusal, scene-change failure paths,
player gravity/movement/sprint/pitch clamp, remote-player isolation, interaction focus,
one-shot persistence through save/load, and wall occlusion.

### NOT verified yet
- Anything visual or real-time: rendering, mouse-look feel, mouse capture, window/fullscreen
  switching (`Settings.apply_all` is skipped in headless), audio output.
- Windows behavior, including save-file replacement via rename. Needs a run on Windows.
- Any real networking. Only the shim and the authority/ownership rules exist.

### Known limitations
- Remote interaction requests are refused until Phase 7.
- Only the Master audio bus is applied; other volumes are stored for the Phase 8 bus layout.
- SceneManager loads synchronously (no loading screen yet).
- The foundation room is a test harness, not game content.
