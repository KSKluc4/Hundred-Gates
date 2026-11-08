extends GutTest
## F-005 C7 on the brain alone, and AC3–AC6 on a running sim.

const TIME: float = EnemyArena.TIME
const TILES: float = EnemyArena.TILES
const FAR: Vector2 = Vector2(0, 100)
const NOT_READY: float = 100.0

var _arena: CasterArena
var _enemy: EnemyLogic
var _brain: CasterBrain


func before_each() -> void:
	_arena = CasterArena.new()
	_brain = CasterBrain.new()


func test_the_factory_maps_caster_to_this_brain() -> void:
	assert_true(EnemyBrain.for_data(CasterArena.caster_values()) is CasterBrain)
	assert_true(EnemyBrain.for_data(EnemyArena.chaser_values()) is ChaserBrain)


func test_c7_1_no_living_player_means_no_target() -> void:
	_enemy = _arena.add_caster(Vector2.ZERO)
	assert_false(_decide().has_target())


func test_c7_2_outside_the_radius_and_not_aggroed_means_no_target() -> void:
	_arena.add_player(FAR)
	_enemy = _arena.add_caster(Vector2.ZERO)
	assert_false(_decide().has_target())
	_enemy._aggroed = true
	assert_eq(_decide().target_id, &"player_1", "once aggroed the radius stops mattering")


func test_c7_2_aggro_boundaries_on_both_sides() -> void:
	_assert_aggroes_at(8.0, true)
	_assert_aggroes_at(8.0 + 0.0000005, true)
	_assert_aggroes_at(8.0 + 0.0001, false)


func test_c7_3_attack_range_boundaries_on_both_sides() -> void:
	_assert_attacks_at(7.0, true)
	_assert_attacks_at(7.0 + 0.0000005, true)
	_assert_attacks_at(7.0 + 0.0001, false)


func test_ac4_shooting_beats_retreating() -> void:
	_enemy_at_distance(1.0)
	var intent: EnemyIntent = _decide()
	assert_true(intent.start_attack)
	assert_eq(intent.target_id, &"player_1")


func test_c7_4_retreat_straight_away_at_most_to_the_retreat_distance() -> void:
	_enemy_at_distance(2.5)
	_enemy._cooldown_remaining = NOT_READY
	var intent: EnemyIntent = _decide()
	assert_false(intent.start_attack)
	assert_eq(intent.move_direction, Vector2.DOWN, "away from the player above it")
	assert_almost_eq(intent.max_move_distance, 0.5, TIME)


func test_c7_5_approach_at_most_to_the_stop_distance() -> void:
	_enemy_at_distance(6.5)
	_enemy._cooldown_remaining = NOT_READY
	var intent: EnemyIntent = _decide()
	assert_eq(intent.move_direction, Vector2.UP)
	assert_almost_eq(intent.max_move_distance, 0.5, TIME)


func test_c7_6_inside_the_band_it_holds_and_keeps_the_target() -> void:
	for distance: float in [3.0, 4.5, 6.0]:
		_enemy_at_distance(distance)
		_enemy._cooldown_remaining = NOT_READY
		var intent: EnemyIntent = _decide()
		assert_eq(intent.max_move_distance, 0.0, str(distance))
		assert_eq(intent.target_id, &"player_1", str(distance))


func test_c7_band_boundaries_within_the_epsilon_hold() -> void:
	for distance: float in [3.0 - 0.0000005, 6.0 + 0.0000005]:
		_enemy_at_distance(distance)
		_enemy._cooldown_remaining = NOT_READY
		assert_eq(_decide().max_move_distance, 0.0, str(distance))


func test_c7_a_zero_direction_holds_still() -> void:
	_enemy_at_distance(0.0)
	_enemy._cooldown_remaining = NOT_READY
	var intent: EnemyIntent = _decide()
	assert_eq(intent.move_direction, Vector2.ZERO)
	assert_eq(intent.max_move_distance, 0.0)
	assert_eq(intent.target_id, &"player_1")


func test_c7_a_retreat_distance_of_zero_never_retreats() -> void:
	_arena.caster_data.retreat_distance_tiles = 0.0
	_arena.add_player()
	_enemy = _arena.add_caster(Vector2(0, 0.5))
	_enemy._cooldown_remaining = NOT_READY
	assert_eq(_decide().max_move_distance, 0.0)


func test_ac3_band_on_a_running_sim_at_every_rate() -> void:
	for rate: int in EnemyArena.RATES:
		var label: String = "%d ticks/s" % rate
		_assert_settles(rate, 2.5, 3.0, "%s: backs off to 3.0" % label)
		_assert_settles(rate, 6.5, 6.0, "%s: walks in to 6.0" % label)
		for distance: float in [3.0, 3.0 + 0.0001, 4.5, 6.0 - 0.0001, 6.0]:
			_assert_settles(rate, distance, distance, "%s: holds at %s" % [label, distance])
		_assert_settles(rate, 3.0 - 0.0001, 3.0, "%s: just inside 3" % label)
		_assert_settles(rate, 6.0 + 0.0001, 6.0, "%s: just outside 6" % label)


