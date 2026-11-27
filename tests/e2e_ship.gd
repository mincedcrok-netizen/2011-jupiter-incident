extends SceneTree
## Rendered end-to-end walkthrough of the Phase 3 ship slice, in a REAL window with REAL
## keyboard events: boots the game, walks the corridor, opens doors, uses terminals, plays a
## recording, reads documents, triggers the damaged section, meets the sealed engine core door,
## saves and reloads, and reports render statistics. Screenshots go to the directory given
## after `--`. Needs a display (Xvfb in the sandbox). Exits non-zero on any failed check.

var out_dir := "/tmp/e2e_ship"
var failed := 0
var checks := 0
var player
var gm: Node
var ns: Node
var ui: Node
var dm: Node
var gs: Node
var deck: Node


func check(cond: bool, msg: String) -> void:
	checks += 1
	print("%s  %s  [%.0fs]" % ["PASS" if cond else "FAIL", msg, Time.get_ticks_msec() / 1000.0])
	if not cond:
		failed += 1


func key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func tap(code: Key) -> void:
	key(code, true)
	key(code, false)
	await frames(3)


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])


func stats(label: String) -> void:
	await RenderingServer.frame_post_draw
	print("STATS %-22s draw calls %3d | objects %3d | primitives %5d | fps %.0f (software GL)" % [label,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), Engine.get_frames_per_second()])


## Real walking: face the target and hold W (Shift to run) until close or timed out.
func walk_to(target: Vector3, tol: float = 0.8, max_seconds: float = 40.0, run: bool = true) -> bool:
	# Wall-clock timeout (software rendering is slow and frame counts are meaningless).
	if run:
		key(KEY_SHIFT, true)
	key(KEY_W, true)
	var ok_reach := false
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < int(max_seconds * 1000.0):
		var d: Vector3 = target - player.global_position
		d.y = 0.0
		if d.length() <= tol:
			ok_reach = true
			break
		player.rotation.y = atan2(-d.x, -d.z)
		await process_frame
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	await frames(4)
	if not ok_reach:
		print("  (walk timed out at %s, wanted %s)" % [str(player.global_position), str(target)])
	return ok_reach


## Stand `dist` m in front of an item (its front is +Z in its own space) and look at it.
func face(node_name: String, dist: float = 1.2, _unused_pitch: float = 0.0) -> Node3D:
	var n := deck.find_child(node_name, true, false) as Node3D
	# Aim like a player would: at the centre of the object's focus volume.
	var cs := n.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D
	var pitch := atan2(n.global_position.y + cs.position.y - 1.65, dist)
	var theta := n.global_rotation.y
	var front := Vector3(sin(theta), 0, cos(theta))
	var spot := n.global_position + front * dist
	player.global_position = Vector3(spot.x, 0.05, spot.z)
	player.velocity = Vector3.ZERO
	player.rotation.y = theta
	player.head.rotation.x = pitch
	await frames(10)
	return n


func door(id: String) -> Node:
	for d in deck.get_node("Doors").get_children():
		if String(d.get("door_id")) == id:
			return d
	return null


## Esc closes an open reader/player; it must never be sent when nothing is open (that pauses the game).
func close_top() -> void:
	if ui.any_view_open():
		await tap(KEY_ESCAPE)
	else:
		check(false, "expected a reader/player to be open before closing it")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	gm = root.get_node("/root/GameManager")
	ns = root.get_node("/root/NarrativeState")
	ui = root.get_node("/root/NarrativeUI")
	dm = root.get_node("/root/DialogueManager")
	gs = root.get_node("/root/GameState")
	_run.call_deferred()


