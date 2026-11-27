class_name WaypointView
extends Control
## Objective guidance without a minimap: a diamond marker on screen pointing at the target of
## the first unfinished objective that has one (NavTarget id), with its name and distance.
## Off-screen or behind the player, it sticks to the screen edge so it always points the
## way. Hidden once you are close, and during dialogue/readers.

const MARGIN := 56.0
const ARRIVE_DISTANCE := 2.5

var shown: bool = false
var marker_position: Vector2 = Vector2.ZERO
var distance: float = 0.0
var label_text: String = ""
var on_screen: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	update_marker()
	queue_redraw()


func active_target_id() -> String:
	for o in NarrativeState.objectives():
		if not o["completed"] and o.get("target", "") != "":
			return o["target"]
	return ""


func update_marker() -> void:
	shown = false
	if GameManager.is_modal_open() or GameManager.state != GameManager.State.PLAYING:
		return
	var id := active_target_id()
	if id == "":
		return
	var target := NavTarget.find(get_tree(), id)
	var cam := get_viewport().get_camera_3d()
	if target == null or cam == null:
		return
	var pos := target.global_position
	distance = cam.global_position.distance_to(pos)
	if distance < ARRIVE_DISTANCE:
		return
	var vp := get_viewport_rect().size
	var behind := cam.is_position_behind(pos)
	var sp := cam.unproject_position(pos)
	if behind:
		sp = vp - sp  # mirror so the marker leans toward the side the target is on
	on_screen = not behind and Rect2(Vector2(MARGIN, MARGIN), vp - Vector2.ONE * MARGIN * 2.0).has_point(sp)
	marker_position = Vector2(clampf(sp.x, MARGIN, vp.x - MARGIN), clampf(sp.y, MARGIN, vp.y - MARGIN))
	if behind:  # pin to the bottom edge region rather than the middle of the screen
		marker_position.y = vp.y - MARGIN
	label_text = "%s  %d m" % [target.display_name if target.display_name != "" else String(target.target_id), int(round(distance))]
	shown = true


func _draw() -> void:
	if not shown:
		return
	var c := RetroStyle.ACCENT
	var p := marker_position
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -11), p + Vector2(9, 0), p + Vector2(0, 11), p + Vector2(-9, 0)]), Color(c, 0.85))
	draw_polyline(PackedVector2Array([p + Vector2(0, -11), p + Vector2(9, 0), p + Vector2(0, 11), p + Vector2(-9, 0), p + Vector2(0, -11)]), Color.BLACK, 1.5)
	var font := RetroStyle.font()
	var size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var pos := p + Vector2(-size.x / 2.0, 30)
	pos.x = clampf(pos.x, 8.0, get_viewport_rect().size.x - size.x - 8.0)
	draw_string_outline(font, pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.9))
	draw_string(font, pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)
