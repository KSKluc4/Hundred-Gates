class_name HitResolver
extends RefCounted
## Finds which hitboxes touch which hurtboxes at a contact instant (F-003/C15). Decides no
## hit and marks nothing: CombatSim does that per C16. Holds no state, so a fresh scene
## rebuilds it just by registering the same combatants (C19).


## F-003/C16: ordered by the hitbox owner's registration order, then each owner's own hitbox
## order (F-005/C6), then the hurtbox owner's registration order.
func find_candidates(combatants: Array[Combatant]) -> Array[HitCandidate]:
	var candidates: Array[HitCandidate] = []
	for attacker: Combatant in combatants:
		for hitbox: Hitbox in attacker.get_live_hitboxes():
			for target: Combatant in combatants:
				var hurtbox: Hurtbox = target.get_hurtbox()
				if _touches(hitbox, hurtbox):
					candidates.append(HitCandidate.new(attacker, target, hitbox, hurtbox))
	return candidates


func _touches(hitbox: Hitbox, hurtbox: Hurtbox) -> bool:
	if hitbox.team == hurtbox.team or hitbox.has_hit(hurtbox.owner_id):
		return false
	return Geometry.circle_hits_sector(
		hurtbox.position,
		hurtbox.radius_tiles,
		hitbox.origin,
		hitbox.direction,
		hitbox.arc_angle_deg,
		hitbox.range_tiles
	)
