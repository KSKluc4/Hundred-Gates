# gdlint:disable=max-public-methods
extends F012SceneTest
## F-012 T5 (AC20-AC22, AC24): the town scene. The gate menu's own rules are in test_gate_menu.
## Review round 1: the engaged gate holds the player exactly (CR-1, CR-9) and the key that closes
## the list is spent before the input comes back (CR-2).

const WALK_TICKS: int = 60
## Most a tile moves in one tick at the Warrior's speed (5 tiles/s at 120 ticks/s) is 0.042.
const ONE_TICK_TILES: float = 0.05
const POSITION_TOLERANCE: float = 0.001
## The player walks up from x = 11.5, so the nearest of the gate's tiles (10..13, 0) is x = 11.
const NORTH_RETURN_TILES: Vector2 = Vector2(11.5, 1.5)
## Just inside the gate, on its way in: a dash north from here reaches the gate tile (y < 1) with
## most of the dash still to run.
const DASH_START_TILES: Vector2 = Vector2(11.5, 1.6)
## A dash is 0.15 s, 18 ticks at 120 ticks/s; the margin covers the step rounding.
const DASH_TICKS: int = 22

var _chosen: Array[Vector2i] = []
var _dashes: int = 0


func before_each() -> void:
	super.before_each()
	_chosen = []
	_dashes = 0


# --- AC20: the town is built ---


func test_ac20_the_town_has_walls_the_player_at_p_and_no_enemies() -> void:
	await spawn_town(TowerFixtures.town_room())
	var built: Room = town().get_room()
	assert_eq(town().get_setup_errors(), PackedStringArray(), "no setup errors")
	assert_same(built.get_room_data(), town().town_room)
	assert_eq(built.get_wall_bodies().size(), _wall_runs(town().town_room))
	assert_gt(built.get_wall_bodies().size(), 0)
	assert_eq(player().motor.get_position_tiles(), Vector2(11.5, 10.5), "the P tile's centre")
	assert_eq(player().global_position, Units.vector_tiles_to_px(Vector2(11.5, 10.5)))
	assert_eq(built.get_enemies().size(), 0, "no enemies")
	assert_eq(built.count_living_enemies(), 0)
	assert_true(built.is_cleared(), "so the town is always cleared")


func test_ac20_the_player_starts_at_full_hp_and_is_the_warrior_by_default() -> void:
	await spawn_town(TowerFixtures.town_room())
	var warrior: ClassData = load(Tunables.WARRIOR_PATH)
	assert_eq(town().class_data.resource_path, Tunables.WARRIOR_PATH)
	var state: CombatState = player().motor.get_combat_state()
	assert_eq(state.get_hp(), warrior.max_hp)
	assert_eq(state.get_hp(), state.get_max_hp(), "full")


func test_ac20_another_class_is_used_when_one_is_set() -> void:
	var tough: ClassData = (load(Tunables.WARRIOR_PATH) as ClassData).duplicate()
	tough.max_hp = 140
	await spawn_town(
		TowerFixtures.town_room(), null, func(scene: TownScene) -> void: scene.class_data = tough
	)
	assert_eq(player().motor.get_combat_state().get_hp(), 140, "the class's own max_hp")


func test_ac20_the_runner_has_no_setup_errors_and_steps() -> void:
	await spawn_town(TowerFixtures.town_room())
	var runner: CombatRunner = town().get_room().get_runner()
	assert_eq(runner.get_setup_errors(), PackedStringArray())
	assert_true(runner.is_physics_processing())
	var time_before: float = runner.get_sim().get_time()
	await run_ticks(10)
	assert_gt(runner.get_sim().get_time(), time_before)


func test_ac20_the_gate_body_has_no_collision() -> void:
	await spawn_town(TowerFixtures.town_room())
	var built: Room = town().get_room()
	assert_not_null(built.get_door(), "the gate is the room's door")
	assert_true(built.is_door_open())
	assert_eq(built.get_door().collision_layer, 0)
	assert_true((built.get_door().get_node("CollisionShape2D") as CollisionShape2D).disabled)


