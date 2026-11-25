extends Node
## Runs one DialogueSequence at a time. Logic only (UI listens to EventBus events), so
## it works headless and for any local or remote player.
##
## Flow: start(id) -> DIALOGUE_NODE events -> advance() / choose(i) -> DIALOGUE_ENDED.
## Nodes whose conditions fail are skipped; choices whose conditions fail are hidden.
## A skipped node continues to its `next` (a skipped choice-node ends the conversation).
## Finishing naturally sets flag `dialogue_completed:<id>`; showing a line sets
## `spoke_with:<speaker>`. The player is held in a "dialogue" modal while active.

const MAX_SKIPS := 100  # guards against condition loops that never reach a visible node

var active_id: StringName = &""
var _seq: DialogueSequence = null
var _node_id: String = ""
var _choices: Array[Dictionary] = []
var _dead_end: bool = false  # node had choices but none are currently available
var _current: Dictionary = {}


func _ready() -> void:
	EventBus.subscribe(Events.LOAD_COMPLETED, _on_load_completed, true)


func is_active() -> bool:
	return _seq != null


func current() -> Dictionary:
	return _current.duplicate(true)


func start(id: StringName) -> bool:
	if is_active():
		return false
	var seq := NarrativeDatabase.get_dialogue(id)
	if seq == null:
		GameManager.report_error("dialogue", "Unknown dialogue '%s'" % id, "warning")
		return false
	_seq = seq
	active_id = id
	GameManager.push_modal("dialogue")
	EventBus.publish(Events.DIALOGUE_STARTED, {"id": id})
	_enter(seq.start)
	return true


## Continue from a node that has no (available) choices.
func advance() -> bool:
	if not is_active() or not _choices.is_empty():
		return false
	var node := _seq.get_node_data(_node_id)
	_enter("" if _dead_end else node["next"])
	return true


## Pick one of the currently visible choices (0-based).
func choose(index: int) -> bool:
	if not is_active() or index < 0 or index >= _choices.size():
		return false
	var choice := _choices[index]
	_apply_flags(choice["set_flags"])
	_enter(choice["next"])
	return true


func abort() -> void:
	if is_active():
		_finish(false)


# --- internals ---------------------------------------------------------------

func _enter(node_id: String) -> void:
	var nid := node_id
	var steps := 0
	while true:
		if nid == "":
			_finish(true)
			return
		steps += 1
		if steps > MAX_SKIPS:
			GameManager.report_error("dialogue", "'%s': condition loop never reached a visible node" % active_id)
			_finish(false)
			return
		var n := _seq.get_node_data(nid)
		if n.is_empty():
			GameManager.report_error("dialogue", "'%s': missing node '%s'" % [active_id, nid])
			_finish(false)
			return
		if NarrativeValidation.conditions_met(n["requires"], n["excludes"]):
			_show(nid, n)
			return
		nid = n["next"]


func _show(nid: String, n: Dictionary) -> void:
	_node_id = nid
	_apply_flags(n["set_flags"])
	GameState.set_flag(StringName("spoke_with:" + String(n["speaker"])), true)
	_choices.clear()
	for c: Dictionary in n["choices"]:
		if NarrativeValidation.conditions_met(c["requires"], c["excludes"]):
			_choices.append(c)
	_dead_end = (n["choices"] as Array).size() > 0 and _choices.is_empty()
	var texts: Array[String] = []
	for c in _choices:
		texts.append(c["text"])
	_current = {"id": active_id, "node": nid, "speaker": n["speaker"], "text": n["text"], "choices": texts}
	EventBus.publish(Events.DIALOGUE_NODE, _current.duplicate(true))


func _apply_flags(flags: Dictionary) -> void:
	for k: String in flags:
		GameState.set_flag(StringName(k), flags[k])


func _finish(completed: bool) -> void:
	var id := active_id
	if completed:
		GameState.set_flag(StringName("dialogue_completed:" + String(id)), true)
	# Clear first, so handlers of DIALOGUE_ENDED may immediately start another conversation.
	_seq = null
	active_id = &""
	_node_id = ""
	_choices.clear()
	_current = {}
	_dead_end = false
	GameManager.pop_modal("dialogue")
	EventBus.publish(Events.DIALOGUE_ENDED, {"id": id, "completed": completed})


func _on_load_completed(_p: Dictionary) -> void:
	abort()  # the loaded world has no memory of a half-finished conversation
