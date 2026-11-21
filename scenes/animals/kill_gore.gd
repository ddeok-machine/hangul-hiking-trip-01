extends Node3D
## The gore of a kill (data: animals.predators.gore), over the top on purpose: a big blood burst
## where the prey stood, 4-6 small red-brown chunks that fly up, tumble and settle on the ground,
## and a dark-red splat on the ground. The splat and the chunks fade away together over
## splat_fade_s seconds, and then the node frees itself. Placeholder shapes.
##
## `advance(delta)` moves it (the node's _process calls it); tests call it directly. The node sits
## at the world origin: everything inside it is placed in world coordinates.

const HitFx := preload("res://scenes/foraging/hit_fx.gd")

signal finished

var config: Dictionary = {}
var height_at: Callable
var chunks: Array[Dictionary] = []
var splat: MeshInstance3D
var age := 0.0

var _chunk_material: StandardMaterial3D
var _splat_material: StandardMaterial3D
var _alpha := 1.0


## `gore` is the scene's gore_placeholder (the blood), `cfg` animals.predators.gore, `at` the
## world position of the kill (on the ground), `lift` how high the blood bursts, and `seed_value`
## fixes the chunks. Call it once the node is in the tree.
func setup(gore: Dictionary, cfg: Dictionary, at: Vector3, lift: float, ground_height: Callable, seed_value: int) -> void:
	name = "KillGore"
	config = cfg
	height_at = ground_height
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var chunk_color: Array = cfg["chunk_color"]
	_chunk_material = StandardMaterial3D.new()
	_chunk_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_chunk_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_chunk_material.albedo_color = Color(chunk_color[0], chunk_color[1], chunk_color[2])
	var splat_color: Array = cfg["splat_color"]
	_splat_material = StandardMaterial3D.new()
	_splat_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_splat_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_splat_material.albedo_color = Color(splat_color[0], splat_color[1], splat_color[2], float(cfg["splat_alpha"]))
	var disc := CylinderMesh.new()
	disc.top_radius = float(cfg["splat_radius"])
	disc.bottom_radius = float(cfg["splat_radius"])
	disc.height = 0.01
	disc.radial_segments = 20
	splat = MeshInstance3D.new()
	splat.name = "Splat"
	splat.mesh = disc
	splat.material_override = _splat_material
	splat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	splat.scale = Vector3(rng.randf_range(0.8, 1.25), 1.0, rng.randf_range(0.8, 1.25))
	add_child(splat)
	splat.global_position = Vector3(at.x, float(height_at.call(at.x)) + 0.03, at.z)
	var count := rng.randi_range(int(cfg["chunks_min"]), int(cfg["chunks_max"]))
	for i in count:
		var size := rng.randf_range(float(cfg["chunk_size_min"]), float(cfg["chunk_size_max"]))
		var box := BoxMesh.new()
		box.size = Vector3(size, size * rng.randf_range(0.6, 1.0), size * rng.randf_range(0.8, 1.3))
		var node := MeshInstance3D.new()
		node.name = "Chunk"
		node.mesh = box
		node.material_override = _chunk_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		node.global_position = at + Vector3(0.0, lift, 0.0)
		var side := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(float(cfg["chunk_speed_min"]), float(cfg["chunk_speed_max"]))
		chunks.append({
			"node": node, "half": box.size.y / 2.0, "landed": false,
			"velocity": Vector3(side.x, rng.randf_range(float(cfg["chunk_lift_min"]), float(cfg["chunk_lift_max"])), side.y),
			"spin": Vector3(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0))})
	HitFx.blood(self, gore, at + Vector3(0.0, lift, 0.0), float(cfg["blood_strength"]))


func _process(delta: float) -> void:
	advance(delta)


## True once every chunk has landed (they lie on the ground, fading with the splat).
func all_landed() -> bool:
	for chunk in chunks:
		if not chunk["landed"]:
			return false
	return true


## Moves the chunks (a flight under gravity, tumbling; on landing they lie still on the ground)
## and fades splat and chunks; frees the node at the end of splat_fade_s.
func advance(delta: float) -> void:
	age += delta
	for chunk in chunks:
		if chunk["landed"]:
			continue
		var node: Node3D = chunk["node"]
		var velocity: Vector3 = chunk["velocity"]
		velocity.y -= float(config["gravity"]) * delta
		chunk["velocity"] = velocity
		node.global_position += velocity * delta
		var spin: Vector3 = chunk["spin"]
		node.rotation += spin * delta
		var floor_y := float(height_at.call(node.global_position.x)) + float(chunk["half"])
		if node.global_position.y <= floor_y and velocity.y < 0.0:
			node.global_position.y = floor_y
			node.rotation = Vector3(0.0, node.rotation.y, 0.0)  # settles flat
			chunk["landed"] = true
	var fade := maxf(float(config["splat_fade_s"]), 0.001)
	_alpha = clampf(1.0 - age / fade, 0.0, 1.0)
	_splat_material.albedo_color.a = float(config["splat_alpha"]) * _alpha
	_chunk_material.albedo_color.a = _alpha
	if age >= fade:
		finished.emit()
		queue_free()


## The splat's current opacity factor (1 fresh .. 0 gone).
func alpha() -> float:
	return _alpha
