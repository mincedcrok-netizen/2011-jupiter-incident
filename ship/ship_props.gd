class_name ShipProps
extends RefCounted
## Procedural prop builders. Each builder adds MeshInstance3Ds under `root` and (when it
## should block the player) CollisionShape3Ds under `body`. Everything is primitives so the
## ship has a consistent look today; swap a builder for a real scene later without touching
## the level. Orientation: a prop's FRONT faces +Z (so rotation 0 against a north wall faces
## into the room; west wall = rotate Y +90, east wall = -90); +Y up.

## Small props and labels stop being drawn beyond this distance (no occlusion culling exists
## in the Compatibility renderer, so a long corridor would otherwise draw the whole deck).
const DETAIL_DISTANCE := 30.0


static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, body: StaticBody3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.visibility_range_end = DETAIL_DISTANCE
	parent.add_child(mi)
	if body != null:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		cs.rotation_degrees = rot_deg
		body.add_child(cs)
	return mi


static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, rot_deg: Vector3 = Vector3.ZERO, sides: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.visibility_range_end = DETAIL_DISTANCE
	parent.add_child(mi)
	return mi


static func pyramid(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 4
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.visibility_range_end = DETAIL_DISTANCE
	parent.add_child(mi)
	return mi


static func label(parent: Node3D, text: String, pos: Vector3, color: Color, pixel_size: float = 0.004, rot_deg: Vector3 = Vector3.ZERO) -> Label3D:
	var l := Label3D.new()
	l.text = NarrativeText.resolve(text)
	l.font_size = 64
	l.pixel_size = pixel_size
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.position = pos
	l.rotation_degrees = rot_deg
	l.visibility_range_end = DETAIL_DISTANCE
	parent.add_child(l)
	return l


# --- set pieces (solid) -------------------------------------------------------

static func build(kind: String, root: Node3D, body: StaticBody3D, text: String, length: float, color: Color, seed_value: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	match kind:
		"bunk": _bunk(root, body)
		"locker_row": _locker_row(root, body, rng)
		"crate_stack": _crate_stack(root, body, rng)
		"shelving": _shelving(root, body, rng)
		"console_bank": _console_bank(root, body, length, rng)
		"command_chair": _command_chair(root, body)
		"pipe_run": _pipe_run(root, length)
		"vent_grille": _vent_grille(root, text == "broken")
		"debris_pile": _debris_pile(root, body, rng)
		"hanging_panel": _hanging_panel(root, rng)
		"shard_cluster": _shard_cluster(root, rng)
		"sparks": _particles(root, Color(1.0, 0.8, 0.4), 0.9, true)
		"steam_vent": _particles(root, Color(0.8, 0.85, 0.9, 0.5), 2.2, false)
		"floor_line": _floor_line(root, length, color)
		"hazard_band": _hazard_band(root, length)
		"scorch": _scorch(root, length, rng)
		"sign": _sign(root, text, color)
		"camera_rig": _camera_rig(root)
		"table": _table(root, body, rng)
		"duffel_bags": _duffel_bags(root, rng)
		"blast_backing": box(root, Vector3(0, 1.5, 0.4), Vector3(4.0, 3.2, 0.6), ShipMaterials.named(&"metal_dark"), Vector3.ZERO, body)
		_:
			return false
	return true


static func _bunk(root: Node3D, body: StaticBody3D) -> void:
	var frame := ShipMaterials.named(&"metal_light")
	for x in [-0.95, 0.95]:
		for z in [-0.45, 0.45]:
			box(root, Vector3(x, 1.0, z), Vector3(0.08, 2.0, 0.08), frame, Vector3.ZERO, body)
	box(root, Vector3(0, 0.42, 0), Vector3(2.0, 0.08, 1.0), frame, Vector3.ZERO, body)
	box(root, Vector3(0, 1.45, 0), Vector3(2.0, 0.08, 1.0), frame, Vector3.ZERO, body)
	box(root, Vector3(0, 0.52, 0), Vector3(1.9, 0.12, 0.9), ShipMaterials.named(&"fabric_a"))
	box(root, Vector3(0, 1.55, 0), Vector3(1.9, 0.12, 0.9), ShipMaterials.named(&"fabric_b"))
	box(root, Vector3(-0.7, 0.64, 0), Vector3(0.45, 0.1, 0.6), ShipMaterials.named(&"paper"))
	box(root, Vector3(-0.7, 1.67, 0), Vector3(0.45, 0.1, 0.6), ShipMaterials.named(&"paper"))


static func _locker_row(root: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var x := (i - 1) * 0.62
		box(root, Vector3(x, 1.0, 0), Vector3(0.58, 2.0, 0.5), ShipMaterials.named(&"console"), Vector3.ZERO, body)
		box(root, Vector3(x, 1.2, 0.26), Vector3(0.5, 0.9, 0.03), ShipMaterials.named(&"metal_light"))
		box(root, Vector3(x + 0.18, 1.1, 0.29), Vector3(0.04, 0.2, 0.03), ShipMaterials.named(&"screen_amber"))
	# One door hangs open: someone left in a hurry.
	box(root, Vector3(-0.62 - 0.22, 1.0, 0.42), Vector3(0.5, 1.9, 0.03), ShipMaterials.named(&"metal_light"), Vector3(0, 62, 0))


static func _crate_stack(root: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var mats := [&"crate", &"crate_dark"]
	for i in rng.randi_range(3, 5):
		var s := rng.randf_range(0.6, 1.0)
		var level := i / 3
		var pos := Vector3(rng.randf_range(-0.5, 0.5) if level == 0 else rng.randf_range(-0.15, 0.15), s / 2.0 + level * 0.8, (i % 3) * 0.95 - 0.95)
		box(root, pos, Vector3(s, s, s), ShipMaterials.named(mats[rng.randi() % 2]), Vector3(0, rng.randf_range(-12, 12), 0), body)


static func _shelving(root: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var metal := ShipMaterials.named(&"metal_light")
	for x in [-0.9, 0.9]:
		box(root, Vector3(x, 1.1, 0), Vector3(0.06, 2.2, 0.5), metal, Vector3.ZERO, body)
	for i in 4:
		var y := 0.3 + i * 0.6
		box(root, Vector3(0, y, 0), Vector3(1.8, 0.05, 0.5), metal, Vector3.ZERO, body)
		for j in rng.randi_range(1, 3):
			var s := rng.randf_range(0.2, 0.4)
			box(root, Vector3(rng.randf_range(-0.7, 0.7), y + 0.025 + s / 2.0, 0), Vector3(s, s, s * 1.2), ShipMaterials.named(&"crate" if rng.randf() > 0.4 else &"crate_dark"))


static func _console_bank(root: Node3D, body: StaticBody3D, length: float, rng: RandomNumberGenerator) -> void:
	var l := maxf(length, 1.5)
	box(root, Vector3(0, 0.4, 0), Vector3(l, 0.8, 0.8), ShipMaterials.named(&"console"), Vector3.ZERO, body)
	box(root, Vector3(0, 0.95, 0.05), Vector3(l, 0.08, 0.7), ShipMaterials.named(&"metal_dark"), Vector3(18, 0, 0))
	var screens := int(l / 0.9)
	var mats := [&"screen_green", &"screen_cyan", &"screen_amber", &"screen_dead"]
	for i in screens:
		var x := -l / 2.0 + (i + 0.5) * (l / screens)
		box(root, Vector3(x, 1.35, -0.2), Vector3(0.7, 0.45, 0.06), ShipMaterials.named(mats[rng.randi() % mats.size()]), Vector3(-12, 0, 0))
		for k in 4:
			box(root, Vector3(x - 0.24 + k * 0.16, 1.0, 0.1), Vector3(0.07, 0.03, 0.07), ShipMaterials.named(&"screen_red" if rng.randf() > 0.7 else &"screen_cyan"))


static func _command_chair(root: Node3D, body: StaticBody3D) -> void:
	cylinder(root, Vector3(0, 0.25, 0), 0.25, 0.5, ShipMaterials.named(&"metal_dark"))
	box(root, Vector3(0, 0.62, 0), Vector3(0.7, 0.14, 0.7), ShipMaterials.named(&"fabric_a"))
	box(root, Vector3(0, 1.1, 0.32), Vector3(0.7, 0.9, 0.12), ShipMaterials.named(&"fabric_a"), Vector3(8, 0, 0))
	box(root, Vector3(-0.42, 0.9, 0), Vector3(0.1, 0.1, 0.55), ShipMaterials.named(&"metal_dark"))
	box(root, Vector3(0.42, 0.9, 0), Vector3(0.1, 0.1, 0.55), ShipMaterials.named(&"metal_dark"))
	box(root, Vector3(0, 0.5, 0), Vector3(0.9, 1.0, 0.9), ShipMaterials.named(&"metal_dark"), Vector3.ZERO, body).visible = false


static func _pipe_run(root: Node3D, length: float) -> void:
	for y in [0.0, 0.32]:
		cylinder(root, Vector3(0, y, 0), 0.14, length, ShipMaterials.named(&"pipe"), Vector3(90, 0, 0))
	for z in range(-int(length / 2.0), int(length / 2.0) + 1, 2):
		box(root, Vector3(0, 0.16, z), Vector3(0.22, 0.7, 0.1), ShipMaterials.named(&"metal_dark"))


static func _vent_grille(root: Node3D, broken: bool) -> void:
	box(root, Vector3(0, 0, 0), Vector3(1.1, 0.7, 0.08), ShipMaterials.named(&"metal_dark"))
	for i in 6:
		if broken and i in [1, 2, 3]:
			continue  # slats missing where something pushed through
		box(root, Vector3(0, -0.27 + i * 0.11, -0.05), Vector3(1.0, 0.04, 0.03), ShipMaterials.named(&"metal_light"))
	if broken:
		box(root, Vector3(0.35, -0.5, -0.3), Vector3(0.7, 0.05, 0.4), ShipMaterials.named(&"metal_light"), Vector3(-70, 0, 15))  # pried-off cover


static func _debris_pile(root: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(4, 7):
		var s := Vector3(rng.randf_range(0.2, 0.6), rng.randf_range(0.1, 0.3), rng.randf_range(0.2, 0.7))
		box(root, Vector3(rng.randf_range(-0.5, 0.5), s.y / 2.0, rng.randf_range(-0.5, 0.5)), s,
			ShipMaterials.named(&"rust" if rng.randf() > 0.4 else &"metal_dark"),
			Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 90), rng.randf_range(-12, 12)), body)


static func _hanging_panel(root: Node3D, rng: RandomNumberGenerator) -> void:
	box(root, Vector3(0, 0, 0), Vector3(1.6, 0.06, 1.2), ShipMaterials.named(&"metal_light"), Vector3(rng.randf_range(18, 30), 0, rng.randf_range(-8, 8)))
	for x in [-0.4, 0.3]:  # dangling cables
		cylinder(root, Vector3(x, 0.5, 0.2), 0.02, 1.0, ShipMaterials.named(&"metal_dark"), Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)), 6)


static func _shard_cluster(root: Node3D, rng: RandomNumberGenerator) -> void:
	var mat := ShipMaterials.crystal()
	for i in rng.randi_range(3, 5):
		var h := rng.randf_range(0.3, 0.9)
		pyramid(root, Vector3(rng.randf_range(-0.3, 0.3), h / 2.0, rng.randf_range(-0.3, 0.3)), rng.randf_range(0.1, 0.22), h, mat,
			Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 90), rng.randf_range(-25, 25)))
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.35, 1.0)
	l.light_energy = 0.7
	l.omni_range = 3.0
	l.shadow_enabled = false
	l.position = Vector3(0, 0.5, 0)
	root.add_child(l)


