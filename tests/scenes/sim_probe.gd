class_name SimProbe
extends Combatant
## Registered on a scene's sim, this watches it from inside. The resolver asks every
## combatant for its hitbox at each contact instant, so `on_contact` runs exactly there.

var steps: int = 0
var on_contact: Callable = Callable()


func _init(id: StringName = &"probe") -> void:
	_combat_id = id
	_team = Team.PLAYER


func step(_duration: float) -> void:
	steps += 1


func get_live_hitbox() -> Hitbox:
	if on_contact.is_valid():
		on_contact.call()
	return null


func _hurtbox_radius() -> float:
	return 0.001
