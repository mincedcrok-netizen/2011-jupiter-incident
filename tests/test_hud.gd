extends TestCase

var hud: Node


func before_each() -> void:
	hud = (load("res://ui/hud.tscn") as PackedScene).instantiate()
	tree.root.add_child(hud)
	await tree.process_frame


func after_each() -> void:
	hud.queue_free()
	await tree.process_frame
	Settings.reset_bindings()


func test_prompt_follows_focus_events() -> void:
	eq(hud.prompt_text(), "", "empty at start")
	EventBus.publish(Events.INTERACTION_FOCUS_CHANGED, {"interaction_id": &"x", "prompt": "Use terminal"})
	eq(hud.prompt_text(), "[E] Use terminal", "prompt shown with the interact key")
	EventBus.publish(Events.INTERACTION_FOCUS_CHANGED, {"interaction_id": &"", "prompt": ""})
	eq(hud.prompt_text(), "", "cleared when focus lost")


func test_prompt_shows_the_rebound_key() -> void:
	Settings.set_binding(InputActions.INTERACT, KEY_F)
	EventBus.publish(Events.INTERACTION_FOCUS_CHANGED, {"interaction_id": &"x", "prompt": "Open"})
	eq(hud.prompt_text(), "[F] Open", "uses current binding")


func test_malformed_event_payload_is_safe() -> void:
	EventBus.publish(Events.INTERACTION_FOCUS_CHANGED, {})
	eq(hud.prompt_text(), "", "missing prompt key treated as no focus")
	EventBus.publish(Events.INTERACTION_FOCUS_CHANGED, {"prompt": 42})
