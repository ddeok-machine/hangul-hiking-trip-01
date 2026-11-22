extends Node
## On-screen input prompts and the small input helpers the scenes share (autoload).
##
## Tracks which kind of device was used last (keyboard / mouse, or a gamepad) and
## names the control of an action for that device: label_for("p1_pick") is "Space"
## on the keyboard and "✕" (or its fallback) on a gamepad. Texts in data carry
## `{action}` tokens that fill() replaces, so a prompt never hardcodes a key.
##
## Also:
##   walk_vector(player)   the walking input: constant speed, no analog speed. The keys plus the
##                         left stick and D-pad of the player's own pad (P1: device 0, P2: device 1)
##                         and nothing else (see walk_vector)
##   pressed(event, action, echo)   is_action_pressed, but a stick counts once per push
##
## Glyph choices live in data/series/input_prompts.json.

signal device_changed(gamepad: bool)

const DATA_PATH := "res://data/series/input_prompts.json"
const PadDebug := preload("res://scripts/pad_debug.gd")
const FONT := preload("res://art/fonts/NotoSansKR-VariableFont_wght.ttf")

## True once a gamepad was the last device used; false for keyboard and mouse.
var gamepad_active := false

var _buttons: Dictionary = {}
var _axes: Dictionary = {}
var _key_names: Dictionary = {}
var _threshold := 0.5
var _release := 0.3
## "device:axis" -> -1, 0 or 1: which way that stick axis was pushed at its last event.
var _stick_state: Dictionary = {}
var _edge_event: InputEvent = null
var _edge_result := false
var _walk_deadzone := 0.3
## Where walk_vector reads the world. The tests replace them; they default to the Input singleton.
var joy_axis_fn: Callable = func(device: int, axis: int) -> float: return Input.get_joy_axis(device, axis)
var joy_button_fn: Callable = func(device: int, button: int) -> bool: return Input.is_joy_button_pressed(device, button)
var joy_connected_fn: Callable = func(device: int) -> bool: return Input.get_connected_joypads().has(device)
var joy_known_fn: Callable = func(device: int) -> bool: return Input.is_joy_known(device)
var key_down_fn: Callable = _key_is_down
## Called with a message for a pad whose mapping is unknown (once per device).
var warn_fn: Callable = func(text: String) -> void: push_warning(text)
## device -> true: its stick is ignored for walking until it has been inside the dead zone once.
var _stick_held: Dictionary = {}
var _unknown_warned: Dictionary = {}
var _last_walk_frame := -1000


func _ready() -> void:
	load_data()
	get_tree().root.window_input.connect(note_event)  # sees events a menu goes on to consume
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if PadDebug.flag_given():
		add_child(PadDebug.new())


func _input(event: InputEvent) -> void:
	note_event(event)


func load_data() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not data is Dictionary:
		push_error("input_prompts: %s is not a readable JSON object" % DATA_PATH)
		return
	_buttons.clear()
	for index in data["buttons"]:
		var entry: Dictionary = data["buttons"][index]
		var glyph := String(entry["glyph"])
		_buttons[int(index)] = glyph if font_has(glyph) else String(entry["fallback"])
	_axes.clear()
	for index in data["axes"]:
		_axes[int(index)] = String(data["axes"][index])
	_key_names = data["key_names"]
	_threshold = float(data["stick_threshold"])
	_release = float(data["stick_release"])
	_walk_deadzone = float(data.get("walk_deadzone", 0.3))


## True if the Korean font draws every character of `text`.
static func font_has(text: String) -> bool:
	for i in text.length():
		if not FONT.has_char(text.unicode_at(i)):
			return false
	return true


## The glyph shown for a JoyButton number ("" if none is defined).
func button_label(button: int) -> String:
	return String(_buttons.get(button, ""))


# ---- The last device ----

## Call with every input event. A key, a mouse click or mouse movement makes the
## prompts keyboard prompts; a button or a pushed stick makes them gamepad prompts.
func note_event(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		stick_edge(event)  # keeps the stick state current even when nothing asks about this event
	var gamepad := gamepad_active
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			gamepad = false
	elif event is InputEventMouseMotion:
		gamepad = false
	elif event is InputEventJoypadButton:
		if event.pressed:
			gamepad = true
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) >= _threshold:
			gamepad = true
	if gamepad != gamepad_active:
		gamepad_active = gamepad
		device_changed.emit(gamepad)


## Forgets the last device and every stick push (the tests start from the keyboard).
func reset() -> void:
	_stick_state.clear()
	_stick_held.clear()
	_unknown_warned.clear()
	_last_walk_frame = Engine.get_physics_frames()
	_edge_event = null
	if gamepad_active:
		gamepad_active = false
		device_changed.emit(false)


# ---- Labels ----

