class_name PlayerInput
extends Node
## Per-player input abstraction. The Player controller reads ONLY this node, never
## the global Input, so a remote player's input can later be fed in over the
## network without touching controller code.

signal interact_pressed

@export var is_local: bool = true

var move: Vector2 = Vector2.ZERO  # x = right, y = back (matches Input.get_vector)
var sprint: bool = false
var _look_accum: Vector2 = Vector2.ZERO


func poll() -> void:
	if not is_local:
		return
	move = Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_FORWARD, InputActions.MOVE_BACK
	)
	sprint = Input.is_action_pressed(InputActions.SPRINT)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_accum += (event as InputEventMouseMotion).relative
	elif event.is_action_pressed(InputActions.INTERACT):
		interact_pressed.emit()


## Returns accumulated mouse motion since the last call.
func consume_look() -> Vector2:
	var l := _look_accum
	_look_accum = Vector2.ZERO
	return l


## Snapshot suitable for sending to the authority (Phase 7).
func get_state() -> Dictionary:
	return {"move": move, "sprint": sprint}


## Applies a snapshot received from a remote peer. Malformed data is ignored.
func apply_remote_state(state: Dictionary) -> void:
	if state.get("move") is Vector2:
		move = (state["move"] as Vector2).limit_length(1.0)
	if state.get("sprint") is bool:
		sprint = state["sprint"]
