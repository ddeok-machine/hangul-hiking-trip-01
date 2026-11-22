extends RefCounted
## The rules of the pause menu's Controls screen, with no nodes: the focused row and slot, the
## capture of a new key or button, and the reset question. The rows are data (controls_rows.json);
## the rebinding itself is Settings.remap. Every change is saved at once.
##
## Rows are the remappable actions, then "reset" and "back". On an action row the focus is on its
## keyboard slot (0) or its gamepad slot (1; rows without one stay on 0). The pick key starts a
## capture: while it runs, every key and button goes to handle_capture() and nothing else of the
## menu acts (Options cannot close it). Esc cancels a keyboard capture, Options a gamepad capture,
## and it times out after capture_timeout_s. "Reset to defaults" asks for the pick key twice.

const Remap := preload("res://scripts/remap.gd")

const KEY := 0
const PAD := 1

var rows: Array = []
var texts: Dictionary = {}
var focus := 0
var slot := KEY
## "" while idle, else "key" or "pad".
var capturing := ""
var capture_left := 0.0
var reset_armed := false
## The notice on screen ("" for none) and how long it still stays.
var message := ""
var message_left := 0.0

var _timeout := 5.0
var _message_s := 2.5


## `row_defs` and `text_defs` default to the data file's.
func _init(row_defs: Array = [], text_defs: Dictionary = {}) -> void:
	var data: Dictionary = Remap.data()
	rows = (row_defs if not row_defs.is_empty() else data.get("controls_rows", [])).duplicate()
	rows.append_array(data.get("controls_tail", []))
	texts = text_defs if not text_defs.is_empty() else data.get("texts", {})
	_timeout = float(data.get("capture_timeout_s", 5.0))
	_message_s = float(data.get("message_s", 2.5))


func is_action_row(index: int) -> bool:
	return index >= 0 and index < rows.size() and rows[index].has("action")


func move(step: int) -> void:
	if capturing != "" or rows.is_empty():
		return
	focus = posmod(focus + step, rows.size())
	reset_armed = false
	_clamp_slot()


func focus_on(index: int) -> void:
	if capturing == "" and index >= 0 and index < rows.size():
		focus = index
		reset_armed = false
		_clamp_slot()


## Left / right between the keyboard and the gamepad slot of an action row.
func move_slot(direction: int) -> void:
	if capturing == "" and is_action_row(focus) and (rows[focus]["slots"] as Array).has("pad"):
		slot = PAD if direction > 0 else KEY


func _clamp_slot() -> void:
	if not is_action_row(focus) or not (rows[focus]["slots"] as Array).has("pad"):
		slot = KEY


## The pick key. Returns "capture" (a capture began), "reset_asked", "reset" (done), "back" or "".
func activate() -> String:
	if capturing != "":
		return ""
	var current: Dictionary = rows[focus]
	if current.has("action"):
		capturing = "key" if slot == KEY else "pad"
		capture_left = _timeout
		reset_armed = false
		_notice(String(texts["press_key" if slot == KEY else "press_button"]), _timeout)
		return "capture"
	if current["id"] == "reset":
		if not reset_armed:
			reset_armed = true
			_notice(String(texts["confirm_reset"]), _message_s * 2.0)
			return "reset_asked"
		reset_armed = false
		Settings.remap.reset_all()
		Settings.save_settings()
		_notice(String(texts["reset_done"]), _message_s)
		return "reset"
	return "back" if current["id"] == "back" else ""


## Every input event while capturing. True if it was taken (always, while capturing). A key press
## binds (Esc cancels a keyboard capture); a button press binds (Options cancels a gamepad
## capture). Any other event is swallowed so nothing else of the menu acts.
func handle_capture(event: InputEvent) -> bool:
	if capturing == "":
		return false
	var action: String = rows[focus]["action"]
	if capturing == "key":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.is_action_pressed("ui_cancel"):  # Esc
				cancel_capture()
			else:
				_finish(Settings.remap.bind_key(action, event))
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			cancel_capture()
		else:
			_finish(Settings.remap.bind_pad(action, event.button_index))
	return true


func cancel_capture() -> void:
	capturing = ""
	message = ""
	message_left = 0.0


## Advances the capture timeout and the notice.
func tick(delta: float) -> void:
	if capturing != "":
		capture_left -= delta
		if capture_left <= 0.0:
			cancel_capture()
	elif message_left > 0.0:
		message_left -= delta
		if message_left <= 0.0:
			message = ""


func _finish(result: Dictionary) -> void:
	capturing = ""
	match String(result["result"]):
		"swap":
			_notice(String(texts["swapped"]).replace("{other}", _label_of(String(result["other"]))), _message_s)
			Settings.save_settings()
		"reserved":
			_notice(String(texts["reserved"]), _message_s)
		"ok":
			message = ""
			message_left = 0.0
			Settings.save_settings()
		_:
			message = ""


func _label_of(action: String) -> String:
	for row in rows:
		if row.get("action", "") == action:
			return String(row["label"])
	return action


func _notice(text: String, seconds: float) -> void:
	message = text
	message_left = seconds


## What a slot shows: the key or button name (InputPrompts' naming), "Press ..." while capturing it.
func slot_text(index: int, which: int) -> String:
	if capturing != "" and index == focus and which == slot:
		return String(texts["press_key" if which == KEY else "press_button"])
	var action: String = rows[index]["action"]
	if which == PAD and not (rows[index]["slots"] as Array).has("pad"):
		return String(texts["none"])
	var shown: String = InputPrompts.key_label_of(action) if which == KEY else InputPrompts.pad_label_of(action)
	return shown if shown != "" else String(texts["none"])
