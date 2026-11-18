extends F011SceneTest
## F-012 T3 (AC14-AC16): the floor scene's death and exit signals and its debug switches. The
## default exports keep F-011's behaviour; the F-011 scene tests cover that half of AC14.

const WALK_TICKS: int = 60

var _died: int = 0
var _exited: Array[int] = []
var _cleared: Array[int] = []


func test_ac14_by_default_a_death_restarts_the_room_and_reports_nothing() -> void:
	await spawn_floor(_floor_of_solo_rooms(1), 0, _connect_signals)
	var old_room: Room = room()
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_ne(room(), old_room, "F-011's rule: a new room")
	assert_eq(hp(), 100)
	assert_eq(_died, 0, "player_died is only for death_restarts_room = false")


func test_ac14_a_death_emits_player_died_once_and_leaves_the_room_alone() -> void:
	await spawn_floor(_floor_of_solo_rooms(2), 0, _no_restart_and_connect)
	var old_room: Room = room()
	hit(player().motor, 1000)
	assert_eq(hp(), 0)
	await run_ticks(2)
	assert_eq(_died, 1)
	await run_ticks(WALK_TICKS)
	assert_eq(_died, 1, "once, however long the player stays dead")
	assert_eq(room(), old_room, "the room is not rebuilt")
	assert_true(is_instance_valid(old_room))
	assert_eq(hp(), 0, "nobody refilled the player")
	assert_eq(_floor.get_run().get_room_index(), 0)


func test_ac14_the_room_keeps_simulating_after_the_death() -> void:
	await spawn_floor(_floor_of_solo_rooms(1), 0, _no_restart_and_connect)
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_eq(_died, 1)
	var sim: CombatSim = room().get_runner().get_sim()
	var time_before: float = sim.get_time()
	await run_ticks(WALK_TICKS)
	assert_gt(sim.get_time(), time_before, "the CombatRunner still steps the room")


func test_ac14_after_the_death_no_heal_no_door_no_swap() -> void:
	await spawn_floor(_floor_of_solo_rooms(2), 0, _no_restart_and_connect)
	var old_room: Room = room()
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_eq(_died, 1)
	kill_all()  # The last enemy dies after the player did.
	await run_ticks(5)
	assert_true(room().is_cleared(), "the sim still says cleared")
	assert_false(room().is_door_open(), "no door opening")
	assert_false(_floor.get_run().is_room_cleared(), "the run was told nothing")
	assert_eq(hp(), 0, "no heal")
	put_player_at(Vector2(room().get_room_data().get_exit_tiles()[0]) + Vector2(0.5, 0.5))
	await run_ticks(WALK_TICKS)
	assert_eq(room(), old_room, "no room swap")
	assert_eq(_floor.get_run().get_room_index(), 0)
	assert_eq(_died, 1)


func test_ac14_a_cleared_floor_does_not_exit_after_the_death() -> void:
	await spawn_floor(_floor_of_solo_rooms(1), 1, _no_restart_and_connect)
	kill_all()
	await run_ticks(2)
	assert_true(_floor.get_run().is_floor_cleared())
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_eq(_died, 1)
	_stand_on_exit()
	await run_ticks(WALK_TICKS)
	assert_eq(_exited, [] as Array[int], "the flow stopped with the death")


func test_ac14_restart_room_after_a_death_starts_the_flow_again() -> void:
	await spawn_floor(_floor_of_solo_rooms(2), 0, _no_restart_and_connect)
	var old_room: Room = room()
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_eq(_died, 1)
	_floor.restart_room()
	assert_ne(room(), old_room, "a new room")
	assert_eq(hp(), 100)
	await run_ticks(2)
	kill_all()
	await run_ticks(2)
	assert_true(room().is_door_open(), "the flow works again")
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_eq(_died, 2, "and can report the next death")


func test_ac15_the_cleared_boss_room_exit_emits_floor_exited_once() -> void:
	await spawn_floor(_floor_of_solo_rooms(1, 4), 1, _connect_signals)
	await _clear_and_stand_on_exit_checks(4)


func test_ac15_the_exit_is_reported_with_death_restarts_room_off_too() -> void:
	await spawn_floor(_floor_of_solo_rooms(1, 2), 1, _no_restart_and_connect)
	await _clear_and_stand_on_exit_checks(2)


func test_ac15_walking_out_through_the_opened_door_emits_it() -> void:
	await spawn_floor(_floor_of_solo_rooms(1, 3), 1, _connect_signals)
	kill_all()
	await run_ticks(2)
	put_player_at_door()
	var out: Callable = func() -> bool: return not _exited.is_empty()
	assert_true(await run_until(out, WALK_TICKS * 2, Vector2.RIGHT))
	assert_eq(_exited, [3] as Array[int])


func test_ac15_no_exit_in_an_uncleared_boss_room() -> void:
	await spawn_floor(_floor_of_solo_rooms(1), 1, _connect_signals)
	enemy().logic.set_ai_enabled(false)
	_stand_on_exit()
	await run_ticks(WALK_TICKS)
	assert_false(_floor.get_run().is_room_cleared())
	assert_eq(_exited, [] as Array[int])


func test_ac15_no_exit_in_a_cleared_room_that_is_not_the_boss_room() -> void:
	await spawn_floor(_floor_of_solo_rooms(2), 0, _connect_signals)
	kill_all()
	await run_ticks(2)
	_stand_on_exit()
	await run_ticks(WALK_TICKS)
	assert_eq(_floor.get_run().get_room_index(), 1, "the door took the player to the next room")
	assert_eq(_exited, [] as Array[int], "and that is not leaving the floor")
	assert_false(_floor.get_run().is_floor_cleared())


