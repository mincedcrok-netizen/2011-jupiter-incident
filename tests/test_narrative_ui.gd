extends NarrativeTestCase


func _key(code: Key, pressed: bool = true) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _frames(n: int = 2) -> void:
	for i in n:
		await tree.process_frame


# --- dialogue box ---------------------------------------------------------------

func test_dialogue_box_shows_speaker_text_and_types_out() -> void:
	var v: DialogueView = NarrativeUI.dialogue_view
	ok(not v.is_showing(), "hidden before a conversation")
	DialogueManager.start(&"test_dialogue_basic")
	ok(v.is_showing(), "shown")
	ok(v.speaker_text().contains("TEST SPEAKER A") and v.speaker_text().contains("ALPHA"), "speaker shows the character's name and callsign (got '%s')" % v.speaker_text())
	eq(v.body_text(), "FIXTURE one.", "line text")
	ok(v.is_typing(), "typewriter running")
	v.skip_typing()
	ok(not v.is_typing(), "skip finishes typing")


func test_dialogue_box_continue_and_choices_work_through_the_ui() -> void:
	var v: DialogueView = NarrativeUI.dialogue_view
	DialogueManager.start(&"test_dialogue_basic")
	v.press_continue()  # first press only finishes typing
	eq(DialogueManager.current()["node"], "n1", "first press did not advance")
	v.press_continue()
	v.press_continue()
	v.press_continue()
	eq(DialogueManager.current()["node"], "n4", "walked to the choice node")
	v.skip_typing()
	eq(v.choice_count(), 2, "two choice buttons")
	var texts: Array[String] = []
	for b in v._choice_box.get_children():
		texts.append((b as Button).text)
	eq(texts, ["1. Left", "2. Leave"], "numbered choice buttons")
	ok(v._choice_box.visible, "choices visible once typing is done")
	v.press_continue()
	eq(DialogueManager.current()["node"], "n4", "continue does nothing while choices are shown")
	(v._choice_box.get_child(0) as Button).pressed.emit()
	eq(DialogueManager.current()["node"], "left", "clicking a choice picks it")


func _tap(code: Key) -> void:
	_key(code)
	_key(code, false)
	await _frames()


func test_dialogue_keyboard_input_through_the_real_input_pipeline() -> void:
	GameManager.enter_gameplay()
	DialogueManager.start(&"test_dialogue_basic")
	var v: DialogueView = NarrativeUI.dialogue_view
	await _tap(KEY_ENTER)
	eq(DialogueManager.current()["node"], "n1", "first Enter only finished the typing")
	await _tap(KEY_ENTER)
	eq(DialogueManager.current()["node"], "n3", "second Enter advanced (n2 skipped by its condition)")
	await _tap(KEY_E)
	await _tap(KEY_E)
	eq(DialogueManager.current()["node"], "n4", "E finishes typing, then advances")
	await _tap(KEY_1)
	eq(DialogueManager.current()["node"], "n4", "number keys are ignored until typing has finished")
	v.skip_typing()
	await _tap(KEY_1)
	eq(DialogueManager.current()["node"], "left", "pressing 1 chose the first option")
	await _tap(KEY_SPACE)
	await _tap(KEY_SPACE)
	ok(not DialogueManager.is_active(), "conversation ran to its end by keyboard")


func test_dialogue_box_hides_when_dialogue_ends() -> void:
	DialogueManager.start(&"test_dialogue_chain")
	DialogueManager.abort()
	ok(not NarrativeUI.dialogue_view.is_showing(), "hidden after abort")


func test_dialogue_with_unknown_speaker_still_displays() -> void:
	write_scratch("dialogue", "x.json", JSON.stringify([{"id": "x", "canon": "test", "start": "a", "nodes": {"a": {"speaker": "mystery_voice", "text": "Hello?"}}}]))
	load_scratch()
	DialogueManager.start(&"x")
	eq(NarrativeUI.dialogue_view.speaker_text(), "MYSTERY_VOICE", "falls back to the raw id")


# --- documents ------------------------------------------------------------------

