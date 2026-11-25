class_name DialogueSequence
extends RefCounted
## A conversation as a graph of nodes. DATA ONLY; DialogueManager runs it.
##
## Node:   {speaker, text, requires[], excludes[], set_flags{}, next: node_id | "", choices[]}
## Choice: {text, next: node_id | "", requires[], excludes[], set_flags{}}
## A node with `choices` waits for the player; otherwise it continues to `next`;
## with neither it ends the conversation. `requires`/`excludes` are story-flag
## conditions: a node whose conditions fail is skipped, a choice is hidden.
## `set_flags` run when the node is shown / the choice is picked.

const MAX_CHOICES := 6

var id: StringName = &""
var canon: String = "test"
var start: String = ""
var nodes: Dictionary = {}  # String node_id -> Dictionary


static func from_dict(d: Dictionary, errors: Array[String]) -> DialogueSequence:
	var before := errors.size()
	var ctx := "dialogue '%s'" % str(d.get("id", "?"))
	NarrativeValidation.check_common(d, errors, ctx)
	var raw_nodes: Variant = d.get("nodes")
	var parsed: Dictionary = {}
	if not (raw_nodes is Dictionary) or (raw_nodes as Dictionary).is_empty():
		errors.append("%s: 'nodes' must be a non-empty object" % ctx)
	else:
		for node_id: Variant in raw_nodes:
			var n := _parse_node(str(node_id), raw_nodes[node_id], errors, ctx)
			if not n.is_empty():
				parsed[str(node_id)] = n
	var start_id: Variant = d.get("start")
	if not NarrativeValidation.is_nonempty_string(start_id):
		errors.append("%s: missing 'start'" % ctx)
	elif errors.size() == before and not parsed.has(start_id):
		errors.append("%s: 'start' points at unknown node '%s'" % [ctx, start_id])
	if errors.size() == before:
		for node_id: String in parsed:
			var n: Dictionary = parsed[node_id]
			for target: String in _targets(n):
				if not parsed.has(target):
					errors.append("%s: node '%s' points at unknown node '%s'" % [ctx, node_id, target])
	if errors.size() > before:
		return null
	var seq := DialogueSequence.new()
	seq.id = StringName(d["id"])
	seq.canon = d["canon"]
	seq.start = start_id
	seq.nodes = parsed
	return seq


func get_node_data(node_id: String) -> Dictionary:
	return nodes.get(node_id, {})


static func _targets(n: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if n["next"] != "":
		out.append(n["next"])
	for c: Dictionary in n["choices"]:
		if c["next"] != "":
			out.append(c["next"])
	return out


static func _parse_node(node_id: String, raw: Variant, errors: Array[String], ctx: String) -> Dictionary:
	var nctx := "%s node '%s'" % [ctx, node_id]
	var before := errors.size()
	if not (raw is Dictionary):
		errors.append("%s: must be an object" % nctx)
		return {}
	if not NarrativeValidation.is_nonempty_string(raw.get("speaker")):
		errors.append("%s: missing 'speaker'" % nctx)
	if not NarrativeValidation.is_nonempty_string(raw.get("text")):
		errors.append("%s: missing 'text'" % nctx)
	var next_id: Variant = raw.get("next", "")
	if not (next_id is String):
		errors.append("%s: 'next' must be a node id string" % nctx)
		next_id = ""
	var choices: Array[Dictionary] = []
	if raw.has("choices"):
		var raw_choices: Variant = raw["choices"]
		if not (raw_choices is Array) or (raw_choices as Array).is_empty() or (raw_choices as Array).size() > MAX_CHOICES:
			errors.append("%s: 'choices' must be an array of 1-%d choices" % [nctx, MAX_CHOICES])
		else:
			if next_id != "":
				errors.append("%s: a node cannot have both 'choices' and 'next'" % nctx)
			for i in (raw_choices as Array).size():
				var c := _parse_choice(raw_choices[i], errors, "%s choice %d" % [nctx, i])
				if not c.is_empty():
					choices.append(c)
	var req := NarrativeValidation.read_string_array(raw, "requires", errors, nctx)
	var exc := NarrativeValidation.read_string_array(raw, "excludes", errors, nctx)
	var flags := NarrativeValidation.read_flag_map(raw, "set_flags", errors, nctx)
	if errors.size() > before:
		return {}
	return {"speaker": raw["speaker"], "text": raw["text"], "next": next_id,
		"choices": choices, "requires": req, "excludes": exc, "set_flags": flags}


static func _parse_choice(raw: Variant, errors: Array[String], cctx: String) -> Dictionary:
	var before := errors.size()
	if not (raw is Dictionary):
		errors.append("%s: must be an object" % cctx)
		return {}
	if not NarrativeValidation.is_nonempty_string(raw.get("text")):
		errors.append("%s: missing 'text'" % cctx)
	var next_id: Variant = raw.get("next", "")
	if not (next_id is String):
		errors.append("%s: 'next' must be a node id string" % cctx)
		next_id = ""
	var req := NarrativeValidation.read_string_array(raw, "requires", errors, cctx)
	var exc := NarrativeValidation.read_string_array(raw, "excludes", errors, cctx)
	var flags := NarrativeValidation.read_flag_map(raw, "set_flags", errors, cctx)
	if errors.size() > before:
		return {}
	return {"text": raw["text"], "next": next_id, "requires": req, "excludes": exc, "set_flags": flags}
