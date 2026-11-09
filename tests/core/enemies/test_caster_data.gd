extends GutTest
## F-005 AC1: every C9 bound on both sides, the shipped files, and setup() refusing bad data.

const RATE: int = 120


func test_the_shipped_files_are_valid_and_hold_the_design_values() -> void:
	var data: EnemyData = load(Tunables.CASTER_PATH)
	assert_eq(data.validate(RATE, Tunables.enemy_combat), PackedStringArray())
	assert_eq(data.id, &"caster")
	assert_eq(data.brain, EnemyData.Brain.CASTER)
	assert_eq(data.max_hp, 30)
	assert_eq(data.hurtbox_radius_tiles, 0.35)
	assert_eq(data.knockback_scale, 1.2)
	assert_eq(data.move_speed, 2.5)
	assert_eq(data.aggro_radius_tiles, 8.0)
	assert_eq(data.attacks[0].trigger_max_tiles, 7.0)
	assert_eq(data.stop_distance_tiles, 6.0)
	assert_eq(data.retreat_distance_tiles, 3.0)
	assert_eq(data.attack_cooldown, 1.2)
	var bolt: EnemyAttackData = load(Tunables.CASTER_BOLT_PATH)
	assert_eq(data.attacks[0].id, bolt.id, "caster.tres uses the bolt file")
	assert_eq(bolt.windup, 0.6)
	assert_eq(bolt.aim_track_time, 0.35)
	assert_eq(bolt.active, 0.1)
	assert_eq(bolt.recovery, 0.8)
	assert_eq(bolt.damage, 18)
	assert_eq(bolt.arc_angle_deg, 360.0)
	assert_eq(bolt.range_tiles, 0.25)
	assert_eq(bolt.knockback_tiles, 0.5)
	assert_eq(bolt.lunge_tiles, 0.0)
	assert_eq(bolt.projectile_speed_tiles, 6.0)
	assert_eq(bolt.projectile_max_distance_tiles, 10.0)
	assert_false(bolt.is_finisher)
	assert_true(bolt.is_projectile())


func test_ac1_the_chaser_files_still_pass_with_no_edit() -> void:
	var chaser: EnemyData = load(Tunables.CHASER_PATH)
	assert_eq(chaser.validate(RATE, Tunables.enemy_combat), PackedStringArray())
	assert_eq(chaser.retreat_distance_tiles, 0.0, "never retreats")
	var swipe: EnemyAttackData = load(Tunables.CHASER_SWIPE_PATH)
	assert_eq(swipe.projectile_speed_tiles, 0.0)
	assert_eq(swipe.projectile_max_distance_tiles, 0.0)
	assert_false(swipe.is_projectile())
	assert_eq(EnemyData.Brain.CHASER, 0, "C13: appended, CHASER stays 0")


func test_ac1_retreat_distance_between_zero_and_the_stop_distance() -> void:
	_assert_field("retreat_distance_tiles", 0.0, -0.001)
	_assert_field("retreat_distance_tiles", 6.0, 6.001)
	var chaser: EnemyData = EnemyArena.chaser_values()
	chaser.retreat_distance_tiles = 1.0
	assert_true(_valid(chaser), "= its stop distance 1.0")
	chaser.retreat_distance_tiles = 1.001
	assert_false(_valid(chaser))


func test_ac1_projectile_fields_are_never_negative() -> void:
	_assert_attack_field("projectile_speed_tiles", 0.001, -0.001)
	_assert_attack_field("projectile_max_distance_tiles", 0.001, -0.001)
	var swipe: EnemyAttackData = EnemyArena.chaser_values().attacks[0]
	swipe.projectile_speed_tiles = -0.001
	assert_false(_attack_valid(swipe))


func test_ac1_a_melee_attack_has_no_max_distance() -> void:
	var swipe: EnemyAttackData = EnemyArena.chaser_values().attacks[0]
	assert_true(_attack_valid(swipe))
	swipe.projectile_max_distance_tiles = 0.5
	var errors: PackedStringArray = _attack_errors(swipe)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "must be 0 for a melee attack")


func test_ac1_a_projectile_attack_is_a_full_circle() -> void:
	_assert_attack_field("arc_angle_deg", 360.0, 359.9)


func test_ac1_a_projectile_attack_never_lunges() -> void:
	_assert_attack_field("lunge_tiles", 0.0, 0.001)