func test_ac20_a_scripted_player_walks_around_and_the_walls_hold() -> void:
	await spawn_town(TowerFixtures.town_room())
	var start: Vector2 = player().motor.get_position_tiles()
	await run_ticks(WALK_TICKS, Vector2.RIGHT)
	assert_gt(player().motor.get_position_tiles().x, start.x + 1.0, "it walks")
	assert_almost_eq(player().motor.get_position_tiles().y, start.y, POSITION_TOLERANCE)
	await run_ticks(WALK_TICKS * 6, Vector2.LEFT)
	assert_gt(player().motor.get_position_tiles().x, 1.0, "the west wall stops it")
	assert_lt(player().motor.get_position_tiles().x, 2.0)
	assert_false(menu().is_open(), "nowhere near the gate")


func test_ac20_the_town_is_a_room_the_same_way_a_floor_builds_one() -> void:
	await spawn_town(TowerFixtures.town_room())
	assert_eq(town().get_room().name, &"Room")
	assert_eq(town().get_room().get_parent(), town())
	assert_eq(town().process_physics_priority, 1, "after the room's runner")


func test_ac20_the_player_input_export_reaches_the_player() -> void:
	await spawn_town(TowerFixtures.town_room())
	assert_false(player().input_enabled, "the helper builds with it off")
	await spawn_town(TowerFixtures.town_room(), null, _input_on)
	assert_true(player().input_enabled)


func test_ac20_an_unset_town_room_builds_nothing() -> void:
	await spawn_town(null)
	assert_eq(town().get_setup_errors(), PackedStringArray(["town_room: not set"]))
	assert_push_error("town_room: not set")
	_assert_nothing_built()


func test_ac20_a_town_room_that_is_not_a_safe_room_is_refused() -> void:
	var data: RoomData = TowerFixtures.town_room()
	data.is_safe_room = false
	await spawn_town(data)
	assert_true(_any(town().get_setup_errors(), "town_room: must be a safe room"))
	for error: String in town().get_setup_errors():
		assert_push_error(error)
	_assert_nothing_built()


func test_ac20_a_combat_room_is_refused_as_a_town() -> void:
	await spawn_town(RoomFixtures.valid_room())
	assert_true(
		_any(town().get_setup_errors(), "must be a safe room"), str(town().get_setup_errors())
	)
	for error: String in town().get_setup_errors():
		assert_push_error(error)
	_assert_nothing_built()


func test_ac20_a_town_room_that_fails_validation_builds_nothing_and_logs_each_error() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(TowerFixtures.town_rows(), 11, 10, ".")
	rows = RoomFixtures.with_tile(rows, 5, 2, "#")  # A thin wall as well: two rules, two errors.
	await spawn_town(TowerFixtures.safe_room_with(&"town", rows))
	var errors: PackedStringArray = town().get_setup_errors()
	assert_gt(errors.size(), 1, str(errors))
	assert_true(_any(errors, "town_room: player_start:"), str(errors))
	for error: String in errors:
		assert_push_error(error)
	_assert_nothing_built()


func test_ac20_the_debug_key_and_the_gate_do_nothing_without_a_town() -> void:
	await spawn_town(null)
	assert_push_error("town_room: not set")
	press_key(KEY_N)
	assert_null(town().get_room())
	assert_false(menu().is_open())


# --- AC21: walking onto the gate opens the list ---


func test_ac21_walking_onto_a_gate_tile_opens_the_list_within_one_tick() -> void:
	await spawn_town(TowerFixtures.town_room())
	assert_false(menu().is_open(), "closed until the gate is reached")
	await run_ticks(WALK_TICKS, Vector2.UP)
	assert_false(menu().is_open(), "still in the middle of the town")
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(await run_until(opened, 400, Vector2.UP))
	var y: float = player().motor.get_position_tiles().y
	assert_lt(y, 1.0, "on a gate tile")
	assert_gt(y, 1.0 - ONE_TICK_TILES, "and the list opened on the tick the player got there")


