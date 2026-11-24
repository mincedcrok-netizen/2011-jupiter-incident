extends Node
## Validated scene transitions. Loading is synchronous for now (scenes are small);
## the interface is stable so threaded loading + a loading screen can slot in later.
## Ownership: LOCAL for now. In co-op the host will drive transitions (Phase 7).

var current_scene_path: String = ""
var _changing: bool = false


func change_scene(path: String) -> Error:
	if _changing:
		return ERR_BUSY
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("SceneManager: scene not found: '%s'" % path)
		EventBus.publish(Events.SCENE_CHANGE_FAILED, {"path": path, "error": ERR_FILE_NOT_FOUND})
		return ERR_FILE_NOT_FOUND
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("SceneManager: not a PackedScene: '%s'" % path)
		EventBus.publish(Events.SCENE_CHANGE_FAILED, {"path": path, "error": ERR_FILE_CORRUPT})
		return ERR_FILE_CORRUPT
	_changing = true
	EventBus.publish(Events.SCENE_CHANGE_STARTED, {"path": path})
	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		_changing = false
		EventBus.publish(Events.SCENE_CHANGE_FAILED, {"path": path, "error": err})
		return err
	# The swap is applied at end of frame; finish bookkeeping afterwards.
	get_tree().process_frame.connect(_finish.bind(path), CONNECT_ONE_SHOT)
	return OK


func is_changing() -> bool:
	return _changing


func _finish(path: String) -> void:
	current_scene_path = path
	_changing = false
	EventBus.publish(Events.SCENE_CHANGE_COMPLETED, {"path": path})