func _run() -> void:
	print("Renderer: %s | display: %s" % [RenderingServer.get_video_adapter_name(), DisplayServer.get_name()])
	var toasts_seen: Array[String] = []
	root.get_node("/root/EventBus").subscribe(&"notification", func(p: Dictionary) -> void: toasts_seen.append(str(p.get("text", ""))))
	var boot := (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await frames(40)
	deck = current_scene
	player = root.get_node("/root/PlayerRegistry").get_local()
	var hud := deck.get_node("HUD")
	var location := deck.find_children("*", "LocationView", true, false)[0]
	var waypoint := deck.find_children("*", "WaypointView", true, false)[0]

	# ============ start: boot -> ship ============
	check(root.get_node("/root/SceneManager").current_scene_path == "res://scenes/ship/deck_a.tscn", "boot loads the ship deck")
	check(gm.state == gm.State.PLAYING and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "playing, mouse captured")
	check(player != null and player.is_on_floor(), "player spawned on the floor")
	check(ns.objectives().size() == 1 and ns.objectives()[0]["id"] == "reach_bridge", "scene entry issued the first objective")
	check(toasts_seen.any(func(t: String) -> bool: return t.contains("MAIN CORRIDOR")), "a notification named the deck on arrival")
	check(location.location_text() == "LOCATION: DECK A: MAIN CORRIDOR", "location tag names the corridor ('%s')" % location.location_text())
	check(waypoint.shown and waypoint.label_text.contains("COMMAND BRIDGE"), "waypoint points at the bridge ('%s')" % waypoint.label_text)
	await shot("01_spawn_corridor")
	await stats("corridor spawn")
	check(root.get_node("/root/GameManager").recent_errors().is_empty(), "no errors so far")

	# ============ walk up the corridor to the bridge door ============
	var reached := await walk_to(Vector3(0, 0.05, -18.3), 0.9)
	check(reached, "walked the length of the corridor (z=%.1f)" % player.global_position.z)
	check(player.global_position.z > -19.7, "the closed bridge door stops the player (z=%.2f)" % player.global_position.z)
	check(hud.prompt_text() == "[E] Open: Command Bridge", "HUD prompt on the door ('%s')" % hud.prompt_text())
	await shot("02_door_prompt")
	await tap(KEY_E)
	await frames(30)
	check(door("bridge").is_open, "E opened the bridge door")
	check(hud.prompt_text() == "[E] Close door", "prompt switched to 'Close door'")
	check(await walk_to(Vector3(0, 0.05, -25.0), 0.9), "walked through the doorway into the bridge")
	await frames(10)
	check(location.location_text() == "LOCATION: COMMAND BRIDGE", "location tag changed to the bridge")
	check(ns.objectives()[0]["completed"] and ns.objectives()[1]["id"] == "check_terminal", "reaching the bridge advanced the objectives")
	await shot("03_bridge")
	await stats("command bridge")

	# ============ bridge terminal -> dialogue -> unlock Section B ============
	await face("StatusTerminal", 1.2)
	check(hud.prompt_text() == "[E] Use bridge status terminal", "prompt for the status terminal ('%s')" % hud.prompt_text())
	check(waypoint.shown or player.global_position.distance_to(deck.get_node("Nav/nav_bridge_terminal").global_position) < 3.0, "waypoint leads to / has reached the terminal")
	await tap(KEY_E)
	check(dm.is_active() and dm.current()["speaker"] == "system", "terminal opened a conversation with the ship's system")
	ui.dialogue_view.skip_typing()
	await frames(3)
	await shot("04_terminal_menu")
	check(door("section_b").is_locked(), "Section B is locked before release")
	await tap(KEY_3)  # Release Section B emergency lock
	check(gs.is_flag_true(&"door_unlocked:section_b"), "choosing option 3 released the lock")
	var guard := 0
	while dm.is_active() and dm.current().get("node") != "menu" and guard < 8:
		await tap(KEY_E)
		guard += 1
	ui.dialogue_view.skip_typing()
	await frames(3)
	check(dm.current()["choices"].size() == 3, "the release option vanished from the menu")
	await tap(KEY_3)  # Log out
	check(not dm.is_active(), "logged out")
	check(ns.objectives().size() == 3 and ns.objectives()[2]["id"] == "search_quarters", "objective moved on: search the crew quarters")
	check(not door("section_b").is_locked() and door("section_b").prompt_text == "Open: Section B", "the Section B door now reads 'Open'")

	# ============ black-box recorder ============
	await face("BlackBox", 0.9, -0.55)
	await tap(KEY_E)
	check(ui.recording_view.is_open() and ns.is_recording_unlocked(&"black_box_0811a"), "black-box recorder opened the recording player")
	await create_timer(5.5).timeout
	await shot("05_black_box_playing")
	var transcript: String = ui.recording_view.transcript_text()
	check(transcript.contains("WREN CALLOWAY") and transcript.contains("Cursor, hands OFF") or transcript.contains("Bit chilly"), "transcript is playing with character data names")
	ui.recording_view.player.advance(60.0)
	await frames(3)
	check(ns.was_recording_played(&"black_box_0811a"), "finished playing -> marked played")
	await close_top()
	check(not ui.recording_view.is_open() and not gm.is_paused(), "Esc closed the recording (no pause)")
	player.head.rotation.x = 0.0

	# ============ flight deck log (document) + environment details ============
	await face("FlightConsole", 1.2)
	await tap(KEY_E)
	check(ui.document_view.is_open() and ui.document_view.title_text().contains("Flight deck log"), "flight deck console shows its log")
	await shot("06_flight_log")
	await close_top()
	player.global_position = Vector3(-6.2, 0.05, -24.0)
	player.rotation.y = deg_to_rad(90.0)
	await frames(15)
	await shot("07_bridge_damaged_console")

	# ============ crew quarters ============
	player.global_position = Vector3(0, 0.05, -22.0)
	player.rotation.y = deg_to_rad(180.0)
	check(await walk_to(Vector3(0, 0.05, -17.0)), "walked back out of the bridge")
	check(await walk_to(Vector3(-1.3, 0.05, -8.0), 0.7), "walked to the quarters door")
	player.rotation.y = deg_to_rad(90.0)
	await frames(8)
	check(hud.prompt_text() == "[E] Open: Crew Quarters", "prompt on the quarters door ('%s')" % hud.prompt_text())
	await tap(KEY_E)
	await frames(30)
	check(await walk_to(Vector3(-6.0, 0.05, -8.0), 0.9), "walked into the crew quarters")
	await frames(10)
	check(location.location_text() == "LOCATION: CREW QUARTERS", "location tag: crew quarters")
	check(ns.objectives()[-1]["id"] == "check_supply", "objective advanced to the supply room")
	await shot("08_quarters")
	await face("Locker_commander", 1.1, -0.5)
	await tap(KEY_E)
	check(ui.document_view.is_open() and ui.document_view.body_text().contains("Dale Brannigan"), "footlocker note is signed with the data-driven name")
	await shot("09_locker_note")
	await close_top()
	await face("CassetteRadio", 0.9, -0.6)
	await tap(KEY_E)
	check(ui.recording_view.is_open() and ns.is_recording_unlocked(&"crew_cassette_livestream"), "cassette radio plays the crew cassette")
	await close_top()
	player.head.rotation.x = 0.0

	# ============ supply room ============
	player.global_position = Vector3(-6.0, 0.05, -8.0)
	player.rotation.y = deg_to_rad(-90.0)
	check(await walk_to(Vector3(-1.2, 0.05, -8.0), 0.7), "left the quarters")
	check(await walk_to(Vector3(0.0, 0.05, 4.0), 0.9), "crossed to the supply door")
	player.rotation.y = deg_to_rad(-90.0)
	await frames(8)
	await tap(KEY_E)
	await frames(30)
	check(await walk_to(Vector3(6.0, 0.05, 4.0), 0.9), "walked into the supply room")
	await frames(10)
	check(location.location_text() == "LOCATION: SUPPLY ROOM", "location tag: supply room")
	check(ns.objectives()[-1]["id"] == "inspect_engineering" and ns.objectives()[-1]["target"] == "nav_engineering", "objective: inspect engineering (waypoint set)")
	await shot("10_supply_room")
	await face("PodChecklist", 1.1, -0.15)
	await tap(KEY_E)
	check(ui.document_view.is_open() and ns.is_document_found(&"pod_provisioning_checklist"), "pod checklist (evacuation preparations) readable")
	await close_top()

	# ============ Section B (damaged) ============
	player.global_position = Vector3(6.0, 0.05, 4.0)
	player.rotation.y = deg_to_rad(90.0)
	check(await walk_to(Vector3(1.0, 0.05, 4.0), 0.7), "left the supply room")
	check(await walk_to(Vector3(0.0, 0.05, 18.4), 0.35), "walked south along the corridor to the Section B door")
	player.rotation.y = deg_to_rad(180.0)
	await frames(8)
	check(hud.prompt_text() == "[E] Open: Section B", "prompt on the (now unlocked) Section B door ('%s')" % hud.prompt_text())
	await tap(KEY_E)
	await frames(30)
	check(await walk_to(Vector3(0.0, 0.05, 26.0), 0.9), "walked into the damaged section")
	await frames(12)
	check(location.location_text() == "LOCATION: SECTION B (DAMAGED)", "location tag: Section B")
	await shot("11_section_b")
	await stats("damaged section")
	await face("CorruptedTerminal", 1.2)
	await tap(KEY_E)
	check(ui.document_view.is_open() and ui.document_view.body_text().contains("▓"), "corrupted terminal shows text eaten by symbols")
	await shot("12_corrupted_terminal")
	await close_top()
	await face("KeyShard", 1.0, -0.6)
	await tap(KEY_E)
	check(ui.notifications.toast_texts().any(func(t: String) -> bool: return t.contains("pyramid-shaped")), "examining the shard gives a description, no explanation")
	await shot("13_key_shard")
	player.head.rotation.x = 0.0

	# ============ engineering access + sealed core door ============
	player.global_position = Vector3(0.0, 0.05, 28.0)
	player.rotation.y = deg_to_rad(180.0)
	check(await walk_to(Vector3(0.0, 0.05, 32.5), 0.8), "walked to the engineering door")
	await frames(8)
	await tap(KEY_E)
	await frames(30)
	check(await walk_to(Vector3(0.0, 0.05, 40.0), 0.9), "walked into engineering access")
	await frames(12)
	check(location.location_text() == "LOCATION: ENGINEERING ACCESS CORRIDOR", "location tag: engineering")
	check(ns.objectives()[-1]["id"] == "engine_core_sealed", "final objective: the engine core is sealed (end of slice)")
	await shot("14_engineering")
	await stats("engineering")
	check(await walk_to(Vector3(0.0, 0.05, 47.5), 0.8), "walked to the end of the corridor")
	player.rotation.y = deg_to_rad(180.0)
	await frames(10)
	check(hud.prompt_text().begins_with("[E] Locked"), "engine core door prompt reads 'Locked' ('%s')" % hud.prompt_text())
	await tap(KEY_E)
	check(not door("engine_core").is_open and ui.notifications.toast_texts().any(func(t: String) -> bool: return t.contains("ACCESS DENIED")), "the sealed door refuses with an explanation")
	await shot("15_engine_core_door")
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	await frames(40)
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	check(player.global_position.z < 49.5, "the player cannot pass the sealed door (z=%.2f)" % player.global_position.z)

	# ============ archive, pause, save/load ============
	await tap(KEY_TAB)
	check(ui.log_view.is_open() and ui.log_view.item_count() >= 6, "the archive lists everything found: 2 recordings + 4 documents (%d entries)" % ui.log_view.item_count())
	await shot("16_archive")
	await tap(KEY_TAB)
	await tap(KEY_ESCAPE)
	check(gm.is_paused() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc pauses and frees the mouse")
	await shot("17_paused")
	await tap(KEY_ESCAPE)
	check(not gm.is_paused(), "Esc resumes")
	var saves := root.get_node("/root/SaveSystem")
	saves.save_dir = "user://e2e_ship_saves"
	check(saves.save_slot(1) == OK, "saved the game")
	gs.reset()
	ns.reset()
	check(saves.load_slot(1) == OK, "loaded the game")
	await frames(3)
	check(ns.was_recording_played(&"black_box_0811a") and ns.is_document_read(&"crew_note_commander") and not door("section_b").is_locked(), "progress restored: recording, document, unlocked door")
	check(ns.objectives()[-1]["id"] == "engine_core_sealed" and ns.objectives()[-1]["target"] == "nav_engine_core", "objectives and waypoint target restored")
	saves.delete_slot(1)
	check(gm.recent_errors().is_empty(), "the game recorded no errors during the entire walkthrough")
	print("\n%d checks, %d failed" % [checks, failed])
	quit(1 if failed > 0 else 0)
