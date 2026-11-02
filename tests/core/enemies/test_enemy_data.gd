extends GutTest
## AC1, AC1b: every C12 bound on both sides, and the shipped data.

const RATE: int = 120


func test_the_shipped_files_are_valid_and_hold_the_design_values() -> void:
	var data: EnemyData = load(Tunables.CHASER_PATH)
	assert_eq(data.validate(RATE, Tunables.enemy_combat), PackedStringArray())
	assert_eq(data.id, &"chaser")
	assert_eq(data.brain, EnemyData.Brain.CHASER)
	assert_eq(data.max_hp, 50)
	assert_eq(data.hurtbox_radius_tiles, 0.4)
	assert_eq(data.knockback_scale, 1.0)
	assert_eq(data.move_speed, 3.0)
	assert_eq(data.aggro_radius_tiles, 6.0)
	assert_eq(data.attack_range_tiles, 1.6)
	assert_eq(data.stop_distance_tiles, 1.0)
	assert_eq(data.attack_cooldown, 0.8)
	var swipe: EnemyAttackData = load(Tunables.CHASER_SWIPE_PATH)
	assert_eq(data.attack.id, swipe.id, "chaser.tres uses the swipe file")
	assert_eq(swipe.windup, 0.5)
	assert_eq(swipe.aim_track_time, 0.3)
	assert_eq(swipe.active, 0.1)
	assert_eq(swipe.recovery, 0.6)
	assert_eq(swipe.damage, 20)
	assert_eq(swipe.arc_angle_deg, 90.0)
	assert_eq(swipe.range_tiles, 1.2)
	assert_eq(swipe.knockback_tiles, 0.8)
	assert_eq(swipe.lunge_tiles, 0.8)
	assert_false(swipe.is_finisher)
	assert_eq(Tunables.enemy_combat.min_telegraph, 0.3)
	assert_eq(Tunables.enemy_combat.min_locked_telegraph, 0.15)


func test_ac1_enemy_combat_tunables_bounds() -> void:
	assert_true(_rules(0.0, 0.0).validate().is_empty(), "0 is a valid minimum")
	assert_true(_rules(0.3, 0.3).validate().is_empty(), "equal is valid")
	assert_false(_rules(-0.1, 0.0).validate().is_empty())
	assert_false(_rules(0.3, -0.1).validate().is_empty())
	assert_false(_rules(0.3, 0.31).validate().is_empty(), "locked can't exceed the telegraph")


func test_ac1_enemy_data_fields_on_both_sides_of_each_bound() -> void:
	_assert_field("id", &"x", &"")
	_assert_field("brain", EnemyData.Brain.CHASER, 99)
	_assert_field("max_hp", 1, 0)
	_assert_field("hurtbox_radius_tiles", 0.001, 0.0)
	_assert_field("knockback_scale", 0.0, -0.001)
	_assert_field("move_speed", 0.0, -0.001)
	_assert_field("aggro_radius_tiles", 0.0, -0.001)
	_assert_field("attack_range_tiles", 0.001, 0.0)
	_assert_field("stop_distance_tiles", 0.0, -0.001)
	_assert_field("attack_cooldown", 0.0, -0.001)


func test_ac1_attack_must_be_set_and_valid() -> void:
	var data: EnemyData = EnemyArena.chaser_values()
	data.attack = null
	assert_false(data.validate(RATE, Tunables.enemy_combat).is_empty())
	data = EnemyArena.chaser_values()
	data.attack.damage = 0
	var errors: PackedStringArray = data.validate(RATE, Tunables.enemy_combat)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "chaser_swipe")


func test_ac1_attack_data_rules_still_apply() -> void:
	_assert_attack_field("id", &"x", &"")
	_assert_attack_field("active", 1.0 / RATE, 0.0)
	_assert_attack_field("recovery", 0.0, -0.001)
	_assert_attack_field("damage", 1, 0)
	_assert_attack_field("arc_angle_deg", 360.0, 360.1)
	_assert_attack_field("arc_angle_deg", 0.1, 0.0)
	_assert_attack_field("range_tiles", 0.001, 0.0)
	_assert_attack_field("knockback_tiles", 0.0, -0.001)


