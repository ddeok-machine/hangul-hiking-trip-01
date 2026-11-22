extends RefCounted
## Rebinding of the Input Map's actions, with no nodes (data/series/controls_rows.json). Each row
## of the data is one remappable action with a keyboard slot and/or a gamepad slot. A slot is the
## action's FIRST event of that kind: binding replaces it and leaves any other events (alternate
## keys, the second pad button) alone.
##
## bind_key / bind_pad return {"result", "other"}:
##   "ok"        bound
##   "swap"      another remappable action held the input; it gets this action's old binding
##   "reserved"  the input belongs to pause or a ui_* action (and is no action's default): refused
##   "invalid"   not a remappable action or slot: refused
## Gamepad inputs only conflict between actions of the same device (player 1's Cross and
## player 2's Cross are different bindings).
##
## capture_defaults() must run before any binding is applied (the defaults are project.godot's).
## changes() / apply_changes() are what is saved in settings.cfg: only the slots that differ from
## the defaults; anything malformed in a saved file is ignored.

const DATA_PATH := "res://data/series/controls_rows.json"

static var _data: Dictionary = {}

## Row dictionaries of the remappable actions: {"action", "label", "slots", "device"}.
var rows: Array = []
var reserved_actions: Array = []
var _defaults: Dictionary = {}  # action -> Array of events


## The data file, read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


## `row_defs` and `reserved` default to the data file's.
func _init(row_defs: Array = [], reserved: Array = []) -> void:
	rows = row_defs if not row_defs.is_empty() else data().get("controls_rows", [])
	reserved_actions = reserved if not reserved.is_empty() else data().get("reserved_actions", [])


## Remembers every remappable action's events as they are now.
func capture_defaults() -> void:
	_defaults.clear()
	for row in rows:
		var action := String(row["action"])
		if InputMap.has_action(action):
			_defaults[action] = InputMap.action_get_events(action).map(func(e): return e.duplicate())


func is_remappable(action: String, slot: String = "") -> bool:
	var row := row_of(action)
	return not row.is_empty() and (slot == "" or (row["slots"] as Array).has(slot))


func row_of(action: String) -> Dictionary:
	for row in rows:
		if row["action"] == action:
			return row
	return {}


## The action's first keyboard event (null if it has none).
func key_of(action: String) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event
	return null


## The action's first gamepad button event (null if it has none).
func pad_of(action: String) -> InputEventJoypadButton:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return event
	return null


static func key_code(event: InputEventKey) -> int:
	return int(event.physical_keycode) if event.physical_keycode != KEY_NONE else int(event.keycode)


static func same_key(a: InputEventKey, b: InputEventKey) -> bool:
	return a != null and b != null and key_code(a) == key_code(b) and int(a.location) == int(b.location)


## Binds the keyboard key of `event` (a press) to `action`'s keyboard slot.
func bind_key(action: String, event: InputEventKey) -> Dictionary:
	if not is_remappable(action, "key") or key_code(event) == int(KEY_NONE):
		return {"result": "invalid", "other": ""}
	var old := key_of(action)
	if same_key(old, event):
		return {"result": "ok", "other": ""}
	var fresh := _new_key(event)
	for row in rows:
		var other := String(row["action"])
		if other == action or not (row["slots"] as Array).has("key"):
			continue
		for held in InputMap.action_get_events(other):
			if held is InputEventKey and same_key(held, fresh):
				_replace_first(other, true, _new_key(old) if old != null else null)
				_replace_first(action, true, fresh)
				return {"result": "swap", "other": other}
	if _reserved_key(fresh):
		return {"result": "reserved", "other": ""}
	_replace_first(action, true, fresh)
	return {"result": "ok", "other": ""}


## Binds gamepad button `button` to `action`'s gamepad slot.
func bind_pad(action: String, button: int) -> Dictionary:
	if not is_remappable(action, "pad") or button < 0 or button >= JOY_BUTTON_MAX:
		return {"result": "invalid", "other": ""}
	var device := int(row_of(action).get("device", 0))
	var old := pad_of(action)
	if old != null and old.button_index == button:
		return {"result": "ok", "other": ""}
	for row in rows:
		var other := String(row["action"])
		if other == action or not (row["slots"] as Array).has("pad") or int(row.get("device", 0)) != device:
			continue
		var held := pad_of(other)
		if held != null and held.button_index == button:
			_replace_first(other, false, _new_pad(old.button_index, device) if old != null else null)
			_replace_first(action, false, _new_pad(button, device))
			return {"result": "swap", "other": other}
	if _reserved_pad(button):
		return {"result": "reserved", "other": ""}
	_replace_first(action, false, _new_pad(button, device))
	return {"result": "ok", "other": ""}


