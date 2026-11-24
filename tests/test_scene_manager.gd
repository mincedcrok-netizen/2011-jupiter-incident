extends TestCase


func before_each() -> void:
	EventBus.clear()
	PlayerRegistry.clear()


func after_each() -> void:
	if tree.current_scene != null:
		tree.current_scene.queue_free()
		await tree.process_frame
	PlayerRegistry.clear()


func test_missing_scene_fails_cleanly() -> void:
	var seen := []
	EventBus.subscribe(Events.SCENE_CHANGE_FAILED, func(e: Dictionary) -> void: seen.append(e))
	eq(SceneManager.change_scene("res://nope/does_not_exist.tscn"), ERR_FILE_NOT_FOUND, "missing -> error")
	eq(SceneManager.change_scene(""), ERR_FILE_NOT_FOUND, "empty path -> error")
	eq(seen.size(), 2, "failure events published")
	ok(not SceneManager.is_changing(), "manager not stuck busy after failure")


func test_non_scene_resource_rejected() -> void:
	eq(SceneManager.change_scene("res://project.godot"), ERR_FILE_NOT_FOUND, "non-resource rejected")


func test_successful_change_completes_and_publishes() -> void:
	var done := []
	EventBus.subscribe(Events.SCENE_CHANGE_COMPLETED, func(e: Dictionary) -> void: done.append(e["path"]))
	var path := "res://scenes/test/foundation_room.tscn"
	eq(SceneManager.change_scene(path), OK, "change accepted")
	eq(SceneManager.change_scene(path), ERR_BUSY, "re-entrant change refused while busy")
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	eq(done, [path], "completed event published once")
	eq(SceneManager.current_scene_path, path, "current path tracked")
	ok(tree.current_scene != null and tree.current_scene.name == "FoundationRoom", "room is the current scene")
	ok(not SceneManager.is_changing(), "not busy afterwards")


func test_boot_scene_hands_off_to_first_scene() -> void:
	var boot := (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	tree.root.add_child(boot)
	for i in 6:
		await tree.process_frame
	eq(SceneManager.current_scene_path, "res://scenes/test/foundation_room.tscn", "boot loaded the first scene")
	boot.queue_free()
