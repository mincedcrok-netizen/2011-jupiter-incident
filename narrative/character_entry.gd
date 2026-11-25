class_name CharacterEntry
extends RefCounted
## Narrative profile of one crew member: description, voice (dialogue style),
## relationships, and the progression states that character can be in.
## Current state lives in NarrativeState (as a story flag), not here.

var id: StringName = &""
var canon: String = "proposed"
var display_name: String = ""
var callsign: String = ""
var role: String = ""
var description: String = ""
var personality: Array[String] = []
var voice_style: String = ""
var voice_quirks: Array[String] = []
var relationships: Array[Dictionary] = []  # {with: String, note: String}
var signature_gear: String = ""
var states: Array[String] = []
var initial_state: String = ""
var canonical_status: String = ""  # Lore Bible "Current Narrative Status", if any
var color: Color = Color(0.2, 1.0, 0.6)


static func from_dict(d: Dictionary, errors: Array[String]) -> CharacterEntry:
	var before := errors.size()
	var ctx := "character '%s'" % str(d.get("id", "?"))
	NarrativeValidation.check_common(d, errors, ctx)
	for field in ["display_name", "role", "description"]:
		if not NarrativeValidation.is_nonempty_string(d.get(field)):
			errors.append("%s: missing '%s'" % [ctx, field])
	for field in ["callsign", "signature_gear", "canonical_status"]:
		if d.has(field) and not (d[field] is String):
			errors.append("%s: '%s' must be a string" % [ctx, field])
	var personality := NarrativeValidation.read_string_array(d, "personality", errors, ctx)
	var voice: Variant = d.get("voice")
	var voice_style := ""
	var quirks: Array[String] = []
	if not (voice is Dictionary) or not NarrativeValidation.is_nonempty_string(voice.get("style")):
		errors.append("%s: 'voice' must be an object with a non-empty 'style'" % ctx)
	else:
		voice_style = voice["style"]
		quirks = NarrativeValidation.read_string_array(voice, "quirks", errors, ctx + " voice")
	var rels: Array[Dictionary] = []
	if d.has("relationships"):
		if not (d["relationships"] is Array):
			errors.append("%s: 'relationships' must be an array" % ctx)
		else:
			for r: Variant in d["relationships"]:
				if r is Dictionary and NarrativeValidation.is_nonempty_string(r.get("with")) \
						and NarrativeValidation.is_nonempty_string(r.get("note")):
					rels.append({"with": r["with"], "note": r["note"]})
				else:
					errors.append("%s: each relationship needs 'with' and 'note'" % ctx)
					break
	var states := NarrativeValidation.read_string_array(d, "states", errors, ctx)
	if states.is_empty():
		errors.append("%s: 'states' must list at least one state" % ctx)
	elif states.size() != _unique_count(states):
		errors.append("%s: 'states' contains duplicates" % ctx)
	var initial: Variant = d.get("initial_state")
	if not (initial is String) or not (initial in states):
		errors.append("%s: 'initial_state' must be one of 'states'" % ctx)
	var col := Color(0.2, 1.0, 0.6)
	if d.has("color"):
		if d["color"] is String and Color.html_is_valid(d["color"]):
			col = Color.html(d["color"])
		else:
			errors.append("%s: 'color' must be a #rrggbb string" % ctx)
	if errors.size() > before:
		return null
	var c := CharacterEntry.new()
	c.id = StringName(d["id"])
	c.canon = d["canon"]
	c.display_name = d["display_name"]
	c.callsign = d.get("callsign", "")
	c.role = d["role"]
	c.description = d["description"]
	c.personality = personality
	c.voice_style = voice_style
	c.voice_quirks = quirks
	c.relationships = rels
	c.signature_gear = d.get("signature_gear", "")
	c.states = states
	c.initial_state = initial
	c.canonical_status = d.get("canonical_status", "")
	c.color = col
	return c


static func _unique_count(arr: Array[String]) -> int:
	var seen := {}
	for s in arr:
		seen[s] = true
	return seen.size()