func test_ac3_it_backs_off_straight_at_move_speed() -> void:
	_arena.add_player()
	_enemy = _arena.add_caster(Vector2(0, 2.5))
	_arena.restore_value(_enemy, "cooldown_remaining", NOT_READY)
	_arena.ticks(12)
	_assert_tiles(_enemy.get_position_tiles(), Vector2(0, 2.75), "2.5 tiles/s for 0.1 s")
	assert_eq(_enemy.get_state(), EnemyLogic.State.CHASE)


func test_ac4_on_a_running_sim_windup_starts_at_distance_one() -> void:
	_arena.add_player()
	_enemy = _arena.add_caster(Vector2(0, 1.0))
	_arena.ticks(1)
	assert_eq(_enemy.get_state(), EnemyLogic.State.WINDUP)
	_assert_tiles(_enemy.get_position_tiles(), Vector2(0, 1.0), "rooted, no retreat")


func test_ac6_caught_on_foot() -> void:
	for rate: int in EnemyArena.RATES:
		var label: String = "%d ticks/s" % rate
		var arena: CasterArena = CasterArena.new()
		var player: PlayerMotor = arena.add_player()
		var caster: EnemyLogic = arena.add_caster(Vector2(0, 2.5))
		arena.restore_value(caster, "cooldown_remaining", 1.0)
		var distances: Array[float] = []
		for thirtieth: int in 15:
			arena.play(rate, thirtieth, thirtieth + 1, {thirtieth: Vector2.DOWN})
			var caster_at: Vector2 = caster.get_position_tiles()
			assert_almost_eq(caster_at.x, 0.0, TILES, "%s: straight along (0, 1)" % label)
			assert_almost_eq(
				caster_at.y, 2.5 + 2.5 * (thirtieth + 1) / 30.0, TILES, "%s: 2.5 tiles/s" % label
			)
			distances.append(caster_at.distance_to(player.get_position_tiles()))
		assert_almost_eq(distances[0], 2.5278, TILES, "%s: grows while it accelerates" % label)
		for index: int in range(1, 15):
			var time: float = (index + 1) / 30.0
			assert_almost_eq(distances[index], 2.625 - 2.5 * time, TILES, label)
			assert_lt(distances[index], distances[index - 1], "%s: shrinks at %d" % [label, index])
		_assert_tiles(player.get_position_tiles(), Vector2(0, 2.375), label)
		_assert_tiles(caster.get_position_tiles(), Vector2(0, 3.75), label)
		assert_almost_eq(distances[14], 1.375, TILES, label)
		assert_lt(distances[14], 1.4, "%s: inside sword hit 1's range" % label)
		assert_eq(caster.get_state(), EnemyLogic.State.CHASE, "%s: never attacked" % label)
		assert_true(caster.get_running_attack() == null, label)


## A fresh run with the caster `distance` tiles below a still player and its cooldown not
## ready. After 2 s it must be at `expected`.
func _assert_settles(rate: int, distance: float, expected: float, label: String) -> void:
	var arena: CasterArena = CasterArena.new()
	arena.add_player()
	var caster: EnemyLogic = arena.add_caster(Vector2(0, distance))
	arena.restore_value(caster, "cooldown_remaining", NOT_READY)
	arena.play(rate, 0, 60)
	assert_almost_eq(caster.get_position_tiles().y, expected, 0.00001, label)
	assert_eq(caster.get_position_tiles().x, 0.0, label)


func _assert_aggroes_at(distance: float, expected: bool) -> void:
	_enemy_at_distance(distance)
	assert_eq(_decide().has_target(), expected, str(distance))


func _assert_attacks_at(distance: float, expected: bool) -> void:
	_enemy_at_distance(distance)
	_enemy._aggroed = true
	assert_eq(_decide().start_attack, expected, str(distance))


func _enemy_at_distance(distance: float) -> void:
	_arena = CasterArena.new()
	_arena.add_player(Vector2.ZERO)
	_enemy = _arena.add_caster(Vector2(0, distance))


func _decide() -> EnemyIntent:
	return _brain.decide(_enemy, CombatView.capture(_arena.sim.get_combatants()))


func _assert_tiles(actual: Vector2, expected: Vector2, label: String) -> void:
	assert_almost_eq(actual.x, expected.x, TILES, label)
	assert_almost_eq(actual.y, expected.y, TILES, label)
