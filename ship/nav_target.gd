class_name NavTarget
extends Marker3D
## A named point the objective waypoint can guide the player to. Objectives reference it
## by `target_id` (see NarrativeState.set_objective). Registered in group "nav_target".

@export var target_id: StringName = &""
@export var display_name: String = ""


func _ready() -> void:
	add_to_group("nav_target")
	if target_id == &"":
		GameManager.report_error("nav_target", "%s has no target_id" % name)


static func find(tree: SceneTree, id: String) -> NavTarget:
	for n in tree.get_nodes_in_group("nav_target"):
		if n is NavTarget and String((n as NavTarget).target_id) == id:
			return n
	return null
