extends Node
## Executes data-defined NarrativeEvents. Listens to EVERY EventBus event, finds the
## events registered for that trigger type, and runs those whose payload match and
## flag conditions pass. Authority-only: in co-op the host decides story events.
## Failed actions are reported and skipped; they never stop the remaining actions.

const MAX_DEPTH := 8  # events triggering events triggering events ...


var _depth: int = 0


func _ready() -> void:
	EventBus.event_published.connect(_on_event)


func _on_event(event_type: StringName, payload: Dictionary) -> void:
	if not Net.is_authority():
		return
	var candidates := NarrativeDatabase.events_for_trigger(event_type)
	if candidates.is_empty():
		return
	if _depth >= MAX_DEPTH:
		GameManager.report_error("event_director", "Event chain too deep at '%s'; stopped" % event_type)
		return
	for ev: NarrativeEvent in candidates.duplicate():
		if ev.once and NarrativeState.is_event_done(ev.id):
			continue
		if not ev.matches(payload):
			continue
		if not NarrativeValidation.conditions_met(ev.requires, ev.excludes):
			continue
		_run(ev)


func _run(ev: NarrativeEvent) -> void:
	_depth += 1
	if ev.once:
		NarrativeState.mark_event_done(ev.id)
	EventBus.publish(Events.NARRATIVE_EVENT_FIRED, {"id": ev.id})
	for action: Dictionary in ev.actions:
		_execute(ev, action)
	_depth -= 1


func _execute(ev: NarrativeEvent, a: Dictionary) -> void:
	var ok := true
	match a["type"]:
		"set_flag":
			ok = GameState.set_flag(StringName(a["flag"]), a["value"])
		"start_dialogue":
			ok = DialogueManager.start(StringName(a["id"]))
		"unlock_recording":
			ok = NarrativeState.unlock_recording(StringName(a["id"]))
		"unlock_document":
			ok = NarrativeState.find_document(StringName(a["id"]))
		"open_document":
			ok = NarrativeState.find_document(StringName(a["id"]))
			if ok:
				EventBus.publish(Events.UI_OPEN_REQUESTED, {"kind": "document", "id": StringName(a["id"])})
		"open_recording":
			ok = NarrativeState.unlock_recording(StringName(a["id"]))
			if ok:
				EventBus.publish(Events.UI_OPEN_REQUESTED, {"kind": "recording", "id": StringName(a["id"])})
		"set_character_state":
			ok = NarrativeState.set_character_state(StringName(a["id"]), a["state"])
		"set_objective":
			ok = NarrativeState.set_objective(a["id"], a["text"])
		"complete_objective":
			ok = NarrativeState.complete_objective(a["id"])
		"notify":
			EventBus.publish(Events.NOTIFICATION, {"text": a["text"]})
	if not ok:
		GameManager.report_error("event_director", "event '%s': action '%s' did not apply" % [ev.id, a["type"]], "warning")
