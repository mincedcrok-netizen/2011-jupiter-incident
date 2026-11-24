# data/

Narrative content lives here as JSON (see `docs/DATA_FORMATS.md`):

- `data/dialogue/*.json` dialogue sequences
- `data/recordings/*.json` collectible recordings and documents

No real content exists yet. Phase 1 only builds and tests the pipeline (fixtures live in
`tests/fixtures/data/`). Every entry must declare `"canon": "established" | "proposed"`.
