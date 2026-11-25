class_name ObjectivesView
extends Control
## HUD list of objectives (top-left). Shows the most recent few; finished ones are dimmed.

const MAX_SHOWN := 5

var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.position = Vector2(24, 24)
	_box.add_theme_constant_override("separation", 4)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	EventBus.subscribe(Events.OBJECTIVE_CHANGED, func(_p: Dictionary) -> void: refresh(), true)
	EventBus.subscribe(Events.LOAD_COMPLETED, func(_p: Dictionary) -> void: refresh(), true)
	refresh()


func lines() -> Array[String]:
	var out: Array[String] = []
	for c in _box.get_children():
		if c is Label and not c.is_queued_for_deletion() and c.get_meta("objective", false):
			out.append((c as Label).text)
	return out


func refresh() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var all := NarrativeState.objectives()
	if all.is_empty():
		return
	_box.add_child(RetroStyle.label("OBJECTIVES", 13, RetroStyle.DIM))
	for o in all.slice(maxi(0, all.size() - MAX_SHOWN)):
		var done: bool = o["completed"]
		var l := RetroStyle.label("%s %s" % ["[x]" if done else "[ ]", o["text"]], 16,
			RetroStyle.DIM if done else RetroStyle.ACCENT)
		l.set_meta("objective", true)
		_box.add_child(l)
