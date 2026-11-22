extends Control
## A placeholder item icon drawn in code (items.json "icon"). Replaced by real
## art later. "baekseolgi": a plain steamed white rice cake (백설기), a soft white
## rounded square with faint grey shading and a few tiny pores. The nine tools
## (Prompt 9c) are simple line drawings: eomuk_kkochi, jipge, hyojason, jamjarichae,
## tteulchae, usan, selcabong, deungsan_stick, gomu_janggap. Prompt 9f adds goranee_fang, deer_antler,
## noru_antler, snake_skin and empty_bottle.

const KNOWN: Array[String] = ["baekseolgi", "eomuk_kkochi", "jipge", "hyojason", "jamjarichae", "tteulchae", "usan", "selcabong", "deungsan_stick", "gomu_janggap", "goranee_fang", "deer_antler", "noru_antler", "snake_skin", "empty_bottle"]

var icon_id := ""


static func is_known(id: String) -> bool:
	return KNOWN.has(id)


func setup(id: String, icon_size: float) -> void:
	name = "Icon"
	icon_id = id
	custom_minimum_size = Vector2(icon_size, icon_size)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if icon_id == "baekseolgi":
		_draw_baekseolgi()
	elif icon_id != "" and has_method("_draw_" + icon_id):
		call("_draw_" + icon_id)


func _draw_baekseolgi() -> void:
	var s := minf(size.x, size.y)
	var pad := s * 0.08
	var body := Rect2(Vector2(pad, pad), Vector2(s, s) - Vector2(pad, pad) * 2.0)
	var radius := int(s * 0.22)
	var shade := StyleBoxFlat.new()  # the faint grey underside, offset down and right
	shade.bg_color = Color(0.78, 0.79, 0.8)
	shade.set_corner_radius_all(radius)
	draw_style_box(shade, Rect2(body.position + Vector2(s, s) * 0.03, body.size))
	var cake := StyleBoxFlat.new()
	cake.bg_color = Color(0.97, 0.97, 0.95)
	cake.set_corner_radius_all(radius)
	draw_style_box(cake, Rect2(body.position, body.size - Vector2(s, s) * 0.03))
	var pore := Color(0.82, 0.83, 0.82)
	for p: Vector2 in [Vector2(0.32, 0.3), Vector2(0.62, 0.26), Vector2(0.48, 0.5), Vector2(0.72, 0.55), Vector2(0.3, 0.66), Vector2(0.55, 0.74)]:
		draw_circle(p * s, maxf(1.0, s * 0.028), pore)


## ---- The tools: a stick, a net or a glove, in a few strokes on a 0..1 square. ----

const WOOD := Color(0.72, 0.55, 0.33)
const STEEL := Color(0.7, 0.72, 0.76)
const DARK := Color(0.25, 0.25, 0.28)


func _p(x: float, y: float) -> Vector2:
	var s := minf(size.x, size.y)
	return Vector2(x, y) * s


func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(_p(a.x, a.y), _p(b.x, b.y), color, maxf(1.0, width * minf(size.x, size.y)))


func _dot(c: Vector2, radius: float, color: Color) -> void:
	draw_circle(_p(c.x, c.y), maxf(1.0, radius * minf(size.x, size.y)), color)


func _draw_eomuk_kkochi() -> void:
	_line(Vector2(0.2, 0.88), Vector2(0.8, 0.12), WOOD, 0.05)
	for t in [0.3, 0.5, 0.7]:
		var c := Vector2(0.2, 0.88).lerp(Vector2(0.8, 0.12), t)
		_dot(c, 0.1, Color(0.93, 0.82, 0.62))
		_dot(c, 0.055, Color(0.8, 0.45, 0.25))


func _draw_jipge() -> void:
	_line(Vector2(0.5, 0.92), Vector2(0.5, 0.5), STEEL, 0.07)
	_line(Vector2(0.5, 0.5), Vector2(0.3, 0.1), STEEL, 0.07)
	_line(Vector2(0.5, 0.5), Vector2(0.7, 0.1), STEEL, 0.07)
	_dot(Vector2(0.5, 0.5), 0.07, DARK)


func _draw_hyojason() -> void:
	_line(Vector2(0.2, 0.9), Vector2(0.65, 0.3), WOOD, 0.06)
	_line(Vector2(0.65, 0.3), Vector2(0.82, 0.14), WOOD, 0.06)
	for i in 3:
		_line(Vector2(0.72 + i * 0.07, 0.12 + i * 0.04), Vector2(0.84 + i * 0.07, 0.04 + i * 0.04), WOOD, 0.04)


func _draw_jamjarichae() -> void:
	_line(Vector2(0.18, 0.92), Vector2(0.6, 0.45), WOOD, 0.05)
	var mesh := Color(0.85, 0.95, 0.85)
	_dot(Vector2(0.68, 0.34), 0.26, mesh)
	_dot(Vector2(0.68, 0.34), 0.2, Color(0.35, 0.55, 0.4))
	_dot(Vector2(0.68, 0.34), 0.17, mesh)


