class_name ShipAnnouncer
extends Node
## The ship's public-address system: a chime and a caption (shown as a toast) every so often.
## No voice acting yet; the caption stands in. The lines are generic system messages.

@export var messages: PackedStringArray = PackedStringArray()
@export var first_delay: float = 28.0
@export var min_interval: float = 45.0
@export var max_interval: float = 90.0

var announcement_count: int = 0
var _player: AudioStreamPlayer
var _timer: Timer
var _rng := RandomNumberGenerator.new()
var _next: int = 0


func _ready() -> void:
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.bus = ShipAudio.bus_name(&"PA")
	_player.volume_db = -4.0
	_player.stream = ShipAudio.one_shot(&"pa_chime")
	add_child(_player)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	_timer.start(first_delay)


## Plays the chime and publishes the caption. Returns false if there is nothing to say.
func announce(text: String = "") -> bool:
	var line := text
	if line == "" and not messages.is_empty():
		line = messages[_next % messages.size()]
		_next += 1
	if line == "":
		return false
	if _player.stream != null:
		_player.play()
	EventBus.publish(Events.NOTIFICATION, {"text": "[PA] %s" % line})
	announcement_count += 1
	return true


func _on_timer() -> void:
	announce()
	_timer.start(_rng.randf_range(min_interval, max_interval))
