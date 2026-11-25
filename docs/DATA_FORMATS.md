# Narrative data formats

Each file under `data/<kind>/*.json` is a JSON **array** of entry objects. Kinds: `characters`,
`dialogue`, `recordings`, `documents`, `events`. Invalid entries are skipped and reported
(`NarrativeDatabase.load_errors` and `GameManager.recent_errors()`); duplicate ids keep the first.
Dangling references (unknown speaker, unknown id in an event action, ...) load with a warning.

## Common fields
- `id` (string, unique per kind)
- `canon`: `"established"` (from the Lore Bible), `"proposed"` (new, awaiting approval),
  or `"test"` (demo/fixture content). **`test` entries are ignored unless
  `NarrativeDatabase.include_test_content` is true (default: debug builds only), so demo content cannot ship.**

## Characters
```json
{"id": "commander", "canon": "proposed", "display_name": "...", "callsign": "optional",
 "role": "...", "description": "...", "personality": ["..."],
 "voice": {"style": "how they talk", "quirks": ["..."]},
 "relationships": [{"with": "other_character_id", "note": "..."}],
 "signature_gear": "optional", "states": ["aboard", "..."], "initial_state": "aboard",
 "canonical_status": "optional Lore Bible end-state text", "color": "#rrggbb"}
```
`states` are the progression states a character can be in; the current one is stored by
`NarrativeState` (default = `initial_state`). `voice` is the character's dialogue profile.

## Dialogue (a graph of nodes)
```json
{"id": "...", "canon": "proposed", "start": "node_id",
 "nodes": {"node_id": {
    "speaker": "character_id | narrator | system", "text": "...",
    "requires": ["flag"], "excludes": ["flag"],
    "set_flags": {"flag": true},
    "next": "other_node | empty to end",
    "choices": [{"text": "...", "next": "node", "requires": [], "excludes": [], "set_flags": {}}]}}}
```
- A node with `choices` (1-6) waits for the player; it cannot also have `next`.
- `requires` / `excludes` are story-flag conditions (truthy test). A node whose conditions fail is
  **skipped** (continues to its `next`); a choice whose conditions fail is **hidden**. To branch
  "first visit vs return visit", chain `returning(requires met) -> first(excludes met) -> ...`.
- `set_flags` run when the node is shown / the choice is picked. Values: bool, number, string.
- Finishing sets `dialogue_completed:<id>`; showing a line sets `spoke_with:<speaker>`.

## Recordings (played back as timed transcript)
```json
{"id": "...", "canon": "proposed", "kind": "cassette | dashcam | black_box", "title": "...",
 "segments": [{"speaker": "optional character id", "text": "...", "seconds": 3}],
 "in_world_date": "free text", "audio": "optional res:// path", "requires": ["flag"]}
```
`cassette` = audio recording, `dashcam` = found footage, `black_box` = flight-recorder transcript.
`seconds` is optional (derived from text length). A missing/unloadable `audio` file falls back to transcript-only.

## Documents
```json
{"id": "...", "canon": "proposed",
 "kind": "crew_report | personal_note | technical_log | incident_report | classified",
 "title": "...", "body": "...", "author": "optional character id", "in_world_date": "free text",
 "classification": "optional, e.g. LEVEL 3", "requires": ["flag"]}
```

## Events (when X happens, do Y)
```json
{"id": "...", "canon": "proposed", "once": true,
 "trigger": {"type": "interacted", "match": {"interaction_id": "some_object"}},
 "requires": ["flag"], "excludes": ["flag"],
 "actions": [{"type": "unlock_recording", "id": "..."}]}
```
`trigger.type` is any EventBus event name (`core/events.gd`): `interacted`, `area_entered`,
`flag_changed`, `dialogue_ended`, `scene_change_completed`, `recording_played`, `document_read`, ...
`match` fields must equal the payload's fields (compared as text). `once` (default true) fires the event
at most once per save; it is only consumed when its conditions pass.
Actions: `set_flag{flag,value}`, `start_dialogue{id}`, `unlock_recording{id}`, `unlock_document{id}`,
`open_document{id}`, `open_recording{id}`, `set_character_state{id,state}`, `set_objective{id,text}`,
`complete_objective{id}`, `notify{text}`. A failing action is reported and the rest still run;
event chains are cut off at depth 8.

## Export note
Exported builds must include `*.json` under `data/` (export preset "Resources to export
non-resource files" filter) or the database will load empty. Handle in Phase 8.
