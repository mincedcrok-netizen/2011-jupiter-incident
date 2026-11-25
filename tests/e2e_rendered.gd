extends SceneTree
## End-to-end run in a REAL window with rendering (needs a display; CI/sandbox uses Xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility \
##       -s tests/e2e_rendered.gd -- /output/dir
## Boots the real boot scene, drives it with synthetic keyboard/mouse events through the
## engine input pipeline, takes screenshots, and exits non-zero on any failed check.

var out_dir := "/tmp/e2e"
var failed := 0
var checks := 0
var player  # untyped on purpose: Player's class pulls in autoloads at compile time
# Autoloads are not compile-time identifiers inside a -s main script; fetch by path.
var scene_manager: Node
var game_manager: Node
var registry: Node
var game_state: Node


func check(cond: bool, msg: String) -> void:
	checks += 1
	print("%s  %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		failed += 1


func key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func tap(code: Key) -> void:
	key(code, true)
	key(code, false)
	await frames(3)


## Presses E (finish typing, then continue) until the dialogue reaches `node`.
func advance_to_node(dm: Node, node: String) -> void:
	var taps := 0
	while dm.is_active() and dm.current().get("node") != node and taps < 8:
		await tap(KEY_E)
		taps += 1


func mouse(rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = rel
	ev.position = Vector2(640, 360)
	Input.parse_input_event(ev)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> float:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	var lum := 0.0
	var step := 7
	var n := 0
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			lum += img.get_pixel(x, y).get_luminance()
			n += 1
	return lum / maxf(n, 1)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame  # autoloads become ready
	scene_manager = root.get_node("/root/SceneManager")
	game_manager = root.get_node("/root/GameManager")
	registry = root.get_node("/root/PlayerRegistry")
	game_state = root.get_node("/root/GameState")
	_run.call_deferred()


func _run() -> void:
	print("Renderer: %s | display: %s" % [RenderingServer.get_video_adapter_name(), DisplayServer.get_name()])
	# --- boot the real entry scene -------------------------------------------------
	var boot := (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await frames(20)
	check(scene_manager.current_scene_path == "res://scenes/test/foundation_room.tscn", "boot scene hands off to the test room")
	check(game_manager.state == game_manager.State.PLAYING, "game state is PLAYING in the room")
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse is captured during play")
	player = registry.get_local()
	check(player != null, "local player registered")
	if player == null:
		quit(1)
		return
	await frames(30)
	check(player.is_on_floor(), "player standing on the floor")
	var boot_ns = root.get_node("/root/NarrativeState")
	var boot_ui = root.get_node("/root/NarrativeUI")
	check(boot_ns.objectives().size() == 1, "entering the room fired the intro event: first objective set")
	check(boot_ui.notifications.toast_texts().any(func(t: String) -> bool: return t.contains("NEW OBJECTIVE")), "a toast announced the objective")
	await shot("00_objective_and_toast")
	var lum_play := await shot("01_start")
	check(lum_play > 0.02, "rendered frame is not black (mean luminance %.3f)" % lum_play)

	# --- mouse look through the real input pipeline --------------------------------
	var yaw0: float = player.rotation.y
	var pitch0: float = player.head.rotation.x
	mouse(Vector2(200, 0))
	await frames(4)
	check(absf(player.rotation.y - yaw0) > 0.1, "horizontal mouse motion turns the player (%.2f rad)" % (player.rotation.y - yaw0))
	mouse(Vector2(0, 120))
	await frames(4)
	check(absf(player.head.rotation.x - pitch0) > 0.1, "vertical mouse motion tilts the camera (%.2f rad)" % (player.head.rotation.x - pitch0))
	await shot("02_looking_away")
	mouse(Vector2(-200, 0))
	mouse(Vector2(0, -120))
	await frames(4)
	check(absf(player.rotation.y - yaw0) < 0.01 and absf(player.head.rotation.x - pitch0) < 0.01, "opposite motion restores the view")

	# --- walk with W / run with Shift ------------------------------------------------
	var z0: float = player.global_position.z
	key(KEY_W, true)
	await frames(15)
	key(KEY_W, false)
	var walked: float = z0 - player.global_position.z
	check(walked > 0.2, "W walks forward (%.2f m)" % walked)
	await frames(20)
	player.global_position = Vector3(0, 0.05, 3.5)
	player.velocity = Vector3.ZERO
	await frames(5)
	var z1: float = player.global_position.z
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	await frames(15)
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	var ran: float = z1 - player.global_position.z
	check(ran > walked * 1.3, "Shift+W runs faster (%.2f m vs %.2f m)" % [ran, walked])

	# ================= PHASE 2: narrative slice, played with real key presses =================
	var ui = root.get_node("/root/NarrativeUI")
	var dm = root.get_node("/root/DialogueManager")
	var ns = root.get_node("/root/NarrativeState")
	var hud = current_scene.get_node("HUD")
	var term = current_scene.get_node("TestTerminal")

	check(ns.objectives()[0]["id"] == "demo_find_scout", "the first objective is the demo one")
	check(ui.objectives_view.lines() == ["[ ] Find the crew member and talk to them."], "objectives HUD shows it")

	# --- A. talk to the crew member --------------------------------------------------
	player.global_position = Vector3(-2.5, 0.05, -0.2)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await frames(12)
	check(hud.prompt_text() == "[E] Talk", "HUD prompt for the crew member ('%s')" % hud.prompt_text())
	await shot("03_facing_crew_member")
	# Sample the typewriter at the instant the line is shown (software-rendered frames are
	# slow enough to finish a line between two frames, so a later check would be flaky).
	var typing_when_shown := [false]
	root.get_node("/root/EventBus").subscribe(&"dialogue_node", func(_p: Dictionary) -> void:
		typing_when_shown[0] = ui.dialogue_view.is_typing())
	await tap(KEY_E)
	check(dm.is_active() and ui.dialogue_view.is_showing(), "pressing E started the conversation")
	check(typing_when_shown[0], "the line starts typing itself out (typewriter)")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse released while talking")
	var held: Vector3 = player.global_position
	key(KEY_W, true)
	await frames(15)
	key(KEY_W, false)
	check(player.global_position.is_equal_approx(held), "player cannot walk away mid-conversation")
	check(ui.dialogue_view.speaker_text().contains("ZEKE MARLOWE"), "speaker named from character data ('%s')" % ui.dialogue_view.speaker_text())
	await shot("06_dialogue_line")
	await advance_to_node(dm, "ask")
	check(dm.current()["node"] == "ask" and dm.current()["choices"].size() == 3, "reached the choices; the terminal-gated choice is hidden (3 shown)")
	ui.dialogue_view.skip_typing()
	await frames(3)
	await shot("07_dialogue_choices")
	await tap(KEY_1)
	check(game_state.is_flag_true(&"demo_asked_ship"), "choosing option 1 set a story flag")
	check(dm.current()["node"] == "ship", "moved to the chosen branch")
	await advance_to_node(dm, "ask")
	check(dm.current()["node"] == "ask", "conversation looped back to the menu")
	ui.dialogue_view.skip_typing()
	await tap(KEY_3)
	check(not dm.is_active(), "choosing 'Nothing. See you.' ended the conversation")
	check(game_state.is_flag_true(&"dialogue_completed:demo_scout_intro") and game_state.is_flag_true(&"spoke_with:scout"), "completion + spoke_with flags set")
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse captured again after the conversation")
	var objs: Array = ns.objectives()
	check(objs.size() == 2 and objs[0]["completed"] and not objs[1]["completed"], "ending the talk completed objective 1 and added objective 2")
	check(ui.objectives_view.lines() == ["[x] Find the crew member and talk to them.", "[ ] Use the glowing terminal."], "HUD shows done + new objectives")

	# --- B. use the terminal -----------------------------------------------------------
	player.global_position = Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	await frames(12)
	check(player.interactor.focused == term, "crosshair ray focuses the terminal")
	check(hud.prompt_text() == "[E] Use terminal", "HUD prompt ('%s')" % hud.prompt_text())
	await tap(KEY_E)
	check(game_state.is_flag_true(term.used_flag_key()), "pressing E used the terminal")
	check(player.interactor.focused == null and hud.prompt_text() == "", "one-shot terminal stops being focusable; prompt clears")
	check(ns.is_recording_unlocked(&"demo_tape_black_box"), "the terminal event unlocked the recording")
	check(ns.objectives()[1]["completed"], "using the terminal completed objective 2 (conditional event)")
	check(ui.notifications.toast_texts().any(func(t: String) -> bool: return t.contains("RECORDING FOUND")), "toast: recording found")
	await shot("08_toasts")

	# --- C. archive + recording playback -----------------------------------------------
	await tap(KEY_TAB)
	check(ui.log_view.is_open() and ui.log_view.item_texts() == ["[NEW] DEMO: Flight deck fragment"], "Tab opened the archive listing the new recording")
	await shot("09_archive")
	var rec_btn: Button = null
	for b in ui.log_view._rec_box.get_children():
		if b is Button:
			rec_btn = b
	rec_btn.pressed.emit()
	await frames(3)
	check(ui.recording_view.is_open() and not ui.log_view.is_open(), "clicking the entry opened the recording player")
	await create_timer(4.0).timeout
	var transcript: String = ui.recording_view.transcript_text()
	check(transcript.contains("WREN CALLOWAY") and transcript.contains("Bit chilly"), "transcript is playing in real time with character names")
	await shot("10_recording_playing")
	ui.recording_view.player.advance(60.0)
	await frames(3)
	check(ns.was_recording_played(&"demo_tape_black_box") and ui.recording_view.transcript_text().contains("AUDIO CORRUPTION"), "playback finished: marked played, full transcript shown")
	await tap(KEY_ESCAPE)
	check(not ui.recording_view.is_open() and not game_manager.is_paused(), "Esc closed the player (and did not pause)")

	# --- D. data pad -> document -------------------------------------------------------
	player.global_position = Vector3(2.5, 0.05, -0.2)
	player.velocity = Vector3.ZERO
	await frames(12)
	check(hud.prompt_text() == "[E] Read data pad", "HUD prompt for the data pad ('%s')" % hud.prompt_text())
	await tap(KEY_E)
	check(ui.document_view.is_open() and ui.document_view.title_text().contains("Launch-day morale report"), "event opened the document")
	check(ns.is_document_read(&"demo_report_launch"), "opening it marked it read")
	await shot("11_document")
	await tap(KEY_ESCAPE)
	check(not ui.document_view.is_open(), "Esc closed the reader")

	# --- E. environmental storytelling trigger -----------------------------------------
	player.global_position = Vector3(4.5, 0.05, -4.5)
	player.velocity = Vector3.ZERO
	await frames(15)
	check(ns.is_document_found(&"demo_note_vent"), "walking into the vent area triggered the discovery")
	check(ui.notifications.toast_texts().any(func(t: String) -> bool: return t.contains("vent grille")), "environmental toast shown")

	# --- F. second conversation: conditional dialogue ------------------------------------
	player.global_position = Vector3(-2.5, 0.05, -0.2)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await frames(12)
	await tap(KEY_E)
	check(dm.is_active() and dm.current()["node"] == "again", "second visit starts at the 'back again' line")
	await advance_to_node(dm, "ask")
	check(dm.current()["node"] == "ask" and dm.current()["choices"].size() == 4, "now 4 choices: the terminal-gated option appeared")
	ui.dialogue_view.skip_typing()
	await frames(3)
	await shot("12_conditional_choice")
	await tap(KEY_3)
	check(game_state.is_flag_true(&"demo_scout_noticed_archive"), "picking the gated option set its flag")
	check(ns.is_document_found(&"demo_classified_stub"), "flag change event unlocked the classified record")
	var guard := 0
	while dm.is_active() and guard < 6:
		await tap(KEY_E)
		guard += 1
	check(not dm.is_active(), "conversation ended")
	await tap(KEY_TAB)
	check(ui.log_view.item_count() == 4, "archive lists 1 recording + 3 documents")
	await shot("13_archive_full")
	var classified_btn: Button = null
	for b in ui.log_view._doc_box.get_children():
		if b is Button and b.text.contains("Restricted access"):
			classified_btn = b
	classified_btn.pressed.emit()
	await frames(3)
	check(ui.document_view.banner_text().contains("CLASSIFIED"), "classified record shows its banner")
	await shot("14_classified_document")
	await tap(KEY_ESCAPE)

	# --- G. save, wipe, load ----------------------------------------------------------
	var saves = root.get_node("/root/SaveSystem")
	saves.save_dir = "user://e2e_saves"
	check(saves.save_slot(1) == OK, "saved the game")
	game_state.reset()
	ns.reset()
	check(not ns.is_recording_unlocked(&"demo_tape_black_box") and ns.objectives().is_empty(), "everything wiped")
	check(saves.load_slot(1) == OK, "loaded the game")
	await frames(3)
	check(ns.was_recording_played(&"demo_tape_black_box") and ns.is_document_read(&"demo_report_launch") and ns.is_document_found(&"demo_classified_stub"), "recordings and documents restored")
	check(ns.objectives().size() == 2 and ns.is_event_done(&"demo_ev_terminal"), "objectives and completed events restored")
	check(game_state.get_flag(&"demo_asked_ship") == true and game_state.is_flag_true(&"dialogue_completed:demo_scout_intro"), "story flags restored")
	check(ui.objectives_view.lines().size() == 2, "objectives HUD refreshed after load")
	saves.delete_slot(1)
	await shot("15_after_load")

	# --- pause / resume with Esc ------------------------------------------------------
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await frames(5)
	check(game_manager.is_paused() and paused, "Esc pauses the game")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse is released while paused")
	var menu_visible := false
	for c in game_manager.get_children():
		if c.has_method("is_menu_visible"):
			menu_visible = c.is_menu_visible()
	check(menu_visible, "pause menu is visible")
	var pz: Vector3 = player.global_position
	key(KEY_W, true)
	await frames(15)
	key(KEY_W, false)
	check(player.global_position.is_equal_approx(pz), "player frozen while paused, even with W held")
	var lum_pause := await shot("04_paused")
	check(lum_pause < lum_play * 0.7, "pause overlay dims the scene (%.3f vs %.3f)" % [lum_pause, lum_play])
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await frames(5)
	check(not game_manager.is_paused() and not paused, "second Esc resumes")
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse captured again after resume")
	var z2: float = player.global_position.z
	key(KEY_W, true)
	await frames(15)
	key(KEY_W, false)
	check(player.global_position.z < z2 - 0.1, "movement works again after resume")
	await shot("05_resumed")

	# --- pause menu buttons -----------------------------------------------------------
	game_manager.pause()
	await frames(3)
	var resume_btn: Button = null
	for c in game_manager.get_children():
		if c.has_method("is_menu_visible"):
			resume_btn = c.get_node("Root/Center/Box/ResumeButton")
	check(resume_btn != null and resume_btn.has_focus(), "Resume button is focused when the menu opens")
	resume_btn.pressed.emit()
	await frames(3)
	check(not game_manager.is_paused(), "Resume button resumes the game")

	# --- the debugger-visible error log must be empty ---------------------------------
	check(game_manager.recent_errors().is_empty(), "no errors recorded by the game during the whole run")
	print("\n%d checks, %d failed" % [checks, failed])
	quit(1 if failed > 0 else 0)
