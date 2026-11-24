extends Node
## Top-level game flow: gameplay/pause state, mouse capture policy, and a central
## error log. Scenes that are playable declare themselves via GameplayScene.
##
## Ownership: LOCAL. In single-player, pausing freezes the tree. In co-op (Phase 7)
## pause will not freeze the host's simulation; that change belongs here.

enum State { IDLE, PLAYING, PAUSED }

const PAUSE_MENU_SCENE := "res://ui/pause_menu.tscn"
const MAX_ERRORS := 50

var state: State = State.IDLE
var _errors: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # must keep running while the tree is paused
	EventBus.subscribe(Events.SCENE_CHANGE_FAILED, _on_scene_change_failed)
	var menu_scene := load(PAUSE_MENU_SCENE) as PackedScene
	if menu_scene == null:
		report_error("game_manager", "Pause menu scene failed to load: %s" % PAUSE_MENU_SCENE)
	else:
		add_child(menu_scene.instantiate())


# --- state -------------------------------------------------------------------

func enter_gameplay() -> void:
	if state == State.PAUSED:
		get_tree().paused = false
	_set_state(State.PLAYING)


func leave_gameplay() -> void:
	get_tree().paused = false
	_set_state(State.IDLE)


func pause() -> bool:
	if state != State.PLAYING:
		return false
	get_tree().paused = true
	_set_state(State.PAUSED)
	EventBus.publish(Events.GAME_PAUSED)
	return true


func resume() -> bool:
	if state != State.PAUSED:
		return false
	get_tree().paused = false
	_set_state(State.PLAYING)
	EventBus.publish(Events.GAME_RESUMED)
	return true


func toggle_pause() -> void:
	if state == State.PLAYING:
		pause()
	elif state == State.PAUSED:
		resume()


func is_paused() -> bool:
	return state == State.PAUSED


## Mouse is captured only while actively playing; every other state needs a cursor.
func wants_mouse_captured() -> bool:
	return state == State.PLAYING


func quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


func _set_state(new_state: State) -> void:
	var previous := state
	state = new_state
	_apply_mouse_mode()
	if previous != new_state:
		EventBus.publish(Events.GAME_STATE_CHANGED, {
			"state": State.keys()[new_state], "previous": State.keys()[previous]})


func _apply_mouse_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = \
		Input.MOUSE_MODE_CAPTURED if wants_mouse_captured() else Input.MOUSE_MODE_VISIBLE


# --- input / window ----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.PAUSE):
		if state == State.PLAYING or state == State.PAUSED:
			toggle_pause()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Alt-tabbing away should never leave the player in a live, uncontrolled game.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause()


# --- error log ---------------------------------------------------------------

## Central place to record non-fatal problems. severity: "warning" or "error".
func report_error(context: String, message: String, severity: String = "error") -> void:
	var entry := {"context": context, "message": message, "severity": severity}
	_errors.append(entry)
	if _errors.size() > MAX_ERRORS:
		_errors.pop_front()
	if severity == "warning":
		push_warning("[%s] %s" % [context, message])
	else:
		push_error("[%s] %s" % [context, message])
	EventBus.publish(Events.ERROR_REPORTED, entry)


func recent_errors() -> Array[Dictionary]:
	return _errors.duplicate()


func clear_errors() -> void:
	_errors.clear()


func _on_scene_change_failed(payload: Dictionary) -> void:
	# SceneManager already push_error()s; record without logging a second time.
	_errors.append({"context": "scene_manager",
		"message": "Failed to load '%s' (error %s)" % [payload.get("path"), payload.get("error")],
		"severity": "error"})
