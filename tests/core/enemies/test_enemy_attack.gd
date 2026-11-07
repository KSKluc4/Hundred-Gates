extends GutTest
## AC7–AC11: the attack's timeline, on a swing that reaches nobody. Default data: windup
## 60 steps, tracking 36 of them, active 12, recovery 72, cooldown 96.

const TIME: float = EnemyArena.TIME
const STEP: float = EnemyArena.STEP


func test_ac7_windup_begins_at_that_step_start_and_it_is_rooted() -> void:
	var arena: EnemyArena = _harmless()
	var watch: EnemyWatch = arena.watch(arena.add_chaser(Vector2(0, 1.6)))
	arena.ticks(59)
	assert_eq(watch.times_entered(EnemyLogic.State.WINDUP)[0], 0.0)
	assert_eq(watch.at(1)["state"], EnemyLogic.State.WINDUP)
	assert_eq(watch.at(59)["position"], Vector2(0, 1.6))
	assert_eq(watch.at(59)["target"], &"player_1")


func test_ac7_a_windup_ignores_a_target_that_walks_out_of_range() -> void:
	var arena: EnemyArena = _harmless()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	for _i: int in 30:
		arena.tick(120, Vector2.UP)
	assert_eq(enemy.get_state(), EnemyLogic.State.WINDUP)
	assert_eq(enemy.get_position_tiles(), Vector2(0, 1.6))


func test_ac8_aim_follows_the_sensed_target_until_the_lock_then_never_changes() -> void:
	var arena: EnemyArena = _harmless()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	var player: PlayerMotor = arena.players[0]
	for index: int in 36:
		var sensed: Vector2 = player.get_position_tiles()
		arena.tick(120, Vector2.RIGHT)
		assert_eq(enemy.get_aim(), Vector2(0, 1.6).direction_to(sensed), "step %d" % index)
		assert_eq(enemy.is_aim_locked(), index == 35, "locks at 0.3: step %d" % index)
	var locked: Vector2 = enemy.get_aim()
	assert_gt(locked.x, 0.1, "it really turned")
	for _i: int in 24:
		arena.tick(120, Vector2.RIGHT)
		assert_eq(enemy.get_aim(), locked)
	arena.tick(120, Vector2.RIGHT)
	assert_eq(enemy.get_state(), EnemyLogic.State.ACTIVE)
	assert_eq(enemy.get_live_hitbox().direction, locked, "the hitbox points along the lock")


func test_c5_a_target_on_top_of_it_leaves_the_aim_as_it_was() -> void:
	var arena: EnemyArena = _harmless()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 0))
	arena.ticks(5)
	assert_eq(enemy.get_state(), EnemyLogic.State.WINDUP)
	assert_eq(enemy.get_aim(), Vector2.DOWN, "zero direction, initial facing")


func test_assumption_an_aim_track_time_of_zero_aims_once_at_windup_start() -> void:
	var arena: EnemyArena = _harmless()
	arena.chaser_data.attack.aim_track_time = 0.0
	var enemy: EnemyLogic = arena.add_chaser(Vector2(1.6, 0))
	arena.tick()
	assert_eq(enemy.get_aim(), Vector2.LEFT)
	assert_true(enemy.is_aim_locked())
	for _i: int in 20:
		arena.tick(120, Vector2.UP)
	assert_eq(enemy.get_aim(), Vector2.LEFT)


func test_ac9_phases_run_on_latched_durations_with_the_hitbox_only_during_active() -> void:
	for rate: int in EnemyArena.RATES:
		var arena: EnemyArena = _harmless()
		var watch: EnemyWatch = arena.watch(arena.add_chaser(Vector2(0, 1.6)))
		arena.play(rate, 0, 40)
		_assert_steps(watch.times_entered(EnemyLogic.State.ACTIVE), [60], rate)
		_assert_steps(watch.times_entered(EnemyLogic.State.RECOVERY), [72], rate)
		for index: int in range(1, 160):
			assert_eq(watch.at(index)["has_hitbox"], index >= 60 and index < 72, "step %d" % index)


func test_ac9_the_lunge_moves_exactly_lunge_tiles_along_the_aim() -> void:
	var arena: EnemyArena = _harmless()
	var watch: EnemyWatch = arena.watch(arena.add_chaser(Vector2(0, 1.6)))
	arena.ticks(144)
	assert_eq(watch.at(60)["position"], Vector2(0, 1.6), "starts with active")
	assert_almost_eq(float(watch.at(66)["position"].y), 1.2, 0.00001, "half way, half the time")
	assert_almost_eq(float(watch.at(72)["position"].y), 0.8, 0.00001)
	assert_eq(watch.at(100)["position"], watch.at(72)["position"], "rooted in recovery")


func test_ac9_no_displacement_in_hitstop_and_the_lunge_finishes_after_it() -> void:
	var arena: EnemyArena = _harmless()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	var watch: EnemyWatch = arena.watch(enemy)
	arena.ticks(66)
	enemy.get_combat_state().apply_landed(HitEvent.new(), arena.rules)
	arena.ticks(14)
	assert_eq(watch.at(72)["position"], watch.at(66)["position"], "6 steps of hitstop")
	assert_almost_eq(float(watch.at(78)["position"].y), 0.8, 0.00001, "and the same lunge")
	_assert_steps(watch.times_entered(EnemyLogic.State.RECOVERY), [78], 120)


