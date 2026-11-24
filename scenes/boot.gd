extends Node
## Entry scene: settings are already loaded by the Settings autoload, so just hand
## off to the first scene. (Main menu / continue-game flow arrives in later phases.)

const FIRST_SCENE := "res://scenes/test/foundation_room.tscn"


func _ready() -> void:
	SceneManager.change_scene.call_deferred(FIRST_SCENE)
