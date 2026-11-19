class_name FloorScene
extends Node2D
## A floor, walked room by room (F-011, D-012). Builds one Room at a time and swaps it when the
## player leaves through the opened door. Every decision is read from logic (G6): the player's
## HP and position, and whether the room is cleared. The FloorRun owns the progress (C10-C13).
## Data that fails validation builds nothing (C8).

signal room_entered(room_index: int)
## Forwarded from the FloorRun, which emits it once.
signal floor_cleared(floor_number: int)

const RESET_ACTION: StringName = &"debug_reset"
const NEXT_ROOM_ACTION: StringName = &"debug_next_room"
const ROOM_NAME: StringName = &"Room"
## Later than the room's CombatRunner (priority 0), so each tick is read right after it ran.
const AFTER_RUNNER_PRIORITY: int = 1

@export var floor_data: FloorData
@export var start_room: int = 0
## Null takes the Warrior (Tunables.WARRIOR_PATH).
@export var class_data: ClassData
## Off for scripted runs: commands then come from whoever calls motor.submit().
@export var player_input_enabled: bool = true

var _run: FloorRun
var _room: Room
var _setup_errors: PackedStringArray = []


func _ready() -> void:
	process_physics_priority = AFTER_RUNNER_PRIORITY
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
	if _room == null:
		return
	if _player_hp() <= 0:
		restart_room()  # F-011/AC20: placeholder death rule until F-012.
		return
	if _room.is_cleared() and not _run.is_room_cleared():
		var heal: int = _run.report_room_cleared(_player_hp())
		_room.get_player().motor.get_combat_state().heal(heal)
		_room.open_door()
	if _run.is_exit_reached(_room.get_player().motor.get_position_tiles()):
		if _run.advance(_player_hp()):
			_build_room()


func _unhandled_input(event: InputEvent) -> void:
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


## F-011/AC20: the current room again, fresh sim, full HP.
func restart_room() -> void:
	if _run == null:
		return
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
	# F-011/C6: bodies read their tile from global_position, the nav grid and the exit from the
	# room's own tiles; they only agree when the scene sits at the world origin.
	if not global_transform.is_equal_approx(Transform2D.IDENTITY):
		(
			errors
			. append(
				(
					(
						"origin: the floor scene must sit at the world origin with no rotation or scale, "
						+ "is at %s (rotation %s, scale %s)"
					)
					% [global_position, global_rotation, global_scale]
				)
			)
		)
	for error: String in Tunables.floors.validate():
		errors.append("floor tunables: %s" % error)
	if floor_data == null:
		errors.append("floor_data: not set")
	else:
		errors.append_array(floor_data.validate(Tunables.floors))
	return errors


## Takes the current room away and builds the run's current one with its entry HP. The old one
## leaves the tree at once, so nothing of it can run again, and is freed at the end of the frame.
func _build_room() -> void:
	if _room != null:
		remove_child(_room)
		# F-011 DEV-13: not free(). This runs inside _physics_process, and a node freed during a
		# processing pass can have its address reused by the new room's nodes, which the engine's
		# group call then skips: the new camera never became current (room drawn in the corner).
		_room.queue_free()
	_room = Room.new()
	_room.name = ROOM_NAME
	_room.player_input_enabled = player_input_enabled
	_room.setup(_run.get_room(), _run.get_entry_hp(), class_data)
	add_child(_room)
	room_entered.emit(_run.get_room_index())


func _player_hp() -> int:
	return _room.get_player().motor.get_combat_state().get_hp()


func _on_run_floor_cleared(floor_number: int) -> void:
	floor_cleared.emit(floor_number)
