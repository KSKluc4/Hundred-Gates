extends GutTest
## AC1's setup, AC2, AC4, AC4b, AC6, and the C4 rules: when an enemy may decide.

const TIME: float = EnemyArena.TIME
const STEP: float = EnemyArena.STEP
const SPEED_PER_STEP: float = 3.0 / 120.0
const NOT_A_RANGE: float = 0.01  # Closer than the stop distance: it never gets to attack.


func test_ac1_invalid_data_fails_setup_and_changes_nothing() -> void:
	var arena: EnemyArena = EnemyArena.new()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(1, 2))
	var before: Dictionary = enemy.to_dict()
	var bad: EnemyData = EnemyArena.chaser_values()
	bad.max_hp = 0
	assert_false(enemy.setup(bad, arena.enemy_rules, 120, Vector2(9, 9), &"other"))
	assert_push_error("data rejected")
	assert_eq_deep(enemy.to_dict(), before)
	assert_eq(enemy.get_data(), arena.chaser_data)
	assert_eq(enemy.get_combat_id(), &"chaser_1")


func test_ac1_missing_or_invalid_rules_fail_setup_too() -> void:
	var enemy: EnemyLogic = EnemyLogic.new()
	var data: EnemyData = EnemyArena.chaser_values()
	assert_false(enemy.setup(null, Tunables.enemy_combat, 120, Vector2.ZERO, &"a"))
	assert_push_error("data rejected")
	assert_false(enemy.setup(data, null, 120, Vector2.ZERO, &"a"))
	assert_push_error("data rejected")
	var bad: EnemyCombatTunables = EnemyCombatTunables.new()
	bad.min_telegraph = -1.0
	assert_false(enemy.setup(data, bad, 120, Vector2.ZERO, &"a"))
	assert_push_error("data rejected")
	assert_null(enemy.get_data())


func test_setup_gives_a_fresh_enemy_on_the_enemy_team() -> void:
	var enemy: EnemyLogic = EnemyArena.new().add_chaser(Vector2(1, 2))
	assert_eq(enemy.get_team(), Combatant.Team.ENEMY)
	assert_eq(enemy.get_state(), EnemyLogic.State.IDLE)
	assert_eq(enemy.get_position_tiles(), Vector2(1, 2))
	assert_eq(enemy.get_aim(), Vector2.DOWN, "C5: initial facing")
	assert_eq(enemy.get_combat_state().get_hp(), 50)
	assert_false(enemy.get_combat_state().is_hurt_protected(), "no hurt i-frames")
	assert_true(enemy.is_alive())
	assert_true(enemy.is_ai_enabled())


func test_ac2_idle_until_a_player_comes_within_the_radius() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2(0, 6.2))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO)
	arena.ticks(10)
	assert_eq(enemy.get_state(), EnemyLogic.State.IDLE)
	assert_eq(enemy.get_position_tiles(), Vector2.ZERO)
	assert_false(enemy.is_aggroed())
	for _i: int in 12:
		arena.tick(120, Vector2.UP)
	assert_eq(enemy.get_state(), EnemyLogic.State.CHASE)
	assert_true(enemy.is_aggroed())


func test_ac2_taking_damage_aggroes_from_the_next_step_start() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.aggro_radius_tiles = 0.0
	arena.chaser_data.attacks[0].trigger_max_tiles = NOT_A_RANGE
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1))
	var watch: EnemyWatch = arena.watch(enemy)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(9)
	assert_eq(enemy.get_combat_state().get_hp(), 40, "hit 1 lands at 10/120")
	assert_true(enemy.is_aggroed())
	arena.ticks(40)
	assert_eq(enemy.get_state(), EnemyLogic.State.CHASE, "after hitstop and knockback")
	assert_eq(watch.times_entered(EnemyLogic.State.CHASE).size(), 1)


func test_ac2_once_aggroed_moving_out_of_the_radius_doesnt_stop_it() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attacks[0].trigger_max_tiles = NOT_A_RANGE
	var player: PlayerMotor = arena.add_player(Vector2(0, 5))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO)
	for _i: int in 120:
		arena.tick(120, Vector2.DOWN)
	assert_gt(player.get_position_tiles().distance_to(enemy.get_position_tiles()), 6.0)
	assert_eq(enemy.get_state(), EnemyLogic.State.CHASE)


