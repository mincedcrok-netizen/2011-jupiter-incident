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

	# --- interact with the terminal --------------------------------------------------
	player.global_position = Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	await frames(10)
	var term = current_scene.get_node("TestTerminal")
	check(player.interactor.focused == term, "crosshair ray focuses the terminal")
	var hud = current_scene.get_node("HUD")
	check(hud.prompt_text() == "[E] Use terminal", "HUD shows the interaction prompt ('%s')" % hud.prompt_text())
	var lum_focus := await shot("03_facing_terminal")
	check(lum_focus > 0.02, "frame with prompt renders (luminance %.3f)" % lum_focus)
	key(KEY_E, true)
	await frames(2)
	key(KEY_E, false)
	await frames(5)
	check(game_state.get_flag(term.used_flag_key(), false) == true, "pressing E uses the terminal")
	check(player.interactor.focused == null, "used one-shot terminal no longer focusable")
	check(hud.prompt_text() == "", "HUD prompt clears once the terminal is used")

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
