class_name HitCandidate
extends RefCounted
## A hitbox touching a hurtbox at a contact instant. Not a hit yet: F-003/C16 rechecks the
## target before it lands.

var attacker: Combatant
var target: Combatant
var hitbox: Hitbox
var hurtbox: Hurtbox


func _init(hit_attacker: Combatant, hit_target: Combatant, sector: Hitbox, circle: Hurtbox) -> void:
	attacker = hit_attacker
	target = hit_target
	hitbox = sector
	hurtbox = circle
