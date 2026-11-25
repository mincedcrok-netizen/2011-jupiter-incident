extends NarrativeTestCase

const SAVE_DIR := "user://test_saves_narrative_state"


func after_each() -> void:
	SaveSystem.save_dir = SaveSystem.DEFAULT_SAVE_DIR
	super.after_each()


func test_recordings_are_discovered_gated_and_tracked() -> void:
	var found := capture(Events.RECORDING_UNLOCKED)
	var played := capture(Events.RECORDING_PLAYED)
	ok(not NarrativeState.unlock_recording(&"ghost"), "unknown recording refused")
	eq(GameManager.recent_errors().size(), 1, "and reported")
	ok(not NarrativeState.is_recording_unlocked(&"test_recording_cassette"), "starts locked")
	ok(not NarrativeState.mark_recording_played(&"test_recording_cassette"), "cannot play what is not found")
	ok(NarrativeState.unlock_recording(&"test_recording_cassette"), "unlock ok")
	ok(NarrativeState.unlock_recording(&"test_recording_cassette"), "unlocking again is harmless")
	eq(found.size(), 1, "discovery event published exactly once")
	ok(not NarrativeState.unlock_recording(&"test_recording_locked"), "gated recording refused without its flag")
	GameState.set_flag(&"test_gate", true)
	ok(NarrativeState.unlock_recording(&"test_recording_locked"), "gated recording unlocks once flag is set")
	ok(NarrativeState.mark_recording_played(&"test_recording_cassette"), "mark played")
	ok(NarrativeState.was_recording_played(&"test_recording_cassette"), "played tracked")
	eq(played.size(), 1, "played event published")
	var ids := []
	for r in NarrativeState.unlocked_recordings():
		ids.append(String(r.id))
	eq(ids, ["test_recording_cassette", "test_recording_locked"], "unlocked list sorted by id")


func test_documents_are_found_gated_and_read() -> void:
	var read := capture(Events.DOCUMENT_READ)
	ok(not NarrativeState.mark_document_read(&"test_doc_report"), "cannot read what is not found")
	ok(not NarrativeState.find_document(&"ghost"), "unknown document refused")
	ok(NarrativeState.find_document(&"test_doc_report"), "found")
	ok(not NarrativeState.is_document_read(&"test_doc_report"), "found is not read")
	ok(NarrativeState.mark_document_read(&"test_doc_report"), "read")
	ok(NarrativeState.mark_document_read(&"test_doc_report"), "reading twice is harmless")
	eq(read.size(), 1, "read event once")
	ok(not NarrativeState.find_document(&"test_doc_classified"), "classified document gated on a flag")
	GameState.set_flag(&"test_gate", true)
	ok(NarrativeState.find_document(&"test_doc_classified"), "found once the flag is set")
	eq(NarrativeState.found_documents().size(), 2, "listing")


func test_wrongly_typed_flags_never_count_as_discovered() -> void:
	GameState.set_flag(&"recording_unlocked:test_recording_cassette", "yes")
	GameState.set_flag(&"document_found:test_doc_report", 1)
	ok(not NarrativeState.is_recording_unlocked(&"test_recording_cassette"), "string flag is not an unlock")
	ok(not NarrativeState.is_document_found(&"test_doc_report"), "int flag is not a find")
	eq(NarrativeState.unlocked_recordings().size(), 0, "listing empty")


func test_character_states() -> void:
	var changed := capture(Events.CHARACTER_STATE_CHANGED)
	eq(NarrativeState.get_character_state(&"test_speaker_a"), "aboard", "initial state")
	eq(NarrativeState.get_character_state(&"ghost"), "", "unknown character -> empty")
	ok(NarrativeState.set_character_state(&"test_speaker_a", "away"), "valid change")
	eq(NarrativeState.get_character_state(&"test_speaker_a"), "away", "state updated")
	eq(changed[0], {"id": &"test_speaker_a", "state": "away", "old": "aboard"}, "event carries old and new")
	ok(NarrativeState.set_character_state(&"test_speaker_a", "away"), "same state is a no-op success")
	eq(changed.size(), 1, "no event for a no-op")
	ok(not NarrativeState.set_character_state(&"test_speaker_a", "teleported"), "undeclared state refused")
	ok(not NarrativeState.set_character_state(&"ghost", "aboard"), "unknown character refused")
	eq(NarrativeState.get_character_state(&"test_speaker_a"), "away", "refusals change nothing")
	GameState.set_flag(&"character_state:test_speaker_b", 42)
	eq(NarrativeState.get_character_state(&"test_speaker_b"), "aboard", "corrupt stored state falls back to the initial state")


func test_objectives() -> void:
	var ev := capture(Events.OBJECTIVE_CHANGED)
	ok(NarrativeState.set_objective("o1", "First"), "add")
	ok(NarrativeState.set_objective("o2", "Second"), "add another")
	ok(NarrativeState.set_objective("o1", "First (reworded)"), "reword")
	eq(NarrativeState.objectives().size(), 2, "reword does not duplicate")
	eq(ev.size(), 2, "events only for additions")
	ok(GameState.is_flag_true(&"objective_added:o1"), "flag usable in conditions")
	ok(NarrativeState.complete_objective("o1"), "complete")
	ok(NarrativeState.complete_objective("o1"), "completing twice is harmless")
	eq(ev.size(), 3, "one completion event")
	eq(ev[2]["kind"], "completed", "kind reported")
	ok(GameState.is_flag_true(&"objective_completed:o1"), "completion flag set")
	ok(not NarrativeState.complete_objective("ghost"), "unknown objective refused")
	ok(not NarrativeState.set_objective("", "x"), "empty id refused")
	ok(not NarrativeState.set_objective("x", "   "), "blank text refused")
	eq(NarrativeState.objectives()[0]["text"], "First (reworded)", "order and text kept")
	NarrativeState.objectives()[0]["text"] = "tampered"
	eq(NarrativeState.objectives()[0]["text"], "First (reworded)", "callers get copies")