static func _particles(root: Node3D, color: Color, lifetime: float, burst: bool) -> void:
	var p := GPUParticles3D.new()
	p.amount = 24 if burst else 14
	p.lifetime = lifetime
	p.explosiveness = 0.9 if burst else 0.0
	p.one_shot = false
	p.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	p.visibility_range_end = DETAIL_DISTANCE
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0) if burst else Vector3(0, 1, 0)
	m.spread = 50.0 if burst else 12.0
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 3.0 if burst else 1.4
	m.gravity = Vector3(0, -6, 0) if burst else Vector3(0, 0.3, 0)
	m.scale_min = 0.5
	m.scale_max = 1.0
	m.color = color
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05) if burst else Vector2(0.7, 0.7)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.albedo_color = color
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if not burst:
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.albedo_texture = _soft_puff()
	q.material = qm
	p.draw_pass_1 = q
	root.add_child(p)


static var _puff: GradientTexture2D = null


## Soft round particle sprite (white centre fading to transparent).
static func _soft_puff() -> GradientTexture2D:
	if _puff == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 1.0])
		_puff = GradientTexture2D.new()
		_puff.gradient = g
		_puff.fill = GradientTexture2D.FILL_RADIAL
		_puff.fill_from = Vector2(0.5, 0.5)
		_puff.fill_to = Vector2(1.0, 0.5)
		_puff.width = 64
		_puff.height = 64
	return _puff


