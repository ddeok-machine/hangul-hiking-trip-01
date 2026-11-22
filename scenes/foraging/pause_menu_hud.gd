extends CanvasLayer
## The pause menu's look: a centred panel with a title and four buttons (Resume, Restart scene,
## Settings, Controls), over a light dim of the map. Settings and Controls are screens of their
## own in the same panel: rows of Control nodes (name, slider or value, key and button slots)
## built from data/series/controls_rows.json, with the same look as the buttons. Drawn in code,
## no art files. It runs while the tree is paused (process mode ALWAYS). Closed, its root is
## hidden and takes no clicks; open, the root covers the screen and swallows them. The keys act
## through PauseMenu (the menu and its confirmation), SettingsMenu and ControlsMenu; like the
## spelling view, it takes every player key while open, so none reaches the map.
##
## Keys: Esc / Circle (ui_cancel) go back one step; Options (`pause`) closes the whole menu,
## except while a new key or button is being captured: then it is the capture's own input.

const PauseMenu := preload("res://scenes/foraging/pause_menu.gd")
const SettingsMenu := preload("res://scenes/foraging/settings_menu.gd")
const ControlsMenu := preload("res://scenes/foraging/controls_menu.gd")
const SpellingCursor := preload("res://scenes/foraging/spelling_cursor.gd")
const FONT := preload("res://art/fonts/NotoSansKR-VariableFont_wght.ttf")

signal chosen(result: String)  ## what PauseMenu.activate() or escape() returned: "resume", "ask", "restart", "back", "settings", "controls"

const TITLE_FONT_SIZE := 30
const BUTTON_FONT_SIZE := 24
const MESSAGE_FONT_SIZE := 20
const OUTLINE_WIDTH := 4

var panel_size := Vector2(460, 440)
var button_size := Vector2(280, 58)
var button_gap := 16.0

var _menu
var _config: Dictionary = {}
var _root: Control
var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _message: Label
var _buttons: Array[Button] = []
var _plain: StyleBoxFlat
var _focused: StyleBoxFlat
var _sub_panel_size := Vector2(760, 560)
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _notice: Label
var _built := ""  # which sub screen the row nodes are built for
var _settings
var _controls
var _row_nodes: Array = []  # per row: {"panel", "name", "value", "slider", "key", "pad"}
var _row_height := 40.0
var _row_font_size := 20
var _slider_width := 220.0


## `menu` is the PauseMenu, `config` is foraging.pause_menu.
func setup(menu, config: Dictionary) -> void:
	layer = 15  # over the hover name (10), under the death beat's dim (20)
	name = "PauseMenuHud"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu = menu
	_config = config
	panel_size = _vec(config["panel_size"])
	_sub_panel_size = _vec(config["sub_panel_size"])
	button_size = _vec(config["button_size"])
	button_gap = float(config["button_gap"])
	_row_height = float(config["row_height"])
	_row_font_size = int(config["row_font_size"])
	_slider_width = float(config["slider_width"])
	var text_color := _color(config["text_color"])
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.0, 0.0, float(config["dim_alpha"]))
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_set_panel_size(panel_size)
	var back := StyleBoxFlat.new()
	back.bg_color = _color(config["panel_color"])
	back.set_corner_radius_all(10)
	back.set_content_margin_all(20.0)
	_panel.add_theme_stylebox_override("panel", back)
	_root.add_child(_panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(button_gap))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	_title = _label("Title", TITLE_FONT_SIZE, text_color)
	_title.text = str(config["title"])
	column.add_child(_title)
	_message = _label("Message", MESSAGE_FONT_SIZE, text_color)
	_message.text = str(config["confirm_text"])
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(panel_size.x - 40.0, 0.0)
	column.add_child(_message)
	_plain = _button_style(_color(config["button_color"]), Color(0, 0, 0, 0), 0)
	_focused = _button_style(_color(config["button_color"]), _color(config["outline_color"]), OUTLINE_WIDTH)
	for i in PauseMenu.COUNT:
		var button := Button.new()
		button.name = "Button%d" % i
		button.custom_minimum_size = button_size
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.focus_mode = Control.FOCUS_NONE  # the focus is PauseMenu's, drawn by the outline
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		for key in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(key, text_color)
		button.pressed.connect(choose.bind(i))
		button.mouse_entered.connect(_menu.focus_on.bind(i))
		button.mouse_entered.connect(refresh)
		column.add_child(button)
		_buttons.append(button)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.focus_mode = Control.FOCUS_NONE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(_sub_panel_size.x - 40.0, float(config["sub_scroll_height"]))
	_scroll.visible = false
	column.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.add_theme_constant_override("separation", 4)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows_box)
	_notice = _label("Notice", MESSAGE_FONT_SIZE, _color(config["outline_color"]))
	_notice.custom_minimum_size = Vector2(0.0, 28.0)
	_notice.visible = false
	column.add_child(_notice)
	refresh()


