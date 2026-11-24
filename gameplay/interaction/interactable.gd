class_name Interactable
extends StaticBody3D
## Anything the player can look at and press Interact on (doors, terminals,
## pickups, cassette decks). Subclass or connect to `interacted` for behavior.
##
## Ownership: AUTHORITY performs interactions. One-shot state is stored as a
## GameState flag, so it is saved/loaded and (later) replicated for free.

signal interacted(actor: Actor)

@export var interaction_id: StringName = &""
@export var prompt_text: String = "Interact"
@export var enabled: bool = true
@export var one_shot: bool = false

var _warned_missing_id := false


func _ready() -> void:
	collision_layer = PhysicsLayers.INTERACTABLE
	collision_mask = 0
	if interaction_id == &"":
		push_error("Interactable '%s' has no interaction_id; it will be inert." % name)


func used_flag_key() -> StringName:
	return StringName("interactable_used:%s" % interaction_id)


func is_available_to(_actor: Actor) -> bool:
	if not enabled or interaction_id == &"":
		return false
	if one_shot and GameState.is_flag_true(used_flag_key()):
		return false
	return true


## Returns true if the interaction happened.
func try_interact(actor: Actor) -> bool:
	if actor == null or not is_available_to(actor):
		return false
	if not Net.is_authority():
		push_warning("Interactable: remote interaction requests arrive in Phase 7")
		return false
	if one_shot:
		GameState.set_flag(used_flag_key(), true)
	interacted.emit(actor)
	EventBus.publish(Events.INTERACTED, {
		"interaction_id": interaction_id,
		"actor_id": actor.actor_id,
		"peer_id": actor.peer_id,
	})
	return true