func test_ac1_enemy_attack_rules() -> void:
	_assert_attack_field("aim_track_time", 0.0, -0.001)
	_assert_attack_field("lunge_tiles", 0.0, -0.001)
	_assert_attack_field("is_finisher", false, true)


func test_ac1_c8_windup_floor_with_the_exact_minimum_passing() -> void:
	_assert_attack_field("windup", 0.45, 0.449)  # aim_track_time 0.3 + locked 0.15.
	var attack: EnemyAttackData = EnemyArena.chaser_values().attack
	attack.aim_track_time = 0.1
	attack.windup = 0.3
	assert_true(attack.validate_enemy(RATE, Tunables.enemy_combat).is_empty(), "exact minimum")
	attack.windup = 0.299
	assert_false(attack.validate_enemy(RATE, Tunables.enemy_combat).is_empty())


func test_ac1_c8_locked_tail_with_the_exact_minimum_passing() -> void:
	_assert_attack_field("aim_track_time", 0.35, 0.351)  # windup 0.5 - locked 0.15.


func test_ac1_c8_rejects_a_telegraph_that_only_fits_the_old_minimums() -> void:
	var data: EnemyData = EnemyArena.chaser_values()
	var stricter: EnemyCombatTunables = _rules(0.6, 0.15)
	assert_false(data.validate(RATE, stricter).is_empty(), "windup 0.5 < 0.6")
	stricter = _rules(0.3, 0.25)
	assert_false(data.validate(RATE, stricter).is_empty(), "locked 0.2 < 0.25")


func test_ac1b_speed_rule_against_a_class_at_five() -> void:
	var warrior: ClassData = _class_at(5.0)
	assert_true(_enemy_at(3.0).validate_against_class(warrior).is_empty())
	assert_true(_enemy_at(4.99).validate_against_class(warrior).is_empty())
	_assert_speed_error(_enemy_at(5.0), warrior)
	_assert_speed_error(_enemy_at(6.0), warrior)


func test_ac1b_speed_rule_against_a_class_lowered_to_three() -> void:
	var warrior: ClassData = _class_at(3.0)
	_assert_speed_error(_enemy_at(3.0), warrior)
	assert_true(_enemy_at(2.99).validate_against_class(warrior).is_empty())


func test_ac1b_the_speed_rule_is_not_part_of_validate() -> void:
	assert_true(_enemy_at(9.0).validate(RATE, Tunables.enemy_combat).is_empty(), "§3 rejected")


func _assert_field(field: String, valid: Variant, invalid: Variant) -> void:
	var data: EnemyData = EnemyArena.chaser_values()
	data.set(field, valid)
	assert_true(data.validate(RATE, Tunables.enemy_combat).is_empty(), "%s valid" % field)
	data.set(field, invalid)
	assert_false(data.validate(RATE, Tunables.enemy_combat).is_empty(), "%s invalid" % field)


func _assert_attack_field(field: String, valid: Variant, invalid: Variant) -> void:
	var attack: EnemyAttackData = EnemyArena.chaser_values().attack
	attack.set(field, valid)
	assert_true(attack.validate_enemy(RATE, Tunables.enemy_combat).is_empty(), "%s valid" % field)
	attack.set(field, invalid)
	assert_false(
		attack.validate_enemy(RATE, Tunables.enemy_combat).is_empty(), "%s invalid" % field
	)


func _assert_speed_error(enemy: EnemyData, class_data: ClassData) -> void:
	var errors: PackedStringArray = enemy.validate_against_class(class_data)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], String(enemy.id))
	assert_string_contains(errors[0], str(enemy.move_speed))
	assert_string_contains(errors[0], str(class_data.move_speed))


func _enemy_at(speed: float) -> EnemyData:
	var data: EnemyData = EnemyArena.chaser_values()
	data.move_speed = speed
	return data


func _class_at(speed: float) -> ClassData:
	var data: ClassData = CombatArena.warrior()
	data.move_speed = speed
	return data


func _rules(min_telegraph: float, min_locked: float) -> EnemyCombatTunables:
	var rules: EnemyCombatTunables = EnemyCombatTunables.new()
	rules.min_telegraph = min_telegraph
	rules.min_locked_telegraph = min_locked
	return rules
