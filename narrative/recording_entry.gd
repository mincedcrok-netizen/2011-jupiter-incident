class_name RecordingEntry
extends RefCounted
## A collectible recording, played back as timed transcript segments.
##   cassette  = audio recording      dashcam = found footage      black_box = flight-recorder transcript
## `audio` is an optional res:// path; if it is missing the transcript still plays.
## Segment: {text, speaker (optional character id), seconds (optional, > 0)}.

const KINDS := ["cassette", "dashcam", "black_box"]
const MIN_SEGMENT_SECONDS := 1.5
const SECONDS_PER_CHAR := 0.045

var id: StringName = &""
var kind: String = ""
var canon: String = "test"
var title: String = ""
var segments: Array[Dictionary] = []
var author: String = ""
var in_world_date: String = ""
var audio: String = ""
var requires: Array[String] = []


static func from_dict(d: Dictionary, errors: Array[String]) -> RecordingEntry:
	var before := errors.size()
	var ctx := "recording '%s'" % str(d.get("id", "?"))
	NarrativeValidation.check_common(d, errors, ctx)
	if not (d.get("kind") is String and d["kind"] in KINDS):
		errors.append("%s: 'kind' must be one of %s" % [ctx, str(KINDS)])
	if not NarrativeValidation.is_nonempty_string(d.get("title")):
		errors.append("%s: missing 'title'" % ctx)
	for optional_field in ["author", "in_world_date", "audio"]:
		if d.has(optional_field) and not (d[optional_field] is String):
			errors.append("%s: '%s' must be a string" % [ctx, optional_field])
	var segs: Array[Dictionary] = []
	var raw: Variant = d.get("segments")
	if not (raw is Array) or (raw as Array).is_empty():
		errors.append("%s: 'segments' must be a non-empty array" % ctx)
	else:
		for i in (raw as Array).size():
			var s: Variant = raw[i]
			var sctx := "%s segment %d" % [ctx, i]
			if not (s is Dictionary) or not NarrativeValidation.is_nonempty_string(s.get("text")):
				errors.append("%s: needs non-empty 'text'" % sctx)
				continue
			if s.has("speaker") and not (s["speaker"] is String):
				errors.append("%s: 'speaker' must be a string" % sctx)
			var secs: Variant = s.get("seconds", 0.0)
			if not (secs is float or secs is int) or secs < 0:
				errors.append("%s: 'seconds' must be a positive number" % sctx)
				continue
			segs.append({"text": s["text"], "speaker": s.get("speaker", ""), "seconds": float(secs)})
	var req := NarrativeValidation.read_string_array(d, "requires", errors, ctx)
	if errors.size() > before:
		return null
	var r := RecordingEntry.new()
	r.id = StringName(d["id"])
	r.kind = d["kind"]
	r.canon = d["canon"]
	r.title = d["title"]
	r.segments = segs
	r.author = d.get("author", "")
	r.in_world_date = d.get("in_world_date", "")
	r.audio = d.get("audio", "")
	r.requires = req
	return r


func segment_seconds(index: int) -> float:
	var s: Dictionary = segments[index]
	if s["seconds"] > 0.0:
		return s["seconds"]
	return maxf(MIN_SEGMENT_SECONDS, (s["text"] as String).length() * SECONDS_PER_CHAR)


func total_seconds() -> float:
	var t := 0.0
	for i in segments.size():
		t += segment_seconds(i)
	return t


func is_unlockable() -> bool:
	return NarrativeValidation.conditions_met(requires, [] as Array[String])
