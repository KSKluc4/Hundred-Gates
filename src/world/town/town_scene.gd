class_name TownScene
extends Node2D
## The town (F-012/C8, C10, D-012): one safe room, built by the same Room as a floor's, whose
## `E` tiles are the tower gate. Walking onto the gate opens the gate menu with the list
## TowerProgress says (C2); a choice is reported through `floor_chosen` and nothing else happens
## here, because whoever owns the town replaces it on its own next tick (C12). Every decision is
## read from logic (G6): the gate latch from the player's position, the list from the progress.
## Data that fails validation builds nothing.

## Once per choice, from the gate menu. The menu has closed and the player's input stays off.
signal floor_chosen(floor_number: int, at_boss: bool)

const NEXT_ROOM_ACTION: StringName = &"debug_next_room"
const ROOM_NAME: StringName = &"Room"
const GATE_MENU_PATH: NodePath = ^"MenuLayer/GateMenu"
## Later than the room's CombatRunner (priority 0), so each tick is read right after it ran.
const AFTER_RUNNER_PRIORITY: int = 1

@export var town_room: RoomData
## Null takes the Warrior (Tunables.WARRIOR_PATH).
@export var class_data: ClassData
## Off for scripted runs: commands then come from whoever calls motor.submit().
@export var player_input_enabled: bool = true
## F-012/C17: on, `debug_next_room` (N) clears the highest unlocked floor.
@export var debug_keys_enabled: bool = true
## Used only when nobody called set_progress().
@export var floor_count: int = 3

var _progress: TowerProgress
var _room: Room
## F-016/C15: what the player fights with, given by the owner (null: the class's own values).
var _sword: SwordData = null
## F-016/C19: `() -> Dictionary` of `{floor_number: text}`, asked on every open of the gate list, so
## the texts are the ones that are true then. Unset: the list opens with no odds.
var _odds_provider: Callable
var _gate: TownGate = TownGate.new()
var _gate_menu: GateMenu
var _setup_errors: PackedStringArray = []
## F-012/C10: the list was closed without a choice and the player's input has not come back yet.
var _input_back_pending: bool = false
var _return_position_tiles: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_physics_priority = AFTER_RUNNER_PRIORITY
	_gate_menu = get_node(GATE_MENU_PATH)
	_setup_errors = _collect_setup_errors()
	if not _setup_errors.is_empty():
		for error: String in _setup_errors:
			push_error("TownScene: %s" % error)
		set_physics_process(false)  # F-012/C9: nothing is built, so nothing steps.
		set_process_unhandled_input(false)
		return
	if class_data == null:
		class_data = load(Tunables.WARRIOR_PATH)  # G5
	if _progress == null:
		_progress = TowerProgress.new()
		_progress.setup(floor_count)
	_gate.setup(town_room)
	_gate_menu.entry_chosen.connect(_on_menu_entry_chosen)
	_gate_menu.closed.connect(_on_menu_closed)
	_build_room()


## F-012/C10. Runs after the room's CombatRunner (priority 1 against 0), so each tick is read and
## corrected right after the runner stepped the player and read the input.
## - Engaged gate: the player goes back on the position they had when it engaged, whatever the
##   runner just did to them (a dash included), and nothing else happens (CR-1). The decision is
##   the gate's own state, not whether the list is open (CR-9).
## - Input pending after a cancel: this tick's runner has already run with the input off, so the
##   key that closed the list is spent (CR-2). The input comes back here, once nothing the player
##   did before the cancel can still move them (a dash, a buffered dash).
func _physics_process(_delta: float) -> void:
	var player: Player = _room.get_player()
	if _gate.is_engaged():
		_put_player_at(player, _gate.get_hold_position_tiles())
		return
	if _input_back_pending:
		_put_player_at(player, _return_position_tiles)
		if _can_move_on_its_own(player):
			return
		_input_back_pending = false
		player.input_enabled = player_input_enabled
	if _gate.check(player.motor.get_position_tiles()):
		_open_gate_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not debug_keys_enabled:
		return  # F-012/C17
	if event.is_action_pressed(NEXT_ROOM_ACTION):
		_clear_highest_unlocked_floor()


## The owner's progress, set before the node enters the tree. Null when the town built nothing.
func set_progress(progress: TowerProgress) -> void:
	_progress = progress


func get_progress() -> TowerProgress:
	return _progress


## F-016/C15: the sword the player fights with (null: the class's own values). Before the node
## enters the tree it is only stored; after, the player on screen takes it at once (max HP follows,
## and never heals). The town has no loot, so this is all of it.
func set_sword(sword: SwordData) -> void:
	_sword = sword
	if _room != null:
		_room.get_player().motor.set_sword(sword, Tunables.items)


