extends CanvasLayer
## Minimal in-game HUD: crosshair plus the prompt of whatever the player is looking
## at. Driven purely by EventBus focus events, so it works for any local player.

@onready var _prompt: Label = $Root/Prompt


func _ready() -> void:
	_prompt.text = ""
	EventBus.subscribe(Events.INTERACTION_FOCUS_CHANGED, _on_focus_changed)


func _exit_tree() -> void:
	EventBus.unsubscribe(Events.INTERACTION_FOCUS_CHANGED, _on_focus_changed)


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
