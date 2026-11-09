extends GutTest
## F-006 AC15: the wall-stun rules of C9, with their exact limits. AC4, AC10, AC11: the shipped
## files hold the design doc's values.

const RATE: int = 120
const CHARGE: int = BruteArena.CHARGE


func test_the_shipped_files_are_valid_and_hold_the_design_values() -> void:
	var data: EnemyData = load(Tunables.BRUTE_PATH)
	assert_eq(data.validate(RATE, Tunables.enemy_combat), PackedStringArray())
	assert_eq(data.validate_against_class(load(Tunables.WARRIOR_PATH)), PackedStringArray())
	assert_eq(data.id, &"brute")
	assert_eq(data.brain, EnemyData.Brain.BRUTE)
	assert_eq(data.max_hp, 120)
	assert_eq(data.hurtbox_radius_tiles, 0.6)
	assert_eq(data.knockback_scale, 0.0)
	assert_eq(data.move_speed, 2.0)
	assert_eq(data.aggro_radius_tiles, 7.0)
	assert_eq(data.stop_distance_tiles, 1.5)
	assert_eq(data.retreat_distance_tiles, 0.0)
	assert_eq(data.attack_cooldown, 1.0)
	var stomp: EnemyAttackData = load(Tunables.BRUTE_STOMP_PATH)
	var charge: EnemyAttackData = load(Tunables.BRUTE_CHARGE_PATH)
	assert_eq(data.attacks.size(), 2)
	assert_eq(data.attacks[0].id, stomp.id, "stomp first")
	assert_eq(data.attacks[1].id, charge.id, "then charge")
	_assert_values(
		charge,
		{
			"id": &"brute_charge",
			"windup": 0.8,
			"aim_track_time": 0.5,
			"active": 0.5,
			"recovery": 0.9,
			"wall_stun_duration": 1.5,
			"damage": 25,
			"arc_angle_deg": 120.0,
			"range_tiles": 0.9,
			"knockback_tiles": 1.5,
			"lunge_tiles": 6.0,
			"trigger_min_tiles": 3.0,
			"trigger_max_tiles": 7.0,
			"projectile_speed_tiles": 0.0,
			"is_finisher": false,
		}
	)
	_assert_values(
		stomp,
		{
			"id": &"brute_stomp",
			"windup": 0.6,
			"aim_track_time": 0.0,
			"active": 0.1,
			"recovery": 0.7,
			"wall_stun_duration": 0.0,
			"damage": 20,
			"arc_angle_deg": 360.0,
			"range_tiles": 1.6,
			"knockback_tiles": 1.2,
			"lunge_tiles": 0.0,
			"trigger_min_tiles": 0.0,
			"trigger_max_tiles": 1.5,
			"projectile_speed_tiles": 0.0,
			"is_finisher": false,
		}
	)


func test_ac15_the_stub_charge_is_valid() -> void:
	assert_eq(_charge().validate_enemy(RATE, Tunables.enemy_combat), PackedStringArray())


func test_ac15_a_negative_stun_is_rejected() -> void:
	var charge: EnemyAttackData = _charge()
	charge.wall_stun_duration = -0.001
	_assert_one_error(charge, "wall_stun_duration must be >= 0")
	charge.wall_stun_duration = 0.0
	_assert_valid(charge, "0 means no stun")


func test_ac15_a_stun_on_a_projectile_is_rejected() -> void:
	var bolt: EnemyAttackData = CasterArena.caster_values().attacks[0]
	bolt.wall_stun_duration = 1.0
	_assert_one_error(bolt, "wall_stun_duration > 0 needs a melee attack")


func test_ac15_a_stun_with_no_lunge_is_rejected() -> void:
	var charge: EnemyAttackData = _charge()
	charge.lunge_tiles = 0.0
	_assert_one_error(charge, "wall_stun_duration > 0 needs lunge_tiles > 0")


func test_ac15_a_stun_needs_two_steps_of_recovery_at_the_rate_validated() -> void:
	var charge: EnemyAttackData = _charge()
	charge.recovery = 2.0 / 120.0
	charge.wall_stun_duration = charge.recovery
	_assert_valid(charge, "exactly 2 steps, stun exactly recovery")
	charge.recovery = 2.0 / 120.0 - 0.0001
	_assert_one_error(charge, "recovery must be >= 2 combat steps")
	assert_eq(
		charge.validate_enemy(240, Tunables.enemy_combat), PackedStringArray(), "2 steps at 240"
	)
	charge.recovery = 2.0 / 240.0 - 0.0001
	assert_eq(charge.validate_enemy(240, Tunables.enemy_combat).size(), 1, "under 2 at 240")


func test_ac15_a_stun_shorter_than_recovery_is_rejected() -> void:
	var charge: EnemyAttackData = _charge()
	charge.wall_stun_duration = 0.9
	_assert_valid(charge, "stun exactly recovery")
	charge.wall_stun_duration = 0.899
	_assert_one_error(charge, "wall_stun_duration must be >= recovery")


func test_ac15_the_recovery_rule_is_only_for_wall_stun_attacks() -> void:
	var charge: EnemyAttackData = _charge()
	charge.wall_stun_duration = 0.0
	charge.recovery = 0.0
	_assert_valid(charge, "no stun, no minimum")
	assert_eq(charge.wall_stun_recovery_errors(RATE), PackedStringArray())


func test_ac15_errors_name_the_attack_in_enemy_data() -> void:
	var data: EnemyData = BruteArena.brute_values()
	data.attacks[CHARGE].wall_stun_duration = 0.5
	var errors: PackedStringArray = data.validate(RATE, Tunables.enemy_combat)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "brute_charge: wall_stun_duration must be >= recovery")


func _charge() -> EnemyAttackData:
	return BruteArena.brute_values().attacks[CHARGE]


func _assert_valid(attack: EnemyAttackData, label: String) -> void:
	assert_eq(attack.validate_enemy(RATE, Tunables.enemy_combat), PackedStringArray(), label)


func _assert_one_error(attack: EnemyAttackData, error: String) -> void:
	var errors: PackedStringArray = attack.validate_enemy(RATE, Tunables.enemy_combat)
	assert_eq(errors.size(), 1, str(errors))
	if errors.size() == 1:
		assert_string_contains(errors[0], error)


func _assert_values(attack: EnemyAttackData, values: Dictionary) -> void:
	for key: String in values:
		assert_eq(attack.get(key), values[key], "%s.%s" % [attack.id, key])
