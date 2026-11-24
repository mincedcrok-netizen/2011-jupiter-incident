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
