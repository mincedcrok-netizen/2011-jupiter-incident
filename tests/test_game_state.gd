extends TestCase

var _events: Array = []


func _cap(p: Dictionary) -> void:
	_events.append(p)


func before_each() -> void:
	GameState.reset()
	EventBus.clear()
	_events.clear()


func test_set_get_has_clear() -> void:
	ok(GameState.set_flag(&"met_crew"), "set returns true")
	eq(GameState.get_flag(&"met_crew"), true, "default value true")
	ok(GameState.has_flag(&"met_crew"), "has flag")
	GameState.clear_flag(&"met_crew")
	ok(not GameState.has_flag(&"met_crew"), "cleared")
	eq(GameState.get_flag(&"missing", 7), 7, "default returned for missing")


func test_change_event_fires_only_on_change() -> void:
	EventBus.subscribe(Events.FLAG_CHANGED, _cap)
	GameState.set_flag(&"a", 1)
	GameState.set_flag(&"a", 1)
	GameState.set_flag(&"a", 2)
	eq(_events.size(), 2, "two real changes")
	eq(_events[1]["old"], 1, "old value reported")


func test_rejects_bad_input() -> void:
	ok(not GameState.set_flag(&"", true), "empty key rejected")
	ok(not GameState.set_flag(&"k", [1, 2]), "array value rejected")
	ok(not GameState.set_flag(&"k", Vector3.ZERO), "vector value rejected")
	ok(not GameState.has_flag(&"k"), "nothing stored")


func test_serialize_roundtrip_through_json_restores_ints() -> void:
	GameState.set_flag(&"count", 3)
	GameState.set_flag(&"name", "bridge")
	GameState.set_flag(&"ratio", 0.5)
	var text := JSON.stringify(GameState.serialize())
	var back: Dictionary = JSON.parse_string(text)
	GameState.reset()
	ok(GameState.deserialize(back), "deserialize ok")
	eq(GameState.get_flag(&"count"), 3, "int restored as int")
	eq(GameState.get_flag(&"name"), "bridge", "string restored")
	eq(GameState.get_flag(&"ratio"), 0.5, "float restored")


func test_deserialize_rejects_malformed() -> void:
	GameState.set_flag(&"keep", true)
	ok(not GameState.deserialize({}), "missing flags key")
	ok(not GameState.deserialize({"flags": 5}), "flags wrong type")
	ok(not GameState.deserialize({"flags": {"k": [1]}}), "bad value type")
	ok(not GameState.deserialize({"flags": {"": true}}), "empty key")
	eq(GameState.get_flag(&"keep"), true, "existing state untouched on failure")
