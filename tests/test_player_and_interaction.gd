extends TestCase

const ROOM := "res://scenes/test/foundation_room.tscn"
var room: Node


func before_each() -> void:
	GameState.reset()
	PlayerRegistry.clear()
	EventBus.clear()
	room = (load(ROOM) as PackedScene).instantiate()
	tree.root.add_child(room)
	await _physics(5)


func after_each() -> void:
	for a in [InputActions.MOVE_FORWARD, InputActions.SPRINT]:
		Input.action_release(a)
	if is_instance_valid(room):
		room.queue_free()
	await tree.process_frame
	await tree.process_frame
	PlayerRegistry.clear()


func _physics(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _player() -> Player:
	return room.get_node("Player") as Player


func test_player_registers_as_local_and_camera_current() -> void:
	var p := _player()
	eq(PlayerRegistry.count(), 1, "one player registered")
	ok(PlayerRegistry.get_local() == p, "registry local == player")
	ok(p.camera.current, "local player's camera is current")
	eq(p.actor_id, &"player_1", "default actor id derived from peer")


func test_player_settles_on_floor() -> void:
	await _physics(30)
	ok(_player().is_on_floor(), "gravity + floor collision work")
	ok(absf(_player().global_position.y) < 0.05, "standing on floor plane")


func test_forward_input_moves_player_and_sprint_is_faster() -> void:
	var p := _player()
	await _physics(10)
	var z0 := p.global_position.z
	Input.action_press(InputActions.MOVE_FORWARD)
	await _physics(20)
	var walked := z0 - p.global_position.z
	Input.action_release(InputActions.MOVE_FORWARD)
	ok(walked > 0.3, "walking forward moved the player (-Z)")
	p.global_position = Vector3(0, 0.05, 3)
	p.velocity = Vector3.ZERO
	await _physics(5)
	var z1 := p.global_position.z
	Input.action_press(InputActions.MOVE_FORWARD)
	Input.action_press(InputActions.SPRINT)
	await _physics(20)
	var sprinted := z1 - p.global_position.z
	ok(sprinted > walked, "sprint covers more distance than walk (%.2f vs %.2f)" % [sprinted, walked])


func test_pitch_is_clamped() -> void:
	var p := _player()
	p.player_input._look_accum = Vector2(0, 100000)
	await _physics(2)
	ok(absf(p.head.rotation.x) <= deg_to_rad(p.pitch_limit_deg) + 0.001, "pitch within limit (down)")
	p.player_input._look_accum = Vector2(0, -100000)
	await _physics(2)
	ok(absf(p.head.rotation.x) <= deg_to_rad(p.pitch_limit_deg) + 0.001, "pitch within limit (up)")


func test_remote_player_is_not_driven_by_local_input() -> void:
	var remote := (load("res://gameplay/player/player.tscn") as PackedScene).instantiate() as Player
	remote.peer_id = 2
	room.add_child(remote)
	remote.global_position = Vector3(5, 0.05, 5)
	await _physics(3)
	var before := remote.global_position
	Input.action_press(InputActions.MOVE_FORWARD)
	await _physics(15)
	ok(not remote.camera.current, "remote camera not current")
	ok(remote.global_position.is_equal_approx(before), "remote did not move from local input")
	eq(PlayerRegistry.count(), 2, "both players registered")


func test_remote_state_is_validated_and_clamped() -> void:
	var inp := _player().player_input
	inp.apply_remote_state({"move": Vector2(10, 0), "sprint": true})
	ok(inp.move.length() <= 1.0 + 0.0001, "remote move clamped to unit length")
	inp.apply_remote_state({"move": "garbage", "sprint": 5})
	ok(inp.move.length() <= 1.0 + 0.0001, "garbage ignored, state still valid")
	ok(inp.sprint == true, "bad sprint value ignored")


func test_terminal_gets_focus_and_one_shot_interaction() -> void:
	var p := _player()
	var term := room.get_node("TestTerminal") as Interactable
	var focus_events := []
	var used_events := []
	EventBus.subscribe(Events.INTERACTION_FOCUS_CHANGED, func(e: Dictionary) -> void: focus_events.append(e))
	EventBus.subscribe(Events.INTERACTED, func(e: Dictionary) -> void: used_events.append(e))
	p.interactor.focused = null  # focus was already acquired during setup; force a fresh event
	await _physics(3)
	ok(p.interactor.focused == term, "ray focuses the terminal in front of the player")
	ok(not focus_events.is_empty(), "focus event published")
	if not focus_events.is_empty():
		eq(focus_events.back()["prompt"], "Use terminal", "focus event carries the prompt")
	ok(p.interactor.interact(), "interaction succeeds")
	eq(used_events.size(), 1, "interacted event published")
	eq(used_events[0]["interaction_id"], &"foundation_test_terminal", "event carries id")
	eq(used_events[0]["actor_id"], &"player_1", "event carries actor id")
	ok(GameState.get_flag(term.used_flag_key()) == true, "one-shot recorded in GameState")
	ok(not p.interactor.interact(), "second interaction refused (one-shot)")
	await _physics(2)
	ok(p.interactor.focused == null, "used one-shot no longer focusable")


func test_one_shot_state_survives_save_and_load() -> void:
	var term := room.get_node("TestTerminal") as Interactable
	_player().interactor.interact()
	SaveSystem.save_dir = "user://test_saves_inter"
	eq(SaveSystem.save_slot(1), OK, "saved")
	GameState.reset()
	ok(term.is_available_to(_player()), "available again after reset")
	eq(SaveSystem.load_slot(1), OK, "loaded")
	ok(not term.is_available_to(_player()), "stays used after load")
	SaveSystem.delete_slot(1)
	SaveSystem.save_dir = SaveSystem.DEFAULT_SAVE_DIR


func test_wall_blocks_interaction_ray() -> void:
	var p := _player()
	var wall := StaticBody3D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.2)
	cs.shape = box
	wall.add_child(cs)
	room.add_child(wall)
	wall.global_position = Vector3(0, 1.5, -1.0)
	await _physics(3)
	ok(p.interactor.focused == null, "wall between player and terminal blocks focus")


func test_disabled_or_id_less_interactable_is_inert() -> void:
	var term := room.get_node("TestTerminal") as Interactable
	term.enabled = false
	ok(not term.try_interact(_player()), "disabled -> refuses")
	term.enabled = true
	ok(not term.try_interact(null), "null actor -> refuses")
	term.interaction_id = &""
	ok(not term.is_available_to(_player()), "empty id -> unavailable")
