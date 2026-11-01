class_name DummyLogic
extends Combatant
## The training dummy's logic (F-003 T10). Never moves on its own and never chooses to
## attack: its pulse is a debug tool toggled from outside (AC19). Not an enemy (§3).

signal state_restored

const SNAPSHOT_KEYS: Array[String] = [
	"position",
	"is_ko",
	"respawn_remaining",
	"pulse_enabled",
	"pulse",
	"combat",
]

var _data: DummyData
var _knockback_scale: float = 0.0
var _is_ko: bool = false
var _respawn_remaining: float = 0.0
var _pulse_enabled: bool = false
var _pulse: PulseCycle = PulseCycle.new()


## F-003/C20: re-running this is the debug reset. Returns false and changes nothing if the
## data is invalid. knockback_scale is the scene's per-instance value (F-003/C2).
func setup(
	data: DummyData,
	step_rate: int,
	start_position_tiles: Vector2,
	knockback_scale: float,
	combat_id: StringName
) -> bool:
	if not _accepts(data, step_rate):
		return false
	_data = data
	_knockback_scale = knockback_scale
	_combat_id = combat_id
	_team = Team.ENEMY
	_position = start_position_tiles
	_tick_displacement = Vector2.ZERO
	_is_ko = false
	_respawn_remaining = 0.0
	_pulse_enabled = false
	_pulse.stop()
	_combat.setup(data.max_hp, false)
	return true


## F-003/C18: replaces data only. A running pulse and respawn keep what they latched.
func apply_data(data: DummyData, step_rate: int) -> bool:
	if not _accepts(data, step_rate):
		return false
	_data = data
	_combat.set_max_hp(data.max_hp)
	return true


## F-003/C20. Debug keys act between ticks.
func set_pulse_enabled(enabled: bool) -> void:
	if enabled == _pulse_enabled:
		return
	_pulse_enabled = enabled
	if not enabled:
		_pulse.stop()
	elif not _is_ko:
		_pulse.start(_data)


func is_pulse_enabled() -> bool:
	return _pulse_enabled


func get_pulse_phase() -> PulseCycle.Phase:
	return _pulse.get_phase()


## The radius of the running pulse, for its telegraph ring.
func get_pulse_radius_tiles() -> float:
	return _pulse.get_radius_tiles()


func is_ko() -> bool:
	return _is_ko


func step(duration: float) -> void:
	if _data == null:
		return
	_tick_displacement = Vector2.ZERO
	var remaining: float = _combat.consume_hitstop(duration)  # F-003/C7, C15.
	while remaining > 0.0:
		var segment: float = minf(remaining, _time_to_next_event())
		_advance(segment)
		remaining -= segment
	_position += _tick_displacement


func apply_hit(event: HitEvent, tunables: PlayerCombatTunables) -> void:
	_combat.apply_hit(event, tunables)
	if _combat.get_hp() == 0 and not _is_ko:
		_enter_ko()


func get_knockback_scale() -> float:
	return _knockback_scale


func to_dict() -> Dictionary:
	return {
		"position": _position,
		"is_ko": _is_ko,
		"respawn_remaining": _respawn_remaining,
		"pulse_enabled": _pulse_enabled,
		"pulse": _pulse.to_dict(),
		"combat": _combat.to_dict(),
	}


func from_dict(snapshot: Dictionary) -> void:
	if not snapshot.has_all(SNAPSHOT_KEYS):
		push_error("DummyLogic snapshot rejected: missing keys")
		return
	_position = snapshot["position"]
	_is_ko = snapshot["is_ko"]
	_respawn_remaining = snapshot["respawn_remaining"]
	_pulse_enabled = snapshot["pulse_enabled"]
	_pulse.from_dict(snapshot["pulse"])
	_combat.from_dict(snapshot["combat"])
	state_restored.emit()


func _accepts(data: DummyData, step_rate: int) -> bool:
	if data == null:
		push_error("DummyLogic data rejected: missing resource")
		return false
	var errors: PackedStringArray = data.validate(step_rate)
	if not errors.is_empty():
		push_error("DummyLogic data rejected: %s" % ", ".join(errors))
		return false
	return true


func _is_protected() -> bool:
	return _is_ko


func _running_window() -> PackedFloat64Array:
	return _pulse.get_running_window()


func _hurtbox_radius() -> float:
	return _data.hurtbox_radius_tiles


func _build_live_hitbox() -> Hitbox:
	return _pulse.build_hitbox(_combat_id, _team, _position)


## Knockback, respawn and pulse boundaries fall at exact times inside a step (F-003/C15).
func _time_to_next_event() -> float:
	var next: float = INF
	if _combat.has_knockback():
		next = _combat.get_knockback_time_left()
	if _is_ko:
		next = minf(next, _respawn_remaining)
	elif _pulse.get_phase() != PulseCycle.Phase.OFF:
		next = minf(next, _pulse.get_phase_time_left())
	return next


func _advance(segment: float) -> void:
	if _combat.has_knockback():
		_tick_displacement += _combat.get_knockback_velocity() * segment
		_combat.advance_knockback(segment)
	if _is_ko:
		_respawn_remaining -= segment
		if _respawn_remaining <= CombatTiming.TIME_EPSILON:
			_respawn()
	else:
		_pulse.advance(segment, _data)


## AC18, F-003/C20: same effect as toggle off, while the toggle stays on.
func _enter_ko() -> void:
	_is_ko = true
	_respawn_remaining = _data.respawn_delay
	_pulse.stop()


func _respawn() -> void:
	_is_ko = false
	_respawn_remaining = 0.0
	_combat.refill()
	if _pulse_enabled:
		_pulse.start(_data)
