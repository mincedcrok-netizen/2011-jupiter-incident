extends TestCase

const ROOM := "res://scenes/test/foundation_room.tscn"
var room: Node


func before_each() -> void:
	GameManager.leave_gameplay()
	GameManager.clear_errors()
	GameState.reset()
	PlayerRegistry.clear()
	EventBus.clear()
	# EventBus.clear() drops GameManager's/menu's own subscriptions; restore them.
	EventBus.subscribe(Events.SCENE_CHANGE_FAILED, GameManager._on_scene_change_failed)
	var menu := _menu()
	EventBus.subscribe(Events.GAME_PAUSED, menu._on_paused)
	EventBus.subscribe(Events.GAME_RESUMED, menu._on_resumed)
	EventBus.subscribe(Events.GAME_STATE_CHANGED, menu._on_state_changed)


func after_each() -> void:
	if is_instance_valid(room):
		room.queue_free()
		room = null
		await tree.process_frame
		await tree.process_frame
	Input.action_release(InputActions.MOVE_FORWARD)
	GameManager.leave_gameplay()
	PlayerRegistry.clear()


func _menu() -> Node:
	for c in GameManager.get_children():
		if c.has_method("is_menu_visible"):
			return c
	return null


func _spawn_room() -> void:
	room = (load(ROOM) as PackedScene).instantiate()
	tree.root.add_child(room)
	for i in 5:
		await tree.physics_frame


func test_pause_menu_is_present() -> void:
	ok(_menu() != null, "pause menu instantiated under GameManager")
	ok(not _menu().is_menu_visible(), "hidden initially")


func test_pause_refused_outside_gameplay() -> void:
	ok(not GameManager.pause(), "cannot pause from IDLE")
	ok(not tree.paused, "tree not paused")
	ok(not GameManager.resume(), "cannot resume when not paused")


func test_pause_and_resume_cycle() -> void:
	GameManager.enter_gameplay()
	ok(GameManager.wants_mouse_captured(), "mouse captured while playing")
	ok(GameManager.pause(), "pause accepted")
	ok(tree.paused, "tree paused")
	ok(GameManager.is_paused(), "state PAUSED")
	ok(not GameManager.wants_mouse_captured(), "mouse released while paused")
	ok(_menu().is_menu_visible(), "menu shown")
	ok(not GameManager.pause(), "double pause refused")
	ok(GameManager.resume(), "resume accepted")
	ok(not tree.paused, "tree running")
	ok(GameManager.wants_mouse_captured(), "mouse captured again")
	ok(not _menu().is_menu_visible(), "menu hidden")


func test_events_published_for_pause_and_resume() -> void:
	var seen := []
	EventBus.subscribe(Events.GAME_PAUSED, func(_p: Dictionary) -> void: seen.append("paused"))
	EventBus.subscribe(Events.GAME_RESUMED, func(_p: Dictionary) -> void: seen.append("resumed"))
	GameManager.enter_gameplay()
	GameManager.pause()
	GameManager.resume()
	eq(seen, ["paused", "resumed"], "events in order")


func test_escape_key_toggles_pause_through_input_pipeline() -> void:
	GameManager.enter_gameplay()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await tree.process_frame
	await tree.process_frame
	ok(GameManager.is_paused(), "Esc paused the game")
	var up := InputEventKey.new()
	up.physical_keycode = KEY_ESCAPE
	up.pressed = false
	Input.parse_input_event(up)
	await tree.process_frame
	var ev2 := ev.duplicate()
	Input.parse_input_event(ev2)
	await tree.process_frame
	await tree.process_frame
	ok(not GameManager.is_paused(), "second Esc resumed the game")


func test_escape_does_nothing_outside_gameplay() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await tree.process_frame
	await tree.process_frame
	ok(not GameManager.is_paused(), "no pause from IDLE")


func test_losing_window_focus_pauses_only_when_playing() -> void:
	GameManager._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(not GameManager.is_paused(), "ignored when idle")
	GameManager.enter_gameplay()
	GameManager._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(GameManager.is_paused(), "paused on focus loss during play")


func test_pause_actually_freezes_the_player() -> void:
	await _spawn_room()
	var p := room.get_node("Player") as Player
	eq(GameManager.state, GameManager.State.PLAYING, "room put the game in PLAYING")
	Input.action_press(InputActions.MOVE_FORWARD)
	GameManager.pause()
	var z0 := p.global_position.z
	for i in 15:
		await tree.physics_frame
	ok(is_equal_approx(p.global_position.z, z0), "player did not move while paused")
	GameManager.resume()
	for i in 15:
		await tree.physics_frame
	ok(p.global_position.z < z0 - 0.2, "player moves again after resume")


func test_leaving_gameplay_while_paused_unpauses_and_hides_menu() -> void:
	await _spawn_room()
	GameManager.pause()
	ok(tree.paused and _menu().is_menu_visible(), "precondition: paused with menu")
	room.queue_free()
	room = null
	await tree.process_frame
	await tree.process_frame
	eq(GameManager.state, GameManager.State.IDLE, "back to IDLE")
	ok(not tree.paused, "tree unpaused")
	ok(not _menu().is_menu_visible(), "menu hidden")


func test_error_log_records_caps_and_publishes() -> void:
	var seen := []
	EventBus.subscribe(Events.ERROR_REPORTED, func(e: Dictionary) -> void: seen.append(e["context"]))
	GameManager.report_error("ctx", "first", "warning")
	eq(GameManager.recent_errors().size(), 1, "recorded")
	eq(seen, ["ctx"], "event published")
	for i in 70:
		GameManager.report_error("flood", "n%d" % i, "warning")
	eq(GameManager.recent_errors().size(), GameManager.MAX_ERRORS, "log is capped")
	eq(GameManager.recent_errors().back()["message"], "n69", "newest kept")
	GameManager.clear_errors()
	eq(GameManager.recent_errors().size(), 0, "cleared")


func test_failed_scene_change_is_logged() -> void:
	SceneManager.change_scene("res://missing/nothing.tscn")
	var errs := GameManager.recent_errors()
	eq(errs.size(), 1, "one error recorded")
	eq(errs[0]["context"], "scene_manager", "from the scene manager")
