class_name Player
extends Actor
## First-person player controller: look, walk/sprint, gravity. Reads only from its
## PlayerInput child and registers itself with PlayerRegistry.

@export var walk_speed: float = 3.5
@export var sprint_speed: float = 6.0
@export var acceleration: float = 14.0
@export var pitch_limit_deg: float = 85.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var player_input: PlayerInput = $PlayerInput
@onready var interactor: PlayerInteractor = $Head/Interactor

const LOOK_SCALE := 0.0022


func _ready() -> void:
	if actor_id == &"":
		actor_id = StringName("player_%d" % peer_id)
	var local := is_locally_controlled()
	player_input.is_local = local
	camera.current = local
	if local:
		player_input.interact_pressed.connect(interactor.interact)
	PlayerRegistry.register(self, peer_id, actor_id)


func _physics_process(delta: float) -> void:
	if not is_locally_controlled():
		return  # remote players are driven by replicated state (Phase 7)
	player_input.poll()
	_apply_look()
	_apply_movement(delta)


func _apply_look() -> void:
	var look := player_input.consume_look()
	if look == Vector2.ZERO:
		return
	var sens: float = Settings.get_value("controls", "mouse_sensitivity")
	var y_sign := -1.0 if Settings.get_value("controls", "invert_y") else 1.0
	rotate_y(-look.x * LOOK_SCALE * sens)
	var limit := deg_to_rad(pitch_limit_deg)
	head.rotation.x = clampf(head.rotation.x - look.y * LOOK_SCALE * sens * y_sign, -limit, limit)


func _apply_movement(delta: float) -> void:
	var input_dir := player_input.move
	var wish := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
	wish.y = 0.0
	wish = wish.normalized() * minf(input_dir.length(), 1.0)
	var speed := sprint_speed if player_input.sprint else walk_speed
	var target := wish * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta * speed)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta * speed)
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	else:
		velocity.y = 0.0
	move_and_slide()
