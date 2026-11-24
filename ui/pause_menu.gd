extends CanvasLayer
## Minimal pause menu: Resume and Quit. Visibility follows GameManager events.
## Runs while the tree is paused (PROCESS_MODE_ALWAYS).

@onready var _root: Control = $Root
@onready var _resume_button: Button = $Root/Center/Box/ResumeButton
@onready var _quit_button: Button = $Root/Center/Box/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_resume_button.pressed.connect(func() -> void: GameManager.resume())
	_quit_button.pressed.connect(func() -> void: GameManager.quit_game())
	EventBus.subscribe(Events.GAME_PAUSED, _on_paused)
	EventBus.subscribe(Events.GAME_RESUMED, _on_resumed)
	EventBus.subscribe(Events.GAME_STATE_CHANGED, _on_state_changed)


func is_menu_visible() -> bool:
	return _root.visible


func _on_paused(_p: Dictionary) -> void:
	_root.visible = true
	_resume_button.grab_focus()


func _on_resumed(_p: Dictionary) -> void:
	_root.visible = false


func _on_state_changed(p: Dictionary) -> void:
	# Leaving gameplay while paused (e.g. scene change) must not strand the menu.
	if p.get("state") == "IDLE":
		_root.visible = false
