class_name ShellFlow
extends RefCounted
## F-015/C2: which menu or screen the game is on. A small state machine and nothing else: it holds
## no nodes and no snapshot (a loaded game starts in PLAYING), and the shell shows what it says.
## Every method acts only from its "From" states: it changes the state, emits state_changed once
## and returns true. From any other state it returns false and changes and emits nothing.

## The previous state is passed so that the menus can work out where the focus goes on the way
## back (F-015/C2, review PR-5) without the shell remembering anything.
signal state_changed(state: State, previous: State)

enum State { TITLE, PLAYING, PAUSED, SETTINGS, CONFIRM_LEAVE, CONFIRM_QUIT, DEAD }

var _state: State = State.TITLE
# Where open_settings() came from: TITLE or PAUSED. Only meaningful while in SETTINGS.
var _settings_origin: State = State.TITLE


func get_state() -> State:
	return _state


## C6: true when the game below the shell must be disabled: the pause menu, its two confirms, and
## the settings when they were opened from the pause menu.
func is_game_paused() -> bool:
	match _state:
		State.PAUSED, State.CONFIRM_LEAVE, State.CONFIRM_QUIT:
			return true
		State.SETTINGS:
			return _settings_origin == State.PAUSED
		_:
			return false


## The state the settings were opened from: TITLE or PAUSED (TITLE before the first time).
func get_settings_origin() -> State:
	return _settings_origin


## TITLE -> PLAYING.
func start_game() -> bool:
	return _go(State.PLAYING, [State.TITLE])


## PLAYING -> PAUSED. `can_pause` is Game.is_pause_allowed(); refused when it is false.
func pause(can_pause: bool) -> bool:
	if not can_pause:
		return false
	return _go(State.PAUSED, [State.PLAYING])


## PAUSED -> PLAYING.
func resume() -> bool:
	return _go(State.PLAYING, [State.PAUSED])


## TITLE or PAUSED -> SETTINGS, remembering which one it was.
func open_settings() -> bool:
	if _state != State.TITLE and _state != State.PAUSED:
		return false
	_settings_origin = _state
	return _go(State.SETTINGS, [_state])


## SETTINGS -> where open_settings() came from.
func close_settings() -> bool:
	return _go(_settings_origin, [State.SETTINGS])


## PAUSED -> CONFIRM_LEAVE. `on_floor` is whether the session is on a floor; refused when false.
func ask_leave(on_floor: bool) -> bool:
	if not on_floor:
		return false
	return _go(State.CONFIRM_LEAVE, [State.PAUSED])


## PAUSED -> CONFIRM_QUIT.
func ask_quit() -> bool:
	return _go(State.CONFIRM_QUIT, [State.PAUSED])


## CONFIRM_LEAVE or CONFIRM_QUIT -> PAUSED.
func cancel_confirm() -> bool:
	return _go(State.PAUSED, [State.CONFIRM_LEAVE, State.CONFIRM_QUIT])


## CONFIRM_LEAVE -> PLAYING.
func confirm_leave() -> bool:
	return _go(State.PLAYING, [State.CONFIRM_LEAVE])


## CONFIRM_QUIT -> TITLE.
func confirm_quit() -> bool:
	return _go(State.TITLE, [State.CONFIRM_QUIT])


## PLAYING -> DEAD.
func player_died() -> bool:
	return _go(State.DEAD, [State.PLAYING])


## DEAD -> PLAYING.
func death_confirmed() -> bool:
	return _go(State.PLAYING, [State.DEAD])


## One step back: resume() in PAUSED, close_settings() in SETTINGS, cancel_confirm() in the two
## confirms. False in TITLE, PLAYING and DEAD (F-015/C8: Escape there does nothing).
func back() -> bool:
	match _state:
		State.PAUSED:
			return resume()
		State.SETTINGS:
			return close_settings()
		State.CONFIRM_LEAVE, State.CONFIRM_QUIT:
			return cancel_confirm()
		_:
			return false


## The one place the state changes, so that every method emits exactly once or not at all.
func _go(target: State, from_states: Array[State]) -> bool:
	if not from_states.has(_state):
		return false
	var previous: State = _state
	_state = target
	state_changed.emit(_state, previous)
	return true
