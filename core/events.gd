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
