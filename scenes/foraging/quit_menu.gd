extends RefCounted
## The rules of the pause menu's Quit screen, with no nodes: Exit to Main Menu and Quit to Desktop
## (rows from controls_rows.json quit_rows; Quit to Desktop is hidden in a web export). Progress is
## lost either way, so each item asks twice: the pick key once only arms it ("asked"), pressing it
## again on the same item returns its id. Moving the focus disarms. Esc / Circle leave the screen
## through PauseMenu; nothing here quits or changes a scene (the map does, through GameState).

const Remap := preload("res://scripts/remap.gd")

var rows: Array = []
var texts: Dictionary = {}
var focus := 0
## The row that has been asked about and waits for its second press, -1 for none.
var armed := -1


## `row_defs` defaults to the data file's; `web` to whether this is a web export.
func _init(row_defs: Array = [], web: bool = OS.has_feature("web")) -> void:
	var data: Dictionary = Remap.data()
	for row in (row_defs if not row_defs.is_empty() else data.get("quit_rows", [])):
		if not (bool(row.get("hide_on_web", false)) and web):
			rows.append(row)
	texts = data.get("texts", {})


func move(step: int) -> void:
	if not rows.is_empty():
		focus = posmod(focus + step, rows.size())
		armed = -1


func focus_on(index: int) -> void:
	if index >= 0 and index < rows.size():
		if index != focus:
			armed = -1
		focus = index


## The pick key: "asked" the first time (armed), then the row's id ("main_menu" or "desktop").
func activate() -> String:
	if rows.is_empty():
		return ""
	if armed != focus:
		armed = focus
		return "asked"
	armed = -1
	return String(rows[focus]["id"])


## The notice under the rows: the question while an item is armed, else "".
func notice() -> String:
	return String(texts.get("confirm_quit", "")) if armed >= 0 else ""
