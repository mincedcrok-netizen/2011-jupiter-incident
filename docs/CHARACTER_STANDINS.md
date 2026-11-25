# Crew stand-in characters

Decision (Phase 0, approved): the four crew members are **original stand-in characters**, not named
real people. They keep the Lore Bible's roles, personalities, signature gear, relationships-by-event and
canonical end-states. **Names, callsigns, voice style/quirks and relationship notes are PROPOSED** and are
plain data in `data/characters/crew.json`, so they can be changed in one place without touching code.
Ids are role-based (`commander`, `scout`, `pilot`, `quartermaster`).

| Id | Lore Bible role | Established (kept) | PROPOSED (new) |
|---|---|---|---|
| `commander` | Mission Commander / Heavy Defender | loud, protective, unshakeable morale; The Gatling; status: Active / Survivor holding the bridge | name, callsign, voice style, quirks, relationship note |
| `scout` | Reconnaissance and Communications Specialist | hyper, erratic, extremely fast, barks at telemetry; Sonic Bark & Dash; status: Missing in Action (decoy pod into Io's flare) | same |
| `pilot` | Chief Pilot and Systems Technician | tech-savvy, analytical, panic-clicks under stress; System Override Keycard; caused the Oct 15 blunder; status: Presumed Lost (engine core) | same |
| `quartermaster` | Tactical Analyst and Quartermaster | dry, deadpan, cynical, unbothered; Gravity Tether & Barrier; status: Unknown (Pod 04 toward Europa) | same |

Each character's `states` contain `aboard` plus their Lore Bible end-state. **Nothing in the code or data
moves a character into an end-state**; how and when that happens is a story decision awaiting approval.
Demo content (`canon: "test"`) uses these characters only to demonstrate the systems and is not canon.