func test_ac21_the_list_is_exactly_the_progress_entries_plus_the_stay_entry() -> void:
	var progress: TowerProgress = _progress(3)
	progress.mark_floor_cleared(1)
	progress.mark_boss_reached(2)
	await spawn_town(TowerFixtures.town_room(), progress)
	await _walk_into_the_gate()
	var entries: Array[TowerEntry] = progress.get_entries()
	assert_eq(entries.size(), 4, "floor 1 twice, floor 2 twice")
	assert_eq(menu().get_entry_count(), entries.size())
	var expected: Array[String] = []
	for entry: TowerEntry in entries:
		expected.append(GateMenu.entry_text(entry))
	expected.append(GateMenu.STAY_TEXT)
	assert_eq(_button_texts(), expected)
	assert_eq(menu().get_focus_index(), 3, "on the last floor entry")


func test_ac21_a_fresh_progress_lists_floor_1_from_the_start_and_the_stay_entry() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3))
	await _walk_into_the_gate()
	assert_eq(_button_texts(), ["Floor 1 — from the start", "Stay in town"] as Array[String])


func test_ac21_the_list_is_read_when_it_opens_not_when_the_town_was_built() -> void:
	var progress: TowerProgress = _progress(3)
	await spawn_town(TowerFixtures.town_room(), progress)
	progress.mark_floor_cleared(1)  # After the town was built.
	await _walk_into_the_gate()
	assert_eq(menu().get_entry_count(), 3, "floor 1 start, floor 1 boss, floor 2 start")


func test_ac21_the_progress_that_was_injected_is_the_one_used() -> void:
	var progress: TowerProgress = _progress(5)
	await spawn_town(TowerFixtures.town_room(), progress)
	assert_same(town().get_progress(), progress)
	progress.mark_floor_cleared(1)
	progress.mark_floor_cleared(2)
	await _walk_into_the_gate()
	assert_eq(menu().get_entry_count(), 5, "its three unlocked floors, two of them with a boss")


func test_ac21_without_injected_progress_the_town_makes_one_with_floor_count_floors() -> void:
	await spawn_town(
		TowerFixtures.town_room(), null, func(scene: TownScene) -> void: scene.floor_count = 5
	)
	var made: TowerProgress = town().get_progress()
	assert_not_null(made)
	assert_eq(made.get_floor_count(), 5)
	assert_eq(made.get_highest_unlocked(), 1, "fresh")
	await spawn_town(TowerFixtures.town_room())
	assert_eq(town().get_progress().get_floor_count(), 3, "the default is 3")


func test_ac21_the_list_opens_on_a_gate_on_each_border() -> void:
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		await spawn_town(TowerFixtures.town_room(&"town", side), _progress(3))
		put_player_at_gate()
		await run_ticks(2)
		assert_false(menu().is_open(), "just inside the gate is not on it: %s" % side)
		var opened: Callable = func() -> bool: return menu().is_open()
		assert_true(await run_until(opened, 200, gate_outward()), "side %s" % side)
		assert_eq(menu().get_entry_count(), 1)
		_assert_player_on_a_gate_tile(side)
		town().queue_free()
		await get_tree().physics_frame


func test_ac21_a_player_who_walked_in_is_held_exactly_where_the_list_opened() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3))
	await _walk_into_the_gate()
	var held: Vector2 = _position_tiles()
	assert_gt(player().motor.get_velocity_tiles().length(), 0.0, "it was still walking")
	assert_eq(await _ticks_off_the(held, WALK_TICKS), 0, "exactly the hold position, every tick")
	assert_false(player().input_enabled, "the player's input is off")
	assert_true(menu().is_open(), "and the list is still there")
	assert_eq(player().motor.get_velocity_tiles(), Vector2.ZERO, "the walk has run out")


func test_ac21_a_player_who_dashed_in_is_held_exactly_where_the_list_opened() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3))
	await _dash_into_the_gate()
	assert_eq(player().motor.get_state(), PlayerMotor.State.DASHING, "the dash is still running")
	var held: Vector2 = _position_tiles()
	assert_gt(held.y, 0.0, "the list opened inside the room")
	assert_lt(held.y, 1.0, "on a gate tile")
	assert_eq(await _ticks_off_the(held, WALK_TICKS), 0, "exactly the hold position, every tick")
	assert_ne(player().motor.get_state(), PlayerMotor.State.DASHING, "the dash has ended")
	assert_eq(player().motor.get_velocity_tiles(), Vector2.ZERO)
	assert_true(menu().is_open())
	assert_eq(menu().get_entry_count(), 1, "the list was opened once")


