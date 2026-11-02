class_name PlayerMotor
extends Combatant
## Movement and dash logic for one player (F-001 §3). Pure: no nodes, no Input (G6).
## Player intentions arrive only through submit() (G8). Tiles and seconds inside (C7).
## step() consumes time in exact segments (C15), so results don't depend on tick rate (G1).

signal dash_started
signal dash_ended
signal invulnerability_changed(is_invulnerable: bool)
## F-003/C12: from_dict() sends no change signals, so views re-sync from state on this.
signal state_restored

enum State { IDLE, MOVING, DASHING, ATTACKING, KNOCKBACK }

## F-003 T2: CombatTiming owns it, this name stays for F-001's code and tests.
const TIME_EPSILON: float = CombatTiming.TIME_EPSILON
const DEFAULT_COMBAT_ID: StringName = &"player_1"
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
	"has_buffered_attack",
	"buffered_attack_age",
	"attack_chain",
	"combat",
]

var _class_data: ClassData
var _tunables: PlayerCombatTunables

var _time: float = 0.0
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

var _has_buffered_attack: bool = false
var _buffered_attack_age: float = 0.0
var _attack_chain: AttackChain = AttackChain.new()

# Per-tick only: never retained past finish_tick(), so never in the snapshot (C5).
var _move_input: Vector2 = Vector2.ZERO
var _aim_input: Vector2 = Vector2.ZERO
var _dash_pressed: bool = false
var _attack_pressed: bool = false
var _fired_this_step: bool = false


## F-001/C18. Returns false and changes nothing if the data is invalid.
func setup(
	class_data: ClassData,
	tunables: PlayerCombatTunables,
	start_position_tiles: Vector2,
	initial_facing: Vector2 = Vector2.DOWN,
	combat_id: StringName = DEFAULT_COMBAT_ID
) -> bool:
	if not _accepts(class_data, tunables):
		return false
	_combat_id = combat_id
	_team = Team.PLAYER
	_class_data = class_data
	_tunables = tunables
	_reset_state()
	_combat.setup(class_data.max_hp, true)
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
	_attack_chain.clamp_next_index(class_data.attack_chain.size())
	_combat.set_max_hp(class_data.max_hp)
	return true


## F-001/C4: the only way player intentions reach the motor. Applies to the next tick().
func submit(command: Command) -> void:
	if command is MoveCommand:
		_move_input = (command as MoveCommand).direction.limit_length(1.0)
	elif command is AimCommand:
		_aim_input = (command as AimCommand).direction.normalized()
	elif command is DashCommand:
		_dash_pressed = true
	elif command is AttackCommand:
		_attack_pressed = true


## F-001/C15, step 2: one tick is one step that long. F-001's API, with its behavior.
func tick(delta: float) -> void:
	step(delta)
	finish_tick()


## F-003/C15: held commands stay for the next step, presses are consumed here.
func step(duration: float) -> void:
	if _class_data == null:
		return
	var step_start: float = _time
	_tick_displacement = Vector2.ZERO
	_fired_this_step = false

	_update_facing()
	_take_presses()
	_run_phases(_combat.consume_hitstop(duration))  # F-003/C7, C15: hitstop goes first.
	if _has_buffered_dash and _buffered_dash_age > _buffer_window() + TIME_EPSILON:
		_has_buffered_dash = false
	if _has_buffered_attack and _buffered_attack_age > _buffer_window() + TIME_EPSILON:
		_has_buffered_attack = false

	_position += _tick_displacement
	if _is_free():
		var is_moving: bool = _velocity != Vector2.ZERO or _move_input != Vector2.ZERO
		_state = State.MOVING if is_moving else State.IDLE
	_update_invulnerability(step_start)


func finish_tick() -> void:
	_clear_commands()


## F-003/C17, AC15: a hit that landed. Interrupts any attack or dash, leaves the buffers.
func apply_hit(event: HitEvent, tunables: PlayerCombatTunables) -> void:
	if _state == State.DASHING:
		_end_dash()  # Velocity 0, and the full cooldown starts here (F-001/C9).
	_attack_chain.reset()
	_velocity = Vector2.ZERO
	# The motion itself starts when hitstop ends (F-003/C15).
	_state = State.KNOCKBACK if event.knockback_tiles > 0.0 else State.IDLE
	_combat.apply_hit(event, tunables)


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
		"has_buffered_attack": _has_buffered_attack,
		"buffered_attack_age": _buffered_attack_age,
		"attack_chain": _attack_chain.to_dict(),
		"combat": _combat.to_dict(),
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
	_has_buffered_attack = snapshot["has_buffered_attack"]
	_buffered_attack_age = snapshot["buffered_attack_age"]
	_attack_chain.from_dict(snapshot["attack_chain"])
	_combat.from_dict(snapshot["combat"])
	_clear_commands()
	state_restored.emit()


