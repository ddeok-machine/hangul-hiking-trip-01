extends RefCounted
## The placeholder effects of the animals' gifts (Prompt 9f; data: animals.gifts.fx): a prop that
## falls and hits (a thunk, no damage), a skewer shot onto Nestor's forehead that stays, antlers
## on a male roe deer's model, a band round an arm, a poop mound. Each is a few boxes and a tween;
## nothing here decides anything (that is gifts.gd).

const Traveler := preload("res://scenes/foraging/traveler.gd")
const FloatLabel := preload("res://scenes/foraging/float_label.gd")


static func color_of(channels: Array) -> Color:
	return Color(channels[0], channels[1], channels[2])


static func box(label: String, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := Traveler.gray_mesh(mesh, color)
	node.name = label
	return node


## A prop that falls `height` m onto `at` in `seconds`, then calls `landed` and goes.
static func fall(host: Node3D, at: Vector3, height: float, seconds: float, size: Vector3, color: Color, landed := Callable()) -> Node3D:
	var node := box("GiftProp", size, color)
	host.add_child(node)
	node.global_position = at + Vector3(0.0, height, 0.0)
	var tween := node.create_tween()
	tween.tween_property(node, "global_position:y", at.y + size.y * 0.5, maxf(seconds, 0.01))
	if landed.is_valid():
		tween.tween_callback(landed)
	tween.tween_callback(node.queue_free)
	return node


## A prop thrown from `from` to `to` in `seconds` (a flat line), then `landed` and gone.
static func shot(host: Node3D, from: Vector3, to: Vector3, seconds: float, size: Vector3, color: Color, landed := Callable()) -> Node3D:
	var node := box("GiftShot", size, color)
	host.add_child(node)
	node.global_position = from
	if not from.is_equal_approx(to):
		node.look_at(to)
	var tween := node.create_tween()
	tween.tween_property(node, "global_position", to, maxf(seconds, 0.01))
	if landed.is_valid():
		tween.tween_callback(landed)
	tween.tween_callback(node.queue_free)
	return node


## The skewer stuck in Nestor's forehead, sticking out in front of him; one stays for the scene.
## `visible_after` seconds from now it shows (when the shot lands).
static func skewer_on(traveler: Node3D, color: Color, visible_after: float) -> Node3D:
	var found := traveler.get_node_or_null("Skewer")
	if found != null:
		return found
	var node := box("Skewer", Vector3(0.04, 0.04, 0.5), color)
	node.position = Vector3(0.0, Traveler.HEIGHT * 0.86, -Traveler.RADIUS - 0.15)
	node.visible = false
	traveler.add_child(node)
	var tween := node.create_tween()
	tween.tween_interval(maxf(visible_after, 0.01))
	tween.tween_callback(func() -> void: node.visible = true)
	return node


## Small antlers on an animal's head (a male roe deer): two bars with a prong each.
static func antlers_on(animal: Node3D, size: Vector3, color: Color) -> Node3D:
	var found := animal.get_node_or_null("Antlers")
	if found != null:
		return found
	var root := Node3D.new()
	root.name = "Antlers"
	root.position = Vector3(0.0, size.y + 0.02, -size.z * 0.3)
	for side in [-1.0, 1.0]:
		var bar := box("Bar", Vector3(0.04, 0.34, 0.04), color)
		bar.position = Vector3(side * 0.14, 0.17, 0.0)
		bar.rotation.z = -side * 0.25
		root.add_child(bar)
		var prong := box("Prong", Vector3(0.04, 0.16, 0.04), color)
		prong.position = Vector3(side * 0.2, 0.3, -0.05)
		prong.rotation.x = -0.6
		root.add_child(prong)
	animal.add_child(root)
	return root


## A band that wraps a traveler's arm for `seconds`, then loosens.
static func wrap_arm(traveler: Node3D, seconds: float, color: Color) -> Node3D:
	var node := box("ArmWrap", Vector3(0.14, 0.1, 0.14), color)
	node.position = Vector3(-Traveler.RADIUS - 0.02, Traveler.HEIGHT * 0.55, 0.0)
	traveler.add_child(node)
	var tween := node.create_tween()
	tween.tween_interval(maxf(seconds, 0.01))
	tween.tween_callback(node.queue_free)
	return node


## The badger's poop mound (stays).
static func mound_at(host: Node3D, at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 1.2
	var node := Traveler.gray_mesh(sphere, color)
	node.name = "DigMound"
	host.add_child(node)
	node.global_position = at + Vector3(0.0, radius * 0.3, 0.0)
	return node


## The animal's body tips forward and back over `seconds` (a bow). Needs the animal in the tree.
static func bow(animal: Node3D, seconds: float) -> void:
	var tween := animal.create_tween()
	tween.tween_property(animal, "rotation:x", 0.7, seconds * 0.4)
	tween.tween_interval(seconds * 0.2)
	tween.tween_property(animal, "rotation:x", 0.0, seconds * 0.4)


static func say(host: Node3D, text: String, at: Vector3, label_config: Dictionary) -> void:
	FloatLabel.make(host, text, at, label_config)