func test_ac21_the_held_player_never_leaves_the_rooms_grid() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3))
	await _dash_into_the_gate()
	var size: Vector2i = town().get_room().get_room_data().get_size()
	var outside: int = 0
	for _i: int in WALK_TICKS:
		await run_ticks(1, Vector2.UP)
		var at: Vector2 = _position_tiles()
		if at.x < 0.0 or at.y < 0.0 or at.x >= size.x or at.y >= size.y:
			outside += 1
	assert_eq(outside, 0, "ticks with the player outside the grid")


func test_ac21_the_hold_does_not_depend_on_the_list_being_open() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3))
	await _walk_into_the_gate()
	var held: Vector2 = _position_tiles()
	menu().close()  # No signal: the gate's own state decides, not the UI (CR-9).
	assert_eq(await _ticks_off_the(held, WALK_TICKS), 0, "still held")
	assert_false(menu().is_open(), "and the list is not opened again")


func test_ac21_with_the_real_input_on_the_held_key_does_not_walk_the_player_away() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3), _input_on)
	assert_true(player().input_enabled)
	hold_key(KEY_W)
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(await run_until(opened, 400), "the player's own input walked it to the gate")
	assert_false(player().input_enabled, "and the list took the input away")
	var held: Vector2 = _position_tiles()
	assert_eq(await _ticks_off_the(held, WALK_TICKS), 0, "still holding the key: not one step")
	assert_lt(held.y, 1.0, "on the gate row")
	assert_gt(held.y, 0.0, "and not off the map")


func test_ac21_the_debug_key_refreshes_the_list_and_the_player_stays_held() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3))
	await _dash_into_the_gate()
	var held: Vector2 = _position_tiles()
	press_key(KEY_N)
	assert_eq(menu().get_entry_count(), 3, "the list is the true one")
	assert_eq(await _ticks_off_the(held, WALK_TICKS), 0)


# --- AC22: choosing and closing ---


func test_ac22_choosing_an_entry_emits_floor_chosen_once_and_closes_the_list() -> void:
	var progress: TowerProgress = _progress(3)
	progress.mark_boss_reached(1)
	await spawn_town(TowerFixtures.town_room(), progress, _connect_signals)
	await _walk_into_the_gate()
	menu().choose(1)
	assert_eq(_chosen, [Vector2i(1, 1)] as Array[Vector2i], "floor 1, at the boss")
	assert_false(menu().is_open())
	await run_ticks(WALK_TICKS)
	assert_eq(_chosen.size(), 1, "once, however long the player stays")
	assert_false(menu().is_open(), "and the list does not come back")


func test_ac22_choosing_with_the_keys_emits_floor_chosen_once() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3), _connect_signals)
	await _walk_into_the_gate()
	press_action(&"ui_accept")
	assert_eq(_chosen, [Vector2i(1, 0)] as Array[Vector2i])
	assert_false(menu().is_open())


func test_ac22_after_a_choice_the_input_stays_off_and_the_player_is_not_moved() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3), _input_on_and_connect)
	hold_key(KEY_W)
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(await run_until(opened, 400))
	await run_ticks(20)
	var settled: Vector2 = player().motor.get_position_tiles()
	menu().choose(0)
	assert_eq(_chosen, [Vector2i(1, 0)] as Array[Vector2i])
	assert_false(player().input_enabled, "the owner replaces the town: nothing else changes here")
	await run_ticks(WALK_TICKS)
	assert_eq(player().motor.get_position_tiles(), settled, "the held key still walks nobody")
	assert_eq(_chosen.size(), 1)
	assert_true(is_instance_valid(town().get_room()), "the town did not free anything")