func test_ac4_chases_straight_at_move_speed_then_holds_at_the_stop_distance() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attacks[0].trigger_max_tiles = NOT_A_RANGE
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(3, 4))
	var watch: EnemyWatch = arena.watch(enemy)
	arena.ticks(120)
	var along: Vector2 = Vector2(-0.6, -0.8)
	assert_almost_eq(enemy.get_position_tiles().x, 3.0 + along.x * 3.0, 0.0001)
	assert_almost_eq(enemy.get_position_tiles().y, 4.0 + along.y * 3.0, 0.0001)
	arena.ticks(120)
	var stop: Vector2 = Vector2(3, 4) * 0.2
	assert_almost_eq(enemy.get_position_tiles().x, stop.x, 0.0001)
	assert_almost_eq(enemy.get_position_tiles().y, stop.y, 0.0001)
	for index: int in range(1, 241):
		var distance: float = (watch.at(index)["position"] as Vector2).length()
		assert_true(distance >= 1.0 - Geometry.DISTANCE_EPSILON * 10.0, "never closer: %s" % index)
	assert_eq(enemy.get_state(), EnemyLogic.State.CHASE, "holding is still chasing")
	var held: Vector2 = enemy.get_position_tiles()
	arena.ticks(20)
	assert_eq(enemy.get_position_tiles(), held)


func test_ac4b_exact_attack_range_after_accumulated_steps_at_every_rate() -> void:
	for rate: int in EnemyArena.RATES:
		assert_almost_eq(_windup_time(rate, 0.0), 56.0 / 120.0, TIME, "%d ticks/s" % rate)
		assert_almost_eq(_windup_time(rate, 0.0001), 57.0 / 120.0, TIME, "%d ticks/s" % rate)


func test_ac4b_exact_stop_distance_after_accumulated_steps_at_every_rate() -> void:
	for rate: int in EnemyArena.RATES:
		assert_eq(_moved_after_arriving(rate, 0.0), 0.0, "arrived, %d ticks/s" % rate)
		assert_gt(_moved_after_arriving(rate, 0.0001), 0.00009, "not yet, %d ticks/s" % rate)


func test_ac4b_exact_aggro_radius_after_accumulated_steps_at_every_rate() -> void:
	for rate: int in EnemyArena.RATES:
		assert_true(_aggroes_after_walking(rate, 0.0), "in, %d ticks/s" % rate)
		assert_false(_aggroes_after_walking(rate, 0.0001), "out, %d ticks/s" % rate)


func test_ac6_recovery_ending_mid_step_holds_still_until_the_next_step_start() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attacks[0].recovery = 0.6 + STEP * 0.5
	arena.chaser_data.attacks[0].range_tiles = 0.01
	arena.chaser_data.attacks[0].lunge_tiles = 0.0
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	var watch: EnemyWatch = arena.watch(enemy)
	arena.ticks(146)
	assert_eq(watch.at(144)["state"], EnemyLogic.State.RECOVERY)
	assert_eq(watch.at(145)["state"], EnemyLogic.State.IDLE, "free inside that step")
	assert_eq(watch.at(145)["position"], Vector2(0, 1.6), "and held still for the rest of it")
	assert_almost_eq(float(watch.at(145)["cooldown"]), 0.8 - STEP * 0.5, TIME, "overshoot carries")
	assert_eq(watch.at(146)["state"], EnemyLogic.State.CHASE, "decided at the next step start")
	assert_almost_eq(float(watch.at(146)["position"].y), 1.6 - SPEED_PER_STEP, 0.000001)


func test_ac6_knockback_ending_mid_step_holds_still_until_the_next_step_start() -> void:
	var arena: EnemyArena = _chasing_arena()
	var enemy: EnemyLogic = arena.enemies[0]
	var watch: EnemyWatch = arena.watch(enemy)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(32)  # Hit at 10/120, 6 steps of hitstop, 14.4 steps of push.
	assert_eq(watch.at(30)["state"], EnemyLogic.State.KNOCKBACK)
	assert_eq(watch.at(31)["state"], EnemyLogic.State.IDLE)
	assert_almost_eq(float(watch.at(31)["position"].y), 2.0, 0.0001, "the whole 0.3 tiles")
	assert_eq(watch.at(32)["state"], EnemyLogic.State.CHASE)


