extends Node
## Gamepad rumble (autoload). rumble() does nothing while the Vibration setting is off. The game
## calls it for exactly three things (scripts/game_state.gd): a traveler taking a hit, going downed
## and being revived. The rumble goes to the controller of the affected player when there is one:
## the controlled traveler is player 1 (controller 0), the other is player 2 (controller 1 if it
## is connected); with no controller connected nothing happens.

## Called as rumble_fn.call(device, weak, strong, seconds). Tests replace it with a counter, so
## that no real rumble is ever sent.
var rumble_fn: Callable = _start_rumble


## `strength` 0..1, `ms` the duration. `device` -1 = controller 0. True if a rumble was sent on.
func rumble(strength: float, ms: int, device := -1) -> bool:
	if not Settings.vibration or strength <= 0.0 or ms <= 0:
		return false
	var target := device if device >= 0 else 0
	rumble_fn.call(target, clampf(strength * 0.5, 0.0, 1.0), clampf(strength, 0.0, 1.0), float(ms) / 1000.0)
	return true


## The controller of a traveler's player.
func device_for(traveler: String) -> int:
	if traveler == GameState.controlled:
		return 0
	return 1 if Input.get_connected_joypads().has(1) else 0


func _start_rumble(device: int, weak: float, strong: float, seconds: float) -> void:
	if Input.get_connected_joypads().has(device):
		Input.start_joy_vibration(device, weak, strong, seconds)
