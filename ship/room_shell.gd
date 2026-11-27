class_name RoomShell
extends Node3D
## Builds a room's hull from primitive boxes: floor, ceiling and four walls with door /
## window openings, collision on the WORLD layer, emissive trim, destination signs above
## doors, and an area trigger that announces "player entered this room".
##
## Origin = centre of the floor; `size` is the OUTER box. Walls sit inside that box, so two
## rooms that touch share a plane with two wall thicknesses between them; a door placed on
## that plane (and an opening in both walls) joins them. Large surfaces are split into
## chunks so culling and per-mesh light limits behave.
##
## openings: Array of {side: north|south|east|west, offset (along the wall from its centre),
##   width, height, kind: "door" | "window" (default door), sill (windows), label (door sign)}
## north = -Z, south = +Z, east = +X, west = -X.

const SIDES := ["north", "south", "east", "west"]
const HULL_DISTANCE := 70.0  # hull pieces are culled well beyond any sightline in the slice
const KINDS := ["door", "window"]

@export var room_id: StringName = &""
@export var display_name: String = ""
@export var zone: StringName = &"corridor"
@export var size: Vector3 = Vector3(6, 3.4, 6)
@export var wall_thickness: float = 0.4
@export var openings: Array = []
@export var chunk_length: float = 8.0
@export var make_trigger: bool = true

var piece_count: int = 0
var trim_count: int = 0
var built: bool = false
var _body: StaticBody3D
var _trim: Array = []  # [Vector3 position, Vector3 size]: merged into ONE mesh per room


func _ready() -> void:
	add_to_group("rooms")
	var errs := validate()
	for e in errs:
		GameManager.report_error("room_shell", "%s: %s" % [room_id, e])
	if errs.is_empty():
		build()


func validate() -> Array[String]:
	var errs: Array[String] = []
	if room_id == &"":
		errs.append("missing room_id")
	if size.x < 3.0 or size.y < 2.5 or size.z < 3.0:
		errs.append("size %s is too small" % str(size))
	for side in SIDES:
		var spans: Array = []
		var length := _wall_length(side)
		for o: Dictionary in _openings_on(side):
			var w := float(o.get("width", 0.0))
			var h := float(o.get("height", 0.0))
			var off := float(o.get("offset", 0.0))
			if not (o.get("kind", "door") in KINDS):
				errs.append("%s opening has unknown kind" % side)
			if w < 0.8 or h < 1.0 or h > size.y - 0.3:
				errs.append("%s opening has a bad width/height (%.1f x %.1f)" % [side, w, h])
			if absf(off) + w / 2.0 > length / 2.0 - 0.3:
				errs.append("%s opening at offset %.1f does not fit in the wall" % [side, off])
			spans.append([off - w / 2.0, off + w / 2.0])
		spans.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for i in range(1, spans.size()):
			if spans[i][0] - spans[i - 1][1] < 0.3:
				errs.append("%s openings overlap or are too close together" % side)
	return errs


func interior_size() -> Vector3:
	return Vector3(size.x - 2.0 * wall_thickness, size.y, size.z - 2.0 * wall_thickness)


func contains_point(global_point: Vector3) -> bool:
	var p := to_local(global_point)
	var half := interior_size() / 2.0
	return absf(p.x) <= half.x and absf(p.z) <= half.z and p.y >= -0.1 and p.y <= size.y


func build() -> void:
	if built:
		return
	built = true
	_body = StaticBody3D.new()
	_body.name = "Hull"
	_body.collision_layer = PhysicsLayers.WORLD
	_body.collision_mask = 0
	add_child(_body)
	_build_floor_and_ceiling()
	for side in SIDES:
		_build_wall(side)
	_build_ceiling_strips()
	_flush_trim()
	if make_trigger:
		_build_trigger()


# --- geometry ----------------------------------------------------------------

func _add_piece(pos: Vector3, sz: Vector3, mat: Material, collide: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.visibility_range_end = HULL_DISTANCE
	add_child(mi)
	piece_count += 1
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		cs.position = pos
		_body.add_child(cs)


func _build_floor_and_ceiling() -> void:
	var nx := ceili(size.x / chunk_length)
	var nz := ceili(size.z / chunk_length)
	var cx := size.x / nx
	var cz := size.z / nz
	for ix in nx:
		for iz in nz:
			var x := -size.x / 2.0 + cx * (ix + 0.5)
			var z := -size.z / 2.0 + cz * (iz + 0.5)
			_add_piece(Vector3(x, -0.15, z), Vector3(cx, 0.3, cz), ShipMaterials.floor_mat(zone))
			_add_piece(Vector3(x, size.y + 0.15, z), Vector3(cx, 0.3, cz), ShipMaterials.ceiling(zone))


func _wall_length(side: String) -> float:
	return size.x if (side == "north" or side == "south") else size.z - 2.0 * wall_thickness


func _openings_on(side: String) -> Array:
	var out: Array = []
	for o: Dictionary in openings:
		if o.get("side", "") == side:
			out.append(o)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["offset"]) < float(b["offset"]))
	return out


func _plane(side: String) -> float:
	var t := wall_thickness
	match side:
		"north": return -(size.z / 2.0 - t / 2.0)
		"south": return size.z / 2.0 - t / 2.0
		"east": return size.x / 2.0 - t / 2.0
	return -(size.x / 2.0 - t / 2.0)  # west


