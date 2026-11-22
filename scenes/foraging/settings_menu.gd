extends RefCounted
## The rules of the pause menu's Settings screen, with no nodes: which row has the focus, and
## what left / right and the pick key do to it. The rows are data (controls_rows.json
## settings_rows); the values live in the Settings autoload and apply as they change.
##
## Row types: "volume" (left / right move a 0-10 step), "toggle" (left / right or pick flips it),
## "back" (pick leaves the screen).

const Remap := preload("res://scripts/remap.gd")

var rows: Array = []
var focus := 0


## `row_defs` defaults to the data file's, without the rows `hide_on_web` drops in a web export.
func _init(row_defs: Array = []) -> void:
	var source: Array = row_defs if not row_defs.is_empty() else Remap.data().get("settings_rows", [])
	for row in source:
		if not (bool(row.get("hide_on_web", false)) and OS.has_feature("web")):
			rows.append(row)


func move(step: int) -> void:
	if not rows.is_empty():
		focus = posmod(focus + step, rows.size())


func focus_on(index: int) -> void:
	if index >= 0 and index < rows.size():
		focus = index


func row() -> Dictionary:
	return rows[focus] if focus < rows.size() else {}


## Left (-1) or right (+1) on the focused row. True if a value changed.
func change(direction: int) -> bool:
	var current := row()
	match String(current.get("type", "")):
		"volume":
			var before: int = Settings.get_volume(current["id"])
			Settings.set_volume(current["id"], before + direction)
			return Settings.get_volume(current["id"]) != before
		"toggle":
			return _set_toggle(current["id"], direction > 0)
	return false


## The pick key on the focused row: a toggle flips, "back" returns "back". "" otherwise.
func activate() -> String:
	var current := row()
	match String(current.get("type", "")):
		"toggle":
			_set_toggle(current["id"], not bool(Settings.get(current["id"])))
			return "toggle"
		"back":
			return "back"
	return ""


func _set_toggle(id: String, value: bool) -> bool:
	var before: bool = Settings.get(id)
	match id:
		"fullscreen":
			Settings.set_fullscreen(value)
		"vibration":
			Settings.set_vibration(value)
	return bool(Settings.get(id)) != before


## The text at the right of row `index`: "7 / 10" or "Muted" for a volume, a toggle's label.
func value_text(index: int) -> String:
	var current: Dictionary = rows[index]
	match String(current.get("type", "")):
		"volume":
			var step: int = Settings.get_volume(current["id"])
			return "Muted" if step == 0 else "%d / 10" % step
		"toggle":
			return String((current["labels"] as Array)[1 if bool(Settings.get(current["id"])) else 0])
	return ""


## The step of a volume row, -1 for any other row.
func step_of(index: int) -> int:
	var current: Dictionary = rows[index]
	return Settings.get_volume(current["id"]) if String(current.get("type", "")) == "volume" else -1
