extends Node
## Persistent user settings (user://settings.cfg). Every value is validated and
## clamped, so a hand-edited or corrupt file can never put the game in a bad state.
## Ownership: LOCAL (settings are per-machine, never replicated).

const DEFAULT_PATH := "user://settings.cfg"
const WINDOW_MODES := ["windowed", "fullscreen", "borderless"]

const DEFAULTS := {
	"graphics": {
		"window_mode": "windowed",
		"resolution": Vector2i(1280, 720),
		"vsync": true,
		"vhs_effects": true,  # consumed by the Phase 8 post-process
	},
	"audio": {"master": 1.0, "music": 0.8, "sfx": 1.0, "voice": 1.0},
	"controls": {"mouse_sensitivity": 1.0, "invert_y": false},
}

var config_path: String = DEFAULT_PATH  # overridable (tests)
var _values: Dictionary = {}


func _ready() -> void:
	InputActions.ensure_defaults()
	load_settings()
	apply_all()


func get_value(section: String, key: String) -> Variant:
	if _values.has(section) and (_values[section] as Dictionary).has(key):
		return _values[section][key]
	if DEFAULTS.has(section) and (DEFAULTS[section] as Dictionary).has(key):
		return DEFAULTS[section][key]
	push_warning("Settings.get_value: unknown setting %s/%s" % [section, key])
	return null


## Returns false (and changes nothing) for unknown keys; invalid values are clamped
## or reset to the default for that key.
func set_value(section: String, key: String, value: Variant) -> bool:
	if not (DEFAULTS.has(section) and (DEFAULTS[section] as Dictionary).has(key)):
		push_warning("Settings.set_value: unknown setting %s/%s" % [section, key])
		return false
	var clean: Variant = _sanitize(section, key, value)
	if not _values.has(section):
		_values[section] = {}
	_values[section][key] = clean
	EventBus.publish(Events.SETTINGS_CHANGED, {"section": section, "key": key, "value": clean})
	return true


func load_settings() -> Error:
	_values = _defaults_copy()
	var cfg := ConfigFile.new()
	var err := cfg.load(config_path)
	if err != OK:
		return err  # missing/corrupt file: defaults stay in effect
	for section: String in DEFAULTS:
		for key: String in DEFAULTS[section]:
			if cfg.has_section_key(section, key):
				_values[section][key] = _sanitize(section, key, cfg.get_value(section, key))
	return OK


func save_settings() -> Error:
	var cfg := ConfigFile.new()
	for section: String in _values:
		for key: String in _values[section]:
			cfg.set_value(section, key, _values[section][key])
	return cfg.save(config_path)


func apply_all() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match get_value("graphics", "window_mode"):
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		_:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(get_value("graphics", "resolution"))
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if get_value("graphics", "vsync") else DisplayServer.VSYNC_DISABLED
	)
	# Only the Master bus exists until the Phase 8 audio layout adds the others.
	AudioServer.set_bus_volume_db(0, linear_to_db(get_value("audio", "master")))


func _defaults_copy() -> Dictionary:
	return DEFAULTS.duplicate(true)


func _sanitize(section: String, key: String, value: Variant) -> Variant:
	var default: Variant = DEFAULTS[section][key]
	match [section, key]:
		["graphics", "window_mode"]:
			return value if (value is String and value in WINDOW_MODES) else default
		["graphics", "resolution"]:
			if value is Vector2i:
				return Vector2i(clampi(value.x, 640, 7680), clampi(value.y, 360, 4320))
			return default
		["audio", _]:
			return clampf(value, 0.0, 1.0) if (value is float or value is int) else default
		["controls", "mouse_sensitivity"]:
			return clampf(value, 0.05, 5.0) if (value is float or value is int) else default
	# Remaining settings are booleans.
	return value if value is bool else default
