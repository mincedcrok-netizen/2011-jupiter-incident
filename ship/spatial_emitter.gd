class_name SpatialEmitter
extends AudioStreamPlayer3D
## A positional sound source in the level (vent hiss, crackling wires, a failing console).
## Set `sound` to a file name in assets/audio/; `loop` makes it continuous.

@export var sound: StringName = &""
@export var loop_sound: bool = true
@export var emitter_volume_db: float = -6.0
@export var range_m: float = 14.0
@export var falloff_unit: float = 3.0


func _ready() -> void:
	bus = ShipAudio.bus_name(&"Ambience")
	max_distance = range_m
	unit_size = falloff_unit
	volume_db = emitter_volume_db
	stream = ShipAudio.loop(sound) if loop_sound else ShipAudio.one_shot(sound)
	if stream == null:
		return  # already reported by ShipAudio
	play(randf() * 2.0 if loop_sound else 0.0)  # desynchronise identical emitters
