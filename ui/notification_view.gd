class_name NotificationView
extends Control
## Short toast messages for important story beats (top-right). Newest on top.

const LIFETIME := 4.5
const MAX_TOASTS := 4

var _box: VBoxContainer
var _toasts: Array[Dictionary] = []  # {node: Control, text: String, left: float}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.anchor_left = 1.0
	_box.anchor_right = 1.0
	_box.offset_left = -380
	_box.offset_right = -24
	_box.offset_top = 24
	_box.add_theme_constant_override("separation", 6)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)


func show_toast(text: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", RetroStyle.box(RetroStyle.ACCENT, RetroStyle.BG, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := RetroStyle.label(text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(l)
	_box.add_child(panel)
	_box.move_child(panel, 0)
	_toasts.push_front({"node": panel, "text": text, "left": LIFETIME})
	while _toasts.size() > MAX_TOASTS:
		_remove(_toasts.size() - 1)


func toast_texts() -> Array[String]:
	var out: Array[String] = []
	for t in _toasts:
		out.append(t["text"])
	return out


func _process(delta: float) -> void:
	for i in range(_toasts.size() - 1, -1, -1):
		_toasts[i]["left"] -= delta
		if _toasts[i]["left"] <= 0.0:
			_remove(i)


func _remove(index: int) -> void:
	var node: Control = _toasts[index]["node"]
	_toasts.remove_at(index)
	_box.remove_child(node)
	node.queue_free()
