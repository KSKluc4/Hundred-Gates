class_name Shell
extends Node
## The node above the game (F-015, C2, C6-C8, C12, C14-C16, C21): the title screen, Start, the pause
## and the resume, the settings, the two confirms, the death screen, and the guard that keeps a menu
## key from acting in the game. It shows what the `ShellFlow` says (C2): when the flow changes state
## it opens the panel with what `ShellMenus` has for that state, or closes it in PLAYING. It keeps
## no variable about which menu is open or where it came from; the one menu variable it has is the
## page of the Equipment menu being shown (F-016/C17: the page is not the flow's, and the entries
## and the body of that menu come from `EquipmentMenu`, not from `ShellMenus`). It decides nothing
## about the game either: the game is built, disabled, enabled and freed here, and everything inside
## it is its own. Where a choice changes the session (leave a floor, confirm a death, equip a sword)
## the game is asked first and the flow or the menu moves only when it said yes (C21): an equip that
## was accepted rewrites the two entries it changed in place (F-015 DEV-11: the panel is never
## rebuilt to change one entry), and a page change is the one thing that opens the Equipment menu
## again.
##
## The shell follows the session by polling, never by a signal (C21): in its own tick, after the
## game's, it sees the death pause and opens the death screen, and while that is up it enables its
## one entry when the session says the delay has passed. It follows in both directions: if
## something other than the entry ended the pause (a direct `confirm_death()`, a restored session),
## the flow leaves DEAD in that tick, through the guard (C21, amended by the lead after T6).
##
## Pausing is `Game.process_mode = PROCESS_MODE_DISABLED` and the 2D physics space inactive, always
## together (`_set_game_running`): with the space still stepping a pause shifts later wall contact
## (C6). `SceneTree.paused` is never touched. Two measured details, both in `_set_game_running`:
## - The game's bodies stay in the space (F-015 code review, fixes A). A disabled node takes its
##   collision objects out of the physics space (the default `DISABLE_MODE_REMOVE`) and puts them
##   back on enable, and that alone shifted a later slide along a side wall, across the seams
##   between the wall bodies (one body per run of wall tiles in a row), by up to 0.004 px for 300
##   and more ticks, after a pause of any length, even none. So at each stop every collision object
##   below the game is set to `DISABLE_MODE_KEEP_ACTIVE` (rooms are rebuilt, so once is not
##   enough); with the space inactive nothing steps all the same.
## - One lag, measured in T5 (DEV-6): when the game is enabled the space comes back one of this
##   node's ticks later, in the tick the game first runs in. The server steps after every node of a
##   tick, so a space switched on in the tick the game is enabled in (a tick the game does not run
##   in) takes one step with nothing moved, and that step alone shifted a later slide along a wall
##   corner by 4e-6 px.
##
## The input guard (C7): a menu choice that leads to PLAYING is made by a key that is also the dash
## (Space, pad A) or by a click that is also the attack, and the player's input reads "just pressed"
## in the first tick that runs after the press. So the game is held back until two of this node's
## own ticks have passed: nothing in the first, the enable in the second (priority 3, after the
## game's 2, so the game's tick of that moment has already passed). Never in the input callback.
## A stopped shell that enters the tree again stops the space again (`_enter_tree`), as one that
## leaves it gives the space back (`_exit_tree`).

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
## mechanism, not a tunable. Measured: a press that arrives between ticks (every real input) is
## "just pressed" in the first tick after it, so one would be enough for it; the second only matters
## for a press posted inside a tick, which is "just pressed" in the tick after the one that is
## running. With 1 that press still dashes (the tests post both kinds).
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
## The physics space the game's world is in, taken on every `_enter_tree` and used everywhere.
var _space: RID
## DEV-6: the game was enabled in the last tick; the space follows in this one.
var _space_follows: bool = false
## C16: how many errors the last Start failed with; 0 after a Start that worked.
var _start_error_count: int = 0
## C7: this node's physics ticks left before the game is enabled; 0 when it is not held back.
var _guard_ticks_left: int = 0
## F-016/C17: the page (0-based) of the Equipment menu on show; meaningful while the flow is in
## EQUIPMENT. Set when that menu opens and on each page change.
var _equipment_page: int = 0

@onready var _dim: ColorRect = get_node(DIM_PATH)
@onready var _menu: MenuPanel = get_node(MENU_PATH)


func _ready() -> void:
	process_physics_priority = AFTER_GAME_PRIORITY
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


## C6: a shell put back in the tree while the game is stopped (leaving it gave the space back) stops
## the space again. The first time there is no game, and nothing is done. The space is read here, on
## every entry, so `_space` and this agree whichever viewport the shell is in.
func _enter_tree() -> void:
	_space = get_viewport().world_2d.space
	if _game != null and _game.process_mode == Node.PROCESS_MODE_DISABLED:
		PhysicsServer2D.space_set_active(_space, false)


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
	_follow_the_session()


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
	if state == ShellFlow.State.TITLE and previous == ShellFlow.State.CONFIRM_QUIT:
		_free_game()  # Before the title is shown: its dim is the opaque one (C15).
	_show_menu(state, previous)
	if _flow.is_game_paused():
		_guard_ticks_left = 0
		_set_game_running(false)


