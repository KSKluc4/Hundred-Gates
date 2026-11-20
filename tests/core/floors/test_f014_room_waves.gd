# gdlint:disable=max-public-methods
extends GutTest
## F-014 T3 (AC7 to AC12, AC15, AC26): the director's rules (C7), its point choice (C8) and its
## counts (C9) on a real CombatSim with a player motor and real enemies, bodies moved by the
## logic. The sim hook and the snapshot are in tests/core/combat/test_f014_sim_waves.gd.
## A step is one 120th of a second: at 120 ticks a second a tick is a step.

const RATE: int = 120
const WARNING_STEPS: int = 96  # 0.8 s of 1/120 s steps.
const INTERVAL_STEPS: int = 180  # 1.5 s.
const AWAY: Vector2 = Vector2(100, 100)

var _rules: FloorTunables


func before_each() -> void:
	_rules = WaveFixtures.rules()


## `placed_count` placed chasers that sleep until woken, `reserve_count` in reserve.
func _rig(placed_count: int, reserve_count: int, max_engaged: int) -> WaveFixtures.Rig:
	var placed_at: Array[Vector2] = []
	for index: int in placed_count:
		placed_at.append(WaveFixtures.PLACED_AT[index])
	return WaveFixtures.rig(placed_at, reserve_count, max_engaged, _rules)


func _starts(rig: WaveFixtures.Rig) -> Array[int]:
	var steps: Array[int] = []
	for entry: Dictionary in rig.recorder.starts:
		steps.append(entry["step"])
	return steps


func _arrival_steps(rig: WaveFixtures.Rig) -> Array[int]:
	var steps: Array[int] = []
	for entry: Dictionary in rig.recorder.arrivals:
		steps.append(entry["step"])
	return steps


## The player's sword, aimed down, on the first tick; then ticks until `done` is true or 120
## ticks have passed. Returns the ticks it took.
func _swing_until(rig: WaveFixtures.Rig, done: Callable) -> int:
	for index: int in 120:
		rig.tick(RATE, Vector2.ZERO, index == 0, Vector2.DOWN)
		if done.call():
			return index + 1
	return -1


# --- AC7: nothing arrives before the fight starts ---------------------------------------------


func test_ac7_nothing_arrives_while_the_player_stays_outside_every_aggro_radius() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 3, 2)
	rig.arena.chaser_data.aggro_radius_tiles = 6.0  # The real radius; (10, 6) is 9.4 from both.
	rig.run(10.0)
	assert_false(rig.waves.has_started())
	assert_eq(rig.waves.get_next_index(), 0)
	assert_eq(rig.waves.get_pending().size(), 0)
	assert_eq(rig.recorder.arrivals.size(), 0)
	for enemy: EnemyLogic in rig.reserve:
		assert_true(enemy.is_waiting())


func test_ac7_the_fight_has_started_by_the_end_of_the_step_an_enemy_notices_by_range() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 3, 2)
	rig.arena.chaser_data.aggro_radius_tiles = 6.0
	rig.put_player(Vector2(2, 4.9))  # 6.1 tiles from the chaser at (2, 11): not noticed.
	rig.ticks(RATE)
	assert_false(rig.waves.has_started(), "outside the radius for a second")
	rig.put_player(Vector2(2, 5.1))  # 5.9 tiles: inside.
	rig.tick()
	assert_true(rig.placed[0].is_aggroed(), "the control: it noticed in that very step")
	assert_true(rig.waves.has_started())
	assert_eq(rig.waves.get_pending().size(), 1, "and a warning started in it")


func test_ac7_after_a_hit_the_fight_has_started_by_the_end_of_the_next_step() -> void:
	var rig: WaveFixtures.Rig = _rig(1, 2, 2)
	rig.place(rig.placed[0], Vector2(10, 6.8))
	var swing_ticks: int = _swing_until(rig, func() -> bool: return rig.placed[0].is_aggroed())
	assert_gt(swing_ticks, 1, "the sword needs its windup before it lands")
	assert_false(rig.waves.has_started(), "the hit is at the contact, after the director")
	rig.tick()
	assert_true(rig.waves.has_started(), "the next step sees it")


func test_ac7_after_a_death_the_fight_has_started_by_the_end_of_the_next_step() -> void:
	var rig: WaveFixtures.Rig = _rig(1, 2, 2)
	rig.place(rig.placed[0], Vector2(10, 6.8))
	rig.placed[0].get_combat_state().set_hp(1)
	var swing_ticks: int = _swing_until(rig, func() -> bool: return not rig.placed[0].is_alive())
	assert_gt(swing_ticks, 1)
	assert_false(rig.waves.has_started(), "killed at the contact, after the director")
	rig.tick()
	assert_true(rig.waves.has_started())


func test_ac7_a_death_alone_starts_the_fight_in_the_next_step() -> void:
	# No hit on the way: the enemy that died was never aggroed, so only the death says so.
	var rig: WaveFixtures.Rig = _rig(2, 3, 2)
	rig.run(1.0)
	assert_false(rig.waves.has_started())
	rig.kill(rig.placed[0])
	assert_false(rig.placed[0].is_aggroed())
	assert_false(rig.waves.has_started(), "the director has not looked yet")
	rig.tick()
	assert_true(rig.waves.has_started())
	assert_eq(rig.waves.get_released_count(), 2, "and the dead one released its share")


