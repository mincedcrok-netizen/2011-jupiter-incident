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
const PAUSE := &"pause"

const DEFAULTS := {
	MOVE_FORWARD: KEY_W,
	MOVE_BACK: KEY_S,
	MOVE_LEFT: KEY_A,
	MOVE_RIGHT: KEY_D,
	SPRINT: KEY_SHIFT,
	INTERACT: KEY_E,
	PAUSE: KEY_ESCAPE,
}


static func ensure_defaults() -> void:
	for action: StringName in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = DEFAULTS[action]
		InputMap.action_add_event(action, ev)


## A physical keycode is acceptable only if it round-trips through its own name
## (rejects arbitrary integers that merely produce some string).
static func is_valid_keycode(keycode: int) -> bool:
	if keycode <= 0:
		return false
	var key_name := OS.get_keycode_string(keycode)
	return not key_name.is_empty() and OS.find_keycode_from_string(key_name) == keycode


## First keyboard binding of an action, or 0 if none.
static func current_keycode(action: StringName) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return (ev as InputEventKey).physical_keycode
	return 0


## The other action already using this keycode, or &"" if free.
static func conflicting_action(action: StringName, keycode: int) -> StringName:
	for other: StringName in DEFAULTS:
		if other != action and current_keycode(other) == keycode:
			return other
	return &""


## Replaces the action's keyboard binding. Refuses unknown actions, invalid
## keycodes and keycodes already used by another action.
static func apply_binding(action: StringName, keycode: int) -> bool:
	if not DEFAULTS.has(action) or not is_valid_keycode(keycode):
		return false
	if conflicting_action(action, keycode) != &"":
		return false
	ensure_defaults()
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
	return true


## Restores every action to its default key (bypasses the conflict check, which
## could otherwise reject a restore while another action still holds the key).
static func reset_all_bindings() -> void:
	ensure_defaults()
	for action: StringName in DEFAULTS:
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = DEFAULTS[action]
		InputMap.action_add_event(action, ev)
