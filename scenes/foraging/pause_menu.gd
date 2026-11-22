extends RefCounted
## The pause menu's rules, with no nodes: when it may open, which button has the
## focus, and the restart confirmation. The HUD draws it and calls in; the map
## decides whether it may open (`allowed`) and does the pausing and the restart.
##
## Screens:
##   menu      0 Resume, 1 Restart scene, 2 Settings, 3 Controls, 4 Quit
##   confirm   0 Yes, 1 No          ("Restart? Progress in this scene is lost.")
##   settings  the Settings screen (`sub` is "settings"; its rows are SettingsMenu's)
##   controls  the Controls screen (`sub` is "controls"; its rows are ControlsMenu's)
##   quit      the Quit screen (`sub` is "quit"; Exit to Main Menu / Quit to Desktop, QuitMenu's)
## The focus wraps. A new screen starts on Resume (menu) or on No (confirm, so a
## double tap of the pick key cannot throw the scene away). Leaving a sub screen puts the
## focus back on its entry.

const COUNT := 5
const CONFIRM_COUNT := 2
const RESUME := 0
const RESTART := 1
const SETTINGS := 2
const CONTROLS := 3
const QUIT := 4
## The sub screen each of those entries opens.
const SUBS := {SETTINGS: "settings", CONTROLS: "controls", QUIT: "quit"}
const YES := 0
const NO := 1

var is_open := false
var confirming := false
## "" on the menu and the confirmation, else "settings", "controls" or "quit".
var sub := ""
var focus := RESUME
## How many times Yes was chosen. It is 1 at most: a restart is asked for once.
var restart_requests := 0


## Opens the menu. False if `allowed` is false (the map says so), it is open
## already, or a restart has been asked for.
func open(allowed: bool) -> bool:
	if not allowed or is_open or restart_requests > 0:
		return false
	is_open = true
	confirming = false
	sub = ""
	focus = RESUME
	return true


## Closes it (Resume). False if it was not open.
func close() -> bool:
	if not is_open:
		return false
	is_open = false
	confirming = false
	sub = ""
	focus = RESUME
	return true


## Moves the focus one choice, wrapping: -1 up, +1 down. Does nothing when closed.
func move(step: int) -> void:
	if is_open and sub == "":
		focus = posmod(focus + step, CONFIRM_COUNT if confirming else COUNT)


## Puts the focus on a choice (the mouse is over it). Does nothing when closed.
func focus_on(index: int) -> void:
	if is_open and sub == "" and index >= 0 and index < (CONFIRM_COUNT if confirming else COUNT):
		focus = index


## Presses the focused choice. Returns what happened: "resume" (closed), "ask" (the
## confirmation is up), "restart" (Yes: the caller restarts the scene, once),
## "back" (No: the menu again, on Restart scene) or "" (closed, or already restarting).
func activate() -> String:
	if not is_open or sub != "":
		return ""
	if not confirming:
		if focus == RESUME:
			close()
			return "resume"
		if SUBS.has(focus):
			sub = SUBS[focus]
			return sub
		confirming = true
		focus = NO
		return "ask"
	if focus == YES:
		restart_requests += 1
		is_open = false
		confirming = false
		return "restart"
	confirming = false
	focus = RESTART
	return "back"


## Back from a sub screen to the menu, on its entry. False if none was open.
func leave_sub() -> bool:
	if sub == "":
		return false
	focus = SUBS.find_key(sub)
	sub = ""
	return true


## Esc. Closed: opens the menu if `allowed` ("open"). Open: Resume ("resume"), or
## No on the confirmation ("back"). "" if nothing happened.
func escape(allowed: bool) -> String:
	if not is_open:
		return "open" if open(allowed) else ""
	if sub != "":
		leave_sub()
		return "back"
	if confirming:
		confirming = false
		focus = RESTART
		return "back"
	close()
	return "resume"
