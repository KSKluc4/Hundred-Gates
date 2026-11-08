class_name Hitbox
extends RefCounted
## A sector that deals damage, as it is at one contact instant (F-003 §3). Tiles.
## Built fresh each contact. Its hit set is the attacker's own, shared by reference.

var owner_id: StringName
var team: Combatant.Team
var origin: Vector2
var direction: Vector2
var arc_angle_deg: float
var range_tiles: float
var damage: int
var knockback_tiles: float
var is_finisher: bool = false
## AC12: false pushes along `direction` instead of from the attacker to the target's center.
var knockback_from_center: bool = true
## F-005/C6: once it lands on one hurtbox, it lands on no other at that contact.
var single_target: bool = false
## F-005/C6: false lands with no hitstop for the attacker. Its hit_landed still fires.
var attacker_hitstop: bool = true
var hit_ids: Array[StringName] = []


## F-003/C8: only a hit that lands marks the hurtbox.
func mark_hit(target_id: StringName) -> void:
	hit_ids.append(target_id)


func has_hit(target_id: StringName) -> bool:
	return hit_ids.has(target_id)
