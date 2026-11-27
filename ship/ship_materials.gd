class_name ShipMaterials
extends RefCounted
## Cached materials for the ship kit. Everything is procedural (no image files): panelled
## walls via a generated texture + triplanar mapping, so any box looks like plated hull
## without per-mesh UVs. Zone palettes give each area its own colour identity.

const ZONES := {
	&"corridor": {"wall": Color(0.50, 0.56, 0.62), "floor": Color(0.26, 0.29, 0.33), "ceiling": Color(0.34, 0.37, 0.42), "trim": Color(0.2, 0.85, 1.0)},
	&"bridge": {"wall": Color(0.30, 0.37, 0.50), "floor": Color(0.18, 0.21, 0.30), "ceiling": Color(0.24, 0.28, 0.38), "trim": Color(0.55, 0.78, 1.0)},
	&"quarters": {"wall": Color(0.58, 0.52, 0.46), "floor": Color(0.30, 0.25, 0.21), "ceiling": Color(0.40, 0.35, 0.30), "trim": Color(1.0, 0.62, 0.2)},
	&"storage": {"wall": Color(0.46, 0.52, 0.43), "floor": Color(0.23, 0.26, 0.21), "ceiling": Color(0.32, 0.35, 0.30), "trim": Color(0.3, 1.0, 0.5)},
	&"damaged": {"wall": Color(0.36, 0.32, 0.32), "floor": Color(0.19, 0.16, 0.16), "ceiling": Color(0.25, 0.22, 0.22), "trim": Color(1.0, 0.2, 0.15)},
	&"engineering": {"wall": Color(0.54, 0.43, 0.36), "floor": Color(0.25, 0.20, 0.17), "ceiling": Color(0.33, 0.28, 0.24), "trim": Color(1.0, 0.5, 0.1)},
}

static var _cache: Dictionary = {}
static var _panel_tex: ImageTexture = null
static var _grate_tex: ImageTexture = null
static var _hazard_tex: ImageTexture = null


static func zone_color(zone: StringName, which: String) -> Color:
	var z: Dictionary = ZONES.get(zone, ZONES[&"corridor"])
	return z[which]


static func wall(zone: StringName) -> StandardMaterial3D:
	return _cached("wall:%s" % zone, func() -> Material:
		return _textured(zone_color(zone, "wall"), _panels(), 0.35, 0.6, 0.25))


static func floor_mat(zone: StringName) -> StandardMaterial3D:
	return _cached("floor:%s" % zone, func() -> Material:
		return _textured(zone_color(zone, "floor"), _grate(), 0.5, 0.55, 0.5))


static func ceiling(zone: StringName) -> StandardMaterial3D:
	return _cached("ceiling:%s" % zone, func() -> Material:
		return _textured(zone_color(zone, "ceiling"), _panels(), 0.3, 0.7, 0.25))


static func trim(zone: StringName) -> StandardMaterial3D:
	return glow(zone_color(zone, "trim"), 1.6)


static func glow(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	return _cached("glow:%s:%s" % [color.to_html(), energy], func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = color.darkened(0.5)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		return m)


static func solid(color: Color, metallic: float = 0.2, roughness: float = 0.7) -> StandardMaterial3D:
	return _cached("solid:%s:%s:%s" % [color.to_html(), metallic, roughness], func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = roughness
		return m)


static func hazard() -> StandardMaterial3D:
	return _cached("hazard", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_texture = _hazard()
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(1.5, 1.5, 1.5)
		m.roughness = 0.8
		return m)


static func glass() -> StandardMaterial3D:
	return _cached("glass", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.5, 0.7, 0.9, 0.12)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic = 0.6
		return m)


static func crystal() -> StandardMaterial3D:
	return _cached("crystal", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.45, 0.35, 0.75)
		m.metallic = 0.9
		m.roughness = 0.15
		m.emission_enabled = true
		m.emission = Color(0.55, 0.3, 1.0)
		m.emission_energy_multiplier = 0.9
		return m)


