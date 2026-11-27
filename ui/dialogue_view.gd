class_name DialogueView
extends Control
## Dialogue box: speaker, typewriter text, numbered choices. Driven only by DIALOGUE_*
## events and DialogueManager calls. Keys: 1-6 choose, E/Enter/Space or click to
## continue (first press finishes the typing). Choice keys are not rebindable yet.

const CHARS_PER_SECOND := 70.0

var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _choice_box: VBoxContainer
var _hint: Label
var _reveal: float = 0.0
var _choice_texts: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 0.62
	_panel.anchor_bottom = 0.95
	_panel.add_theme_stylebox_override("panel", RetroStyle.box())
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_speaker = RetroStyle.label("", 18, RetroStyle.ACCENT)
	_text = RetroStyle.label("", 18)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 4)
	_hint = RetroStyle.label("[E / Enter / click] continue", 13, RetroStyle.DIM)
	box.add_child(_speaker)
	box.add_child(_text)
	box.add_child(_choice_box)
	box.add_child(_hint)
	_panel.add_child(RetroStyle.scanlines())
	EventBus.subscribe(Events.DIALOGUE_NODE, _on_node, true)
	EventBus.subscribe(Events.DIALOGUE_ENDED, _on_ended, true)


func is_showing() -> bool:
	return visible


func speaker_text() -> String:
	return _speaker.text


func body_text() -> String:
	return _text.text


func choice_count() -> int:
	return _choice_texts.size()


func is_typing() -> bool:
	return visible and _text.visible_characters < _text.text.length() and _text.visible_characters >= 0


func skip_typing() -> void:
	_text.visible_characters = -1
	_reveal = float(_text.text.length())
	_after_typing()


## Finishes typing if still typing, otherwise advances (no-op while choices are shown).
func press_continue() -> void:
	if not visible:
		return
	if is_typing():
		skip_typing()
	elif _choice_texts.is_empty():
		DialogueManager.advance()


func choose(index: int) -> void:
	if visible and not is_typing():
		DialogueManager.choose(index)


func _process(delta: float) -> void:
	if not is_typing():
		return
	_reveal += CHARS_PER_SECOND * delta
	_text.visible_characters = int(_reveal)
	if _text.visible_characters >= _text.text.length():
		skip_typing()


func _on_node(p: Dictionary) -> void:
	visible = true
	var speaker: String = p.get("speaker", "")
	var ch := NarrativeDatabase.get_character(StringName(speaker))
	_speaker.text = RetroStyle.character_name(speaker)
	_speaker.add_theme_color_override("font_color", ch.color if ch != null else RetroStyle.ACCENT)
	_text.text = NarrativeText.resolve(str(p.get("text", "")))
	_text.visible_characters = 0
	_reveal = 0.0
	_choice_texts.clear()
	for t: Variant in p.get("choices", []):
		_choice_texts.append(str(t))
	for c in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.queue_free()
	for i in _choice_texts.size():
		var b := RetroStyle.button("%d. %s" % [i + 1, _choice_texts[i]])
		b.pressed.connect(choose.bind(i))
		_choice_box.add_child(b)
	_choice_box.visible = false
	_hint.visible = false


func _after_typing() -> void:
	_choice_box.visible = not _choice_texts.is_empty()
	_hint.visible = _choice_texts.is_empty()
	if _choice_box.visible and _choice_box.get_child_count() > 0:
		(_choice_box.get_child(0) as Control).grab_focus()


func _on_ended(_p: Dictionary) -> void:
	visible = false
	_choice_texts.clear()


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		press_continue()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).physical_keycode
	if key >= KEY_1 and key <= KEY_6 and not is_typing():
		choose(key - KEY_1)
	elif event.is_action_pressed(InputActions.INTERACT) or key == KEY_ENTER or key == KEY_SPACE:
		press_continue()
	else:
		return
	get_viewport().set_input_as_handled()
