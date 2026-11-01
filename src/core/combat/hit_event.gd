class_name HitEvent
extends RefCounted
## A hit that landed (AC11). Exists only after F-003/C16's recheck.

var attacker_id: StringName
var target_id: StringName
var damage: int
var is_finisher: bool
## AC12: also the knockback direction.
var direction: Vector2
## Distance after the target's knockback_scale.
var knockback_tiles: float


static func from_candidate(candidate: HitCandidate, knockback_scale: float) -> HitEvent:
	var hitbox: Hitbox = candidate.hitbox
	var event: HitEvent = HitEvent.new()
	event.attacker_id = hitbox.owner_id
	event.target_id = candidate.hurtbox.owner_id
	event.damage = hitbox.damage
	event.is_finisher = hitbox.is_finisher
	event.direction = _direction_of(hitbox, candidate.hurtbox)
	event.knockback_tiles = hitbox.knockback_tiles * knockback_scale
	return event


static func _direction_of(hitbox: Hitbox, hurtbox: Hurtbox) -> Vector2:
	var to_target: Vector2 = hurtbox.position - hitbox.origin
	if hitbox.knockback_from_center and to_target != Vector2.ZERO:
		return to_target.normalized()
	return hitbox.direction
