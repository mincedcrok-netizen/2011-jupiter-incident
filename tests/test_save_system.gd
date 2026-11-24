extends TestCase

const DIR := "user://test_saves"


func before_each() -> void:
	SaveSystem.save_dir = DIR
	_wipe()
	GameState.reset()
	EventBus.clear()


func after_each() -> void:
	_wipe()
	SaveSystem.save_dir = SaveSystem.DEFAULT_SAVE_DIR


func _wipe() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute("%s/%s" % [DIR, f])


func test_save_then_load_restores_flags() -> void:
	GameState.set_flag(&"tape_1", true)
	GameState.set_flag(&"deaths", 2)
	eq(SaveSystem.save_slot(1, {"label": "t"}), OK, "save ok")
	GameState.reset()
	eq(SaveSystem.load_slot(1), OK, "load ok")
	eq(GameState.get_flag(&"tape_1"), true, "bool flag restored")
	eq(GameState.get_flag(&"deaths"), 2, "int flag restored")


func test_slots_listing_and_delete() -> void:
	SaveSystem.save_slot(0)
	SaveSystem.save_slot(3)
	eq(SaveSystem.list_slots(), [0, 3] as Array[int], "lists saved slots")
	eq(SaveSystem.delete_slot(3), OK, "delete ok")
	ok(not SaveSystem.slot_exists(3), "slot gone")


func test_invalid_slot_numbers() -> void:
	eq(SaveSystem.save_slot(-1), ERR_INVALID_PARAMETER, "negative slot")
	eq(SaveSystem.load_slot(100), ERR_INVALID_PARAMETER, "too-large slot")


func test_load_missing_slot() -> void:
	eq(SaveSystem.load_slot(7), ERR_FILE_NOT_FOUND, "missing file")


func test_corrupt_save_is_rejected_without_changing_state() -> void:
	GameState.set_flag(&"live", true)
	SaveSystem.save_slot(2)
	var f := FileAccess.open(SaveSystem.slot_path(2), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	eq(SaveSystem.load_slot(2), ERR_FILE_CORRUPT, "corrupt reported")
	eq(GameState.get_flag(&"live"), true, "live state untouched")


func test_corrupt_primary_falls_back_to_backup() -> void:
	GameState.set_flag(&"gen", 1)
	SaveSystem.save_slot(4)          # generation 1
	GameState.set_flag(&"gen", 2)
	SaveSystem.save_slot(4)          # generation 2; gen 1 moves to .bak
	var f := FileAccess.open(SaveSystem.slot_path(4), FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	eq(SaveSystem.load_slot(4), OK, "falls back to backup")
	eq(GameState.get_flag(&"gen"), 1, "backup generation loaded")


func test_newer_version_refused() -> void:
	var f := FileAccess.open("%s/slot_5.json" % DIR, FileAccess.WRITE) \
		if DirAccess.make_dir_recursive_absolute(DIR) == OK else null
	f.store_string(JSON.stringify({"version": 999, "data": {}}))
	f.close()
	eq(SaveSystem.load_slot(5), ERR_UNAVAILABLE, "future version refused")


func test_bad_provider_data_rolls_back() -> void:
	GameState.set_flag(&"before", true)
	var f_ok := SaveSystem.save_slot(6)
	eq(f_ok, OK, "baseline saved")
	# Hand-write a save whose game_state section is invalid.
	var f := FileAccess.open(SaveSystem.slot_path(6), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "data": {"game_state": {"flags": {"x": [1]}}}}))
	f.close()
	GameState.set_flag(&"after_save", true)
	eq(SaveSystem.load_slot(6), ERR_INVALID_DATA, "invalid data reported")
	eq(GameState.get_flag(&"after_save"), true, "rolled back to pre-load state")


func test_missing_provider_section_resets_that_system() -> void:
	var f_dir := DirAccess.make_dir_recursive_absolute(DIR)
	ok(f_dir == OK, "dir created")
	var f := FileAccess.open("%s/slot_8.json" % DIR, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "data": {}}))
	f.close()
	GameState.set_flag(&"stale", true)
	eq(SaveSystem.load_slot(8), OK, "loads")
	ok(not GameState.has_flag(&"stale"), "systems absent from save are reset to defaults")


func test_events_published() -> void:
	var seen := []
	EventBus.subscribe(Events.SAVE_COMPLETED, func(p: Dictionary) -> void: seen.append(p["slot"]))
	SaveSystem.save_slot(9)
	eq(seen, [9], "save event with slot")
