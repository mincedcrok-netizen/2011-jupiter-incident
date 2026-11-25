class_name DocumentView
extends Control
## Reader for documents. Opening a found document marks it read.

const KIND_LABELS := {
	"crew_report": "CREW REPORT", "personal_note": "PERSONAL NOTE", "technical_log": "TECHNICAL LOG",
	"incident_report": "INCIDENT REPORT", "classified": "CLASSIFIED RECORD",
}

var _title: Label
var _meta: Label
var _banner: Label
var _body: Label
var _open_id: StringName = &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := RetroStyle.centered_panel(Vector2(0.6, 0.78))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_banner = RetroStyle.label("", 16, RetroStyle.WARN)
	_title = RetroStyle.label("", 22, RetroStyle.ACCENT)
	_meta = RetroStyle.label("", 13, RetroStyle.DIM)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body = RetroStyle.label("", 17)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	var close := RetroStyle.button("Close  [Esc]")
	close.pressed.connect(close_view)
	for n in [_banner, _title, _meta, scroll, close]:
		box.add_child(n)
	panel.add_child(RetroStyle.scanlines())


func is_open() -> bool:
	return visible


func title_text() -> String:
	return _title.text


func body_text() -> String:
	return _body.text


func banner_text() -> String:
	return _banner.text


func open_document(id: StringName) -> bool:
	var doc := NarrativeDatabase.get_document(id)
	if doc == null or not NarrativeState.is_document_found(id):
		return false
	_open_id = id
	_title.text = doc.title
	var parts: Array[String] = [KIND_LABELS.get(doc.kind, doc.kind)]
	if doc.author != "":
		parts.append("FROM: " + RetroStyle.character_name(doc.author))
	if doc.in_world_date != "":
		parts.append(doc.in_world_date)
	_meta.text = "  |  ".join(parts)
	var secret := doc.kind == "classified" or doc.classification != ""
	_banner.text = ("*** CLASSIFIED %s ***" % doc.classification).strip_edges() if secret else ""
	_banner.visible = secret
	_body.text = doc.body
	NarrativeState.mark_document_read(id)
	GameManager.push_modal("document")
	visible = true
	return true


func close_view() -> void:
	if not visible:
		return
	visible = false
	_open_id = &""
	GameManager.pop_modal("document")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(InputActions.PAUSE):
		close_view()
		get_viewport().set_input_as_handled()
