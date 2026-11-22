extends Node
## The animal scene's exit (Prompt 9e; data: animals.ending and animals.cairn): the exit note and
## the way out past the cairn. It is foraging's ending in the animal scene's shape: the same
## rules (Ending), the same note node (ExitNote), the same flight, landing, pickup and fade, but
## the gate is the cairn's trail instead of the 고사목's gap.
##
## `open()` is called when the last need is met: the note's pause starts and the exit trigger
## on the trail goes live. Each tick (`tick`, called by the map's step) the human traveler is
## checked against the trigger: with anyone downed the "Revive ... before you leave" note shows
## and nothing else happens; with nobody downed the screen fades to black, hearts, backpack and
## tools are stored as GameState's pending bank, and the scene mapped to `ending.next` is loaded.
##
## exit_state: "" (playing) | "fading" | "hold" (black, the target has no scene) | "handed_off".

const Ending := preload("res://scenes/foraging/ending.gd")
const ExitNote := preload("res://scenes/foraging/exit_note.gd")
const Cairn := preload("res://scenes/animals/cairn.gd")
const FloatLabel := preload("res://scenes/foraging/float_label.gd")

signal exit_opened
signal note_landed
signal note_picked
## The human traveler entered the trigger with the way clear: the black starts.
signal exit_started
## The screen is black and the next scene (`path`) is about to load.
signal exit_handoff(target_id: String, path: String)

var map: Node3D
var ending: Dictionary = {}
var logic
var rng := RandomNumberGenerator.new()
var note_node: Node3D
var note_spot_source := ""
var exit_open := false
var exit_state := ""


func setup(owner_map: Node3D, ending_config: Dictionary, seed_value: int) -> void:
	name = "ExitFlow"
	map = owner_map
	ending = ending_config
	logic = Ending.new(ending_config)
	rng.seed = seed_value


## The last need is met: the note's pause starts and the trigger goes live. Only once.
func open() -> void:
	if exit_open:
		return
	exit_open = true
	logic.begin_wait()
	exit_opened.emit()


## The exit trigger over (x, z) (on the trail behind the cairn).
func trigger_rect() -> Rect2:
	return Cairn.trigger_rect(map.config)


## True while the exit's clocks stand still: a panel or view is open, or the scene is dying.
func frozen() -> bool:
	return map.exit_frozen()


## One tick: the fade once the exit is entered, else the trigger, the note's pause and flight.
func tick(delta: float) -> void:
	if exit_state == "fading":
		var done: bool = logic.tick_fade(delta)
		map.ending_hud.set_alpha(1.0 if done else logic.fade_alpha())
		if done:
			_faded()
		return
	if not exit_open or exit_state != "" or frozen():
		return
	var spot := Vector2(map.player.global_position.x, map.player.global_position.z)
	if trigger_rect().has_point(spot) and map.try_leave():  # nobody downed: leave; else the note shows and nothing else happens
		_begin_exit()
		return
	match logic.phase:
		Ending.WAITING:
			if logic.tick_wait(delta):
				_launch_note()
		Ending.FLYING:
			_fly_note(delta, spot)


## The human traveler is in the trigger: input stops, the screen goes black, and what they
## carry is kept for the next scene.
func _begin_exit() -> void:
	exit_state = "fading"
	map.picking.cancel_walk()
	logic.begin_fade()
	GameState.store_pending_bank(logic.next_id())
	exit_started.emit()


## The screen is black: hand over to the next scene, or hold if it is not built.
func _faded() -> void:
	map.ending_hud.set_alpha(1.0)
	var target: String = logic.next_id()
	var path: String = logic.scene_path(target)
	if path == "":
		exit_state = "hold"
		map.ending_hud.show_line(logic.hold_text(target))
		return
	exit_state = "handed_off"
	exit_handoff.emit(target, path)
	if get_tree().current_scene == map:
		get_tree().change_scene_to_file(path)


## True if the note may lie at (x, z): inside the walk limits and clear of the edges, the
## cairn, the lake and every bottle or tool lying about (data: ending.note.clear_*).
func note_spot_ok(spot: Vector2) -> bool:
	var paper: Dictionary = ending["note"]
	if not map.walk_bounds().grow(-float(paper["clear_edge"])).has_point(spot):
		return false
	if spot.distance_to(Cairn.center(map.config)) < float(paper["clear_cairn"]):
		return false
	var clear_lake := float(paper["clear_lake"])
	if spot.distance_to(map.lake_center) < map.lake_radius + clear_lake and spot.y <= map.lake_center.y + clear_lake:
		return false
	var apart := float(paper["clear_pile"])
	for index in map.pickup_nodes:
		var node: Node3D = map.pickup_nodes[index]
		if node.visible and Vector2(node.global_position.x, node.global_position.z).distance_to(spot) < apart:
			return false
	return true