func test_ac7_a_sleeping_room_stays_idle_with_a_player_standing_next_to_it() -> void:
	# The control of the two tests above: no hit and no death, no fight.
	var rig: WaveFixtures.Rig = _rig(1, 2, 2)
	rig.place(rig.placed[0], Vector2(10, 6.8))
	rig.run(3.0)
	assert_false(rig.waves.has_started())
	assert_eq(rig.waves.get_next_index(), 0)


# --- AC8: the cap counts engaged enemies and pending arrivals ---------------------------------


func test_ac8_nothing_arrives_while_both_placed_enemies_live() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 3, 2)
	rig.wake(rig.placed[0])
	rig.wake(rig.placed[1])
	rig.run(3.0)
	assert_true(rig.waves.has_started())
	assert_eq(rig.waves.get_next_index(), 0)
	assert_eq(rig.waves.get_pending().size(), 0)
	assert_eq(rig.recorder.arrivals.size(), 0)


func test_ac8_a_death_starts_a_warning_in_the_next_step_and_it_lands_96_steps_later() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 3, 2)
	rig.wake(rig.placed[0])
	rig.wake(rig.placed[1])
	rig.run(1.0)
	rig.kill(rig.placed[0])
	var death_step: int = rig.step_count()
	rig.tick()
	assert_eq(_starts(rig), [death_step + 1] as Array[int], "the step after the death")
	var pending: Array[RoomWaves.Pending] = rig.waves.get_pending()
	assert_eq(pending.size(), 1)
	assert_almost_eq(pending[0].time_left, 0.8, 1e-9, "the whole warning is still to run")
	assert_almost_eq(pending[0].total, 0.8, 1e-9)
	assert_eq(pending[0].enemy_id, rig.reserve[0].get_combat_id())
	rig.ticks(WARNING_STEPS - 1)
	assert_eq(rig.recorder.arrivals.size(), 0, "95 steps later it is still on its way")
	assert_true(rig.reserve[0].is_waiting())
	rig.tick()
	assert_eq(_arrival_steps(rig), [death_step + 1 + WARNING_STEPS] as Array[int])
	assert_false(rig.reserve[0].is_waiting())
	assert_true(rig.reserve[0].is_aggroed())
	assert_eq(rig.waves.get_pending().size(), 0, "and it is no longer pending")


func test_ac8_never_more_than_the_cap_engaged_or_on_their_way() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 3, 2)
	rig.wake(rig.placed[0])
	rig.wake(rig.placed[1])
	rig.run(1.0)
	rig.kill(rig.placed[0])
	rig.run(6.0)
	assert_eq(rig.waves.get_next_index(), 1, "the arrival fills the place of the dead one")
	assert_eq(rig.recorder.most_on_the_way(), 2)
	rig.kill(rig.placed[1])
	rig.run(6.0)
	assert_eq(rig.waves.get_next_index(), 2)
	assert_eq(rig.recorder.most_on_the_way(), 2, "still two at most, never three")


# --- AC9: a sleeping placed enemy does not count; the interval; the order ---------------------


func test_ac9_a_warning_starts_in_the_step_the_fight_starts_with_one_enemy_asleep() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 4, 2)
	rig.wake(rig.placed[0])
	rig.tick()
	assert_false(rig.placed[1].is_aggroed(), "the other one still sleeps")
	assert_eq(_starts(rig), [1] as Array[int], "in the step the fight started")
	assert_eq(rig.waves.get_pending().size(), 1)


func test_ac9_the_cap_of_two_holds_with_one_placed_enemy_awake_and_one_arrival() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 4, 2)
	rig.wake(rig.placed[0])
	rig.run(6.0)
	assert_eq(rig.waves.get_next_index(), 1, "one awake plus one arrival is two")
	assert_eq(rig.recorder.arrivals.size(), 1)


func test_ac9_the_second_warning_starts_one_interval_after_the_first_in_reserve_order() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 4, 3)
	rig.wake(rig.placed[0])
	rig.run(3.0)
	var starts: Array[int] = _starts(rig)
	assert_eq(starts.size(), 2, "the first share holds two")
	assert_eq(starts[0], 1)
	assert_eq(starts[1], 1 + INTERVAL_STEPS, "wave_spawn_interval after the first")
	assert_eq(rig.recorder.starts[0]["id"], rig.reserve[0].get_combat_id())
	assert_eq(rig.recorder.starts[1]["id"], rig.reserve[1].get_combat_id())


func test_ac9_the_interval_is_the_tunable() -> void:
	_rules.wave_spawn_interval = 0.5
	var rig: WaveFixtures.Rig = _rig(2, 4, 3)
	rig.wake(rig.placed[0])
	rig.run(2.0)
	assert_eq(_starts(rig), [1, 61] as Array[int])


func test_ac9_with_an_interval_of_zero_both_start_in_the_same_step_at_different_points() -> void:
	_rules.wave_spawn_interval = 0.0
	var rig: WaveFixtures.Rig = _rig(2, 4, 3)
	rig.wake(rig.placed[0])
	rig.tick()
	assert_eq(_starts(rig), [1, 1] as Array[int])
	var pending: Array[RoomWaves.Pending] = rig.waves.get_pending()
	assert_eq(pending.size(), 2)
	assert_ne(pending[0].point, pending[1].point)
	assert_eq(pending[0].enemy_id, rig.reserve[0].get_combat_id())
	assert_eq(pending[1].enemy_id, rig.reserve[1].get_combat_id())


