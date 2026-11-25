class_name NarrativeTrigger
extends Area3D
## Invisible volume for environmental storytelling and encounters. When a player
## actor enters, it publishes AREA_ENTERED {trigger_id, peer_id}; NarrativeEvents in
## data decide what that means. Only the authority publishes, so co-op fires it once.

@export var trigger_id: StringName = &""


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	if trigger_id == &"":
		push_error("NarrativeTrigger '%s' has no trigger_id; it will be inert." % name)


func _on_body_entered(body: Node3D) -> void:
	if trigger_id == &"" or not (body is Actor) or not Net.is_authority():
		return
	EventBus.publish(Events.AREA_ENTERED, {"trigger_id": String(trigger_id), "peer_id": (body as Actor).peer_id})
