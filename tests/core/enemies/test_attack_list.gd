extends GutTest
## F-006 T1: the attack list (C4), pick_attack() (AC1 with stub data, AC2) and the list and band
## rules of C9 (AC15).

const RATE: int = 120
const EPSILON: float = Geometry.DISTANCE_EPSILON


func test_c4_shipped_chaser_and_caster_are_one_item_lists_with_their_old_range() -> void:
	var chaser: EnemyData = load(Tunables.CHASER_PATH)
	assert_eq(chaser.attacks.size(), 1)
	assert_eq(chaser.attacks[0].trigger_min_tiles, 0.0)
	assert_eq(chaser.attacks[0].trigger_max_tiles, 1.6)
	var caster: EnemyData = load(Tunables.CASTER_PATH)
	assert_eq(caster.attacks.size(), 1)
	assert_eq(caster.attacks[0].trigger_min_tiles, 0.0)
	assert_eq(caster.attacks[0].trigger_max_tiles, 7.0)


func test_ac1_pick_attack_uses_the_band_bounds_inclusively() -> void:
	var data: EnemyData = _stub([[0.0, 1.5], [3.0, 7.0]])
	assert_eq(EnemyBrain.pick_attack(data, 0.0), 0)
	assert_eq(EnemyBrain.pick_attack(data, 1.0), 0)
	assert_eq(EnemyBrain.pick_attack(data, 1.5), 0, "exact max")
	assert_eq(EnemyBrain.pick_attack(data, 1.5 + EPSILON * 0.5), 0, "within epsilon")
	assert_eq(EnemyBrain.pick_attack(data, 2.0), -1, "between bands")
	assert_eq(EnemyBrain.pick_attack(data, 3.0 - EPSILON * 0.5), 1, "within epsilon")
	assert_eq(EnemyBrain.pick_attack(data, 3.0), 1, "exact min")
	assert_eq(EnemyBrain.pick_attack(data, 7.0), 1, "exact max")
	assert_eq(EnemyBrain.pick_attack(data, 7.5), -1, "beyond every band")


func test_ac1_order_of_the_list_not_of_the_bands_decides_index() -> void:
	var data: EnemyData = _stub([[3.0, 7.0], [0.0, 1.5]])
	assert_eq(EnemyBrain.pick_attack(data, 1.0), 1)
	assert_eq(EnemyBrain.pick_attack(data, 5.0), 0)


func test_ac2_with_overlapping_bands_the_first_in_list_order_wins() -> void:
	var data: EnemyData = _stub([[0.0, 5.0], [2.0, 7.0]])
	assert_eq(EnemyBrain.pick_attack(data, 3.0), 0)
	assert_eq(EnemyBrain.pick_attack(data, 6.0), 1)
	data = _stub([[2.0, 7.0], [0.0, 5.0]])
	assert_eq(EnemyBrain.pick_attack(data, 3.0), 0)
	assert_eq(EnemyBrain.pick_attack(data, 1.0), 1)


func test_ac2_a_chaser_starts_the_first_matching_attack_of_its_list() -> void:
	var arena: EnemyArena = EnemyArena.new()
	var second: EnemyAttackData = arena.chaser_data.attacks[0].duplicate()
	second.id = &"second_swipe"
	arena.chaser_data.attacks[0].id = &"first_swipe"
	arena.chaser_data.attacks.append(second)
	arena.add_player(Vector2.ZERO)
	var chaser: EnemyLogic = arena.add_chaser(Vector2(1.0, 0.0))
	arena.tick()
	assert_eq(chaser.get_state(), EnemyLogic.State.WINDUP)
	assert_eq(chaser.get_running_attack().id, &"first_swipe")
	# Only the second band holds 1.0 now.
	arena.chaser_data.attacks[0].trigger_min_tiles = 1.2
	var other: EnemyLogic = arena.add_chaser(Vector2(-1.0, 0.0), &"chaser_2")
	arena.tick()
	assert_eq(other.get_running_attack().id, &"second_swipe")


