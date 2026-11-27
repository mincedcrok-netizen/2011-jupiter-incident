class_name ShipProp
extends Node3D
## Places a procedural set piece (see ShipProps.build) in the level. Solid kinds get a
## collision body on the WORLD layer.

const SOLID_KINDS := ["bunk", "locker_row", "crate_stack", "shelving", "console_bank", "command_chair", "debris_pile", "table", "blast_backing"]

@export var kind: String = ""
@export var text: String = ""
@export var length: float = 2.0
@export var color: Color = Color(0.2, 0.85, 1.0)
@export var seed_value: int = 1


func _ready() -> void:
	var body: StaticBody3D = null
	if kind in SOLID_KINDS:
		body = StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = PhysicsLayers.WORLD
		body.collision_mask = 0
		add_child(body)
	if not ShipProps.build(kind, self, body, text, length, color, seed_value):
		GameManager.report_error("ship_prop", "%s: unknown prop kind '%s'" % [name, kind])