func test_ac9_a_warning_of_zero_lands_in_the_step_after_it_started() -> void:
	_rules.wave_spawn_warning_duration = 0.0
	var rig: WaveFixtures.Rig = _rig(2, 4, 3)
	rig.wake(rig.placed[0])
	rig.tick()
	assert_eq(_starts(rig), [1] as Array[int])
	assert_eq(rig.recorder.arrivals.size(), 0, "not in the step it started")
	rig.tick()
	assert_eq(_arrival_steps(rig), [2] as Array[int])


# --- AC10: the point choice (C8) --------------------------------------------------------------


func _choose(
	points: Array[Vector2],
	players: Array[Vector2],
	taken: PackedByteArray = PackedByteArray(),
	enemies: Array[Vector2] = []
) -> int:
	var plain: int = RoomWaves.choose_point(points, taken, players, enemies, _rules)
	# CR-1: no walks given means every walk is short, so a list of short walks changes nothing.
	var short_walks: PackedFloat64Array = PackedFloat64Array()
	short_walks.resize(points.size())
	assert_eq(
		RoomWaves.choose_point(points, taken, players, enemies, _rules, short_walks),
		plain,
		"short walks everywhere are the answer with none given"
	)
	return plain


func _choose_walking(points: Array[Vector2], players: Array[Vector2], walks: Array[float]) -> int:
	return RoomWaves.choose_point(
		points, PackedByteArray(), players, [] as Array[Vector2], _rules, PackedFloat64Array(walks)
	)


func test_ac10_the_nearest_point_that_is_far_enough_wins() -> void:
	var points: Array[Vector2] = [Vector2(7, 0), Vector2(9, 0), Vector2(8, 0), Vector2(3, 0)]
	# 7, 9, 8 and 3 tiles from the player; 6 is the minimum: the 7 wins, not the 3 that is nearer.
	assert_eq(_choose(points, [Vector2.ZERO] as Array[Vector2]), 0)
	points = [Vector2(9, 0), Vector2(7, 0), Vector2(8, 0)]
	assert_eq(_choose(points, [Vector2.ZERO] as Array[Vector2]), 1, "whatever the order")


func test_ac10_far_enough_means_the_minimum_itself_counts() -> void:
	var points: Array[Vector2] = [Vector2(3, 0), Vector2(6, 0), Vector2(9, 0)]
	assert_eq(_choose(points, [Vector2.ZERO] as Array[Vector2]), 1, "exactly 6.0")
	points = [Vector2(3, 0), Vector2(5.99, 0), Vector2(9, 0)]
	assert_eq(_choose(points, [Vector2.ZERO] as Array[Vector2]), 2, "5.99 is not far enough")


func test_ac10_a_point_inside_the_box_beats_a_nearer_one_outside_it() -> void:
	# The box is 19 x 10 tiles. (0, 10.5) is 10.5 away and above the box's height; (15, 0) is
	# 15 away and inside it.
	var points: Array[Vector2] = [Vector2(0, 10.5), Vector2(15, 0)]
	assert_eq(_choose(points, [Vector2.ZERO] as Array[Vector2]), 1)
	# The control: both inside, the nearer wins.
	points = [Vector2(0, 9.5), Vector2(15, 0)]
	assert_eq(_choose(points, [Vector2.ZERO] as Array[Vector2]), 0)


func test_ac10_the_box_edges_are_inside() -> void:
	var points: Array[Vector2] = [Vector2(0, 10), Vector2(19, 0), Vector2(30, 0)]
	assert_eq(_choose(points, [Vector2.ZERO] as Array[Vector2]), 0, "exactly 10 high is inside")
	points = [Vector2(19, 0), Vector2(0, 10), Vector2(30, 0)]
	assert_eq(_choose(points, [Vector2.ZERO] as Array[Vector2]), 1, "10 is nearer than 19")
	points = [Vector2(19.01, 0), Vector2(30, 0)]
	assert_eq(_choose(points, [Vector2.ZERO] as Array[Vector2]), 0, "none inside: the nearest")


func test_ac10_with_none_inside_the_box_the_nearest_far_enough_wins() -> void:
	var points: Array[Vector2] = [Vector2(40, 0), Vector2(0, 12), Vector2(0, 11), Vector2(2, 0)]
	assert_eq(_choose(points, [Vector2.ZERO] as Array[Vector2]), 2, "11 up, not the 2 or the 40")


func test_ac10_with_none_far_enough_the_farthest_wins() -> void:
	var points: Array[Vector2] = [Vector2(2, 0), Vector2(5, 0), Vector2(3, 0)]
	assert_eq(_choose(points, [Vector2.ZERO] as Array[Vector2]), 1)


func test_ac10_the_earlier_point_wins_a_tie_and_a_difference_below_the_epsilon() -> void:
	var player: Array[Vector2] = [Vector2.ZERO]
	var tie: Array[Vector2] = [Vector2(0, 8), Vector2(8, 0), Vector2(-8, 0)]
	assert_eq(_choose(tie, player), 0, "three at 8.0")
	# Vector2 holds 32-bit floats: 7.9999995 is the float just under 8, 4.8e-7 closer.
	var nearly: Array[Vector2] = [Vector2(8, 0), Vector2(7.9999995, 0)]
	assert_eq(_choose(nearly, player), 0, "closer by 5e-7, under Geometry.DISTANCE_EPSILON")
	var better: Array[Vector2] = [Vector2(8, 0), Vector2(7.999, 0)]
	assert_eq(_choose(better, player), 1, "closer by 1e-3: the later one is better")
	var far_tie: Array[Vector2] = [Vector2(4, 0), Vector2(0, 4), Vector2(3, 0)]
	assert_eq(_choose(far_tie, player), 0, "the farthest tier: ties go to the earlier too")
	var far_nearly: Array[Vector2] = [Vector2(4, 0), Vector2(4.0000005, 0)]
	assert_eq(_choose(far_nearly, player), 0, "farther by 5e-7 is not better")
	var far_better: Array[Vector2] = [Vector2(4, 0), Vector2(4.001, 0)]
	assert_eq(_choose(far_better, player), 1)


