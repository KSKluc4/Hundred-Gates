class_name CombatState
extends RefCounted
## What being in a fight adds to an entity (F-003 T7): HP, hitstop, knockback, hurt i-frames.
## Shared by the player and the dummy. Logic never emits shake (C10): presentation listens.

signal hit_landed(event: HitEvent)
signal damaged(event: HitEvent)
signal died

const TIME_EPSILON: float = CombatTiming.TIME_EPSILON
const SNAPSHOT_KEYS: Array[String] = [
	"hp",
	"hitstop_remaining",
	"hurt_iframes_remaining",
	"knockback_remaining",
	"knockback_direction",
	"knockback_speed",
]

var _max_hp: int = 0
var _has_hurt_iframes: bool = false
var _hp: int = 0
var _hitstop_remaining: float = 0.0
var _hurt_iframes_remaining: float = 0.0
var _knockback_remaining: float = 0.0
var _knockback_direction: Vector2 = Vector2.ZERO
var _knockback_speed: float = 0.0


## has_hurt_iframes: true for players only in phase 1 (design doc, Q3).
func setup(max_hp: int, has_hurt_iframes: bool) -> void:
	_max_hp = max_hp
	_has_hurt_iframes = has_hurt_iframes
	_hp = max_hp
	_hitstop_remaining = 0.0
	_hurt_iframes_remaining = 0.0
	_clear_knockback()


## AC11, on the target: damage, knockback, hitstop, hurt i-frames, then the signals.
## New timers start here, at the contact instant, so the next step consumes them first.
func apply_hit(event: HitEvent, tunables: PlayerCombatTunables) -> void:
	var was_alive: bool = _hp > 0
	_hp = maxi(0, _hp - event.damage)
	_start_knockback(event, tunables)
	_extend_hitstop(event, tunables)
	if _has_hurt_iframes:
		_hurt_iframes_remaining = tunables.player_hurt_iframes
	damaged.emit(event)
	if was_alive and _hp == 0:
		died.emit()


## AC11, on the attacker. C16: one attack hitting several targets at one instant gets one
## hitstop, because the second max() changes nothing.
func apply_landed(event: HitEvent, tunables: PlayerCombatTunables) -> void:
	_extend_hitstop(event, tunables)
	hit_landed.emit(event)


## F-003/C15: hitstop goes first in a step. Returns what's left of the step, carried exactly.
func consume_hitstop(duration: float) -> float:
	var consumed: float = minf(duration, _hitstop_remaining)
	_hitstop_remaining -= consumed
	if _hitstop_remaining <= TIME_EPSILON:
		_hitstop_remaining = 0.0
	return duration - consumed


func is_in_hitstop() -> bool:
	return _hitstop_remaining > 0.0


func get_hitstop_remaining() -> float:
	return _hitstop_remaining


func get_hp() -> int:
	return _hp


func get_max_hp() -> int:
	return _max_hp


## F-003/C18: raising it doesn't heal.
func set_max_hp(max_hp: int) -> void:
	_max_hp = max_hp
	_hp = mini(_hp, max_hp)


func refill() -> void:
	_hp = _max_hp


func is_hurt_protected() -> bool:
	return _hurt_iframes_remaining > TIME_EPSILON


func get_hurt_iframes_remaining() -> float:
	return _hurt_iframes_remaining


func advance_hurt_iframes(seconds: float) -> void:
	_hurt_iframes_remaining = maxf(0.0, _hurt_iframes_remaining - seconds)


func has_knockback() -> bool:
	return _knockback_remaining > 0.0


func get_knockback_time_left() -> float:
	return _knockback_remaining / _knockback_speed if has_knockback() else 0.0


func get_knockback_velocity() -> Vector2:
	return _knockback_direction * _knockback_speed if has_knockback() else Vector2.ZERO


## AC12: the distance is never recalculated, so a wall can't change when knockback ends.
func advance_knockback(seconds: float) -> void:
	if get_knockback_time_left() - seconds <= TIME_EPSILON:
		_clear_knockback()
	else:
		_knockback_remaining -= _knockback_speed * seconds


## F-004/C11: a dead enemy never moves again, whatever the killing hit started.
func stop_knockback() -> void:
	_clear_knockback()


func to_dict() -> Dictionary:
	return {
		"hp": _hp,
		"hitstop_remaining": _hitstop_remaining,
		"hurt_iframes_remaining": _hurt_iframes_remaining,
		"knockback_remaining": _knockback_remaining,
		"knockback_direction": _knockback_direction,
		"knockback_speed": _knockback_speed,
	}


func from_dict(snapshot: Dictionary) -> void:
	_hp = snapshot["hp"]
	_hitstop_remaining = snapshot["hitstop_remaining"]
	_hurt_iframes_remaining = snapshot["hurt_iframes_remaining"]
	_knockback_remaining = snapshot["knockback_remaining"]
	_knockback_direction = snapshot["knockback_direction"]
	_knockback_speed = snapshot["knockback_speed"]


## F-003/C17: replaces, never accumulates. Zero distance means no knockback at all.
func _start_knockback(event: HitEvent, tunables: PlayerCombatTunables) -> void:
	_clear_knockback()
	if event.knockback_tiles > 0.0:
		_knockback_remaining = event.knockback_tiles
		_knockback_direction = event.direction
		_knockback_speed = event.knockback_tiles / tunables.knockback_duration


func _clear_knockback() -> void:
	_knockback_remaining = 0.0
	_knockback_direction = Vector2.ZERO
	_knockback_speed = 0.0


## F-003/C7: the larger of remaining and new, never the sum.
func _extend_hitstop(event: HitEvent, tunables: PlayerCombatTunables) -> void:
	var hitstop: float = tunables.hitstop_finisher if event.is_finisher else tunables.hitstop_normal
	_hitstop_remaining = maxf(_hitstop_remaining, hitstop)
