class_name EnemyBrain
extends RefCounted
## The only per-archetype code (F-004 §3). Holds no state: it reads a CombatView and its own
## enemy, and answers with an EnemyIntent. Everything every enemy shares lives in EnemyLogic.


## Null for a value this build doesn't know. EnemyData.validate() rejects that first.
static func for_data(data: EnemyData) -> EnemyBrain:
	match data.brain:
		EnemyData.Brain.CHASER:
			return ChaserBrain.new()
	return null


## F-004/C9: the nearest living player, ties to the one registered first. Null if there's none.
static func nearest_player(view: CombatView, from: Vector2) -> CombatView.Entry:
	var nearest: CombatView.Entry = null
	var nearest_distance: float = INF
	for entry: CombatView.Entry in view.get_entries():
		if entry.team != Combatant.Team.PLAYER or not entry.is_alive:
			continue
		var distance: float = from.distance_to(entry.position)
		if distance < nearest_distance - Geometry.DISTANCE_EPSILON:  # F-004/C5, C9.
			nearest = entry
			nearest_distance = distance
	return nearest


## F-004/C4: asked once, at a step start where the enemy is free.
func decide(_enemy: EnemyLogic, _view: CombatView) -> EnemyIntent:
	return EnemyIntent.idle()
