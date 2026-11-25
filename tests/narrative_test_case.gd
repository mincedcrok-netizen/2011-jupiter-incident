class_name NarrativeTestCase
extends TestCase
## Base for narrative suites: loads the fixture content set, resets all narrative
## state before each test, and restores the shipped data afterwards.

const FIXTURES := "res://tests/fixtures/data"
const SCRATCH := "user://test_narrative_scratch"


func before_each() -> void:
	_reset_world()
	NarrativeDatabase.data_root = FIXTURES
	NarrativeDatabase.include_test_content = true
	NarrativeDatabase.load_all()
	GameManager.clear_errors()


func after_each() -> void:
	_reset_world()
	_wipe_scratch()
	NarrativeDatabase.data_root = "res://data"
	NarrativeDatabase.include_test_content = OS.is_debug_build()
	NarrativeDatabase.load_all()
	GameManager.clear_errors()


func _reset_world() -> void:
	DialogueManager.abort()
	NarrativeUI.close_all_views()
	GameManager.leave_gameplay()
	GameState.reset()
	NarrativeState.reset()
	EventBus.clear()


## Records every payload of an event type (transient subscription).
func capture(event_type: StringName) -> Array:
	var out: Array = []
	EventBus.subscribe(event_type, func(p: Dictionary) -> void: out.append(p))
	return out


func write_scratch(kind: String, file: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute("%s/%s" % [SCRATCH, kind])
	var f := FileAccess.open("%s/%s/%s" % [SCRATCH, kind, file], FileAccess.WRITE)
	f.store_string(text)
	f.close()


func load_scratch() -> void:
	NarrativeDatabase.data_root = SCRATCH
	NarrativeDatabase.load_all()


func _wipe_scratch() -> void:
	for kind in NarrativeDatabase.KINDS:
		var d := "%s/%s" % [SCRATCH, kind]
		if DirAccess.dir_exists_absolute(d):
			for f in DirAccess.get_files_at(d):
				DirAccess.remove_absolute("%s/%s" % [d, f])
			DirAccess.remove_absolute(d)
	DirAccess.remove_absolute(SCRATCH)
