extends Node
## Player settings, saved to user://settings.cfg and applied as they change (autoload).
##
##   romanization, english_subtitles   subtitles (bool)
##   master_volume, music_volume, sfx_volume   0..10 steps, 10 = full, 0 = mute; they drive the
##                                     buses Master, Music and SFX (the last two are made here if
##                                     the project has no audio bus layout)
##   fullscreen                        false = windowed (does nothing in a web export)
##   vibration                         gamepad rumble on/off (scripts/vibration.gd)
##   remap                             the Input Map rebinding (scripts/remap.gd), saved in the
##                                     [controls] section
##
## A missing or corrupt file, or a bad entry in one, gives the defaults for what it spoils.

const Remap := preload("res://scripts/remap.gd")

signal setting_changed(key: String, value)

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"
const CONTROLS := "controls"
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const MAX_VOLUME := 10
## Volume setting -> bus.
const VOLUME_BUSES := {"master_volume": BUS_MASTER, "music_volume": BUS_MUSIC, "sfx_volume": BUS_SFX}

## Tests point this at a temp file so the real settings aren't touched.
var path: String = DEFAULT_PATH
## Called with true/false when the display mode is to change. Tests replace it, so that no
## window is ever touched; the default does nothing headless or on the web.
var window_fn: Callable = _set_window_mode

var romanization: bool = false
var english_subtitles: bool = false
var master_volume: int = MAX_VOLUME
var music_volume: int = MAX_VOLUME
var sfx_volume: int = MAX_VOLUME
var fullscreen: bool = false
var vibration: bool = true
var remap


func _ready() -> void:
	ensure_buses()
	remap = Remap.new()
	remap.capture_defaults()  # project.godot's bindings, before any saved remap is applied
	load_settings()


func set_romanization(value: bool) -> void:
	_apply("romanization", value)


func set_english_subtitles(value: bool) -> void:
	_apply("english_subtitles", value)


func set_fullscreen(value: bool) -> void:
	_apply("fullscreen", value)


func set_vibration(value: bool) -> void:
	_apply("vibration", value)


## `id` is "master", "music" or "sfx"; the step is clamped to 0..10.
func set_volume(id: String, step: int) -> void:
	_apply(id + "_volume", clampi(step, 0, MAX_VOLUME))


func get_volume(id: String) -> int:
	return int(get(id + "_volume"))


func _apply(key: String, value) -> void:
	if get(key) == value:
		return
	set(key, value)
	_apply_effect(key)
	save_settings()
	setting_changed.emit(key, value)


func _apply_effect(key: String) -> void:
	if VOLUME_BUSES.has(key):
		apply_volume(key)
	elif key == "fullscreen":
		window_fn.call(fullscreen)


# ---- Audio ----

## Makes the Music and SFX buses (sending to Master) if they are not there. Safe to repeat.
func ensure_buses() -> void:
	for bus in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, BUS_MASTER)


## The bus volume of a step: 10 is 0 dB, each step below is a linear tenth less; 0 is silence.
static func volume_db(step: int) -> float:
	return -80.0 if step <= 0 else linear_to_db(float(clampi(step, 0, MAX_VOLUME)) / MAX_VOLUME)


func apply_volume(key: String) -> void:
	var index := AudioServer.get_bus_index(VOLUME_BUSES[key])
	if index < 0:
		return
	var step: int = get(key)
	AudioServer.set_bus_mute(index, step <= 0)
	AudioServer.set_bus_volume_db(index, volume_db(step))


func apply_all() -> void:
	ensure_buses()
	for key in VOLUME_BUSES:
		apply_volume(key)
	window_fn.call(fullscreen)


func _set_window_mode(full: bool) -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		return
	var mode := DisplayServer.window_get_mode()
	var fullscreen_now := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if full and not fullscreen_now:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not full and fullscreen_now:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# ---- File ----

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "romanization", romanization)
	cfg.set_value(SECTION, "english_subtitles", english_subtitles)
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.set_value(SECTION, "vibration", vibration)
	if remap != null:
		var changes: Dictionary = remap.changes()
		for action in changes:
			cfg.set_value(CONTROLS, action, changes[action])
	var err := cfg.save(path)
	if err != OK:
		push_error("Can't save settings to %s (error %d)" % [path, err])


## Missing file or keys fall back to the defaults; the result is applied (buses, window, bindings).
func load_settings() -> void:
	romanization = false
	english_subtitles = false
	master_volume = MAX_VOLUME
	music_volume = MAX_VOLUME
	sfx_volume = MAX_VOLUME
	fullscreen = false
	vibration = true
	if remap != null:
		remap.reset_all()
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		romanization = _bool(cfg.get_value(SECTION, "romanization", false), false)
		english_subtitles = _bool(cfg.get_value(SECTION, "english_subtitles", false), false)
		master_volume = _step(cfg.get_value(SECTION, "master_volume", MAX_VOLUME))
		music_volume = _step(cfg.get_value(SECTION, "music_volume", MAX_VOLUME))
		sfx_volume = _step(cfg.get_value(SECTION, "sfx_volume", MAX_VOLUME))
		fullscreen = _bool(cfg.get_value(SECTION, "fullscreen", false), false)
		vibration = _bool(cfg.get_value(SECTION, "vibration", true), true)
		if remap != null and cfg.has_section(CONTROLS):
			var saved := {}
			for action in cfg.get_section_keys(CONTROLS):
				saved[action] = cfg.get_value(CONTROLS, action)
			remap.apply_changes(saved)
	apply_all()


static func _bool(value, fallback: bool) -> bool:
	return value if value is bool else fallback


static func _step(value) -> int:
	if (value is int) or (value is float and is_equal_approx(value, roundf(value))):
		return clampi(int(value), 0, MAX_VOLUME)
	return MAX_VOLUME