static func scorch() -> StandardMaterial3D:
	return _cached("scorch", func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.02, 0.02, 0.02, 0.7)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 1.0
		return m)


## Named materials for props.
static func named(material_name: StringName) -> Material:
	match material_name:
		&"metal_dark": return solid(Color(0.14, 0.15, 0.17), 0.7, 0.45)
		&"metal_light": return solid(Color(0.62, 0.65, 0.70), 0.7, 0.4)
		&"console": return solid(Color(0.20, 0.23, 0.28), 0.5, 0.5)
		&"crate": return solid(Color(0.40, 0.34, 0.22), 0.05, 0.9)
		&"crate_dark": return solid(Color(0.22, 0.26, 0.22), 0.1, 0.85)
		&"fabric_a": return solid(Color(0.30, 0.38, 0.55), 0.0, 1.0)
		&"fabric_b": return solid(Color(0.55, 0.30, 0.28), 0.0, 1.0)
		&"pipe": return solid(Color(0.58, 0.48, 0.38), 0.8, 0.45)
		&"rust": return solid(Color(0.42, 0.22, 0.12), 0.4, 0.9)
		&"screen_green": return glow(Color(0.2, 1.0, 0.5), 1.3)
		&"screen_cyan": return glow(Color(0.2, 0.85, 1.0), 1.3)
		&"screen_red": return glow(Color(1.0, 0.2, 0.15), 1.3)
		&"screen_amber": return glow(Color(1.0, 0.7, 0.2), 1.3)
		&"screen_dead": return solid(Color(0.02, 0.03, 0.03), 0.3, 0.2)
		&"paper": return solid(Color(0.85, 0.82, 0.7), 0.0, 1.0)
	return solid(Color(1, 0, 1))  # unmistakable "missing material" magenta


static func _cached(key: String, make: Callable) -> Variant:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


static func _textured(color: Color, tex: Texture2D, metallic: float, roughness: float, tri_scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = tex
	m.metallic = metallic
	m.roughness = roughness
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * tri_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _hash(x: int, y: int) -> float:
	return fposmod(sin(float(x) * 127.1 + float(y) * 311.7) * 43758.5453, 1.0)


## 4x4 hull panels (64 px each): seams, rivets and per-panel wear variation.
static func _panels() -> ImageTexture:
	if _panel_tex != null:
		return _panel_tex
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for py in 256:
		for px in 256:
			var ix := px / 64
			var iy := py / 64
			var v := 0.78 + 0.22 * _hash(ix, iy)
			var lx := px % 64
			var ly := py % 64
			if lx < 2 or ly < 2:
				v *= 0.45
			elif (lx < 8 or lx > 56) and (ly < 8 or ly > 56) and lx % 56 in [4, 3, 5] and ly % 56 in [4, 3, 5]:
				v *= 0.6  # rivets at the panel corners
			img.set_pixel(px, py, Color(v, v, v))
	_panel_tex = ImageTexture.create_from_image(img)
	return _panel_tex


static func _grate() -> ImageTexture:
	if _grate_tex != null:
		return _grate_tex
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for py in 128:
		for px in 128:
			var v := 0.55 + 0.25 * _hash(px / 16, py / 16)
			if px % 16 < 4:
				v += 0.25
			if py % 64 < 2:
				v *= 0.5
			img.set_pixel(px, py, Color(v, v, v))
	_grate_tex = ImageTexture.create_from_image(img)
	return _grate_tex


static func _hazard() -> ImageTexture:
	if _hazard_tex != null:
		return _hazard_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for py in 64:
		for px in 64:
			img.set_pixel(px, py, Color(0.95, 0.75, 0.1) if ((px + py) / 16) % 2 == 0 else Color(0.06, 0.06, 0.06))
	_hazard_tex = ImageTexture.create_from_image(img)
	return _hazard_tex
