extends Node
## On-screen input prompts and the small input helpers the scenes share (autoload).
##
## Tracks which kind of device was used last (keyboard / mouse, or a gamepad) and
## names the control of an action for that device: label_for("p1_pick") is "Space"
## on the keyboard and "✕" (or its fallback) on a gamepad. Texts in data carry
## `{action}` tokens that fill() replaces, so a prompt never hardcodes a key.
##
## Also:
##   walk_vector(player)   the walking input: constant speed, no analog speed
##   pressed(event, action, echo)   is_action_pressed, but a stick counts once per push
##
## Glyph choices live in data/series/input_prompts.json.

signal device_changed(gamepad: bool)

const DATA_PATH := "res://data/series/input_prompts.json"
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


func _ready() -> void:
	load_data()
	get_tree().root.window_input.connect(note_event)  # sees events a menu goes on to consume


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

## The walking input of player 1 or 2: a unit vector, or zero. Keys and the stick
## walk at the same constant speed; a half-pushed stick is no slower.
func walk_vector(player := 1) -> Vector2:
	var v := Input.get_vector("p%d_left" % player, "p%d_right" % player, "p%d_up" % player, "p%d_down" % player, 0.0)
	return v.normalized() if v.length() > 0.001 else Vector2.ZERO


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
