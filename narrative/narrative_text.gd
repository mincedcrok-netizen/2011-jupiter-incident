class_name NarrativeText
extends RefCounted
## Resolves character tokens in any player-facing text so names live in ONE place
## (data/characters/*.json): {name:id}, {callsign:id}, {role:id}. Unknown ids are left as
## written. Used by every narrative view and by in-world signs.

static var _re: RegEx = null


static func resolve(text: String) -> String:
	if not text.contains("{"):
		return text
	if _re == null:
		_re = RegEx.new()
		_re.compile("\\{(name|callsign|role):([a-z0-9_]+)\\}")
	var out := text
	for m in _re.search_all(text):
		var ch := NarrativeDatabase.get_character(StringName(m.get_string(2)))
		if ch == null:
			continue
		var value := ch.display_name
		match m.get_string(1):
			"callsign": value = ch.callsign if ch.callsign != "" else ch.display_name
			"role": value = ch.role
		out = out.replace(m.get_string(), value)
	return out
