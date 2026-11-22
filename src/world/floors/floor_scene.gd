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
## F-012/AC33: HP gained between fights, positive only.
signal healed(amount: int)
## F-016/C16, C20: swords the player took, by id, in the order taken. Emitted at once where it is
## decided (a tick, leaving a room, Return to town), never empty.
signal loot_taken(sword_ids: Array[StringName])

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
## They also do nothing once a death was reported (C5).
@export var debug_keys_enabled: bool = true
## F-012/C11: off hides the debug label's layer.
@export var debug_label_visible: bool = true

var _run: FloorRun
var _room: Room
## F-016/C15: what the player fights with, given by the owner (null: the class's own values).
var _sword: SwordData = null
## F-016/C9: the character's loot, given by the owner. Null: a floor without loot.
var _character_loot: CharacterLoot = null
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
	var loadout: PlayerLoadout = _make_loadout()
	_run = FloorRun.new()
	_run.setup(floor_data, Tunables.floors, loadout.get_max_hp(), start_room)
	_run.set_loadout_values(loadout.get_max_hp(), loadout.get_room_heal_bonus())  # F-016/C15
	_run.floor_cleared.connect(_on_run_floor_cleared)
	_build_room()


## F-011/C11: the three steps read the room's logic, in this order, every tick.
func _physics_process(_delta: float) -> void:
	if _room == null or _death_reported:
		return  # F-012/AC14: after a reported death nothing of the flow runs.
	_report_taken()  # F-016/C20: what this tick's steps took, read before anything else.
	if _player_hp() <= 0:
		# F-012/C5: the death is read first, so a death and a boss kill in one tick is a death.
		if death_restarts_room:
			restart_room()  # F-011/AC20: placeholder death rule.
		else:
			_death_reported = true
			# F-012/C5 (CR-4): a dead player takes no input. A rebuilt room has it as built.
			_room.get_player().input_enabled = false
			player_died.emit()
		return
	if _room.is_cleared() and not _run.is_room_cleared():
		var heal: int = _run.report_room_cleared(_player_hp())
		var healed_now: int = _room.get_player().motor.get_combat_state().heal(heal)
		_room.open_door()
		_report_healed(healed_now)  # F-012/AC33: what heal() really did.
	if _run.is_exit_reached(_room.get_player().motor.get_position_tiles()):
		if not _advance_room(_player_hp()) and _is_boss_exit_reached() and not _exit_reported:
			_exit_reported = true  # F-012/AC15: once, however long the player stands there.
			take_loot_here()  # F-016/C16: the door of the boss room leaves the room too.
			floor_exited.emit(floor_data.floor_number)


func _unhandled_input(event: InputEvent) -> void:
	# F-017/C2: the switch wins over `debug_keys_enabled`.
	if not (DevTools.enabled and debug_keys_enabled) or _death_reported:
		return  # F-012/C11; C5 (CR-4): after the death N and R do nothing either.
	if event.is_action_pressed(RESET_ACTION):
		restart_room()
	elif event.is_action_pressed(NEXT_ROOM_ACTION):
		skip_room()


func get_run() -> FloorRun:
	return _run


## F-016/C15: the character's loot, before the node enters the tree. The floor then makes a RoomLoot
## for every room it builds. Null (the default) is a floor without loot.
func set_loot(character_loot: CharacterLoot) -> void:
	_character_loot = character_loot


## F-016/C15: the sword the player fights with (null: the class's own values). Before the node
## enters the tree it is only stored; after, the player on screen takes it at once and the run's max
## HP and heal bonus follow (the entry HP is clamped down, never raised). Rooms built later get it
## before their entry HP is applied.
func set_sword(sword: SwordData) -> void:
	_sword = sword
	if _run == null or _room == null:
		return
	_room.get_player().motor.set_sword(sword, Tunables.items)
	var loadout: PlayerLoadout = _make_loadout()
	_run.set_loadout_values(loadout.get_max_hp(), loadout.get_room_heal_bonus())


## F-016/C16: takes what lies in the room whatever the player's place, and reports it. Nothing is
## taken when the player is dead. Whoever leaves the room calls this before it is freed.
func take_loot_here() -> void:
	if _room == null or _room.get_loot() == null:
		return
	_room.get_loot().take_all()
	_report_taken()


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
	_advance_room(hp)


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
		# F-011 DEV-13: not free(). This runs inside a processing pass (_physics_process) or an
		# input callback (N, R), and a node freed there can have its address reused by the new
		# room's nodes, which the engine's group call then skips: the new camera never became
		# current (room drawn in the corner).
		_room.queue_free()
	_room = Room.new()
	_room.name = ROOM_NAME
	_room.player_input_enabled = player_input_enabled
	_room.setup(_run.get_room(), _run.get_entry_hp(), class_data)
	_room.set_loadout(_sword, Tunables.items)  # F-016/C15: before the entry HP is applied.
	_room.set_loot(_make_room_loot())
	add_child(_room)
	room_entered.emit(_run.get_room_index())


## Moves the run on with the HP the player carries and builds the room it lands in. F-012/AC33: a
## room entered with more HP than was carried (the boss room's refill, FloorRun's entry HP) reports
## the difference, once the new room stands.
func _advance_room(carried_hp: int) -> bool:
	if not _run.advance(carried_hp):
		return false
	take_loot_here()  # F-016/C16: before the room is freed; the heal banner below is joined to it.
	_build_room()
	_report_healed(_run.get_entry_hp() - carried_hp)
	return true


## F-012/AC33: positive amounts only; zero (full HP, a boss clear) and below say nothing.
## F-012/CR-21: nor does a floor whose death was reported: a debug skip then carries 0 HP into the
## next room, and that refill is not HP gained between fights.
func _report_healed(amount: int) -> void:
	if amount > 0 and not _death_reported:
		healed.emit(amount)


## F-012/AC15: the last room, cleared, with the player on an exit tile. The FloorRun already
## answers "cleared and on an exit tile"; advance() has just refused, so this is the last room.
func _is_boss_exit_reached() -> bool:
	return _run.get_room().is_boss_room and _run.is_floor_cleared()


## F-016/C15: the class and the sword the player has now, as the four numbers the floor reads.
func _make_loadout() -> PlayerLoadout:
	return PlayerLoadout.of(class_data, _sword, Tunables.items)


## F-016/C9: null with no loot (no character given, or one with no catalog): the room then has none.
func _make_room_loot() -> RoomLoot:
	if _character_loot == null or _character_loot.get_catalog() == null:
		return null
	return _character_loot.make_room_loot(
		floor_data.floor_number, floor_data, _run.get_room_index(), Tunables.items
	)


## F-016/C20: what the room's loot took since the last call, told once.
func _report_taken() -> void:
	if _room == null or _room.get_loot() == null:
		return
	var taken: Array[StringName] = _room.get_loot().pop_taken()
	if not taken.is_empty():
		loot_taken.emit(taken)


func _player_hp() -> int:
	return _room.get_player().motor.get_combat_state().get_hp()


func _on_run_floor_cleared(floor_number: int) -> void:
	floor_cleared.emit(floor_number)
