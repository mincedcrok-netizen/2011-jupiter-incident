class_name RecordingEntry
extends RefCounted
## Data for a collectible narrative document: cassette, dashcam footage, black-box
## transcript, mission report, or personal crew record. DATA ONLY: the in-game log UI
## and playback arrive in Phase 2. `in_world_date` is free text so no timeline is invented.

const KINDS := ["cassette", "dashcam", "black_box", "report", "personal_record"]

var id: StringName = &""
var kind: String = ""
var canon: String = "test"
var title: String = ""
var body: String = ""
var author: String = ""
var in_world_date: String = ""
var requires: Array[String] = []


static func from_dict(d: Dictionary, errors: Array[String]) -> RecordingEntry:
	var before := errors.size()
	var ctx := "recording '%s'" % str(d.get("id", "?"))
	NarrativeValidation.check_common(d, errors, ctx)
	if not (d.get("kind") is String and d["kind"] in KINDS):
		errors.append("%s: 'kind' must be one of %s" % [ctx, str(KINDS)])
	if not NarrativeValidation.is_nonempty_string(d.get("title")):
		errors.append("%s: missing 'title'" % ctx)
	if not NarrativeValidation.is_nonempty_string(d.get("body")):
		errors.append("%s: missing 'body'" % ctx)
	for optional_field in ["author", "in_world_date"]:
		if d.has(optional_field) and not (d[optional_field] is String):
			errors.append("%s: '%s' must be a string" % [ctx, optional_field])
	var req := NarrativeValidation.read_string_array(d, "requires", errors, ctx)
	if errors.size() > before:
		return null
	var r := RecordingEntry.new()
	r.id = StringName(d["id"])
	r.kind = d["kind"]
	r.canon = d["canon"]
	r.title = d["title"]
	r.body = d["body"]
	r.author = d.get("author", "")
	r.in_world_date = d.get("in_world_date", "")
	r.requires = req
	return r


func is_unlockable() -> bool:
	return NarrativeValidation.conditions_met(requires, [] as Array[String])
