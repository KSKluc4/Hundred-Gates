class_name PulseCycle
extends RefCounted
## The dummy's debug pulse (F-003/C20): telegraph, active, wait, start to start. Every value
## is latched at telegraph start, so a reload applies from the next pulse (C18).

enum Phase { OFF, TELEGRAPH, ACTIVE, WAIT }

const TIME_EPSILON: float = CombatTiming.TIME_EPSILON
const FULL_CIRCLE_DEG: float = 360.0
## AC12: a pulse pushes this way, not away from its center.
const KNOCKBACK_DIRECTION: Vector2 = Vector2.DOWN
const SNAPSHOT_KEYS: Array[String] = [
	"phase",
	"phase_elapsed",
	"interval",
	"telegraph",
	"active",
	"radius",
	"damage",
	"knockback",
	"hit_ids",
]

var _phase: Phase = Phase.OFF
var _phase_elapsed: float = 0.0
var _interval: float = 0.0
var _telegraph: float = 0.0
var _active: float = 0.0
var _radius: float = 0.0
var _damage: int = 0
var _knockback: float = 0.0
# Belongs to one active phase, clears at the next telegraph (F-003/C20). Replaced, not
# cleared, like AttackChain's: a trade may still mark it after the pulse was stopped.
var _hit_ids: Array[StringName] = []


## F-003/C20: a new cycle, at telegraph.
func start(data: DummyData) -> void:
	_begin_cycle(data)
	_cross_finished_phases(data)


## F-003/C20: stops at once. The hitbox is gone and the hit set is cleared.
func stop() -> void:
	_phase = Phase.OFF
	_phase_elapsed = 0.0
	_hit_ids = []


## Never past the end of a phase. `data` is what the next cycle latches.
func advance(seconds: float, data: DummyData) -> void:
	if _phase == Phase.OFF:
		return
	_phase_elapsed += seconds
	_cross_finished_phases(data)


func get_phase() -> Phase:
	return _phase


func get_phase_time_left() -> float:
	return _phase_duration() - _phase_elapsed


func get_radius_tiles() -> float:
	return _radius


## F-003/C18: [lead, active] while the window can still be lost, else empty.
func get_running_window() -> PackedFloat64Array:
	if _phase == Phase.TELEGRAPH or _phase == Phase.ACTIVE:
		return PackedFloat64Array([_telegraph, _active])
	return PackedFloat64Array()


## Null outside the active phase.
func build_hitbox(owner_id: StringName, team: Combatant.Team, origin: Vector2) -> Hitbox:
	if _phase != Phase.ACTIVE:
		return null
	var hitbox: Hitbox = Hitbox.new()
	hitbox.owner_id = owner_id
	hitbox.team = team
	hitbox.origin = origin
	hitbox.direction = KNOCKBACK_DIRECTION
	hitbox.arc_angle_deg = FULL_CIRCLE_DEG
	hitbox.range_tiles = _radius
	hitbox.damage = _damage
	hitbox.knockback_tiles = _knockback
	hitbox.knockback_from_center = false
	hitbox.hit_ids = _hit_ids
	return hitbox


func to_dict() -> Dictionary:
	return {
		"phase": _phase,
		"phase_elapsed": _phase_elapsed,
		"interval": _interval,
		"telegraph": _telegraph,
		"active": _active,
		"radius": _radius,
		"damage": _damage,
		"knockback": _knockback,
		"hit_ids": _hit_ids.duplicate(),
	}


func from_dict(snapshot: Dictionary) -> void:
	_phase = snapshot["phase"]
	_phase_elapsed = snapshot["phase_elapsed"]
	_interval = snapshot["interval"]
	_telegraph = snapshot["telegraph"]
	_active = snapshot["active"]
	_radius = snapshot["radius"]
	_damage = snapshot["damage"]
	_knockback = snapshot["knockback"]
	_hit_ids = []
	_hit_ids.assign(snapshot["hit_ids"])


func _begin_cycle(data: DummyData) -> void:
	_phase = Phase.TELEGRAPH
	_phase_elapsed = 0.0
	_interval = data.pulse_interval
	_telegraph = data.pulse_telegraph
	_active = data.pulse_active
	_radius = data.pulse_radius_tiles
	_damage = data.pulse_damage
	_knockback = data.pulse_knockback_tiles
	_hit_ids = []


func _phase_duration() -> float:
	match _phase:
		Phase.TELEGRAPH:
			return _telegraph
		Phase.ACTIVE:
			return _active
		Phase.WAIT:
			return maxf(0.0, _interval - _telegraph - _active)
	return 0.0


## F-003/C15: a phase reaching its end crosses now. A loop, because telegraph and wait may be
## 0. It ends because active is never 0 (C18).
func _cross_finished_phases(data: DummyData) -> void:
	while _phase != Phase.OFF and get_phase_time_left() <= TIME_EPSILON:
		_phase_elapsed = 0.0
		match _phase:
			Phase.TELEGRAPH:
				_phase = Phase.ACTIVE
			Phase.ACTIVE:
				_phase = Phase.WAIT
			Phase.WAIT:
				_begin_cycle(data)
