extends GutTest
## AC11, AC12: cooldown and input buffer, at 30/60/120 ticks/s.

const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")


func test_ac11_c9_cooldown_starts_when_the_dash_ends() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		var fire_times: Array[float] = Harness.record_fire_times(motor)
		Harness.run_with_presses(motor, rate, 1.0, [0.0, 0.4, 0.5] as Array[float])
		assert_eq(fire_times.size(), 2)
		assert_almost_eq(fire_times[1], data.dash_duration + data.dash_cooldown, 0.000001)


func test_cooldown_reports_full_value_after_a_dash_ending_on_a_tick_boundary() -> void:
	var data: ClassData = Harness.warrior()
	data.dash_duration = 0.1
	data.dash_iframe_duration = 0.05
	var motor: PlayerMotor = Harness.motor_with(data)
	Harness.step(motor, 30, Vector2.ZERO, Vector2.ZERO, true)
	Harness.run(motor, 30, 2.0 / 30.0)
	assert_almost_eq(motor.get_cooldown_remaining(), data.dash_cooldown, 0.000001)


func test_zero_cooldown_lets_a_buffered_dash_fire_at_dash_end() -> void:
	var data: ClassData = Harness.warrior()
	data.dash_cooldown = 0.0
	var motor: PlayerMotor = Harness.motor_with(data)
	var fire_times: Array[float] = Harness.record_fire_times(motor)
	Harness.run_with_presses(motor, 30, 0.5, [0.0, 0.1] as Array[float])
	assert_eq(fire_times.size(), 2)
	assert_almost_eq(fire_times[1], data.dash_duration, 0.000001)


func test_ac12_press_during_cooldown_fires_when_eligible() -> void:
	for rate: int in Harness.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		var fire_times: Array[float] = Harness.record_fire_times(motor)
		Harness.run_with_presses(motor, rate, 0.45, [0.0, 0.4] as Array[float])
		assert_true(motor.has_buffered_dash(), "buffered while cooling down")
		Harness.run(motor, rate, 0.1)
		assert_false(motor.has_buffered_dash())
		assert_eq(fire_times.size(), 2)
		assert_almost_eq(fire_times[1], 0.5, 0.000001, "%d Hz" % rate)


func test_ac12_press_too_early_is_dropped() -> void:
	for rate: int in Harness.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		var fire_times: Array[float] = Harness.record_fire_times(motor)
		Harness.run_with_presses(motor, rate, 1.0, [0.0, 0.1] as Array[float])
		assert_eq(fire_times.size(), 1, "%d Hz" % rate)
		assert_false(motor.has_buffered_dash())


func test_ac12_buffer_boundary_is_inclusive() -> void:
	for rate: int in Harness.RATES:
		var tunables: PlayerCombatTunables = Harness.rules()
		tunables.input_buffer_window = 0.1
		var motor: PlayerMotor = Harness.motor_with(null, tunables)
		var fire_times: Array[float] = Harness.record_fire_times(motor)
		Harness.run_with_presses(motor, rate, 0.6, [0.0, 0.4] as Array[float])
		assert_eq(fire_times.size(), 2, "age equal to the window fires, %d Hz" % rate)


func test_ac12_buffer_just_past_the_window_is_dropped() -> void:
	for rate: int in Harness.RATES:
		var tunables: PlayerCombatTunables = Harness.rules()
		tunables.input_buffer_window = 0.0999
		var motor: PlayerMotor = Harness.motor_with(null, tunables)
		var fire_times: Array[float] = Harness.record_fire_times(motor)
		Harness.run_with_presses(motor, rate, 0.6, [0.0, 0.4] as Array[float])
		assert_eq(fire_times.size(), 1, "%d Hz" % rate)


func test_ac12_newer_press_replaces_the_older_one() -> void:
	for rate: int in Harness.RATES:
		var tunables: PlayerCombatTunables = Harness.rules()
		tunables.input_buffer_window = 0.08
		var motor: PlayerMotor = Harness.motor_with(null, tunables)
		var fire_times: Array[float] = Harness.record_fire_times(motor)
		var presses: Array[float] = [0.0, 0.4, 13.0 / 30.0]
		Harness.run_with_presses(motor, rate, 0.6, presses)
		assert_eq(fire_times.size(), 2, "the 0.4 press alone would expire, %d Hz" % rate)


func test_ac12_direction_is_read_at_fire_time() -> void:
	var data: ClassData = Harness.warrior()
	var motor: PlayerMotor = Harness.motor_with(data)
	Harness.run_with_presses(motor, 60, 0.45, [0.0, 0.4] as Array[float], Vector2.DOWN)
	var before_fire: Vector2 = Harness.position_tiles(motor)
	Harness.run(motor, 60, 0.3, Vector2.LEFT)
	assert_lt(Harness.position_tiles(motor).x, before_fire.x - data.dash_distance + 0.01)


func test_window_of_zero_still_fires_when_eligible_at_the_press() -> void:
	var tunables: PlayerCombatTunables = Harness.rules()
	tunables.input_buffer_window = 0.0
	var motor: PlayerMotor = Harness.motor_with(null, tunables)
	Harness.step(motor, 60, Vector2.ZERO, Vector2.ZERO, true)
	assert_eq(motor.get_state(), PlayerMotor.State.DASHING)
