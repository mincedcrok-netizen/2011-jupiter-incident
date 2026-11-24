extends TestCase

const FIXTURES := "res://tests/fixtures/data"
const SCRATCH := "user://test_narrative_data"


func before_each() -> void:
	GameState.reset()
	GameManager.clear_errors()
	NarrativeDatabase.data_root = FIXTURES
	NarrativeDatabase.load_all()


func after_each() -> void:
	_wipe(SCRATCH)
	NarrativeDatabase.data_root = "res://data"
	NarrativeDatabase.load_all()
	GameState.reset()
	GameManager.clear_errors()


func _wipe(path: String) -> void:
	for sub in ["dialogue", "recordings", ""]:
		var d := path if sub == "" else "%s/%s" % [path, sub]
		if DirAccess.dir_exists_absolute(d):
			for f in DirAccess.get_files_at(d):
				DirAccess.remove_absolute("%s/%s" % [d, f])
	for sub in ["dialogue", "recordings"]:
		DirAccess.remove_absolute("%s/%s" % [path, sub])
	DirAccess.remove_absolute(path)


func _write(sub: String, file: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute("%s/%s" % [SCRATCH, sub])
	var f := FileAccess.open("%s/%s/%s" % [SCRATCH, sub, file], FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_fixtures_load_cleanly() -> void:
	eq(NarrativeDatabase.dialogue_count(), 1, "one dialogue")
	eq(NarrativeDatabase.recording_count(), 2, "two recordings")
	eq(NarrativeDatabase.load_errors.size(), 0, "no load errors")
	ok(NarrativeDatabase.has_dialogue(&"test_dialogue_basic"), "has dialogue")
	ok(NarrativeDatabase.get_recording(&"test_recording_cassette") != null, "recording retrievable")
	ok(NarrativeDatabase.get_recording(&"nope") == null, "unknown id -> null")


func test_dialogue_lines_follow_story_flags() -> void:
	var seq := NarrativeDatabase.get_dialogue(&"test_dialogue_basic")
	eq(seq.available_lines().size(), 2, "flag unset: line 1 and the excludes-line")
	GameState.set_flag(&"test_flag", true)
	var lines := seq.available_lines()
	eq(lines.size(), 2, "flag set: line 1 and the requires-line")
	eq(lines[1]["speaker"], "test_speaker_b", "requires-line now present, excludes-line gone")
	GameState.set_flag(&"test_flag", false)
	eq(seq.available_lines().size(), 2, "false flag counts as unset")


func test_unlock_unknown_recording_refused() -> void:
	ok(not NarrativeDatabase.unlock_recording(&"ghost"), "unknown id refused")
	eq(NarrativeDatabase.load_errors.size(), 1, "reported")


func test_unlock_flow_and_gating() -> void:
	ok(not NarrativeDatabase.is_unlocked(&"test_recording_cassette"), "starts locked")
	ok(NarrativeDatabase.unlock_recording(&"test_recording_cassette"), "ungated unlock ok")
	ok(NarrativeDatabase.is_unlocked(&"test_recording_cassette"), "now unlocked")
	ok(not NarrativeDatabase.unlock_recording(&"test_recording_locked"), "gated: refused without flag")
	GameState.set_flag(&"test_gate", true)
	ok(NarrativeDatabase.unlock_recording(&"test_recording_locked"), "gated: ok once flag set")
	var ids := []
	for r in NarrativeDatabase.unlocked_recordings():
		ids.append(String(r.id))
	eq(ids, ["test_recording_cassette", "test_recording_locked"], "unlocked list sorted by id")


func test_unlocked_recordings_survive_save_and_load() -> void:
	NarrativeDatabase.unlock_recording(&"test_recording_cassette")
	SaveSystem.save_dir = "user://test_saves_narr"
	eq(SaveSystem.save_slot(1), OK, "saved")
	GameState.reset()
	ok(not NarrativeDatabase.is_unlocked(&"test_recording_cassette"), "locked after reset")
	eq(SaveSystem.load_slot(1), OK, "loaded")
	ok(NarrativeDatabase.is_unlocked(&"test_recording_cassette"), "unlock persisted")
	SaveSystem.delete_slot(1)
	SaveSystem.save_dir = SaveSystem.DEFAULT_SAVE_DIR


func test_missing_data_folders_are_not_an_error() -> void:
	NarrativeDatabase.data_root = "user://definitely_not_here"
	NarrativeDatabase.load_all()
	eq(NarrativeDatabase.dialogue_count() + NarrativeDatabase.recording_count(), 0, "empty")
	eq(NarrativeDatabase.load_errors.size(), 0, "no errors for absent folders")


func test_shipped_data_folder_loads_without_errors() -> void:
	NarrativeDatabase.data_root = "res://data"
	NarrativeDatabase.load_all()
	eq(NarrativeDatabase.load_errors.size(), 0, "res://data is valid (currently empty)")


func test_malformed_files_and_entries_are_skipped_not_fatal() -> void:
	_write("dialogue", "broken.json", "{ not json")
	_write("dialogue", "wrongtop.json", "{\"id\": \"x\"}")
	_write("dialogue", "ignored.txt", "this is not a json file")
	_write("dialogue", "mixed.json", JSON.stringify([
		{"id": "good", "canon": "test", "lines": [{"speaker": "a", "text": "hi"}]},
		{"canon": "test", "lines": [{"speaker": "a", "text": "no id"}]},
		{"id": "badcanon", "canon": "official", "lines": [{"speaker": "a", "text": "x"}]},
		{"id": "nolines", "canon": "test", "lines": []},
		{"id": "badline", "canon": "test", "lines": [{"speaker": "", "text": 5}]},
		{"id": "badreq", "canon": "test", "lines": [{"speaker": "a", "text": "x", "requires": [1]}]},
		{"id": "good", "canon": "test", "lines": [{"speaker": "a", "text": "duplicate"}]},
		"not an object",
	]))
	_write("recordings", "mixed.json", JSON.stringify([
		{"id": "r_ok", "kind": "dashcam", "canon": "proposed", "title": "t", "body": "b"},
		{"id": "r_badkind", "kind": "podcast", "canon": "test", "title": "t", "body": "b"},
		{"id": "r_notitle", "kind": "report", "canon": "test", "body": "b"},
		{"id": "r_badauthor", "kind": "report", "canon": "test", "title": "t", "body": "b", "author": 7},
	]))
	NarrativeDatabase.data_root = SCRATCH
	NarrativeDatabase.load_all()
	eq(NarrativeDatabase.dialogue_count(), 1, "only the valid dialogue loaded")
	ok(NarrativeDatabase.has_dialogue(&"good"), "valid dialogue present")
	eq(NarrativeDatabase.get_dialogue(&"good").lines[0]["text"], "hi", "first duplicate wins")
	eq(NarrativeDatabase.recording_count(), 1, "only the valid recording loaded")
	ok(NarrativeDatabase.has_recording(&"r_ok"), "valid recording present")
	ok(NarrativeDatabase.load_errors.size() >= 10, "every problem reported (got %d)" % NarrativeDatabase.load_errors.size())
	ok(GameManager.recent_errors().size() >= 10, "problems also in the central error log")


func test_wrongly_typed_unlock_flag_in_a_save_is_harmless() -> void:
	GameState.set_flag(&"recording_unlocked:test_recording_cassette", "yes")
	ok(not NarrativeDatabase.is_unlocked(&"test_recording_cassette"), "string flag does not count as unlocked, and no error")
	GameState.set_flag(&"recording_unlocked:test_recording_cassette", 1)
	ok(not NarrativeDatabase.is_unlocked(&"test_recording_cassette"), "int flag does not count either")
	eq(NarrativeDatabase.unlocked_recordings().size(), 0, "listing stays empty")
