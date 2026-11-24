# Narrative data formats

Each file is a JSON **array** of entry objects. Invalid entries are skipped and reported
(`NarrativeDatabase.load_errors` and `GameManager.recent_errors()`); duplicates keep the first.

## Common fields
- `id` (string, unique per kind)
- `canon`: `"established"` (from the Lore Bible), `"proposed"` (needs approval), or `"test"` (fixtures only)

## Dialogue sequence (`data/dialogue/*.json`)
```json
{"id": "...", "canon": "proposed",
 "lines": [{"speaker": "character_id", "text": "...",
            "requires": ["flag"], "excludes": ["flag"]}]}
```
`requires`/`excludes` are optional story-flag keys (truthy test). Choices and the runner are Phase 2.

## Recording (`data/recordings/*.json`)
```json
{"id": "...", "canon": "proposed",
 "kind": "cassette|dashcam|black_box|report|personal_record",
 "title": "...", "body": "...",
 "author": "optional", "in_world_date": "optional free text",
 "requires": ["optional flags needed before it can be unlocked"]}
```
Unlocking sets the story flag `recording_unlocked:<id>`, so it is saved with `GameState`.

## Export note
Exported builds must include `*.json` under `data/` (export preset "Resources to export
non-resource files" filter) or the database will load empty. Handle in Phase 8.
