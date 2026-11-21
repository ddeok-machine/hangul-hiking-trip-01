extends RefCounted
## The predators of the animal scene, with no nodes (data: animals.predators and animals.attacks;
## Prompt 9d). Three jobs, all seeded from one rng:
##
##  HUNTS    A live predator (들개, 멧돼지, 검독수리) rolls hunt_chance once when it reaches its linger
##           spot (the eagle, which does not linger, when it first comes into view). On a yes it
##           picks the nearest live prey within hunt_radius_m and chases it at chase_speed_mult
##           times its speed; the prey flees at flee_speed_mult. A catch takes the prey off the map
##           (its letter is gone with it) and the predator stays eat_s at the kill, then leaves; it
##           gives up after chase_max_s. A traveler is never prey.
##  ATTACKS  One clock (a random gap of gap_min_s..gap_max_s) runs down; once it has, the attack waits
##           for a predator within radius_m of a STANDING traveler. The predator stops, a mark shows
##           the traveler's spot for telegraph_s, then it charges that spot. A traveler within
##           hit_radius_m of the spot at impact is hit (down_chance: downed, else 1..damage_max half
##           hearts); one who moved out is missed. The predator then flees off screen. The equipped
##           tool may block a hit (items.json block_kind / block_cost).
##  CROWS    With the lure item equipped by the controlled traveler, each crow that comes into view
##           rolls dive_chance to dive the same way (1..damage_max, no down roll); the attack clock
##           also runs lure_clock_mult times faster.
##
## A predator being steered is "held" (Crossing.Walker.held): its route stops and this class sets
## its place. `tick()` returns the events the scene turns into gore, hits and nodes:
##   {"event": "hunt_start", "predator", "prey"}
##   {"event": "kill", "predator", "prey", "at": Vector2, "altitude": float, "letter": String}
##   {"event": "hunt_end", "predator", "why": "gave_up" | "gone" | "ate"}
##   {"event": "telegraph", "predator", "traveler": id, "point": Vector2, "crow": bool}
##   {"event": "impact", "predator", "traveler": id, "crow": bool, "hit": bool, "blocked": bool,
##    "cost": int (tool uses a block spends), "down": bool, "damage": int (half hearts, 0 if downed)}

var config: Dictionary = {}
var attacks: Dictionary = {}
var crossing
var rng := RandomNumberGenerator.new()
## Seconds the attack clock has to run (it waits at 0 for a predator).
var attack_left := 0.0
## walker id -> the state of what it is doing: {"walker", "phase", "t", ...}.
var states: Dictionary = {}
## Walker ids that have had their hunt roll, and crows that have come into view.
var rolled: Dictionary = {}
var crow_seen: Dictionary = {}
var kills := 0
var attack_count := 0


## `animals_config` is the animals section, `crossing` the Crossing.
func _init(animals_config: Dictionary, crossing_ref, seed_value: int) -> void:
	config = animals_config["predators"]
	attacks = animals_config["attacks"]
	crossing = crossing_ref
	rng.seed = seed_value
	attack_left = draw_gap()


## A new gap of the attack clock, in seconds.
func draw_gap() -> float:
	return rng.randf_range(float(attacks["gap_min_s"]), float(attacks["gap_max_s"]))


## True if the kind is a predator that hunts and attacks (listed in animals.predators).
func is_predator(kind: Dictionary) -> bool:
	return bool(kind.get("predator", false)) and config.has(String(kind["id"])) and config[String(kind["id"])] is Dictionary


## The kind ids a predator kind hunts ([] for any other kind).
func prey_of(kind_id: String) -> Array:
	var entry = config.get(kind_id, null)
	return (entry as Dictionary).get("prey", []) if entry is Dictionary else []


## True if `predator_kind` hunts `prey_kind`. Never a traveler, never a predator not listed.
func is_prey(predator_kind: Dictionary, prey_kind: Dictionary) -> bool:
	return prey_of(String(predator_kind["id"])).has(String(prey_kind["id"]))


## True while the walker is on a hunt or an attack.
func busy(walker) -> bool:
	return states.has(walker.id)


## The state's phase ("chase", "eat", "telegraph", "charge") or "".
func phase_of(walker) -> String:
	return String(states[walker.id]["phase"]) if states.has(walker.id) else ""


