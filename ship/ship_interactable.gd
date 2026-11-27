class_name ShipInteractable
extends Interactable
## An Interactable with ship-kit visuals (terminal, footlocker, black box, ...). All behaviour
## comes from the Phase 2 narrative events keyed on `interaction_id`; this only adds a body.
## "terminal_damaged" glitches its screen (the O. Algo anomaly corrupting consoles).

@export var kind: String = "terminal"

var _screen: MeshInstance3D = null
var _screen_mat: StandardMaterial3D = null
var _t: float = 0.0


func _ready() -> void:
	super._ready()
	var info := ShipProps.build_interactable(kind, self)
	if info.is_empty():
		GameManager.report_error("ship_interactable", "%s: unknown kind '%s'" % [name, kind])
		return
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = info["size"]
	cs.shape = bs
	cs.position = info["offset"]
	add_child(cs)
	_screen = get_node_or_null("Screen") as MeshInstance3D
	if _screen != null:
		# Own copy: the shared cached material must not flicker on every console.
		_screen_mat = (_screen.material_override as StandardMaterial3D).duplicate()
		_screen.material_override = _screen_mat
	set_process(_screen_mat != null and (kind == "terminal_damaged" or kind == "black_box"))


func _process(delta: float) -> void:
	_t += delta
	if kind == "terminal_damaged":
		var glitch := absf(sin(_t * 37.0) * sin(_t * 11.3))
		_screen_mat.emission_energy_multiplier = 0.0 if fmod(_t, 2.3) < 0.12 else 0.3 + 1.2 * glitch
	else:
		_screen_mat.emission_energy_multiplier = 0.2 + 1.4 * (0.5 + 0.5 * sin(_t * 3.0))  # blinking recorder LED