func test_ac6_hitstop_ending_mid_step_holds_still_until_the_next_step_start() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.rules.hitstop_normal = 0.05 + STEP * 0.5
	arena.chaser_data.knockback_scale = 0.0
	arena.chaser_data.attacks[0].trigger_max_tiles = NOT_A_RANGE
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.95))
	var watch: EnemyWatch = arena.watch(enemy)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(18)
	var hit_at: Vector2 = watch.at(10)["position"]
	assert_eq(watch.at(16)["state"], EnemyLogic.State.IDLE, "still in hitstop")
	assert_eq(watch.at(17)["state"], EnemyLogic.State.IDLE, "hitstop ended inside this step")
	assert_eq(watch.at(17)["position"], hit_at, "and it held still for the rest of it")
	assert_eq(watch.at(18)["state"], EnemyLogic.State.CHASE, "decided at the next step start")
	assert_almost_eq(float(watch.at(18)["position"].y), hit_at.y - SPEED_PER_STEP, 0.000001)


func test_c4_with_ai_off_a_free_enemy_holds_still_and_starts_nothing() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1))
	enemy.set_ai_enabled(false)
	arena.ticks(30)
	assert_eq(enemy.get_state(), EnemyLogic.State.IDLE)
	assert_eq(enemy.get_position_tiles(), Vector2(0, 1))
	assert_false(enemy.is_aggroed(), "no decision, so no aggro")
	enemy.set_ai_enabled(true)
	arena.ticks(1)
	assert_eq(enemy.get_state(), EnemyLogic.State.WINDUP)


func test_c4_with_ai_off_a_running_attack_still_finishes() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	arena.ticks(10)
	enemy.set_ai_enabled(false)
	arena.ticks(61)
	assert_eq(arena.hurt_times.size(), 1, "the swing lands")
	arena.ticks(200)
	assert_eq(enemy.get_state(), EnemyLogic.State.IDLE, "and it stops once free")
	assert_lt(enemy.get_cooldown_remaining(), 0.8)


func test_c4_with_ai_off_a_chasing_enemy_stops_at_the_next_step_start() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 3))
	arena.ticks(5)
	assert_eq(enemy.get_state(), EnemyLogic.State.CHASE)
	enemy.set_ai_enabled(false)
	var held: Vector2 = enemy.get_position_tiles()
	arena.ticks(5)
	assert_eq(enemy.get_state(), EnemyLogic.State.IDLE)
	assert_eq(enemy.get_position_tiles(), held)


func _chasing_arena() -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attacks[0].trigger_max_tiles = NOT_A_RANGE
	arena.add_player()
	arena.add_chaser(Vector2(0, 1.95))
	return arena


func _windup_time(rate: int, extra: float) -> float:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2(0, -extra))
	var watch: EnemyWatch = arena.watch(arena.add_chaser(Vector2(0, 3)))
	arena.play(rate, 0, 15)
	return watch.times_entered(EnemyLogic.State.WINDUP)[0]


## How far it still moved in the step after it should have arrived.
func _moved_after_arriving(rate: int, extra: float) -> float:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attacks[0].trigger_max_tiles = NOT_A_RANGE
	arena.add_player(Vector2(0, -extra))
	var watch: EnemyWatch = arena.watch(arena.add_chaser(Vector2(0, 3)))
	arena.play(rate, 0, 21)
	return absf(watch.at(81)["position"].y - watch.at(80)["position"].y)


## A player walking into the radius: its 12 steps end at exactly 6 tiles, or 0.0001 short.
## Near the origin on purpose: this is what a float32 position can hold to 1e-6.
func _aggroes_after_walking(rate: int, extra: float) -> bool:
	var arena: EnemyArena = EnemyArena.new()
	arena.class_data.move_accel_time = 0.0
	arena.class_data.move_decel_time = 0.0
	arena.add_player(Vector2(-0.5 - extra, 0))
	var enemy: EnemyLogic = arena.add_chaser(Vector2(6, 0))
	var moves: Dictionary = {0: Vector2.RIGHT, 1: Vector2.RIGHT, 2: Vector2.RIGHT}
	arena.play(rate, 0, 4, moves)
	return enemy.is_aggroed()