func test_document_reader() -> void:
	var v: DocumentView = NarrativeUI.document_view
	ok(not NarrativeUI.open_document(&"test_doc_report"), "cannot open a document that has not been found")
	ok(not v.is_open(), "reader stays closed")
	NarrativeState.find_document(&"test_doc_report")
	ok(NarrativeUI.open_document(&"test_doc_report"), "opens once found")
	ok(v.is_open() and GameManager.is_modal_open(), "open and holding the modal")
	eq(v.title_text(), "FIXTURE report", "title")
	eq(v.body_text(), "FIXTURE body text.", "body")
	ok(v.banner_text() == "", "ordinary documents have no classified banner")
	ok(NarrativeState.is_document_read(&"test_doc_report"), "opening marks it read")
	v.close_view()
	ok(not v.is_open() and not GameManager.is_modal_open(), "closed and modal released")


func test_classified_documents_show_a_banner() -> void:
	GameState.set_flag(&"test_gate", true)
	NarrativeState.find_document(&"test_doc_classified")
	NarrativeUI.open_document(&"test_doc_classified")
	ok(NarrativeUI.document_view.banner_text().contains("CLASSIFIED") and NarrativeUI.document_view.banner_text().contains("LEVEL 9"), "banner shows the classification")


func test_escape_closes_the_reader_instead_of_pausing() -> void:
	GameManager.enter_gameplay()
	NarrativeState.find_document(&"test_doc_report")
	NarrativeUI.open_document(&"test_doc_report")
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE, false)
	await _frames()
	ok(not NarrativeUI.document_view.is_open(), "Esc closed the reader")
	ok(not GameManager.is_paused(), "and did not also pause the game")


# --- recordings -----------------------------------------------------------------

func test_recording_player_ui() -> void:
	var v: RecordingView = NarrativeUI.recording_view
	ok(not NarrativeUI.open_recording(&"test_recording_cassette"), "locked recording refused")
	NarrativeState.unlock_recording(&"test_recording_cassette")
	ok(NarrativeUI.open_recording(&"test_recording_cassette"), "opens once found")
	ok(v.is_open() and v.player.state == RecordingPlayer.State.PLAYING, "starts playing")
	v.player.advance(0.2)
	v._refresh()
	ok(v.transcript_text().contains("First segment."), "transcript shows the first segment")
	ok(v.transcript_text().contains("TEST SPEAKER A"), "with the speaker's name")
	ok(not v.transcript_text().contains("Second segment."), "later segments not revealed yet")
	v.toggle_play()
	eq(v.player.state, RecordingPlayer.State.PAUSED, "pause button pauses")
	v.toggle_play()
	eq(v.player.state, RecordingPlayer.State.PLAYING, "and resumes")
	v.player.advance(10.0)
	v._refresh()
	ok(v.transcript_text().contains("Second segment."), "everything revealed at the end")
	ok(NarrativeState.was_recording_played(&"test_recording_cassette"), "finishing marks it played")
	v.close_view()
	ok(not v.is_open() and not GameManager.is_modal_open(), "closed and modal released")


func test_missing_audio_file_degrades_to_transcript_only() -> void:
	NarrativeState.unlock_recording(&"test_recording_no_audio")
	ok(NarrativeUI.open_recording(&"test_recording_no_audio"), "still opens")
	ok(NarrativeUI.recording_view.status_text().contains("transcript only"), "tells the player it is transcript-only")
	ok(NarrativeUI.recording_view.player != null, "playback still works")


# --- archive / log --------------------------------------------------------------

func test_archive_lists_discoveries_and_tracks_new_entries() -> void:
	GameManager.enter_gameplay()
	var v: LogView = NarrativeUI.log_view
	ok(NarrativeUI.open_log(), "archive opens during play")
	eq(v.item_count(), 0, "empty at first")
	v.close_view()
	NarrativeState.unlock_recording(&"test_recording_cassette")
	NarrativeState.find_document(&"test_doc_report")
	NarrativeUI.open_log()
	eq(v.item_texts(), ["[NEW] FIXTURE cassette", "[NEW] FIXTURE report"], "both listed and marked NEW")
	v.close_view()
	NarrativeState.mark_recording_played(&"test_recording_cassette")
	NarrativeState.mark_document_read(&"test_doc_report")
	NarrativeUI.open_log()
	eq(v.item_texts(), ["FIXTURE cassette", "FIXTURE report"], "NEW marker disappears once played/read")


func test_archive_entries_open_their_viewer() -> void:
	GameManager.enter_gameplay()
	NarrativeState.find_document(&"test_doc_report")
	NarrativeUI.open_log()
	var btn: Button = null
	for b in NarrativeUI.log_view._doc_box.get_children():
		if b is Button:
			btn = b
	btn.pressed.emit()
	ok(NarrativeUI.document_view.is_open(), "clicking opened the document")
	ok(not NarrativeUI.log_view.is_open(), "and closed the archive")


