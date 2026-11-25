extends NarrativeTestCase


func test_fixtures_load_cleanly_with_valid_cross_references() -> void:
	eq(NarrativeDatabase.count("characters"), 2, "characters")
	eq(NarrativeDatabase.count("dialogue"), 4, "dialogue")
	eq(NarrativeDatabase.count("recordings"), 3, "recordings")
	eq(NarrativeDatabase.count("documents"), 2, "documents")
	eq(NarrativeDatabase.count("events"), 7, "events")
	eq(NarrativeDatabase.load_errors, [] as Array[String], "no load errors or warnings")
	ok(NarrativeDatabase.get_recording(&"nope") == null, "unknown id -> null")
	ok(NarrativeDatabase.get_character(&"nope") == null, "unknown character -> null")


func test_all_of_is_sorted_alphabetically() -> void:
	var ids := []
	for r in NarrativeDatabase.all_of("recordings"):
		ids.append(String(r.id))
	eq(ids, ["test_recording_cassette", "test_recording_locked", "test_recording_no_audio"], "sorted by id")


func test_test_content_is_hidden_unless_enabled() -> void:
	NarrativeDatabase.include_test_content = false
	NarrativeDatabase.load_all()
	eq(NarrativeDatabase.count("dialogue") + NarrativeDatabase.count("events") + NarrativeDatabase.count("characters"), 0, "fixtures ignored")
	ok(NarrativeDatabase.skipped_test_entries > 10, "skips are counted (%d)" % NarrativeDatabase.skipped_test_entries)
	eq(NarrativeDatabase.load_errors.size(), 0, "hiding test content is not an error")


func test_shipped_data_is_valid_in_both_modes() -> void:
	NarrativeDatabase.data_root = "res://data"
	NarrativeDatabase.include_test_content = true
	NarrativeDatabase.load_all()
	eq(NarrativeDatabase.load_errors, [] as Array[String], "shipped data loads with no errors or warnings (incl. cross-refs)")
	ok(NarrativeDatabase.count("dialogue") >= 1 and NarrativeDatabase.count("events") >= 8, "demo content present in debug mode")
	NarrativeDatabase.include_test_content = false
	NarrativeDatabase.load_all()
	eq(NarrativeDatabase.count("characters"), 4, "the four crew profiles ship")
	eq(NarrativeDatabase.count("dialogue") + NarrativeDatabase.count("recordings") + NarrativeDatabase.count("documents") + NarrativeDatabase.count("events"), 0, "release mode ships no demo content")


func test_crew_profiles_match_the_lore_bible_roles() -> void:
	NarrativeDatabase.data_root = "res://data"
	NarrativeDatabase.load_all()
	var expect := {
		&"commander": ["Mission Commander", "The Gatling", "holding_bridge"],
		&"scout": ["Reconnaissance", "Sonic Bark", "missing_in_action"],
		&"pilot": ["Chief Pilot", "System Override Keycard", "presumed_lost"],
		&"quartermaster": ["Quartermaster", "Gravity Tether", "unknown"],
	}
	for id: StringName in expect:
		var c := NarrativeDatabase.get_character(id)
		ok(c != null, "%s exists" % id)
		if c == null:
			continue
		ok(c.role.contains(expect[id][0]), "%s role" % id)
		ok(c.signature_gear.contains(expect[id][1]), "%s signature gear" % id)
		ok(expect[id][2] in c.states, "%s has its Lore Bible end-state available" % id)
		eq(c.initial_state, "aboard", "%s starts aboard" % id)
		eq(c.canon, "proposed", "%s stand-in is marked proposed" % id)
		ok(c.voice_style != "" and c.description != "", "%s has voice + description" % id)


func test_missing_folders_are_not_an_error() -> void:
	NarrativeDatabase.data_root = "user://definitely_not_here"
	NarrativeDatabase.load_all()
	eq(NarrativeDatabase.count("dialogue"), 0, "empty")
	eq(NarrativeDatabase.load_errors.size(), 0, "no errors for absent folders")


