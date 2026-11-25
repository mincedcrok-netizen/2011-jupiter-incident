class_name NarrativeValidation
extends RefCounted
## Shared validation helpers for narrative data files.

## Every narrative entry must declare how it relates to the Lore Bible:
##   established = taken from the Lore Bible, proposed = new and awaiting approval,
##   test = fixture for tests only (never shipped content).
const CANON_VALUES := ["established", "proposed", "test"]


static func is_nonempty_string(v: Variant) -> bool:
	return v is String and not (v as String).strip_edges().is_empty()


## Reads an optional array-of-strings field. Appends to `errors` if malformed.
static func read_string_array(d: Dictionary, field: String, errors: Array[String], ctx: String) -> Array[String]:
	var out: Array[String] = []
	if not d.has(field):
		return out
	if not (d[field] is Array):
		errors.append("%s: '%s' must be an array of strings" % [ctx, field])
		return out
	for item: Variant in d[field]:
		if not is_nonempty_string(item):
			errors.append("%s: '%s' contains a non-string or empty entry" % [ctx, field])
			return []
		out.append(item)
	return out


static func is_flag_value(v: Variant) -> bool:
	return v is bool or v is int or v is float or v is String


## Optional {flag: value} map (used for set_flags). JSON numbers arrive as floats, so
## whole floats are normalised to int to match what GameState stores after a load.
static func read_flag_map(d: Dictionary, field: String, errors: Array[String], ctx: String) -> Dictionary:
	var out: Dictionary = {}
	if not d.has(field):
		return out
	if not (d[field] is Dictionary):
		errors.append("%s: '%s' must be an object of flag: value" % [ctx, field])
		return out
	for k: Variant in d[field]:
		var v: Variant = d[field][k]
		if not is_nonempty_string(k) or not is_flag_value(v):
			errors.append("%s: '%s' has an invalid key or value (only bool/number/string allowed)" % [ctx, field])
			return {}
		if v is float and is_equal_approx(v, round(v)) and absf(v) < 9.0e15:
			v = int(v)
		out[k] = v
	return out


static func check_common(d: Dictionary, errors: Array[String], ctx: String) -> void:
	if not is_nonempty_string(d.get("id")):
		errors.append("%s: missing or empty 'id'" % ctx)
	if not (d.get("canon") is String and d["canon"] in CANON_VALUES):
		errors.append("%s: 'canon' must be one of %s" % [ctx, str(CANON_VALUES)])


## All `requires` flags are set and no `excludes` flag is set (truthy test).
static func conditions_met(requires: Array[String], excludes: Array[String]) -> bool:
	for key in requires:
		if not _flag_truthy(key):
			return false
	for key in excludes:
		if _flag_truthy(key):
			return false
	return true


static func _flag_truthy(key: String) -> bool:
	var v: Variant = GameState.get_flag(StringName(key), false)
	return bool(v)