static func _floor_line(root: Node3D, length: float, color: Color) -> void:
	box(root, Vector3(0, 0.012, 0), Vector3(0.12, 0.02, maxf(length, 0.2)), ShipMaterials.glow(color, 1.2))


static func _hazard_band(root: Node3D, length: float) -> void:
	box(root, Vector3(0, 0.012, 0), Vector3(0.5, 0.02, maxf(length, 0.2)), ShipMaterials.hazard())


static func _scorch(root: Node3D, length: float, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(rng.randf_range(0.8, 1.6) * maxf(length, 0.6), rng.randf_range(0.8, 1.6))
		q.mesh = qm
		q.material_override = ShipMaterials.scorch()
		q.position = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.3), 0.001 * (i + 1))
		q.rotation_degrees.z = rng.randf_range(-20, 20)
		q.visibility_range_end = DETAIL_DISTANCE
		root.add_child(q)


static func _sign(root: Node3D, text: String, color: Color) -> void:
	# Plate sized to its text: ~0.55 em per character at 64 px, shrunk so no sign exceeds 2.4 m.
	var resolved := NarrativeText.resolve(text)
	var lines := resolved.split("\n")
	var longest := 1
	for l in lines:
		longest = maxi(longest, l.length())
	var px := 0.0035
	var width := longest * 64.0 * 0.55 * px + 0.3
	if width > 2.4:
		px *= 2.4 / width
		width = 2.4
	var h := 0.2 + lines.size() * 64.0 * px * 1.25
	box(root, Vector3(0, 0, 0), Vector3(maxf(width, 0.9), h, 0.04), ShipMaterials.named(&"metal_dark"))
	label(root, text, Vector3(0, 0, 0.025), color, px)


