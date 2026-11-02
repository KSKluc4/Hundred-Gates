class_name AttackChain
extends RefCounted
## One player's attack chain (F-003 T8): which hit is next, the running hit and its phase,
## the chain window and the hit set. PlayerMotor decides when a hit may start.

enum Phase { NONE, WINDUP, ACTIVE, RECOVERY }

const TIME_EPSILON: float = CombatTiming.TIME_EPSILON

var _next_index: int = 0
var _phase: Phase = Phase.NONE
var _phase_elapsed: float = 0.0
# F-003/C18: every field latched at windup start, so a reload can't touch a running hit.
var _attack: AttackData = null
var _direction: Vector2 = Vector2.ZERO
# F-003/C8: ids, never references (C19). Replaced, not cleared: a Hitbox from this contact
# shares it, and a trade may still mark it after this attack was interrupted (C16).
var _hit_ids: Array[StringName] = []
var _window_remaining: float = 0.0


## AC3: `direction` is the facing at the first instant of windup. The chain must not be empty.
func start(chain: Array[AttackData], direction: Vector2) -> void:
	var index: int = _next_index if _next_index < chain.size() else 0
	_attack = chain[index].duplicate()
	_next_index = (index + 1) % chain.size()
	_direction = direction
	_hit_ids = []
	_window_remaining = 0.0
	_phase = Phase.WINDUP
	_phase_elapsed = 0.0
	_cross_finished_phases(0.0)


## Advances a running hit, never past the end of its phase. chain_window is latched here,
## at the first instant of recovery (F-003/C18).
func advance(seconds: float, chain_window: float) -> void:
	_phase_elapsed += seconds
	_window_remaining = maxf(0.0, _window_remaining - seconds)
	_cross_finished_phases(chain_window)


## After recovery, the window closing is what resets the chain. A recovery press chains even
## if the window has already run out (F-003/C17), so this only runs outside a hit.
func advance_window(seconds: float) -> void:
	if _window_remaining <= 0.0:
		return
	_window_remaining -= seconds
	if _window_remaining <= TIME_EPSILON:
		_close_window()


## F-003/C17: an interrupt or a dash. Nothing of the chain survives it.
func reset() -> void:
	_clear_running_hit()
	_close_window()


## F-003/C18: a reload may shorten the chain.
func clamp_next_index(chain_size: int) -> void:
	if _next_index >= chain_size:
		_next_index = 0


func get_phase() -> Phase:
	return _phase


func get_phase_time_left() -> float:
	return _phase_duration() - _phase_elapsed


func get_next_index() -> int:
	return _next_index


func get_window_remaining() -> float:
	return _window_remaining


func get_attack_id() -> StringName:
	return _attack.id if _attack != null else &""


func is_finisher() -> bool:
	return _attack != null and _attack.is_finisher


## F-003/C18: [lead, active] while the window can still be lost, else empty.
func get_running_window() -> PackedFloat64Array:
	if _phase == Phase.WINDUP or _phase == Phase.ACTIVE:
		return PackedFloat64Array([_attack.windup, _attack.active])
	return PackedFloat64Array()


## Null outside the active phase.
func build_hitbox(owner_id: StringName, team: Combatant.Team, origin: Vector2) -> Hitbox:
	if _phase != Phase.ACTIVE:
		return null
	var hitbox: Hitbox = Hitbox.new()
	hitbox.owner_id = owner_id
	hitbox.team = team
	hitbox.origin = origin
	hitbox.direction = _direction
	hitbox.arc_angle_deg = _attack.arc_angle_deg
	hitbox.range_tiles = _attack.range_tiles
	hitbox.damage = _attack.damage
	hitbox.knockback_tiles = _attack.knockback_tiles
	hitbox.is_finisher = _attack.is_finisher
	hitbox.hit_ids = _hit_ids
	return hitbox


func to_dict() -> Dictionary:
	return {
		"next_index": _next_index,
		"phase": _phase,
		"phase_elapsed": _phase_elapsed,
		"attack": _attack.to_dict() if _attack != null else {},
		"direction": _direction,
		"hit_ids": _hit_ids.duplicate(),
		"window_remaining": _window_remaining,
	}


func from_dict(snapshot: Dictionary) -> void:
	_next_index = snapshot["next_index"]
	_phase = snapshot["phase"]
	_phase_elapsed = snapshot["phase_elapsed"]
	var attack: Dictionary = snapshot["attack"]
	_attack = null if attack.is_empty() else AttackData.from_dict(attack)
	_direction = snapshot["direction"]
	_hit_ids = []
	_hit_ids.assign(snapshot["hit_ids"])
	_window_remaining = snapshot["window_remaining"]


func _phase_duration() -> float:
	match _phase:
		Phase.WINDUP:
			return _attack.windup
		Phase.ACTIVE:
			return _attack.active
		Phase.RECOVERY:
			return _attack.recovery
	return 0.0


## F-003/C15: a phase reaching its end crosses now, so the contact at this instant sees the
## new phase. A loop, because windup and recovery may be 0.
func _cross_finished_phases(chain_window: float) -> void:
	while _phase != Phase.NONE and get_phase_time_left() <= TIME_EPSILON:
		_phase_elapsed = 0.0
		match _phase:
			Phase.WINDUP:
				_phase = Phase.ACTIVE
			Phase.ACTIVE:
				_phase = Phase.RECOVERY
				_window_remaining = chain_window
			Phase.RECOVERY:
				_finish_recovery()


func _finish_recovery() -> void:
	_clear_running_hit()
	if _window_remaining <= TIME_EPSILON:
		_close_window()


func _clear_running_hit() -> void:
	_phase = Phase.NONE
	_phase_elapsed = 0.0
	_attack = null
	_direction = Vector2.ZERO
	_hit_ids = []


func _close_window() -> void:
	_window_remaining = 0.0
	_next_index = 0