func test_ac22_closing_without_a_choice_emits_nothing_and_puts_the_player_inside_the_gate() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3), _connect_signals)
	await _walk_into_the_gate()
	menu().cancel()
	assert_eq(_chosen, [] as Array[Vector2i], "nothing was chosen")
	assert_false(menu().is_open())
	assert_eq(_position_tiles(), NORTH_RETURN_TILES, "the tile inward of the gate tile")
	assert_eq(player().global_position, Units.vector_tiles_to_px(NORTH_RETURN_TILES), "the body")
	assert_eq(player().global_position, player().motor.get_position_px(), "follows the logic")


func test_ac22_ui_cancel_closes_the_list_the_same_way() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3), _connect_signals)
	await _walk_into_the_gate()
	press_action(&"ui_cancel")
	assert_false(menu().is_open())
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_eq(_position_tiles(), NORTH_RETURN_TILES)


func test_ac22_the_stay_entry_closes_the_list_the_same_way() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3), _connect_signals)
	await _walk_into_the_gate()
	press_action(&"ui_down")  # From floor 1, the last floor entry, to the stay entry.
	press_action(&"ui_accept")
	assert_false(menu().is_open())
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_eq(_position_tiles(), NORTH_RETURN_TILES)


func test_ac22_closing_gives_the_input_back_one_tick_later_as_it_was_built() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3), _input_on)
	hold_key(KEY_W)
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(await run_until(opened, 400))
	assert_false(player().input_enabled)
	release_held_keys()
	menu().cancel()
	assert_false(player().input_enabled, "not in the handler, where the closing key is still fresh")
	await run_ticks(1)
	assert_true(player().input_enabled, "back after the next tick: the town was built with it on")
	await spawn_town(TowerFixtures.town_room(), _progress(3))
	await _walk_into_the_gate()
	menu().cancel()
	await run_ticks(2)
	assert_false(player().input_enabled, "a scripted town stays scripted")


func test_ac22_the_scene_runs_after_the_runner_so_the_closing_key_is_spent() -> void:
	await spawn_town(TowerFixtures.town_room())
	var runner: CombatRunner = town().get_room().get_runner()
	assert_lt(runner.process_physics_priority, town().process_physics_priority)
	assert_eq(runner.get_parent(), town().get_room(), "the runner steps with the room's ticks")


func test_ac22_the_player_walks_on_after_closing() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3), _input_on)
	hold_key(KEY_W)
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(await run_until(opened, 400))
	release_held_keys()
	menu().cancel()
	hold_key(KEY_S)
	await run_ticks(WALK_TICKS)
	assert_gt(player().motor.get_position_tiles().y, 2.5, "it walks into the town")


func test_ac22_the_list_does_not_reopen_until_the_player_has_left_and_come_back() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3))
	await _walk_into_the_gate()
	menu().cancel()
	await run_ticks(WALK_TICKS)
	assert_false(menu().is_open(), "standing just inside the gate opens nothing")
	await run_ticks(WALK_TICKS, Vector2.DOWN)
	assert_false(menu().is_open(), "nor does walking away")
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(await run_until(opened, 400, Vector2.UP), "coming back to the gate does")
	assert_eq(menu().get_entry_count(), 1)


func test_ac22_the_latch_rearms_by_itself_once_the_player_is_off_the_gate() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3))
	await _walk_into_the_gate()
	menu().cancel()
	await run_ticks(2)
	assert_false(menu().is_open())
	var on_the_gate: Vector2 = Vector2(TowerFixtures.gate_tiles()[1]) + Vector2(0.5, 0.5)
	put_player_at(on_the_gate)  # Not a walk, but the position is on the gate again.
	await run_ticks(2)
	assert_true(menu().is_open(), "nobody had to re-arm it: the player was off the gate")


func test_ac22_stay_chosen_with_a_real_space_press_does_not_make_the_player_dodge() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3), _input_on_and_connect)
	await _hold_w_into_the_gate()
	await run_ticks(WALK_TICKS)
	player().motor.dash_started.connect(_count_a_dash)
	press_key(KEY_DOWN)  # A real ui_down: from floor 1 to the stay entry.
	assert_eq(menu().get_focus_index(), menu().get_entry_count(), "on 'Stay in town'")
	await hold_key_between_ticks(KEY_SPACE)  # ui_accept and dodge at once.
	assert_false(menu().is_open(), "the list closed")
	assert_false(player().input_enabled, "and the input is not back in the same input phase")
	var off_the_tile: int = 0
	for _i: int in 30:
		await run_ticks(1)
		if _position_tiles() != NORTH_RETURN_TILES:
			off_the_tile += 1
	assert_eq(_dashes, 0, "no dash was started")
	assert_eq(off_the_tile, 0, "the player stood on the return tile throughout")
	assert_eq(player().motor.get_velocity_tiles(), Vector2.ZERO)
	assert_false(menu().is_open(), "the list did not reopen")
	assert_eq(_chosen, [] as Array[Vector2i], "and nothing was chosen")
	assert_true(player().input_enabled, "the input is back")


