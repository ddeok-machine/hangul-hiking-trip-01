extends RefCounted
## The animal scene's hidden timer (Prompt 9e; data: animals.scene_timer). No nodes, never shown.
##
## A duration is drawn at scene start from the scene's seed, between min_s and max_s. `tick`
## counts it down while the scene is playing (the caller says so) and returns the events that fell
## inside the tick, each once:
##   "warn1"        warn1_s seconds left: a faint shake and a distant roar
##   "repeat"       every repeat_s after that (while more than warn2_s is left): the same
##   "warn2"        warn2_s left: the shadow sweeps in and the roar is loud (`loud` is true)
##   "repeat_loud"  every repeat_s after warn2, if time is left: a loud roar again
##   "timeout"      0: the scene sends the bear
## Each event is {"event", "loud", "left" (the mark)}; "timeout" is {"event": "timeout", ...}.
## `stop()` ends it for good (all the needs are met). `shadow_edge` is the screen edge the
## shadow sweeps along ("west", "east", "far" or "near"), drawn once from the same seed.

const EDGES: Array[String] = ["west", "east", "far", "near"]

var config: Dictionary = {}
var duration := 0.0
var left := 0.0
var shadow_edge := "west"
var stopped := false
var fired := false

var _marks: Array[Dictionary] = []
var _next := 0


func _init(timer_config: Dictionary, seed_value: int) -> void:
	config = timer_config
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	duration = rng.randf_range(float(config["min_s"]), float(config["max_s"]))
	shadow_edge = EDGES[rng.randi_range(0, EDGES.size() - 1)]
	left = duration
	_marks = marks_for(config, duration)


## The marks (seconds left, event name, loud) of a timer of `total` seconds, latest first. A mark
## at or after the start is left out.
static func marks_for(timer_config: Dictionary, total: float) -> Array[Dictionary]:
	var warn1 := float(timer_config["warn1_s"])
	var warn2 := float(timer_config["warn2_s"])
	var every := maxf(float(timer_config["repeat_s"]), 0.001)
	var out: Array[Dictionary] = []
	out.append({"at": warn1, "event": "warn1", "loud": false})
	var at := warn1 - every
	while at > warn2 + 0.001:
		out.append({"at": at, "event": "repeat", "loud": false})
		at -= every
	out.append({"at": warn2, "event": "warn2", "loud": true})
	at = warn2 - every
	while at > 0.001:
		out.append({"at": at, "event": "repeat_loud", "loud": true})
		at -= every
	var kept: Array[Dictionary] = []
	for mark in out:
		if float(mark["at"]) < total:
			kept.append(mark)
	return kept


## True while it can still fire: not stopped and not run out.
func is_active() -> bool:
	return not stopped and not fired


## Ends it for good: no more events.
func stop() -> void:
	stopped = true


## Seconds counted down so far.
func elapsed() -> float:
	return duration - left


## One tick. Counts down only when `playing`; returns the events that fell inside it.
func tick(delta: float, playing: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not is_active() or not playing:
		return events
	left -= delta
	while _next < _marks.size() and left <= float(_marks[_next]["at"]):
		var mark: Dictionary = _marks[_next]
		events.append({"event": mark["event"], "loud": mark["loud"], "left": mark["at"]})
		_next += 1
	if left <= 0.0:
		left = 0.0
		fired = true
		events.append({"event": "timeout", "loud": true, "left": 0.0})
	return events
