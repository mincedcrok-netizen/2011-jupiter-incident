class_name InputActions
extends RefCounted
## Registers default keyboard/mouse bindings at runtime so bindings live in code
## (and later in user settings for rebinding) rather than being scattered in
## project.godot. Existing actions are left alone so user rebinds survive.

const MOVE_FORWARD := &"move_forward"
const MOVE_BACK := &"move_back"
const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const SPRINT := &"sprint"
const INTERACT := &"interact"
const RELEASE_MOUSE := &"release_mouse"

const DEFAULTS := {
	MOVE_FORWARD: KEY_W,
	MOVE_BACK: KEY_S,
	MOVE_LEFT: KEY_A,
	MOVE_RIGHT: KEY_D,
	SPRINT: KEY_SHIFT,
	INTERACT: KEY_E,
	RELEASE_MOUSE: KEY_ESCAPE,
}


static func ensure_defaults() -> void:
	for action: StringName in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = DEFAULTS[action]
		InputMap.action_add_event(action, ev)
