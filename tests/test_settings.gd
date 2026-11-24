extends TestCase

const PATH := "user://test_settings.cfg"


func before_each() -> void:
	Settings.config_path = PATH
	DirAccess.remove_absolute(PATH)
	Settings.load_settings()


func after_each() -> void:
	DirAccess.remove_absolute(PATH)
	Settings.config_path = Settings.DEFAULT_PATH


func test_defaults_when_no_file() -> void:
	eq(Settings.get_value("graphics", "window_mode"), "windowed", "default window mode")
	eq(Settings.get_value("audio", "master"), 1.0, "default master volume")


func test_set_clamps_and_validates() -> void:
	Settings.set_value("audio", "master", 5.0)
	eq(Settings.get_value("audio", "master"), 1.0, "volume clamped high")
	Settings.set_value("audio", "master", -2.0)
	eq(Settings.get_value("audio", "master"), 0.0, "volume clamped low")
	Settings.set_value("graphics", "window_mode", "nonsense")
	eq(Settings.get_value("graphics", "window_mode"), "windowed", "bad mode -> default")
	Settings.set_value("graphics", "resolution", Vector2i(1, 1))
	eq(Settings.get_value("graphics", "resolution"), Vector2i(640, 360), "resolution clamped")
	Settings.set_value("controls", "mouse_sensitivity", "fast")
	eq(Settings.get_value("controls", "mouse_sensitivity"), 1.0, "wrong type -> default")


func test_unknown_setting_rejected() -> void:
	ok(not Settings.set_value("nope", "nada", 1), "unknown key rejected")


func test_save_and_reload_roundtrip() -> void:
	Settings.set_value("audio", "music", 0.25)
	Settings.set_value("graphics", "window_mode", "fullscreen")
	Settings.set_value("graphics", "resolution", Vector2i(1920, 1080))
	eq(Settings.save_settings(), OK, "saved")
	Settings.load_settings()
	eq(Settings.get_value("audio", "music"), 0.25, "float persisted")
	eq(Settings.get_value("graphics", "window_mode"), "fullscreen", "string persisted")
	eq(Settings.get_value("graphics", "resolution"), Vector2i(1920, 1080), "vector persisted")


func test_hand_edited_garbage_is_sanitized() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[audio]\nmaster=99.0\nmusic=\"loud\"\n[graphics]\nwindow_mode=\"zzz\"\n")
	f.close()
	Settings.load_settings()
	eq(Settings.get_value("audio", "master"), 1.0, "out-of-range clamped")
	eq(Settings.get_value("audio", "music"), 0.8, "wrong type -> default")
	eq(Settings.get_value("graphics", "window_mode"), "windowed", "bad enum -> default")


func test_unparseable_file_falls_back_to_defaults() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[[[ not a config")
	f.close()
	Settings.load_settings()
	eq(Settings.get_value("audio", "master"), 1.0, "defaults in effect")


func test_input_defaults_registered() -> void:
	ok(InputMap.has_action(InputActions.MOVE_FORWARD), "move_forward exists")
	ok(InputMap.has_action(InputActions.INTERACT), "interact exists")