## F-003 T16: the body's velocity holds only one step's share once a tick has several.
func get_velocity_tiles() -> Vector2:
	return _velocity


func get_facing() -> Vector2:
	return _facing


func get_state() -> State:
	return _state


## F-001/C8: true iff the i-frame window overlaps the last step's interval. A presentation
## flag: hits use is_dash_protected() (F-003/C15).
func is_invulnerable() -> bool:
	return _invulnerable


## F-001/C8: the exact window [start, end) in motor-clock seconds. Empty once the last
## step no longer overlaps it, or before any dash.
func get_iframe_window() -> PackedFloat64Array:
	if _has_iframe_window:
		return PackedFloat64Array([_iframe_start, _iframe_end])
	return PackedFloat64Array()


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func has_buffered_dash() -> bool:
	return _has_buffered_dash


func has_buffered_attack() -> bool:
	return _has_buffered_attack


## Read-only for callers: the chain changes only through commands (G8).
func get_attack_chain() -> AttackChain:
	return _attack_chain


func get_knockback_scale() -> float:
	return _class_data.knockback_scale


## F-003/C15: the exact check. is_invulnerable() never decides a hit.
func is_dash_protected() -> bool:
	return (
		_has_iframe_window
		and _time >= _iframe_start - TIME_EPSILON
		and _time < _iframe_end - TIME_EPSILON
	)


func _accepts(class_data: ClassData, tunables: PlayerCombatTunables) -> bool:
	if class_data == null or tunables == null:
		push_error("PlayerMotor data rejected: missing resource")
		return false
	var errors: PackedStringArray = class_data.validate()
	errors.append_array(tunables.validate())
	errors.append_array(tunables.validate_combat())
	errors.append_array(class_data.validate_combat(tunables.combat_step_rate))
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
	_has_buffered_attack = false
	_buffered_attack_age = 0.0
	_attack_chain.reset()
	_tick_displacement = Vector2.ZERO
	_clear_commands()


func _clear_commands() -> void:
	_move_input = Vector2.ZERO
	_aim_input = Vector2.ZERO
	_dash_pressed = false
	_attack_pressed = false


## F-003/C7, C17: a buffer stays stored through hitstop, and one ending on this instant is over.
func _fire_due_actions() -> void:
	if _class_data == null or _combat.is_in_hitstop():
		return
	_fire_buffered_actions()
	if _fired_this_step:
		_update_invulnerability(_time)  # F-001/C8: the step a dash fires in reports true.


func _build_live_hitbox() -> Hitbox:
	return _attack_chain.build_hitbox(_combat_id, _team, _position)


func _is_protected() -> bool:
	return is_dash_protected()


func _running_window() -> PackedFloat64Array:
	return _attack_chain.get_running_window()


func _hurtbox_radius() -> float:
	return _class_data.hurtbox_radius_tiles


func _is_free() -> bool:
	return _state == State.IDLE or _state == State.MOVING


func _is_in_recovery() -> bool:
	return _state == State.ATTACKING and _attack_chain.get_phase() == AttackChain.Phase.RECOVERY


## F-001/C15, F-003/C17: every press enters its buffer, and fires from there.
func _take_presses() -> void:
	if _dash_pressed:
		_has_buffered_dash = true
		_buffered_dash_age = 0.0
		_dash_pressed = false
	if _attack_pressed:
		_has_buffered_attack = true
		_buffered_attack_age = 0.0
		_attack_pressed = false


func _buffer_window() -> float:
	return _tunables.input_buffer_window


func _update_facing() -> void:
	if _aim_input != Vector2.ZERO:
		_facing = _aim_input
	elif _move_input != Vector2.ZERO:
		_facing = _move_input.normalized()