func test_ac10_a_point_with_a_pending_arrival_is_never_chosen() -> void:
	var points: Array[Vector2] = [Vector2(7, 0), Vector2(8, 0), Vector2(9, 0)]
	var player: Array[Vector2] = [Vector2.ZERO]
	assert_eq(_choose(points, player, PackedByteArray([1, 0, 0])), 1)
	assert_eq(_choose(points, player, PackedByteArray([1, 1, 0])), 2)
	assert_eq(_choose(points, player, PackedByteArray([1, 1, 1])), -1, "none left")


func test_ac10_a_point_with_a_living_enemy_nearer_than_the_gap_is_never_chosen() -> void:
	var points: Array[Vector2] = [Vector2(7, 0), Vector2(8, 0)]
	var player: Array[Vector2] = [Vector2.ZERO]
	var near: Array[Vector2] = [Vector2(7, 1.4)]
	assert_eq(_choose(points, player, PackedByteArray(), near), 1, "1.4 is nearer than 1.5")
	var at_gap: Array[Vector2] = [Vector2(7, 1.5)]
	assert_eq(
		_choose(points, player, PackedByteArray(), at_gap), 0, "exactly the gap is not nearer"
	)
	var both: Array[Vector2] = [Vector2(7, 1.0), Vector2(8, -1.0)]
	assert_eq(_choose(points, player, PackedByteArray(), both), -1, "none qualifies")


func test_ac10_the_distance_is_to_the_nearest_living_player() -> void:
	var points: Array[Vector2] = [Vector2(7, 0), Vector2(30, 0), Vector2(60, 0)]
	# Players at the origin and at (30, 0): the point at 30 is on the second one, 0 tiles away,
	# so it is not far enough; the 7 is far enough from the first and 23 from the second.
	var players: Array[Vector2] = [Vector2.ZERO, Vector2(30, 0)]
	assert_eq(_choose(points, players), 0)
	var behind: Array[Vector2] = [Vector2(30, 0), Vector2.ZERO]
	assert_eq(_choose(points, behind), 0, "the order of the players changes nothing")
	# The first player is far from both points: the second, nearer one decides the tier.
	var two_points: Array[Vector2] = [Vector2(7, 0), Vector2(20, 0)]
	var far_first: Array[Vector2] = [Vector2(50, 0), Vector2.ZERO]
	assert_eq(_choose(two_points, far_first), 0, "7 from one, outside the box of the other")


func test_ac10_no_player_no_point() -> void:
	var points: Array[Vector2] = [Vector2(7, 0)]
	assert_eq(_choose(points, [] as Array[Vector2]), -1)


func test_ac10_choosing_changes_nothing() -> void:
	var points: Array[Vector2] = [Vector2(7, 0), Vector2(8, 0)]
	var taken: PackedByteArray = PackedByteArray([0, 0])
	var players: Array[Vector2] = [Vector2.ZERO]
	var enemies: Array[Vector2] = [Vector2(7, 1)]
	_choose(points, players, taken, enemies)
	assert_eq(points, [Vector2(7, 0), Vector2(8, 0)] as Array[Vector2])
	assert_eq(taken, PackedByteArray([0, 0]))
	assert_eq(enemies, [Vector2(7, 1)] as Array[Vector2])


func test_ac10_the_director_sends_none_while_no_point_qualifies_then_starts_in_the_first_step(
) -> void:
	_rules.wave_spawn_gap_tiles = 100.0  # Every point is near a living enemy.
	var rig: WaveFixtures.Rig = _rig(1, 2, 2)
	rig.wake(rig.placed[0])
	rig.run(2.0)
	assert_true(rig.waves.has_started())
	assert_eq(rig.waves.get_next_index(), 0, "nothing qualifies, nothing is sent")
	assert_eq(rig.waves.get_pending().size(), 0)
	_rules.wave_spawn_gap_tiles = 1.5
	var step_before: int = rig.step_count()
	rig.tick()
	assert_eq(_starts(rig), [step_before + 1] as Array[int], "the first step in which one does")


func test_ac10_a_taken_point_frees_up_once_its_enemy_has_walked_off_it() -> void:
	_rules.wave_spawn_interval = 0.0
	var point: Array[Vector2] = [Vector2(16.5, 3.5)]
	var rig: WaveFixtures.Rig = WaveFixtures.rig(
		[WaveFixtures.PLACED_AT[0]], 2, 3, _rules, point, 0.01
	)
	rig.wake(rig.placed[0])
	rig.tick()
	assert_eq(_starts(rig), [1] as Array[int], "one point, one warning")
	rig.ticks(WARNING_STEPS - 1)
	assert_eq(rig.waves.get_next_index(), 1, "still taken during its warning")
	rig.tick()
	assert_eq(_arrival_steps(rig), [1 + WARNING_STEPS] as Array[int])
	var started_second: bool = false
	for _i: int in 240:
		rig.tick()
		if rig.waves.get_next_index() == 2:
			started_second = true
			break
	assert_true(started_second, "the second one is sent once the point is free")
	var distance: float = rig.reserve[0].get_position_tiles().distance_to(point[0])
	assert_gte(distance, 1.5 - 1e-6, "the first one had walked the gap off the point")
	assert_gt(rig.recorder.starts[1]["step"], 1 + WARNING_STEPS, "and not before it had arrived")


