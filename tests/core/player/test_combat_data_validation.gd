extends GutTest
## F-003/C18: attack and class bounds, both sides. Bounds using the step are checked at
## their exact minimum, so TIME_EPSILON has to let them pass.

const RATE: int = 120
const STEP: float = 1.0 / RATE


func test_valid_attack_has_no_errors() -> void:
	assert_eq(_attack().validate(RATE).size(), 0)


func test_each_attack_bound_is_rejected() -> void:
	var cases: Array[Array] = [
		["id", &""],
		["windup", -0.01],
		["recovery", -0.01],
		["damage", 0],
		["arc_angle_deg", 0.0],
		["arc_angle_deg", 360.5],
		["range_tiles", 0.0],
		["knockback_tiles", -0.01],
	]
	for case: Array in cases:
		var attack: AttackData = _attack()
		attack.set(case[0], case[1])
		assert_eq(attack.validate(RATE).size(), 1, "%s = %s" % case)


func test_attack_values_at_their_limits_are_valid() -> void:
	var cases: Array[Array] = [
		["windup", 0.0 + 1.0 / RATE],
		["recovery", 0.0],
		["damage", 1],
		["arc_angle_deg", 0.001],
		["arc_angle_deg", 360.0],
		["range_tiles", 0.001],
		["knockback_tiles", 0.0],
	]
	for case: Array in cases:
		var attack: AttackData = _attack()
		attack.set(case[0], case[1])
		assert_eq(attack.validate(RATE).size(), 0, "%s = %s" % case)


func test_ac26_active_below_one_step_is_rejected() -> void:
	var attack: AttackData = _attack()
	attack.active = 0.008
	assert_eq(attack.validate(RATE).size(), 1)
	attack.active = STEP
	assert_eq(attack.validate(RATE).size(), 0)


func test_ac26_zero_lead_needs_two_steps_of_active_time() -> void:
	var attack: AttackData = _attack()
	attack.windup = 0.0
	attack.active = STEP
	assert_eq(attack.validate(RATE).size(), 1)
	attack.active = 2.0 * STEP
	assert_eq(attack.validate(RATE).size(), 0)


func test_ac26_one_step_of_lead_and_one_of_active_is_valid() -> void:
	var attack: AttackData = _attack()
	attack.windup = STEP
	attack.active = STEP
	assert_eq(attack.validate(RATE).size(), 0)


func test_window_rules_follow_the_step_rate_they_are_given() -> void:
	var attack: AttackData = _attack()
	attack.windup = 0.036
	attack.active = 1.0 / 240.0
	assert_eq(attack.validate(240).size(), 0)
	assert_eq(attack.validate(120).size(), 1)


func test_window_errors_with_a_broken_rate_report_it_and_do_not_divide_by_zero() -> void:
	assert_eq(CombatTiming.window_errors(0.1, 0.1, 0).size(), 1)


func test_valid_class_has_no_combat_errors() -> void:
	assert_eq(_class_data().validate_combat(RATE).size(), 0)


func test_each_class_bound_is_rejected() -> void:
	var cases: Array[Array] = [
		["attack_chain_window", -0.01],
		["max_hp", 0],
		["hurtbox_radius_tiles", 0.0],
		["knockback_scale", -0.01],
	]
	for case: Array in cases:
		var data: ClassData = _class_data()
		data.set(case[0], case[1])
		assert_eq(data.validate_combat(RATE).size(), 1, "%s = %s" % case)


func test_class_values_at_their_limits_are_valid() -> void:
	var data: ClassData = _class_data()
	data.attack_chain_window = 0.0
	data.knockback_scale = 0.0
	data.max_hp = 1
	data.hurtbox_radius_tiles = 0.001
	assert_eq(data.validate_combat(RATE).size(), 0)


func test_empty_chain_is_rejected() -> void:
	var data: ClassData = _class_data()
	data.attack_chain = []
	assert_eq(data.validate_combat(RATE).size(), 1)


func test_null_chain_entry_is_rejected() -> void:
	var data: ClassData = _class_data()
	data.attack_chain = [_attack(), null]
	assert_eq(data.validate_combat(RATE).size(), 1)


func test_invalid_chain_entry_is_rejected_and_named() -> void:
	var data: ClassData = _class_data()
	var bad: AttackData = _attack()
	bad.id = &"bad_hit"
	bad.damage = 0
	data.attack_chain = [bad]
	var errors: PackedStringArray = data.validate_combat(RATE)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "bad_hit")


func test_finisher_is_allowed_on_the_last_entry_only() -> void:
	var data: ClassData = _class_data()
	var finisher: AttackData = _attack()
	finisher.is_finisher = true
	data.attack_chain = [_attack(), finisher]
	assert_eq(data.validate_combat(RATE).size(), 0)
	data.attack_chain = [finisher, _attack()]
	assert_eq(data.validate_combat(RATE).size(), 1)


func test_a_chain_of_one_and_a_chain_with_no_finisher_are_valid() -> void:
	var data: ClassData = _class_data()
	data.attack_chain = [_attack()]
	assert_eq(data.validate_combat(RATE).size(), 0)


func _attack() -> AttackData:
	var attack: AttackData = AttackData.new()
	attack.id = &"hit"
	attack.windup = 0.08
	attack.active = 0.06
	attack.recovery = 0.18
	attack.damage = 10
	attack.arc_angle_deg = 100.0
	attack.range_tiles = 1.4
	attack.knockback_tiles = 0.3
	return attack


func _class_data() -> ClassData:
	var data: ClassData = ClassData.new()
	data.attack_chain = [_attack()]
	data.attack_chain_window = 0.25
	data.max_hp = 100
	data.hurtbox_radius_tiles = 0.35
	data.knockback_scale = 1.0
	return data
