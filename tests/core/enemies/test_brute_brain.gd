extends GutTest
## F-006 C5 on the brain alone (AC1), and AC1, AC3, AC18 on a running sim.

const TIME: float = EnemyArena.TIME
const TILES: float = EnemyArena.TILES
const STEP: float = EnemyArena.STEP
const NOT_READY: float = 100.0
const STOMP: int = BruteArena.STOMP
const CHARGE: int = BruteArena.CHARGE

var _arena: BruteArena
var _enemy: EnemyLogic
var _brain: BruteBrain


func before_each() -> void:
	_arena = BruteArena.new()
	_brain = BruteBrain.new()


func test_c13_brute_is_appended_and_the_factory_maps_it() -> void:
	assert_eq(EnemyData.Brain.CHASER, 0)
	assert_eq(EnemyData.Brain.CASTER, 1)
	assert_eq(EnemyData.Brain.BRUTE, 2)
	assert_true(EnemyBrain.for_data(BruteArena.brute_values()) is BruteBrain)


func test_c9_a_brute_needs_every_attack_melee() -> void:
	var data: EnemyData = BruteArena.brute_values()
	assert_eq(data.validate(120, Tunables.enemy_combat), PackedStringArray())
	data.attacks.append(CasterArena.caster_values().attacks[0])
	var errors: PackedStringArray = data.validate(120, Tunables.enemy_combat)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "brain BRUTE needs a melee attack, caster_bolt")


func test_c5_1_no_living_player_means_no_target() -> void:
	_enemy = _arena.add_brute(Vector2.ZERO)
	assert_false(_decide().has_target())


func test_ac1_selection_of_an_aggroed_ready_brute() -> void:
	_assert_attack(1.0, STOMP)
	_assert_attack(1.5, STOMP)
	_assert_walks_in(2.0, 0.5)
	_assert_attack(3.0, CHARGE)
	_assert_attack(7.0, CHARGE)
	_assert_walks_in(7.5, 6.0)


func test_ac1_bounds_within_the_epsilon() -> void:
	_assert_attack(1.5 + 0.0000005, STOMP)
	_assert_walks_in(1.5 + 0.0001, 0.0001)
	_assert_attack(3.0 - 0.0000005, CHARGE)
	_assert_walks_in(3.0 - 0.0001, 1.5 - 0.0001)
	_assert_attack(7.0 + 0.0000005, CHARGE)


func test_ac1_a_brute_that_is_not_aggroed_idles_beyond_its_radius() -> void:
	_enemy_at_distance(7.5)
	var intent: EnemyIntent = _decide()
	assert_false(intent.has_target())
	assert_false(intent.start_attack)
	_arena.ticks(1)
	assert_eq(_enemy.get_state(), EnemyLogic.State.IDLE)
	assert_false(_enemy.is_aggroed())
	_assert_tiles(_enemy.get_position_tiles(), Vector2(0, 7.5), "no move")


func test_ac1_at_exactly_seven_it_aggroes_and_charges_in_that_decision() -> void:
	_enemy_at_distance(7.0)
	assert_false(_enemy.is_aggroed())
	_arena.ticks(1)
	assert_true(_enemy.is_aggroed())
	assert_eq(_enemy.get_state(), EnemyLogic.State.WINDUP)
	assert_eq(_enemy.get_running_attack().id, &"brute_charge")


func test_ac1_registration_order_never_changes_the_choice() -> void:
	for distance: float in [1.0, 2.0, 5.0]:
		var player_first: BruteArena = BruteArena.new()
		player_first.add_player(Vector2.ZERO)
		var first: EnemyLogic = player_first.add_brute(Vector2(0, distance))
		var brute_first: BruteArena = BruteArena.new()
		var second: EnemyLogic = brute_first.add_brute(Vector2(0, distance))
		brute_first.add_player(Vector2.ZERO)
		player_first.restore_value(first, "aggroed", true)
		brute_first.restore_value(second, "aggroed", true)
		player_first.ticks(1)
		brute_first.ticks(1)
		var label: String = str(distance)
		assert_eq(first.get_state(), second.get_state(), label)
		assert_eq(first.get_running_attack() == null, second.get_running_attack() == null, label)
		if first.get_running_attack() != null:
			assert_eq(first.get_running_attack().id, second.get_running_attack().id, label)
		assert_eq(first.get_position_tiles(), second.get_position_tiles(), label)


func test_c5_4_holds_inside_the_stop_distance_and_keeps_the_target() -> void:
	for distance: float in [0.5, 1.0, 1.5, 1.5 + 0.0000005]:
		_enemy_at_distance(distance)
		_enemy._aggroed = true
		_enemy._cooldown_remaining = NOT_READY
		var intent: EnemyIntent = _decide()
		assert_false(intent.start_attack, str(distance))
		assert_eq(intent.max_move_distance, 0.0, str(distance))
		assert_eq(intent.target_id, &"player_1", str(distance))


func test_c5_4_never_retreats_and_a_zero_direction_holds() -> void:
	_enemy_at_distance(0.0)
	_enemy._cooldown_remaining = NOT_READY
	var intent: EnemyIntent = _decide()
	assert_eq(intent.move_direction, Vector2.ZERO)
	assert_eq(intent.max_move_distance, 0.0)
	assert_eq(intent.target_id, &"player_1")