## Position/size of a wall box spanning [a, b] along the wall axis and [y0, y1] vertically.
func _wall_box(side: String, a: float, b: float, y0: float, y1: float, thick: float) -> Array:
	var c := (a + b) / 2.0
	var len := b - a
	var y := (y0 + y1) / 2.0
	var h := y1 - y0
	if side == "north" or side == "south":
		return [Vector3(c, y, _plane(side)), Vector3(len, h, thick)]
	return [Vector3(_plane(side), y, c), Vector3(thick, h, len)]


func _wall_run(side: String, a: float, b: float, y0: float, y1: float) -> void:
	if b - a < 0.01 or y1 - y0 < 0.01:
		return
	var n := ceili((b - a) / chunk_length)
	var step := (b - a) / n
	for i in n:
		var box := _wall_box(side, a + step * i, a + step * (i + 1), y0, y1, wall_thickness)
		_add_piece(box[0], box[1], ShipMaterials.wall(zone))
		if y0 <= 0.001:
			_add_baseboard(side, a + step * i, a + step * (i + 1))


func _inner_offset(side: String, inset: float) -> Vector3:
	# A step from the wall's centre plane toward the room interior.
	var d := wall_thickness / 2.0 + inset
	match side:
		"north": return Vector3(0, 0, d)
		"south": return Vector3(0, 0, -d)
		"east": return Vector3(-d, 0, 0)
	return Vector3(d, 0, 0)


func _add_baseboard(side: String, a: float, b: float) -> void:
	var box := _wall_box(side, a, b, 0.1, 0.16, 0.05)
	_trim.append([box[0] + _inner_offset(side, 0.0), box[1]])


## One merged mesh for every emissive strip in the room (instead of dozens of tiny meshes).
func _flush_trim() -> void:
	if _trim.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t: Array in _trim:
		var bm := BoxMesh.new()
		bm.size = t[1]
		st.append_from(bm, 0, Transform3D(Basis.IDENTITY, t[0]))
	var mi := MeshInstance3D.new()
	mi.name = "Trim"
	mi.mesh = st.commit()
	mi.material_override = ShipMaterials.trim(zone)
	mi.visibility_range_end = HULL_DISTANCE
	add_child(mi)
	trim_count = _trim.size()
	_trim.clear()


func _build_wall(side: String) -> void:
	var length := _wall_length(side)
	var cursor := -length / 2.0
	for o: Dictionary in _openings_on(side):
		var off := float(o["offset"])
		var w := float(o["width"])
		var h := float(o["height"])
		var sill := float(o.get("sill", 1.0 if o.get("kind", "door") == "window" else 0.0))
		_wall_run(side, cursor, off - w / 2.0, 0.0, size.y)
		var a := off - w / 2.0
		var b := off + w / 2.0
		if size.y - h > 0.01:  # lintel
			var lb := _wall_box(side, a, b, h, size.y, wall_thickness)
			_add_piece(lb[0], lb[1], ShipMaterials.wall(zone))
		if sill > 0.01:
			var sb := _wall_box(side, a, b, 0.0, sill, wall_thickness)
			_add_piece(sb[0], sb[1], ShipMaterials.wall(zone))
		if o.get("kind", "door") == "window":
			var gb := _wall_box(side, a, b, sill, h, 0.06)
			_add_piece(gb[0], gb[1], ShipMaterials.glass())
		if str(o.get("label", "")) != "":
			_add_door_sign(side, off, h, str(o["label"]))
		cursor = b
	_wall_run(side, cursor, length / 2.0, 0.0, size.y)


func _add_door_sign(side: String, offset: float, opening_h: float, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.0045
	l.modulate = ShipMaterials.zone_color(zone, "trim").lightened(0.2)
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.no_depth_test = false
	l.visibility_range_end = 30.0
	var y := opening_h + (size.y - opening_h) / 2.0
	var inner := _inner_offset(side, 0.03)
	if side == "north" or side == "south":
		l.position = Vector3(offset, y, _plane(side)) + inner
	else:
		l.position = Vector3(_plane(side), y, offset) + inner
	match side:  # Label3D faces +Z; turn it toward the room interior
		"south": l.rotation_degrees.y = 180.0
		"east": l.rotation_degrees.y = -90.0
		"west": l.rotation_degrees.y = 90.0
	add_child(l)


func _build_ceiling_strips() -> void:
	var along_z := size.z >= size.x
	var length := (size.z if along_z else size.x) - 2.0 * wall_thickness - 1.0
	var seg := 2.4
	var gap := 1.6
	var n := int(length / (seg + gap))
	var start := -((n - 1) * (seg + gap)) / 2.0
	for i in n:
		var c := start + i * (seg + gap)
		var pos := Vector3(0, size.y - 0.02, c) if along_z else Vector3(c, size.y - 0.02, 0)
		var sz := Vector3(0.28, 0.04, seg) if along_z else Vector3(seg, 0.04, 0.28)
		_trim.append([pos, sz])


func _build_trigger() -> void:
	var t := NarrativeTrigger.new()
	t.name = "RoomTrigger"
	t.trigger_id = StringName("room_%s" % room_id)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var inner := interior_size()
	bs.size = Vector3(inner.x, size.y, inner.z)
	cs.shape = bs
	cs.position = Vector3(0, size.y / 2.0, 0)
	t.add_child(cs)
	add_child(t)