func test_ac1_a_projectile_attack_has_a_max_distance() -> void:
	_assert_attack_field("projectile_max_distance_tiles", 0.001, 0.0)


func test_ac1_sampling_limit_at_120_with_the_exact_limit_passing() -> void:
	_assert_attack_field("projectile_speed_tiles", 30.0, 30.001)  # 30 / 120 = radius 0.25.
	_assert_attack_field("range_tiles", 0.05, 0.0499)  # Speed 6 / 120.


func test_ac1_sampling_limit_at_240_with_the_exact_limit_passing() -> void:
	var bolt: EnemyAttackData = CasterArena.caster_values().attacks[0]
	bolt.projectile_speed_tiles = 60.0
	assert_true(_attack_valid(bolt, 240), "60 / 240 = radius 0.25")
	assert_false(_attack_valid(bolt, 120), "the same at 120 moves 0.5 per step")
	bolt.projectile_speed_tiles = 60.001
	assert_false(_attack_valid(bolt, 240))
	var errors: PackedStringArray = _attack_errors(bolt, 240)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "more than its radius")


func test_ac1_a_chaser_with_a_projectile_attack_is_rejected() -> void:
	var data: EnemyData = EnemyArena.chaser_values()
	data.attacks = [CasterArena.caster_values().attacks[0]]
	var errors: PackedStringArray = data.validate(RATE, Tunables.enemy_combat)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "CHASER needs a melee attack")


func test_ac1_a_caster_with_a_melee_attack_is_rejected() -> void:
	var data: EnemyData = CasterArena.caster_values()
	data.attacks = [EnemyArena.chaser_values().attacks[0]]
	var errors: PackedStringArray = data.validate(RATE, Tunables.enemy_combat)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "CASTER needs a projectile attack")


func test_ac1_attack_errors_name_the_bolt() -> void:
	var data: EnemyData = CasterArena.caster_values()
	data.attacks[0].lunge_tiles = 0.5
	var errors: PackedStringArray = data.validate(RATE, Tunables.enemy_combat)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "caster_bolt")


func test_ac1_invalid_data_fails_setup_and_changes_nothing() -> void:
	var arena: CasterArena = CasterArena.new()
	arena.add_player()
	var caster: EnemyLogic = arena.add_caster(Vector2(0, 6.52))
	arena.ticks(80)
	var before: Dictionary = caster.to_dict()
	var bad: EnemyData = CasterArena.caster_values()
	bad.retreat_distance_tiles = 7.0
	var rules: EnemyCombatTunables = arena.enemy_rules
	assert_false(caster.setup(bad, rules, RATE, Vector2.ZERO, &"caster_1"))
	assert_push_error("data rejected")
	assert_false(caster.apply_data(bad, rules, RATE))
	assert_push_error("data rejected")
	assert_eq(caster.get_data(), arena.caster_data)
	assert_eq_deep(caster.to_dict(), before)
	var fresh: EnemyLogic = EnemyLogic.new()
	assert_false(fresh.setup(bad, rules, RATE, Vector2.ZERO, &"caster_2"))
	assert_push_error("data rejected")
	assert_null(fresh.get_data())


func _assert_field(field: String, valid: Variant, invalid: Variant) -> void:
	var data: EnemyData = CasterArena.caster_values()
	data.set(field, valid)
	assert_true(_valid(data), "%s = %s valid" % [field, valid])
	data.set(field, invalid)
	assert_false(_valid(data), "%s = %s invalid" % [field, invalid])


func _assert_attack_field(field: String, valid: Variant, invalid: Variant) -> void:
	var bolt: EnemyAttackData = CasterArena.caster_values().attacks[0]
	bolt.set(field, valid)
	assert_true(_attack_valid(bolt), "%s = %s valid" % [field, valid])
	bolt.set(field, invalid)
	assert_false(_attack_valid(bolt), "%s = %s invalid" % [field, invalid])


func _valid(data: EnemyData) -> bool:
	return data.validate(RATE, Tunables.enemy_combat).is_empty()


func _attack_valid(attack: EnemyAttackData, rate: int = RATE) -> bool:
	return _attack_errors(attack, rate).is_empty()


func _attack_errors(attack: EnemyAttackData, rate: int = RATE) -> PackedStringArray:
	return attack.validate_enemy(rate, Tunables.enemy_combat)
