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
var _gate: TownGate = TownGate.new()
var _gate_menu: GateMenu
var _setup_errors: PackedStringArray = []


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


## F-012/C10: while the list is closed, the gate latch reads where the player is after this tick.
## While it is open, check() is not called: the latch stays off until the player has left.
func _physics_process(_delta: float) -> void:
	if _gate_menu.is_open():
		return
	var player: Player = _room.get_player()
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


func get_room() -> Room:
	return _room


func get_gate_menu() -> GateMenu:
	return _gate_menu


## F-012/C9: why nothing was built. Empty when the town is running.
func get_setup_errors() -> PackedStringArray:
	return _setup_errors


func _collect_setup_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
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
	_room.setup(town_room, class_data.max_hp, class_data)
	add_child(_room)
	_room.open_door()


## F-012/C10: the player takes no input while the list is open. With no commands the motor
## decelerates on its own, and a door that doesn't collide lets it drift a few hundredths of a tile.
func _open_gate_menu() -> void:
	_room.get_player().input_enabled = false
	_gate_menu.open(_progress.get_entries())


func _on_menu_entry_chosen(floor_number: int, at_boss: bool) -> void:
	floor_chosen.emit(floor_number, at_boss)  # F-012/C12: input stays off; nothing else here.


## F-012/C10, AC22: back on the walkable tile inside the gate, logic first and then the body, and
## the input back as it was built. The latch re-arms by itself once the player is off the gate.
func _on_menu_closed() -> void:
	var player: Player = _room.get_player()
	var inside: Vector2 = _gate.get_return_position_tiles(player.motor.get_position_tiles())
	player.motor.sync_position(Units.vector_tiles_to_px(inside))
	player.sync_body_from_logic()
	player.input_enabled = player_input_enabled


## F-012/C17, AC24: the one place outside TowerSession that changes progress, and only for a
## debug key: there is no save yet, so reaching floor 3 needs a shortcut.
func _clear_highest_unlocked_floor() -> void:
	var floor_number: int = _progress.get_highest_unlocked()
	_progress.mark_boss_reached(floor_number)
	_progress.mark_floor_cleared(floor_number)
	if _gate_menu.is_open():
		_gate_menu.open(_progress.get_entries())  # The list shown is the list that is true.
