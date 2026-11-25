extends CanvasLayer
## Minimal in-game HUD: crosshair plus the prompt of whatever the player is looking
## at. Driven purely by EventBus focus events, so it works for any local player.

@onready var _root: Control = $Root
@onready var _prompt: Label = $Root/Prompt


func _ready() -> void:
	_prompt.text = ""
	EventBus.subscribe(Events.INTERACTION_FOCUS_CHANGED, _on_focus_changed, true)


func _exit_tree() -> void:
	EventBus.unsubscribe(Events.INTERACTION_FOCUS_CHANGED, _on_focus_changed)


func _process(_delta: float) -> void:
	# The crosshair/prompt belong to the 3D view; hide them behind dialogue and readers.
	_root.visible = not GameManager.is_modal_open()


func is_hud_visible() -> bool:
	return _root.visible


func prompt_text() -> String:
	return _prompt.text


func _on_focus_changed(payload: Dictionary) -> void:
	var raw: Variant = payload.get("prompt", "")
	var text: String = raw if raw is String else ""
	if text.is_empty():
		_prompt.text = ""
		return
	var key_name := OS.get_keycode_string(InputActions.current_keycode(InputActions.INTERACT))
	_prompt.text = "[%s] %s" % [key_name, text]
