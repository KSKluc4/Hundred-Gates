class_name PlayerInput
extends Node
## Thin device layer (F-001 §3): fills an InputSample from Godot and submits the mapper's
## commands. Every decision lives in PlayerInputMapper.

const DODGE_ACTION: StringName = &"dodge"
const MOVE_UP_ACTION: StringName = &"move_up"
const MOVE_DOWN_ACTION: StringName = &"move_down"
const MOVE_LEFT_ACTION: StringName = &"move_left"
const MOVE_RIGHT_ACTION: StringName = &"move_right"

var _mapper: PlayerInputMapper = PlayerInputMapper.new()
var _device_events: Array[InputSample.DeviceEvent] = []


func _input(event: InputEvent) -> void:
	var device_event: InputSample.DeviceEvent = _to_device_event(event)
	if device_event != null:
		_device_events.append(device_event)


## Must run once per tick, before motor.tick() (F-001/C15, step 1).
func submit_commands(motor: PlayerMotor, mouse_offset_px: Vector2, stick_deadzone: float) -> void:
	for command: Command in _mapper.map(_build_sample(mouse_offset_px), stick_deadzone):
		motor.submit(command)
	_device_events.clear()


func get_aim_mode() -> PlayerInputMapper.AimMode:
	return _mapper.get_aim_mode()


func _to_device_event(event: InputEvent) -> InputSample.DeviceEvent:
	if event is InputEventMouseMotion:
		# Screen pixels: `relative` shrinks with the viewport stretch.
		var motion: float = (event as InputEventMouseMotion).screen_relative.length()
		return InputSample.DeviceEvent.new(InputSample.DeviceEventKind.MOUSE_MOTION, 0, motion)
	if event is InputEventMouseButton and event.is_pressed():
		return InputSample.DeviceEvent.new(InputSample.DeviceEventKind.MOUSE_BUTTON)
	if event is InputEventJoypadButton and event.is_pressed():
		return InputSample.DeviceEvent.new(InputSample.DeviceEventKind.JOY_BUTTON, event.device)
	if event is InputEventJoypadMotion:
		return _to_stick_event(event as InputEventJoypadMotion)
	return null


func _to_stick_event(event: InputEventJoypadMotion) -> InputSample.DeviceEvent:
	var stick: Vector2 = Vector2.ZERO
	if event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y:
		stick = _left_stick(event.device)
	elif event.axis == JOY_AXIS_RIGHT_X or event.axis == JOY_AXIS_RIGHT_Y:
		stick = _right_stick(event.device)
	else:
		return null
	return InputSample.DeviceEvent.new(
		InputSample.DeviceEventKind.JOY_STICK, event.device, stick.length()
	)


func _build_sample(mouse_offset_px: Vector2) -> InputSample:
	var sample: InputSample = InputSample.new()
	sample.digital_move = Vector2(
		_digital_strength(MOVE_RIGHT_ACTION) - _digital_strength(MOVE_LEFT_ACTION),
		_digital_strength(MOVE_DOWN_ACTION) - _digital_strength(MOVE_UP_ACTION)
	)
	for device: int in Input.get_connected_joypads():
		sample.left_sticks[device] = _left_stick(device)
		sample.right_sticks[device] = _right_stick(device)
	sample.mouse_offset_tiles = Units.vector_px_to_tiles(mouse_offset_px)
	sample.dodge_pressed = Input.is_action_just_pressed(DODGE_ACTION)
	sample.device_events = _device_events.duplicate()
	return sample


## F-001/C14: the move_* actions also bind the left stick, with their own deadzone. Reading
## the action would filter the stick twice, so only its key and button bindings are read.
func _digital_strength(action: StringName) -> float:
	for binding: InputEvent in InputMap.action_get_events(action):
		if binding is InputEventKey:
			if Input.is_physical_key_pressed((binding as InputEventKey).physical_keycode):
				return 1.0
		elif binding is InputEventJoypadButton:
			if _any_joypad_pressed((binding as InputEventJoypadButton).button_index):
				return 1.0
	return 0.0


func _any_joypad_pressed(button: JoyButton) -> bool:
	for device: int in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, button):
			return true
	return false


func _left_stick(device: int) -> Vector2:
	return Vector2(
		Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	)


func _right_stick(device: int) -> Vector2:
	return Vector2(
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	)
