extends ShipTestCase

const SAVE_DIR := "user://test_saves_ship_narrative"


func after_each() -> void:
	SaveSystem.save_dir = SaveSystem.DEFAULT_SAVE_DIR
	await super.after_each()


func use(interaction_id: String) -> bool:
	for n in deck.find_children("*", "StaticBody3D", true, false):
		if n is Interactable and String((n as Interactable).interaction_id) == interaction_id:
			return (n as Interactable).try_interact(player)
	push_error("test: no interactable '%s'" % interaction_id)
	return false


func enter_room(room_id: String) -> void:
	var r := room(room_id)
	teleport(r.global_position + Vector3(0.3, 0.05, 0.3), 0)
	await physics(6)


func objectives_text() -> Array:
	var out := []
	for o in NarrativeState.objectives():
		out.append("%s%s" % ["x:" if o["completed"] else "-:", o["id"]])
	return out


func test_the_objective_chain_leads_through_the_whole_slice() -> void:
	EventBus.publish(Events.SCENE_CHANGE_COMPLETED, {"path": DECK})
	eq(objectives_text(), ["-:reach_bridge"], "entering the deck issues the first objective")
	eq(NarrativeState.objectives()[0]["target"], "nav_bridge", "pointing at the bridge")
	await enter_room("bridge")
	eq(objectives_text(), ["x:reach_bridge", "-:check_terminal"], "reaching the bridge advances it")
	ok(use("bridge_status_terminal") and DialogueManager.is_active(), "the status terminal opens a conversation")
	eq(DialogueManager.current()["speaker"], "system", "spoken by the ship's system")
	eq(DialogueManager.current()["choices"].size(), 4, "four options while Section B is still locked")
	ok(door("section_b").is_locked(), "Section B is still locked")
	DialogueManager.choose(2)  # Release Section B emergency lock
	ok(GameState.is_flag_true(&"door_unlocked:section_b") and not door("section_b").is_locked(), "the dialogue choice released the door")
	DialogueManager.advance()
	eq(DialogueManager.current()["choices"].size(), 3, "the release option disappears once used")
	DialogueManager.choose(2)  # Log out
	ok(not DialogueManager.is_active(), "conversation ended")
	eq(objectives_text(), ["x:reach_bridge", "x:check_terminal", "-:search_quarters"], "using the terminal advances the objective")
	await enter_room("quarters")
	await enter_room("storage")
	await enter_room("engineering")
	eq(objectives_text(), ["x:reach_bridge", "x:check_terminal", "x:search_quarters", "x:check_supply", "x:inspect_engineering", "-:engine_core_sealed"], "the full chain completes in order")
	var targets := []
	for o in NarrativeState.objectives():
		targets.append(o["target"])
	eq(targets, ["nav_bridge", "nav_bridge_terminal", "nav_quarters", "nav_storage", "nav_engineering", "nav_engine_core"], "every objective points at a real waypoint")
	for t in targets:
		ok(NavTarget.find(tree, t) != null, "waypoint '%s' exists in the level" % t)


func test_skipping_ahead_never_softlocks_the_objectives() -> void:
	EventBus.publish(Events.SCENE_CHANGE_COMPLETED, {"path": DECK})
	await enter_room("storage")
	await enter_room("engineering")
	await enter_room("quarters")
	eq(objectives_text(), ["-:reach_bridge"], "out-of-order rooms change nothing; the objective still points at the bridge")
	ok(not NarrativeState.is_event_done(&"deck_a_storage_reached"), "and one-shot events were not consumed")


func test_leaving_the_terminal_without_releasing_keeps_the_objective() -> void:
	EventBus.publish(Events.SCENE_CHANGE_COMPLETED, {"path": DECK})
	await enter_room("bridge")
	use("bridge_status_terminal")
	DialogueManager.choose(3)  # Log out straight away
	eq(objectives_text(), ["x:reach_bridge", "-:check_terminal"], "still asked to check the terminal")
	ok(use("bridge_status_terminal") and DialogueManager.is_active(), "and the terminal can be used again")


func test_every_interactable_delivers_its_content_through_the_phase_2_systems() -> void:
	var docs := {
		"bridge_flight_console": ["flight_log_fragment", "Flight deck log"],
		"quarters_locker_commander": ["crew_note_commander", "commander"],
		"quarters_locker_scout": ["crew_note_scout", "journal"],
		"quarters_locker_pilot": ["crew_note_pilot", "Sticky notes"],
		"quarters_locker_quartermaster": ["crew_note_quartermaster", "inventory"],
		"storage_manifest_terminal": ["supply_manifest", "Supply manifest"],
		"storage_pod_checklist": ["pod_provisioning_checklist", "pod provisioning"],
		"damaged_terminal": ["corrupted_incident_report", "corrupted"],
		"engineering_terminal": ["engineering_maintenance_log", "maintenance"],
	}
	for iid in docs:
		NarrativeUI.close_all_views()
		ok(use(iid), "%s: interaction accepted" % iid)
		var id := StringName(docs[iid][0])
		ok(NarrativeState.is_document_found(id), "%s: document found" % iid)
		ok(NarrativeUI.document_view.is_open() and NarrativeState.is_document_read(id), "%s: reader opened and marked read" % iid)
		ok(NarrativeUI.document_view.title_text().to_lower().contains(String(docs[iid][1]).to_lower()) or NarrativeUI.document_view.body_text().to_lower().contains(String(docs[iid][1]).to_lower()), "%s: shows the right document" % iid)
		ok(not NarrativeUI.document_view.body_text().contains("{"), "%s: no unresolved name tokens" % iid)
	NarrativeUI.close_all_views()
	for pair in [["bridge_black_box", "black_box_0811a"], ["quarters_radio", "crew_cassette_livestream"]]:
		NarrativeUI.close_all_views()
		ok(use(pair[0]), "%s: accepted" % pair[0])
		ok(NarrativeState.is_recording_unlocked(StringName(pair[1])) and NarrativeUI.recording_view.is_open(), "%s: recording unlocked and player opened" % pair[0])
	var notes := capture(Events.NOTIFICATION)
	use("storage_battery_crate")
	use("damaged_shard")
	eq(notes.size(), 2, "flavour interactions give a notification")
	ok(String(notes[1]["text"]).contains("pyramid"), "the shard is described, not explained")
	ok(not use("damaged_shard"), "one-shot objects do not repeat")