## The attack marks to show: [{"walker", "point": Vector2, "progress": 0..1 of the telegraph,
## "crow"}] for every predator or crow in its telegraph or charge.
func marks() -> Array:
	var list: Array = []
	for st in states.values():
		if st["phase"] == "telegraph" or st["phase"] == "charge":
			list.append({"walker": st["walker"], "point": st["point"], "progress": clampf(float(st["t"]) / float(attacks["telegraph_s"]), 0.0, 1.0) if st["phase"] == "telegraph" else 1.0, "crow": st["crow"]})
	return list


## One tick. `ctx`: "standing" {traveler id: Vector2} (downed travelers are left out), "controlled"
## (id), "equipped" (the controlled traveler's tool definition, {} if none), "lure" (true if the
## lure item is equipped), "attacks_on" (false freezes the clock and the attacks, e.g. in the
## spelling view or the death beat; hunts go on), "hunts_on" (default true).
func tick(delta: float, ctx: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var attacks_on := bool(ctx.get("attacks_on", true))
	for id in states.keys():
		var st: Dictionary = states[id]
		var walker = st["walker"]
		if not walker.held or not crossing.alive.has(walker):  # grabbed, or gone: not ours any more
			states.erase(id)
			continue
		match String(st["phase"]):
			"chase":
				_tick_chase(st, delta, events)
			"eat":
				st["t"] = float(st["t"]) + delta
				if float(st["t"]) >= float(config["eat_s"]):
					states.erase(id)
					crossing.release(walker, 1.0)
					events.append({"event": "hunt_end", "predator": walker, "why": "ate"})
			"telegraph":
				if attacks_on:
					_tick_telegraph(st, delta)
			"charge":
				if attacks_on:
					_tick_charge(st, delta, ctx, events)
	if bool(ctx.get("hunts_on", true)):
		_roll_hunts(events)
	if attacks_on:
		var rate := float(attacks["lure_clock_mult"]) if bool(ctx.get("lure", false)) else 1.0
		attack_left = maxf(attack_left - delta * rate, 0.0)
		if attack_left <= 0.0:
			_try_attack(ctx, events)
		_roll_crows(ctx, events)
	return events


# ---- Hunts ----

## Walkers that are predators and idle: not steered, not running off.
func _free_predators() -> Array:
	var list: Array = []
	for walker in crossing.alive:
		if is_predator(walker.kind) and not walker.held and not walker.fled and not states.has(walker.id):
			list.append(walker)
	return list


## True once a predator stands at its linger spot (the eagle: once it is in view).
func _at_spot(walker) -> bool:
	if bool(walker.kind["flies"]):
		return crossing.view.has_point(walker.position())
	return walker.stop_dist >= 0.0 and walker.travelled >= walker.stop_dist - 0.001


func _roll_hunts(events: Array[Dictionary]) -> void:
	for walker in _free_predators():
		if rolled.has(walker.id) or not _at_spot(walker):
			continue
		rolled[walker.id] = true
		if rng.randf() >= float(config["hunt_chance"]):
			continue
		var prey = nearest_prey(walker)
		if prey != null:
			begin_hunt(walker, prey, events)


## The nearest live prey of a predator within hunt_radius_m (null if none): of a listed kind,
## not already running off (fled), not already hunted.
func nearest_prey(walker):
	var best = null
	var best_d := INF
	var here: Vector2 = walker.position()
	for other in crossing.alive:
		if other == walker or other.fled or other.held or not is_prey(walker.kind, other.kind) or _is_hunted(other):
			continue
		var d: float = here.distance_to(other.position())
		if d <= float(config["hunt_radius_m"]) and d < best_d:
			best = other
			best_d = d
	return best


func _is_hunted(prey) -> bool:
	for st in states.values():
		if st["phase"] == "chase" and st["prey"] == prey:
			return true
	return false


## Starts a chase: the predator is held where it stands, the prey flees at flee_speed_mult.
func begin_hunt(walker, prey, events: Array[Dictionary]) -> void:
	walker.held_pos = walker.position()
	walker.held = true
	states[walker.id] = {"walker": walker, "phase": "chase", "t": 0.0, "prey": prey}
	crossing.flee(prey, float(config["flee_speed_mult"]))
	events.append({"event": "hunt_start", "predator": walker, "prey": prey})


func _tick_chase(st: Dictionary, delta: float, events: Array[Dictionary]) -> void:
	var walker = st["walker"]
	var prey = st["prey"]
	if not crossing.alive.has(prey):  # it got away (or was taken some other way)
		_end_hunt(st, "gone", events)
		return
	st["t"] = float(st["t"]) + delta
	var here: Vector2 = walker.held_pos
	var goal: Vector2 = prey.position()
	var gap := here.distance_to(goal)
	if gap > float(config["catch_radius_m"]):
		var step := minf(float(walker.kind["speed"]) * float(config["chase_speed_mult"]) * delta, gap)
		var dir := (goal - here).normalized()
		here += dir * step
		if not bool(walker.kind["flies"]):
			here = crossing.keep_out_lake(here)
		walker.held_pos = here
		walker.held_heading = dir
		gap = here.distance_to(goal)
		if bool(walker.kind["flies"]):
			walker.altitude = _dive_altitude(walker, maxf(gap - float(config["catch_radius_m"]), 0.0), prey.altitude)
	if gap <= float(config["catch_radius_m"]):
		_kill(st, events)
	elif float(st["t"]) >= float(config["chase_max_s"]):
		_end_hunt(st, "gave_up", events)


## Height of a diving flyer `gap` metres from its mark: fly_height far away, `floor_alt` at it.
func _dive_altitude(walker, gap: float, floor_alt: float) -> float:
	var top := maxf(walker.fly_height, floor_alt)
	return floor_alt + (top - floor_alt) * clampf(gap / maxf(float(config["dive_m"]), 0.001), 0.0, 1.0)


func _kill(st: Dictionary, events: Array[Dictionary]) -> void:
	var walker = st["walker"]
	var prey = st["prey"]
	var at: Vector2 = prey.position()
	var altitude: float = prey.altitude
	var letter: String = prey.letter
	crossing.remove(prey)
	kills += 1
	st["phase"] = "eat"
	st["t"] = 0.0
	walker.held_pos = at
	events.append({"event": "kill", "predator": walker, "prey": prey, "at": at, "altitude": altitude, "letter": letter})


## The predator lets go: it leaves normally from where it stands.
func _end_hunt(st: Dictionary, why: String, events: Array[Dictionary]) -> void:
	var walker = st["walker"]
	states.erase(walker.id)
	crossing.release(walker, 1.0)
	events.append({"event": "hunt_end", "predator": walker, "why": why})


# ---- Attacks ----

## The standing traveler nearest `from` within radius_m: {"id", "distance"} or {}.
func nearest_target(from: Vector2, standing: Dictionary) -> Dictionary:
	var best := {}
	var best_d := INF
	for id in standing:
		var d: float = from.distance_to(standing[id])
		if d <= float(attacks["radius_m"]) and d < best_d:
			best = {"id": String(id), "distance": d}
			best_d = d
	return best


func _try_attack(ctx: Dictionary, events: Array[Dictionary]) -> void:
	var standing: Dictionary = ctx.get("standing", {})
	var best_walker = null
	var best_target := {}
	for walker in _free_predators():
		var found := nearest_target(walker.position(), standing)
		if found.is_empty():
			continue
		if best_walker == null or float(found["distance"]) < float(best_target["distance"]):
			best_walker = walker
			best_target = found
	if best_walker == null:
		return  # waits
	attack_left = draw_gap()
	attack_count += 1
	begin_attack(best_walker, String(best_target["id"]), standing[best_target["id"]], false, events)


## Stops a predator (or a crow) and marks `point`, the traveler's spot.
func begin_attack(walker, traveler: String, point: Vector2, crow: bool, events: Array[Dictionary]) -> void:
	walker.held_pos = walker.position()
	walker.held = true
	walker.held_heading = (point - walker.held_pos).normalized() if not point.is_equal_approx(walker.held_pos) else walker.held_heading
	states[walker.id] = {"walker": walker, "phase": "telegraph", "t": 0.0, "traveler": traveler, "point": point, "crow": crow}
	events.append({"event": "telegraph", "predator": walker, "traveler": traveler, "point": point, "crow": crow})


func _tick_telegraph(st: Dictionary, delta: float) -> void:
	st["t"] = float(st["t"]) + delta
	if float(st["t"]) >= float(attacks["telegraph_s"]):
		st["phase"] = "charge"
		st["t"] = 0.0


func _charge_speed(st: Dictionary) -> float:
	var walker = st["walker"]
	if bool(st["crow"]):
		return float(attacks["crow"]["charge_speed"])
	return float(config[String(walker.kind["id"])]["charge_speed"])


func _tick_charge(st: Dictionary, delta: float, ctx: Dictionary, events: Array[Dictionary]) -> void:
	var walker = st["walker"]
	st["t"] = float(st["t"]) + delta
	var here: Vector2 = walker.held_pos
	var point: Vector2 = st["point"]
	var gap := here.distance_to(point)
	var step := minf(_charge_speed(st) * delta, gap)
	if gap > 0.000001:
		walker.held_heading = (point - here).normalized()
		here += walker.held_heading * step
		if not bool(walker.kind["flies"]):
			here = crossing.keep_out_lake(here)
		walker.held_pos = here
	gap = here.distance_to(point)
	if bool(walker.kind["flies"]):
		walker.altitude = _dive_altitude(walker, gap, 0.0)
	if gap <= 0.05 or step <= 0.0 or float(st["t"]) >= float(attacks["charge_max_s"]):
		_impact(st, ctx, events)


## The charge lands: hit or miss, block, damage; then the attacker flees.
func _impact(st: Dictionary, ctx: Dictionary, events: Array[Dictionary]) -> void:
	var walker = st["walker"]
	var traveler := String(st["traveler"])
	var crow := bool(st["crow"])
	var standing: Dictionary = ctx.get("standing", {})
	var event := {"event": "impact", "predator": walker, "traveler": traveler, "crow": crow, "hit": false, "blocked": false, "cost": 0, "down": false, "damage": 0}
	var there = standing.get(traveler, null)  # a traveler downed meanwhile is not there to hit
	if there != null and (there as Vector2).distance_to(st["point"]) <= float(attacks["hit_radius_m"]):
		event["hit"] = true
		var tool_def: Dictionary = ctx.get("equipped", {})
		if traveler == String(ctx.get("controlled", "")) and not tool_def.is_empty() and String(tool_def.get("block_kind", "")) == String(walker.kind["id"]):
			event["blocked"] = true
			event["cost"] = maxi(int(tool_def.get("block_cost", 1)), 1)
			var away: Vector2 = (walker.held_pos - (there as Vector2)).normalized()
			if away.is_zero_approx():
				away = Vector2(1.0, 0.0)
			walker.held_pos = crossing.keep_out_lake(walker.held_pos + away * float(attacks["knockback_m"])) if not bool(walker.kind["flies"]) else walker.held_pos + away * float(attacks["knockback_m"])
		elif crow:
			event["damage"] = rng.randi_range(1, int(attacks["crow"]["damage_max"]))
		elif rng.randf() < float(attacks["down_chance"]):
			event["down"] = true
		else:
			event["damage"] = rng.randi_range(1, int(config[String(walker.kind["id"])]["damage_max"]))
	states.erase(walker.id)
	crossing.release(walker, float(attacks["flee_speed_mult"]))
	events.append(event)


# ---- Crows ----

func _roll_crows(ctx: Dictionary, events: Array[Dictionary]) -> void:
	var crow: Dictionary = attacks["crow"]
	var controlled := String(ctx.get("controlled", ""))
	var standing: Dictionary = ctx.get("standing", {})
	for walker in crossing.alive.duplicate():
		if String(walker.kind["id"]) != String(crow["kind"]) or crow_seen.has(walker.id) or not crossing.view.has_point(walker.position()):
			continue
		crow_seen[walker.id] = true
		if not bool(ctx.get("lure", false)) or walker.held or walker.fled or states.has(walker.id) or not standing.has(controlled):
			continue
		if rng.randf() < float(crow["dive_chance"]):
			begin_attack(walker, controlled, standing[controlled], true, events)
