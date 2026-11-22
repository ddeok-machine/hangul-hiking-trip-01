extends Control
## A placeholder main menu: the title, Start (the Hallasan foraging scene) and Quit to Desktop
## (not in a web export). Everything it says and goes to is data/series/main_menu.json. The
## buttons take the keyboard and the gamepad through the UI focus (ui_up / ui_down / ui_accept).
## Scene changes and quitting go through functions the tests replace.

const DATA_PATH := "res://data/series/main_menu.json"
const FONT := preload("res://art/fonts/NotoSansKR-VariableFont_wght.ttf")

## Called with the scene path for Start; called with no argument for Quit.
var start_fn: Callable = _change_scene
var quit_fn: Callable = _quit

var data: Dictionary = {}
var start_button: Button
var quit_button: Button


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	data = parsed if parsed is Dictionary else {}
	var back := ColorRect.new()
	back.color = Color(0.10, 0.16, 0.12)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(column)
	column.add_child(_label("Title", String(data.get("title", "")), 44))
	column.add_child(_label("Subtitle", String(data.get("subtitle", "")), 26))
	start_button = _button("Start", String(data.get("start_label", "Start")))
	start_button.pressed.connect(start)
	column.add_child(start_button)
	if not OS.has_feature("web"):
		quit_button = _button("Quit", String(data.get("quit_label", "Quit")))
		quit_button.pressed.connect(quit)
		column.add_child(quit_button)
	start_button.grab_focus.call_deferred()


## Start: the first scene of the game.
func start() -> void:
	start_fn.call(String(data.get("start_scene", "")))


## Quit to Desktop.
func quit() -> void:
	quit_fn.call()


func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _quit() -> void:
	get_tree().quit()


func _label(label_name: String, text: String, size: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(button_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.custom_minimum_size = Vector2(320.0, 52.0)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 24)
	return button
