extends GutTest
## F-001/C16 aim device rules and AC4/AC5 mapper side, through raw samples.

const DEADZONE: float = 0.2
const PAD: int = 0
const OTHER_PAD: int = 3
const KIND: Variant = InputSample.DeviceEventKind
const MODE: Variant = PlayerInputMapper.AimMode

var _mapper: PlayerInputMapper


func before_each() -> void:
	_mapper = PlayerInputMapper.new()


func test_initial_mode_is_mouse() -> void:
	assert_eq(_mapper.get_aim_mode(), MODE.MOUSE)


func test_ac4_mouse_aim_points_at_the_mouse() -> void:
	var sample: InputSample = InputSample.new()
	sample.mouse_offset_tiles = Vector2(0, -3)
	assert_eq(_aim(sample), Vector2.UP)


func test_ac4_mouse_on_the_player_gives_no_aim() -> void:
	var sample: InputSample = InputSample.new()
	sample.mouse_offset_tiles = Vector2(0.24, 0)
	assert_eq(_aim(sample), Vector2.ZERO)
	sample.mouse_offset_tiles = Vector2(0.25, 0)
	assert_eq(_aim(sample), Vector2.RIGHT)


func test_ac5_joypad_button_switches_to_gamepad() -> void:
	_map_events([_event(KIND.JOY_BUTTON, PAD)])
	assert_eq(_mapper.get_aim_mode(), MODE.GAMEPAD)


func test_ac5_stick_above_deadzone_switches_to_gamepad() -> void:
	_map_events([_event(KIND.JOY_STICK, PAD, 0.21)])
	assert_eq(_mapper.get_aim_mode(), MODE.GAMEPAD)


func test_ac5_stick_noise_does_not_switch() -> void:
	_map_events([_event(KIND.JOY_STICK, PAD, 0.1), _event(KIND.JOY_STICK, PAD, 0.2)])
	assert_eq(_mapper.get_aim_mode(), MODE.MOUSE)


func test_ac5_mouse_motion_of_two_px_switches_back() -> void:
	_map_events([_event(KIND.JOY_BUTTON, PAD)])
	_map_events([_event(KIND.MOUSE_MOTION, 0, 2.0)])
	assert_eq(_mapper.get_aim_mode(), MODE.MOUSE)


func test_ac5_mouse_jitter_does_not_switch_back() -> void:
	_map_events([_event(KIND.JOY_BUTTON, PAD)])
	_map_events([_event(KIND.MOUSE_MOTION, 0, 1.9)])
	assert_eq(_mapper.get_aim_mode(), MODE.GAMEPAD)


func test_ac5_mouse_button_switches_back() -> void:
	_map_events([_event(KIND.JOY_BUTTON, PAD)])
	_map_events([_event(KIND.MOUSE_BUTTON)])
	assert_eq(_mapper.get_aim_mode(), MODE.MOUSE)


func test_ac5_camera_movement_does_not_switch() -> void:
	_map_events([_event(KIND.JOY_BUTTON, PAD)])
	var sample: InputSample = _pad_sample()
	sample.mouse_offset_tiles = Vector2(5, 5)
	_mapper.map(sample, DEADZONE)
	sample.mouse_offset_tiles = Vector2(-5, 2)
	_mapper.map(sample, DEADZONE)
	assert_eq(_mapper.get_aim_mode(), MODE.GAMEPAD)


func test_keyboard_move_does_not_switch() -> void:
	var sample: InputSample = InputSample.new()
	sample.digital_move = Vector2.RIGHT
	_mapper.map(sample, DEADZONE)
	assert_eq(_mapper.get_aim_mode(), MODE.MOUSE)


func test_last_event_of_a_tick_wins() -> void:
	_map_events([_event(KIND.JOY_BUTTON, PAD), _event(KIND.MOUSE_MOTION, 0, 5.0)])
	assert_eq(_mapper.get_aim_mode(), MODE.MOUSE)
	_map_events([_event(KIND.MOUSE_MOTION, 0, 5.0), _event(KIND.JOY_BUTTON, PAD)])
	assert_eq(_mapper.get_aim_mode(), MODE.GAMEPAD)


func test_ac5_gamepad_aim_uses_the_right_stick_as_a_unit_vector() -> void:
	_map_events([_event(KIND.JOY_BUTTON, PAD)])
	var sample: InputSample = _pad_sample(Vector2.ZERO, Vector2(0.5, 0))
	assert_eq(_aim(sample), Vector2.RIGHT)


func test_ac5_gamepad_aim_below_deadzone_is_zero() -> void:
	_map_events([_event(KIND.JOY_BUTTON, PAD)])
	assert_eq(_aim(_pad_sample(Vector2.ZERO, Vector2(0.2, 0))), Vector2.ZERO)


func test_gamepad_mode_ignores_the_mouse() -> void:
	_map_events([_event(KIND.JOY_BUTTON, PAD)])
	var sample: InputSample = _pad_sample()
	sample.mouse_offset_tiles = Vector2(9, 0)
	assert_eq(_aim(sample), Vector2.ZERO)


func test_active_joypad_is_the_last_one_with_a_qualifying_event() -> void:
	var sample: InputSample = _two_pad_sample()
	sample.device_events = [_event(KIND.JOY_BUTTON, OTHER_PAD)]
	assert_eq(_aim(sample), Vector2.LEFT)


func test_default_joypad_is_the_first_connected() -> void:
	var sample: InputSample = _two_pad_sample()
	var move: Vector2 = (_mapper.map(sample, 0.0)[0] as MoveCommand).direction
	assert_eq(move, Vector2.UP)


func test_disconnected_active_joypad_falls_back_to_the_first_connected() -> void:
	var sample: InputSample = _two_pad_sample()
	sample.device_events = [_event(KIND.JOY_BUTTON, OTHER_PAD)]
	_mapper.map(sample, DEADZONE)
	assert_eq(_aim(_pad_sample(Vector2.ZERO, Vector2.DOWN)), Vector2.DOWN)


func test_gamepad_mode_with_no_joypad_connected_gives_no_aim() -> void:
	_map_events([_event(KIND.JOY_BUTTON, PAD)])
	assert_eq(_aim(InputSample.new()), Vector2.ZERO)


func _aim(sample: InputSample) -> Vector2:
	return (_mapper.map(sample, DEADZONE)[1] as AimCommand).direction


func _map_events(events: Array[InputSample.DeviceEvent]) -> void:
	var sample: InputSample = _pad_sample()
	sample.device_events = events
	_mapper.map(sample, DEADZONE)


func _event(kind: int, device: int = 0, value: float = 0.0) -> InputSample.DeviceEvent:
	return InputSample.DeviceEvent.new(kind as InputSample.DeviceEventKind, device, value)


func _pad_sample(left: Vector2 = Vector2.ZERO, right: Vector2 = Vector2.ZERO) -> InputSample:
	var sample: InputSample = InputSample.new()
	sample.left_sticks[PAD] = left
	sample.right_sticks[PAD] = right
	return sample


func _two_pad_sample() -> InputSample:
	var sample: InputSample = _pad_sample(Vector2.UP, Vector2.RIGHT)
	sample.left_sticks[OTHER_PAD] = Vector2.DOWN
	sample.right_sticks[OTHER_PAD] = Vector2.LEFT
	return sample
