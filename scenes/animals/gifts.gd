extends RefCounted
## The gifts the animals give when their kind's need is met (Prompt 9f; data: animals.gifts and
## animals.dogam), with no nodes. The scene only plays what this decides.
##
## `request(kind, tier)` opens a gift job for the kind. If an animal of the kind is on screen
## (`bind_on_screen`) it delivers now; otherwise the job waits and the next animal of the kind to
## spawn (`on_spawn`) takes it. The animal is held (Crossing.Walker.held), walks to the controlled
## traveler, stops `arrive_m` short of it and runs its plan: timed steps that become effects
## ({"event": "effects", "job", "effects": [...]}) for the scene to play:
##   {"type": "fx", "name", "to"}      a placeholder effect (spit, antler_drop, bow, ...)
##   {"type": "give", "item", "count"} items into the backpack (a tool onto the belt, full uses)
##   {"type": "pickup", "item", "place", "index", "attack", "job"}   an item lying on the map
##   {"type": "take" | "return", "item"}   the weasel's borrowed backpack item
## The ducks hold the gift until Space is pressed near them (`press_space`); the dog stays for
## its pickup (`pickup_taken` says whether taking it starts the attack). An animal that is grabbed
## or killed before it has arrived gives the job back to the next one of the kind; once it has
## begun its act, the rest of the plan is played at once, so a gift is never lost half way.
## Endangered and extinct needs deliver twice (`times_for`): the gift items come twice, the one
## act is played once. The 멧돼지 has no plan, so no job.

const WAITING := "waiting"
const WALKING := "walking"
const ASKING := "asking"
const ACTING := "acting"
const BAIT := "bait"
const DONE := "done"

var config: Dictionary = {}
var crossing
var rng := RandomNumberGenerator.new()
var jobs: Array[Dictionary] = []
## walker id -> "male" | "female" (kinds with male_chance, rolled when they spawn).
var sexes: Dictionary = {}
var _queue: Array[Dictionary] = []
var _next_id := 1


func _init(gifts_config: Dictionary, crossing_ref, seed_value: int) -> void:
	config = gifts_config
	crossing = crossing_ref
	rng.seed = seed_value


func has_gift(kind_id: String) -> bool:
	return (config["kinds"] as Dictionary).has(kind_id)


## How many times the gift items come for a need of a kind of `tier`.
func times_for(tier: String) -> int:
	return int(config["times"].get(tier, 1))


## The plan of a kind for an animal of `sex` ("" if it has none): the kind's data with the sex's
## own entries laid over it.
func plan_of(kind_id: String, sex := "") -> Dictionary:
	if not has_gift(kind_id):
		return {}
	var plan: Dictionary = (config["kinds"][kind_id] as Dictionary).duplicate(true)
	if sex != "" and plan.has(sex):
		plan.merge(plan[sex], true)
	plan.erase("male")
	plan.erase("female")
	return plan


func sex_of(walker) -> String:
	return String(sexes.get(walker.id, ""))


## A need of a `kind_id` animal was met: a new job, or {} if the kind gives nothing.
func request(kind_id: String, tier: String) -> Dictionary:
	if not has_gift(kind_id):
		return {}
	var job := {"id": _next_id, "kind": kind_id, "tier": tier, "times": times_for(tier), "state": WAITING,
			"walker": null, "plan": {}, "t": 0.0, "step": 0, "center": Vector2.ZERO, "taken": "", "start": Vector2.ZERO, "angle": 0.0}
	_next_id += 1
	jobs.append(job)
	return job


func job_by_id(job_id: int) -> Dictionary:
	for job in jobs:
		if int(job["id"]) == job_id:
			return job
	return {}


