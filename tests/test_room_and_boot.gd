extends TestCase

const ROOM := "res://scenes/test/foundation_room.tscn"
var room: Node


func before_each() -> void:
	GameManager.leave_gameplay()
	GameManager.clear_errors()
	GameState.reset()
	PlayerRegistry.clear()
	room = (load(ROOM) as PackedScene).instantiate()
	tree.root.add_child(room)
	for i in 5:
		await tree.physics_frame


func after_each() -> void:
	Input.action_release(InputActions.MOVE_FORWARD)
	Input.action_release(InputActions.SPRINT)
	if is_instance_valid(room):
		room.queue_free()
	await tree.process_frame
	await tree.process_frame
	PlayerRegistry.clear()
	GameManager.clear_errors()


func _cast(dir: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(0, 1, 0), Vector3(0, 1, 0) + dir * 30.0)
	q.collision_mask = PhysicsLayers.WORLD
	return (room as Node3D).get_world_3d().direct_space_state.intersect_ray(q)


func test_room_is_fully_enclosed() -> void:
	for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var hit := _cast(dir)
		ok(not hit.is_empty(), "solid collision in direction %s" % str(dir))
		if not hit.is_empty():
			ok((hit["position"] as Vector3).distance_to(Vector3(0, 1, 0)) < 7.0, "surface within room bounds %s" % str(dir))


func test_room_has_lighting_and_a_current_camera() -> void:
	ok(room.get_node_or_null("Light") is OmniLight3D, "has a light")
	ok(room.get_node_or_null("WorldEnvironment") is WorldEnvironment, "has an environment")
	var cam := (room.get_node("Player") as Player).camera
	ok(cam.current, "player camera is current")
	ok(room.get_viewport().get_camera_3d() == cam, "viewport renders through the player camera")


func test_player_cannot_walk_through_outer_wall() -> void:
	var p := room.get_node("Player") as Player
	p.global_position = Vector3(4, 0.05, 0)
	p.rotation.y = -PI / 2.0  # face +X (east wall inner face at x = 5.8)
	await tree.physics_frame
	Input.action_press(InputActions.MOVE_FORWARD)
	Input.action_press(InputActions.SPRINT)
	for i in 150:
		await tree.physics_frame
	ok(p.global_position.x > 5.0, "player reached the wall (x=%.2f)" % p.global_position.x)
	ok(p.global_position.x < 5.8, "player did not pass through the wall (x=%.2f)" % p.global_position.x)


func test_player_is_blocked_by_crate() -> void:
	var p := room.get_node("Player") as Player
	p.global_position = Vector3(3, 0.05, 4.8)  # crate occupies z 1.5..2.5 at x 3
	await tree.physics_frame
	Input.action_press(InputActions.MOVE_FORWARD)
	for i in 120:
		await tree.physics_frame
	ok(p.global_position.z >= 2.8, "stopped at the crate (z=%.2f)" % p.global_position.z)
	ok(p.global_position.z < 3.2, "and actually walked up to it (z=%.2f)" % p.global_position.z)


func test_boot_failure_shows_message_and_logs_error() -> void:
	var boot := (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	boot.set("first_scene", "res://scenes/does_not_exist.tscn")
	tree.root.add_child(boot)
	for i in 4:
		await tree.process_frame
	var label: Label = boot.get("error_label")
	ok(label != null, "error label shown")
	if label != null:
		ok(label.text.contains("could not start"), "message explains the failure")
		ok(label.text.contains("does_not_exist"), "message names the missing scene")
	var contexts := []
	for e in GameManager.recent_errors():
		contexts.append(e["context"])
	ok("boot" in contexts, "boot failure recorded in the error log")
	boot.queue_free()
