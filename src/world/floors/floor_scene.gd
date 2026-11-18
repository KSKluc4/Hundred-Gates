class_name FloorScene
extends Node2D
## A floor, walked room by room (F-011, D-012). Builds one Room at a time and swaps it when the
## player leaves through the opened door. Every decision is read from logic (G6): the player's
## HP and position, and whether the room is cleared. The FloorRun owns the progress (C10-C13).
## Data that fails validation builds nothing (C8).

signal room_entered(room_index: int)
## Forwarded from the FloorRun, which emits it once.
signal floor_cleared(floor_number: int)
## F-012/C11: only with `death_restarts_room` off. Emitted once; the floor's flow then stops.
signal player_died
## F-012: the cleared boss room's exit was reached, once. Emitted with either death rule.
signal floor_exited(floor_number: int)

const RESET_ACTION: StringName = &"debug_reset"
const NEXT_ROOM_ACTION: StringName = &"debug_next_room"
const DEBUG_LAYER_PATH: NodePath = ^"DebugLayer"
const ROOM_NAME: StringName = &"Room"
## Later than the room's CombatRunner (priority 0), so each tick is read right after it ran.
const AFTER_RUNNER_PRIORITY: int = 1

@export var floor_data: FloorData
@export var start_room: int = 0
## Null takes the Warrior (Tunables.WARRIOR_PATH).
@export var class_data: ClassData
## Off for scripted runs: commands then come from whoever calls motor.submit().
@export var player_input_enabled: bool = true
## F-012/C11: on is F-011's placeholder (the room starts again). Off, a dead player is reported
## through `player_died` and the floor stops: whoever owns the floor decides what comes next.
@export var death_restarts_room: bool = true
## F-012/C11: off, N and R do nothing. The public skip_room() / restart_room() still work.
@export var debug_keys_enabled: bool = true
## F-012/C11: off hides the debug label's layer.
@export var debug_label_visible: bool = true

var _run: FloorRun
var _room: Room
var _setup_errors: PackedStringArray = []
## F-012: set when the death was reported, or the exit; restart_room() clears both.
var _death_reported: bool = false
var _exit_reported: bool = false


func _ready() -> void:
	process_physics_priority = AFTER_RUNNER_PRIORITY
	(get_node(DEBUG_LAYER_PATH) as CanvasLayer).visible = debug_label_visible  # F-012/C11
	_setup_errors = _collect_setup_errors()
	if not _setup_errors.is_empty():
		for error: String in _setup_errors:
			push_error("FloorScene: %s" % error)
		set_physics_process(false)  # F-011/C8: nothing is built, so nothing steps.
		return
	if class_data == null:
		class_data = load(Tunables.WARRIOR_PATH)  # G5
	_run = FloorRun.new()
	_run.setup(floor_data, Tunables.floors, class_data.max_hp, start_room)
	_run.floor_cleared.connect(_on_run_floor_cleared)
	_build_room()


## F-011/C11: the three steps read the room's logic, in this order, every tick.
func _physics_process(_delta: float) -> void:
	if _room == null or _death_reported:
		return  # F-012/AC14: after a reported death nothing of the flow runs.
	if _player_hp() <= 0:
		# F-012/C5: the death is read first, so a death and a boss kill in one tick is a death.
		if death_restarts_room:
			restart_room()  # F-011/AC20: placeholder death rule.
		else:
			_death_reported = true
			player_died.emit()
		return
	if _room.is_cleared() and not _run.is_room_cleared():
		var heal: int = _run.report_room_cleared(_player_hp())
		_room.get_player().motor.get_combat_state().heal(heal)
		_room.open_door()
	if _run.is_exit_reached(_room.get_player().motor.get_position_tiles()):
		if _run.advance(_player_hp()):
			_build_room()
		elif _is_boss_exit_reached() and not _exit_reported:
			_exit_reported = true  # F-012/AC15: once, however long the player stands there.
			floor_exited.emit(floor_data.floor_number)


func _unhandled_input(event: InputEvent) -> void:
	if not debug_keys_enabled:
		return  # F-012/C11
	if event.is_action_pressed(RESET_ACTION):
		restart_room()
	elif event.is_action_pressed(NEXT_ROOM_ACTION):
		skip_room()


func get_run() -> FloorRun:
	return _run


func get_room() -> Room:
	return _room


## F-011/C8: why nothing was built. Empty when the floor is running.
func get_setup_errors() -> PackedStringArray:
	return _setup_errors


## F-011/AC20: the current room again, fresh sim, full HP. F-012: also lets the floor report a
## death or an exit again.
func restart_room() -> void:
	if _run == null:
		return
	_death_reported = false
	_exit_reported = false
	_run.restart_room()
	_build_room()


## Debug (N): the room counts as cleared, with no heal, and the player moves on carrying the HP
## they have. Does nothing in the last room.
func skip_room() -> void:
	if _run == null or _run.get_room_index() >= floor_data.get_room_count() - 1:
		return
	var hp: int = _player_hp()
	_run.report_room_cleared(hp)  # The heal it returns is dropped on purpose.
	if _run.advance(hp):
		_build_room()


func _collect_setup_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for error: String in Tunables.floors.validate():
		errors.append("floor tunables: %s" % error)
	if floor_data == null:
		errors.append("floor_data: not set")
	else:
		errors.append_array(floor_data.validate(Tunables.floors))
	return errors


## Takes the current room away and builds the run's current one with its entry HP. The old one
## leaves the tree and is freed at once: nothing of it can run again.
func _build_room() -> void:
	if _room != null:
		remove_child(_room)
		_room.free()
	_room = Room.new()
	_room.name = ROOM_NAME
	_room.player_input_enabled = player_input_enabled
	_room.setup(_run.get_room(), _run.get_entry_hp(), class_data)
	add_child(_room)
	room_entered.emit(_run.get_room_index())


## F-012/AC15: the last room, cleared, with the player on an exit tile. The FloorRun already
## answers "cleared and on an exit tile"; advance() has just refused, so this is the last room.
func _is_boss_exit_reached() -> bool:
	return _run.get_room().is_boss_room and _run.is_floor_cleared()


func _player_hp() -> int:
	return _room.get_player().motor.get_combat_state().get_hp()


func _on_run_floor_cleared(floor_number: int) -> void:
	floor_cleared.emit(floor_number)
