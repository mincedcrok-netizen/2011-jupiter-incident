class_name FlickerLight
extends OmniLight3D
## Ship lighting with character: steady, flicker (failing fixture), pulse (emergency beacon),
## strobe, dying. Lights farther than `active_distance` from the camera switch off, which
## keeps the number of live lights small however big the deck gets.

@export_enum("steady", "flicker", "pulse", "strobe", "dying") var mode: String = "steady"
@export var base_energy: float = 1.0
@export var phase: float = 0.0
@export var active_distance: float = 30.0

var _t: float = 0.0
var _check: float = 0.0


## Pure function (testable): light energy for a mode at time t. Always within [0, base*1.05].
static func energy_at(light_mode: String, base: float, t: float, phase_offset: float = 0.0) -> float:
	var x := t + phase_offset
	match light_mode:
		"flicker":
			var n := sin(x * 41.0) * sin(x * 13.7) + sin(x * 7.1)
			return base * (0.15 if n > 1.15 else (0.55 if n > 0.8 else 1.0))
		"pulse":
			return base * (0.25 + 0.75 * (0.5 + 0.5 * sin(x * 3.2)))
		"strobe":
			return base if fmod(x, 1.1) < 0.12 else base * 0.08
		"dying":
			var d := 0.5 + 0.5 * sin(x * 2.1)
			return base * (d * d if sin(x * 23.0) > -0.6 else 0.05)
	return base


func _ready() -> void:
	light_energy = energy_at(mode, base_energy, 0.0, phase)
	set_process(mode != "steady")


func _process(delta: float) -> void:
	_t += delta
	_check -= delta
	if _check <= 0.0:
		_check = 0.3
		var cam := get_viewport().get_camera_3d()
		visible = cam == null or cam.global_position.distance_to(global_position) <= active_distance
	if visible:
		light_energy = energy_at(mode, base_energy, _t, phase)
