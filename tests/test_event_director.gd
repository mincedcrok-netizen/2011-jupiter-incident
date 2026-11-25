extends NarrativeTestCase

const SAVE_DIR := "user://test_saves_events"


func after_each() -> void:
	SaveSystem.save_dir = SaveSystem.DEFAULT_SAVE_DIR
	super.after_each()


func _interact(id: String) -> void:
	EventBus.publish(Events.INTERACTED, {"interaction_id": StringName(id), "actor_id": &"player_1", "peer_id": 1})


func test_interaction_event_runs_all_actions_in_order() -> void:
	var notes := capture(Events.NOTIFICATION)
	var fired := capture(Events.NARRATIVE_EVENT_FIRED)
	_interact("test_door")
	eq(GameState.get_flag(&"test_ev_once_ran"), 1, "set_flag action (int)")
	eq(NarrativeState.objectives().size(), 1, "set_objective action")
	eq(notes.size(), 1, "notify action")
	eq(fired[0]["id"], &"test_ev_once", "NARRATIVE_EVENT_FIRED published")
	ok(NarrativeState.is_event_done(&"test_ev_once"), "one-shot recorded")


func test_one_shot_fires_once_repeatable_fires_every_time() -> void:
	var notes := capture(Events.NOTIFICATION)
	_interact("test_door")
	_interact("test_door")
	eq(notes.size(), 1, "once: second interaction ignored")
	_interact("test_repeat")
	_interact("test_repeat")
	_interact("test_repeat")
	eq(notes.size(), 4, "once=false fires each time")


func test_non_matching_payloads_do_nothing() -> void:
	_interact("some_other_door")
	EventBus.publish(Events.INTERACTED, {})
	ok(not GameState.has_flag(&"test_ev_once_ran"), "nothing fired")


func test_flag_conditions_gate_conditional_events() -> void:
	var enter := func() -> void: EventBus.publish(Events.AREA_ENTERED, {"trigger_id": "test_zone", "peer_id": 1})
	enter.call()
	ok(not NarrativeState.is_recording_unlocked(&"test_recording_cassette"), "requires unmet: nothing happens")
	ok(not NarrativeState.is_event_done(&"test_ev_cond"), "and the one-shot is NOT consumed by a failed attempt")
	GameState.set_flag(&"test_gate", true)
	GameState.set_flag(&"test_blocker", true)
	enter.call()
	ok(not NarrativeState.is_recording_unlocked(&"test_recording_cassette"), "excludes flag blocks it")
	GameState.clear_flag(&"test_blocker")
	enter.call()
	ok(NarrativeState.is_recording_unlocked(&"test_recording_cassette"), "fires once conditions hold: recording unlocked")
	ok(NarrativeState.is_document_found(&"test_doc_report"), "document found")
	eq(NarrativeState.get_character_state(&"test_speaker_a"), "away", "character state changed")


func test_events_chain_through_flag_changes() -> void:
	GameState.set_flag(&"test_a", true)
	ok(GameState.is_flag_true(&"test_b") and GameState.is_flag_true(&"test_c"), "a -> b -> c")


func test_runaway_chain_is_stopped_by_the_depth_guard() -> void:
	EventBus.publish(Events.NOTIFICATION, {"text": "loop"})
	ok(EventDirector._depth == 0, "depth counter unwound after the guard tripped")
	var tripped := false
	for e in GameManager.recent_errors():
		if e["context"] == "event_director":
			tripped = true
	ok(tripped, "guard reported the runaway chain")


func test_event_can_start_a_dialogue() -> void:
	_interact("test_talk")
	ok(DialogueManager.is_active() and DialogueManager.active_id == &"test_dialogue_chain", "dialogue started by an event")


func test_matching_ignores_stringname_vs_string() -> void:
	EventBus.publish(Events.INTERACTED, {"interaction_id": "test_door"})  # plain String
	ok(GameState.has_flag(&"test_ev_once_ran"), "String payload matches")


func test_one_shot_state_survives_save_and_load() -> void:
	SaveSystem.save_dir = SAVE_DIR
	var notes := capture(Events.NOTIFICATION)
	_interact("test_door")
	SaveSystem.save_slot(1)
	NarrativeState.reset()
	GameState.reset()
	SaveSystem.load_slot(1)
	notes.clear()
	_interact("test_door")
	eq(notes.size(), 0, "a loaded game does not replay an event that already happened")
	SaveSystem.delete_slot(1)


func test_failing_actions_are_reported_and_do_not_stop_later_actions() -> void:
	write_scratch("events", "bad.json", JSON.stringify([{"id": "bad", "canon": "test",
		"trigger": {"type": "interacted", "match": {"interaction_id": "bad_door"}},
		"actions": [{"type": "unlock_recording", "id": "ghost"}, {"type": "complete_objective", "id": "ghost"},
			{"type": "start_dialogue", "id": "ghost"}, {"type": "set_flag", "flag": "after_bad", "value": true}]}]))
	load_scratch()
	GameManager.clear_errors()
	_interact("bad_door")
	ok(GameState.is_flag_true(&"after_bad"), "the last action still ran")
	ok(GameManager.recent_errors().size() >= 3, "each failed action reported (got %d)" % GameManager.recent_errors().size())