func test_c5_4_walks_in_at_move_speed_and_stops_at_the_stop_distance() -> void:
	for rate: int in EnemyArena.RATES:
		var arena: BruteArena = BruteArena.new()
		arena.add_player(Vector2.ZERO)
		var brute: EnemyLogic = arena.add_brute(Vector2(0, 2.5))
		arena.restore_value(brute, "cooldown_remaining", NOT_READY)
		arena.play(rate, 0, 6)
		_assert_tiles(brute.get_position_tiles(), Vector2(0, 2.1), "%d: 2.0 tiles/s" % rate)
		arena.play(rate, 6, 30)
		_assert_tiles(brute.get_position_tiles(), Vector2(0, 1.5), "%d: holds at 1.5" % rate)
		assert_eq(brute.get_state(), EnemyLogic.State.CHASE)


## AC3: the charge's knockback is 0 here, so the target stays next to where the charge ends.
func test_ac3_no_stomp_until_the_shared_cooldown_has_passed() -> void:
	for rate: int in EnemyArena.RATES:
		var label: String = "%d ticks/s" % rate
		var arena: BruteArena = BruteArena.new()
		arena.brute_data.attacks[CHARGE].knockback_tiles = 0.0
		arena.add_player(Vector2.ZERO)
		var brute: EnemyLogic = arena.add_brute(Vector2(7.0, 0))
		var watch: EnemyWatch = arena.watch(brute)
		arena.play(rate, 0, 66)  # 2.2 s: the charge is in recovery.
		assert_eq(arena.hurt_times.size(), 1, "%s: the charge hit" % label)
		assert_eq(brute.get_state(), EnemyLogic.State.RECOVERY, label)
		var end: Vector2 = brute.get_position_tiles()
		assert_lt(end.length(), 1.5, "%s: it ended inside the stomp band" % label)
		arena.play(rate, 66, 105)  # 3.5 s: the stomp is in its windup.
		var recovery_start: float = watch.times_entered(EnemyLogic.State.RECOVERY)[0]
		var windups: Array = watch.times_entered(EnemyLogic.State.WINDUP)
		assert_eq(windups.size(), 2, label)
		assert_almost_eq(windups[1] - recovery_start, 0.9 + 1.0, STEP + TIME, label)
		assert_true(watch.times_entered(EnemyLogic.State.CHASE).size() >= 1, "%s: held" % label)
		assert_eq(brute.get_running_attack().id, &"brute_stomp", label)
		_assert_tiles(brute.get_position_tiles(), end, "%s: never moved meanwhile" % label)


func test_ac18_targets_the_nearest_player_and_keeps_it_for_the_whole_attack() -> void:
	var walker: PlayerMotor = _arena.add_player(Vector2(5.0, 0), &"player_1")
	_arena.add_player(Vector2(0, 4.0), &"player_2")
	var brute: EnemyLogic = _arena.add_brute(Vector2.ZERO)
	_arena.restore_value(brute, "aggroed", true)
	_arena.ticks(1)
	assert_eq(brute.get_running_attack().id, &"brute_charge")
	assert_eq(brute.get_target_id(), &"player_2")
	# player_1 walks in to 2.5 tiles during the windup: nearer, but the target stays.
	for _i: int in 60:
		_arena.tick(120, Vector2.LEFT)
		assert_eq(brute.get_target_id(), &"player_2")
	assert_lt(walker.get_position_tiles().x, 3.0)
	assert_almost_eq(brute.get_aim().x, 0.0, TIME, "aimed at player_2")
	while brute.get_running_attack() != null:
		assert_eq(brute.get_target_id(), &"player_2")
		_arena.tick()


func test_ac18_ties_go_to_the_player_registered_first() -> void:
	for ids: Array in [[&"player_1", &"player_2"], [&"player_2", &"player_1"]]:
		var arena: BruteArena = BruteArena.new()
		arena.add_player(Vector2(5.0, 0), ids[0])
		arena.add_player(Vector2(-5.0, 0), ids[1])
		var brute: EnemyLogic = arena.add_brute(Vector2.ZERO)
		arena.ticks(1)
		assert_eq(brute.get_target_id(), ids[0])


func _assert_attack(distance: float, index: int) -> void:
	_enemy_at_distance(distance)
	_enemy._aggroed = true
	var intent: EnemyIntent = _decide()
	assert_true(intent.start_attack, str(distance))
	assert_eq(intent.attack_index, index, str(distance))
	assert_eq(intent.target_id, &"player_1", str(distance))


func _assert_walks_in(distance: float, max_move: float) -> void:
	_enemy_at_distance(distance)
	_enemy._aggroed = true
	var intent: EnemyIntent = _decide()
	assert_false(intent.start_attack, str(distance))
	assert_eq(intent.move_direction, Vector2.UP, str(distance))
	assert_almost_eq(intent.max_move_distance, max_move, TIME, str(distance))


func _enemy_at_distance(distance: float) -> void:
	_arena = BruteArena.new()
	_arena.add_player(Vector2.ZERO)
	_enemy = _arena.add_brute(Vector2(0, distance))


func _decide() -> EnemyIntent:
	return _brain.decide(_enemy, CombatView.capture(_arena.sim.get_combatants()))


func _assert_tiles(actual: Vector2, expected: Vector2, label: String) -> void:
	assert_almost_eq(actual.x, expected.x, TILES, label)
	assert_almost_eq(actual.y, expected.y, TILES, label)
