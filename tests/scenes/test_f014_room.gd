# gdlint:disable=max-public-methods
extends F011SceneTest
## F-014 T4: a Room with reinforcements, in the real floor scene on fixture floors (never on the
## shipped rooms). The reserve is built after the placed enemies, held in reserve, and sent by
## the director; the room counts kills from the logic; the exit waits for the kill target.
##
## WaveFixtures.wave_room(): 20 x 12, P at (1, 5), a chaser `chaser_1` and a caster `caster_2`
## placed (asleep), reinforcements chaser_3, caster_4, chaser_5, four arrival points.

const ENEMY_LAYER: int = 4
const FIRST_POINT: Vector2 = Vector2(16.5, 3.5)
const RESERVE_IDS: Array[StringName] = [&"chaser_3", &"caster_4", &"chaser_5"]
const KILL_LOOP_LIMIT_TICKS: int = 1500
const SECOND_STEPS: int = 120


func _wave_floor(wave_rooms: int = 1) -> FloorData:
	var rooms: Array[RoomData] = []
	for index: int in wave_rooms:
		rooms.append(WaveFixtures.wave_room(StringName("wave_%d" % (index + 1))))
	return FloorFixtures.floor_of(rooms)


func _ids_of_sim(built: Room) -> Array[StringName]:
	var ids: Array[StringName] = []
	for combatant: Combatant in built.get_runner().get_sim().get_combatants():
		ids.append(combatant.get_combat_id())
	return ids


