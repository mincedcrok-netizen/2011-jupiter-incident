extends NarrativeTestCase


func test_dialogue_begins_and_progresses_to_completion() -> void:
	var nodes := capture(Events.DIALOGUE_NODE)
	var started := capture(Events.DIALOGUE_STARTED)
	var ended := capture(Events.DIALOGUE_ENDED)
	ok(DialogueManager.start(&"test_dialogue_basic"), "start accepted")
	ok(DialogueManager.is_active(), "active")
	eq(started.size(), 1, "STARTED published")
	ok(GameManager.is_modal_open(), "dialogue holds the player in a modal")
	eq(DialogueManager.current()["text"], "FIXTURE one.", "first line shown")
	eq(DialogueManager.current()["speaker"], "test_speaker_a", "speaker reported")
	ok(GameState.is_flag_true(&"spoke_with:test_speaker_a"), "speaking records spoke_with:<character>")
	ok(DialogueManager.advance(), "advance")
	eq(DialogueManager.current()["node"], "n3", "n2 skipped (needs test_flag), n3 shown")
	DialogueManager.advance()
	eq(DialogueManager.current()["node"], "n4", "reached the choice node")
	eq(DialogueManager.current()["choices"], ["Left", "Leave"], "'Right' hidden: its condition is unmet")
	ok(not DialogueManager.advance(), "cannot advance past a choice")
	ok(DialogueManager.choose(0), "choose Left")
	eq(GameState.get_flag(&"test_picked"), "left", "choice set_flags applied (string)")
	eq(DialogueManager.current()["node"], "left", "moved to the chosen branch")
	ok(GameState.is_flag_true(&"test_left_seen"), "node set_flags applied (bool)")
	eq(GameState.get_flag(&"test_count"), 3, "numeric flag stored as int")
	DialogueManager.advance()
	ok(not DialogueManager.is_active(), "dialogue ended")
	ok(not GameManager.is_modal_open(), "modal released")
	ok(GameState.is_flag_true(&"dialogue_completed:test_dialogue_basic"), "completion flag set")
	eq(ended.size(), 1, "ENDED published once")
	eq(ended[0]["completed"], true, "reported as completed")
	eq(nodes.size(), 4, "one NODE event per displayed line")


func test_conditions_change_the_path_and_choices() -> void:
	GameState.set_flag(&"test_flag", true)
	GameState.set_flag(&"test_right_ok", true)
	DialogueManager.start(&"test_dialogue_basic")
	DialogueManager.advance()
	eq(DialogueManager.current()["node"], "n2", "flag set: n2 is shown")
	DialogueManager.advance()
	eq(DialogueManager.current()["node"], "n4", "flag set: n3 is skipped")
	eq(DialogueManager.current()["choices"], ["Left", "Right", "Leave"], "all three choices visible")
	DialogueManager.choose(1)
	eq(DialogueManager.current()["node"], "right", "Right branch reachable once its flag is set")


func test_leave_choice_ends_the_conversation_as_completed() -> void:
	DialogueManager.start(&"test_dialogue_basic")
	DialogueManager.advance()
	DialogueManager.advance()
	DialogueManager.choose(1)  # "Leave" is index 1 when Right is hidden
	ok(not DialogueManager.is_active(), "ended")
	ok(GameState.is_flag_true(&"dialogue_completed:test_dialogue_basic"), "counts as completed")


func test_invalid_calls_are_refused_safely() -> void:
	ok(not DialogueManager.choose(0), "choose with nothing active")
	ok(not DialogueManager.advance(), "advance with nothing active")
	ok(not DialogueManager.start(&"does_not_exist"), "unknown dialogue refused")
	eq(GameManager.recent_errors().size(), 1, "and reported")
	DialogueManager.start(&"test_dialogue_basic")
	ok(not DialogueManager.start(&"test_dialogue_chain"), "cannot start a second while one is active")
	eq(String(DialogueManager.active_id), "test_dialogue_basic", "original conversation untouched")
	DialogueManager.advance()
	DialogueManager.advance()
	ok(not DialogueManager.choose(-1), "negative index")
	ok(not DialogueManager.choose(99), "index past the end")
	ok(DialogueManager.is_active(), "still active after bad choices")


func test_abort_ends_without_completion() -> void:
	var ended := capture(Events.DIALOGUE_ENDED)
	DialogueManager.start(&"test_dialogue_basic")
	DialogueManager.abort()
	ok(not DialogueManager.is_active(), "aborted")
	ok(not GameState.is_flag_true(&"dialogue_completed:test_dialogue_basic"), "no completion flag")
	eq(ended[0]["completed"], false, "reported as not completed")
	ok(not GameManager.is_modal_open(), "modal released")


func test_condition_loop_cannot_hang() -> void:
	ok(DialogueManager.start(&"test_dialogue_loop"), "start accepted")
	ok(not DialogueManager.is_active(), "guard ended the conversation")
	ok(not GameState.is_flag_true(&"dialogue_completed:test_dialogue_loop"), "not marked completed")
	eq(GameManager.recent_errors().size(), 1, "reported once")


func test_choice_node_with_no_visible_choices_does_not_trap_the_player() -> void:
	DialogueManager.start(&"test_dialogue_deadend")
	eq(DialogueManager.current()["choices"], [] as Array[String], "no choices offered")
	ok(DialogueManager.advance(), "advance still works")
	ok(not DialogueManager.is_active(), "and ends it")


func test_special_speakers_and_chain_flags() -> void:
	DialogueManager.start(&"test_dialogue_chain")
	ok(GameState.is_flag_true(&"test_chain_started"), "set_flags on the first node")
	eq(DialogueManager.current()["speaker"], "narrator", "narrator speaker allowed")
	DialogueManager.advance()
	eq(DialogueManager.current()["speaker"], "system", "system speaker allowed")
	DialogueManager.advance()
	ok(not DialogueManager.is_active(), "ends after the last node")


func test_loading_a_save_aborts_a_conversation_in_progress() -> void:
	DialogueManager.start(&"test_dialogue_basic")
	EventBus.publish(Events.LOAD_COMPLETED, {"slot": 1})
	ok(not DialogueManager.is_active(), "stale conversation dropped on load")
	ok(not GameManager.is_modal_open(), "player released")


func test_ended_handler_can_start_the_next_conversation() -> void:
	EventBus.subscribe(Events.DIALOGUE_ENDED, func(p: Dictionary) -> void:
		if p["id"] == &"test_dialogue_chain":
			DialogueManager.start(&"test_dialogue_basic"))
	DialogueManager.start(&"test_dialogue_chain")
	DialogueManager.advance()
	DialogueManager.advance()
	ok(DialogueManager.is_active(), "next conversation started from inside the ENDED handler")
	eq(String(DialogueManager.active_id), "test_dialogue_basic", "the right one")
	ok(GameManager.is_modal_open(), "and the modal is held again")


func test_second_visit_replays_with_updated_flags() -> void:
	DialogueManager.start(&"test_dialogue_basic")
	DialogueManager.abort()
	ok(GameState.is_flag_true(&"spoke_with:test_speaker_a"), "first visit recorded")
	GameState.set_flag(&"test_flag", true)
	DialogueManager.start(&"test_dialogue_basic")
	DialogueManager.advance()
	eq(DialogueManager.current()["node"], "n2", "same conversation, different path on the second visit")
