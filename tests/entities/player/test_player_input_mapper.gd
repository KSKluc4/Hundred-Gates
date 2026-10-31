extends GutTest
## F-001/C14 stick contract and commands, through raw samples. No scene, no devices.

const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const DEADZONE: float = 0.2
const PAD: int = 0

var _mapper: PlayerInputMapper


func before_each() -> void:
	_mapper = PlayerInputMapper.new()


func test_c14_formula_at_the_spec_values() -> void:
	var cases: Array[Array] = [[0.1, 0.0], [0.2, 0.0], [0.5, 0.375], [1.0, 1.0]]
	for case: Array in cases:
		var mapped: Vector2 = PlayerInputMapper.apply_deadzone(Vector2(case[0], 0), DEADZONE)
		assert_almost_eq(mapped.length(), float(case[1]), 0.00001, "raw %s" % case[0])


func test_c14_deadzone_is_radial_and_keeps_direction() -> void:
	var raw: Vector2 = Vector2(0.3, 0.4)
	var mapped: Vector2 = PlayerInputMapper.apply_deadzone(raw, DEADZONE)
	assert_almost_eq(mapped.length(), 0.375, 0.00001)
	assert_almost_eq(mapped.normalized().dot(raw.normalized()), 1.0, 0.00001)


func test_c14_raw_is_clamped_to_length_one() -> void:
	var mapped: Vector2 = PlayerInputMapper.apply_deadzone(Vector2(1, 1), DEADZONE)
	assert_almost_eq(mapped.length(), 1.0, 0.00001)


func test_c14_zero_deadzone_passes_the_stick_through() -> void:
	var mapped: Vector2 = PlayerInputMapper.apply_deadzone(Vector2(0.5, 0), 0.0)
	assert_almost_eq(mapped.x, 0.5, 0.00001)


func test_digital_move_is_normalized() -> void:
	var sample: InputSample = _sample()
	sample.digital_move = Vector2(1, -1)
	assert_almost_eq(_move(sample).length(), 1.0, 0.00001)


func test_stick_wins_over_digital_above_deadzone() -> void:
	var sample: InputSample = _sample_with_pad(Vector2(0, 0.5))
	sample.digital_move = Vector2(1, 0)
	assert_almost_eq(_move(sample), Vector2(0, 0.375), Vector2(0.00001, 0.00001))


func test_digital_is_used_when_the_stick_is_inside_the_deadzone() -> void:
	var sample: InputSample = _sample_with_pad(Vector2(0, 0.1))
	sample.digital_move = Vector2(1, 0)
	assert_eq(_move(sample), Vector2.RIGHT)


func test_no_joypad_uses_digital() -> void:
	var sample: InputSample = _sample()
	sample.digital_move = Vector2(0, 1)
	assert_eq(_move(sample), Vector2.DOWN)


func test_ac2_settled_speed_through_raw_samples() -> void:
	var cases: Array[Array] = [[0.1, 0.0], [0.2, 0.0], [0.5, 0.375], [1.0, 1.0]]
	for case: Array in cases:
		for rate: int in Harness.RATES:
			var data: ClassData = Harness.warrior()
			var motor: PlayerMotor = Harness.motor_with(data)
			for _i: int in Harness.ticks_for(rate, 0.3):
				for command: Command in _mapper.map(
					_sample_with_pad(Vector2(case[0], 0)), DEADZONE
				):
					motor.submit(command)
				motor.tick(1.0 / rate)
			var expected: float = float(case[1]) * data.move_speed
			var label: String = "raw %s at %d Hz" % [case[0], rate]
			assert_almost_eq(Harness.velocity_tiles(motor).x, expected, 0.0001, label)


func test_a_reloaded_deadzone_applies_on_the_next_map() -> void:
	var sample: InputSample = _sample_with_pad(Vector2(0.5, 0))
	assert_almost_eq(_move(sample).x, 0.375, 0.00001)
	var after_reload: Array[Command] = _mapper.map(sample, 0.6)
	assert_eq((after_reload[0] as MoveCommand).direction, Vector2.ZERO)
	assert_almost_eq((_mapper.map(sample, 0.0)[0] as MoveCommand).direction.x, 0.5, 0.00001, "dz 0")


func test_a_reloaded_deadzone_decides_mode_switching_too() -> void:
	var event: InputSample.DeviceEvent = InputSample.DeviceEvent.new(
		InputSample.DeviceEventKind.JOY_STICK, PAD, 0.5
	)
	var sample: InputSample = _sample_with_pad(Vector2(0.5, 0))
	sample.device_events = [event]
	_mapper.map(sample, 0.6)
	assert_eq(_mapper.get_aim_mode(), PlayerInputMapper.AimMode.MOUSE)
	_mapper.map(sample, 0.4)
	assert_eq(_mapper.get_aim_mode(), PlayerInputMapper.AimMode.GAMEPAD)


func test_move_and_aim_are_always_submitted_and_dash_only_on_press() -> void:
	var sample: InputSample = _sample()
	var idle: Array[Command] = _mapper.map(sample, DEADZONE)
	assert_eq(idle.size(), 2)
	assert_is(idle[0], MoveCommand)
	assert_is(idle[1], AimCommand)
	sample.dodge_pressed = true
	var pressed: Array[Command] = _mapper.map(sample, DEADZONE)
	assert_eq(pressed.size(), 3)
	assert_is(pressed[2], DashCommand)


func test_two_mappers_are_independent() -> void:
	var other: PlayerInputMapper = PlayerInputMapper.new()
	var sample: InputSample = _sample_with_pad(Vector2.ZERO)
	sample.device_events = [
		InputSample.DeviceEvent.new(InputSample.DeviceEventKind.JOY_BUTTON, PAD)
	]
	_mapper.map(sample, DEADZONE)
	assert_eq(_mapper.get_aim_mode(), PlayerInputMapper.AimMode.GAMEPAD)
	assert_eq(other.get_aim_mode(), PlayerInputMapper.AimMode.MOUSE)


func _move(sample: InputSample) -> Vector2:
	return (_mapper.map(sample, DEADZONE)[0] as MoveCommand).direction


func _sample() -> InputSample:
	return InputSample.new()


func _sample_with_pad(left: Vector2, right: Vector2 = Vector2.ZERO) -> InputSample:
	var sample: InputSample = InputSample.new()
	sample.left_sticks[PAD] = left
	sample.right_sticks[PAD] = right
	return sample
