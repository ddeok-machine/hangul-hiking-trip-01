extends CanvasLayer
## The second warning of the scene timer (Prompt 9e): a huge dark shadow that sweeps along one
## screen edge, as if something enormous walked past just out of sight. A dark blob (a radial
## gradient, drawn as a stretched texture) whose centre sits on the edge and slides from before
## one end of the edge to beyond the other over `seconds`. It is aged by the map (`advance`), so
## it stands still while the scene does. Data: animals.scene_timer.shadow.

var edge := ""
var seconds := 4.0
var thickness := 0.4
var alpha := 0.88
var _time := -1.0
var _blob: TextureRect
var _length := 0.55  # the blob's extent along the edge, as a share of the edge


func setup(config: Dictionary) -> void:
	name = "WarningFx"
	layer = 9
	seconds = float(config["seconds"])
	thickness = float(config["thickness"])
	alpha = float(config["alpha"])
	var c: Array = config["color"]
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(c[0], c[1], c[2], 1.0), Color(c[0], c[1], c[2], 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_blob = TextureRect.new()
	_blob.name = "Shadow"
	_blob.texture = texture
	_blob.stretch_mode = TextureRect.STRETCH_SCALE
	_blob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_blob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blob.modulate.a = alpha
	_blob.visible = false
	add_child(_blob)


## Starts a sweep along `along` ("west", "east", "far" or "near").
func start(along: String) -> void:
	edge = along
	_time = 0.0
	_blob.visible = true
	_place()


func is_active() -> bool:
	return _time >= 0.0


## 0..1 along the sweep (0 when it is not running).
func progress() -> float:
	return clampf(_time / maxf(seconds, 0.001), 0.0, 1.0) if _time >= 0.0 else 0.0


func is_visible_now() -> bool:
	return _blob.visible


func advance(delta: float) -> void:
	if _time < 0.0:
		return
	_time += delta
	if _time >= seconds:
		_time = -1.0
		_blob.visible = false
		return
	_place()


## The blob's rectangle on the screen now.
func rect() -> Rect2:
	return Rect2(_blob.position, _blob.size)


func _place() -> void:
	var view := get_viewport().get_visible_rect().size
	var u := progress()
	var sweep := lerpf(-_length * 0.5, 1.0 + _length * 0.5, u)  # the centre's place along the edge, as a share of it
	var horizontal := edge == "far" or edge == "near"  # these edges run along x
	var along := (view.x if horizontal else view.y)
	var across := (view.y if horizontal else view.x)
	var long_side := along * _length
	var deep := across * thickness * 2.0  # half of it is off screen: the centre sits on the edge
	var centre := Vector2.ZERO
	match edge:
		"west":
			centre = Vector2(0.0, sweep * along)
		"east":
			centre = Vector2(view.x, (1.0 - sweep) * along)
		"far":
			centre = Vector2(sweep * along, 0.0)
		_:
			centre = Vector2((1.0 - sweep) * along, view.y)
	var size := Vector2(long_side, deep) if horizontal else Vector2(deep, long_side)
	_blob.size = size
	_blob.position = centre - size / 2.0
