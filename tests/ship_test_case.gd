class_name ShipTestCase
extends NarrativeTestCase
## Base for deck tests: instantiates the real Deck A scene with shipped (non-fixture)
## narrative data, and gives helpers to move the player and walk it through the level.

const DECK := "res://scenes/ship/deck_a.tscn"
var deck: Node
var player: Player


func before_each() -> void:
	_reset_world()
	NarrativeDatabase.data_root = "res://data"
	NarrativeDatabase.include_test_content = false
	NarrativeDatabase.load_all()
	GameManager.clear_errors()
	deck = (load(DECK) as PackedScene).instantiate()
	tree.root.add_child(deck)
	player = deck.get_node("Player") as Player
	await physics(6)


func after_each() -> void:
	Input.action_release(InputActions.MOVE_FORWARD)
	Input.action_release(InputActions.SPRINT)
	if is_instance_valid(deck):
		deck.queue_free()
	await tree.process_frame
	await tree.process_frame
	PlayerRegistry.clear()
	super.after_each()


func physics(n: int) -> void:
	for i in n:
		await tree.physics_frame


func door(id: String) -> ShipDoor:
	for d in deck.get_node("Doors").get_children():
		if d is ShipDoor and String(d.door_id) == id:
			return d
	return null


func room(id: String) -> RoomShell:
	return LocationView.find_room(tree, id)


func teleport(pos: Vector3, yaw_deg: float = 0.0) -> void:
	player.global_position = pos
	player.rotation.y = deg_to_rad(yaw_deg)
	player.velocity = Vector3.ZERO


func open_all_doors() -> void:
	GameState.set_flag(&"door_unlocked:section_b", true)
	for d in deck.get_node("Doors").get_children():
		if d is ShipDoor and not d.sealed:
			d.set_open(true, false)


## Walks the real player (physics, collision, input) to a point on the XZ plane. Returns
## true if it got within `tolerance` before the timeout.
func walk_to(target: Vector3, tolerance: float = 0.7, max_frames: int = 900) -> bool:
	for i in max_frames:
		var delta := target - player.global_position
		delta.y = 0.0
		if delta.length() <= tolerance:
			Input.action_release(InputActions.MOVE_FORWARD)
			return true
		player.rotation.y = atan2(-delta.x, -delta.z)  # face the target
		Input.action_press(InputActions.MOVE_FORWARD)
		await tree.physics_frame
	Input.action_release(InputActions.MOVE_FORWARD)
	return false
