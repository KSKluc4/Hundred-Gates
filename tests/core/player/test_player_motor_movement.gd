extends GutTest
## AC1–AC5 at motor level, at 30/60/120 ticks/s. Oracle: C15 step d kinematics.

const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const EIGHT_DIRECTIONS: Array[Vector2] = [
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(0, 1),
	Vector2(0, -1),
	Vector2(1, 1),
	Vector2(1, -1),
	Vector2(-1, 1),
	Vector2(-1, -1),
]


func test_ac1_settled_speed_matches_in_all_eight_directions() -> void:
	for rate: int in Harness.RATES:
		for direction: Vector2 in EIGHT_DIRECTIONS:
			var data: ClassData = Harness.warrior()
			var motor: PlayerMotor = Harness.motor_with(data)
			var move: Vector2 = direction.normalized()
			Harness.run(motor, rate, 0.2, move)
			var before: Vector2 = Harness.position_tiles(motor)
			Harness.run(motor, rate, 1.0, move)
			var travelled: float = before.distance_to(Harness.position_tiles(motor))
			assert_almost_eq(travelled, data.move_speed, 0.01, "%d Hz %s" % [rate, direction])


func test_ac1_oversized_input_is_not_faster() -> void:
	var data: ClassData = Harness.warrior()
	var motor: PlayerMotor = Harness.motor_with(data)
	Harness.run(motor, 60, 0.2, Vector2(1, 1))
	assert_almost_eq(Harness.velocity_tiles(motor).length(), data.move_speed, 0.001)


func test_ac2_settled_speed_scales_with_mapped_magnitude() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		Harness.run(motor, rate, 0.2, Vector2(0.375, 0))
		assert_almost_eq(Harness.velocity_tiles(motor).x, 0.375 * data.move_speed, 0.0001)


func test_ac3_accel_reaches_full_speed_within_accel_time_plus_one_tick() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		var ticks: int = ceili(data.move_accel_time * rate) + 1
		for _i: int in ticks:
			Harness.step(motor, rate, Vector2.RIGHT)
		assert_eq(Harness.velocity_tiles(motor).x, float(data.move_speed), "%d Hz" % rate)


func test_ac3_decel_reaches_zero_within_decel_time_plus_one_tick() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		Harness.run(motor, rate, 0.2, Vector2.RIGHT)
		var ticks: int = ceili(data.move_decel_time * rate) + 1
		for _i: int in ticks:
			Harness.step(motor, rate)
		assert_eq(Harness.velocity_tiles(motor), Vector2.ZERO, "%d Hz" % rate)
		assert_eq(motor.get_state(), PlayerMotor.State.IDLE)


func test_ac3_zero_times_change_velocity_in_the_same_tick() -> void:
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		data.move_accel_time = 0.0
		data.move_decel_time = 0.0
		var motor: PlayerMotor = Harness.motor_with(data)
		Harness.step(motor, rate, Vector2.RIGHT)
		assert_eq(Harness.velocity_tiles(motor).x, float(data.move_speed))
		assert_almost_eq(Harness.position_tiles(motor).x, data.move_speed / rate, 0.0001)
		Harness.step(motor, rate)
		assert_eq(Harness.velocity_tiles(motor), Vector2.ZERO)


func test_acceleration_displacement_is_the_exact_integral_at_every_rate() -> void:
	# From rest, at 1/30 s the ramp (0.05 s) is unfinished: x = ½·a·t².
	for rate: int in Harness.RATES:
		var data: ClassData = Harness.warrior()
		var motor: PlayerMotor = Harness.motor_with(data)
		Harness.run(motor, rate, Harness.THIRTIETH, Vector2.RIGHT)
		var acceleration: float = data.move_speed / data.move_accel_time
		var expected: float = 0.5 * acceleration * Harness.THIRTIETH * Harness.THIRTIETH
		assert_almost_eq(Harness.position_tiles(motor).x, expected, 0.0001, "%d Hz" % rate)


func test_reversal_uses_decel_then_accel_inside_one_tick_at_every_rate() -> void:
	# Full right, then a slower left: v slows at the decel rate until |v| = |target|, then
	# keeps going at the accel rate. Must match across rates even mid-ramp.
	var data: ClassData = Harness.warrior()
	data.move_accel_time = 0.3
	data.move_decel_time = 0.1
	var results: Array[Vector2] = []
	for rate: int in Harness.RATES:
		var motor: PlayerMotor = Harness.motor_with(data)
		Harness.run(motor, rate, 0.5, Vector2.RIGHT)
		Harness.run(motor, rate, 0.1, Vector2.LEFT * 0.4)
		results.append(Harness.position_tiles(motor))
		assert_almost_eq(
			Harness.velocity_tiles(motor).x, _reversal_speed_after(data, 0.1), 0.001, "%d Hz" % rate
		)
	assert_almost_eq(results[0].x, results[2].x, 0.001)
	assert_almost_eq(results[1].x, results[2].x, 0.001)


func test_state_follows_movement() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	assert_eq(motor.get_state(), PlayerMotor.State.IDLE)
	Harness.step(motor, 60, Vector2.RIGHT)
	assert_eq(motor.get_state(), PlayerMotor.State.MOVING)


func test_commands_last_one_tick() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Harness.run(motor, 60, 0.2, Vector2.RIGHT)
	motor.tick(1.0 / 60.0)
	motor.tick(1.0 / 60.0)
	motor.tick(1.0 / 60.0)
	assert_eq(Harness.velocity_tiles(motor).x, 0.0, "no command means no move intent")


func test_ac4_ac5_facing_follows_aim_while_moving_and_dashing() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Harness.step(motor, 60, Vector2.LEFT, Vector2.UP)
	assert_eq(motor.get_facing(), Vector2.UP, "aim beats move")
	Harness.step(motor, 60, Vector2.LEFT, Vector2.RIGHT, true)
	assert_eq(motor.get_state(), PlayerMotor.State.DASHING)
	assert_eq(motor.get_facing(), Vector2.RIGHT, "aim updates during a dash")


func test_ac4_ac5_facing_falls_back_to_move_then_keeps_last() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	assert_eq(motor.get_facing(), Vector2.DOWN, "initial facing")
	Harness.step(motor, 60, Vector2(0.5, 0))
	assert_eq(motor.get_facing(), Vector2.RIGHT, "move direction, normalized")
	Harness.step(motor, 60)
	assert_eq(motor.get_facing(), Vector2.RIGHT, "no input keeps the last facing")


## Hand-derived oracle for the reversal test: starts at +speed, target -0.4 speed.
func _reversal_speed_after(data: ClassData, seconds: float) -> float:
	var decel: float = data.move_speed / data.move_decel_time
	var accel: float = data.move_speed / data.move_accel_time
	var target_speed: float = 0.4 * data.move_speed
	var slowdown_time: float = (data.move_speed - target_speed) / decel
	return target_speed - accel * (seconds - slowdown_time)