## Shows or hides the menu to match PauseMenu, and draws the focus.
func refresh() -> void:
	var open: bool = _menu.is_open
	_root.visible = open
	if not open:
		return
	var sub: String = _menu.sub
	if sub != _built:
		_build_sub(sub)
	var confirming: bool = _menu.confirming
	_set_panel_size(_sub_panel_size if sub != "" else panel_size)
	_title.visible = not confirming
	_title.text = str(_config["title"]) if sub == "" else str(_config[sub + "_title"])
	_message.visible = confirming
	_scroll.visible = sub != ""
	_notice.visible = sub == "controls"
	var texts: Array = [_config["yes_text"], _config["no_text"]] if confirming else [_config["resume_text"], _config["restart_text"], _config["settings_text"], _config["controls_text"]]
	for i in _buttons.size():
		_buttons[i].visible = sub == "" and i < texts.size()
		if i < texts.size():
			_buttons[i].text = str(texts[i])
		var style := _focused if i == _menu.focus else _plain
		for state in ["normal", "hover", "pressed", "focus"]:
			_buttons[i].add_theme_stylebox_override(state, style)
	if sub == "settings":
		_refresh_settings()
	elif sub == "controls":
		_refresh_controls()


## A press of choice `index` (the mouse): the focus moves there, then it is pressed.
func choose(index: int) -> void:
	_menu.focus_on(index)
	chosen.emit(_menu.activate())
	refresh()


## The capture timeout and the notices of the Controls screen run on real time.
func _process(delta: float) -> void:
	tick(delta)


## Advances the Controls screen's capture timeout and notice (the tests call it directly).
func tick(delta: float) -> void:
	if _controls != null and _menu.is_open and _menu.sub == "controls":
		var before: String = _controls.capturing + _controls.message
		_controls.tick(delta)
		if _controls.capturing + _controls.message != before:
			refresh()


## Esc / Circle go back, Options closes, the player keys, the sticks and the D-pads move and press;
## every player key is taken while open. While a key or button is being captured, everything goes
## to the capture.
func _input(event: InputEvent) -> void:
	if not _menu.is_open:
		return
	if _menu.sub == "controls" and _controls != null and _controls.capturing != "":
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
			_controls.handle_capture(event)
			refresh()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		var result: String = _menu.escape(false)
		chosen.emit(result)
		refresh()
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _menu.close():
			chosen.emit("resume")
		refresh()
	else:
		var action := _action_for(event)
		if action != "" or SpellingCursor.is_player_key(event):
			get_viewport().set_input_as_handled()
			_act(action)
			refresh()