func test_malformed_dialogue_is_skipped_and_reported() -> void:
	write_scratch("dialogue", "broken.json", "{ not json")
	write_scratch("dialogue", "wrongtop.json", "{\"id\": \"x\"}")
	write_scratch("dialogue", "ignored.txt", "not json at all")
	var ok_node := {"speaker": "narrator", "text": "hi"}
	write_scratch("dialogue", "mixed.json", JSON.stringify([
		{"id": "good", "canon": "test", "start": "a", "nodes": {"a": ok_node}},
		{"canon": "test", "start": "a", "nodes": {"a": ok_node}},
		{"id": "badcanon", "canon": "official", "start": "a", "nodes": {"a": ok_node}},
		{"id": "nonodes", "canon": "test", "start": "a", "nodes": {}},
		{"id": "nostart", "canon": "test", "nodes": {"a": ok_node}},
		{"id": "badstart", "canon": "test", "start": "zzz", "nodes": {"a": ok_node}},
		{"id": "badnext", "canon": "test", "start": "a", "nodes": {"a": {"speaker": "narrator", "text": "x", "next": "ghost"}}},
		{"id": "bothkinds", "canon": "test", "start": "a", "nodes": {"a": {"speaker": "narrator", "text": "x", "next": "a", "choices": [{"text": "c"}]}}},
		{"id": "emptychoices", "canon": "test", "start": "a", "nodes": {"a": {"speaker": "narrator", "text": "x", "choices": []}}},
		{"id": "toomany", "canon": "test", "start": "a", "nodes": {"a": {"speaker": "narrator", "text": "x", "choices": [{"text": "1"}, {"text": "2"}, {"text": "3"}, {"text": "4"}, {"text": "5"}, {"text": "6"}, {"text": "7"}]}}},
		{"id": "badchoice", "canon": "test", "start": "a", "nodes": {"a": {"speaker": "narrator", "text": "x", "choices": [{"text": ""}]}}},
		{"id": "badflags", "canon": "test", "start": "a", "nodes": {"a": {"speaker": "narrator", "text": "x", "set_flags": {"k": [1]}}}},
		{"id": "badreq", "canon": "test", "start": "a", "nodes": {"a": {"speaker": "narrator", "text": "x", "requires": [5]}}},
		{"id": "notext", "canon": "test", "start": "a", "nodes": {"a": {"speaker": "narrator"}}},
		{"id": "good", "canon": "test", "start": "a", "nodes": {"a": {"speaker": "narrator", "text": "duplicate"}}},
		"not an object",
	]))
	load_scratch()
	eq(NarrativeDatabase.count("dialogue"), 1, "only the valid dialogue loaded")
	eq(NarrativeDatabase.get_dialogue(&"good").get_node_data("a")["text"], "hi", "first duplicate wins")
	ok(NarrativeDatabase.load_errors.size() >= 15, "every problem reported (got %d)" % NarrativeDatabase.load_errors.size())
	ok(GameManager.recent_errors().size() >= 15, "problems also reach the central error log")


