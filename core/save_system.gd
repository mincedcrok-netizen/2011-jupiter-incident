extends Node
## Versioned JSON save files in user://saves. Systems that own persistent state
## register a "provider" (an object with serialize()->Dictionary and
## deserialize(Dictionary)->bool, optional reset()). Saves are written atomically
## (temp file + rename), keep a .bak of the previous save, fall back to it if the
## main file is corrupt, and roll back live state if loading fails midway.
##
## Ownership: AUTHORITY. In co-op only the host writes campaign saves.

const SAVE_VERSION := 1
const DEFAULT_SAVE_DIR := "user://saves"
const MAX_SLOT := 99

var save_dir: String = DEFAULT_SAVE_DIR  # overridable (tests use a scratch dir)
var _providers: Dictionary = {}  # String -> Object


func register_provider(key: String, provider: Object) -> void:
	if key.is_empty() or provider == null:
		push_warning("SaveSystem.register_provider: invalid arguments")
		return
	if not (provider.has_method("serialize") and provider.has_method("deserialize")):
		push_error("SaveSystem: provider '%s' lacks serialize()/deserialize()" % key)
		return
	_providers[key] = provider


func unregister_provider(key: String) -> void:
	_providers.erase(key)


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [save_dir, slot]


func slot_exists(slot: int) -> bool:
	return _valid_slot(slot) and FileAccess.file_exists(slot_path(slot))


func list_slots() -> Array[int]:
	var out: Array[int] = []
	for s in range(0, MAX_SLOT + 1):
		if FileAccess.file_exists(slot_path(s)):
			out.append(s)
	return out


func save_slot(slot: int, meta: Dictionary = {}) -> Error:
	if not _valid_slot(slot):
		return ERR_INVALID_PARAMETER
	if not Net.is_authority():
		return ERR_UNAUTHORIZED
	var doc := {
		"version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"meta": meta,
		"data": _collect(),
	}
	var text := JSON.stringify(doc, "\t")
	var mk := DirAccess.make_dir_recursive_absolute(save_dir)
	if mk != OK:
		return mk
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.flush()
	f.close()
	if FileAccess.file_exists(path):
		var bak_err := DirAccess.rename_absolute(path, path + ".bak")
		if bak_err != OK:
			return bak_err
	var rn := DirAccess.rename_absolute(tmp, path)
	if rn != OK:
		return rn
	EventBus.publish(Events.SAVE_COMPLETED, {"slot": slot})
	return OK


func load_slot(slot: int) -> Error:
	if not _valid_slot(slot):
		return ERR_INVALID_PARAMETER
	var path := slot_path(slot)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return ERR_FILE_NOT_FOUND
	var doc := _read_doc(path)
	if doc.is_empty():
		doc = _read_doc(path + ".bak")  # primary corrupt/missing: try backup
	if doc.is_empty():
		return ERR_FILE_CORRUPT
	var version: int = int(doc["version"])
	if version > SAVE_VERSION:
		return ERR_UNAVAILABLE  # written by a newer game build
	doc = _migrate(doc, version)
	var snapshot := _collect()
	var data: Dictionary = doc["data"]
	for key: String in _providers:
		var provider: Object = _providers[key]
		var ok := true
		if data.has(key):
			if data[key] is Dictionary:
				ok = provider.deserialize(data[key])
			else:
				ok = false
		elif provider.has_method("reset"):
			provider.reset()
		if not ok:
			_apply(snapshot)  # roll back everything
			return ERR_INVALID_DATA
	EventBus.publish(Events.LOAD_COMPLETED, {"slot": slot})
	return OK


func delete_slot(slot: int) -> Error:
	if not _valid_slot(slot):
		return ERR_INVALID_PARAMETER
	var path := slot_path(slot)
	var result := OK
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			var e := DirAccess.remove_absolute(p)
			if e != OK:
				result = e
	return result


# --- internals ---------------------------------------------------------------

func _valid_slot(slot: int) -> bool:
	return slot >= 0 and slot <= MAX_SLOT


func _collect() -> Dictionary:
	var out: Dictionary = {}
	for key: String in _providers:
		out[key] = (_providers[key] as Object).serialize()
	return out


func _apply(snapshot: Dictionary) -> void:
	for key: String in snapshot:
		if _providers.has(key):
			(_providers[key] as Object).deserialize(snapshot[key])


## Returns {} when the file is missing, unparseable, or structurally invalid.
func _read_doc(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	var d: Dictionary = json.data
	if not (d.get("version") is float or d.get("version") is int):
		return {}
	if not (d.get("data") is Dictionary):
		return {}
	return d


## Future save-format upgrades go here, one step per version.
func _migrate(doc: Dictionary, _from_version: int) -> Dictionary:
	return doc
