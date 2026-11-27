extends SceneTree
## Run: godot --headless --path . -s tests/run_tests.gd
## Exit code is 0 only if every check passes.

const SUITES := [
	"res://tests/test_event_bus.gd",
	"res://tests/test_game_state.gd",
	"res://tests/test_save_system.gd",
	"res://tests/test_settings.gd",
	"res://tests/test_player_registry.gd",
	"res://tests/test_player_and_interaction.gd",
	"res://tests/test_scene_manager.gd",
	"res://tests/test_game_manager.gd",
	"res://tests/test_narrative_data.gd",
	"res://tests/test_dialogue_manager.gd",
	"res://tests/test_narrative_state.gd",
	"res://tests/test_event_director.gd",
	"res://tests/test_recording_player.gd",
	"res://tests/test_narrative_ui.gd",
	"res://tests/test_room_and_boot.gd",
	"res://tests/test_hud.gd",
	"res://tests/test_ship_layout.gd",
	"res://tests/test_ship_doors.gd",
	"res://tests/test_ship_navigation.gd",
	"res://tests/test_ship_narrative.gd",
	"res://tests/test_ship_atmosphere.gd",
]


func _initialize() -> void:
	# In -s mode autoloads are added to the tree after _initialize; wait a frame
	# so every autoload has run _ready() before any test touches it.
	await process_frame
	var total_checks := 0
	var total_failed := 0
	for path: String in SUITES:
		var script := load(path) as GDScript
		if script == null:
			print("FAIL  cannot load suite %s" % path)
			total_failed += 1
			continue
		for m: Dictionary in script.get_script_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			var t: TestCase = script.new()
			t.tree = self
			await t.before_each()
			await t.call(mname)
			await t.after_each()
			total_checks += t.checks
			var label := "%s::%s" % [path.get_file(), mname]
			if t.failures.is_empty():
				print("PASS  %s (%d checks)" % [label, t.checks])
			else:
				total_failed += t.failures.size()
				for f in t.failures:
					print("FAIL  %s -- %s" % [label, f])
	print("\n%d checks, %d failed" % [total_checks, total_failed])
	quit(1 if total_failed > 0 else 0)
