class_name ShipAudio
extends RefCounted
## Loads the placeholder sounds in assets/audio/ safely (a missing file reports once and
## yields null, never a crash) and owns the ship audio buses.

const DIR := "res://assets/audio/"
const BUSES: Array[StringName] = [&"Ambience", &"SFX", &"PA"]

static var _loops: Dictionary = {}
static var _missing: Dictionary = {}


static func ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, &"Master")


static func bus_name(bus: StringName) -> StringName:
	ensure_buses()
	return bus


static func one_shot(sound: StringName) -> AudioStream:
	var path := "%s%s.wav" % [DIR, sound]
	if not ResourceLoader.exists(path):
		if not _missing.has(path):
			_missing[path] = true
			GameManager.report_error("ship_audio", "Missing sound: %s" % path, "warning")
		return null
	return load(path) as AudioStream


## Seamlessly looping copy of a sound (the shared imported resource is left untouched).
static func loop(sound: StringName) -> AudioStream:
	if _loops.has(sound):
		return _loops[sound]
	var base := one_shot(sound) as AudioStreamWAV
	if base == null:
		return null
	var s := base.duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	var bytes_per_sample := 2 if s.format == AudioStreamWAV.FORMAT_16_BITS else 1
	if s.stereo:
		bytes_per_sample *= 2
	s.loop_end = s.data.size() / bytes_per_sample
	_loops[sound] = s
	return s
