extends GutTest
## F-001/C17: every valid range, both sides of each boundary.


func test_valid_class_data_has_no_errors() -> void:
	assert_eq(_valid_class_data().validate().size(), 0)


func test_each_class_data_bound_is_rejected() -> void:
	var cases: Array[Array] = [
		["move_speed", 0.0],
		["move_accel_time", -0.01],
		["move_decel_time", -0.01],
		["dash_distance", 0.0],
		["dash_iframe_duration", 0.0],
		["dash_iframe_duration", 0.2],
		["dash_iframe_duration", 0.3],
		["dash_cooldown", -0.01],
	]
	for case: Array in cases:
		var data: ClassData = _valid_class_data()
		data.set(case[0], case[1])
		assert_eq(data.validate().size(), 1, "%s = %s" % case)


func test_zero_dash_duration_is_rejected() -> void:
	var data: ClassData = _valid_class_data()
	data.dash_duration = 0.0
	assert_true(data.validate().has("dash_duration must be > 0"))


func test_zero_accel_decel_and_cooldown_are_valid() -> void:
	var data: ClassData = _valid_class_data()
	data.move_accel_time = 0.0
	data.move_decel_time = 0.0
	data.dash_cooldown = 0.0
	assert_eq(data.validate().size(), 0)


func test_valid_tunables_have_no_errors() -> void:
	var tunables: PlayerCombatTunables = PlayerCombatTunables.new()
	tunables.input_buffer_window = 0.0
	tunables.stick_deadzone = 0.0
	assert_eq(tunables.validate().size(), 0)


func test_each_tunable_bound_is_rejected() -> void:
	var cases: Array[Array] = [
		["input_buffer_window", -0.01],
		["stick_deadzone", -0.01],
		["stick_deadzone", 1.0],
	]
	for case: Array in cases:
		var tunables: PlayerCombatTunables = PlayerCombatTunables.new()
		tunables.set(case[0], case[1])
		assert_eq(tunables.validate().size(), 1, "%s = %s" % case)


func _valid_class_data() -> ClassData:
	var data: ClassData = ClassData.new()
	data.move_speed = 5.0
	data.move_accel_time = 0.05
	data.move_decel_time = 0.04
	data.dash_distance = 3.0
	data.dash_duration = 0.2
	data.dash_iframe_duration = 0.1
	data.dash_cooldown = 0.35
	return data


func test_warrior_file_has_the_design_values_and_is_valid() -> void:
	var warrior: ClassData = load("res://data/classes/warrior.tres")
	assert_eq(warrior.validate().size(), 0)
	assert_eq(warrior.id, &"warrior")
	assert_eq(warrior.weapon_family, &"sword")
	assert_eq(warrior.move_speed, 5.0)
	assert_eq(warrior.move_accel_time, 0.05)
	assert_eq(warrior.move_decel_time, 0.04)
	assert_eq(warrior.dash_distance, 3.0)
	assert_eq(warrior.dash_duration, 0.15)
	assert_eq(warrior.dash_iframe_duration, 0.11)
	assert_eq(warrior.dash_cooldown, 0.35)


func test_autoload_exposes_the_shared_rules_file() -> void:
	var tunables: PlayerCombatTunables = Tunables.player_combat
	assert_eq(tunables.validate().size(), 0)
	assert_eq(tunables.input_buffer_window, 0.12)
	assert_eq(tunables.stick_deadzone, 0.2)