## What a press of `action` ("up", "down", "left", "right", "pick") does on the screen shown.
func _act(action: String) -> void:
	match String(_menu.sub):
		"settings":
			if action == "up" or action == "down":
				_settings.move(-1 if action == "up" else 1)
			elif action == "left" or action == "right":
				_settings.change(-1 if action == "left" else 1)
			elif action == "pick" and _settings.activate() == "back":
				_menu.leave_sub()
				chosen.emit("back")
		"controls":
			if action == "up" or action == "down":
				_controls.move(-1 if action == "up" else 1)
			elif action == "left" or action == "right":
				_controls.move_slot(-1 if action == "left" else 1)
			elif action == "pick" and _controls.activate() == "back":
				_menu.leave_sub()
				chosen.emit("back")
		_:
			if action == "up" or action == "down":
				_menu.move(-1 if action == "up" else 1)
			elif action == "pick":
				chosen.emit(_menu.activate())


## "up", "down", "left", "right" or "pick" for a press of either player's key, a ui_* key (arrows,
## D-pads, sticks, Enter, Space, Cross: they cannot be rebound, so the menu is never out of reach),
## else "". The menu is shared, so both players act.
func _action_for(event: InputEvent) -> String:
	for player in [1, 2]:
		for action in ["up", "down", "left", "right"]:
			if InputPrompts.pressed(event, "p%d_%s" % [player, action], true):
				return action
		if event.is_action_pressed("p%d_pick" % player):
			return "pick"
	for action in ["up", "down", "left", "right"]:
		if InputPrompts.pressed(event, "ui_" + action, true):
			return action
	if event.is_action_pressed("ui_accept"):
		return "pick"
	return ""


# ---- The Settings and Controls screens ----

func _build_sub(sub: String) -> void:
	for node in _rows_box.get_children():
		_rows_box.remove_child(node)
		node.queue_free()
	_row_nodes.clear()
	_built = sub
	_settings = null
	_controls = null
	if sub == "settings":
		_settings = SettingsMenu.new()
		for i in _settings.rows.size():
			_row_nodes.append(_build_settings_row(i))
	elif sub == "controls":
		_controls = ControlsMenu.new()
		for i in _controls.rows.size():
			_row_nodes.append(_build_controls_row(i))
	_scroll.scroll_vertical = 0


