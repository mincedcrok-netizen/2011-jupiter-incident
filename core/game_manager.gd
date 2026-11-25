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
var _modals: Dictionary = {}  # String id -> true; open full-attention UI (dialogue, reader...)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # must keep running while the tree is paused
	EventBus.subscribe(Events.SCENE_CHANGE_FAILED, _on_scene_change_failed, true)
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
	_modals.clear()
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


## A modal is any UI that takes the player's full attention (dialogue, document
## reader, ...). While one is open the player cannot move/look/interact and the
## mouse is released. Idempotent per id.
func push_modal(id: String) -> void:
	_modals[id] = true
	_apply_mouse_mode()


func pop_modal(id: String) -> void:
	_modals.erase(id)
	_apply_mouse_mode()


func is_modal_open() -> bool:
	return not _modals.is_empty()


## True whenever the local player must not receive gameplay input.
func input_blocked() -> bool:
	return state != State.PLAYING or not _modals.is_empty()


## Mouse is captured only while actively playing with no modal UI open.
func wants_mouse_captured() -> bool:
	return state == State.PLAYING and _modals.is_empty()


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
