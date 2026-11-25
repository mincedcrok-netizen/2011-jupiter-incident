class_name DocumentEntry
extends RefCounted
## A readable document: crew report, personal note, technical log, incident report
## or classified record. `in_world_date` is free text so no timeline is invented.

const KINDS := ["crew_report", "personal_note", "technical_log", "incident_report", "classified"]

var id: StringName = &""
var kind: String = ""
var canon: String = "test"
var title: String = ""
var body: String = ""
var author: String = ""
var in_world_date: String = ""
var classification: String = ""
var requires: Array[String] = []


static func from_dict(d: Dictionary, errors: Array[String]) -> DocumentEntry:
	var before := errors.size()
	var ctx := "document '%s'" % str(d.get("id", "?"))
	NarrativeValidation.check_common(d, errors, ctx)
	if not (d.get("kind") is String and d["kind"] in KINDS):
		errors.append("%s: 'kind' must be one of %s" % [ctx, str(KINDS)])
	for field in ["title", "body"]:
		if not NarrativeValidation.is_nonempty_string(d.get(field)):
			errors.append("%s: missing '%s'" % [ctx, field])
	for field in ["author", "in_world_date", "classification"]:
		if d.has(field) and not (d[field] is String):
			errors.append("%s: '%s' must be a string" % [ctx, field])
	var req := NarrativeValidation.read_string_array(d, "requires", errors, ctx)
	if errors.size() > before:
		return null
	var doc := DocumentEntry.new()
	doc.id = StringName(d["id"])
	doc.kind = d["kind"]
	doc.canon = d["canon"]
	doc.title = d["title"]
	doc.body = d["body"]
	doc.author = d.get("author", "")
	doc.in_world_date = d.get("in_world_date", "")
	doc.classification = d.get("classification", "")
	doc.requires = req
	return doc


func is_findable() -> bool:
	return NarrativeValidation.conditions_met(requires, [] as Array[String])
