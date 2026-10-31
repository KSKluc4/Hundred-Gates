extends GutTest
## C17 validity and latching, C18 lifecycle effects.

const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")


func test_setup_places_the_motor_and_faces_it() -> void:
	var motor: PlayerMotor = PlayerMotor.new()
	var started: bool = motor.setup(
		Harness.warrior(), Harness.rules(), Vector2(2, 3), Vector2(0, -5)
	)
	assert_true(started)
	assert_eq(motor.get_position_px(), Units.vector_tiles_to_px(Vector2(2, 3)))
	assert_eq(motor.get_facing(), Vector2.UP)


func test_setup_with_zero_facing_keeps_facing_non_zero() -> void:
	var motor: PlayerMotor = PlayerMotor.new()
	motor.setup(Harness.warrior(), Harness.rules(), Vector2.ZERO, Vector2.ZERO)
	assert_eq(motor.get_facing(), Vector2.DOWN)


func test_setup_resets_all_state() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	var fresh: Dictionary = motor.to_dict()
	Harness.run_with_presses(motor, 60, 0.05, [0.0] as Array[float], Vector2.RIGHT)
	motor.setup(Harness.warrior(), Harness.rules(), Vector2.ZERO)
	assert_eq_deep(motor.to_dict(), fresh)


func test_invalid_setup_is_refused_and_motor_stays_unstarted() -> void:
	var data: ClassData = Harness.warrior()
	data.dash_iframe_duration = data.dash_duration
	var motor: PlayerMotor = PlayerMotor.new()
	assert_false(motor.setup(data, Harness.rules(), Vector2.ZERO))
	assert_push_error("data rejected")
	Harness.step(motor, 60, Vector2.RIGHT, Vector2.ZERO, true)
	assert_eq(motor.get_position_px(), Vector2.ZERO)
	assert_eq(motor.get_state(), PlayerMotor.State.IDLE)


func test_invalid_setup_keeps_the_previous_state() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Harness.run(motor, 60, 0.2, Vector2.RIGHT)
	var before: Dictionary = motor.to_dict()
	var tunables: PlayerCombatTunables = Harness.rules()
	tunables.stick_deadzone = 1.0
	assert_false(motor.setup(Harness.warrior(), tunables, Vector2(9, 9)))
	assert_push_error("data rejected")
	assert_eq_deep(motor.to_dict(), before)


func test_sync_position_overwrites_position_only() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Harness.run(motor, 60, 0.2, Vector2.RIGHT)
	var before: Dictionary = motor.to_dict()
	motor.sync_position(Vector2(160, 32))
	var after: Dictionary = motor.to_dict()
	assert_eq(motor.get_position_px(), Vector2(160, 32))
	after["position"] = before["position"]
	assert_eq_deep(after, before)


func test_apply_data_keeps_state() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Harness.run_with_presses(motor, 60, 0.05, [0.0] as Array[float], Vector2.RIGHT)
	var before: Dictionary = motor.to_dict()
	var faster: ClassData = Harness.warrior()
	faster.move_speed = 9.0
	assert_true(motor.apply_data(faster, Harness.rules()))
	assert_eq_deep(motor.to_dict(), before)


func test_invalid_apply_data_changes_nothing() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	var data: ClassData = Harness.warrior()
	data.move_speed = -1.0
	assert_false(motor.apply_data(data, Harness.rules()))
	assert_push_error("data rejected")
	Harness.run(motor, 60, 0.2, Vector2.RIGHT)
	assert_almost_eq(Harness.velocity_tiles(motor).x, 5.0, 0.001)


func test_c17_mid_dash_reload_keeps_latched_values_and_affects_the_next_dash() -> void:
	for rate: int in Harness.RATES:
		var old_data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(old_data)
		Harness.step(motor, rate, Vector2.RIGHT, Vector2.ZERO, true)
		var window: PackedFloat64Array = motor.get_iframe_window()
		var new_data: ClassData = Harness.warrior()
		new_data.dash_distance = 6.0
		new_data.dash_duration = 0.3
		new_data.dash_iframe_duration = 0.2
		motor.apply_data(new_data, Harness.rules())
		assert_eq(motor.get_iframe_window(), window)
		assert_eq(window[1], old_data.dash_iframe_duration)
		Harness.run(motor, rate, 0.25)
		assert_almost_eq(Harness.position_tiles(motor).x, old_data.dash_distance, 0.01)
		Harness.run(motor, rate, 0.3)
		var start: float = Harness.position_tiles(motor).x
		Harness.step(motor, rate, Vector2.RIGHT, Vector2.ZERO, true)
		Harness.run(motor, rate, 0.4)
		var travelled: float = Harness.position_tiles(motor).x - start
		assert_almost_eq(travelled, new_data.dash_distance, 0.01, "%d Hz" % rate)


func test_c17_reload_keeps_remaining_cooldown_and_new_value_applies_next_time() -> void:
	var data: ClassData = Harness.warrior()
	var motor: PlayerMotor = Harness.motor_with(data)
	var fire_times: Array[float] = Harness.record_fire_times(motor)
	Harness.step(motor, 60, Vector2.ZERO, Vector2.ZERO, true)
	Harness.run(motor, 60, 0.25)
	var remaining: float = motor.get_cooldown_remaining()
	var new_data: ClassData = Harness.warrior()
	new_data.dash_cooldown = 0.7
	motor.apply_data(new_data, Harness.rules())
	assert_eq(motor.get_cooldown_remaining(), remaining)
	Harness.run(motor, 60, 0.3)
	Harness.step(motor, 60, Vector2.ZERO, Vector2.ZERO, true)
	Harness.run(motor, 60, 0.2)
	assert_eq(fire_times.size(), 2)
	assert_almost_eq(motor.get_cooldown_remaining(), 0.7 - 0.05 - 1.0 / 60.0, 0.0001)


func test_c17_reload_keeps_buffer_age_and_new_window_applies_next_tick() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Harness.run_with_presses(motor, 60, 0.4 + 1.0 / 60.0, [0.0, 0.4] as Array[float])
	assert_true(motor.has_buffered_dash())
	var age: float = motor.to_dict()["buffered_dash_age"]
	var tighter: PlayerCombatTunables = Harness.rules()
	tighter.input_buffer_window = 0.0
	motor.apply_data(Harness.warrior(), tighter)
	assert_true(motor.has_buffered_dash(), "the reload itself drops nothing")
	assert_eq(motor.to_dict()["buffered_dash_age"], age)
	Harness.step(motor, 60)
	assert_false(motor.has_buffered_dash(), "new window applies from the next tick")


func test_c17_move_values_apply_from_the_next_tick() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Harness.run(motor, 60, 0.2, Vector2.RIGHT)
	var faster: ClassData = Harness.warrior()
	faster.move_speed = 8.0
	faster.move_accel_time = 0.0
	motor.apply_data(faster, Harness.rules())
	Harness.step(motor, 60, Vector2.RIGHT)
	assert_eq(Harness.velocity_tiles(motor).x, 8.0)