func _ground_at(spot: Vector2) -> Vector3:
	return Vector3(spot.x, map.terrain.height_at(spot.x), spot.y)


## The pause is over: picks the landing spot near the human traveler and sends the note in
## from off the right edge of the view.
func _launch_note() -> void:
	var paper: Dictionary = ending["note"]
	var origin := Vector2(map.player.global_position.x, map.player.global_position.z)
	var chosen: Dictionary = _choose_spot(origin)
	if note_spot_source == "none valid":
		push_warning("No clear ground for the exit note within reach of the traveler; it lands in the open")
	var spot: Vector2 = chosen["spot"]
	var start := _ground_at(spot)
	start.x = maxf(map.camera.global_position.x + map.camera_half_width() + float(paper["start_margin"]), spot.x + float(paper["start_margin"]))
	start.y += float(paper["start_height"])
	note_node = ExitNote.new()
	note_node.setup(paper)
	map.add_child(note_node)
	logic.begin_flight(start, _ground_at(spot), spot, rng.randf_range(0.0, TAU))
	_pose_note()


## A landing spot 1.5-3 m from `origin` (Ending.choose_spot). `note_spot_source` says how it went.
func _choose_spot(origin: Vector2) -> Dictionary:
	var chosen: Dictionary = logic.choose_spot(rng, origin, note_spot_ok)
	note_spot_source = String(chosen["source"])
	return chosen


func _pose_note() -> void:
	var pose: Dictionary = logic.pose()
	note_node.global_position = pose["position"]
	note_node.rotation = pose["rotation"]


## One tick of the flight. If the human traveler has walked out of the 1.5-3 m range the note is
## re-aimed from where it is; it lands when its line has been flown and the traveler is in range.
func _fly_note(delta: float, from: Vector2) -> void:
	if not logic.in_range(from, logic.spot):
		_retarget(from)
	var ended: bool = logic.tick_flight(delta)
	_pose_note()
	if not ended:
		return
	if not logic.in_range(from, logic.spot):
		_retarget(from)
		return
	_land_note()


func _retarget(from: Vector2) -> void:
	var chosen: Dictionary = _choose_spot(from)
	logic.retarget(_ground_at(chosen["spot"]), chosen["spot"])


## The note comes to rest flat on the ground and can be picked (nearest-target logic and reach
## ring, as in foraging).
func _land_note() -> void:
	logic.land()
	var spot: Vector2 = logic.spot
	var at := _ground_at(spot)
	at.y += float(ending["note"]["rest_lift"])
	note_node.global_position = at
	note_node.rotation = Vector3(-PI / 2.0, logic.rest_yaw, 0.0)
	map.picking.add_note(spot)
	note_landed.emit()


## Takes the landed note into the backpack (the 수첩) with a floating "+1 note". False if it has not
## landed, is gone already or picks are not allowed.
func pick_note() -> bool:
	var result: Dictionary = map.picking.pick_note(map.picks_allowed())
	if result["result"] == "none":
		return false
	var at: Vector3 = note_node.global_position
	logic.take()
	note_node.get_parent().remove_child(note_node)
	note_node.queue_free()
	note_node = null
	if GameState.inventory.add(String(ending["note"]["item"])):
		FloatLabel.make(map, String(ending["note"]["pickup_text"]), at + Vector3(0.0, 0.5, 0.0), map.float_label_config)
	note_picked.emit()
	return true


## A restart: the note (flying or lying) is gone, the black is lifted and the bank waiting for
## the next scene is thrown away.
func clear() -> void:
	if note_node != null and is_instance_valid(note_node):
		note_node.get_parent().remove_child(note_node)
		note_node.queue_free()
	note_node = null
	map.picking.clear_note()
	logic = Ending.new(ending)
	exit_open = false
	exit_state = ""
	map.ending_hud.set_alpha(0.0)
	map.ending_hud.hide_line()
	GameState.discard_pending_bank()
