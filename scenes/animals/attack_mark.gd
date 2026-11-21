extends Node3D
## The telegraph of an attack (data: animals.attacks.mark): a red "!" over the traveler's spot and
## a red ring on the ground that shrinks from ring_start_m to hit_radius_m as the telegraph runs
## out. Placeholder. `set_progress(0..1)` is called each tick by the scene.

const ReachRing := preload("res://scenes/foraging/reach_ring.gd")
const FONT := preload("res://art/fonts/NotoSansKR-VariableFont_wght.ttf")

const RING_WIDTH := 0.12

var config: Dictionary = {}
var ring: MeshInstance3D
var label: Label3D
var progress := 0.0
var point := Vector2.ZERO

var _start := 2.6
var _end := 1.0
var _height_at: Callable
var _last_steps := -1


## `cfg` is animals.attacks.mark; `hit_radius` the radius the ring shrinks to. Call it once the
## node is in the tree.
func setup(cfg: Dictionary, hit_radius: float, height_at: Callable) -> void:
	name = "AttackMark"
	config = cfg
	_start = float(cfg["ring_start_m"])
	_end = hit_radius
	_height_at = height_at
	var color: Array = cfg["color"]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color[0], color[1], color[2], float(cfg["alpha"]))
	ring = MeshInstance3D.new()
	ring.name = "Ring"
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	label = Label3D.new()
	label.name = "Bang"
	label.text = String(cfg["text"])
	label.font = FONT
	label.font_size = int(cfg["font_size"])
	label.pixel_size = float(cfg["pixel_size"])
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	label.no_depth_test = true
	label.outline_size = 16
	label.outline_modulate = Color(0.1, 0.02, 0.02)
	label.modulate = Color(color[0], color[1], color[2])
	label.position.y = float(cfg["height"])
	add_child(label)
	set_progress(0.0)


## Stands the mark on the ground at `spot` (x, z).
func place(spot: Vector2) -> void:
	point = spot
	global_position = Vector3(spot.x, float(_height_at.call(spot.x)), spot.y)
	_last_steps = -1
	set_progress(progress)


## The ring's outer radius at a progress of 0..1.
func radius_at(p: float) -> float:
	return lerpf(_start, _end, clampf(p, 0.0, 1.0))


func set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	var outer := radius_at(progress)
	var steps := roundi(outer * 100.0)
	if steps == _last_steps:
		return
	_last_steps = steps
	var centre := global_position if is_inside_tree() else Vector3.ZERO
	ring.mesh = ReachRing.mesh(outer, maxf(outer - RING_WIDTH, 0.0), centre, _height_at)
