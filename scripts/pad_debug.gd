extends Node
## The `--pad-debug` launch flag: prints, and appends to user://pad_debug.log, what the gamepads
## are and what is making the travelers walk. Added by InputPrompts only when the flag is given.
##
##   at startup        every connected device (id, name, guid, Input.is_joy_known) and the log path
##   while it runs     whenever a movement action (p1_* / p2_*) has strength > 0: the device id, the
##                     axis or button index, the raw value, and the action; 4 lines a second at most
##
## The readers are InputPrompts' (replaceable), so the tests can describe a pad that is not there.

const LOG_PATH := "user://pad_debug.log"
const MAX_LINES_PER_SECOND := 4
const DIRECTIONS := ["left", "right", "up", "down"]

## Where a line goes (print and the file by default); the tests collect them instead.
var sink: Callable = _write_line
var _window_start := -1.0
var _window_lines := 0
var _file: FileAccess = null


func _ready() -> void:
	print_startup()


func _process(_delta: float) -> void:
	scan(Time.get_ticks_msec() / 1000.0)


## True if the command line has the flag (also after a `--` separator).
static func flag_given() -> bool:
	return OS.get_cmdline_args().has("--pad-debug") or OS.get_cmdline_user_args().has("--pad-debug")


func print_startup() -> void:
	emit_line("pad-debug on. Log file: %s" % ProjectSettings.globalize_path(LOG_PATH))
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		emit_line("no connected gamepads")
	for device in pads:
		emit_line(device_line(device))


static func device_line(device: int) -> String:
	return "device %d name=\"%s\" guid=%s known=%s" % [device, Input.get_joy_name(device), Input.get_joy_guid(device), str(Input.is_joy_known(device))]


## One look at every movement action. `now` is in seconds.
func scan(now: float) -> void:
	for player in [1, 2]:
		for direction in DIRECTIONS:
			var action := "p%d_%s" % [player, direction]
			var sources := describe_sources(action)
			if sources.is_empty() and Input.get_action_strength(action) <= 0.0:
				continue
			if sources.is_empty():
				sources.append("source unknown (an action pressed by code, not an input event)")
			for source in sources:
				if allow(now):
					emit_line("%s <- %s" % [action, source])


## What is holding `action` down, by InputPrompts' readers: "key P", "device 0 axis 1 raw -0.812",
## "device 0 button 11 raw 1".
static func describe_sources(action: String) -> Array[String]:
	var out: Array[String] = []
	if not InputMap.has_action(action):
		return out
	var deadzone := InputMap.action_get_deadzone(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			if InputPrompts.key_down_fn.call(event):
				out.append("key %s" % OS.get_keycode_string(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode))
		elif event is InputEventJoypadMotion:
			for device in _devices_of(event):
				var raw: float = InputPrompts.joy_axis_fn.call(device, event.axis)
				if absf(raw) >= deadzone and (raw < 0.0) == (event.axis_value < 0.0):
					out.append("device %d axis %d raw %.3f" % [device, event.axis, raw])
		elif event is InputEventJoypadButton:
			for device in _devices_of(event):
				if InputPrompts.joy_button_fn.call(device, event.button_index):
					out.append("device %d button %d raw 1" % [device, event.button_index])
	return out


static func _devices_of(event: InputEvent) -> Array:
	if event.device >= 0:
		return [event.device] if InputPrompts.joy_connected_fn.call(event.device) else []
	return Input.get_connected_joypads()  # -1: every device


## True if one more line may go out in the second `now` is in (4 a second at most).
func allow(now: float) -> bool:
	if _window_start < 0.0 or now - _window_start >= 1.0:
		_window_start = now
		_window_lines = 0
	if _window_lines >= MAX_LINES_PER_SECOND:
		return false
	_window_lines += 1
	return true


func emit_line(text: String) -> void:
	sink.call(text)


func _write_line(text: String) -> void:
	print("[pad-debug] ", text)
	if _file == null:
		_file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
		if _file != null:
			_file.seek_end(0)
	if _file != null:
		_file.store_line("%s  %s" % [Time.get_datetime_string_from_system(), text])
		_file.flush()
