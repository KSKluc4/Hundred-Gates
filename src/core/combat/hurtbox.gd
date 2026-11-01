class_name Hurtbox
extends RefCounted
## A circle that can receive hits, as it is at one contact instant (F-003 §3). Tiles.

var owner_id: StringName
var team: Combatant.Team
var position: Vector2
var radius_tiles: float


func _init(id: StringName, owner_team: Combatant.Team, center: Vector2, radius: float) -> void:
	owner_id = id
	team = owner_team
	position = center
	radius_tiles = radius