func test_archive_only_opens_during_play_and_never_over_another_modal() -> void:
	ok(not NarrativeUI.open_log(), "refused outside gameplay")
	GameManager.enter_gameplay()
	DialogueManager.start(&"test_dialogue_basic")
	ok(not NarrativeUI.open_log(), "refused during dialogue")
	DialogueManager.abort()
	GameManager.pause()
	ok(not NarrativeUI.open_log(), "refused while paused")


func test_tab_key_toggles_the_archive() -> void:
	GameManager.enter_gameplay()
	_key(KEY_TAB)
	_key(KEY_TAB, false)
	await _frames()
	ok(NarrativeUI.log_view.is_open(), "Tab opened it")
	_key(KEY_TAB)
	_key(KEY_TAB, false)
	await _frames()
	ok(not NarrativeUI.log_view.is_open(), "Tab closed it")


# --- objectives + notifications ------------------------------------------------

func test_objectives_hud_and_toasts() -> void:
	var toasts: NotificationView = NarrativeUI.notifications
	NarrativeState.set_objective("o1", "Find the thing")
	eq(NarrativeUI.objectives_view.lines(), ["[ ] Find the thing"] as Array[String], "objective listed")
	ok(toasts.toast_texts()[0].contains("NEW OBJECTIVE: Find the thing"), "toast announces it")
	NarrativeState.complete_objective("o1")
	eq(NarrativeUI.objectives_view.lines(), ["[x] Find the thing"] as Array[String], "completion shown")
	ok(toasts.toast_texts()[0].contains("OBJECTIVE COMPLETE"), "completion toast")
	NarrativeState.unlock_recording(&"test_recording_cassette")
	ok(toasts.toast_texts()[0].contains("RECORDING FOUND: FIXTURE cassette"), "discovery toast (recording)")
	NarrativeState.find_document(&"test_doc_report")
	ok(toasts.toast_texts()[0].contains("DOCUMENT FOUND: FIXTURE report"), "discovery toast (document)")


func test_toasts_are_capped_and_expire() -> void:
	var t: NotificationView = NarrativeUI.notifications
	for i in 10:
		t.show_toast("toast %d" % i)
	eq(t.toast_texts().size(), NotificationView.MAX_TOASTS, "capped")
	eq(t.toast_texts()[0], "toast 9", "newest first")
	t._process(NotificationView.LIFETIME + 0.1)
	eq(t.toast_texts().size(), 0, "all expired")


func test_objectives_hud_only_shows_the_latest_few() -> void:
	for i in 8:
		NarrativeState.set_objective("o%d" % i, "Objective %d" % i)
	var lines := NarrativeUI.objectives_view.lines()
	eq(lines.size(), ObjectivesView.MAX_SHOWN, "capped")
	eq(lines[-1], "[ ] Objective 7", "newest last")


func test_ui_open_requests_from_events() -> void:
	NarrativeState.find_document(&"test_doc_report")
	EventBus.publish(Events.UI_OPEN_REQUESTED, {"kind": "document", "id": &"test_doc_report"})
	ok(NarrativeUI.document_view.is_open(), "event opened the document")
	NarrativeUI.close_all_views()
	EventBus.publish(Events.UI_OPEN_REQUESTED, {"kind": "document", "id": &"ghost"})
	EventBus.publish(Events.UI_OPEN_REQUESTED, {"kind": "nonsense", "id": &"x"})
	EventBus.publish(Events.UI_OPEN_REQUESTED, {})
	ok(not NarrativeUI.any_view_open(), "bad requests are ignored safely")


func test_leaving_gameplay_closes_every_view() -> void:
	GameManager.enter_gameplay()
	NarrativeState.find_document(&"test_doc_report")
	NarrativeUI.open_document(&"test_doc_report")
	GameManager.leave_gameplay()
	ok(not NarrativeUI.document_view.is_open(), "reader closed when gameplay ends")
	ok(not GameManager.is_modal_open(), "no modal left behind")


# --- the player is held while a modal is open -----------------------------------

