extends SceneTree
## Two-process persistence check. Run once with `-- write`, then again (a fresh Godot
## process) with `-- verify`. Uses scratch paths so real user data is untouched.
##   godot --headless --path . -s tests/restart_persistence.gd -- write
##   godot --headless --path . -s tests/restart_persistence.gd -- verify

var failed := 0


func check(cond: bool, msg: String) -> void:
	print("%s  %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		failed += 1


func _initialize() -> void:
	# Safety net: a script error must never leave a headless process running forever.
	create_timer(60.0).timeout.connect(func() -> void: quit(2))
	await process_frame
	var settings: Node = root.get_node("/root/Settings")
	var saves: Node = root.get_node("/root/SaveSystem")
	var state: Node = root.get_node("/root/GameState")
	var narr: Node = root.get_node("/root/NarrativeDatabase")
	var ns: Node = root.get_node("/root/NarrativeState")
	settings.config_path = "user://restart_test_settings.cfg"
	saves.save_dir = "user://restart_test_saves"
	narr.data_root = "res://tests/fixtures/data"
	narr.include_test_content = true
	narr.load_all()
	var phase := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	match phase:
		"write":
			settings.set_value("controls", "mouse_sensitivity", 2.5)
			settings.set_value("audio", "master", 0.4)
			settings.set_binding(&"interact", KEY_F)
			check(settings.save_settings() == OK, "settings written")
			state.set_flag(&"chapter", 3)
			state.set_flag(&"met_crew", true)
			ns.unlock_recording(&"test_recording_cassette")
			ns.mark_recording_played(&"test_recording_cassette")
			ns.find_document(&"test_doc_report")
			ns.mark_document_read(&"test_doc_report")
			ns.set_character_state(&"test_speaker_a", "away")
			ns.set_objective("o1", "Persist me")
			ns.set_objective("o2", "Still open")
			ns.complete_objective("o1")
			ns.mark_event_done(&"test_ev_once")
			state.set_flag(&"test_picked", "left")
			check(saves.save_slot(2, {"label": "restart test"}) == OK, "save slot written")
		"verify":
			settings.load_settings()
			check(is_equal_approx(settings.get_value("controls", "mouse_sensitivity"), 2.5), "mouse sensitivity survived restart")
			check(is_equal_approx(settings.get_value("audio", "master"), 0.4), "audio volume survived restart")
			var ev: Array = InputMap.action_get_events(&"interact")
			check(ev.size() == 1 and (ev[0] as InputEventKey).physical_keycode == KEY_F, "rebound Interact key (F) survived restart")
			check(saves.load_slot(2) == OK, "save slot loads in a new process")
			check(typeof(state.get_flag(&"chapter", null)) == TYPE_INT and state.get_flag(&"chapter") == 3, "int flag survived (as int)")
			check(state.is_flag_true(&"met_crew"), "bool flag survived")
			check(ns.is_recording_unlocked(&"test_recording_cassette") and ns.was_recording_played(&"test_recording_cassette"), "discovered + played recording survived")
			check(ns.is_document_found(&"test_doc_report") and ns.is_document_read(&"test_doc_report"), "found + read document survived")
			check(ns.get_character_state(&"test_speaker_a") == "away", "character state survived")
			check(ns.objectives() == [{"id": "o1", "text": "Persist me", "completed": true}, {"id": "o2", "text": "Still open", "completed": false}], "objectives (text, order, completion) survived")
			check(ns.is_event_done(&"test_ev_once"), "completed narrative event survived")
			check(state.get_flag(&"test_picked", "") == "left", "string decision flag survived")
			# clean up scratch data
			saves.delete_slot(2)
			DirAccess.remove_absolute("user://restart_test_settings.cfg")
		_:
			check(false, "usage: -- write | verify")
	quit(1 if failed > 0 else 0)
