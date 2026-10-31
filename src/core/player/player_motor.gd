class_name PlayerMotor
extends RefCounted
## Movement and dash logic for one player (F-001 §3). Pure: no nodes, no Input (G6).
## Player intentions arrive only through submit() (G8). Tiles and seconds inside (C7).
## tick() consumes delta in exact segments (C15), so results don't depend on tick rate (G1).

signal dash_started
signal dash_ended
signal invulnerability_changed(is_invulnerable: bool)

enum State { IDLE, MOVING, DASHING }

## Absorbs float rounding at exact time boundaries. Far below AC13's 1 µs.
const TIME_EPSILON: float = 1e-9
const SNAPSHOT_KEYS: Array[String] = [
	"time",
	"position",
	"velocity",
	"facing",
	"state",
	"dash_direction",
	"dash_elapsed",
	"dash_distance",
	"dash_duration",
	"dash_iframe_duration",
	"cooldown_remaining",
	"has_buffered_dash",
	"buffered_dash_age",
	"invulnerable",
	"has_iframe_window",
	"iframe_start",
	"iframe_end",
]

var _class_data: ClassData
var _tunables: PlayerCombatTunables

var _time: float = 0.0
var _position: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.DOWN
var _state: State = State.IDLE

var _dash_direction: Vector2 = Vector2.ZERO
var _dash_elapsed: float = 0.0
# F-001/C17: latched when a dash fires, so a mid-dash reload affects the next one.
var _dash_distance: float = 0.0
var _dash_duration: float = 0.0
var _dash_iframe_duration: float = 0.0

var _cooldown_remaining: float = 0.0
var _has_buffered_dash: bool = false
var _buffered_dash_age: float = 0.0

var _invulnerable: bool = false
var _has_iframe_window: bool = false
var _iframe_start: float = 0.0
var _iframe_end: float = 0.0

# Per-tick only: never retained past tick(), so never in the snapshot (C5).
var _move_input: Vector2 = Vector2.ZERO
var _aim_input: Vector2 = Vector2.ZERO
var _dash_pressed: bool = false
var _fired_this_tick: bool = false
var _tick_displacement: Vector2 = Vector2.ZERO


## F-001/C18. Returns false and changes nothing if the data is invalid.
func setup(
	class_data: ClassData,
	tunables: PlayerCombatTunables,
	start_position_tiles: Vector2,
	initial_facing: Vector2 = Vector2.DOWN
) -> bool:
	if not _accepts(class_data, tunables):
		return false
	_class_data = class_data
	_tunables = tunables
	_reset_state()
	_position = start_position_tiles
	if initial_facing != Vector2.ZERO:
		_facing = initial_facing.normalized()
	return true


## F-001/C17. Replaces data only, state is kept. Returns false if the data is invalid.
func apply_data(class_data: ClassData, tunables: PlayerCombatTunables) -> bool:
	if not _accepts(class_data, tunables):
		return false
	_class_data = class_data
	_tunables = tunables
	return true


## F-001/C4: the only way player intentions reach the motor. Applies to the next tick().
func submit(command: Command) -> void:
	if command is MoveCommand:
		_move_input = (command as MoveCommand).direction.limit_length(1.0)
	elif command is AimCommand:
		_aim_input = (command as AimCommand).direction.normalized()
	elif command is DashCommand:
		_dash_pressed = true


## F-001/C15, step 2.
func tick(delta: float) -> void:
	if _class_data == null:
		_clear_commands()
		return
	var tick_start: float = _time
	_tick_displacement = Vector2.ZERO
	_fired_this_tick = false

	_update_facing()
	if _dash_pressed:
		_has_buffered_dash = true
		_buffered_dash_age = 0.0
	_run_phases(delta)
	if _has_buffered_dash and _buffered_dash_age > _buffer_window() + TIME_EPSILON:
		_has_buffered_dash = false

	_position += _tick_displacement
	if _state != State.DASHING:
		var is_moving: bool = _velocity != Vector2.ZERO or _move_input != Vector2.ZERO
		_state = State.MOVING if is_moving else State.IDLE
	_update_invulnerability(tick_start)
	_clear_commands()


## F-001/C18: the physics result is authoritative in the scene.
func sync_position(position_px: Vector2) -> void:
	_position = Units.vector_px_to_tiles(position_px)


