class_name LogView
extends Control
## The player's archive: every recording and document found so far. Entries that have
## not been played/read yet are marked NEW. Clicking one opens it.

var _rec_box: VBoxContainer
var _doc_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := RetroStyle.centered_panel(Vector2(0.7, 0.7))
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	outer.add_child(RetroStyle.label("ARCHIVE", 22, RetroStyle.ACCENT))
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 24)
	outer.add_child(cols)
	_rec_box = _column(cols, "RECORDINGS")
	_doc_box = _column(cols, "DOCUMENTS")
	var close := RetroStyle.button("Close  [Tab / Esc]")
	close.pressed.connect(close_view)
	outer.add_child(close)
	panel.add_child(RetroStyle.scanlines())


func _column(parent: Control, heading: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	box.add_child(RetroStyle.label(heading, 15, RetroStyle.DIM))
	scroll.add_child(box)
	parent.add_child(scroll)
	return box


func is_open() -> bool:
	return visible


## Number of entry buttons currently listed (recordings + documents).
func item_count() -> int:
	return _items(_rec_box).size() + _items(_doc_box).size()


func item_texts() -> Array[String]:
	var out: Array[String] = []
	for b in _items(_rec_box) + _items(_doc_box):
		out.append((b as Button).text)
	return out


func open_view() -> void:
	rebuild()
	visible = true
	GameManager.push_modal("log")


func close_view() -> void:
	if not visible:
		return
	visible = false
	GameManager.pop_modal("log")


func rebuild() -> void:
	_clear(_rec_box)
	_clear(_doc_box)
	for rec: RecordingEntry in NarrativeState.unlocked_recordings():
		var mark := "" if NarrativeState.was_recording_played(rec.id) else "[NEW] "
		var b := RetroStyle.button("%s%s" % [mark, rec.title])
		b.pressed.connect(_open_item.bind("recording", rec.id))
		_rec_box.add_child(b)
	for doc: DocumentEntry in NarrativeState.found_documents():
		var mark := "" if NarrativeState.is_document_read(doc.id) else "[NEW] "
		var b := RetroStyle.button("%s%s" % [mark, doc.title])
		b.pressed.connect(_open_item.bind("document", doc.id))
		_doc_box.add_child(b)
	for box: VBoxContainer in [_rec_box, _doc_box]:
		if _items(box).is_empty():
			box.add_child(RetroStyle.label("(nothing yet)", 14, RetroStyle.DIM))


func _items(box: VBoxContainer) -> Array:
	return box.get_children().filter(func(n: Node) -> bool: return n is Button and not n.is_queued_for_deletion())


func _clear(box: VBoxContainer) -> void:
	for i in range(box.get_child_count() - 1, 0, -1):  # keep the heading label (index 0)
		var c := box.get_child(i)
		box.remove_child(c)
		c.queue_free()


func _open_item(kind: String, id: StringName) -> void:
	EventBus.publish(Events.UI_OPEN_REQUESTED, {"kind": kind, "id": id})


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(InputActions.PAUSE):
		close_view()
		get_viewport().set_input_as_handled()
