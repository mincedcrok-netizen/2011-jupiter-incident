# Narrative architecture (Phase 2)

```
 data/*.json --load/validate--> NarrativeDatabase (read-only)
                                      |
 world (Interactable, NarrativeTrigger, SceneManager, ...) --EventBus events--+
                                      v                                       |
                               EventDirector --runs actions--> NarrativeState / DialogueManager / GameState
                                                                      |                  |
                                                       EventBus events (state changes)   +--> SaveSystem providers
                                                                      v
                                                    NarrativeUI (dialogue box, readers, archive, HUD, toasts)
```

| System | File(s) | Responsibility |
|---|---|---|
| NarrativeDatabase | `narrative/narrative_database.gd` | Loads + validates characters, dialogue, recordings, documents, events; cross-reference warnings; hides `test` content in release |
| Entry classes | `narrative/*_entry.gd`, `dialogue_sequence.gd`, `narrative_event.gd` | One validated data class per kind (`from_dict`) |
| GameState | `core/game_state.gd` | Story flags: decisions, discoveries, statuses, completed objectives/dialogue (the single condition store) |
| NarrativeState | `narrative/narrative_state.gd` | Found/played recordings, found/read documents, character states, objectives, completed events |
| DialogueManager | `narrative/dialogue_manager.gd` | Runs a dialogue graph: conditions, choices, flags, loop guard; holds the player in a modal |
| EventDirector | `narrative/event_director.gd` | Executes data-defined events on any EventBus trigger |
| RecordingPlayer | `narrative/recording_player.gd` | Timed transcript playback |
| NarrativeUI | `ui/narrative_ui.gd` + `ui/*_view.gd` | Presentation only; Tab = archive |
| NarrativeTrigger | `gameplay/interaction/narrative_trigger.gd` | Area3D that publishes `area_entered` for environmental storytelling/encounters |

## Persistence
`SaveSystem` writes one section per provider. Narrative progress is in two: `game_state` (all flags,
which already include discoveries, reads, character states, decisions, completed dialogue) and
`narrative` (objective list with order/text/completion, completed one-shot events). Loading validates
each section, rolls everything back on a bad one, resets a section that is absent (old saves), and aborts
any dialogue in progress. A conversation in progress is deliberately not saved.

## Co-op readiness
All narrative state mutators are authority-only and the EventDirector only runs on the authority, so the
host decides story. Progress is plain flags + a small provider, which is what will be replicated. Views are
local presentation. Not done yet (Phase 7): replicating state to clients, per-player UI state for shared
conversations, and what "modal" means when the world keeps running for other players.

## Adding content
Drop JSON in `data/<kind>/`, set `canon` honestly (`proposed` for anything new), run `tools/run_tests.sh`
(the shipped-data test fails on any invalid entry or dangling reference). Wire it to the world with an
`events` entry; no code is needed for new conversations, recordings, documents or triggers.