func test_ac22_a_floor_chosen_with_a_real_space_press_does_not_make_the_player_dodge() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3), _input_on_and_connect)
	await _hold_w_into_the_gate()
	await run_ticks(WALK_TICKS)
	var held: Vector2 = _position_tiles()
	player().motor.dash_started.connect(_count_a_dash)
	await hold_key_between_ticks(KEY_SPACE)  # On floor 1, the only entry.
	assert_eq(_chosen, [Vector2i(1, 0)] as Array[Vector2i], "floor 1 from the start")
	assert_eq(await _ticks_off_the(held, 30), 0, "held until the owner replaces the town")
	assert_eq(_dashes, 0, "no dash was started")
	assert_false(player().input_enabled)
	assert_eq(_chosen.size(), 1)


func test_ac22_closing_during_a_dash_keeps_the_player_on_the_return_tile_until_it_ends() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3), _input_on)
	await _dash_into_the_gate(true)
	assert_eq(player().motor.get_state(), PlayerMotor.State.DASHING, "still running at the cancel")
	release_held_keys()
	menu().cancel()
	assert_eq(_position_tiles(), NORTH_RETURN_TILES)
	var off_the_tile: int = 0
	var input_back_while_dashing: int = 0
	var was_dashing: bool = false
	for _i: int in DASH_TICKS * 2:
		await run_ticks(1)
		if _position_tiles() != NORTH_RETURN_TILES:
			off_the_tile += 1
		var dashing: bool = player().motor.get_state() == PlayerMotor.State.DASHING
		was_dashing = was_dashing or dashing
		if dashing and player().input_enabled:
			input_back_while_dashing += 1
	assert_true(was_dashing, "the dash did run on after the cancel")
	assert_eq(off_the_tile, 0, "on the return tile every tick, the dash notwithstanding")
	assert_eq(input_back_while_dashing, 0, "the input waits for the dash")
	assert_true(player().input_enabled, "and comes back when it has ended")
	assert_ne(player().motor.get_state(), PlayerMotor.State.DASHING)
	assert_false(menu().is_open(), "the list did not reopen")


func test_ac22_a_dash_still_in_the_buffer_does_not_carry_the_player_through_the_gate() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3), _input_on_and_connect)
	await _hold_w_into_the_gate()
	player().motor.dash_started.connect(_count_a_dash)
	player().motor.submit(DashCommand.new())  # Held in place by the gate.
	await run_ticks(1)
	assert_eq(_dashes, 1, "the first dash")
	# Wait until that dash's cooldown is about to end, then press dash again: it is buffered.
	var nearly_ready: Callable = func() -> bool:
		return (
			player().motor.get_cooldown_remaining() < 0.05
			and _dashes == 1
			and player().motor.get_state() != PlayerMotor.State.DASHING
		)
	assert_true(await run_until(nearly_ready, 120), "the cooldown is almost over")
	player().motor.submit(DashCommand.new())
	await run_ticks(1)
	assert_true(player().motor.has_buffered_dash(), "waiting for the cooldown")
	menu().cancel()
	assert_eq(_position_tiles(), NORTH_RETURN_TILES)
	var off_the_tile: int = 0
	for _i: int in DASH_TICKS * 2:
		await run_ticks(1)
		if _position_tiles() != NORTH_RETURN_TILES:
			off_the_tile += 1
	assert_eq(_dashes, 2, "the buffered dash fired while the player was still held")
	assert_eq(off_the_tile, 0, "and went nowhere")
	assert_true(player().input_enabled)