func waiting_jobs(kind_id: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for job in jobs:
		if job["state"] == WAITING and job["kind"] == kind_id:
			list.append(job)
	return list


## True if some job holds this animal.
func is_bound(walker) -> bool:
	for job in jobs:
		if job["walker"] == walker and job["state"] != DONE:
			return true
	return false


## The animal of the job's kind nearest to `from` that is on screen (inside `view`) and free (not
## held, not running off, not bound to a job); null if none.
func find_on_screen(kind_id: String, view: Rect2, from: Vector2):
	var best = null
	var best_d := INF
	for walker in crossing.alive:
		if walker.kind["id"] != kind_id or walker.held or walker.fled or is_bound(walker):
			continue
		var spot: Vector2 = walker.position()
		if not view.has_point(spot):
			continue
		var d := spot.distance_to(from)
		if d < best_d:
			best = walker
			best_d = d
	return best


## Sends an animal of the job's kind that is on screen, if there is one. True if one was sent.
func bind_on_screen(job: Dictionary, view: Rect2, from: Vector2) -> bool:
	var walker = find_on_screen(String(job["kind"]), view, from)
	if walker == null:
		return false
	_bind(job, walker)
	return true


## A new animal spawned: kinds with a male_chance roll its sex (always, one random number), and a
## waiting job of its kind takes it. True if a job did.
func on_spawn(walker) -> bool:
	var kind_id := String(walker.kind["id"])
	if has_gift(kind_id) and (config["kinds"][kind_id] as Dictionary).has("male_chance"):
		sexes[walker.id] = "male" if rng.randf() < float(config["kinds"][kind_id]["male_chance"]) else "female"
	var waiting := waiting_jobs(kind_id)
	if waiting.is_empty():
		return false
	_bind(waiting[0], walker)
	return true


func _bind(job: Dictionary, walker) -> void:
	job["walker"] = walker
	job["state"] = WALKING
	job["plan"] = plan_of(String(job["kind"]), sex_of(walker))
	job["t"] = 0.0
	job["step"] = 0
	walker.held_pos = walker.position()
	walker.held = true
	if not bool(walker.kind["flies"]):
		walker.altitude = 0.0  # (a duck on the wing comes down: it waddles)


func _unbind(job: Dictionary, events: Array[Dictionary]) -> void:
	var walker = job["walker"]
	job["walker"] = null
	job["state"] = WAITING
	job["step"] = 0
	job["t"] = 0.0
	events.append({"event": "unbound", "job": job})
	if walker != null and crossing.alive.has(walker) and walker.held:
		crossing.release(walker, 1.0)


## One tick. `ctx`: "target" (x, z of the controlled traveler) and "inventory" (Inventory.items(),
## for the weasel). Returns the events: arrive, ask, thanks, effects, leave, unbound.
func tick(delta: float, ctx: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = _queue.duplicate()
	_queue.clear()
	for job in jobs:
		var state := String(job["state"])
		if state == WAITING or state == DONE:
			continue
		var walker = job["walker"]
		var alive: bool = crossing.alive.has(walker)
		match state:
			WALKING, ASKING:
				if not alive or not walker.held:  # grabbed or killed on the way: the next one of the kind
					_unbind(job, events)
				elif state == WALKING:
					_walk(job, delta, ctx, events)
			ACTING:
				if not alive or not walker.held:
					_flush(job, ctx, events)
				else:
					_act(job, delta, ctx, events)
			BAIT:
				job["t"] = float(job["t"]) + delta
				if not alive or not walker.held:
					job["state"] = DONE
				elif float(job["t"]) >= float(job["plan"]["hold_s"]):
					_leave(job, events)
	return events


func _walk(job: Dictionary, delta: float, ctx: Dictionary, events: Array[Dictionary]) -> void:
	var walker = job["walker"]
	var plan: Dictionary = job["plan"]
	var to: Vector2 = ctx["target"]
	var here: Vector2 = walker.held_pos
	var stop := float(plan.get("arrive_m", config["arrive_m"]))
	var gap := here.distance_to(to)
	if gap > stop + 0.001:
		var heading := (to - here).normalized()
		var step := minf(float(walker.kind["speed"]) * float(config["walk_mult"]) * delta, gap - stop)
		here += heading * step
		if not bool(walker.kind["flies"]) and walker.habitat != "lake":
			here = crossing.keep_out_lake(here)
		walker.held_pos = here
		walker.held_heading = heading
		gap = here.distance_to(to)
	if gap <= stop + 0.05:
		walker.held_heading = (to - here).normalized() if gap > 0.000001 else walker.held_heading
		job["center"] = to
		job["start"] = here
		job["angle"] = (here - to).angle()
		job["t"] = 0.0
		job["step"] = 0
		if bool(plan.get("wait_space", false)):
			job["state"] = ASKING
			events.append({"event": "ask", "job": job})
		else:
			job["state"] = ACTING
			events.append({"event": "arrive", "job": job})


## Space near an animal that waits for it: it thanks and the act starts. True if one did.
func press_space(spot: Vector2) -> bool:
	for job in jobs:
		if job["state"] != ASKING:
			continue
		var walker = job["walker"]
		if walker != null and walker.held_pos.distance_to(spot) <= float(job["plan"].get("near_m", 2.0)):
			job["state"] = ACTING
			job["t"] = 0.0
			job["step"] = 0
			_queue.append({"event": "thanks", "job": job})
			return true
	return false


func _act(job: Dictionary, delta: float, ctx: Dictionary, events: Array[Dictionary]) -> void:
	var plan: Dictionary = job["plan"]
	job["t"] = float(job["t"]) + delta
	_play_due(job, float(job["t"]), ctx, events)
	_lap(job)
	if int(job["step"]) >= (plan["steps"] as Array).size() and float(job["t"]) >= float(plan["act_s"]):
		if plan.has("hold_s"):
			job["state"] = BAIT
			job["t"] = 0.0
		else:
			_leave(job, events)


## The steps whose time has come.
func _play_due(job: Dictionary, t: float, ctx: Dictionary, events: Array[Dictionary]) -> void:
	var steps: Array = job["plan"]["steps"]
	while int(job["step"]) < steps.size() and float(steps[int(job["step"])]["at"]) <= t:
		var effects := _effects_of(job, steps[int(job["step"])], ctx)
		job["step"] = int(job["step"]) + 1
		if not effects.is_empty():
			events.append({"event": "effects", "job": job, "effects": effects})


## The animal is gone or was grabbed after it began: the rest of its plan happens now.
func _flush(job: Dictionary, ctx: Dictionary, events: Array[Dictionary]) -> void:
	_play_due(job, INF, ctx, events)
	job["state"] = DONE
	events.append({"event": "leave", "job": job})


func _leave(job: Dictionary, events: Array[Dictionary]) -> void:
	var walker = job["walker"]
	job["state"] = DONE
	if walker != null and crossing.alive.has(walker) and walker.held:
		crossing.release(walker, 1.0)
	events.append({"event": "leave", "job": job})


## The weasel's lap: a circle round the traveler, eased in and out from where it stood.
func _lap(job: Dictionary) -> void:
	var lap: Dictionary = job["plan"].get("lap", {})
	if lap.is_empty():
		return
	var walker = job["walker"]
	var u := clampf((float(job["t"]) - float(lap["start_s"])) / float(lap["seconds"]), 0.0, 1.0)
	if u <= 0.0 or u >= 1.0:
		walker.held_pos = job["start"] if u >= 1.0 else walker.held_pos
		return
	var center: Vector2 = job["center"]
	var angle := float(job["angle"]) + TAU * u
	var ring := center + Vector2(cos(angle), sin(angle)) * float(lap["radius"])
	var ease_in := smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.85, 1.0, u))
	var at: Vector2 = (job["start"] as Vector2).lerp(ring, ease_in)
	if not bool(walker.kind["flies"]):
		at = crossing.keep_out_lake(at)
	walker.held_heading = (at - walker.held_pos).normalized() if at.distance_to(walker.held_pos) > 0.0001 else walker.held_heading
	walker.held_pos = at


