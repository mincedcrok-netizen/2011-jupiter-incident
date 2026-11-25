extends Node
## Loads all narrative DATA from JSON under `data_root`: characters, dialogue,
## recordings, documents and events. Every entry is validated; bad entries are skipped
## and reported, never crash the game. After loading, cross-references (speakers,
## ids used by events, ...) are checked and problems reported as warnings.
## Read-only at runtime; progress lives in NarrativeState.
##
## Entries with canon "test" are demo/fixture content and are ignored unless
## `include_test_content` is true (default: debug builds only), so they cannot ship.
## NOTE for Phase 8: exported builds must include *.json under data/.

const KINDS := ["characters", "dialogue", "recordings", "documents", "events"]
const SPECIAL_SPEAKERS := ["narrator", "system"]

var data_root: String = "res://data"  # overridable (tests use fixtures)
var include_test_content: bool = OS.is_debug_build()
var load_errors: Array[String] = []
var skipped_test_entries: int = 0

var _stores: Dictionary = {}  # kind -> {StringName id -> entry}
var _events_by_trigger: Dictionary = {}  # StringName -> Array[NarrativeEvent]


func _ready() -> void:
	load_all()


func load_all() -> void:
	load_errors.clear()
	skipped_test_entries = 0
	_events_by_trigger.clear()
	for kind: String in KINDS:
		_stores[kind] = {}
	for kind: String in KINDS:  # characters first so later kinds can be cross-checked
		_load_kind(kind)
	_index_events()
	_check_references()


# --- lookups -----------------------------------------------------------------

func get_character(id: StringName) -> CharacterEntry:
	return _stores["characters"].get(id)


func get_dialogue(id: StringName) -> DialogueSequence:
	return _stores["dialogue"].get(id)


func get_recording(id: StringName) -> RecordingEntry:
	return _stores["recordings"].get(id)


func get_document(id: StringName) -> DocumentEntry:
	return _stores["documents"].get(id)


func get_event(id: StringName) -> NarrativeEvent:
	return _stores["events"].get(id)


func has_character(id: StringName) -> bool:
	return _stores["characters"].has(id)


func has_dialogue(id: StringName) -> bool:
	return _stores["dialogue"].has(id)


func has_recording(id: StringName) -> bool:
	return _stores["recordings"].has(id)


func has_document(id: StringName) -> bool:
	return _stores["documents"].has(id)


func count(kind: String) -> int:
	return (_stores.get(kind, {}) as Dictionary).size()


func dialogue_count() -> int:
	return count("dialogue")


func recording_count() -> int:
	return count("recordings")


## All entries of a kind, sorted by id (plain-string sort; StringName order is unstable).
func all_of(kind: String) -> Array:
	var ids: Array[String] = []
	for id: StringName in (_stores.get(kind, {}) as Dictionary):
		ids.append(String(id))
	ids.sort()
	var out: Array = []
	for id_text in ids:
		out.append(_stores[kind][StringName(id_text)])
	return out


func events_for_trigger(trigger_type: StringName) -> Array:
	return _events_by_trigger.get(trigger_type, [])


# --- loading -----------------------------------------------------------------

func _load_kind(kind: String) -> void:
	var dir_path := "%s/%s" % [data_root, kind]
	if not DirAccess.dir_exists_absolute(dir_path):
		return  # absent folder == no content (checked first: get_files_at logs an engine error)
	var files := Array(DirAccess.get_files_at(dir_path))
	files.sort()
	for file_name: String in files:
		if not file_name.ends_with(".json"):
			continue
		var path := "%s/%s" % [dir_path, file_name]
		var entries := _read_entries(path)
		for i in entries.size():
			_register(kind, entries[i], "%s/%s#%d" % [kind, file_name, i])


func _read_entries(path: String) -> Array:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		_note("%s: not valid JSON (line %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
		return []
	if not (json.data is Array):
		_note("%s: top level must be an array of entries" % path)
		return []
	return json.data


func _register(kind: String, entry: Variant, where: String) -> void:
	if not (entry is Dictionary):
		_note("%s: entry must be an object" % where)
		return
	var errs: Array[String] = []
	var obj: Object = null
	match kind:
		"characters": obj = CharacterEntry.from_dict(entry, errs)
		"dialogue": obj = DialogueSequence.from_dict(entry, errs)
		"recordings": obj = RecordingEntry.from_dict(entry, errs)
		"documents": obj = DocumentEntry.from_dict(entry, errs)
		"events": obj = NarrativeEvent.from_dict(entry, errs)
	if obj == null:
		_note("%s: %s" % [where, "; ".join(errs)])
		return
	if obj.canon == "test" and not include_test_content:
		skipped_test_entries += 1
		return
	var store: Dictionary = _stores[kind]
	if store.has(obj.id):
		_note("%s: duplicate id '%s' ignored" % [where, obj.id])
		return
	store[obj.id] = obj


func _index_events() -> void:
	for ev: NarrativeEvent in all_of("events"):
		var list: Array = _events_by_trigger.get(ev.trigger_type, [])
		list.append(ev)
		_events_by_trigger[ev.trigger_type] = list


## Cross-reference checks. Problems are warnings: the entry stays loaded and the
## runtime handles a missing target safely when it is actually used.
func _check_references() -> void:
	for seq: DialogueSequence in all_of("dialogue"):
		for node_id: String in seq.nodes:
			var speaker: String = seq.nodes[node_id]["speaker"]
			if not has_character(StringName(speaker)) and not (speaker in SPECIAL_SPEAKERS):
				_note("dialogue '%s' node '%s': unknown speaker '%s'" % [seq.id, node_id, speaker])
	for rec: RecordingEntry in all_of("recordings"):
		for seg: Dictionary in rec.segments:
			if seg["speaker"] != "" and not has_character(StringName(seg["speaker"])):
				_note("recording '%s': unknown speaker '%s'" % [rec.id, seg["speaker"]])
	for ch: CharacterEntry in all_of("characters"):
		for rel: Dictionary in ch.relationships:
			if not has_character(StringName(rel["with"])):
				_note("character '%s': relationship with unknown character '%s'" % [ch.id, rel["with"]])
	for ev: NarrativeEvent in all_of("events"):
		for a: Dictionary in ev.actions:
			_check_action(ev, a)


func _check_action(ev: NarrativeEvent, a: Dictionary) -> void:
	var target := StringName(a.get("id", ""))
	var missing := false
	match a["type"]:
		"start_dialogue": missing = not has_dialogue(target)
		"unlock_recording", "open_recording": missing = not has_recording(target)
		"unlock_document", "open_document": missing = not has_document(target)
		"set_character_state":
			var ch := get_character(target)
			missing = ch == null or not (a["state"] in ch.states)
	if missing:
		_note("event '%s': action '%s' refers to unknown target '%s'" % [ev.id, a["type"], a.get("id")])


func _note(message: String) -> void:
	load_errors.append(message)
	GameManager.report_error("narrative_data", message, "warning")
