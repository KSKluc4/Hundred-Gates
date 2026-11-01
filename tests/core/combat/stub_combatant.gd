class_name StubCombatant
extends Combatant
## A combatant with fixed shapes, for tests of the resolver and the sim.

var hurtbox_radius: float = 0.5
var live_hitbox: Hitbox = null


static func make(id: StringName, team: Team, position: Vector2) -> StubCombatant:
	var stub: StubCombatant = StubCombatant.new()
	stub._combat_id = id
	stub._team = team
	stub._position = position
	return stub


## A sword-like hitbox owned by this stub, pointing `direction`.
func arm(direction: Vector2 = Vector2.DOWN, range_tiles: float = 1.4) -> Hitbox:
	live_hitbox = Hitbox.new()
	live_hitbox.owner_id = _combat_id
	live_hitbox.team = _team
	live_hitbox.origin = _position
	live_hitbox.direction = direction
	live_hitbox.arc_angle_deg = 100.0
	live_hitbox.range_tiles = range_tiles
	live_hitbox.damage = 10
	return live_hitbox


func _hurtbox_radius() -> float:
	return hurtbox_radius


func _build_live_hitbox() -> Hitbox:
	return live_hitbox