func _node_ids(nodes: Array[Enemy]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for node: Enemy in nodes:
		ids.append(node.combat_id)
	return ids


func _enemy_named(id: StringName) -> Enemy:
	for node: Enemy in room().get_enemies():
		if node.combat_id == id:
			return node
	return null


func _debug_draw() -> CombatDebugDraw:
	for child: Node in room().get_children():
		if child is CombatDebugDraw:
			return child as CombatDebugDraw
	return null


## The placed enemies dead: the fight has started and every share is released.
func _kill_placed() -> void:
	for node: Enemy in room().get_enemies():
		if not room().get_reserve_enemies().has(node):
			kill(node)


func _pending_now() -> bool:
	return not room().get_waves().get_pending().is_empty()


## Kills every reserve enemy that is on the field, between ticks.
func _kill_arrived() -> int:
	var killed: int = 0
	for node: Enemy in room().get_reserve_enemies():
		if not node.logic.is_waiting() and node.logic.is_alive():
			kill(node)
			killed += 1
	return killed


func _assert_fresh_waves(built: Room, label: String) -> void:
	var waves: RoomWaves = built.get_waves()
	assert_not_null(waves, label)
	assert_false(waves.has_started(), "%s: the fight has not started" % label)
	assert_eq(waves.get_kill_count(), 0, "%s: no kills" % label)
	assert_eq(built.get_kill_count(), 0, "%s: no kills in the room" % label)
	assert_eq(waves.get_next_index(), 0, "%s: nothing was started" % label)
	assert_true(waves.get_pending().is_empty(), "%s: nothing is pending" % label)
	assert_eq(waves.get_released_count(), 0, "%s: nothing is released" % label)
	assert_eq(built.get_reserve_enemies().size(), 3, "%s: the whole reserve" % label)
	for node: Enemy in built.get_reserve_enemies():
		assert_true(node.logic.is_waiting(), "%s: %s waits" % [label, node.combat_id])


# --- AC16: the reserve ------------------------------------------------------------------------


func test_ac16_the_reserve_is_built_after_the_placed_enemies_in_arrival_order() -> void:
	await spawn_floor(_wave_floor())
	var placed_ids: Array[StringName] = [&"chaser_1", &"caster_2"]
	assert_eq(_node_ids(room().get_enemies()), placed_ids + RESERVE_IDS)
	assert_eq(_node_ids(room().get_reserve_enemies()), RESERVE_IDS)
	assert_eq(_ids_of_sim(room()), [&"player_1"] as Array[StringName] + placed_ids + RESERVE_IDS)
	assert_eq(room().get_runner().combatant_paths.size(), 6, "player, two placed, three reserve")


func test_ac16_a_reserve_enemy_is_in_reserve_at_the_first_arrival_point() -> void:
	await spawn_floor(_wave_floor())
	for node: Enemy in room().get_reserve_enemies():
		assert_true(node.starts_in_reserve)
		assert_true(node.logic.is_waiting())
		assert_eq(node.logic.get_position_tiles(), FIRST_POINT)
		assert_eq(node.global_position, Units.vector_tiles_to_px(FIRST_POINT))
	for node: Enemy in [enemy(0), enemy(1)]:
		assert_false(node.starts_in_reserve, "the placed ones are not")
		assert_false(node.logic.is_waiting())


func test_ac16_the_reserve_has_no_collision_and_draws_nothing() -> void:
	await spawn_floor(_wave_floor())
	await run_ticks(2)
	for node: Enemy in room().get_reserve_enemies():
		assert_eq(node.collision_layer, 0, node.combat_id)
		assert_eq(node.collision_mask, 0, node.combat_id)
		assert_false(node.is_body_drawn(), "no shape, bar or telegraph")
		assert_false(node.did_draw_body(), "its draw pass drew none")
		assert_false((node.get_node("DebugLabel") as Label).visible, "no label")
	for node: Enemy in [enemy(0), enemy(1)]:
		assert_true(node.is_body_drawn(), "the control: a placed enemy is drawn")
		assert_eq(node.collision_layer, ENEMY_LAYER)
		assert_true(node.did_draw_body())
		assert_true((node.get_node("DebugLabel") as Label).visible)


func test_ac16_the_debug_draw_has_a_ring_for_every_placed_enemy_and_none_for_the_reserve() -> void:
	await spawn_floor(_wave_floor())
	var rings: Array[Hurtbox] = _debug_draw().get_hurtboxes()
	assert_eq(rings.size(), 3, "the player and the two placed enemies")
	var ids: Array[StringName] = []
	for ring: Hurtbox in rings:
		ids.append(ring.owner_id)
	assert_eq(ids, [&"player_1", &"chaser_1", &"caster_2"] as Array[StringName])


func test_ac16_a_body_walks_through_the_place_of_a_waiting_node() -> void:
	await spawn_floor(_wave_floor())
	await get_tree().physics_frame
	assert_null(await _run_probe_through(Units.vector_tiles_to_px(FIRST_POINT)))
	var standing: Vector2 = enemy(0).global_position
	assert_not_null(await _run_probe_through(standing), "the control: a placed enemy is solid")


func test_ac16_reset_on_a_room_with_waves_changes_nothing_and_reports_an_error() -> void:
	await spawn_floor(_wave_floor())
	kill(enemy(0))
	await run_until(_pending_now, 20)
	await run_ticks(10)
	var before: Dictionary = room().get_runner().take_snapshot()
	room().get_runner().reset()
	assert_push_error("reset refused")
	assert_eq_deep(room().get_runner().take_snapshot(), before)
	assert_eq(room().get_reserve_enemies().size(), 3)
	assert_true(room().get_waves().has_started())
	assert_eq(room().get_waves().get_next_index(), 1, "its one warning is as it was")


func test_ac16_reset_on_a_room_without_waves_still_resets_it() -> void:
	await spawn_floor(FloorFixtures.floor_of([FloorFixtures.one_enemy_room()]))
	hit(enemy().logic, 5)
	assert_lt(enemy().logic.get_combat_state().get_hp(), FloorFixtures.WEAK_HP)
	room().get_runner().reset()
	assert_eq(enemy().logic.get_combat_state().get_hp(), FloorFixtures.WEAK_HP, "the control")


# --- AC12, AC15: the counts and the clear -----------------------------------------------------


func test_ac12_kill_count_and_target_through_a_whole_room() -> void:
	await spawn_floor(_wave_floor())
	assert_eq(room().get_kill_target(), 5)
	assert_eq(room().get_waves().get_kill_target(), 5)
	assert_eq(room().get_kill_count(), 0)
	assert_false(room().is_cleared())
	assert_eq(room().count_living_enemies(), 2, "alive: the reserve is not")
	kill(enemy(0))
	assert_eq(room().get_kill_count(), 1, "by the end of the step it dies in")
	kill(enemy(1))
	assert_eq(room().get_kill_count(), 2)
	assert_false(room().is_cleared(), "nobody alive, but three still to come")
	assert_eq(room().count_living_enemies(), 0)
	var most_seen: int = 2
	var ticks: int = 0
	while room().get_kill_count() < room().get_kill_target() and ticks < KILL_LOOP_LIMIT_TICKS:
		set_hp(100)
		await run_ticks(1)
		ticks += 1
		var before: int = room().get_kill_count()
		assert_eq(before, most_seen, "no kill appears by itself")
		assert_false(room().is_cleared(), "not cleared before the target")
		var killed: int = _kill_arrived()
		assert_eq(room().get_kill_count(), before + killed, "+1 the moment one dies")
		most_seen += killed
		assert_eq(room().get_kill_count(), room().get_waves().get_kill_count())
	assert_eq(room().get_kill_count(), 5, "n of n when the last dies")
	assert_eq(room().get_kill_target(), 5)
	assert_true(room().is_cleared(), "cleared exactly then")
	assert_lt(ticks, KILL_LOOP_LIMIT_TICKS, "every reinforcement came")


func test_ac12_is_cleared_needs_the_whole_reserve_gone_not_just_the_placed() -> void:
	await spawn_floor(_wave_floor())
	_kill_placed()
	assert_false(room().is_cleared())
	for node: Enemy in room().get_reserve_enemies():
		kill(node)
	assert_true(room().is_cleared())
	assert_eq(room().get_kill_count(), 5)


func test_ac15_kill_all_clears_the_room_in_that_tick_and_nothing_arrives_after() -> void:
	await spawn_floor(_wave_floor())
	await run_ticks(5)
	kill_all()
	assert_true(room().get_waves().get_pending().is_empty(), "at once")
	assert_true(room().is_cleared(), "in that tick")
	await run_ticks(1)
	assert_true(room().is_cleared())
	assert_eq(room().get_kill_count(), 5)
	await run_ticks(5 * SECOND_STEPS)
	assert_true(room().get_waves().get_pending().is_empty())
	for node: Enemy in room().get_enemies():
		assert_eq(
			node.logic.get_state(), EnemyLogic.State.DEAD, "%s never arrived" % node.combat_id
		)
	assert_eq(room().get_waves().get_next_index(), 3, "every slot was passed over, silently")


func test_ac15_a_reserve_enemy_killed_in_its_own_warning_never_arrives() -> void:
	await spawn_floor(_wave_floor())
	kill(enemy(0))
	assert_true(await run_until(_pending_now, 20), "a warning starts")
	var warned: Enemy = _enemy_named(room().get_waves().get_pending()[0].enemy_id)
	var spot: Vector2 = warned.global_position
	kill(warned)
	assert_true(room().get_waves().get_pending().is_empty(), "gone from the list at once")
	await run_ticks(3 * SECOND_STEPS)
	assert_eq(warned.logic.get_state(), EnemyLogic.State.DEAD, "it never arrived")
	assert_eq(warned.logic.get_position_px(), spot)
	assert_eq(warned.collision_layer, 0)


func test_ac15_a_reserve_enemy_killed_while_it_waits_counts_and_is_never_sent() -> void:
	await spawn_floor(_wave_floor())
	var last: Enemy = _enemy_named(&"chaser_5")
	kill(last)
	assert_eq(room().get_kill_count(), 1, "it counts as a kill")
	_kill_placed()
	for _i: int in 3 * SECOND_STEPS:
		set_hp(100)
		await run_ticks(1)
		_kill_arrived()
	assert_eq(last.logic.get_state(), EnemyLogic.State.DEAD)
	assert_true(room().is_cleared())


func test_ac12_a_room_without_reinforcements_reports_its_counts_and_has_no_director() -> void:
	await spawn_floor(FloorFixtures.floor_of([FloorFixtures.arena_room()]))
	assert_null(room().get_waves())
	assert_eq(room().get_reserve_enemies().size(), 0)
	assert_eq(room().get_enemies().size(), 2)
	assert_eq(room().get_kill_target(), 2)
	assert_eq(room().get_kill_count(), 0)
	assert_false(room().is_cleared())
	kill(enemy(0))
	assert_eq(room().get_kill_count(), 1)
	assert_false(room().is_cleared())
	kill(enemy(1))
	assert_eq(room().get_kill_count(), 2)
	assert_true(room().is_cleared())


func test_ac24_a_room_without_reinforcements_has_todays_snapshot_keys() -> void:
	await spawn_floor(FloorFixtures.floor_of([FloorFixtures.arena_room()]))
	await run_ticks(3)
	var keys: Array = room().get_runner().take_snapshot().keys()
	keys.sort()
	assert_eq(keys, ["combatants", "order", "step_rate", "time"], "exactly today's four")
	assert_null(room().get_runner().get_sim().get_waves())


func test_ac24_a_room_with_reinforcements_adds_only_the_waves_key() -> void:
	await spawn_floor(_wave_floor())
	var keys: Array = room().get_runner().take_snapshot().keys()
	keys.sort()
	assert_eq(keys, ["combatants", "order", "step_rate", "time", "waves"])
	assert_eq(room().get_runner().get_sim().get_waves(), room().get_waves())


func test_ac19_a_dead_enemy_of_a_room_without_reinforcements_is_drawn_as_before() -> void:
	await spawn_floor(FloorFixtures.floor_of([FloorFixtures.arena_room()]))
	var node: Enemy = enemy(0)
	assert_false(node.hide_when_dead, "untouched")
	kill(node)
	await wait_process_frames(2)
	assert_true(node.is_body_drawn(), "shape, bar and label, as before")
	assert_true(node.did_draw_body())
	assert_true((node.get_node("DebugLabel") as Label).visible)
	assert_eq(node.get_body_color(), node.dead_color)
	assert_eq(_debug_draw().get_hurtboxes().size(), 3, "its ring too: the player and both")


# --- AC19: the exit, the heal, how a dead enemy looks -----------------------------------------


func test_ac19_the_exit_opens_in_the_tick_the_kill_target_is_reached_and_heals_once() -> void:
	await spawn_floor(_wave_floor())
	var healed_amounts: Array[int] = []
	_floor.healed.connect(func(amount: int) -> void: healed_amounts.append(amount))
	set_hp(50)
	_kill_placed()
	await run_ticks(2)
	assert_false(room().is_door_open(), "the placed enemies are dead and the door stays locked")
	assert_false(_floor.get_run().is_room_cleared())
	var ticks: int = 0
	while room().get_kill_count() < room().get_kill_target() - 1 and ticks < KILL_LOOP_LIMIT_TICKS:
		await run_ticks(1)
		ticks += 1
		_kill_arrived()
		assert_false(room().is_door_open(), "locked at %d of 5" % room().get_kill_count())
	assert_eq(room().get_kill_count(), 4)
	assert_eq(healed_amounts, [] as Array[int], "no heal yet")
	var last: Callable = func() -> bool: return _kill_arrived() > 0
	assert_true(await run_until(last, KILL_LOOP_LIMIT_TICKS), "the last one arrived and died")
	assert_eq(room().get_kill_count(), 5)
	assert_false(room().is_door_open(), "this tick has not read it yet")
	await run_ticks(1)
	assert_true(room().is_door_open(), "open in the tick the target is reached")
	assert_eq(healed_amounts.size(), 1, "the heal comes then, once")
	assert_eq(healed_amounts[0], 30, "30 % of 100")
	assert_eq(hp(), 80)
	await run_ticks(2 * SECOND_STEPS)
	assert_eq(healed_amounts.size(), 1, "still once")
	assert_eq(hp(), 80)


func test_ac19_a_dead_enemy_of_a_room_with_reinforcements_is_not_drawn_but_its_number_is() -> void:
	await spawn_floor(_wave_floor())
	var node: Enemy = enemy(0)
	assert_true(node.hide_when_dead)
	for each: Enemy in room().get_enemies():
		assert_true(each.hide_when_dead, "every enemy of the room, placed and reserve")
	kill(node)
	await wait_process_frames(2)
	assert_false(node.is_body_drawn())
	assert_false(node.did_draw_body())
	assert_false((node.get_node("DebugLabel") as Label).visible)
	assert_eq(node.collision_layer, 0)
	var numbers: DamageNumbers = node.get_damage_numbers()
	assert_eq(numbers.get_labels().size(), 1, "the killing hit's number")
	assert_true(numbers.get_labels()[0].is_visible_in_tree())
	var ids: Array[StringName] = []
	for ring: Hurtbox in _debug_draw().get_hurtboxes():
		ids.append(ring.owner_id)
	assert_false(ids.has(&"chaser_1"), "no debug ring for it")
	assert_true(ids.has(&"caster_2"), "the living one keeps its ring")


# --- AC18: arriving, restoring ---------------------------------------------------------------


func test_ac18_on_arrival_the_node_is_on_the_arrival_point_visible_and_solid() -> void:
	await spawn_floor(_wave_floor())
	kill(enemy(0))
	assert_true(await run_until(_pending_now, 20))
	var warning: RoomWaves.Pending = room().get_waves().get_pending()[0]
	var node: Enemy = _enemy_named(warning.enemy_id)
	assert_false(node.is_body_drawn(), "still hidden during its warning")
	assert_eq(node.collision_layer, 0)
	var arrived: Callable = func() -> bool: return not node.logic.is_waiting()
	assert_true(await run_until(arrived, 200), "it arrives")
	assert_eq(node.global_position, Units.vector_tiles_to_px(warning.point), "on the point")
	assert_eq(node.logic.get_position_px(), node.global_position)
	assert_true(node.is_body_drawn(), "visible")
	assert_true((node.get_node("DebugLabel") as Label).visible)
	assert_eq(node.collision_layer, ENEMY_LAYER, "with collision")
	assert_eq(node.collision_mask, 5)
	assert_true(node.logic.is_aggroed())
	await run_ticks(1)
	assert_true(node.did_draw_body())
	await get_tree().physics_frame
	assert_not_null(await _run_probe_through(node.global_position), "and it is solid")


## "Attack range" here: the enemy begins an attack (its state is WINDUP), which a chaser does
## only inside its attack's trigger band.
func test_ac18_it_reaches_attack_range_of_a_player_10_tiles_away_behind_a_pillar() -> void:
	await spawn_floor(FloorFixtures.floor_of([FloorFixtures.wave_pillar_room()]))
	put_player_at(Vector2(10.5, 5.5))
	kill(enemy(0))
	assert_true(await run_until(_pending_now, 20))
	var warning: RoomWaves.Pending = room().get_waves().get_pending()[0]
	assert_eq(warning.point, Vector2(20.5, 4.5), "the nearer of the two points, 10 tiles away")
	var node: Enemy = _enemy_named(warning.enemy_id)
	var attacking: Callable = func() -> bool:
		set_hp(100)
		return node.logic.get_state() == EnemyLogic.State.WINDUP
	assert_true(await run_until(attacking, KILL_LOOP_LIMIT_TICKS), "it came round the pillar")
	var gap: float = node.logic.get_position_tiles().distance_to(
		player().motor.get_position_tiles()
	)
	var attack: EnemyAttackData = node.logic.get_data().attacks[0]
	assert_lte(gap, attack.trigger_max_tiles + 0.1, "inside its attack's trigger band")
	var nav: NavGrid = room().get_runner().get_sim().get_nav()
	var radius: float = node.logic.get_data().hurtbox_radius_tiles
	assert_false(
		nav.has_clear_line(warning.point, Vector2(10.5, 5.5), radius),
		"the pillar is between the point and the player"
	)


func test_ac18_a_snapshot_before_the_arrival_restored_after_it_hides_the_node_again() -> void:
	await spawn_floor(_wave_floor())
	kill(enemy(0))
	assert_true(await run_until(_pending_now, 20))
	var warning: RoomWaves.Pending = room().get_waves().get_pending()[0]
	var node: Enemy = _enemy_named(warning.enemy_id)
	var before: Dictionary = room().get_runner().take_snapshot()
	var waiting_at: Vector2 = node.global_position
	var arrived: Callable = func() -> bool: return not node.logic.is_waiting()
	assert_true(await run_until(arrived, 200))
	await run_ticks(10)  # Walking when the restore comes.
	assert_true(node.is_body_drawn())
	assert_true(room().get_runner().restore_snapshot(before))
	assert_true(node.logic.is_waiting())
	assert_false(node.is_body_drawn(), "hidden again")
	assert_false((node.get_node("DebugLabel") as Label).visible)
	assert_eq(node.collision_layer, 0, "and without collision")
	assert_eq(node.collision_mask, 0)
	assert_eq(node.global_position, waiting_at, "back where it waited")
	assert_eq(room().get_waves().get_pending().size(), 1, "its warning is running again")
	await run_ticks(60)
	assert_eq(node.global_position, waiting_at, "its body does not move in the next 60 ticks")
	assert_eq(node.logic.get_position_px(), waiting_at)
	assert_true(node.logic.is_waiting())
	assert_eq(node.collision_layer, 0)
	assert_true(await run_until(arrived, 200), "the warning goes on to the same arrival")
	assert_eq(node.global_position, Units.vector_tiles_to_px(warning.point))


func test_ac18_a_snapshot_taken_after_the_arrival_restored_into_a_new_room_shows_the_node() -> void:
	await spawn_floor(_wave_floor())
	kill(enemy(0))
	assert_true(await run_until(_pending_now, 20))
	var id: StringName = room().get_waves().get_pending()[0].enemy_id
	var node: Enemy = _enemy_named(id)
	var arrived: Callable = func() -> bool: return not node.logic.is_waiting()
	assert_true(await run_until(arrived, 200))
	await run_ticks(30)
	var after: Dictionary = room().get_runner().take_snapshot()
	var arrived_at: Vector2 = node.logic.get_position_px()
	var old_room: Room = room()
	_floor.restart_room()
	assert_ne(room(), old_room, "a freshly built room of the same data")
	var fresh: Enemy = _enemy_named(id)
	assert_true(fresh.logic.is_waiting())
	assert_false(fresh.is_body_drawn())
	assert_true(room().get_runner().restore_snapshot(after))
	assert_false(fresh.logic.is_waiting())
	assert_true(fresh.is_body_drawn(), "visible")
	assert_true((fresh.get_node("DebugLabel") as Label).visible)
	assert_eq(fresh.collision_layer, ENEMY_LAYER, "collidable")
	assert_eq(fresh.collision_mask, 5)
	assert_eq(fresh.global_position, arrived_at, "on the logic's position")
	assert_eq(fresh.logic.get_position_px(), arrived_at)
	assert_eq(room().get_waves().get_kill_count(), 1)
	await get_tree().physics_frame
	assert_not_null(await _run_probe_through(arrived_at))


# --- C6, C11: what the room hands the director ----------------------------------------------


func test_c11_the_first_placed_enemy_to_wake_releases_only_its_share() -> void:
	await spawn_floor(_wave_floor())
	kill(enemy(0))  # The shares of three over two placed enemies are 2 and 1.
	for _i: int in 6 * SECOND_STEPS:
		set_hp(100)
		await run_ticks(1)
		_kill_arrived()
	assert_eq(room().get_waves().get_released_count(), 2)
	assert_eq(room().get_waves().get_next_index(), 2, "two were sent")
	assert_true(_enemy_named(&"chaser_5").logic.is_waiting(), "the third waits for the caster")
	assert_eq(room().get_kill_count(), 3)
	assert_false(room().is_cleared())


func test_c11_the_room_hands_its_max_engaged_to_the_director() -> void:
	var data: RoomData = WaveFixtures.wave_room()
	data.max_engaged = 1
	await spawn_floor(FloorFixtures.floor_of([data]))
	_kill_placed()
	for _i: int in 4 * SECOND_STEPS:
		set_hp(100)
		await run_ticks(1)
	assert_eq(room().get_waves().get_next_index(), 1, "one on the player, so no second one")
	await spawn_floor(_wave_floor())  # 0 means the tunable: 3.
	_kill_placed()
	for _i: int in 4 * SECOND_STEPS:
		set_hp(100)
		await run_ticks(1)
	assert_gt(room().get_waves().get_next_index(), 1, "the control: with the default more come")


# --- AC20: a rebuilt room starts its waves over ----------------------------------------------


## The room has gone through a fight: the placed enemies are dead, a warning has run.
func _play_a_while() -> void:
	_kill_placed()
	assert_true(await run_until(_pending_now, 20))
	await run_ticks(30)
	assert_true(room().get_waves().has_started())
	assert_gt(room().get_kill_count(), 0)


func test_ac20_the_r_key_gives_a_room_whose_waves_start_from_the_beginning() -> void:
	await spawn_floor(_wave_floor())
	await _play_a_while()
	var old_room: Room = room()
	press_key(KEY_R)
	assert_ne(room(), old_room)
	_assert_fresh_waves(room(), "after R")
	await run_ticks(5 * SECOND_STEPS)
	assert_false(room().get_waves().has_started(), "and it stays quiet: nobody has noticed anyone")
	assert_true(room().get_waves().get_pending().is_empty())


func test_ac20_the_n_key_gives_a_room_whose_waves_start_from_the_beginning() -> void:
	await spawn_floor(_wave_floor(2))
	await _play_a_while()
	var old_room: Room = room()
	press_key(KEY_N)
	assert_ne(room(), old_room)
	assert_eq(room().get_room_data().id, &"wave_2")
	_assert_fresh_waves(room(), "after N")


func test_ac20_a_death_gives_a_room_whose_waves_start_from_the_beginning() -> void:
	await spawn_floor(_wave_floor())
	await _play_a_while()
	var old_room: Room = room()
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_ne(room(), old_room, "a new room")
	assert_eq(hp(), 100)
	_assert_fresh_waves(room(), "after a death")


## A probe that collides with enemy bodies only, started 48 px west of `target` and run 96 px
## through it. Returns what move_and_collide() reports: null when nothing was in the way.
func _run_probe_through(target: Vector2) -> KinematicCollision2D:
	var probe: CharacterBody2D = CharacterBody2D.new()
	probe.collision_layer = 0
	probe.collision_mask = ENEMY_LAYER
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	probe.add_child(shape)
	probe.position = target - Vector2(48, 0)
	room().add_child(probe)
	await get_tree().physics_frame
	var hit_found: KinematicCollision2D = probe.move_and_collide(Vector2(96, 0))
	room().remove_child(probe)
	probe.free()
	return hit_found