func test_malformed_other_kinds_are_skipped_and_reported() -> void:
	write_scratch("characters", "c.json", JSON.stringify([
		{"id": "ok", "canon": "test", "display_name": "N", "role": "r", "description": "d", "voice": {"style": "s"}, "states": ["a"], "initial_state": "a"},
		{"id": "badinit", "canon": "test", "display_name": "N", "role": "r", "description": "d", "voice": {"style": "s"}, "states": ["a"], "initial_state": "zzz"},
		{"id": "nostates", "canon": "test", "display_name": "N", "role": "r", "description": "d", "voice": {"style": "s"}, "states": [], "initial_state": ""},
		{"id": "dupstates", "canon": "test", "display_name": "N", "role": "r", "description": "d", "voice": {"style": "s"}, "states": ["a", "a"], "initial_state": "a"},
		{"id": "novoice", "canon": "test", "display_name": "N", "role": "r", "description": "d", "states": ["a"], "initial_state": "a"},
		{"id": "badcolor", "canon": "test", "display_name": "N", "role": "r", "description": "d", "voice": {"style": "s"}, "states": ["a"], "initial_state": "a", "color": "red-ish"},
		{"id": "badrel", "canon": "test", "display_name": "N", "role": "r", "description": "d", "voice": {"style": "s"}, "states": ["a"], "initial_state": "a", "relationships": [{"with": "x"}]},
	]))
	write_scratch("recordings", "r.json", JSON.stringify([
		{"id": "ok", "kind": "cassette", "canon": "test", "title": "t", "segments": [{"text": "x"}]},
		{"id": "badkind", "kind": "podcast", "canon": "test", "title": "t", "segments": [{"text": "x"}]},
		{"id": "nosegs", "kind": "cassette", "canon": "test", "title": "t", "segments": []},
		{"id": "badseg", "kind": "cassette", "canon": "test", "title": "t", "segments": [{"text": ""}]},
		{"id": "badsecs", "kind": "cassette", "canon": "test", "title": "t", "segments": [{"text": "x", "seconds": -4}]},
		{"id": "notitle", "kind": "cassette", "canon": "test", "segments": [{"text": "x"}]},
	]))
	write_scratch("documents", "d.json", JSON.stringify([
		{"id": "ok", "kind": "technical_log", "canon": "test", "title": "t", "body": "b"},
		{"id": "badkind", "kind": "memo", "canon": "test", "title": "t", "body": "b"},
		{"id": "nobody", "kind": "crew_report", "canon": "test", "title": "t"},
		{"id": "badauthor", "kind": "crew_report", "canon": "test", "title": "t", "body": "b", "author": 5},
	]))
	write_scratch("events", "e.json", JSON.stringify([
		{"id": "ok", "canon": "test", "trigger": {"type": "interacted"}, "actions": [{"type": "notify", "text": "x"}]},
		{"id": "notrigger", "canon": "test", "actions": [{"type": "notify", "text": "x"}]},
		{"id": "noactions", "canon": "test", "trigger": {"type": "interacted"}, "actions": []},
		{"id": "badaction", "canon": "test", "trigger": {"type": "interacted"}, "actions": [{"type": "explode"}]},
		{"id": "missingparam", "canon": "test", "trigger": {"type": "interacted"}, "actions": [{"type": "set_objective", "id": "x"}]},
		{"id": "badonce", "canon": "test", "once": "yes", "trigger": {"type": "interacted"}, "actions": [{"type": "notify", "text": "x"}]},
		{"id": "badmatch", "canon": "test", "trigger": {"type": "interacted", "match": {"k": [1]}}, "actions": [{"type": "notify", "text": "x"}]},
	]))
	load_scratch()
	eq(NarrativeDatabase.count("characters"), 1, "one valid character")
	eq(NarrativeDatabase.count("recordings"), 1, "one valid recording")
	eq(NarrativeDatabase.count("documents"), 1, "one valid document")
	eq(NarrativeDatabase.count("events"), 1, "one valid event")
	ok(NarrativeDatabase.load_errors.size() >= 19, "all invalid entries reported (got %d)" % NarrativeDatabase.load_errors.size())


func test_dangling_references_are_warned_but_entries_still_load() -> void:
	write_scratch("dialogue", "d.json", JSON.stringify([{"id": "d", "canon": "test", "start": "a", "nodes": {"a": {"speaker": "ghost_person", "text": "x"}}}]))
	write_scratch("events", "e.json", JSON.stringify([{"id": "e", "canon": "test", "trigger": {"type": "interacted"}, "actions": [
		{"type": "start_dialogue", "id": "nope"}, {"type": "unlock_recording", "id": "nope"}, {"type": "unlock_document", "id": "nope"},
		{"type": "set_character_state", "id": "nope", "state": "x"}]}]))
	load_scratch()
	eq(NarrativeDatabase.count("dialogue"), 1, "dialogue still loaded")
	eq(NarrativeDatabase.count("events"), 1, "event still loaded")
	eq(NarrativeDatabase.load_errors.size(), 5, "one warning per dangling reference")


func test_recording_durations() -> void:
	var rec := NarrativeDatabase.get_recording(&"test_recording_cassette")
	eq(rec.total_seconds(), 4.0, "explicit seconds are summed")
	write_scratch("recordings", "auto.json", JSON.stringify([{"id": "auto", "kind": "cassette", "canon": "test", "title": "t", "segments": [{"text": "hi"}, {"text": "x".repeat(200)}]}]))
	load_scratch()
	var auto := NarrativeDatabase.get_recording(&"auto")
	eq(auto.segment_seconds(0), RecordingEntry.MIN_SEGMENT_SECONDS, "short text gets the minimum")
	ok(auto.segment_seconds(1) > 8.0, "long text gets a length-based duration")
