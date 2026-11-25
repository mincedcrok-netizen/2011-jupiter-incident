extends Node
## Narrative PROGRESS: which recordings/documents the player has found, played or
## read, each character's current state, the objective list, and which one-shot
## events have fired. Almost everything is a GameState story flag (so conditions can
## test it and it is saved/replicated through one store); the objective list and
## completed-event set, which are not flat flags, are saved by this node's own provider.
##
## Ownership: AUTHORITY. Every mutator refuses on non-authority peers.
##
## Flag keys: recording_unlocked:<id> recording_played:<id> document_found:<id>
##            document_read:<id> character_state:<id> objective_added:<id>
##            objective_completed:<id>

const SAVE_KEY := "narrative"

var _objectives: Array[Dictionary] = []  # {id: String, text: String, completed: bool}
var _done_events: Dictionary = {}        # String event id -> true


func _ready() -> void:
	SaveSystem.register_provider(SAVE_KEY, self)


# --- recordings --------------------------------------------------------------

func unlock_recording(id: StringName) -> bool:
	if not Net.is_authority():
		return false
	var rec := NarrativeDatabase.get_recording(id)
	if rec == null:
		GameManager.report_error("narrative", "unlock_recording: unknown recording '%s'" % id, "warning")
		return false
	if not rec.is_unlockable():
		return false
	if is_recording_unlocked(id):
		return true
	if not GameState.set_flag(_key("recording_unlocked:", id), true):
		return false
	EventBus.publish(Events.RECORDING_UNLOCKED, {"id": id})
	return true


func is_recording_unlocked(id: StringName) -> bool:
	return GameState.is_flag_true(_key("recording_unlocked:", id))


func mark_recording_played(id: StringName) -> bool:
	if not Net.is_authority() or not is_recording_unlocked(id):
		return false
	if was_recording_played(id):
		return true
	GameState.set_flag(_key("recording_played:", id), true)
	EventBus.publish(Events.RECORDING_PLAYED, {"id": id})
	return true


func was_recording_played(id: StringName) -> bool:
	return GameState.is_flag_true(_key("recording_played:", id))


func unlocked_recordings() -> Array[RecordingEntry]:
	var out: Array[RecordingEntry] = []
	for rec: RecordingEntry in NarrativeDatabase.all_of("recordings"):
		if is_recording_unlocked(rec.id):
			out.append(rec)
	return out


# --- documents ---------------------------------------------------------------

func find_document(id: StringName) -> bool:
	if not Net.is_authority():
		return false
	var doc := NarrativeDatabase.get_document(id)
	if doc == null:
		GameManager.report_error("narrative", "find_document: unknown document '%s'" % id, "warning")
		return false
	if not doc.is_findable():
		return false
	if is_document_found(id):
		return true
	if not GameState.set_flag(_key("document_found:", id), true):
		return false
	EventBus.publish(Events.DOCUMENT_FOUND, {"id": id})
	return true


func is_document_found(id: StringName) -> bool:
	return GameState.is_flag_true(_key("document_found:", id))


func mark_document_read(id: StringName) -> bool:
	if not Net.is_authority() or not is_document_found(id):
		return false
	if is_document_read(id):
		return true
	GameState.set_flag(_key("document_read:", id), true)
	EventBus.publish(Events.DOCUMENT_READ, {"id": id})
	return true


func is_document_read(id: StringName) -> bool:
	return GameState.is_flag_true(_key("document_read:", id))


func found_documents() -> Array[DocumentEntry]:
	var out: Array[DocumentEntry] = []
	for doc: DocumentEntry in NarrativeDatabase.all_of("documents"):
		if is_document_found(doc.id):
			out.append(doc)
	return out


# --- characters --------------------------------------------------------------

## Current progression state; the character's initial state until changed.
## Returns "" for an unknown character.
func get_character_state(id: StringName) -> String:
	var ch := NarrativeDatabase.get_character(id)
	if ch == null:
		return ""
	var v: Variant = GameState.get_flag(_key("character_state:", id), ch.initial_state)
	return v if (v is String and v in ch.states) else ch.initial_state


func set_character_state(id: StringName, state: String) -> bool:
	if not Net.is_authority():
		return false
	var ch := NarrativeDatabase.get_character(id)
	if ch == null or not (state in ch.states):
		GameManager.report_error("narrative", "set_character_state: invalid character/state '%s'/'%s'" % [id, state], "warning")
		return false
	var old := get_character_state(id)
	if old == state:
		return true
	if not GameState.set_flag(_key("character_state:", id), state):
		return false
	EventBus.publish(Events.CHARACTER_STATE_CHANGED, {"id": id, "state": state, "old": old})
	return true


# --- objectives --------------------------------------------------------------

func set_objective(id: String, text: String) -> bool:
	if not Net.is_authority() or id.is_empty() or text.strip_edges().is_empty():
		return false
	for o in _objectives:
		if o["id"] == id:
			o["text"] = text  # reword an existing objective; completion is kept
			return true
	_objectives.append({"id": id, "text": text, "completed": false})
	GameState.set_flag(StringName("objective_added:" + id), true)
	EventBus.publish(Events.OBJECTIVE_CHANGED, {"id": id, "text": text, "kind": "added"})
	return true


func complete_objective(id: String) -> bool:
	if not Net.is_authority():
		return false
	for o in _objectives:
		if o["id"] == id:
			if not o["completed"]:
				o["completed"] = true
				GameState.set_flag(StringName("objective_completed:" + id), true)
				EventBus.publish(Events.OBJECTIVE_CHANGED, {"id": id, "text": o["text"], "kind": "completed"})
			return true
	GameManager.report_error("narrative", "complete_objective: unknown objective '%s'" % id, "warning")
	return false


func objectives() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in _objectives:
		out.append(o.duplicate())
	return out


# --- one-shot events ---------------------------------------------------------

func mark_event_done(id: StringName) -> void:
	_done_events[String(id)] = true


func is_event_done(id: StringName) -> bool:
	return _done_events.has(String(id))


# --- SaveSystem provider -----------------------------------------------------

func reset() -> void:
	_objectives.clear()
	_done_events.clear()


func serialize() -> Dictionary:
	return {"objectives": objectives(), "completed_events": _done_events.keys()}


func deserialize(data: Dictionary) -> bool:
	if not (data.get("objectives") is Array) or not (data.get("completed_events") is Array):
		return false
	var objs: Array[Dictionary] = []
	for o: Variant in data["objectives"]:
		if not (o is Dictionary) or not (o.get("id") is String) or not (o.get("text") is String) \
				or not (o.get("completed") is bool) or (o["id"] as String).is_empty():
			return false
		objs.append({"id": o["id"], "text": o["text"], "completed": o["completed"]})
	var done: Dictionary = {}
	for e: Variant in data["completed_events"]:
		if not (e is String) or (e as String).is_empty():
			return false
		done[e] = true
	_objectives = objs
	_done_events = done
	return true


static func _key(prefix: String, id: StringName) -> StringName:
	return StringName(prefix + String(id))