## F-001/C5: valid only between ticks, with no pending commands.
func to_dict() -> Dictionary:
	return {
		"time": _time,
		"position": _position,
		"velocity": _velocity,
		"facing": _facing,
		"state": _state,
		"dash_direction": _dash_direction,
		"dash_elapsed": _dash_elapsed,
		"dash_distance": _dash_distance,
		"dash_duration": _dash_duration,
		"dash_iframe_duration": _dash_iframe_duration,
		"cooldown_remaining": _cooldown_remaining,
		"has_buffered_dash": _has_buffered_dash,
		"buffered_dash_age": _buffered_dash_age,
		"invulnerable": _invulnerable,
		"has_iframe_window": _has_iframe_window,
		"iframe_start": _iframe_start,
		"iframe_end": _iframe_end,
	}


## F-001/C5, C18. The caller then sets the body's position from get_position_px().
func from_dict(snapshot: Dictionary) -> void:
	if not snapshot.has_all(SNAPSHOT_KEYS):
		push_error("PlayerMotor snapshot rejected: missing keys")
		return
	_time = snapshot["time"]
	_position = snapshot["position"]
	_velocity = snapshot["velocity"]
	_facing = snapshot["facing"]
	_state = snapshot["state"]
	_dash_direction = snapshot["dash_direction"]
	_dash_elapsed = snapshot["dash_elapsed"]
	_dash_distance = snapshot["dash_distance"]
	_dash_duration = snapshot["dash_duration"]
	_dash_iframe_duration = snapshot["dash_iframe_duration"]
	_cooldown_remaining = snapshot["cooldown_remaining"]
	_has_buffered_dash = snapshot["has_buffered_dash"]
	_buffered_dash_age = snapshot["buffered_dash_age"]
	_invulnerable = snapshot["invulnerable"]
	_has_iframe_window = snapshot["has_iframe_window"]
	_iframe_start = snapshot["iframe_start"]
	_iframe_end = snapshot["iframe_end"]
	_clear_commands()


func get_tick_displacement_px() -> Vector2:
	return Units.vector_tiles_to_px(_tick_displacement)


func get_position_px() -> Vector2:
	return Units.vector_tiles_to_px(_position)


func get_facing() -> Vector2:
	return _facing


func get_state() -> State:
	return _state


## F-001/C8: true iff the i-frame window overlaps the last tick's interval.
func is_invulnerable() -> bool:
	return _invulnerable


## F-001/C8: the exact window [start, end) in motor-clock seconds. Empty once the last
## tick no longer overlaps it, or before any dash.
func get_iframe_window() -> PackedFloat64Array:
	if _has_iframe_window:
		return PackedFloat64Array([_iframe_start, _iframe_end])
	return PackedFloat64Array()


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func has_buffered_dash() -> bool:
	return _has_buffered_dash


func _accepts(class_data: ClassData, tunables: PlayerCombatTunables) -> bool:
	if class_data == null or tunables == null:
		push_error("PlayerMotor data rejected: missing resource")
		return false
	var errors: PackedStringArray = class_data.validate()
	errors.append_array(tunables.validate())
	if not errors.is_empty():
		push_error("PlayerMotor data rejected: %s" % ", ".join(errors))
		return false
	return true


func _reset_state() -> void:
	_time = 0.0
	_position = Vector2.ZERO
	_velocity = Vector2.ZERO
	_facing = Vector2.DOWN
	_state = State.IDLE
	_dash_direction = Vector2.ZERO
	_dash_elapsed = 0.0
	_dash_distance = 0.0
	_dash_duration = 0.0
	_dash_iframe_duration = 0.0
	_cooldown_remaining = 0.0
	_has_buffered_dash = false
	_buffered_dash_age = 0.0
	_invulnerable = false
	_has_iframe_window = false
	_iframe_start = 0.0
	_iframe_end = 0.0
	_tick_displacement = Vector2.ZERO
	_clear_commands()


func _clear_commands() -> void:
	_move_input = Vector2.ZERO
	_aim_input = Vector2.ZERO
	_dash_pressed = false


func _buffer_window() -> float:
	return _tunables.input_buffer_window


func _update_facing() -> void:
	if _aim_input != Vector2.ZERO:
		_facing = _aim_input
	elif _move_input != Vector2.ZERO:
		_facing = _move_input.normalized()


## F-001/C15 step c: never rounds to tick boundaries. A dash, its whole cooldown and the
## next dash can all fall inside one tick.
func _run_phases(delta: float) -> void:
	var remaining: float = delta
	while remaining > 0.0:
		if _state != State.DASHING and _can_fire_buffered_dash():
			_fire_dash()
		var segment: float = 0.0
		if _state == State.DASHING:
			segment = _advance_dash(remaining)
		else:
			segment = _advance_normal(remaining)
		_time += segment
		remaining -= segment
		if _has_buffered_dash:
			_buffered_dash_age += segment