func test_character_names_come_from_data_not_from_the_level() -> void:
	NarrativeUI.close_all_views()
	use("quarters_locker_commander")
	var commander := NarrativeDatabase.get_character(&"commander")
	ok(NarrativeUI.document_view.body_text().contains(commander.display_name), "the note is signed with the commander's data-driven name")
	NarrativeUI.close_all_views()
	use("quarters_locker_pilot")
	ok(NarrativeUI.document_view.body_text().contains(NarrativeDatabase.get_character(&"commander").callsign), "callsign tokens resolve")
	commander.display_name = "RENAMED IN DATA"
	NarrativeUI.close_all_views()
	NarrativeUI.open_document(&"crew_note_commander")
	ok(NarrativeUI.document_view.body_text().contains("RENAMED IN DATA"), "changing the character data changes every mention, nothing is hard-coded")
	for l in deck.find_children("*", "Label3D", true, false):
		ok(not (l as Label3D).text.contains("{"), "sign text fully resolved: '%s'" % (l as Label3D).text.replace("\n", " "))


func test_the_black_box_log_plays_with_resolved_names() -> void:
	use("bridge_black_box")
	var v: RecordingView = NarrativeUI.recording_view
	v.player.advance(60.0)
	v._refresh()
	var t := v.transcript_text()
	for who in ["WREN CALLOWAY", "DALE BRANNIGAN", "ZEKE MARLOWE", "HOLLIS PREWITT"]:
		ok(t.contains(who), "%s speaks in the log" % who)
	ok(t.contains("Cursor, hands OFF"), "callsign token resolved inside a spoken line")
	ok(t.contains("AUDIO CORRUPTION"), "ends with the corruption marker")
	ok(NarrativeState.was_recording_played(&"black_box_0811a"), "finishing marks it played")


func test_progress_in_the_slice_survives_save_and_load() -> void:
	SaveSystem.save_dir = SAVE_DIR
	EventBus.publish(Events.SCENE_CHANGE_COMPLETED, {"path": DECK})
	await enter_room("bridge")
	use("bridge_status_terminal")
	DialogueManager.choose(2)
	DialogueManager.advance()
	DialogueManager.choose(2)
	NarrativeUI.close_all_views()
	use("bridge_black_box")
	NarrativeUI.recording_view.player.advance(60.0)
	NarrativeUI.close_all_views()
	use("quarters_locker_scout")
	NarrativeUI.close_all_views()
	eq(SaveSystem.save_slot(1), OK, "saved mid-slice")
	GameState.reset()
	NarrativeState.reset()
	ok(door("section_b").is_locked() and NarrativeState.objectives().is_empty(), "state really cleared")
	eq(SaveSystem.load_slot(1), OK, "loaded")
	ok(not door("section_b").is_locked(), "the unlocked door is restored")
	ok(NarrativeState.was_recording_played(&"black_box_0811a") and NarrativeState.is_document_read(&"crew_note_scout"), "recordings and documents restored")
	eq(objectives_text(), ["x:reach_bridge", "x:check_terminal", "-:search_quarters"], "objectives restored")
	eq(NarrativeState.objectives()[2]["target"], "nav_quarters", "including the waypoint target")
	ok(NarrativeState.is_event_done(&"deck_a_terminal_done"), "one-shot events remembered")
	SaveSystem.delete_slot(1)


func test_all_shipped_text_resolves_and_nothing_unapproved_leaks_in() -> void:
	var seen := 0
	for kind in ["documents", "recordings", "dialogue", "events"]:
		for entry in NarrativeDatabase.all_of(kind):
			var texts: Array[String] = []
			match kind:
				"documents": texts = [entry.title, entry.body]
				"recordings":
					texts.append(entry.title)
					for s in entry.segments:
						texts.append(s["text"])
				"dialogue":
					for nid in entry.nodes:
						texts.append(entry.nodes[nid]["text"])
						for c in entry.nodes[nid]["choices"]:
							texts.append(c["text"])
				"events":
					for a in entry.actions:
						texts.append(str(a.get("text", "")))
			for t in texts:
				seen += 1
				ok(not NarrativeText.resolve(t).contains("{"), "%s '%s' fully resolves" % [kind, entry.id])
				ok(not t.to_lower().contains("zero-g") and not t.to_lower().contains("zero g") and not t.to_lower().contains("weightless"), "%s '%s' does not use the PROPOSED Zero-G hazard" % [kind, entry.id])
	ok(seen > 60, "a meaningful amount of text was checked (%d strings)" % seen)
