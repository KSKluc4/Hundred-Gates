class_name ChaserBrain
extends EnemyBrain
## Melee pressure: walks straight at the target and swipes (F-004/C5, design doc). No path
## finding: walls are the body's problem, and it slides along them.


func decide(enemy: EnemyLogic, view: CombatView) -> EnemyIntent:
	var data: EnemyData = enemy.get_data()
	var own_position: Vector2 = enemy.get_position_tiles()
	var target: CombatView.Entry = EnemyBrain.nearest_player(view, own_position)
	if target == null:
		return EnemyIntent.idle()
	var distance: float = own_position.distance_to(target.position)
	var epsilon: float = Geometry.DISTANCE_EPSILON
	if not enemy.is_aggroed() and distance > data.aggro_radius_tiles + epsilon:
		return EnemyIntent.idle()
	if enemy.is_attack_ready() and distance <= data.attack_range_tiles + epsilon:
		return EnemyIntent.attack(target.combat_id)
	var gap: float = distance - data.stop_distance_tiles
	var max_distance: float = gap if gap > epsilon else 0.0
	var direction: Vector2 = own_position.direction_to(target.position)
	return EnemyIntent.move(target.combat_id, direction, max_distance)
