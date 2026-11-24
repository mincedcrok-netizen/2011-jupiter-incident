class_name DialogueSequence
extends RefCounted
## Data for one conversation: an ordered list of lines, each optionally gated by
## story flags. This is DATA ONLY; the runner/UI and player choices arrive in Phase 2.
##
## Line shape: {speaker: String, text: String, requires: Array[String], excludes: Array[String]}
## `speaker` is a character id string (character data is not defined yet, so it is not cross-checked).

var id: StringName = &""
var canon: String = "test"
var lines: Array[Dictionary] = []


## Returns null (and appends to `errors`) if the dictionary is not a valid sequence.
static func from_dict(d: Dictionary, errors: Array[String]) -> DialogueSequence:
	var before := errors.size()
	var ctx := "dialogue '%s'" % str(d.get("id", "?"))
	NarrativeValidation.check_common(d, errors, ctx)
	var raw_lines: Variant = d.get("lines")
	var parsed: Array[Dictionary] = []
	if not (raw_lines is Array) or (raw_lines as Array).is_empty():
		errors.append("%s: 'lines' must be a non-empty array" % ctx)
	else:
		for i in (raw_lines as Array).size():
			var line: Variant = raw_lines[i]
			var lctx := "%s line %d" % [ctx, i]
			if not (line is Dictionary):
				errors.append("%s: must be an object" % lctx)
				continue
			if not NarrativeValidation.is_nonempty_string(line.get("speaker")):
				errors.append("%s: missing 'speaker'" % lctx)
			if not NarrativeValidation.is_nonempty_string(line.get("text")):
				errors.append("%s: missing 'text'" % lctx)
			var req := NarrativeValidation.read_string_array(line, "requires", errors, lctx)
			var exc := NarrativeValidation.read_string_array(line, "excludes", errors, lctx)
			parsed.append({"speaker": line.get("speaker"), "text": line.get("text"),
				"requires": req, "excludes": exc})
	if errors.size() > before:
		return null
	var seq := DialogueSequence.new()
	seq.id = StringName(d["id"])
	seq.canon = d["canon"]
	seq.lines = parsed
	return seq


## Lines whose flag conditions are currently satisfied, in order.
func available_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line in lines:
		if NarrativeValidation.conditions_met(line["requires"], line["excludes"]):
			out.append(line)
	return out