func test_ac15_an_empty_list_is_rejected() -> void:
	var data: EnemyData = EnemyArena.chaser_values()
	data.attacks = []
	_assert_one_error(data, "attacks must not be empty")


func test_ac15_a_null_entry_is_rejected() -> void:
	var data: EnemyData = EnemyArena.chaser_values()
	data.attacks.append(null)
	_assert_one_error(data, "attacks[1] must not be null")


func test_ac15_every_entry_is_validated_and_errors_name_the_attack() -> void:
	var data: EnemyData = EnemyArena.chaser_values()
	var second: EnemyAttackData = data.attacks[0].duplicate()
	second.id = &"bad_second"
	second.damage = 0
	data.attacks.append(second)
	_assert_one_error(data, "bad_second: damage must be >= 1")


func test_ac15_band_bounds_on_both_sides() -> void:
	_assert_band(0.0, 1.0, "")
	_assert_band(-0.001, 1.0, "trigger_min_tiles must be >= 0")
	_assert_band(0.0, 0.001, "")
	_assert_band(0.0, 0.0, "trigger_max_tiles must be > 0")
	_assert_band(1.0, 1.0, "")
	_assert_band(1.001, 1.0, "trigger_min_tiles must be <= trigger_max_tiles")


func test_ac15_kind_is_checked_for_every_attack_in_the_list() -> void:
	var chaser: EnemyData = EnemyArena.chaser_values()
	chaser.attacks.append(CasterArena.caster_values().attacks[0])
	_assert_one_error(chaser, "CHASER needs a melee attack, caster_bolt is a projectile")
	var caster: EnemyData = CasterArena.caster_values()
	caster.attacks.append(EnemyArena.chaser_values().attacks[0])
	_assert_one_error(caster, "CASTER needs a projectile attack, chaser_swipe is melee")


func test_c10_the_latched_attack_snapshot_holds_the_band() -> void:
	var attack: EnemyAttackData = EnemyArena.chaser_values().attacks[0]
	attack.trigger_min_tiles = 0.25
	var copy: EnemyAttackData = EnemyAttackData.from_snapshot(attack.to_dict())
	assert_eq(copy.trigger_min_tiles, 0.25)
	assert_eq(copy.trigger_max_tiles, 1.6)


func _stub(bands: Array) -> EnemyData:
	var data: EnemyData = EnemyArena.chaser_values()
	var attacks: Array[EnemyAttackData] = []
	for band: Array in bands:
		var attack: EnemyAttackData = data.attacks[0].duplicate()
		attack.trigger_min_tiles = band[0]
		attack.trigger_max_tiles = band[1]
		attacks.append(attack)
	data.attacks = attacks
	assert_eq(data.validate(RATE, Tunables.enemy_combat), PackedStringArray(), "stub is valid")
	return data


func _assert_band(min_tiles: float, max_tiles: float, error: String) -> void:
	var attack: EnemyAttackData = EnemyArena.chaser_values().attacks[0]
	attack.trigger_min_tiles = min_tiles
	attack.trigger_max_tiles = max_tiles
	var errors: PackedStringArray = attack.validate_enemy(RATE, Tunables.enemy_combat)
	if error.is_empty():
		assert_eq(errors, PackedStringArray(), "[%s, %s] is valid" % [min_tiles, max_tiles])
		return
	assert_eq(errors.size(), 1, "[%s, %s]" % [min_tiles, max_tiles])
	if errors.size() == 1:
		assert_string_contains(errors[0], error)


func _assert_one_error(data: EnemyData, error: String) -> void:
	var errors: PackedStringArray = data.validate(RATE, Tunables.enemy_combat)
	assert_eq(errors.size(), 1, str(errors))
	if errors.size() == 1:
		assert_string_contains(errors[0], error)
