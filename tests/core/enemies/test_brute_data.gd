extends GutTest
## F-006 AC15: the wall-stun rules of C9, with their exact limits.

const RATE: int = 120
const CHARGE: int = BruteArena.CHARGE


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