# --- AC11: no living player --------------------------------------------------------------------


func test_ac11_with_no_living_player_nothing_new_starts_but_pending_arrivals_arrive() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 4, 3)
	rig.wake(rig.placed[0])
	rig.tick()
	assert_eq(rig.waves.get_pending().size(), 1)
	rig.heal_player = false
	rig.player.get_combat_state().set_hp(0)
	assert_false(rig.player.is_alive())
	rig.run(5.0)
	assert_eq(_arrival_steps(rig), [1 + WARNING_STEPS] as Array[int], "the pending one landed")
	assert_eq(rig.waves.get_next_index(), 1, "and no second one started in five seconds")


func test_ac11_the_same_run_with_a_living_player_does_start_the_second() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 4, 3)
	rig.wake(rig.placed[0])
	rig.run(5.0)
	assert_eq(_starts(rig), [1, 1 + INTERVAL_STEPS] as Array[int])


# --- AC12: the counts --------------------------------------------------------------------------


func test_ac12_the_kill_target_is_every_enemy_and_nothing_is_killed_at_the_start() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 3, 2)
	assert_eq(rig.waves.get_kill_target(), 5)
	assert_eq(rig.waves.get_kill_count(), 0, "three of them are not alive, but waiting")
	rig.run(1.0)
	assert_eq(rig.waves.get_kill_count(), 0)


func test_ac12_a_kill_counts_by_the_end_of_the_step_it_happens_in() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 3, 2)
	rig.place(rig.placed[0], Vector2(10, 6.8))
	rig.placed[0].get_combat_state().set_hp(1)
	var swing_ticks: int = _swing_until(rig, func() -> bool: return not rig.placed[0].is_alive())
	assert_gt(swing_ticks, 1)
	assert_eq(rig.waves.get_kill_count(), 1, "the step it died in")
	assert_eq(rig.waves.get_kill_target(), 5, "the target never moves")


func test_ac12_the_count_follows_the_room_to_n_of_n() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 3, 5)
	rig.wake(rig.placed[0])
	rig.wake(rig.placed[1])
	rig.run(4.0)
	assert_eq(rig.recorder.arrivals.size(), 3, "everyone came in")
	var expected: int = 0
	for enemy: EnemyLogic in rig.all_enemies():
		assert_eq(rig.waves.get_kill_count(), expected)
		rig.kill(enemy)
		expected += 1
		assert_eq(rig.waves.get_kill_count(), expected, "at once")
		rig.tick()
		assert_eq(rig.waves.get_kill_count(), expected, "and it stays")
	assert_eq(rig.waves.get_kill_count(), rig.waves.get_kill_target())


func test_ac12_a_waiting_enemy_killed_is_a_kill_and_a_waiting_one_is_not() -> void:
	var rig: WaveFixtures.Rig = _rig(1, 2, 2)
	rig.kill(rig.reserve[1])
	assert_eq(rig.waves.get_kill_count(), 1)
	assert_true(rig.reserve[0].is_waiting())


# --- AC15: a reserve enemy that is not waiting any more ----------------------------------------


func test_ac15_a_reserve_enemy_killed_while_waiting_counts_and_is_never_sent() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 3, 3)
	rig.kill(rig.reserve[0])
	assert_eq(rig.waves.get_kill_count(), 1)
	rig.run(3.0)
	assert_true(rig.waves.has_started(), "a death starts the fight, wherever it is")
	assert_eq(rig.recorder.arrivals.size(), 0, "but no placed enemy has woken: nothing is released")
	rig.wake(rig.placed[0])
	var wake_step: int = rig.step_count()
	rig.run(8.0)
	assert_eq(rig.recorder.starts[-1]["step"], wake_step + 1, "passing it over costs no wait")
	var ids: Array[StringName] = []
	for entry: Dictionary in rig.recorder.arrivals:
		ids.append(entry["id"])
	assert_false(ids.has(rig.reserve[0].get_combat_id()), str(ids))
	assert_eq(ids.size(), 1, "the dead one used a slot of the first share (2): only one is left")
	assert_eq(ids[0], rig.reserve[1].get_combat_id())
	assert_eq(rig.reserve[0].get_state(), EnemyLogic.State.DEAD)
	assert_eq(rig.waves.get_pending().size(), 0)


func test_ac15_one_killed_during_its_own_warning_never_arrives() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 4, 3)
	rig.wake(rig.placed[0])
	rig.ticks(10)
	assert_eq(rig.waves.get_pending().size(), 1)
	rig.kill(rig.reserve[0])
	assert_eq(rig.waves.get_pending().size(), 0, "gone from the list at once, with no tick")
	rig.run(4.0)
	var ids: Array[StringName] = []
	for entry: Dictionary in rig.recorder.arrivals:
		ids.append(entry["id"])
	assert_false(ids.has(rig.reserve[0].get_combat_id()))
	assert_eq(rig.reserve[0].get_state(), EnemyLogic.State.DEAD)
	assert_eq(ids, [rig.reserve[1].get_combat_id()] as Array[StringName], "the next one comes")


