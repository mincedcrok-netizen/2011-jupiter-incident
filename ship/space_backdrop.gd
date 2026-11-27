class_name SpaceBackdrop
extends Node3D
## The world outside the hull: a star sky, a deep-space environment (dim ambient, light fog
## so corridors fall off into darkness) and Jupiter with its Great Red Spot, visible through
## the bridge window. Purely visual; Jupiter's station and the O. Algo source are NOT
## depicted (unresolved lore).

const STAR_SKY := """
shader_type sky;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void sky() {
	vec3 d = EYEDIR;
	vec2 uv = vec2(atan(d.z, d.x), asin(clamp(d.y, -1.0, 1.0)));
	vec2 g = floor(uv * 90.0);
	float h = hash(g);
	float star = step(0.985, h) * (0.35 + 0.65 * hash(g + 3.1));
	COLOR = vec3(0.006, 0.008, 0.016) + vec3(star) * vec3(0.9, 0.95, 1.0);
}
"""

const JUPITER := """
shader_type spatial;
render_mode unshaded;
varying vec3 n;
void vertex() { n = NORMAL; }
void fragment() {
	float band = sin(UV.y * 38.0 + sin(UV.x * 12.0) * 0.6) * 0.5 + 0.5;
	float band2 = sin(UV.y * 14.0 + 1.3) * 0.5 + 0.5;
	vec3 col = mix(mix(vec3(0.78, 0.58, 0.40), vec3(0.55, 0.33, 0.22), band), vec3(0.90, 0.80, 0.66), band2 * 0.35);
	vec2 d = (UV - vec2(0.62, 0.60)) * vec2(1.0 / 0.07, 1.0 / 0.035);
	col = mix(col, vec3(0.75, 0.18, 0.10), smoothstep(1.0, 0.6, length(d)));
	float lit = clamp(dot(normalize(n), normalize(vec3(-0.6, 0.4, 0.7))) * 0.6 + 0.5, 0.12, 1.0);
	ALBEDO = col * lit;
}
"""

@export var jupiter_position: Vector3 = Vector3(24, 16, -175)
@export var jupiter_radius: float = 36.0

var world_environment: WorldEnvironment
var jupiter: MeshInstance3D


func _ready() -> void:
	var sky_shader := Shader.new()
	sky_shader.code = STAR_SKY
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = sky_shader
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.32, 0.42)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.07, 0.1)
	env.fog_density = 0.012
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	world_environment = WorldEnvironment.new()
	world_environment.environment = env
	add_child(world_environment)
	var sm := SphereMesh.new()
	sm.radius = jupiter_radius
	sm.height = jupiter_radius * 2.0
	sm.radial_segments = 48
	sm.rings = 24
	jupiter = MeshInstance3D.new()
	jupiter.mesh = sm
	var js := Shader.new()
	js.code = JUPITER
	var jm := ShaderMaterial.new()
	jm.shader = js
	jupiter.material_override = jm
	jupiter.position = jupiter_position
	jupiter.rotation_degrees = Vector3(0, 90, 12)
	add_child(jupiter)
