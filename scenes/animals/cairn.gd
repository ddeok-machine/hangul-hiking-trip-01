extends Node3D
## The 돌탑 (stone cairn) at the top of the animal map (Prompt 9e; data: animals.cairn): a stack of
## flattened grey stones narrowing upward, with a solid round collider at its base. The static
## functions give the geometry of the cairn, its trail and the exit trigger from the animals
## section, so the ground, the props, the scene and the tests agree. Coordinates as in the animal
## scene: x along the stage, z depth, 1 unit = 1 m.

const Traveler := preload("res://scenes/foraging/traveler.gd")

var stones: Array[MeshInstance3D] = []
var top_y := 0.0   # the height of the top of the highest stone above the cairn's base
var body: StaticBody3D


## The cairn's (x, z): horizontally centred, `inset_m` inside the far edge.
static func center(cfg: Dictionary) -> Vector2:
	return Vector2(float(cfg["stage"]["width"]) / 2.0, -float(cfg["stage"]["depth"]) / 2.0 + float(cfg["cairn"]["inset_m"]))


## The z of the invisible wall before the exit opens: the cairn's own line.
static func wall_z(cfg: Dictionary) -> float:
	return center(cfg).y


## The trail strip over (x, z): from the cairn's line to the far edge of the drawn ground.
static func trail_rect(cfg: Dictionary) -> Rect2:
	var c := center(cfg)
	var half := float(cfg["cairn"]["trail"]["half_width_m"])
	var far_z := -float(cfg["stage"]["depth"]) / 2.0 - float(cfg["apron"]["far"])
	return Rect2(Vector2(c.x - half, far_z), Vector2(2.0 * half, c.y - far_z))


## The exit trigger over (x, z): on the trail behind the cairn, from the far edge of the stage
## to `trigger_gap_m` behind the cairn's base.
static func trigger_rect(cfg: Dictionary) -> Rect2:
	var c := center(cfg)
	var half := float(cfg["cairn"]["trigger_half_width_m"])
	var far_z := -float(cfg["stage"]["depth"]) / 2.0
	var end_z := c.y - float(cfg["cairn"]["base_radius"]) - float(cfg["cairn"]["trigger_gap_m"])
	return Rect2(Vector2(c.x - half, far_z), Vector2(2.0 * half, maxf(end_z - far_z, 0.0)))


## The share (0..1) of the trail's colour at a point: 1 on the strip, easing to 0 over `blend_m`
## at its sides and at the cairn's line. Used by the ground texture.
static func trail_weight(cfg: Dictionary, x: float, z: float) -> float:
	var c := center(cfg)
	var trail: Dictionary = cfg["cairn"]["trail"]
	var blend := maxf(float(trail["blend_m"]), 0.001)
	var sides := clampf((float(trail["half_width_m"]) - absf(x - c.x)) / blend + 0.5, 0.0, 1.0)
	var behind := clampf((c.y - z) / blend + 0.5, 0.0, 1.0)
	return sides * behind


## True if a point is within the clearance round the cairn, or on its trail (the props keep off).
static func blocks_props(cfg: Dictionary, spot: Vector2) -> bool:
	var clear := float(cfg["cairn"]["clear_m"])
	if spot.distance_to(center(cfg)) < clear:
		return true
	return trail_rect(cfg).grow(1.0).has_point(spot)


## `cairn` is animals.cairn; `base` the ground height at the cairn.
func setup(cairn: Dictionary, base: Vector3) -> void:
	name = "Cairn"
	position = base
	var count := maxi(int(cairn["stones"]), 1)
	var height := float(cairn["height_m"])
	var r0 := float(cairn["base_radius"])
	var r1 := float(cairn["top_radius"])
	var colors: Array = cairn["colors"]
	var slice := height / count
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242  # the same stack every time
	for i in count:
		var u := float(i) / float(maxi(count - 1, 1))
		var radius := lerpf(r0, r1, u)
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		var c: Array = colors[i % colors.size()]
		var stone := Traveler.gray_mesh(mesh, Color(c[0], c[1], c[2]))
		stone.name = "Stone%d" % i
		var squash := (slice * 0.5) / radius * 1.15  # flat: a stone is about as tall as its slice
		stone.scale = Vector3(1.0, squash, 1.0)
		stone.position = Vector3(rng.randf_range(-0.05, 0.05), slice * (i + 0.5), rng.randf_range(-0.05, 0.05))
		stone.rotation.y = rng.randf_range(0.0, TAU)
		add_child(stone)
		stones.append(stone)
	top_y = slice * (count - 1) + slice * 0.5 * 1.15 + slice * 0.5
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = r0
	cylinder.height = height
	shape.shape = cylinder
	shape.position = Vector3(0.0, height / 2.0, 0.0)
	body = StaticBody3D.new()
	body.name = "Wall"
	body.add_child(shape)
	add_child(body)