func test_ac9_no_hitbox_while_its_owner_is_in_hitstop() -> void:
	var arena: EnemyArena = _harmless()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	arena.ticks(61)
	assert_not_null(enemy.get_live_hitbox())
	enemy.get_combat_state().apply_landed(HitEvent.new(), arena.rules)
	assert_null(enemy.get_live_hitbox(), "F-003/C15")


func test_ac10_cooldown_starts_when_recovery_ends_and_it_walks_during_it() -> void:
	var arena: EnemyArena = _harmless()
	arena.chaser_data.attack.lunge_tiles = 0.0
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	var watch: EnemyWatch = arena.watch(enemy)
	arena.ticks(241)
	assert_eq(watch.at(143)["cooldown"], 0.0)
	assert_almost_eq(float(watch.at(144)["cooldown"]), 0.8, TIME)
	assert_eq(watch.at(150)["state"], EnemyLogic.State.CHASE)
	assert_lt(float(watch.at(150)["position"].y), 1.6, "it walks in during the cooldown")
	_assert_steps(watch.times_entered(EnemyLogic.State.WINDUP), [0, 240], 120)


func test_ac10_hitstop_pauses_the_cooldown() -> void:
	var arena: EnemyArena = _harmless()
	arena.chaser_data.attack.lunge_tiles = 0.0
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	var watch: EnemyWatch = arena.watch(enemy)
	arena.ticks(150)
	var before: float = enemy.get_cooldown_remaining()
	enemy.get_combat_state().apply_landed(HitEvent.new(), arena.rules)
	arena.ticks(6)
	assert_eq(enemy.get_cooldown_remaining(), before)
	arena.ticks(91)
	_assert_steps(watch.times_entered(EnemyLogic.State.WINDUP), [0, 246], 120)


func test_ac10_a_cooldown_of_zero_attacks_at_the_next_step_start() -> void:
	var arena: EnemyArena = _harmless()
	arena.chaser_data.attack_cooldown = 0.0
	var watch: EnemyWatch = arena.watch(arena.add_chaser(Vector2(0, 1.6)))
	arena.ticks(146)
	_assert_steps(watch.times_entered(EnemyLogic.State.WINDUP), [0, 144], 120)


func test_ac11_the_shortest_valid_telegraph_runs_at_its_full_length() -> void:
	var arena: EnemyArena = _harmless()
	arena.chaser_data.attack.windup = 0.3
	arena.chaser_data.attack.aim_track_time = 0.15
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	var watch: EnemyWatch = arena.watch(enemy)
	arena.ticks(40)
	assert_eq(enemy.get_data().validate(120, arena.enemy_rules), PackedStringArray())
	_assert_steps(watch.aim_lock_times, [18], 120)
	_assert_steps(watch.times_entered(EnemyLogic.State.ACTIVE), [36], 120)
	var locked: float = watch.times_entered(EnemyLogic.State.ACTIVE)[0] - watch.aim_lock_times[0]
	assert_true(locked >= arena.enemy_rules.min_locked_telegraph - TIME)
	assert_true(
		watch.times_entered(EnemyLogic.State.ACTIVE)[0] >= arena.enemy_rules.min_telegraph - TIME
	)


func test_c5_zero_recovery_and_a_windup_of_zero_cross_at_once() -> void:
	var arena: EnemyArena = _harmless()
	arena.enemy_rules.min_telegraph = 0.0
	arena.enemy_rules.min_locked_telegraph = 0.0
	arena.chaser_data.attack.windup = 0.0
	arena.chaser_data.attack.aim_track_time = 0.0
	arena.chaser_data.attack.recovery = 0.0
	var enemy: EnemyLogic = arena.add_chaser(Vector2(1.6, 0))
	var watch: EnemyWatch = arena.watch(enemy)
	arena.tick()
	assert_eq(enemy.get_state(), EnemyLogic.State.ACTIVE)
	assert_eq(enemy.get_aim(), Vector2.LEFT)
	arena.ticks(12)
	assert_eq(watch.times_entered(EnemyLogic.State.RECOVERY).size(), 0, "crossed inside one call")
	assert_almost_eq(enemy.get_cooldown_remaining(), 0.8 - STEP, 0.02)


## A player the swing can't reach: a 0.01 tile sector, and data set before any add_chaser().
func _harmless() -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attack.range_tiles = 0.01
	arena.add_player()
	return arena


func _assert_steps(actual: Array, expected_steps: Array, rate: int) -> void:
	assert_eq(actual.size(), expected_steps.size(), "%d ticks/s: %s" % [rate, actual])
	for index: int in mini(actual.size(), expected_steps.size()):
		assert_almost_eq(float(actual[index]), expected_steps[index] / 120.0, TIME, str(rate))