func test_ac22_every_border_returns_the_player_to_the_tile_inward_of_the_gate() -> void:
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		await spawn_town(TowerFixtures.town_room(&"town", side), _progress(3))
		put_player_at_gate()
		var inside: Vector2 = _position_tiles()
		var opened: Callable = func() -> bool: return menu().is_open()
		assert_true(await run_until(opened, 200, gate_outward()), "side %s" % side)
		menu().cancel()
		assert_almost_eq(_position_tiles(), inside, Vector2.ONE * POSITION_TOLERANCE, "%s" % side)
		assert_eq(player().global_position, player().motor.get_position_px(), "%s" % side)
		await run_ticks(WALK_TICKS)
		assert_false(menu().is_open(), "side %s: not again" % side)
		assert_true(
			await run_until(opened, 200, gate_outward()), "side %s: again after a walk" % side
		)
		town().queue_free()
		await get_tree().physics_frame


func test_ac22_the_return_tile_is_the_one_nearest_the_player_on_a_wide_gate() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3))
	put_player_at(Vector2(13.5, 2.0))  # In front of the gate's last tile (13, 0).
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(await run_until(opened, 200, Vector2.UP))
	menu().cancel()
	assert_almost_eq(_position_tiles(), Vector2(13.5, 1.5), Vector2.ONE * POSITION_TOLERANCE)


# --- AC24: the debug key ---


func test_ac24_the_debug_key_clears_the_highest_unlocked_floor() -> void:
	var progress: TowerProgress = _progress(3)
	await spawn_town(TowerFixtures.town_room(), progress)
	press_key(KEY_N)
	assert_true(progress.is_floor_cleared(1))
	assert_true(progress.is_boss_reached(1))
	assert_true(progress.is_floor_unlocked(2))
	assert_false(progress.is_floor_cleared(2))
	press_key(KEY_N)
	assert_true(progress.is_floor_cleared(2), "now floor 2 is the highest unlocked")
	assert_true(progress.is_floor_unlocked(3))
	assert_false(progress.is_floor_cleared(3))


func test_ac24_the_debug_key_on_the_last_floor_clears_it_and_then_does_nothing() -> void:
	var progress: TowerProgress = _progress(2)
	await spawn_town(TowerFixtures.town_room(), progress)
	for _i: int in 4:
		press_key(KEY_N)
	assert_true(progress.is_floor_cleared(1))
	assert_true(progress.is_floor_cleared(2))
	assert_eq(progress.get_highest_unlocked(), 2)
	assert_eq(progress.get_entries().size(), 4)


func test_ac24_with_the_debug_keys_off_the_key_does_nothing() -> void:
	var progress: TowerProgress = _progress(3)
	await spawn_town(
		TowerFixtures.town_room(),
		progress,
		func(scene: TownScene) -> void: scene.debug_keys_enabled = false
	)
	press_key(KEY_N)
	assert_false(progress.is_floor_cleared(1))
	assert_false(progress.is_boss_reached(1))
	assert_eq(progress.get_entries().size(), 1)


func test_ac24_the_key_works_through_the_action_too() -> void:
	var progress: TowerProgress = _progress(3)
	await spawn_town(TowerFixtures.town_room(), progress)
	press_action(&"debug_next_room")
	assert_true(progress.is_floor_cleared(1))


func test_ac24_the_key_reopens_an_open_list_so_it_is_current() -> void:
	var progress: TowerProgress = _progress(3)
	await spawn_town(TowerFixtures.town_room(), progress)
	await _walk_into_the_gate()
	assert_eq(menu().get_entry_count(), 1)
	press_key(KEY_N)
	assert_true(menu().is_open(), "still open")
	assert_eq(menu().get_entry_count(), 3, "floor 1 start, floor 1 boss, floor 2 start")
	assert_eq(_button_texts()[0], "Floor 1 — from the start (cleared)")
	assert_eq(menu().get_focus_index(), 2)
	assert_false(player().input_enabled, "the player is still held")


func test_ac24_the_key_does_not_open_a_closed_list() -> void:
	await spawn_town(TowerFixtures.town_room(), _progress(3))
	press_key(KEY_N)
	assert_false(menu().is_open())