func _effects_of(job: Dictionary, step: Dictionary, ctx: Dictionary) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	var times := int(job["times"])
	if step.has("fx"):
		effects.append({"type": "fx", "name": String(step["fx"]), "to": String(step.get("to", ""))})
	if step.has("take"):
		var taken := _pick_takeable(ctx.get("inventory", []))
		if taken != "":
			job["taken"] = taken
			effects.append({"type": "take", "item": taken})
	if step.has("return") and String(job["taken"]) != "":
		effects.append({"type": "return", "item": String(job["taken"])})
		job["taken"] = ""
	if step.has("give"):
		for item in step["give"]:
			effects.append({"type": "give", "item": String(item), "count": times})
	if step.has("pickup"):
		var index := 0
		for copy in times:
			for item in step["pickup"]:
				effects.append({"type": "pickup", "item": String(item), "place": String(step.get("place", "drop")), "index": index,
						"attack": bool(step.get("attack", false)), "job": int(job["id"])})
				index += 1
	return effects


## The item the weasel borrows: one of a random held item kind that may be taken (never a tool,
## the notebook, a note or DDEOK); "" if the backpack holds nothing of the sort.
func _pick_takeable(items: Array) -> String:
	var ids: Array[String] = []
	for entry in items:
		var id := String(entry["id"])
		if (config["takeable_kinds"] as Array).has(String(Content.item(id).get("kind", ""))):
			ids.append(id)
	if ids.is_empty():
		return ""
	return ids[rng.randi_range(0, ids.size() - 1)]


## The dog's pickup was taken: true if its dog is still waiting for it, so the attack starts (and
## the job is over). False for anything else.
func pickup_taken(job_id: int) -> bool:
	var job := job_by_id(job_id)
	if job.is_empty() or job["state"] != BAIT:
		return false
	var walker = job["walker"]
	if walker == null or not crossing.alive.has(walker) or not walker.held:
		return false
	job["state"] = DONE
	return true


## The page and trophy a met need of `kind_id` (a `tier` kind) earns: {"page": note id or "",
## "trophy": item id or ""}, each only if `inventory` holds none of it yet (so once per hike).
## `dogam` is animals.dogam.
static func collection(dogam: Dictionary, kind_id: String, tier: String, inventory) -> Dictionary:
	var found := {"page": "", "trophy": ""}
	if not (dogam["tiers"] as Array).has(tier):
		return found
	var page := String(dogam["pages"].get(kind_id, ""))
	if page != "" and inventory.count(page) < 1:
		found["page"] = page
	var trophy := String(dogam["trophies"].get(kind_id, ""))
	if trophy != "" and inventory.count(trophy) < 1:
		found["trophy"] = trophy
	return found
