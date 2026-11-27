class_name PlayerInteractor
extends RayCast3D
## Raycast from the player's view that tracks which Interactable is focused and
## triggers it on request. Walls block the ray (world layer is in the mask).

var focused: Interactable = null
var _actor: Actor = null


func _ready() -> void:
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.INTERACTABLE
	collide_with_areas = false
	collide_with_bodies = true
	_actor = _find_actor()


func _physics_process(_delta: float) -> void:
	var target: Interactable = null
	if is_colliding():
		target = get_collider() as Interactable
		if target != null and not target.is_available_to(_actor):
			target = null
	if target != focused:
		focused = target
		_publish_focus()


func _publish_focus() -> void:
	EventBus.publish(Events.INTERACTION_FOCUS_CHANGED, {
		"interaction_id": focused.interaction_id if focused else &"",
		"prompt": focused.prompt_text if focused else "",
	})


## Returns true if something was interacted with.
func interact() -> bool:
	if focused == null or not is_instance_valid(focused):
		return false
	var done := focused.try_interact(_actor)
	if done and is_instance_valid(focused):
		_publish_focus()  # the prompt may have changed ("Open" -> "Close")
	return done


func _find_actor() -> Actor:
	var n: Node = get_parent()
	while n != null:
		if n is Actor:
			return n
		n = n.get_parent()
	return null
