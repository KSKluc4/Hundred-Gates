class_name Shell
extends Node
## The node above the game (F-015, C2, C6-C8, C14-C16): the title screen, Start, the pause and the
## resume, and the guard that keeps a menu key from acting in the game. It shows what the
## `ShellFlow` says (C2): when the flow changes state it opens the panel with what `ShellMenus` has
## for that state, or closes it in PLAYING. It keeps no variable about which menu is open or where
## it came from. It decides nothing about the game either: the game is built, disabled and enabled
## here, and everything inside it is its own.
##
## Pausing is `Game.process_mode = PROCESS_MODE_DISABLED` and the 2D physics space inactive, always
## together (`_set_game_running`): with the space still stepping a pause shifts later wall contact
## (C6). `SceneTree.paused` is never touched. One lag, measured in T5 (DEV-1): when the game is
## enabled the space comes back one of this node's ticks later, in the tick the game first runs in.
## The server steps after every node of a tick, so a space switched on in the tick the game is
## enabled in (a tick the game does not run in) takes one step with nothing moved, and that step
## alone shifts a later slide along a wall corner by 4e-6 px.
##
## The input guard (C7): a menu choice that leads to PLAYING is made by a key that is also the dash
## (Space, pad A) or by a click that is also the attack, and the player's input reads "just pressed"
## in the first tick that runs after the press. So the game is held back until two of this node's
## own ticks have passed: nothing in the first, the enable in the second (priority 3, after the
## game's 2, so the game's tick of that moment has already passed). Never in the input callback.

## F-015/C17, G5: the game this node builds on Start.
const GAME_SCENE_PATH: String = "res://src/world/game.tscn"
const GAME_SCENE: PackedScene = preload(GAME_SCENE_PATH)
const GAME_NODE_NAME: StringName = &"Game"
const DIM_PATH: NodePath = ^"MenuLayer/Dim"
const MENU_PATH: NodePath = ^"MenuLayer/Menu"
const PAUSE_ACTION: StringName = &"pause"
## C7: after the game's own priority of 2.
const AFTER_GAME_PRIORITY: int = 3
## C7: how many of this node's `_physics_process` calls the game is held back for after a choice
## that leads to PLAYING: the first does nothing, the second enables it. This is the guard's
## mechanism, not a tunable: with 1 the press that chose is still "just pressed" in the game's tick.
const GUARD_TICKS: int = 2

## Null loads the shipped tower (Game does it). Passed on to the game.
@export var tower_data: TowerData
## Passed on to the game.
@export var player_input_enabled: bool = true
## C12: where the settings are read and written. Empty: neither.
@export var settings_path: String = UserSettings.DEFAULT_PATH
## C17: behind a menu over the game, and behind the title screen (opaque).
@export var dim_color: Color = Color(0.0, 0.0, 0.0, 0.6)
@export var title_color: Color = Color(0.0, 0.0, 0.0, 1.0)

## C14: `(mode: DisplayServer.WindowMode) -> void`. Called once in `_ready` with the mode of the
## settings' fullscreen value. Tests set it before the node enters the tree; unset, it is the
## window's.
var window_mode_applier: Callable
## C15: called by Quit on the title screen. Unset, it is `get_tree().quit`.
var quit_handler: Callable

var _flow: ShellFlow = ShellFlow.new()
## Null on the title screen, and after a Start that failed.
var _game: Game
## The physics space the game's world is in, kept for `_exit_tree`.
var _space: RID
## DEV-1: the game was enabled in the last tick; the space follows in this one.
var _space_follows: bool = false
## C16: how many errors the last Start failed with; 0 after a Start that worked.
var _start_error_count: int = 0
## C7: this node's physics ticks left before the game is enabled; 0 when it is not held back.
var _guard_ticks_left: int = 0

@onready var _dim: ColorRect = get_node(DIM_PATH)
@onready var _menu: MenuPanel = get_node(MENU_PATH)


func _ready() -> void:
	process_physics_priority = AFTER_GAME_PRIORITY
	_space = get_viewport().world_2d.space
	if not window_mode_applier.is_valid():
		window_mode_applier = _apply_window_mode
	if not quit_handler.is_valid():
		quit_handler = get_tree().quit
	if not settings_path.is_empty():
		UserSettings.load_from(settings_path)
	window_mode_applier.call(_window_mode_of(UserSettings.settings.fullscreen))
	_menu.entry_chosen.connect(_on_entry_chosen)
	_menu.cancelled.connect(_on_cancelled)
	_flow.state_changed.connect(_on_state_changed)
	_show_menu(_flow.get_state(), _flow.get_state())


