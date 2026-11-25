extends CanvasLayer
## Owns the narrative interface (dialogue box, recording player, document reader, archive,
## objectives HUD, toasts) and routes narrative events to it. Pure presentation:
## all state lives in NarrativeState / DialogueManager.

var dialogue_view: DialogueView
var recording_view: RecordingView
var document_view: DocumentView
var log_view: LogView
var objectives_view: ObjectivesView
var notifications: NotificationView


func _ready() -> void:
	layer = 20
	# Draw order = add order: toasts last so they are never hidden behind a reader panel.
	objectives_view = _add(ObjectivesView.new())
	dialogue_view = _add(DialogueView.new())
	log_view = _add(LogView.new())
	document_view = _add(DocumentView.new())
	recording_view = _add(RecordingView.new())
	notifications = _add(NotificationView.new())
	EventBus.subscribe(Events.RECORDING_UNLOCKED, _on_recording_unlocked, true)
	EventBus.subscribe(Events.DOCUMENT_FOUND, _on_document_found, true)
	EventBus.subscribe(Events.OBJECTIVE_CHANGED, _on_objective_changed, true)
	EventBus.subscribe(Events.NOTIFICATION, _on_notification, true)
	EventBus.subscribe(Events.UI_OPEN_REQUESTED, _on_open_requested, true)
	EventBus.subscribe(Events.GAME_STATE_CHANGED, _on_game_state_changed, true)


func any_view_open() -> bool:
	return document_view.is_open() or recording_view.is_open() or log_view.is_open() or dialogue_view.is_showing()


func open_document(id: StringName) -> bool:
	log_view.close_view()
	return document_view.open_document(id)


func open_recording(id: StringName) -> bool:
	log_view.close_view()
	return recording_view.open_recording(id)


func open_log() -> bool:
	if GameManager.state != GameManager.State.PLAYING or GameManager.is_modal_open():
		return false
	log_view.open_view()
	return true


func close_all_views() -> void:
	document_view.close_view()
	recording_view.close_view()
	log_view.close_view()


func _add(view: Control) -> Control:
	add_child(view)
	return view


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.OPEN_LOG):
		if log_view.is_open():
			log_view.close_view()
			get_viewport().set_input_as_handled()
		elif open_log():
			get_viewport().set_input_as_handled()


func _on_recording_unlocked(p: Dictionary) -> void:
	var rec := NarrativeDatabase.get_recording(p.get("id", &""))
	if rec != null:
		notifications.show_toast("RECORDING FOUND: %s" % rec.title)


func _on_document_found(p: Dictionary) -> void:
	var doc := NarrativeDatabase.get_document(p.get("id", &""))
	if doc != null:
		notifications.show_toast("DOCUMENT FOUND: %s" % doc.title)


func _on_objective_changed(p: Dictionary) -> void:
	var prefix := "OBJECTIVE COMPLETE: " if p.get("kind") == "completed" else "NEW OBJECTIVE: "
	notifications.show_toast(prefix + str(p.get("text", "")))


func _on_notification(p: Dictionary) -> void:
	notifications.show_toast(str(p.get("text", "")))


func _on_open_requested(p: Dictionary) -> void:
	var id: StringName = p.get("id", &"")
	match p.get("kind"):
		"document": open_document(id)
		"recording": open_recording(id)


func _on_game_state_changed(p: Dictionary) -> void:
	if p.get("state") == "IDLE":
		close_all_views()  # leaving gameplay must never strand a reader on screen