func test_ac15_after_everyone_is_killed_nothing_arrives_and_nothing_is_pending() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 4, 3)
	rig.wake(rig.placed[0])
	rig.ticks(30)
	assert_eq(rig.waves.get_pending().size(), 1, "a warning is running")
	rig.kill_everyone()
	assert_eq(rig.waves.get_kill_count(), rig.waves.get_kill_target())
	assert_eq(rig.waves.get_pending().size(), 0, "empty at once")
	var arrivals: int = rig.recorder.arrivals.size()
	rig.run(5.0)
	assert_eq(rig.recorder.arrivals.size(), arrivals, "nothing arrives")
	assert_eq(rig.waves.get_pending().size(), 0)
	for entry: Dictionary in rig.recorder.starts:
		if entry["step"] > 30:
			assert_eq(entry["point"], Vector2(-1, -1), "passed over, with no warning")
	assert_eq(rig.waves.get_kill_count(), rig.waves.get_kill_target())


# --- AC26: the reserve is released in shares ---------------------------------------------------


func _share_rig() -> WaveFixtures.Rig:
	_rules.wave_spawn_interval = 0.0
	return _rig(2, 5, 4)  # Shares of 3 and 2.


func test_ac26_the_first_placed_enemy_to_wake_releases_exactly_three() -> void:
	var rig: WaveFixtures.Rig = _share_rig()
	assert_eq(rig.waves.get_released_count(), 0)
	rig.wake(rig.placed[0])
	assert_eq(rig.waves.get_released_count(), 3)
	rig.tick()
	assert_eq(_starts(rig), [1, 1, 1] as Array[int], "three at once, the interval being 0")
	rig.run(3.0)
	assert_eq(rig.recorder.arrivals.size(), 3)
	assert_eq(rig.waves.get_next_index(), 3)


func test_ac26_no_fourth_however_many_die() -> void:
	var rig: WaveFixtures.Rig = _share_rig()
	rig.wake(rig.placed[0])
	rig.run(3.0)
	rig.kill(rig.placed[0])
	for enemy: EnemyLogic in rig.reserve.slice(0, 3):
		rig.kill(enemy)
	rig.run(5.0)
	assert_eq(rig.waves.get_next_index(), 3, "the room has nobody on the player and sends none")
	assert_eq(rig.waves.get_released_count(), 3)
	assert_true(rig.reserve[3].is_waiting())
	assert_true(rig.reserve[4].is_waiting())
	assert_eq(rig.waves.get_pending().size(), 0)


func test_ac26_the_second_placed_enemy_engaged_releases_the_last_two() -> void:
	var rig: WaveFixtures.Rig = _share_rig()
	rig.wake(rig.placed[0])
	rig.run(3.0)
	rig.kill(rig.placed[0])
	for enemy: EnemyLogic in rig.reserve.slice(0, 3):
		rig.kill(enemy)
	rig.run(1.0)
	rig.wake(rig.placed[1])
	assert_eq(rig.waves.get_released_count(), 5)
	var step_before: int = rig.step_count()
	rig.tick()
	assert_eq(rig.waves.get_next_index(), 5)
	assert_eq(_starts(rig).slice(3), [step_before + 1, step_before + 1] as Array[int])


func test_ac26_the_second_placed_enemy_killed_releases_the_last_two_too() -> void:
	var rig: WaveFixtures.Rig = _share_rig()
	rig.wake(rig.placed[0])
	rig.run(3.0)
	rig.kill(rig.placed[0])
	for enemy: EnemyLogic in rig.reserve.slice(0, 3):
		rig.kill(enemy)
	rig.run(1.0)
	rig.kill(rig.placed[1])
	assert_eq(rig.waves.get_released_count(), 5)
	rig.tick()
	assert_eq(rig.waves.get_next_index(), 5)
	assert_eq(rig.waves.get_pending().size(), 2)


func test_ac26_while_the_cap_is_full_the_released_ones_wait_for_it() -> void:
	_rules.wave_spawn_interval = 0.0
	var rig: WaveFixtures.Rig = _rig(2, 5, 2)
	rig.wake(rig.placed[0])
	rig.wake(rig.placed[1])
	assert_eq(rig.waves.get_released_count(), 5, "all released, none sent")
	rig.run(3.0)
	assert_eq(rig.waves.get_next_index(), 0, "two engaged is the cap")
	rig.kill(rig.placed[0])
	rig.tick()
	assert_eq(rig.waves.get_next_index(), 1, "one place free: one starts")
	rig.run(3.0)
	assert_eq(rig.waves.get_next_index(), 1)
	rig.kill(rig.reserve[0])
	rig.tick()
	assert_eq(rig.waves.get_next_index(), 2)
	assert_eq(rig.recorder.most_on_the_way(), 2)


func test_ac26_shares_split_evenly_with_the_larger_ones_first() -> void:
	# Seven over three placed enemies: 3, 2 and 2.
	_rules.wave_spawn_interval = 0.0
	var rig: WaveFixtures.Rig = _rig(3, 7, 9)
	var released: Array[int] = []
	for index: int in 3:
		rig.wake(rig.placed[index])
		released.append(rig.waves.get_released_count())
	assert_eq(released, [3, 5, 7] as Array[int])


