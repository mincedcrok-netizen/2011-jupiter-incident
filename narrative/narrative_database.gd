extends Node
## Loads narrative data (dialogue sequences, recordings) from JSON files under
## `data_root`, validating every entry. Bad entries are skipped and reported, never
## crash the game. Unlocked recordings are stored as story flags, so they are saved,
## loaded and (later) replicated through GameState with no extra machinery.
##
## Ownership: data is read-only on every peer; unlocking is AUTHORITY.
## NOTE for Phase 8: exported builds must include *.json (export filter "data/*").

const RECORDING_FLAG_PREFIX := "recording_unlocked:"

var data_root: String = "res://data"  # overridable (tests use fixtures)
var load_errors: Array[String] = []

var _dialogue: Dictionary = {}    # StringName -> DialogueSequence
var _recordings: Dictionary = {}  # StringName -> RecordingEntry


func _ready() -> void:
	load_all()


func load_all() -> void:
	_dialogue.clear()
	_recordings.clear()
	load_errors.clear()
	_load_kind("dialogue")
	_load_kind("recordings")


func has_dialogue(id: StringName) -> bool:
	return _dialogue.has(id)


func get_dialogue(id: StringName) -> DialogueSequence:
	return _dialogue.get(id)


func has_recording(id: StringName) -> bool:
	return _recordings.has(id)


func get_recording(id: StringName) -> RecordingEntry:
	return _recordings.get(id)


func dialogue_count() -> int:
	return _dialogue.size()


func recording_count() -> int:
	return _recordings.size()


func is_unlocked(id: StringName) -> bool:
	return GameState.is_flag_true(StringName(RECORDING_FLAG_PREFIX + String(id)))


## Unlocks a recording. Refuses unknown ids, unmet requirements, and non-authority peers.
func unlock_recording(id: StringName) -> bool:
	var rec := get_recording(id)
	if rec == null:
		_note("unlock_recording: unknown recording '%s'" % id)
		return false
	if not rec.is_unlockable():
		return false
	return GameState.set_flag(StringName(RECORDING_FLAG_PREFIX + String(id)), true)


## Unlocked recordings, sorted by id for stable ordering.
func unlocked_recordings() -> Array[RecordingEntry]:
	# Sort as plain Strings: StringName ordering is not alphabetical.
	var ids: Array[String] = []
	for id: StringName in _recordings:
		ids.append(String(id))
	ids.sort()
	var out: Array[RecordingEntry] = []
	for id_text in ids:
		if is_unlocked(StringName(id_text)):
			out.append(_recordings[StringName(id_text)])
	return out


# --- loading -----------------------------------------------------------------

func _load_kind(subdir: String) -> void:
	var dir_path := "%s/%s" % [data_root, subdir]
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
			_register(subdir, entries[i], "%s#%d" % [file_name, i])


func _read_entries(path: String) -> Array:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		_note("%s: not valid JSON (line %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
		return []
	if not (json.data is Array):
		_note("%s: top level must be an array of entries" % path)
		return []
	return json.data


func _register(subdir: String, entry: Variant, where: String) -> void:
	if not (entry is Dictionary):
		_note("%s: entry must be an object" % where)
		return
	var errs: Array[String] = []
	var obj: Object = null
	if subdir == "dialogue":
		obj = DialogueSequence.from_dict(entry, errs)
	else:
		obj = RecordingEntry.from_dict(entry, errs)
	if obj == null:
		_note("%s: %s" % [where, "; ".join(errs)])
		return
	var store := _dialogue if subdir == "dialogue" else _recordings
	if store.has(obj.id):
		_note("%s: duplicate id '%s' ignored" % [where, obj.id])
		return
	store[obj.id] = obj


func _note(message: String) -> void:
	load_errors.append(message)
	GameManager.report_error("narrative_data", message, "warning")