## Every remappable action back to its captured defaults.
func reset_all() -> void:
	for action in _defaults:
		InputMap.action_erase_events(action)
		for event in _defaults[action]:
			InputMap.action_add_event(action, event.duplicate())


## What differs from the defaults: {action: {"key": [code, location], "pad": button}}.
func changes() -> Dictionary:
	var out := {}
	for row in rows:
		var action := String(row["action"])
		if not _defaults.has(action):
			continue
		var entry := {}
		var slots: Array = row["slots"]
		if slots.has("key") and not same_key(key_of(action), _first_default_key(action)):
			var now := key_of(action)
			if now != null:
				entry["key"] = [key_code(now), int(now.location)]
		if slots.has("pad"):
			var now_pad := pad_of(action)
			var was := _first_default_pad(action)
			if now_pad != null and (was == null or now_pad.button_index != was.button_index):
				entry["pad"] = int(now_pad.button_index)
		if not entry.is_empty():
			out[action] = entry
	return out


## Applies a saved `changes()`. Anything malformed is skipped; the rest still applies.
func apply_changes(saved) -> void:
	if not saved is Dictionary:
		return
	for action in saved:
		var entry = saved[action]
		if not entry is Dictionary or not is_remappable(String(action)) or not _defaults.has(String(action)):
			continue
		var key = entry.get("key")
		if key is Array and key.size() == 2 and _is_whole(key[0]) and _is_whole(key[1]) and is_remappable(String(action), "key"):
			if int(key[0]) > 0 and int(key[1]) >= 0 and int(key[1]) <= 2:
				var event := InputEventKey.new()
				event.physical_keycode = int(key[0]) as Key
				event.location = int(key[1]) as KeyLocation
				event.device = -1
				_replace_first(String(action), true, event)
		var pad = entry.get("pad")
		if _is_whole(pad) and is_remappable(String(action), "pad") and int(pad) >= 0 and int(pad) < JOY_BUTTON_MAX:
			_replace_first(String(action), false, _new_pad(int(pad), int(row_of(String(action)).get("device", 0))))


func _is_whole(value) -> bool:
	return (value is int) or (value is float and is_equal_approx(value, roundf(value)))


func _first_default_key(action: String) -> InputEventKey:
	for event in _defaults.get(action, []):
		if event is InputEventKey:
			return event
	return null


func _first_default_pad(action: String) -> InputEventJoypadButton:
	for event in _defaults.get(action, []):
		if event is InputEventJoypadButton:
			return event
	return null


func _new_key(from: InputEventKey) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key_code(from) as Key
	event.location = from.location
	event.device = -1
	return event


func _new_pad(button: int, device: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button as JoyButton
	event.device = device
	event.pressed = true
	return event


## Replaces the first keyboard (or gamepad button) event of `action`, in place; with `event`
## null that event is removed.
func _replace_first(action: String, keyboard: bool, event: InputEvent) -> void:
	var events := InputMap.action_get_events(action)
	var at := -1
	for i in events.size():
		if (keyboard and events[i] is InputEventKey) or (not keyboard and events[i] is InputEventJoypadButton):
			at = i
			break
	if at >= 0 and event != null:
		events[at] = event
	elif at >= 0:
		events.remove_at(at)
	elif event != null:
		events.append(event)
	InputMap.action_erase_events(action)
	for e in events:
		InputMap.action_add_event(action, e)


## True if a reserved action holds `event` and no remappable action has it as its default.
func _reserved_key(event: InputEventKey) -> bool:
	for action in _defaults:
		for held in _defaults[action]:
			if held is InputEventKey and same_key(held, event):
				return false
	for action in reserved_actions:
		if InputMap.has_action(action):
			for held in InputMap.action_get_events(action):
				if held is InputEventKey and (key_code(held) == key_code(event) or (held.physical_keycode == KEY_NONE and held.keycode == event.physical_keycode)):
					return true
	return false


func _reserved_pad(button: int) -> bool:
	for row in rows:
		if (row["slots"] as Array).has("pad"):  # (the D-pad of a movement action is not one of these)
			for held in _defaults.get(String(row["action"]), []):
				if held is InputEventJoypadButton and held.button_index == button:
					return false
	for action in reserved_actions:
		if InputMap.has_action(action):
			for held in InputMap.action_get_events(action):
				if held is InputEventJoypadButton and held.button_index == button:
					return true
	return false
