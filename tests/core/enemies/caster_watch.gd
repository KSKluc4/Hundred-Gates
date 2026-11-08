class_name CasterWatch
extends EnemyWatch
## An EnemyWatch that also records the caster's projectiles at every contact instant.

## Projectile serials ever seen at a contact, by serial: the step indexes they were seen at.
var seen_at: Dictionary = {}


func _contact_sample() -> Dictionary:
	var sample: Dictionary = super()
	var projectiles: Array[Dictionary] = []
	var step_index: int = roundi(_sim().get_time() * STEPS_PER_SECOND)
	for projectile: ProjectileSet.Projectile in enemy.get_projectiles().get_projectiles():
		(
			projectiles
			. append(
				{
					"serial": projectile.serial,
					"position": projectile.position,
					"direction": projectile.direction,
					"spent": projectile.spent,
				}
			)
		)
		if not seen_at.has(projectile.serial):
			seen_at[projectile.serial] = []
		seen_at[projectile.serial].append(step_index)
	sample["projectiles"] = projectiles
	sample["hitboxes"] = enemy.get_live_hitboxes().size()
	sample["own_hitbox"] = enemy.get_live_hitbox() != null
	sample["hitstop"] = enemy.get_combat_state().get_hitstop_remaining()
	return sample


## Null if that projectile wasn't there at that contact.
func projectile_at(step_index: int, serial: int = 0) -> Variant:
	for entry: Dictionary in at(step_index)["projectiles"]:
		if entry["serial"] == serial:
			return entry
	return null