## F-001/C15 step c: never rounds to step boundaries. A dash, its whole cooldown and the
## next dash can all fall inside one step.
func _run_phases(duration: float) -> void:
	var remaining: float = duration
	# F-003/C15: a remainder this small is rounding, not time. Without this, a buffer due on
	# a step's end would fire before or after that contact depending on the rounding.
	while remaining > TIME_EPSILON:
		_fire_buffered_actions()
		var segment: float = 0.0
		match _state:
			State.DASHING:
				segment = _advance_dash(remaining)
			State.ATTACKING:
				segment = _advance_attack(remaining)
			State.KNOCKBACK:
				segment = _advance_knockback(remaining)
			_:
				segment = _advance_normal(remaining)
		_time += segment
		remaining -= segment
		_combat.advance_hurt_iframes(segment)  # AC14: they run during knockback.
		if _has_buffered_dash:
			_buffered_dash_age += segment
		if _has_buffered_attack:
			_buffered_attack_age += segment
	_time += remaining


## F-003/C17: the dash wins, whatever the press order, and an attack that could also fire
## now is discarded. A dash that can't fire yet doesn't block an attack that can.
func _fire_buffered_actions() -> void:
	if _can_fire_buffered_dash():
		if _can_fire_buffered_attack():
			_has_buffered_attack = false
		_fire_dash()
	elif _can_fire_buffered_attack():
		_fire_attack()


func _can_fire_buffered_dash() -> bool:
	return (
		_has_buffered_dash
		and (_is_free() or _is_in_recovery())
		# F-003/C15: rounding must not move a fire past the contact on its expiry instant.
		and _cooldown_remaining <= TIME_EPSILON
		and _buffered_dash_age <= _buffer_window() + TIME_EPSILON
	)


func _can_fire_buffered_attack() -> bool:
	if not _has_buffered_attack or _buffered_attack_age > _buffer_window() + TIME_EPSILON:
		return false
	if _is_in_recovery():
		return not _attack_chain.is_finisher()  # AC6: only a dash cancels a finisher's recovery.
	return _is_free()


func _fire_attack() -> void:
	_has_buffered_attack = false
	_attack_chain.start(_class_data.attack_chain, _facing)
	_state = State.ATTACKING


func _fire_dash() -> void:
	_has_buffered_dash = false
	_attack_chain.reset()  # F-003/C17: any dash that fires resets the chain.
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
	_fired_this_step = true
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


## Returns the time consumed.
func _advance_normal(limit: float) -> float:
	var segment: float = _stop_at_cooldown_expiry(limit)
	_integrate_movement(segment, _move_input * _class_data.move_speed)
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - segment)
	_attack_chain.advance_window(segment)
	return segment


## AC7: rooted, whatever the move input says. Returns the time consumed.
func _advance_attack(limit: float) -> float:
	var segment: float = minf(_stop_at_cooldown_expiry(limit), _attack_chain.get_phase_time_left())
	_integrate_movement(segment, Vector2.ZERO)
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - segment)
	_attack_chain.advance(segment, _class_data.attack_chain_window)
	if _attack_chain.get_phase() == AttackChain.Phase.NONE:
		_state = State.IDLE
	return segment


## AC12: at constant speed for its duration, and walls don't change when it ends. Returns
## the time consumed.
func _advance_knockback(limit: float) -> float:
	var segment: float = minf(_stop_at_cooldown_expiry(limit), _combat.get_knockback_time_left())
	_velocity = _combat.get_knockback_velocity()
	_tick_displacement += _velocity * segment
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - segment)
	_combat.advance_knockback(segment)
	if not _combat.has_knockback():
		_velocity = Vector2.ZERO
		_state = State.IDLE
	return segment


## A waiting dash fires at the exact instant its cooldown ends.
func _stop_at_cooldown_expiry(limit: float) -> float:
	if _cooldown_remaining > 0.0 and _has_buffered_dash:
		return minf(limit, _cooldown_remaining)
	return limit


## F-001/C15 step d: exact integral of piecewise-constant acceleration, not Euler steps.
func _integrate_movement(duration: float, target: Vector2) -> void:
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


## F-001/C8: a half-open interval overlap, so a fire step always reports true.
func _update_invulnerability(step_start: float) -> void:
	var overlapped: bool = (
		_fired_this_step
		or (
			_has_iframe_window and _iframe_start < _time and step_start < _iframe_end - TIME_EPSILON
		)
	)
	if not overlapped:
		_has_iframe_window = false
	if overlapped != _invulnerable:
		_invulnerable = overlapped
		invulnerability_changed.emit(_invulnerable)
