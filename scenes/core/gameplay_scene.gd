class_name GameplayScene
extends Node3D
## Root script for any scene in which the player is actually playing. It tells the
## GameManager gameplay has started/ended, which drives pause rules and mouse capture.


func _ready() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.enter_gameplay()


func _exit_tree() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.leave_gameplay()
