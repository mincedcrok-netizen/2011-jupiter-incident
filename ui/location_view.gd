class_name LocationView
extends Control
## Consistent room identification: a persistent "LOCATION" tag (bottom-left) and a large
## title that fades in for a few seconds each time the player enters a room.

const BANNER_SECONDS := 3.2

var current_room: StringName = &""
var _tag: Label
var _banner: Label
var _banner_left: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag = RetroStyle.label("", 14, RetroStyle.DIM)
	_tag.anchor_top = 1.0
	_tag.anchor_bottom = 1.0
	_tag.offset_left = 24
	_tag.offset_top = -40
	add_child(_tag)
	_banner = RetroStyle.label("", 30, RetroStyle.ACCENT)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.14
	_banner.anchor_bottom = 0.14
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	add_child(_banner)
	EventBus.subscribe(Events.AREA_ENTERED, _on_area_entered, true)


func location_text() -> String:
	return _tag.text


func banner_text() -> String:
	return _banner.text


func banner_alpha() -> float:
	return _banner.modulate.a


func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.modulate.a = clampf(minf(_banner_left, 1.0), 0.0, 1.0) * (1.0 if _banner_left < BANNER_SECONDS - 0.4 else (BANNER_SECONDS - _banner_left) / 0.4)


func enter_room(room: RoomShell) -> void:
	if room.room_id == current_room:
		return
	current_room = room.room_id
	var name_text := room.display_name.to_upper()
	_tag.text = "LOCATION: %s" % name_text
	_banner.text = name_text
	_banner_left = BANNER_SECONDS


static func find_room(tree: SceneTree, room_id: String) -> RoomShell:
	for n in tree.get_nodes_in_group("rooms"):
		if n is RoomShell and String((n as RoomShell).room_id) == room_id:
			return n
	return null


func _on_area_entered(p: Dictionary) -> void:
	var id := str(p.get("trigger_id", ""))
	if not id.begins_with("room_") or not is_inside_tree():
		return
	var room := find_room(get_tree(), id.substr(5))
	if room != null:
		enter_room(room)