func _exit_tree() -> void:
	PhysicsServer2D.space_set_active(_space, true)


func _physics_process(_delta: float) -> void:
	if _space_follows:
		_space_follows = false
		PhysicsServer2D.space_set_active(_space, true)
	if _guard_ticks_left > 0:
		_guard_ticks_left -= 1
		if _guard_ticks_left == 0:
			_set_game_running(true)


## C8: `pause` is this node's alone; the menus handle `ui_cancel` and nothing of `pause`. In PLAYING
## it pauses (refused while guarding, and when the game says no); anywhere else it goes back one
## step, which the flow refuses in TITLE and DEAD. The event is marked handled when the flow acted.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(PAUSE_ACTION):
		return
	var acted: bool = false
	if _flow.get_state() == ShellFlow.State.PLAYING:
		acted = not is_guarding() and _flow.pause(_game.is_pause_allowed())
	else:
		acted = _flow.back()
	if acted:
		get_viewport().set_input_as_handled()


func get_flow() -> ShellFlow:
	return _flow


## Null on the title screen.
func get_game() -> Game:
	return _game


func get_menu() -> MenuPanel:
	return _menu


## C7: true from a choice that leads to PLAYING until the game is enabled.
func is_guarding() -> bool:
	return _guard_ticks_left > 0


## The shell shows what the flow says (C2).
func _on_state_changed(state: ShellFlow.State, previous: ShellFlow.State) -> void:
	if state == ShellFlow.State.PLAYING:
		_menu.close()
		_dim.visible = false
		_begin_guard()
		return
	_show_menu(state, previous)
	if _flow.is_game_paused():
		_guard_ticks_left = 0
		_set_game_running(false)


func _on_entry_chosen(id: StringName) -> void:
	match id:
		ShellMenus.START:
			_start_game()
		ShellMenus.QUIT:
			quit_handler.call()
		ShellMenus.RESUME:
			_flow.resume()


## `ui_cancel` on a menu: one step back, which the flow refuses in TITLE.
func _on_cancelled() -> void:
	_flow.back()


## C16: the game is built first, disabled; the flow moves only for a game that built.
func _start_game() -> void:
	var game: Game = GAME_SCENE.instantiate()
	game.name = GAME_NODE_NAME
	if tower_data != null:
		game.tower_data = tower_data
	game.player_input_enabled = player_input_enabled
	_game = game
	_set_game_running(false)
	add_child(game)
	var errors: PackedStringArray = game.get_setup_errors()
	if not errors.is_empty():
		remove_child(game)
		game.queue_free()
		_game = null
		_set_game_running(true)
		_start_error_count = errors.size()
		_menu.set_body(ShellMenus.body(ShellFlow.State.TITLE, "", "", _start_error_count))
		return
	_start_error_count = 0
	_flow.start_game()


## C7: the game stays (or becomes) disabled and is enabled in this node's second tick from now.
func _begin_guard() -> void:
	_set_game_running(false)
	_guard_ticks_left = GUARD_TICKS


## The one place the game and the physics space change together (C6): running, or stopped. Stopped:
## both at once. Running: the game now and the space in the next tick (see the header). With no game
## the space is active at once.
func _set_game_running(running: bool) -> void:
	_space_follows = running and _game != null
	if _game == null:
		PhysicsServer2D.space_set_active(_space, true)
		return
	_game.process_mode = Node.PROCESS_MODE_INHERIT if running else Node.PROCESS_MODE_DISABLED
	if not running:
		PhysicsServer2D.space_set_active(_space, false)


## Opens the panel with `state`'s menu, having come from `previous`. The title screen has no game
## behind it, so its dim is the opaque one.
func _show_menu(state: ShellFlow.State, previous: ShellFlow.State) -> void:
	var settings: GameSettings = UserSettings.settings
	_menu.open(
		ShellMenus.heading(state),
		ShellMenus.body(state, "", "", _start_error_count),
		ShellMenus.entries(
			state, _is_on_floor(), settings.screen_shake_enabled, settings.fullscreen, false
		),
		ShellMenus.focus(state, previous)
	)
	_dim.color = title_color if _game == null else dim_color
	_dim.visible = true


## Whether the session is on a floor: only then the pause menu offers the way back to town.
func _is_on_floor() -> bool:
	return _game != null and _game.get_session().get_place() == TowerSession.Place.FLOOR


func _window_mode_of(fullscreen: bool) -> DisplayServer.WindowMode:
	return (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _apply_window_mode(mode: DisplayServer.WindowMode) -> void:
	DisplayServer.window_set_mode(mode)
