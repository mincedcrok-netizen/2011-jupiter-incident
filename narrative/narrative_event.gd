class_name NarrativeEvent
extends RefCounted
## A data-defined story event: WHEN an EventBus event of `trigger.type` fires with a
## payload matching `trigger.match`, AND flag conditions hold, run `actions` in order.
## Environmental storytelling (area triggers), character encounters (interactions) and
## conditional story beats are all expressed this way. EventDirector executes them.
##
## trigger.type is any EventBus event name (see core/events.gd), e.g. "interacted",
## "area_entered", "flag_changed", "dialogue_ended", "scene_change_completed".

## action type -> required string parameters
const ACTION_TYPES := {
	"set_flag": ["flag"],
	"start_dialogue": ["id"],
	"unlock_recording": ["id"],
	"unlock_document": ["id"],
	"open_document": ["id"],
	"open_recording": ["id"],
	"set_character_state": ["id", "state"],
	"set_objective": ["id", "text"],
	"complete_objective": ["id"],
	"notify": ["text"],
}

var id: StringName = &""
var canon: String = "test"
var trigger_type: StringName = &""
var match_fields: Dictionary = {}
var requires: Array[String] = []
var excludes: Array[String] = []
var once: bool = true
var actions: Array[Dictionary] = []


static func from_dict(d: Dictionary, errors: Array[String]) -> NarrativeEvent:
	var before := errors.size()
	var ctx := "event '%s'" % str(d.get("id", "?"))
	NarrativeValidation.check_common(d, errors, ctx)
	var trig: Variant = d.get("trigger")
	var match_map: Dictionary = {}
	if not (trig is Dictionary) or not NarrativeValidation.is_nonempty_string(trig.get("type")):
		errors.append("%s: 'trigger' must be an object with a 'type'" % ctx)
	else:
		match_map = NarrativeValidation.read_flag_map(trig, "match", errors, ctx + " trigger")
	if d.has("once") and not (d["once"] is bool):
		errors.append("%s: 'once' must be true or false" % ctx)
	var acts: Array[Dictionary] = []
	var raw: Variant = d.get("actions")
	if not (raw is Array) or (raw as Array).is_empty():
		errors.append("%s: 'actions' must be a non-empty array" % ctx)
	else:
		for i in (raw as Array).size():
			var a := _parse_action(raw[i], errors, "%s action %d" % [ctx, i])
			if not a.is_empty():
				acts.append(a)
	var req := NarrativeValidation.read_string_array(d, "requires", errors, ctx)
	var exc := NarrativeValidation.read_string_array(d, "excludes", errors, ctx)
	if errors.size() > before:
		return null
	var ev := NarrativeEvent.new()
	ev.id = StringName(d["id"])
	ev.canon = d["canon"]
	ev.trigger_type = StringName(d["trigger"]["type"])
	ev.match_fields = match_map
	ev.requires = req
	ev.excludes = exc
	ev.once = d.get("once", true)
	ev.actions = acts
	return ev


## True if every `match` field equals the payload field (compared as text, so
## StringName vs String never matters).
func matches(payload: Dictionary) -> bool:
	for k: String in match_fields:
		if not payload.has(k) or str(payload[k]) != str(match_fields[k]):
			return false
	return true


static func _parse_action(raw: Variant, errors: Array[String], actx: String) -> Dictionary:
	if not (raw is Dictionary) or not (raw.get("type") is String) or not ACTION_TYPES.has(raw["type"]):
		errors.append("%s: 'type' must be one of %s" % [actx, str(ACTION_TYPES.keys())])
		return {}
	var out: Dictionary = {"type": raw["type"]}
	for param: String in ACTION_TYPES[raw["type"]]:
		if not NarrativeValidation.is_nonempty_string(raw.get(param)):
			errors.append("%s (%s): missing '%s'" % [actx, raw["type"], param])
			return {}
		out[param] = raw[param]
	if raw["type"] == "set_objective" and raw.has("target"):
		if not NarrativeValidation.is_nonempty_string(raw["target"]):
			errors.append("%s: set_objective 'target' must be a non-empty string" % actx)
			return {}
		out["target"] = raw["target"]
	if raw["type"] == "set_flag":
		var v: Variant = raw.get("value", true)
		if not NarrativeValidation.is_flag_value(v):
			errors.append("%s: set_flag 'value' must be bool/number/string" % actx)
			return {}
		if v is float and is_equal_approx(v, round(v)) and absf(v) < 9.0e15:
			v = int(v)
		out["value"] = v
	return out