func test_ac26_a_dead_placed_enemy_releases_its_share_like_a_woken_one() -> void:
	var rig: WaveFixtures.Rig = _share_rig()
	rig.kill(rig.placed[1])  # The second one: but the first share is what k = 1 releases.
	assert_eq(rig.waves.get_released_count(), 3)


# --- C9: what the glue reads -------------------------------------------------------------------


func test_c9_the_pending_list_gives_point_time_left_total_and_id_and_is_a_copy() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 3, 3)
	rig.wake(rig.placed[0])
	rig.ticks(31)
	var pending: Array[RoomWaves.Pending] = rig.waves.get_pending()
	assert_eq(pending.size(), 1)
	assert_eq(pending[0].enemy_id, rig.reserve[0].get_combat_id())
	assert_eq(pending[0].point, Vector2(16.5, 3.5), "the nearest far-enough point of (10, 6)")
	assert_almost_eq(pending[0].time_left, 0.8 - 30.0 / 120.0, 1e-9)
	assert_almost_eq(pending[0].total, 0.8, 1e-9)
	pending[0].time_left = 99.0
	assert_almost_eq(rig.waves.get_pending()[0].time_left, 0.8 - 30.0 / 120.0, 1e-9)


func test_c9_the_arrival_stands_on_its_point() -> void:
	var rig: WaveFixtures.Rig = _rig(2, 3, 3)
	rig.wake(rig.placed[0])
	rig.ticks(1 + WARNING_STEPS)
	assert_eq(rig.recorder.arrivals[0]["position"], Vector2(16.5, 3.5))


func test_c9_a_room_with_no_placed_enemy_holds_nothing_back() -> void:
	var rig: WaveFixtures.Rig = _rig(0, 2, 2)
	assert_eq(rig.waves.get_released_count(), 2)
	# CR-5: and the fight starts at once, so the reserve really comes.
	assert_false(rig.waves.has_started())
	rig.tick()
	assert_true(rig.waves.has_started(), "nobody to wait for")
	rig.run(5.0)
	assert_eq(_starts(rig), [1, 1 + INTERVAL_STEPS] as Array[int])
	assert_eq(rig.recorder.arrivals.size(), 2, "both reinforcements arrived")
	for enemy: EnemyLogic in rig.reserve:
		assert_false(enemy.is_waiting())


# --- AC10 (CR-1): the walk tier -------------------------------------------------------------


func test_ac10_a_boxed_point_with_a_short_walk_beats_a_nearer_boxed_one_with_a_long_walk() -> void:
	var player: Array[Vector2] = [Vector2.ZERO]
	var points: Array[Vector2] = [Vector2(7, 0), Vector2(12, 0)]
	assert_eq(_choose_walking(points, player, [30.0, 10.0]), 1, "7 away by 30, 12 away by 10")
	assert_eq(
		_choose_walking(points, player, [10.0, 10.0]), 0, "the control: both short, the nearer"
	)
	assert_eq(_choose_walking(points, player, [10.0, 30.0]), 0)


func test_ac10_the_only_boxed_point_wins_over_an_unboxed_one_even_with_a_long_walk() -> void:
	var player: Array[Vector2] = [Vector2.ZERO]
	var points: Array[Vector2] = [Vector2(7, 0), Vector2(0, 11.5)]  # The second is above the box.
	assert_eq(
		_choose_walking(points, player, [30.0, 5.0]), 0, "boxed with a long walk beats unboxed"
	)
	assert_eq(_choose_walking(points, player, [5.0, 5.0]), 0)


func test_ac10_when_every_walk_is_long_the_nearest_boxed_point_wins() -> void:
	var player: Array[Vector2] = [Vector2.ZERO]
	var points: Array[Vector2] = [Vector2(12, 0), Vector2(7, 0), Vector2(9, 0)]
	assert_eq(_choose_walking(points, player, [30.0, 30.0, 30.0]), 1)
	assert_eq(_choose_walking(points, player, [INF, INF, INF]), 1, "no way at all is long too")


func test_ac10_a_walk_of_exactly_the_maximum_is_short() -> void:
	var player: Array[Vector2] = [Vector2.ZERO]
	var points: Array[Vector2] = [Vector2(12, 0), Vector2(7, 0)]
	assert_eq(_rules.wave_max_walk_tiles, 18.0)
	assert_eq(_choose_walking(points, player, [18.0, 18.5]), 0, "18.0 is short, 18.5 is not")
	assert_eq(_choose_walking(points, player, [18.5, 18.0]), 1)
	_rules.wave_max_walk_tiles = 5.0
	assert_eq(_choose_walking(points, player, [4.0, 6.0]), 0, "the maximum is the tunable")


func test_ac10_an_infinite_walk_is_never_short() -> void:
	var player: Array[Vector2] = [Vector2.ZERO]
	var points: Array[Vector2] = [Vector2(7, 0), Vector2(12, 0)]
	assert_eq(_choose_walking(points, player, [INF, 10.0]), 1)


func test_ac10_the_walk_only_ranks_points_that_are_far_enough_and_boxed() -> void:
	var player: Array[Vector2] = [Vector2.ZERO]
	# A point too near with a short walk loses to a far one with a long walk.
	var near_and_far: Array[Vector2] = [Vector2(3, 0), Vector2(12, 0)]
	assert_eq(_choose_walking(near_and_far, player, [1.0, 30.0]), 1)
	# With none far enough the farthest wins, whatever the walks say.
	var all_near: Array[Vector2] = [Vector2(2, 0), Vector2(5, 0)]
	assert_eq(_choose_walking(all_near, player, [1.0, 99.0]), 1)
	assert_eq(_choose_walking(all_near, player, [99.0, 1.0]), 1)


