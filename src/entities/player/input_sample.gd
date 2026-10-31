class_name InputSample
extends RefCounted
## Raw device values for one tick, filled by PlayerInput. Plain data, so the mapper can be
## tested without devices (F-001 §3).

enum DeviceEventKind { MOUSE_MOTION, MOUSE_BUTTON, JOY_BUTTON, JOY_STICK }


## A device event, in arrival order (F-001/C16: the last qualifying one wins).
class DeviceEvent:
	var kind: DeviceEventKind
	var device: int
	var magnitude: float

	func _init(event_kind: DeviceEventKind, event_device: int = 0, value: float = 0.0) -> void:
		kind = event_kind
		device = event_device
		magnitude = value


## Keys and D-pad, each component -1, 0 or 1. Never includes stick values (F-001/C14).
var digital_move: Vector2 = Vector2.ZERO
## Raw stick vectors by connected joypad, in connection order.
var left_sticks: Dictionary[int, Vector2] = {}
var right_sticks: Dictionary[int, Vector2] = {}
## From the player to the mouse's world position.
var mouse_offset_tiles: Vector2 = Vector2.ZERO
var dodge_pressed: bool = false
var device_events: Array[DeviceEvent] = []