## What a choice means, by its id and where the flow is: `settings`, `confirm` and `cancel` are in
## more than one menu.
func _on_entry_chosen(id: StringName) -> void:
	var state: ShellFlow.State = _flow.get_state()
	match id:
		ShellMenus.START:
			_start_game()
		ShellMenus.QUIT:
			quit_handler.call()
		ShellMenus.RESUME:
			_flow.resume()
		ShellMenus.SETTINGS:
			_flow.open_settings()
		ShellMenus.EQUIPMENT_ID:
			_flow.open_equipment()  # F-016/C17
		ShellMenus.BACK:
			_go_back(state)
		EquipmentMenu.NEXT_ID:
			if state == ShellFlow.State.EQUIPMENT:
				_open_equipment_page(_equipment_page + 1, &"")
		EquipmentMenu.PREVIOUS_ID:
			if state == ShellFlow.State.EQUIPMENT:
				_open_equipment_page(_equipment_page - 1, &"")
		ShellMenus.SHAKE:
			if state == ShellFlow.State.SETTINGS:
				_flip_shake()
		ShellMenus.FULLSCREEN:
			if state == ShellFlow.State.SETTINGS:
				_flip_fullscreen()
		ShellMenus.LEAVE:
			_flow.ask_leave(_is_on_floor())
		ShellMenus.QUIT_TO_TITLE:
			_flow.ask_quit()
		ShellMenus.CONFIRM:
			_confirm(state)
		ShellMenus.CANCEL:
			_flow.cancel_confirm()
		ShellMenus.RETURN:
			_confirm_death(state)
		_:
			var sword_id: StringName = EquipmentMenu.sword_of(id)
			if state == ShellFlow.State.EQUIPMENT and not sword_id.is_empty():
				_equip_sword(sword_id)


## F-016/C17: `Back` is in two menus and means what the state says: the settings close, or the
## Equipment menu does (the flow lands on the pause menu with the focus on the entry that led here).
func _go_back(state: ShellFlow.State) -> void:
	match state:
		ShellFlow.State.SETTINGS:
			_flow.close_settings()
		ShellFlow.State.EQUIPMENT:
			_flow.close_equipment()


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


## C21: the game is asked first, the flow follows only when it said yes; a refusal changes nothing
## and the menu stays. The leave goes through the guard like every way into PLAYING (C7).
func _confirm(state: ShellFlow.State) -> void:
	match state:
		ShellFlow.State.CONFIRM_LEAVE:
			if _game.leave_floor():
				_flow.confirm_leave()
		ShellFlow.State.CONFIRM_QUIT:
			_flow.confirm_quit()


## C21: the death screen's one entry. The session may say no (the entry is disabled meanwhile).
func _confirm_death(state: ShellFlow.State) -> void:
	if state == ShellFlow.State.DEAD and _game.confirm_death():
		_flow.death_confirmed()


## C12, C14: flips the setting, rewrites its entry in place (the focus stays) and saves. The shell
## does not listen to the settings' `changed`: it applies what it changed itself.
func _flip_shake() -> void:
	var settings: GameSettings = UserSettings.settings
	settings.screen_shake_enabled = not settings.screen_shake_enabled
	_menu.set_entry_text(ShellMenus.SHAKE, ShellMenus.shake_text(settings.screen_shake_enabled))
	_save_settings()


## As _flip_shake(), and the window is told once, with the new mode.
func _flip_fullscreen() -> void:
	var settings: GameSettings = UserSettings.settings
	settings.fullscreen = not settings.fullscreen
	_menu.set_entry_text(ShellMenus.FULLSCREEN, ShellMenus.fullscreen_text(settings.fullscreen))
	window_mode_applier.call(_window_mode_of(settings.fullscreen))
	_save_settings()


## C12: nothing is written with an empty path. A failed write is the autoload's warning and changes
## nothing else: the setting stays as it is for this run.
func _save_settings() -> void:
	if not settings_path.is_empty():
		UserSettings.save_to(settings_path)


## F-016/C17: the game is asked to equip the sword; on a yes the entries that changed (the one that
## lost the mark and the one that gained it) are rewritten in place: the panel is not opened again,
## so the focus stays and the choose guard does not restart. On a no nothing changes. The texts are
## `EquipmentMenu`'s, read again from the inventory.
func _equip_sword(sword_id: StringName) -> void:
	if not _game.equip_sword(sword_id):
		return
	for entry: MenuEntry in _equipment_entries(_equipment_page):
		if _menu.get_entry_text(entry.id) != entry.text:
			_menu.set_entry_text(entry.id, entry.text)