func test_ac10_a_walk_missing_from_a_short_list_counts_as_short() -> void:
	var player: Array[Vector2] = [Vector2.ZERO]
	var points: Array[Vector2] = [Vector2(7, 0), Vector2(12, 0)]
	assert_eq(_choose_walking(points, player, [30.0]), 1, "the second has no walk: short")


func test_ac10_equal_distance_players_resolve_to_the_earlier_registered_one() -> void:
	# The point (0, 0) is 11 from both players. With the first player (-11, 0) it is boxed; with
	# the second one (0, 11) it is not, because the box is 10 high.
	var points: Array[Vector2] = [Vector2.ZERO, Vector2(-11, 10.5)]
	var west: Vector2 = Vector2(-11, 0)
	var north: Vector2 = Vector2(0, 11)
	assert_eq(_choose(points, [west, north] as Array[Vector2]), 0, "the west one is first")
	assert_eq(_choose(points, [north, west] as Array[Vector2]), 1, "the north one is first")


# --- AC27 (CR-1): the director asks the room's walls -----------------------------------------


## 40 x 22: a wall 2 thick at x = 19..20 from y = 1 to 17, with a gap below it (y = 18..20).
func _walled_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for y: int in 22:
		var row: String = "#" + ".".repeat(38) + "#"
		if y == 0 or y == 21:
			row = "#".repeat(40)
		elif y <= 17:
			row = row.substr(0, 19) + "##" + row.substr(21)
		rows.append(row)
	return rows


## A walled rig: the player east of the wall at (22.5, 5.5), a point behind the wall at (14.5, 5.5)
## 8 tiles away and a point on the player side at (31.5, 5.5) 9 away.
func _walled_rig(with_nav: bool) -> WaveFixtures.Rig:
	var points: Array[Vector2] = [Vector2(14.5, 5.5), Vector2(31.5, 5.5)]
	var placed_at: Array[Vector2] = [Vector2(36.5, 19.5)]
	var rig: WaveFixtures.Rig = WaveFixtures.rig(
		placed_at, 2, 3, _rules, points, 0.01, Vector2(22.5, 5.5)
	)
	if with_nav:
		rig.arena.sim.set_nav(NavGrid.from_rows(_walled_rows()))
	return rig


func test_ac27_with_a_wall_in_the_way_the_arrival_goes_to_the_point_with_a_short_walk() -> void:
	var rig: WaveFixtures.Rig = _walled_rig(true)
	var nav: NavGrid = rig.arena.sim.get_nav()
	assert_gt(nav.walk_distance(Vector2(14.5, 5.5), Vector2(22.5, 5.5)), 18.0, "behind the wall")
	assert_lt(nav.walk_distance(Vector2(31.5, 5.5), Vector2(22.5, 5.5)), 18.0, "on this side")
	rig.wake(rig.placed[0])
	rig.tick()
	assert_eq(rig.recorder.starts.size(), 1)
	assert_eq(rig.recorder.starts[0]["point"], Vector2(31.5, 5.5), "boxed, with a short walk")


func test_ac27_the_same_rig_without_a_nav_grid_chooses_the_straight_line_nearest() -> void:
	var rig: WaveFixtures.Rig = _walled_rig(false)
	assert_null(rig.arena.sim.get_nav())
	rig.wake(rig.placed[0])
	rig.tick()
	assert_eq(rig.recorder.starts.size(), 1)
	assert_eq(rig.recorder.starts[0]["point"], Vector2(14.5, 5.5), "as before the walk tier")


func test_ac27_the_director_asks_the_nav_grid_only_when_it_is_about_to_choose() -> void:
	var rig: WaveFixtures.Rig = _walled_rig(true)
	var nav: NavGrid = rig.arena.sim.get_nav()
	rig.run(2.0)
	assert_false(rig.waves.has_started())
	assert_eq(nav.get_field_builds(), 0, "nobody woke: no field was built for nothing")
	rig.wake(rig.placed[0])
	rig.tick()
	assert_gt(nav.get_field_builds(), 0, "a choice was made")


# --- AC27 (CR-12): a point's walk is to its own nearest player ----------------------------


func test_ac27_a_points_walk_is_measured_to_its_own_nearest_player() -> void:
	# Players on both sides of the wall: the first east at (22.5, 5.5), the second west at (7.5, 5.5).
	# The point (14.5, 5.5) is 7 from the second one by a short walk and 8 from the first by a walk
	# of over 18. Asked of the nearest player (the second) it is a short walk and wins as the
	# nearest; asked of the first player it would be a long one and the east point would win.
	var rig: WaveFixtures.Rig = _walled_rig(true)
	rig.arena.add_player(Vector2(7.5, 5.5), &"player_2")
	var nav: NavGrid = rig.arena.sim.get_nav()
	var behind_the_wall: Vector2 = Vector2(14.5, 5.5)
	assert_gt(nav.walk_distance(behind_the_wall, Vector2(22.5, 5.5)), 18.0, "long to the first")
	assert_lt(nav.walk_distance(behind_the_wall, Vector2(7.5, 5.5)), 18.0, "short to the second")
	rig.wake(rig.placed[0])
	rig.tick()
	assert_eq(rig.recorder.starts.size(), 1)
	assert_eq(
		rig.recorder.starts[0]["point"], behind_the_wall, "the walk to its own nearest player"
	)