static func _camera_rig(root: Node3D) -> void:
	for a in [0.0, 120.0, 240.0]:
		var r := deg_to_rad(a)
		box(root, Vector3(sin(r) * 0.3, 0.6, cos(r) * 0.3), Vector3(0.04, 1.2, 0.04), ShipMaterials.named(&"metal_dark"), Vector3(sin(r) * 10, 0, cos(r) * 10))
	box(root, Vector3(0, 1.3, 0), Vector3(0.22, 0.2, 0.34), ShipMaterials.named(&"metal_dark"))
	box(root, Vector3(0, 1.3, -0.22), Vector3(0.12, 0.12, 0.14), ShipMaterials.named(&"console"))
	box(root, Vector3(0.08, 1.42, -0.08), Vector3(0.04, 0.04, 0.04), ShipMaterials.named(&"screen_red"))  # REC light


static func _table(root: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	box(root, Vector3(0, 0.75, 0), Vector3(1.8, 0.06, 0.9), ShipMaterials.named(&"metal_light"), Vector3.ZERO, body)
	for x in [-0.8, 0.8]:
		box(root, Vector3(x, 0.37, 0), Vector3(0.06, 0.74, 0.7), ShipMaterials.named(&"metal_dark"), Vector3.ZERO, body)
	for i in 5:  # snack wrappers, a mug, playing cards
		box(root, Vector3(rng.randf_range(-0.7, 0.7), 0.8, rng.randf_range(-0.3, 0.3)), Vector3(rng.randf_range(0.08, 0.2), 0.03, rng.randf_range(0.08, 0.15)),
			ShipMaterials.named([&"screen_amber", &"paper", &"screen_cyan", &"fabric_b", &"paper"][i]), Vector3(0, rng.randf_range(0, 180), 0))
	cylinder(root, Vector3(0.5, 0.86, 0.2), 0.05, 0.12, ShipMaterials.named(&"metal_light"))


static func _duffel_bags(root: Node3D, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var c := cylinder(root, Vector3(i * 0.7 - 0.7, 0.25, rng.randf_range(-0.1, 0.1)), 0.25, 0.8, ShipMaterials.named(&"fabric_b" if i % 2 else &"fabric_a"), Vector3(0, rng.randf_range(0, 40), 90), 8)
		c.position.y = 0.25


# --- interactable visuals -----------------------------------------------------

## Builds the visual for an interactable kind under `root`; returns the collision box
## {size, offset} used for focus raycasts.
static func build_interactable(kind: String, root: Node3D) -> Dictionary:
	match kind:
		"terminal", "terminal_damaged":
			box(root, Vector3(0, 0.55, 0), Vector3(0.9, 1.1, 0.6), ShipMaterials.named(&"console"))
			box(root, Vector3(0, 1.3, -0.05), Vector3(0.85, 0.55, 0.1), ShipMaterials.named(&"metal_dark"), Vector3(-14, 0, 0))
			var scr := box(root, Vector3(0, 1.3, 0.03), Vector3(0.74, 0.44, 0.03), ShipMaterials.named(&"screen_red" if kind == "terminal_damaged" else &"screen_green"), Vector3(-14, 0, 0))
			scr.name = "Screen"
			return {"size": Vector3(0.95, 1.7, 0.7), "offset": Vector3(0, 0.85, 0)}
		"footlocker":
			box(root, Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.5), ShipMaterials.named(&"crate_dark"))
			box(root, Vector3(0, 0.52, 0), Vector3(0.92, 0.05, 0.52), ShipMaterials.named(&"metal_light"))
			box(root, Vector3(0, 0.34, 0.26), Vector3(0.12, 0.1, 0.03), ShipMaterials.named(&"screen_amber"))
			return {"size": Vector3(0.95, 0.9, 0.65), "offset": Vector3(0, 0.45, 0)}
		"black_box":
			box(root, Vector3(0, 0.15, 0), Vector3(0.5, 0.3, 0.35), ShipMaterials.named(&"screen_amber"))
			box(root, Vector3(0, 0.32, 0), Vector3(0.52, 0.04, 0.37), ShipMaterials.named(&"metal_dark"))
			var led := box(root, Vector3(0.18, 0.35, 0.12), Vector3(0.05, 0.03, 0.05), ShipMaterials.named(&"screen_red"))
			led.name = "Screen"
			return {"size": Vector3(0.7, 0.55, 0.55), "offset": Vector3(0, 0.27, 0)}
		"radio":
			box(root, Vector3(0, 0.12, 0), Vector3(0.45, 0.24, 0.22), ShipMaterials.named(&"metal_dark"))
			box(root, Vector3(-0.1, 0.13, 0.12), Vector3(0.16, 0.12, 0.02), ShipMaterials.named(&"screen_dead"))
			box(root, Vector3(0.12, 0.13, 0.12), Vector3(0.1, 0.1, 0.02), ShipMaterials.named(&"screen_amber"))
			return {"size": Vector3(0.65, 0.5, 0.45), "offset": Vector3(0, 0.25, 0)}
		"pad":
			box(root, Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.3), ShipMaterials.named(&"console"))
			box(root, Vector3(0, 0.7, 0.16), Vector3(0.4, 0.3, 0.02), ShipMaterials.named(&"screen_cyan"))
			return {"size": Vector3(0.55, 1.0, 0.35), "offset": Vector3(0, 0.5, 0)}
		"crystal":
			var mat := ShipMaterials.crystal()
			pyramid(root, Vector3(0, 0.2, 0), 0.16, 0.4, mat, Vector3(8, 20, -6))
			pyramid(root, Vector3(0.18, 0.12, 0.05), 0.1, 0.24, mat, Vector3(-18, 50, 14))
			return {"size": Vector3(0.7, 0.7, 0.65), "offset": Vector3(0.05, 0.35, 0)}
		"crate_open":
			box(root, Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.7), ShipMaterials.named(&"crate"))
			for i in 4:
				cylinder(root, Vector3(-0.27 + i * 0.18, 0.66, 0), 0.07, 0.2, ShipMaterials.named(&"screen_amber"))
			return {"size": Vector3(0.95, 0.95, 0.8), "offset": Vector3(0, 0.47, 0)}
	return {}