## F-016/C19: who says what the gate shows under the list for each floor (`{floor_number: text}`).
## It is asked on every open, the one after debug N included, and this node works nothing out.
func set_odds_provider(provider: Callable) -> void:
	_odds_provider = provider


func get_room() -> Room:
	return _room


func get_gate_menu() -> GateMenu:
	return _gate_menu


## F-012/C9: why nothing was built. Empty when the town is running.
func get_setup_errors() -> PackedStringArray:
	return _setup_errors


func _collect_setup_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	# F-012/C9, F-011/C6: the gate latch reads the player's logic position, which comes from
	# global_position, against the room's own tiles; they only agree at the world origin.
	if not global_transform.is_equal_approx(Transform2D.IDENTITY):
		var message: String = (
			"origin: the town scene must sit at the world origin with no rotation or scale, "
			+ "is at %s (rotation %s, scale %s)"
		)
		errors.append(message % [global_position, global_rotation, global_scale])
	for error: String in Tunables.floors.validate():
		errors.append("floor tunables: %s" % error)
	if town_room == null:
		errors.append("town_room: not set")
		return errors
	for error: String in town_room.validate(Tunables.floors):
		errors.append("town_room: %s" % error)
	if not town_room.is_safe_room:
		errors.append("town_room: must be a safe room")
	return errors


## The way FloorScene builds a room. The gate is the room's door: a town has no enemies, so it is
## cleared from the start and its door opens at once.
func _build_room() -> void:
	_room = Room.new()
	_room.name = ROOM_NAME
	_room.player_input_enabled = player_input_enabled
	var loadout: PlayerLoadout = PlayerLoadout.of(class_data, _sword, Tunables.items)
	_room.setup(town_room, loadout.get_max_hp(), class_data)  # F-016/C15: the sword's max HP.
	_room.set_loadout(_sword, Tunables.items)
	add_child(_room)
	_room.open_door()


## F-012/C10: the gate has engaged (check() said so). The player takes no input and, from the next
## tick on, _physics_process holds them on the position they had.
func _open_gate_menu() -> void:
	_room.get_player().input_enabled = false
	_gate_menu.open(_progress.get_entries(), _gate_odds())


## F-012/C10: a floor was chosen. The gate stays engaged, so the player stays held until whoever
## owns the town replaces it (C12); nothing else here.
func _on_menu_entry_chosen(floor_number: int, at_boss: bool) -> void:
	floor_chosen.emit(floor_number, at_boss)


## F-012/C10, AC22: the gate lets go and the player is back on the walkable tile inside it, logic
## first and then the body. The input is NOT given back here: this runs in the input phase, where
## the key that closed the list is still "just pressed" for the player's own input (Space is
## `ui_accept` and `dodge`, a click is `attack`). _physics_process gives it back (CR-2). The latch
## re-arms by itself once the player is off the gate.
func _on_menu_closed() -> void:
	var player: Player = _room.get_player()
	_gate.release()
	_return_position_tiles = _gate.get_return_position_tiles(player.motor.get_position_tiles())
	_put_player_at(player, _return_position_tiles)
	_input_back_pending = true


## Logic first, then the body from it (F-001/C18's restore path).
func _put_player_at(player: Player, position_tiles: Vector2) -> void:
	player.motor.sync_position(Units.vector_tiles_to_px(position_tiles))
	player.sync_body_from_logic()


## F-012/C10: a dash that was running when the list closed (or one waiting in the buffer) would
## carry the player back through the gate, which has no collision. Held until it is over.
func _can_move_on_its_own(player: Player) -> bool:
	return player.motor.get_state() == PlayerMotor.State.DASHING or player.motor.has_buffered_dash()


## F-012/C17, AC24: the one place outside TowerSession that changes progress, and only for a
## debug key: there is no save yet, so reaching floor 3 needs a shortcut.
func _clear_highest_unlocked_floor() -> void:
	var floor_number: int = _progress.get_highest_unlocked()
	_progress.mark_boss_reached(floor_number)
	_progress.mark_floor_cleared(floor_number)
	if _gate_menu.is_open():
		_gate_menu.open(_progress.get_entries(), _gate_odds())  # The list shown is the list that is true.


## F-016/C19: the odds for the gate list, asked now; none without a provider.
func _gate_odds() -> Dictionary:
	if _odds_provider.is_valid():
		return _odds_provider.call()
	return {}
