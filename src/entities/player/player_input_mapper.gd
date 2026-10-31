class_name PlayerInputMapper
extends RefCounted
## Turns an InputSample into commands (G8). Pure: no Input, no nodes. Implements the stick
## contract (F-001/C14) and the aim device rules (F-001/C16). One instance per player (C6).

enum AimMode { MOUSE, GAMEPAD }

const NO_JOYPAD: int = -1
# F-001/C16: device-detection rules, not movement tunables.
const MOUSE_SWITCH_MIN_MOTION_PX: float = 2.0
const MOUSE_AIM_MIN_DISTANCE_TILES: float = 0.25
## Vector2 is 32-bit: a raw 0.2 reads as 0.200000003, which must still equal a dz of 0.2.
const STICK_TOLERANCE: float = 0.000001

var _aim_mode: AimMode = AimMode.MOUSE
var _active_joypad: int = NO_JOYPAD


## F-001/C14. The one stick formula, used for move and aim.
static func apply_deadzone(raw: Vector2, deadzone: float) -> Vector2:
	var stick: Vector2 = raw.limit_length(1.0)
	var length: float = stick.length()
	if not _exceeds_deadzone(length, deadzone):
		return Vector2.ZERO
	return stick / length * ((length - deadzone) / (1.0 - deadzone))


static func _exceeds_deadzone(length: float, deadzone: float) -> bool:
	return length - deadzone > STICK_TOLERANCE


func map(sample: InputSample, stick_deadzone: float) -> Array[Command]:
	_apply_device_events(sample, stick_deadzone)
	var commands: Array[Command] = [
		MoveCommand.new(_move_direction(sample, stick_deadzone)),
		AimCommand.new(_aim_direction(sample, stick_deadzone)),
	]
	if sample.dodge_pressed:
		commands.append(DashCommand.new())
	return commands


func get_aim_mode() -> AimMode:
	return _aim_mode


## Camera or player movement sends no event, so it can never switch the mode (C16).
func _apply_device_events(sample: InputSample, stick_deadzone: float) -> void:
	for event: InputSample.DeviceEvent in sample.device_events:
		match event.kind:
			InputSample.DeviceEventKind.MOUSE_MOTION:
				if event.magnitude >= MOUSE_SWITCH_MIN_MOTION_PX:
					_aim_mode = AimMode.MOUSE
			InputSample.DeviceEventKind.MOUSE_BUTTON:
				_aim_mode = AimMode.MOUSE
			InputSample.DeviceEventKind.JOY_BUTTON:
				_switch_to_gamepad(event.device)
			InputSample.DeviceEventKind.JOY_STICK:
				if _exceeds_deadzone(event.magnitude, stick_deadzone):
					_switch_to_gamepad(event.device)


func _switch_to_gamepad(device: int) -> void:
	_aim_mode = AimMode.GAMEPAD
	_active_joypad = device


func _move_direction(sample: InputSample, stick_deadzone: float) -> Vector2:
	var joypad: int = _resolve_joypad(sample)
	if joypad != NO_JOYPAD:
		var stick: Vector2 = apply_deadzone(sample.left_sticks[joypad], stick_deadzone)
		if stick != Vector2.ZERO:
			return stick
	return sample.digital_move.normalized()


func _aim_direction(sample: InputSample, stick_deadzone: float) -> Vector2:
	if _aim_mode == AimMode.MOUSE:
		if sample.mouse_offset_tiles.length() < MOUSE_AIM_MIN_DISTANCE_TILES:
			return Vector2.ZERO
		return sample.mouse_offset_tiles.normalized()
	var joypad: int = _resolve_joypad(sample)
	if joypad == NO_JOYPAD:
		return Vector2.ZERO
	return apply_deadzone(sample.right_sticks[joypad], stick_deadzone).normalized()


## The joypad of the last qualifying event, else the first connected one (C16).
func _resolve_joypad(sample: InputSample) -> int:
	if sample.left_sticks.has(_active_joypad):
		return _active_joypad
	if sample.left_sticks.is_empty():
		return NO_JOYPAD
	return sample.left_sticks.keys()[0]