func _row_panel(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Row%d" % index
	panel.custom_minimum_size = Vector2(0.0, _row_height)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_child(panel)
	return panel


func _row_label(text: String, width: float, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := _label("Text", _row_font_size, _color(_config["text_color"]))
	label.add_theme_font_override("font", FONT)
	label.text = text
	label.horizontal_alignment = align
	label.custom_minimum_size = Vector2(width, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _build_settings_row(index: int) -> Dictionary:
	var row: Dictionary = _settings.rows[index]
	var panel := _row_panel(index)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)
	var entry := {"panel": panel}
	if String(row["type"]) == "back":
		var back := _row_label(String(row["label"]), 0.0, HORIZONTAL_ALIGNMENT_CENTER)
		back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(back)
		panel.gui_input.connect(_on_settings_row_input.bind(index))
		return entry
	var name_label := _row_label(String(row["label"]), 230.0)
	line.add_child(name_label)
	if String(row["type"]) == "volume":
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 10
		slider.step = 1
		slider.focus_mode = Control.FOCUS_NONE
		slider.custom_minimum_size = Vector2(_slider_width, 0.0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_slider_changed.bind(index))
		line.add_child(slider)
		entry["slider"] = slider
	var value := _row_label("", 150.0, HORIZONTAL_ALIGNMENT_RIGHT)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(value)
	entry["value"] = value
	panel.gui_input.connect(_on_settings_row_input.bind(index))
	return entry


func _build_controls_row(index: int) -> Dictionary:
	var row: Dictionary = _controls.rows[index]
	var panel := _row_panel(index)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)
	var entry := {"panel": panel}
	if not row.has("action"):
		var text := _row_label(String(row["label"]), 0.0, HORIZONTAL_ALIGNMENT_CENTER)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		panel.gui_input.connect(_on_controls_row_input.bind(index))
		return entry
	var name_label := _row_label(String(row["label"]), 300.0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	for which in [ControlsMenu.KEY, ControlsMenu.PAD]:
		var button := Button.new()
		button.name = "Key" if which == ControlsMenu.KEY else "Pad"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(170.0, 0.0)
		button.add_theme_font_override("font", FONT)
		button.add_theme_font_size_override("font_size", _row_font_size)
		for key in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(key, _color(_config["text_color"]))
		button.disabled = which == ControlsMenu.PAD and not (row["slots"] as Array).has("pad")
		button.visible = true
		button.pressed.connect(_on_slot_pressed.bind(index, which))
		line.add_child(button)
		entry[button.name.to_lower()] = button
	return entry


func _refresh_settings() -> void:
	for i in _row_nodes.size():
		var entry: Dictionary = _row_nodes[i]
		_style_row(entry["panel"], i == _settings.focus)
		if entry.has("value"):
			entry["value"].text = _settings.value_text(i)
		if entry.has("slider"):
			entry["slider"].set_value_no_signal(_settings.step_of(i))
	_notice.text = ""
	_scroll_to.call_deferred(_settings.focus)


func _refresh_controls() -> void:
	for i in _row_nodes.size():
		var entry: Dictionary = _row_nodes[i]
		var here: bool = i == _controls.focus
		_style_row(entry["panel"], here and not entry.has("key"))
		if entry.has("key"):
			entry["panel"].add_theme_stylebox_override("panel", _plain)
			for which in [ControlsMenu.KEY, ControlsMenu.PAD]:
				var button: Button = entry["key" if which == ControlsMenu.KEY else "pad"]
				button.text = _controls.slot_text(i, which)
				var style := _focused if here and which == _controls.slot else _plain
				for state in ["normal", "hover", "pressed", "focus", "disabled"]:
					button.add_theme_stylebox_override(state, style if not button.disabled else _plain)
				if button.disabled:
					button.text = ""
	_notice.text = _controls.message
	_scroll_to.call_deferred(_controls.focus)


func _style_row(panel: PanelContainer, focused: bool) -> void:
	panel.add_theme_stylebox_override("panel", _focused if focused else _plain)


func _scroll_to(index: int) -> void:
	if index >= 0 and index < _row_nodes.size() and is_instance_valid(_row_nodes[index]["panel"]):
		_scroll.ensure_control_visible(_row_nodes[index]["panel"])


func _on_slider_changed(value: float, index: int) -> void:
	if _settings != null:
		_settings.focus_on(index)
		Settings.set_volume(_settings.rows[index]["id"], int(value))
		refresh()


func _on_settings_row_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _settings != null:
		_settings.focus_on(index)
		_act("pick")
		refresh()


func _on_controls_row_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _controls != null:
		_controls.focus_on(index)
		_act("pick")
		refresh()


func _on_slot_pressed(index: int, which: int) -> void:
	if _controls == null or _controls.capturing != "":
		return
	_controls.focus_on(index)
	_controls.slot = which
	_act("pick")
	refresh()


# ---- For the tests ----

func settings_logic():
	return _settings


func controls_logic():
	return _controls


func sub_row_count() -> int:
	return _row_nodes.size()


func row_rect(index: int) -> Rect2:
	return _row_nodes[index]["panel"].get_global_rect()


func notice_text() -> String:
	return _notice.text


func title_text() -> String:
	return _title.text


## Where a button is on the screen (tests click its centre).
func button_rect(index: int) -> Rect2:
	return _buttons[index].get_global_rect()


func panel_rect() -> Rect2:
	return _panel.get_global_rect()


func root_visible() -> bool:
	return _root.visible


func focused_style_on(index: int) -> bool:
	return _buttons[index].get_theme_stylebox("normal") == _focused


func _set_panel_size(size: Vector2) -> void:
	_panel.offset_left = -size.x / 2.0
	_panel.offset_right = size.x / 2.0
	_panel.offset_top = -size.y / 2.0
	_panel.offset_bottom = size.y / 2.0


func _label(label_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button_style(fill: Color, outline: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style


func _vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


func _color(value: Array) -> Color:
	return Color(float(value[0]), float(value[1]), float(value[2]))
