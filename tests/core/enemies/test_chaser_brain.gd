extends GutTest
## C5's decision order, C9's targets and AC4b's epsilons, on the brain alone: it reads a view
## and its enemy, and nothing else.

const FAR: Vector2 = Vector2(0, 100)

var _arena: EnemyArena
var _enemy: EnemyLogic
var _brain: ChaserBrain


func before_each() -> void:
	_arena = EnemyArena.new()
	_brain = ChaserBrain.new()


func test_no_living_player_means_no_target() -> void:
	_enemy = _arena.add_chaser(Vector2.ZERO)
	var intent: EnemyIntent = _decide()
	assert_false(intent.has_target())
	assert_false(intent.start_attack)
	assert_eq(intent.max_move_distance, 0.0)


func test_ac2_outside_the_radius_and_not_aggroed_means_no_target() -> void:
	_arena.add_player(FAR)
	_enemy = _arena.add_chaser(Vector2.ZERO)
	assert_false(_decide().has_target())


func test_ac2_inside_the_radius_it_chases() -> void:
	_arena.add_player(Vector2(0, 5))
	_enemy = _arena.add_chaser(Vector2.ZERO)
	var intent: EnemyIntent = _decide()
	assert_eq(intent.target_id, &"player_1")
	assert_eq(intent.move_direction, Vector2.DOWN)
	assert_almost_eq(intent.max_move_distance, 4.0, 0.000001, "distance - stop distance")


func test_ac2_once_aggroed_the_radius_stops_mattering() -> void:
	_arena.add_player(FAR)
	_enemy = _arena.add_chaser(Vector2.ZERO)
	_enemy._aggroed = true
	assert_eq(_decide().target_id, &"player_1")


func test_ac7_in_range_with_the_cooldown_ready_it_attacks() -> void:
	_arena.add_player(Vector2(0, 1.6))
	_enemy = _arena.add_chaser(Vector2.ZERO)
	var intent: EnemyIntent = _decide()
	assert_true(intent.start_attack)
	assert_eq(intent.target_id, &"player_1")
	assert_eq(intent.max_move_distance, 0.0, "rooted")


func test_ac10_in_range_on_cooldown_it_keeps_walking() -> void:
	_arena.add_player(Vector2(0, 1.6))
	_enemy = _arena.add_chaser(Vector2.ZERO)
	_enemy._cooldown_remaining = 0.5
	var intent: EnemyIntent = _decide()
	assert_false(intent.start_attack)
	assert_almost_eq(intent.max_move_distance, 0.6, 0.000001)


func test_c5_a_cooldown_within_time_epsilon_is_ready() -> void:
	_arena.add_player(Vector2(0, 1.6))
	_enemy = _arena.add_chaser(Vector2.ZERO)
	_enemy._cooldown_remaining = CombatTiming.TIME_EPSILON * 0.5
	assert_true(_decide().start_attack)


func test_ac3_nearest_living_player() -> void:
	_arena.add_player(Vector2(0, 3), &"far")
	_arena.add_player(Vector2(0, 2), &"near")
	_enemy = _arena.add_chaser(Vector2.ZERO)
	assert_eq(_decide().target_id, &"near")


func test_ac3_equal_distances_go_to_the_player_registered_first() -> void:
	_arena.add_player(Vector2(3, 0), &"first")
	_arena.add_player(Vector2(-3, 0), &"second")
	_enemy = _arena.add_chaser(Vector2.ZERO)
	assert_eq(_decide().target_id, &"first")


func test_ac3_equal_distances_within_the_epsilon_also_go_to_the_first() -> void:
	_arena.add_player(Vector2(3.0000005, 0), &"first")
	_arena.add_player(Vector2(-3, 0), &"second")
	_enemy = _arena.add_chaser(Vector2.ZERO)
	assert_eq(_decide().target_id, &"first")


func test_ac3_a_target_at_zero_hp_is_skipped() -> void:
	var dead: PlayerMotor = _arena.add_player(Vector2(0, 2), &"near")
	_arena.add_player(Vector2(0, 3), &"far")
	_enemy = _arena.add_chaser(Vector2.ZERO)
	_kill(dead)
	assert_eq(_decide().target_id, &"far")


func test_c9_enemies_and_dummies_are_never_targets() -> void:
	var dummy: DummyLogic = DummyLogic.new()
	dummy.setup(CombatArena.dummy_values(), 120, Vector2(0, 1), 0.0, &"dummy")
	_arena.sim.setup(120, _arena.rules)
	_arena.sim.register(dummy)
	_arena.add_chaser(Vector2(1, 0), &"other")
	_enemy = _arena.add_chaser(Vector2.ZERO)
	assert_false(_decide().has_target())


func test_ac4b_range_boundaries_on_both_sides() -> void:
	_assert_in_attack_range(1.6, true)
	_assert_in_attack_range(1.6 + 0.0000005, true)
	_assert_in_attack_range(1.6 + 0.0001, false)


func test_ac4b_aggro_boundaries_on_both_sides() -> void:
	_assert_aggroes_at(6.0, true)
	_assert_aggroes_at(6.0 + 0.0000005, true)
	_assert_aggroes_at(6.0 + 0.0001, false)


func test_ac4b_stop_boundaries_on_both_sides() -> void:
	_enemy_at_distance(1.0)
	_enemy._cooldown_remaining = 1.0
	assert_eq(_decide().max_move_distance, 0.0)
	_enemy_at_distance(1.0 + 0.0000005)
	_enemy._cooldown_remaining = 1.0
	assert_eq(_decide().max_move_distance, 0.0, "within the epsilon")
	_enemy_at_distance(1.0 + 0.0001)
	_enemy._cooldown_remaining = 1.0
	assert_gt(_decide().max_move_distance, 0.00009, "outside it")


func test_c5_closer_than_the_stop_distance_it_moves_nothing_and_keeps_its_target() -> void:
	_enemy_at_distance(0.5)
	_enemy._cooldown_remaining = 1.0
	var intent: EnemyIntent = _decide()
	assert_eq(intent.max_move_distance, 0.0)
	assert_eq(intent.target_id, &"player_1")


func _assert_in_attack_range(distance: float, expected: bool) -> void:
	_enemy_at_distance(distance)
	assert_eq(_decide().start_attack, expected, str(distance))


func _assert_aggroes_at(distance: float, expected: bool) -> void:
	_enemy_at_distance(distance)
	assert_eq(_decide().has_target(), expected, str(distance))


func _enemy_at_distance(distance: float) -> void:
	_arena = EnemyArena.new()
	_arena.add_player(Vector2.ZERO)
	_enemy = _arena.add_chaser(Vector2(0, distance))


func _decide() -> EnemyIntent:
	return _brain.decide(_enemy, CombatView.capture(_arena.sim.get_combatants()))


func _kill(motor: PlayerMotor) -> void:
	var event: HitEvent = HitEvent.new()
	event.damage = 1000
	motor.apply_hit(event, _arena.rules)