func test_modal_ui_blocks_player_input() -> void:
	GameManager.enter_gameplay()
	var pi := PlayerInput.new()
	tree.root.add_child(pi)
	Input.action_press(InputActions.MOVE_FORWARD)
	pi.poll()
	ok(pi.move.y < 0.0, "free to move with no modal")
	DialogueManager.start(&"test_dialogue_basic")
	pi.poll()
	eq(pi.move, Vector2.ZERO, "movement blocked during dialogue")
	ok(not GameManager.wants_mouse_captured(), "mouse released during dialogue")
	DialogueManager.abort()
	pi.poll()
	ok(pi.move.y < 0.0, "movement returns when the dialogue ends")
	ok(GameManager.wants_mouse_captured(), "mouse captured again")
	Input.action_release(InputActions.MOVE_FORWARD)
	pi.queue_free()
	await tree.process_frame


# --- layout (these caught zero-size overlays that no behavioural check could) ---------

func _viewport_size() -> Vector2:
	return NarrativeUI.get_viewport().get_visible_rect().size


func _within_viewport(c: Control) -> bool:
	var r := c.get_global_rect()
	var vp := Rect2(Vector2.ZERO, _viewport_size()).grow(1.0)
	return vp.encloses(r)


func test_overlays_cover_the_whole_screen() -> void:
	var vp := _viewport_size()
	for v: Control in [NarrativeUI.dialogue_view, NarrativeUI.document_view, NarrativeUI.recording_view, NarrativeUI.log_view, NarrativeUI.objectives_view, NarrativeUI.notifications]:
		eq(v.size, vp, "%s fills the viewport" % v.get_class() + "/" + str(v.get_script().get_global_name()))


func test_dialogue_box_sits_along_the_bottom_and_is_sized_sensibly() -> void:
	DialogueManager.start(&"test_dialogue_basic")
	await _frames()
	var panel: Control = NarrativeUI.dialogue_view._panel
	var vp := _viewport_size()
	var r := panel.get_global_rect()
	ok(_within_viewport(panel), "dialogue box is fully on screen (%s)" % str(r))
	ok(r.position.y > vp.y * 0.5, "in the lower half of the screen (y=%.0f)" % r.position.y)
	ok(r.size.x > vp.x * 0.7, "wide enough to read (%.0f px)" % r.size.x)
	ok(r.size.y > 80.0, "tall enough for text and choices (%.0f px)" % r.size.y)


func test_reader_panels_are_centered_and_large() -> void:
	GameManager.enter_gameplay()
	NarrativeState.find_document(&"test_doc_report")
	NarrativeState.unlock_recording(&"test_recording_cassette")
	var vp := _viewport_size()
	NarrativeUI.open_document(&"test_doc_report")
	await _frames()
	var doc_panel: Control = null
	for c in NarrativeUI.document_view.get_children():
		if c is PanelContainer:
			doc_panel = c
	var r := doc_panel.get_global_rect()
	ok(_within_viewport(doc_panel) and r.size.x > vp.x * 0.5 and r.size.y > vp.y * 0.5, "document panel is large and on screen (%s)" % str(r))
	ok(absf(r.get_center().x - vp.x / 2.0) < 2.0 and absf(r.get_center().y - vp.y / 2.0) < 2.0, "and centered")
	NarrativeUI.document_view.close_view()
	NarrativeUI.open_recording(&"test_recording_cassette")
	await _frames()
	for c in NarrativeUI.recording_view.get_children():
		if c is PanelContainer:
			ok(_within_viewport(c) and c.get_global_rect().size.x > vp.x * 0.5, "recording panel large and on screen")
	NarrativeUI.close_all_views()
	NarrativeUI.open_log()
	await _frames()
	for c in NarrativeUI.log_view.get_children():
		if c is PanelContainer:
			ok(_within_viewport(c) and c.get_global_rect().size.x > vp.x * 0.5, "archive panel large and on screen")


func test_toasts_and_objectives_are_on_screen() -> void:
	NarrativeUI.notifications.show_toast("A reasonably long notification message that should wrap")
	NarrativeState.set_objective("o", "An objective")
	await _frames(3)
	for toast in NarrativeUI.notifications._box.get_children():
		ok(_within_viewport(toast), "toast fully on screen (%s)" % str(toast.get_global_rect()))
		ok(toast.get_global_rect().size.x > 150.0, "toast has real width")
	ok(_within_viewport(NarrativeUI.objectives_view._box), "objectives list on screen")


func test_toasts_draw_above_every_reader_panel() -> void:
	var top := NarrativeUI.notifications.get_index()
	for v: Control in [NarrativeUI.dialogue_view, NarrativeUI.log_view, NarrativeUI.document_view, NarrativeUI.recording_view]:
		ok(top > v.get_index(), "notifications are drawn after %s" % v.get_script().get_global_name())