## F-016/C17: opens the Equipment menu on `page` (clamped to the pages there are), with the focus on
## `focus_id`, or on the first entry when there is none: the first sword of the page, or `Back` with
## no swords. This is an `open()`: used when the menu is shown and on a page change.
func _open_equipment_page(page: int, focus_id: StringName) -> void:
	var inventory: Inventory = _game.get_session().get_loot().get_inventory()
	_equipment_page = clampi(
		page, 0, EquipmentMenu.page_count(inventory, Tunables.items.equipment_page_size) - 1
	)
	_menu.open(
		ShellMenus.heading(ShellFlow.State.EQUIPMENT),
		EquipmentMenu.body(inventory, _game.can_equip_sword()),
		_equipment_entries(_equipment_page),
		focus_id
	)


## The entries of Equipment page `page` as the game's inventory and the equip rule say now.
func _equipment_entries(page: int) -> Array[MenuEntry]:
	var loot: CharacterLoot = _game.get_session().get_loot()
	return EquipmentMenu.entries(
		loot.get_inventory(),
		loot.get_catalog(),
		_game.class_data,
		Tunables.floors.room_clear_heal_fraction,
		_game.can_equip_sword(),
		page,
		Tunables.items.equipment_page_size
	)


## C21: after the game's own tick (priority 3). In PLAYING, when the game is running and the session
## is in the death pause, the death screen opens in this very tick, with the lines the game fed into
## the HUD in its tick. In DEAD, when the session is no longer in the death pause (something other
## than the entry ended it) the flow leaves DEAD at once; otherwise the entry follows what the
## session says, every tick.
func _follow_the_session() -> void:
	if _game == null:
		return
	var session: TowerSession = _game.get_session()
	match _flow.get_state():
		ShellFlow.State.PLAYING:
			if not is_guarding() and session.get_place() == TowerSession.Place.DEATH_PAUSE:
				_flow.player_died()
		ShellFlow.State.DEAD:
			if session.get_place() != TowerSession.Place.DEATH_PAUSE:
				_flow.death_confirmed()
			else:
				_menu.set_entry_enabled(ShellMenus.RETURN, session.can_confirm_death())


## C15: out of the tree first, freed at the end of the frame, never from a signal of the game. The
## physics space is active again at once.
func _free_game() -> void:
	var old: Game = _game
	_game = null
	_guard_ticks_left = 0
	remove_child(old)
	old.queue_free()
	_set_game_running(true)


## C7: the game stays (or becomes) disabled and is enabled in this node's second tick from now.
func _begin_guard() -> void:
	_set_game_running(false)
	_guard_ticks_left = GUARD_TICKS


## The one place the game and the physics space change together (C6): running, or stopped. Stopped:
## the game's bodies are told to stay in the space, then both stop at once. Running: the game now
## and the space in the next tick (see the header). With no game the space is active at once.
func _set_game_running(running: bool) -> void:
	_space_follows = running and _game != null
	if _game == null:
		PhysicsServer2D.space_set_active(_space, true)
		return
	if not running:
		_keep_bodies_in_space()
	_game.process_mode = Node.PROCESS_MODE_INHERIT if running else Node.PROCESS_MODE_DISABLED
	if not running:
		PhysicsServer2D.space_set_active(_space, false)


## C6: before the game is disabled, every collision object below it is set to stay in the physics
## space (see the header). Done at each stop: the rooms are rebuilt, and a new body has the default.
func _keep_bodies_in_space() -> void:
	for node: Node in _game.find_children("*", "CollisionObject2D", true, false):
		(node as CollisionObject2D).disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE


## Opens the panel with `state`'s menu, having come from `previous`. The title screen has no game
## behind it, so its dim is the opaque one.
func _show_menu(state: ShellFlow.State, previous: ShellFlow.State) -> void:
	if state == ShellFlow.State.EQUIPMENT:
		# F-016/C17: on the page of the equipped sword, the focus on it (the first entry with none).
		var inventory: Inventory = _game.get_session().get_loot().get_inventory()
		var equipped: StringName = inventory.get_equipped_id()
		_open_equipment_page(
			EquipmentMenu.page_of(inventory, equipped, Tunables.items.equipment_page_size),
			EquipmentMenu.sword_entry_id(equipped)
		)
		_dim.color = dim_color
		_dim.visible = true
		return
	var settings: GameSettings = UserSettings.settings
	var location: String = ""
	var kills: String = ""
	var can_confirm_death: bool = false
	if state == ShellFlow.State.DEAD:
		# C5, C21: the HUD's two lines as the game left them in this tick.
		location = _game.get_hud().get_location()
		kills = _game.get_hud().get_kills_text()
		can_confirm_death = _game.get_session().can_confirm_death()
	_menu.open(
		ShellMenus.heading(state),
		ShellMenus.body(state, location, kills, _start_error_count),
		ShellMenus.entries(
			state,
			_is_on_floor(),
			settings.screen_shake_enabled,
			settings.fullscreen,
			can_confirm_death
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


## The game running inside the editor's own window cannot change that window's mode: the setting is
## still flipped and saved, the window is left alone.
func _apply_window_mode(mode: DisplayServer.WindowMode) -> void:
	if Engine.is_embedded_in_editor():
		return
	DisplayServer.window_set_mode(mode)
