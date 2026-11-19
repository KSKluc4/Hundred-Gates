# gdlint:disable=max-public-methods
extends F011SceneTest
## F-012 T3 (AC14-AC16): the floor scene's death and exit signals and its debug switches. The
## default exports keep F-011's behaviour; the F-011 scene tests cover that half of AC14.
## Review round 1 (CR-4): a dead player takes no input and the debug keys do nothing until the
## room is rebuilt.

const WALK_TICKS: int = 60

var _died: int = 0
var _exited: Array[int] = []
var _cleared: Array[int] = []
var _input_at_death: bool = true
var _held_keys: Array[Key] = []


func after_each() -> void:
	_release_held_keys()
	super.after_each()


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


# --- CR-4: a dead player takes no input and the debug keys do nothing, until a rebuild ---


func test_cr4_a_reported_death_turns_the_players_input_off_before_the_signal() -> void:
	await spawn_floor(_floor_of_solo_rooms(1), 0, _no_restart_connect_and_input_on)
	assert_true(player().input_enabled, "the floor was built with the player's own input")
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_eq(_died, 1)
	assert_false(player().input_enabled, "off after the death")
	assert_false(_input_at_death, "and already off when player_died was emitted")


func test_cr4_a_dead_player_does_not_walk_dash_or_attack_with_the_real_input_held() -> void:
	await spawn_floor(_floor_of_solo_rooms(1), 0, _no_restart_connect_and_input_on)
	enemy().logic.set_ai_enabled(false)  # Nobody pushes the body: any motion would be input.
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_eq(_died, 1)
	var start: Vector2 = player().motor.get_position_tiles()
	await _hold_key_between_ticks(KEY_W)
	await _hold_key_between_ticks(KEY_J)  # attack
	await _hold_key_between_ticks(KEY_SPACE)  # dodge
	var seen: Dictionary = await _watch_ticks(WALK_TICKS)
	assert_eq(seen["farthest"], 0.0, "did not walk or dash")
	assert_eq(player().motor.get_position_tiles(), start)
	assert_eq(
		seen["states"], [PlayerMotor.State.IDLE] as Array[int], "never moving, dashing or attacking"
	)
	assert_eq(hp(), 0)


func test_cr4_r_and_n_pressed_after_the_death_change_nothing() -> void:
	await spawn_floor(_floor_of_solo_rooms(2), 0, _no_restart_and_connect)
	var old_room: Room = room()
	var entered: Array[int] = []
	_floor.room_entered.connect(func(index: int) -> void: entered.append(index))
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_eq(_died, 1)
	press_key(KEY_R)
	press_key(KEY_N)
	await run_ticks(WALK_TICKS)
	assert_same(room(), old_room, "the same room object")
	assert_eq(hp(), 0, "still dead: R did not revive")
	assert_eq(entered, [] as Array[int], "no room_entered")
	assert_eq(_floor.get_run().get_room_index(), 0, "N did not move on")
	assert_eq(_died, 1)


func test_cr4_restart_room_called_directly_rebuilds_with_the_input_and_the_keys_back() -> void:
	await spawn_floor(_floor_of_solo_rooms(2), 0, _no_restart_connect_and_input_on)
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_false(player().input_enabled)
	var dead_room: Room = room()
	_floor.restart_room()
	assert_ne(room(), dead_room, "a new room")
	assert_eq(hp(), 100)
	assert_true(player().input_enabled, "the input as the floor was built with it")
	var second_room: Room = room()
	press_key(KEY_R)
	assert_ne(room(), second_room, "and the keys work again")
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_eq(_died, 2, "a second death is reported and silenced the same way")
	assert_false(player().input_enabled)


func test_cr4_with_death_restarts_room_on_nothing_about_the_input_changes() -> void:
	await spawn_floor(_floor_of_solo_rooms(1), 0, _connect_and_input_on)
	var old_room: Room = room()
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_ne(room(), old_room, "F-011's rule: a new room")
	assert_eq(_died, 0)
	assert_true(player().input_enabled, "the new player has its input")
	enemy().logic.set_ai_enabled(false)
	await _hold_key_between_ticks(KEY_W)
	var seen: Dictionary = await _watch_ticks(WALK_TICKS / 2)
	assert_gt(seen["farthest"], 0.0, "the player's own input walks it")
	var before_r: Room = room()
	press_key(KEY_R)
	assert_ne(room(), before_r, "R still restarts")
	assert_true(player().input_enabled)


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
	_input_at_death = true
	scene.player_died.connect(_on_player_died)
	scene.floor_exited.connect(func(number: int) -> void: _exited.append(number))
	scene.floor_cleared.connect(func(number: int) -> void: _cleared.append(number))


func _no_restart_and_connect(scene: FloorScene) -> void:
	scene.death_restarts_room = false
	_connect_signals(scene)


func _keys_off(scene: FloorScene) -> void:
	scene.debug_keys_enabled = false


func _no_restart_connect_and_input_on(scene: FloorScene) -> void:
	scene.player_input_enabled = true
	_no_restart_and_connect(scene)


func _connect_and_input_on(scene: FloorScene) -> void:
	scene.player_input_enabled = true
	_connect_signals(scene)


## With nothing scripted, the way the player's own input is polled: one tick per iteration. The
## farthest the player got from where it started, and the states its motor was in.
func _watch_ticks(ticks: int) -> Dictionary:
	var start: Vector2 = player().motor.get_position_tiles()
	var farthest: float = 0.0
	var states: Array[int] = []
	for _i: int in ticks:
		await get_tree().physics_frame
		var state: int = player().motor.get_state()
		if not states.has(state):
			states.append(state)
		farthest = maxf(farthest, (player().motor.get_position_tiles() - start).length())
	return {"farthest": farthest, "states": states}


## The key goes down between two physics ticks, where the OS delivers it, and stays down until
## after_each(). Both the key and the physical key, as the keyboard sends them.
func _hold_key_between_ticks(key: Key) -> void:
	await get_tree().process_frame
	_send_key(key, true)
	_held_keys.append(key)


func _release_held_keys() -> void:
	for key: Key in _held_keys:
		_send_key(key, false)
	_held_keys.clear()


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _on_player_died() -> void:
	_died += 1
	_input_at_death = player().input_enabled


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
