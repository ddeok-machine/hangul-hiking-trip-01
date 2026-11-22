extends Control
## The placeholder that ends the demo (Prompt 9e): a black screen with "To be continued…" and
## "백록담" below it, fading in. Any key or click goes back to the game's main scene (a new hike).
## The first `grace_s` seconds ignore input, so a key still held from walking does nothing.
## Data: animals.ending.to_be_continued in data/mountains/<game>.json.

const FONT := preload("res://art/fonts/NotoSansKR-VariableFont_wght.ttf")

## The scene is about to be left for `path` (the main scene).
signal returning(path: String)

var line_label: Label
var sub_label: Label
var fade_in_s := 2.0
var grace_s := 0.6
var time := 0.0
var returned := false
var _black: ColorRect
var _column: VBoxContainer


## The main scene of the project as a res:// path.
static func main_scene_path() -> String:
	return ResourceUID.ensure_path(String(ProjectSettings.get_setting("application/run/main_scene")))


func _ready() -> void:
	var look: Dictionary = Content.mountain(GameState.game_id).get("animals", {}).get("ending", {}).get("to_be_continued", {})
	fade_in_s = float(look.get("fade_in_s", fade_in_s))
	grace_s = float(look.get("grace_s", grace_s))
	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_black)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", int(look.get("gap_px", 24)))
	_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_column)
	line_label = _make_label("Line", String(look.get("line", "To be continued…")), int(look.get("line_size", 64)), look.get("color", [0.95, 0.95, 0.92]))
	sub_label = _make_label("Sub", String(look.get("sub", "백록담")), int(look.get("sub_size", 40)), look.get("sub_color", [0.7, 0.8, 0.82]))
	_column.modulate.a = 0.0


func _make_label(label_name: String, text: String, size: int, color: Array) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(color[0], color[1], color[2]))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(label)
	return label


func _process(delta: float) -> void:
	advance(delta)


## Ages the fade-in (public so tests can drive it).
func advance(delta: float) -> void:
	time += delta
	_column.modulate.a = clampf(time / maxf(fade_in_s, 0.001), 0.0, 1.0)


## 0 (black) .. 1 (the text fully shown).
func text_alpha() -> float:
	return _column.modulate.a


func accepts_input() -> bool:
	return time >= grace_s and not returned


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed)
	if pressed and accepts_input():
		get_viewport().set_input_as_handled()
		return_to_main()


## Back to the game's main scene, on a new hike (hearts, backpack and the bank are what a new
## game has). A scene that is not the current one (as in the tests) only announces it.
func return_to_main() -> bool:
	if returned:
		return false
	returned = true
	GameState.new_hike()
	var path := main_scene_path()
	returning.emit(path)
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(path)
	return true
