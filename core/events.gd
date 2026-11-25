class_name Events
extends RefCounted
## Canonical event type names for the EventBus.
## Use these constants instead of raw strings to avoid typos.
## Payload shapes are documented next to each constant.

## {key: String, value: Variant, old: Variant}
const FLAG_CHANGED := &"flag_changed"
## {interaction_id: StringName, actor_id: StringName, peer_id: int}
const INTERACTED := &"interacted"
## {interaction_id: StringName, prompt: String} (empty id when focus lost)
const INTERACTION_FOCUS_CHANGED := &"interaction_focus_changed"
## {peer_id: int, actor_id: StringName}
const PLAYER_REGISTERED := &"player_registered"
const PLAYER_UNREGISTERED := &"player_unregistered"
## {path: String}
const SCENE_CHANGE_STARTED := &"scene_change_started"
const SCENE_CHANGE_COMPLETED := &"scene_change_completed"
## {path: String, error: int}
const SCENE_CHANGE_FAILED := &"scene_change_failed"
## {slot: int}
const SAVE_COMPLETED := &"save_completed"
const LOAD_COMPLETED := &"load_completed"
## {section: String, key: String, value: Variant}
const SETTINGS_CHANGED := &"settings_changed"

## {state: String, previous: String}
const GAME_STATE_CHANGED := &"game_state_changed"
const GAME_PAUSED := &"game_paused"
const GAME_RESUMED := &"game_resumed"
## {context: String, message: String, severity: String}
const ERROR_REPORTED := &"error_reported"

## --- Phase 2 narrative events ---
## {id: StringName}
const DIALOGUE_STARTED := &"dialogue_started"
## {id: StringName, node: String, speaker: String, text: String, choices: Array[String]}
const DIALOGUE_NODE := &"dialogue_node"
## {id: StringName, completed: bool}
const DIALOGUE_ENDED := &"dialogue_ended"
## {id: StringName}
const RECORDING_UNLOCKED := &"recording_unlocked"
const RECORDING_PLAYED := &"recording_played"
const DOCUMENT_FOUND := &"document_found"
const DOCUMENT_READ := &"document_read"
## {id: StringName, state: String, old: String}
const CHARACTER_STATE_CHANGED := &"character_state_changed"
## {id: String, text: String, kind: "added" | "completed"}
const OBJECTIVE_CHANGED := &"objective_changed"
## {id: StringName}
const NARRATIVE_EVENT_FIRED := &"narrative_event_fired"
## {text: String}
const NOTIFICATION := &"notification"
## {trigger_id: String, peer_id: int}  (published by NarrativeTrigger areas)
const AREA_ENTERED := &"area_entered"
## {kind: "document" | "recording", id: StringName}  (asks the UI layer to open something)
const UI_OPEN_REQUESTED := &"ui_open_requested"
