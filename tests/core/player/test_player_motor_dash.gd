extends GutTest
## AC6, AC7, AC10, C10 at 30/60/120 ticks/s.

const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")


func test_ac6_dash_goes_in_move_direction_of_the_fire_tick() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		Harness.step(motor, rate, Vector2.RIGHT * 0.5, Vector2.UP, true)
		Harness.run(motor, rate, 0.2, Vector2.ZERO, Vector2.UP)
		assert_almost_eq(Harness.position_tiles(motor).x, data.dash_distance, 0.01)


func test_ac6_stationary_dash_goes_in_facing_direction() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		Harness.step(motor, rate, Vector2.ZERO, Vector2.LEFT, true)
		Harness.run(motor, rate, 0.2)
		assert_almost_eq(Harness.position_tiles(motor).x, -data.dash_distance, 0.01)


func test_ac6_dash_right_after_setup_goes_down() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		motor.submit(DashCommand.new())
		motor.tick(1.0 / rate)
		Harness.run(motor, rate, 0.2)
		assert_almost_eq(Harness.position_tiles(motor).y, data.dash_distance, 0.01)
		assert_almost_eq(Harness.position_tiles(motor).x, 0.0, 0.001)


func test_ac7_travel_is_exact_and_speed_constant() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		var speed: float = data.dash_distance / data.dash_duration
		Harness.step(motor, rate, Vector2.RIGHT, Vector2.ZERO, true)
		Harness.run(motor, rate, Harness.THIRTIETH - 1.0 / rate, Vector2.RIGHT)
		assert_almost_eq(Harness.position_tiles(motor).x, speed * Harness.THIRTIETH, 0.01)
		Harness.run(motor, rate, Harness.THIRTIETH * 3.0, Vector2.RIGHT)
		assert_almost_eq(Harness.position_tiles(motor).x, speed * Harness.THIRTIETH * 4.0, 0.01)
		Harness.run(motor, rate, Harness.THIRTIETH)
		Harness.run(motor, rate, 0.1)
		assert_almost_eq(Harness.position_tiles(motor).x, data.dash_distance, 0.01)


func test_ac7_dash_lasts_duration() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		var ended_at_tick: Array[int] = []
		var tick_index: Array[int] = [0]
		motor.dash_ended.connect(func() -> void: ended_at_tick.append(tick_index[0]))
		for index: int in rate:
			tick_index[0] = index
			Harness.step(motor, rate, Vector2.ZERO, Vector2.ZERO, index == 0)
		assert_eq(ended_at_tick.size(), 1)
		var ended_by: float = (ended_at_tick[0] + 1.0) / rate
		assert_almost_eq(ended_by, data.dash_duration, Harness.THIRTIETH, "%d Hz" % rate)


func test_c10_move_input_is_ignored_during_a_dash() -> void:
	var data: ClassData = Harness.warrior()
	var motor: PlayerMotor = Harness.motor_with(data)
	Harness.step(motor, 60, Vector2.RIGHT, Vector2.ZERO, true)
	Harness.run(motor, 60, 0.1, Vector2.DOWN)
	assert_eq(motor.get_state(), PlayerMotor.State.DASHING)
	assert_almost_eq(Harness.position_tiles(motor).y, 0.0, 0.0001)


func test_ac10_no_momentum_after_a_dash() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		var velocity_at_end: Array[Vector2] = Harness.record_end_velocities(motor)
		Harness.step(motor, rate, Vector2.RIGHT, Vector2.ZERO, true)
		Harness.run(motor, rate, 0.3)
		assert_eq(velocity_at_end, [Vector2.ZERO] as Array[Vector2])
		assert_almost_eq(Harness.position_tiles(motor).x, data.dash_distance, 0.01)


func test_ac10_movement_resumes_with_normal_accel_inside_the_dash_end_tick() -> void:
	# Dash ends at 0.15, inside the 30 Hz tick [0.1333, 0.1667): the rest of it integrates
	# normal movement from rest. Same answer at every rate.
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		Harness.step(motor, rate, Vector2.RIGHT, Vector2.ZERO, true)
		Harness.run(motor, rate, 5.0 / 30.0 - 1.0 / rate, Vector2.RIGHT)
		var after_dash: float = 5.0 / 30.0 - data.dash_duration
		var acceleration: float = data.move_speed / data.move_accel_time
		var expected: float = data.dash_distance + 0.5 * acceleration * after_dash * after_dash
		assert_almost_eq(Harness.position_tiles(motor).x, expected, 0.01, "%d Hz" % rate)
