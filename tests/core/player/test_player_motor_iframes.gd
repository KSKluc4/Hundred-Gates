extends GutTest
## AC9 and C8: the exact i-frame window, at 30/60/120 ticks/s.

const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")


func test_c8_window_is_exact_and_held_through_the_dash() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		Harness.step(motor, rate, Vector2.ZERO, Vector2.ZERO, true)
		var window: PackedFloat64Array = motor.get_iframe_window()
		assert_eq(window.size(), 2)
		assert_eq(window[0], 0.0)
		assert_eq(window[1], data.dash_iframe_duration)


func test_c8_window_is_empty_before_any_dash_and_after_it_passes() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	assert_eq(motor.get_iframe_window().size(), 0)
	Harness.step(motor, 60, Vector2.ZERO, Vector2.ZERO, true)
	Harness.run(motor, 60, 0.2)
	assert_eq(motor.get_iframe_window().size(), 0)


func test_ac9_flag_follows_the_overlap_rule_on_every_tick() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		for index: int in Harness.ticks_for(rate, 0.3):
			Harness.step(motor, rate, Vector2.ZERO, Vector2.ZERO, index == 0)
			var tick_start: float = float(index) / rate
			var expected: bool = tick_start < data.dash_iframe_duration
			assert_eq(motor.is_invulnerable(), expected, "%d Hz tick %d" % [rate, index])


func test_ac9_tail_is_vulnerable_while_still_dashing() -> void:
	var data: ClassData = Harness.warrior()
	var motor: PlayerMotor = Harness.motor_with(data)
	Harness.step(motor, 120, Vector2.ZERO, Vector2.ZERO, true)
	Harness.run(motor, 120, 0.125)
	assert_eq(motor.get_state(), PlayerMotor.State.DASHING)
	assert_false(motor.is_invulnerable())


func test_ac9_sub_tick_window_is_true_for_the_fire_tick_only() -> void:
	var data: ClassData = Harness.warrior()
	data.dash_duration = 0.1
	data.dash_iframe_duration = 0.01
	var motor: PlayerMotor = Harness.motor_with(data)
	Harness.step(motor, 30, Vector2.ZERO, Vector2.ZERO, true)
	assert_true(motor.is_invulnerable())
	assert_eq(motor.get_state(), PlayerMotor.State.DASHING)
	assert_eq(motor.get_iframe_window()[1], 0.01)
	Harness.step(motor, 30)
	assert_false(motor.is_invulnerable())


func test_ac9_sub_tick_whole_dash_reports_true_and_emits_both_signals() -> void:
	var data: ClassData = Harness.warrior()
	data.dash_duration = 0.02
	data.dash_iframe_duration = 0.01
	var motor: PlayerMotor = Harness.motor_with(data)
	watch_signals(motor)
	Harness.step(motor, 30, Vector2.ZERO, Vector2.ZERO, true)
	assert_true(motor.is_invulnerable())
	assert_ne(motor.get_state(), PlayerMotor.State.DASHING)
	assert_signal_emitted(motor, "dash_started")
	assert_signal_emitted(motor, "dash_ended")
	assert_signal_emitted_with_parameters(motor, "invulnerability_changed", [true])
	Harness.step(motor, 30)
	assert_false(motor.is_invulnerable())


func test_ac9_sub_tick_tail_ends_with_the_flag_cleared_on_the_tail_only_tick() -> void:
	# Dash [0, 0.1), window [0, 0.09): the tail lives inside the third 30 Hz tick, which
	# still overlaps the window. The next tick has only cooldown.
	var data: ClassData = Harness.warrior()
	data.dash_duration = 0.1
	data.dash_iframe_duration = 0.09
	var motor: PlayerMotor = Harness.motor_with(data)
	Harness.step(motor, 30, Vector2.ZERO, Vector2.ZERO, true)
	Harness.run(motor, 30, 2.0 / 30.0)
	assert_true(motor.is_invulnerable())
	assert_eq(motor.get_iframe_window()[1], 0.09)
	Harness.step(motor, 30)
	assert_false(motor.is_invulnerable())


func test_c8_changed_signal_fires_once_each_way() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	watch_signals(motor)
	Harness.step(motor, 60, Vector2.ZERO, Vector2.ZERO, true)
	Harness.run(motor, 60, 0.3)
	assert_signal_emit_count(motor, "invulnerability_changed", 2)


func test_ac9_window_shorter_than_float_tolerance_still_reports_the_fire_tick() -> void:
	var data: ClassData = Harness.warrior()
	data.dash_iframe_duration = 0.0000000001
	var motor: PlayerMotor = Harness.motor_with(data)
	Harness.step(motor, 30, Vector2.ZERO, Vector2.ZERO, true)
	assert_true(motor.is_invulnerable())