func _draw_tteulchae() -> void:
	_line(Vector2(0.15, 0.92), Vector2(0.55, 0.5), WOOD, 0.05)
	_dot(Vector2(0.66, 0.38), 0.3, DARK)
	_dot(Vector2(0.66, 0.38), 0.25, Color(0.55, 0.78, 0.9))


func _draw_usan() -> void:
	var points := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		points.append(_p(0.5 + 0.42 * cos(a), 0.5 + 0.38 * sin(a)))
	draw_colored_polygon(points, Color(0.85, 0.3, 0.3))
	_line(Vector2(0.5, 0.5), Vector2(0.5, 0.88), DARK, 0.045)
	_line(Vector2(0.5, 0.88), Vector2(0.4, 0.92), DARK, 0.045)


func _draw_selcabong() -> void:
	_line(Vector2(0.3, 0.92), Vector2(0.65, 0.35), DARK, 0.05)
	draw_rect(Rect2(_p(0.52, 0.06), _p(0.28, 0.34)), Color(0.2, 0.2, 0.24))
	draw_rect(Rect2(_p(0.56, 0.1), _p(0.2, 0.22)), Color(0.5, 0.75, 0.95))


func _draw_deungsan_stick() -> void:
	_line(Vector2(0.45, 0.95), Vector2(0.55, 0.08), Color(0.35, 0.45, 0.35), 0.05)
	_line(Vector2(0.36, 0.78), Vector2(0.64, 0.78), DARK, 0.04)
	_line(Vector2(0.5, 0.08), Vector2(0.6, 0.06), DARK, 0.08)


func _draw_gomu_janggap() -> void:
	var yellow := Color(0.98, 0.85, 0.2)
	var shade := Color(0.85, 0.7, 0.1)
	draw_rect(Rect2(_p(0.3, 0.5), _p(0.4, 0.42)), yellow)
	draw_rect(Rect2(_p(0.3, 0.84), _p(0.4, 0.08)), shade)
	for i in 4:
		draw_rect(Rect2(_p(0.3 + i * 0.1, 0.12 + (0.04 if i == 0 or i == 3 else 0.0)), _p(0.08, 0.42)), yellow)
	draw_rect(Rect2(_p(0.06, 0.4), _p(0.08, 0.3)), yellow)

## ---- Prompt 9f: trophies, a souvenir, a skin and junk ----

func _draw_goranee_fang() -> void:
	var bone := Color(0.95, 0.93, 0.85)
	draw_colored_polygon(PackedVector2Array([_p(0.38, 0.1), _p(0.62, 0.1), _p(0.54, 0.6), _p(0.5, 0.92), _p(0.46, 0.6)]), bone)
	_line(Vector2(0.44, 0.14), Vector2(0.5, 0.8), Color(0.8, 0.77, 0.68), 0.02)


func _draw_deer_antler() -> void:
	var horn := Color(0.62, 0.45, 0.28)
	_line(Vector2(0.5, 0.95), Vector2(0.5, 0.45), horn, 0.07)
	_line(Vector2(0.5, 0.6), Vector2(0.25, 0.3), horn, 0.06)
	_line(Vector2(0.25, 0.3), Vector2(0.2, 0.08), horn, 0.05)
	_line(Vector2(0.5, 0.45), Vector2(0.75, 0.18), horn, 0.06)
	_line(Vector2(0.62, 0.32), Vector2(0.86, 0.34), horn, 0.045)
	_line(Vector2(0.38, 0.45), Vector2(0.16, 0.5), horn, 0.045)


func _draw_noru_antler() -> void:
	var horn := Color(0.7, 0.58, 0.4)
	_line(Vector2(0.4, 0.92), Vector2(0.45, 0.4), horn, 0.09)
	_line(Vector2(0.45, 0.4), Vector2(0.62, 0.1), horn, 0.07)
	_line(Vector2(0.44, 0.5), Vector2(0.24, 0.3), horn, 0.055)
	_dot(Vector2(0.4, 0.92), 0.07, Color(0.55, 0.45, 0.32))


func _draw_snake_skin() -> void:
	var skin := Color(0.82, 0.86, 0.7, 0.9)
	var points := PackedVector2Array()
	for i in 12:
		var t := float(i) / 11.0
		points.append(_p(0.12 + 0.76 * t, 0.5 + 0.22 * sin(t * TAU * 1.2)))
	draw_polyline(points, skin, maxf(2.0, 0.16 * minf(size.x, size.y)))
	draw_polyline(points, Color(0.55, 0.62, 0.45), maxf(1.0, 0.03 * minf(size.x, size.y)))


func _draw_empty_bottle() -> void:
	var glass := Color(0.35, 0.62, 0.4, 0.85)
	draw_rect(Rect2(_p(0.4, 0.06), _p(0.2, 0.28)), glass)
	draw_colored_polygon(PackedVector2Array([_p(0.4, 0.32), _p(0.6, 0.32), _p(0.78, 0.5), _p(0.78, 0.94), _p(0.22, 0.94), _p(0.22, 0.5)]), glass)
	draw_rect(Rect2(_p(0.22, 0.58), _p(0.56, 0.18)), Color(0.95, 0.95, 0.9))
	draw_rect(Rect2(_p(0.38, 0.03), _p(0.24, 0.05)), Color(0.8, 0.8, 0.8))
