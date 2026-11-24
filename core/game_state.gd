extends Node
## Story-flag store and serializable game state. This is the single source of
## truth for narrative progress (flags now; missions/dialogue use it in Phase 2).
##
## Ownership: AUTHORITY (host). Non-authority peers must not mutate flags
## directly; they will send requests in Phase 7 and receive replicated values.
##
## Values are limited to JSON-safe scalars: bool, int, float, String.

const SAVE_KEY := "game_state"

var _flags: Dictionary = {}  # String -> bool|int|float|String


func _ready() -> void:
	SaveSystem.register_provider(SAVE_KEY, self)


func set_flag(key: StringName, value: Variant = true) -> bool:
	if String(key).is_empty():
		push_warning("GameState.set_flag: empty key rejected")
		return false
	if not _is_valid_value(value):
		push_warning("GameState.set_flag('%s'): unsupported value type %d" % [key, typeof(value)])
		return false
	if not Net.is_authority():
		push_warning("GameState.set_flag('%s'): only the authority may set flags" % key)
		return false
	var k := String(key)
	var had: bool = _flags.has(k)
	var old: Variant = _flags.get(k)
	# Compare types first: == between e.g. String and int is a runtime error in GDScript.
	if had and typeof(old) == typeof(value) and old == value:
		return true  # unchanged; no event
	_flags[k] = value
	EventBus.publish(Events.FLAG_CHANGED, {"key": k, "value": value, "old": old})
	return true


func get_flag(key: StringName, default: Variant = false) -> Variant:
	return _flags.get(String(key), default)


## Strict boolean read: true only if the flag exists AND is the boolean true. Safe
## against flags of other types (e.g. from a hand-edited save); never errors.
func is_flag_true(key: StringName) -> bool:
	var v: Variant = _flags.get(String(key), false)
	return v is bool and v


func has_flag(key: StringName) -> bool:
	return _flags.has(String(key))


func clear_flag(key: StringName) -> void:
	var k := String(key)
	if not _flags.has(k) or not Net.is_authority():
		return
	var old: Variant = _flags[k]
	_flags.erase(k)
	EventBus.publish(Events.FLAG_CHANGED, {"key": k, "value": null, "old": old})


func all_flags() -> Dictionary:
	return _flags.duplicate()


# --- SaveSystem provider interface -------------------------------------------

func reset() -> void:
	_flags.clear()


func serialize() -> Dictionary:
	return {"flags": _flags.duplicate()}


func deserialize(data: Dictionary) -> bool:
	if not data.has("flags") or not (data["flags"] is Dictionary):
		return false
	var incoming: Dictionary = data["flags"]
	var clean: Dictionary = {}
	for k: Variant in incoming:
		if not (k is String) or (k as String).is_empty():
			return false
		var v: Variant = incoming[k]
		# JSON has one number type; restore whole floats to int.
		if v is float and is_equal_approx(v, round(v)) and absf(v) < 9.0e15:
			v = int(v)
		if not _is_valid_value(v):
			return false
		clean[k] = v
	_flags = clean
	return true


func _is_valid_value(value: Variant) -> bool:
	return value is bool or value is int or value is float or value is String