func _can_fire_buffered_dash() -> bool:
	return (
		_has_buffered_dash
		and _cooldown_remaining <= 0.0
		and _buffered_dash_age <= _buffer_window() + TIME_EPSILON
	)


func _fire_dash() -> void:
	_has_buffered_dash = false
	_dash_distance = _class_data.dash_distance
	_dash_duration = _class_data.dash_duration
	_dash_iframe_duration = _class_data.dash_iframe_duration
	var direction: Vector2 = _move_input if _move_input != Vector2.ZERO else _facing
	_dash_direction = direction.normalized()
	_dash_elapsed = 0.0
	_velocity = _dash_direction * (_dash_distance / _dash_duration)
	_state = State.DASHING
	_has_iframe_window = true
	_iframe_start = _time
	_iframe_end = _time + _dash_iframe_duration
	_fired_this_tick = true
	dash_started.emit()


## Returns the time consumed.
func _advance_dash(limit: float) -> float:
	var dash_time_left: float = _dash_duration - _dash_elapsed
	var segment: float = minf(limit, dash_time_left)
	_tick_displacement += _velocity * segment
	_dash_elapsed += segment
	if dash_time_left - segment <= TIME_EPSILON:
		_end_dash()
	return segment


func _end_dash() -> void:
	_velocity = Vector2.ZERO
	_cooldown_remaining = _class_data.dash_cooldown  # F-001/C9
	_state = State.IDLE
	dash_ended.emit()


## Returns the time consumed. Stops exactly at cooldown expiry if a dash is waiting for it.
func _advance_normal(limit: float) -> float:
	var segment: float = limit
	if _cooldown_remaining > 0.0 and _has_buffered_dash:
		segment = minf(limit, _cooldown_remaining)
	_integrate_movement(segment)
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - segment)
	return segment


## F-001/C15 step d: exact integral of piecewise-constant acceleration, not Euler steps.
func _integrate_movement(duration: float) -> void:
	var target: Vector2 = _move_input * _class_data.move_speed
	var time_left: float = _ramp_toward(
		_slowdown_end(target), _class_data.move_decel_time, duration
	)
	time_left = _ramp_toward(target, _class_data.move_accel_time, time_left)
	_tick_displacement += _velocity * time_left


## Where speed first falls to the target's speed, on the straight line from the current
## velocity to the target. Decel applies up to there and accel after it, even if that
## point falls inside a tick, or a reversal would depend on the tick rate.
func _slowdown_end(target: Vector2) -> Vector2:
	var target_speed: float = target.length()
	if _velocity.length() <= target_speed:
		return _velocity
	var to_target: Vector2 = target - _velocity
	var gap: float = to_target.length()
	var along: Vector2 = to_target / gap
	var projection: float = _velocity.dot(along)
	var half_chord_squared: float = (
		target_speed * target_speed - _velocity.length_squared() + projection * projection
	)
	var entry: float = -projection - sqrt(maxf(half_chord_squared, 0.0))
	if entry >= gap:
		return target
	return _velocity + along * entry


## Moves velocity straight toward goal at constant acceleration. change_time is the time
## a full move_speed change takes, 0 means instant. Returns the time left over.
func _ramp_toward(goal: Vector2, change_time: float, time_left: float) -> float:
	if _velocity == goal:
		return time_left
	if change_time <= 0.0:
		_velocity = goal
		return time_left
	var gap: float = _velocity.distance_to(goal)
	var acceleration: float = _class_data.move_speed / change_time
	var time_to_goal: float = gap / acceleration
	var end_velocity: Vector2 = goal
	var ramp_time: float = time_to_goal
	if time_left < time_to_goal:
		end_velocity = _velocity.lerp(goal, time_left / time_to_goal)
		ramp_time = time_left
	_tick_displacement += (_velocity + end_velocity) * 0.5 * ramp_time
	_velocity = end_velocity
	return time_left - ramp_time


## F-001/C8: a half-open interval overlap, so a fire tick always reports true.
func _update_invulnerability(tick_start: float) -> void:
	var overlapped: bool = (
		_fired_this_tick
		or (
			_has_iframe_window and _iframe_start < _time and tick_start < _iframe_end - TIME_EPSILON
		)
	)
	if not overlapped:
		_has_iframe_window = false
	if overlapped != _invulnerable:
		_invulnerable = overlapped
		invulnerability_changed.emit(_invulnerable)
