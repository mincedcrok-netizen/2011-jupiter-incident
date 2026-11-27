extends ShipTestCase


func test_doors_start_in_the_right_state() -> void:
	for id in ["bridge", "quarters", "supply", "engineering"]:
		var d := door(id)
		ok(d != null and not d.is_open and not d.is_locked(), "%s starts closed and unlocked" % id)
	ok(door("section_b").is_locked() and not door("section_b").is_open, "Section B starts locked")
	ok(door("engine_core").is_locked() and door("engine_core").sealed, "engine core is sealed")


func test_opening_a_door_by_interaction_updates_prompt_state_and_collision() -> void:
	var d := door("bridge")
	eq(d.prompt_text, "Open: Command Bridge", "closed prompt names the destination")
	ok(d.try_interact(player), "interaction accepted")
	ok(d.is_open, "door is open")
	eq(d.prompt_text, "Close door", "prompt now offers to close it")
	await physics(2)
	ok(d._blocker_shape.disabled, "physical blocker is removed while open")
	ok(d.try_interact(player), "interact again")
	ok(not d.is_open, "door closed again")
	await physics(2)
	ok(not d._blocker_shape.disabled, "blocker is back when closed")


func test_closed_door_blocks_the_player_and_open_door_lets_them_through() -> void:
	teleport(Vector3(0, 0.05, -16), 0)
	await physics(4)
	ok(not await walk_to(Vector3(0, 0.05, -24), 0.7, 240), "a closed door blocks the way")
	ok(player.global_position.z > -19.5, "player stopped at the door (z=%.2f)" % player.global_position.z)
	door("bridge").try_interact(player)
	await physics(3)
	ok(await walk_to(Vector3(0, 0.05, -24)), "after opening, the player walks through into the bridge")
	ok(room("bridge").contains_point(player.global_position), "and is inside the bridge")


func test_locked_door_refuses_with_feedback_until_a_flag_releases_it() -> void:
	var d := door("section_b")
	var notes := capture(Events.NOTIFICATION)
	var used := capture(Events.INTERACTED)
	eq(d.prompt_text, "Locked: Section B", "locked prompt")
	ok(d.try_interact(player), "the attempt is an interaction (narrative events can react)")
	ok(not d.is_open, "but the door stays shut")
	eq(used.size(), 1, "INTERACTED still published for locked doors")
	ok(notes.size() == 1 and String(notes[0]["text"]).contains("LOCKED"), "player is told why")
	ok(not d.set_open(true), "set_open refuses while locked")
	GameState.set_flag(&"door_unlocked:section_b", true)
	ok(not d.is_locked(), "flag released the lock")
	eq(d.prompt_text, "Open: Section B", "prompt follows the lock state")
	d.try_interact(player)
	ok(d.is_open, "now it opens")


func test_sealed_door_never_opens() -> void:
	var d := door("engine_core")
	GameState.set_flag(&"door_unlocked:engine_core", true)
	ok(d.is_locked(), "a flag cannot unlock a sealed door")
	ok(not d.set_open(true, false), "set_open refused")
	var notes := capture(Events.NOTIFICATION)
	d.try_interact(player)
	ok(not d.is_open and notes.size() == 1 and String(notes[0]["text"]).contains("ACCESS DENIED"), "denial message shown")


func test_a_door_will_not_close_on_the_player() -> void:
	var d := door("quarters")
	d.set_open(true, false)
	teleport(Vector3(-2.5, 0.05, -8), 90)  # standing in the doorway
	await physics(4)
	ok(d.is_doorway_occupied(), "sensor sees the player")
	var notes := capture(Events.NOTIFICATION)
	d.try_interact(player)
	ok(d.is_open, "door refused to close")
	ok(notes.size() == 1 and String(notes[0]["text"]).contains("blocked"), "player is told the doorway is blocked")
	teleport(Vector3(-6, 0.05, -8), 90)
	await physics(4)
	ok(d.set_open(false, false) and not d.is_open, "closes once the doorway is clear")


func test_player_can_focus_a_door_and_the_hud_prompt_updates_after_use() -> void:
	teleport(Vector3(0, 0.05, -18.2), 0)
	await physics(6)
	var d := door("bridge")
	ok(player.interactor.focused == d, "ray focuses the door")
	var hud := deck.get_node("HUD")
	eq(hud.prompt_text(), "[E] Open: Command Bridge", "HUD shows the door prompt")
	ok(player.interactor.interact(), "interact through the real interactor")
	eq(hud.prompt_text(), "[E] Close door", "prompt refreshed immediately after use")
	await physics(3)
	ok(player.interactor.focused == d, "an open door can still be focused (to close it)")


func test_unlocking_survives_save_and_load() -> void:
	SaveSystem.save_dir = "user://test_saves_ship"
	GameState.set_flag(&"door_unlocked:section_b", true)
	eq(SaveSystem.save_slot(1), OK, "saved")
	GameState.reset()
	ok(door("section_b").is_locked(), "locked again after reset")
	eq(SaveSystem.load_slot(1), OK, "loaded")
	ok(not door("section_b").is_locked(), "unlock restored")
	eq(door("section_b").prompt_text, "Open: Section B", "prompt refreshed by the flag change")
	SaveSystem.delete_slot(1)
	SaveSystem.save_dir = SaveSystem.DEFAULT_SAVE_DIR
