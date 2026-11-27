extends Node
## Entry scene: settings are already loaded by the Settings autoload, so just hand
## off to the first scene. If that fails, show a readable error instead of a blank
## window. (Main menu / continue-game flow arrives in later phases.)

@export var first_scene: String = "res://scenes/ship/deck_a.tscn"

var error_label: Label = null


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	var err := SceneManager.change_scene(first_scene)
	if err != OK:
		_show_fatal("Could not load '%s' (error %d: %s)" % [first_scene, err, error_string(err)])


func _show_fatal(message: String) -> void:
	GameManager.report_error("boot", message)
	var layer := CanvasLayer.new()
	error_label = Label.new()
	error_label.text = "The game could not start.\n\n%s" % message
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	error_label.offset_left = 24
	error_label.offset_top = 24
	layer.add_child(error_label)
	add_child(layer)