## The name of the control for `action` on the device used last: "Space", "E",
## "Tab" on the keyboard; "✕", "△", "R1", "Options" on a gamepad. An action with no
## control on that device shows its other one; "" if it has none at all.
func label_for(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	var pad := _pad_label(action)
	var key := _key_label(action)
	if gamepad_active:
		return pad if pad != "" else key
	return key if key != "" else pad


## Replaces every `{action}` in `text` by label_for(action). A brace that is not an
## action is left alone.
func fill(text: String) -> String:
	if not text.contains("{"):
		return text
	var out := ""
	var rest := text
	while true:
		var open := rest.find("{")
		var close := rest.find("}", open + 1) if open >= 0 else -1
		if open < 0 or close < 0:
			break
		var action := rest.substr(open + 1, close - open - 1)
		var label := label_for(action)
		out += rest.substr(0, open) + (label if label != "" else rest.substr(open, close - open + 1))
		rest = rest.substr(close + 1)
	return out + rest


## The keyboard name of `action` whatever device was used last ("" if it has no key).
func key_label_of(action: String) -> String:
	return _key_label(action) if InputMap.has_action(action) else ""


## The gamepad name of `action` whatever device was used last ("" if it has no button).
func pad_label_of(action: String) -> String:
	return _pad_label(action) if InputMap.has_action(action) else ""


func _key_label(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			var shown := code
			if event.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
				shown = DisplayServer.keyboard_get_keycode_from_physical(code)  # the key's name on the player's own layout
			var key_name := OS.get_keycode_string(shown if shown != KEY_NONE else code)
			return String(_key_names.get(key_name, key_name))
	return ""


func _pad_label(action: String) -> String:
	for event in InputMap.action_get_events(action):  # in the order of the Input Map: a stick before the D-pad
		if event is InputEventJoypadButton:
			return button_label(event.button_index)
		if event is InputEventJoypadMotion:
			return String(_axes.get(event.axis, ""))
	return ""


# ---- Walking and presses ----

## The walking input of player 1 or 2: a unit vector, or zero; keys and pad walk at the same
## constant speed. Only these count:
##   the player's keys (the keyboard events of p<N>_left / right / up / down, so remaps follow),
##   the LEFT stick (JOY_AXIS_LEFT_X / LEFT_Y) of that player's own pad (P1: device 0, P2: device 1),
##     inside a radial dead zone of walk_deadzone (0.3) = no walking,
##   the four D-pad buttons of that pad.
## Every other axis (triggers, which rest at -1 on some drivers, the right stick, raw axes of a pad
## the engine has no mapping for) and every other device are ignored. A pad Input.is_joy_known says
## no to is ignored too (one warning). A stick that was held while nobody was walking (a menu was
## open, the pad was just plugged in) is ignored until it has been inside the dead zone once.
func walk_vector(player := 1) -> Vector2:
	var frame := Engine.get_physics_frames()
	if frame - _last_walk_frame > 1:  # the scene did not ask last frame: a menu or pause was in the way
		hold_sticks()
	_last_walk_frame = frame
	var v := _key_vector(player) + _pad_vector(player - 1)
	return v.normalized() if v.length() > 0.001 else Vector2.ZERO


## Ignores every stick for walking until it has been inside the dead zone once.
func hold_sticks() -> void:
	for device in [0, 1]:
		_stick_held[device] = true


func _key_vector(player: int) -> Vector2:
	var prefix := "p%d_" % player
	return Vector2(float(_key_held(prefix + "right")) - float(_key_held(prefix + "left")), float(_key_held(prefix + "down")) - float(_key_held(prefix + "up")))


func _key_held(action: String) -> bool:
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and key_down_fn.call(event):
				return true
	return false


func _key_is_down(event: InputEventKey) -> bool:
	if event.physical_keycode != KEY_NONE:
		return Input.is_physical_key_pressed(event.physical_keycode)
	return event.keycode != KEY_NONE and Input.is_key_pressed(event.keycode)


func _pad_vector(device: int) -> Vector2:
	if not joy_connected_fn.call(device):
		return Vector2.ZERO
	if not joy_known_fn.call(device):
		if not _unknown_warned.has(device):
			_unknown_warned[device] = true
			warn_fn.call("Gamepad %d has no known mapping (%s): ignored for walking." % [device, Input.get_joy_name(device)])
		return Vector2.ZERO
	var stick := Vector2(joy_axis_fn.call(device, JOY_AXIS_LEFT_X), joy_axis_fn.call(device, JOY_AXIS_LEFT_Y))
	var outside := stick.length() >= _walk_deadzone
	if _stick_held.get(device, false):
		if outside:
			stick = Vector2.ZERO
		else:
			_stick_held.erase(device)
	var v := stick.normalized() if outside and stick != Vector2.ZERO else Vector2.ZERO
	v.x += float(joy_button_fn.call(device, JOY_BUTTON_DPAD_RIGHT)) - float(joy_button_fn.call(device, JOY_BUTTON_DPAD_LEFT))
	v.y += float(joy_button_fn.call(device, JOY_BUTTON_DPAD_DOWN)) - float(joy_button_fn.call(device, JOY_BUTTON_DPAD_UP))
	return v


## A pad was plugged in or out: nothing held stays held, and a pad that is just there must have
## its stick at rest before it walks anyone.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_stick_state.clear()
	_stick_held.clear()
	_unknown_warned.erase(device)
	_edge_event = null
	if connected:
		_stick_held[device] = true


## is_action_pressed(), except that a stick pushed past its dead zone counts as one
## press, not as one for every motion event while it is held (a stick sends a stream
## of them). Buttons and keys are unchanged. `echo` lets a held key repeat.
func pressed(event: InputEvent, action: String, echo := false) -> bool:
	var edge := true
	if event is InputEventJoypadMotion:
		edge = stick_edge(event)  # also for an event that is no press: it records the release
	return edge and event.is_action_pressed(action, echo)


## True if `event` is the push of a stick axis (past the threshold from below it, or to the
## other side). Asked any number of times about one event, it gives one answer.
func stick_edge(event: InputEventJoypadMotion) -> bool:
	if event == _edge_event:
		return _edge_result
	var key := "%d:%d" % [event.device, event.axis]
	var was: int = _stick_state.get(key, 0)
	var now := 0
	var side := 1 if event.axis_value > 0.0 else -1
	var limit := _release if was == side else _threshold  # leaving the push takes a little less than entering it
	if absf(event.axis_value) >= limit:
		now = side
	_stick_state[key] = now
	_edge_event = event
	_edge_result = now != 0 and now != was
	return _edge_result