func test_ac15_restart_room_lets_the_exit_be_reported_again() -> void:
	await spawn_floor(_floor_of_solo_rooms(1, 2), 1, _connect_signals)
	kill_all()
	await run_ticks(2)
	_stand_on_exit()
	await run_ticks(WALK_TICKS)
	assert_eq(_exited, [2] as Array[int])
	_floor.restart_room()
	kill_all()
	await run_ticks(2)
	_stand_on_exit()
	await run_ticks(WALK_TICKS)
	assert_eq(_exited, [2, 2] as Array[int], "a debug restart makes it work again")
	assert_eq(_cleared, [2] as Array[int], "while the floor still announced itself once")


func test_ac16_with_the_debug_keys_off_n_and_r_do_nothing() -> void:
	await spawn_floor(_floor_of_solo_rooms(2), 0, _keys_off)
	var first: int = room().get_instance_id()
	set_hp(40)
	press_key(KEY_N)
	assert_eq(room().get_instance_id(), first, "N did nothing")
	assert_eq(_floor.get_run().get_room_index(), 0)
	press_key(KEY_R)
	assert_eq(room().get_instance_id(), first, "R did nothing")
	assert_eq(hp(), 40, "not restarted: no full HP")


func test_ac16_with_the_debug_keys_on_they_still_work() -> void:
	await spawn_floor(_floor_of_solo_rooms(2))
	var first: int = room().get_instance_id()
	press_key(KEY_N)
	assert_ne(room().get_instance_id(), first)
	assert_eq(_floor.get_run().get_room_index(), 1)


func test_ac16_the_public_methods_work_with_the_keys_off() -> void:
	await spawn_floor(_floor_of_solo_rooms(2), 0, _keys_off)
	_floor.skip_room()
	assert_eq(_floor.get_run().get_room_index(), 1, "skip_room() is not a key")
	var second: int = room().get_instance_id()
	_floor.restart_room()
	assert_ne(room().get_instance_id(), second, "nor is restart_room()")


func test_ac16_with_debug_label_visible_off_the_label_layer_is_hidden() -> void:
	await spawn_floor(
		_floor_of_solo_rooms(1),
		0,
		func(scene: FloorScene) -> void: scene.debug_label_visible = false
	)
	var layer: CanvasLayer = _floor.get_node("DebugLayer")
	assert_false(layer.visible)
	assert_false(
		(_floor.get_node("DebugLayer/FloorDebugLabel") as Label).is_visible_in_tree(),
		"so is the label"
	)


func test_ac16_the_debug_label_is_visible_by_default() -> void:
	await spawn_floor(_floor_of_solo_rooms(1))
	assert_true((_floor.get_node("DebugLayer") as CanvasLayer).visible)
	assert_true((_floor.get_node("DebugLayer/FloorDebugLabel") as Label).is_visible_in_tree())


func test_ac16_the_player_and_the_boss_dying_in_one_tick_is_a_death() -> void:
	await spawn_floor(_floor_of_solo_rooms(1, 5), 1, _no_restart_and_connect)
	hit(player().motor, 1000)
	kill(enemy())  # Both before the next tick.
	await run_ticks(3)
	assert_eq(_died, 1, "the death counts")
	assert_eq(_cleared, [] as Array[int], "floor_cleared was not emitted")
	assert_false(_floor.get_run().is_floor_cleared())
	assert_false(room().is_door_open())
	_stand_on_exit()
	await run_ticks(WALK_TICKS)
	assert_eq(_exited, [] as Array[int])


## Kills the room, stands on the exit, and checks the report is once and only for the exit.
func _clear_and_stand_on_exit_checks(floor_number: int) -> void:
	_stand_on_exit()
	await run_ticks(WALK_TICKS)
	assert_eq(_exited, [] as Array[int], "not before the clear")
	kill_all()
	await run_ticks(2)
	assert_true(_floor.get_run().is_floor_cleared())
	_stand_on_exit()  # The locked door pushed the player out while it held.
	await run_ticks(2)
	assert_eq(_exited, [floor_number] as Array[int], "within the ticks after the kill")
	await run_ticks(WALK_TICKS)
	assert_eq(_exited, [floor_number] as Array[int], "standing there longer emits nothing more")


func _stand_on_exit() -> void:
	put_player_at(Vector2(room().get_room_data().get_exit_tiles()[0]) + Vector2(0.5, 0.5))


func _connect_signals(scene: FloorScene) -> void:
	_died = 0
	_exited = []
	_cleared = []
	scene.player_died.connect(func() -> void: _died += 1)
	scene.floor_exited.connect(func(number: int) -> void: _exited.append(number))
	scene.floor_cleared.connect(func(number: int) -> void: _cleared.append(number))


func _no_restart_and_connect(scene: FloorScene) -> void:
	scene.death_restarts_room = false
	_connect_signals(scene)


func _keys_off(scene: FloorScene) -> void:
	scene.debug_keys_enabled = false


## `solo_rooms` combat rooms of one weak enemy, then the fixture boss room.
func _floor_of_solo_rooms(solo_rooms: int, floor_number: int = 1) -> FloorData:
	var rooms: Array[RoomData] = []
	for index: int in solo_rooms:
		rooms.append(
			FloorFixtures.one_enemy_room(
				StringName("solo_%d" % (index + 1)), StringName("grunt%d" % (index + 1))
			)
		)
	return FloorFixtures.floor_of(rooms, floor_number)