func _build_progress() -> void:
	GameState.set_flag(&"test_gate", true)
	GameState.set_flag(&"story_choice", "went_left")
	NarrativeState.unlock_recording(&"test_recording_cassette")
	NarrativeState.mark_recording_played(&"test_recording_cassette")
	NarrativeState.unlock_recording(&"test_recording_locked")
	NarrativeState.find_document(&"test_doc_report")
	NarrativeState.mark_document_read(&"test_doc_report")
	NarrativeState.find_document(&"test_doc_classified")
	NarrativeState.set_character_state(&"test_speaker_a", "gone")
	NarrativeState.set_objective("o1", "First")
	NarrativeState.set_objective("o2", "Second")
	NarrativeState.complete_objective("o1")
	NarrativeState.mark_event_done(&"test_ev_once")
	DialogueManager.start(&"test_dialogue_chain")
	DialogueManager.advance()
	DialogueManager.advance()


func _assert_progress(label: String) -> void:
	eq(GameState.get_flag(&"story_choice"), "went_left", label + ": decision flag")
	ok(NarrativeState.was_recording_played(&"test_recording_cassette"), label + ": recording played")
	ok(NarrativeState.is_recording_unlocked(&"test_recording_locked"), label + ": recording discovered (unplayed)")
	ok(not NarrativeState.was_recording_played(&"test_recording_locked"), label + ": unplayed stays unplayed")
	ok(NarrativeState.is_document_read(&"test_doc_report"), label + ": document read")
	ok(NarrativeState.is_document_found(&"test_doc_classified") and not NarrativeState.is_document_read(&"test_doc_classified"), label + ": found-but-unread document")
	eq(NarrativeState.get_character_state(&"test_speaker_a"), "gone", label + ": character state")
	eq(NarrativeState.objectives(), [{"id": "o1", "text": "First", "completed": true}, {"id": "o2", "text": "Second", "completed": false}] as Array[Dictionary], label + ": objectives with completion and order")
	ok(NarrativeState.is_event_done(&"test_ev_once"), label + ": completed event")
	ok(GameState.is_flag_true(&"dialogue_completed:test_dialogue_chain"), label + ": completed dialogue")


func test_save_and_load_preserve_all_narrative_progress() -> void:
	SaveSystem.save_dir = SAVE_DIR
	_build_progress()
	_assert_progress("before save")
	eq(SaveSystem.save_slot(1), OK, "saved")
	GameState.reset()
	NarrativeState.reset()
	ok(not NarrativeState.is_recording_unlocked(&"test_recording_cassette"), "state really cleared")
	eq(NarrativeState.objectives().size(), 0, "objectives cleared")
	eq(SaveSystem.load_slot(1), OK, "loaded")
	_assert_progress("after load")
	SaveSystem.delete_slot(1)


func test_save_survives_a_json_round_trip_on_disk() -> void:
	SaveSystem.save_dir = SAVE_DIR
	_build_progress()
	SaveSystem.save_slot(2)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.slot_path(2)))
	ok(doc["data"].has("game_state") and doc["data"].has("narrative"), "save has separate modular sections")
	eq(doc["data"]["narrative"]["completed_events"], ["test_ev_once"], "readable, stable format")
	SaveSystem.delete_slot(2)


func test_loading_a_save_without_narrative_data_resets_it() -> void:
	SaveSystem.save_dir = SAVE_DIR
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(SaveSystem.slot_path(3), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "data": {"game_state": {"flags": {}}}}))
	f.close()
	NarrativeState.set_objective("stale", "Stale")
	eq(SaveSystem.load_slot(3), OK, "loads")
	eq(NarrativeState.objectives().size(), 0, "a save from before the narrative system starts with a clean slate")
	SaveSystem.delete_slot(3)


func test_corrupt_narrative_section_rolls_back_everything() -> void:
	SaveSystem.save_dir = SAVE_DIR
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(SaveSystem.slot_path(4), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "data": {"game_state": {"flags": {"from_save": true}}, "narrative": {"objectives": [{"id": 5}], "completed_events": []}}}))
	f.close()
	NarrativeState.set_objective("live", "Live objective")
	GameState.set_flag(&"live_flag", true)
	eq(SaveSystem.load_slot(4), ERR_INVALID_DATA, "corrupt section rejected")
	ok(GameState.is_flag_true(&"live_flag") and not GameState.has_flag(&"from_save"), "game state rolled back too")
	eq(NarrativeState.objectives().size(), 1, "live objective kept")
	SaveSystem.delete_slot(4)


func test_deserialize_rejects_malformed_sections() -> void:
	ok(not NarrativeState.deserialize({}), "empty")
	ok(not NarrativeState.deserialize({"objectives": "x", "completed_events": []}), "wrong container type")
	ok(not NarrativeState.deserialize({"objectives": [{"id": "a", "text": "t", "completed": "no"}], "completed_events": []}), "wrong field type")
	ok(not NarrativeState.deserialize({"objectives": [], "completed_events": [5]}), "bad event id")
	ok(NarrativeState.deserialize({"objectives": [], "completed_events": []}), "valid empty section accepted")