func test_ac24_the_next_list_shows_what_the_key_cleared() -> void:
	var progress: TowerProgress = _progress(3)
	await spawn_town(TowerFixtures.town_room(), progress)
	press_key(KEY_N)
	await _walk_into_the_gate()
	var expected: Array[String] = []
	for entry: TowerEntry in progress.get_entries():
		expected.append(GateMenu.entry_text(entry))
	expected.append(GateMenu.STAY_TEXT)
	assert_eq(_button_texts(), expected)
	assert_eq(menu().get_entry_count(), 3)


# --- helpers ---


func _progress(floors: int) -> TowerProgress:
	var progress: TowerProgress = TowerProgress.new()
	progress.setup(floors)
	return progress


## Walks the scripted player straight north into a gate on the north border, until the list opens.
func _walk_into_the_gate() -> void:
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(await run_until(opened, 400, Vector2.UP), "the player reached the gate")


## Starts just inside the gate and dashes north into it, until the list has opened (the dash is
## then still running, as in a real run). `real_input`: W and Space are real keys, for a town built
## with the player's own input on (its commands would override the scripted ones).
func _dash_into_the_gate(real_input: bool = false) -> void:
	put_player_at(DASH_START_TILES)
	if real_input:
		hold_key(KEY_W)
	await run_ticks(2)
	assert_false(menu().is_open(), "just inside the gate is not on it")
	if real_input:
		await hold_key_between_ticks(KEY_SPACE)
	else:
		await dash_for_one_tick(Vector2.UP)
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(await run_until(opened, DASH_TICKS, Vector2.UP), "the dash reached the gate")


## The real input on: holds W until the list opens, then lets go of it.
func _hold_w_into_the_gate() -> void:
	hold_key(KEY_W)
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(await run_until(opened, 400), "the player's own input walked it to the gate")
	release_held_keys()


## Runs `ticks` ticks (no commands) and counts those that ended anywhere but exactly on `held`,
## in the logic or in the body.
func _ticks_off_the(held: Vector2, ticks: int) -> int:
	var off: int = 0
	for _i: int in ticks:
		await run_ticks(1)
		if _position_tiles() != held or player().global_position != Units.vector_tiles_to_px(held):
			off += 1
	return off


func _count_a_dash() -> void:
	_dashes += 1


func _position_tiles() -> Vector2:
	return player().motor.get_position_tiles()


func _assert_player_on_a_gate_tile(side: Vector2i) -> void:
	var tile: Vector2i = Vector2i(floori(_position_tiles().x), floori(_position_tiles().y))
	assert_true(TowerFixtures.gate_tiles(side).has(tile), "tile %s, side %s" % [tile, side])


func _button_texts() -> Array[String]:
	var texts: Array[String] = []
	for child: Node in menu().get_node("Panel/List").get_children():
		texts.append((child as Button).text)
	return texts


func _assert_nothing_built() -> void:
	assert_null(town().get_room(), "no room")
	assert_false(town().is_physics_processing(), "nothing steps")
	assert_false(menu().is_open())
	var rooms: int = 0
	for child: Node in town().get_children():
		if child is Room:
			rooms += 1
	assert_eq(rooms, 0, "and nothing was added to the tree")


## The horizontal runs of `#`: one wall body each (F-011/AC16).
func _wall_runs(data: RoomData) -> int:
	var runs: int = 0
	for row: String in data.rows:
		var previous_was_wall: bool = false
		for tile_char: String in row:
			var is_wall: bool = tile_char == RoomData.WALL
			if is_wall and not previous_was_wall:
				runs += 1
			previous_was_wall = is_wall
	return runs


func _any(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false


func _input_on(scene: TownScene) -> void:
	scene.player_input_enabled = true


func _connect_signals(scene: TownScene) -> void:
	_chosen = []
	scene.floor_chosen.connect(
		func(floor_number: int, at_boss: bool) -> void:
			_chosen.append(Vector2i(floor_number, 1 if at_boss else 0))
	)


func _input_on_and_connect(scene: TownScene) -> void:
	_input_on(scene)
	_connect_signals(scene)
