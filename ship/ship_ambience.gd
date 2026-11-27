class_name ShipAmbience
extends Node
## The deck's audio bed: a constant machinery hum plus sporadic distant clanks and thumps
## from random positions around the listener, so the ship never feels perfectly still.

const DISTANT := [&"distant_clank_1", &"distant_clank_2", &"distant_thump"]

@export var hum_db: float = -17.0
@export var min_interval: float = 9.0
@export var max_interval: float = 24.0

var distant_noise_count: int = 0
var _hum: AudioStreamPlayer
var _timer: Timer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_hum = AudioStreamPlayer.new()
	_hum.bus = ShipAudio.bus_name(&"Ambience")
	_hum.volume_db = hum_db
	_hum.stream = ShipAudio.loop(&"ship_hum")
	add_child(_hum)
	if _hum.stream != null:
		_hum.play()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	_timer.start(_rng.randf_range(min_interval, max_interval))


func is_hum_playing() -> bool:
	return _hum != null and _hum.playing


## Plays one distant noise now (also used by the timer).
func trigger_distant_noise() -> bool:
	var cam := get_viewport().get_camera_3d()
	var origin := cam.global_position if cam != null else Vector3.ZERO
	var s := ShipAudio.one_shot(DISTANT[_rng.randi() % DISTANT.size()])
	if s == null:
		return false
	var p := AudioStreamPlayer3D.new()
	p.bus = ShipAudio.bus_name(&"Ambience")
	p.stream = s
	p.max_distance = 70.0
	p.unit_size = 10.0
	p.volume_db = -8.0
	p.finished.connect(p.queue_free)
	add_child(p)  # own child: never depends on a current scene existing
	var angle := _rng.randf() * TAU
	p.global_position = origin + Vector3(cos(angle), _rng.randf_range(-0.3, 0.6), sin(angle)) * _rng.randf_range(18.0, 40.0)
	p.play()
	distant_noise_count += 1
	return true


func _on_timer() -> void:
	trigger_distant_noise()
	_timer.start(_rng.randf_range(min_interval, max_interval))
