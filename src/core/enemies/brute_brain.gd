class_name BruteBrain
extends EnemyBrain
## Heavy space control (F-006/C5, design doc): stomps when you hug it, charges from mid range,
## walks in between. Never retreats. No path finding: walls are the body's problem.


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
	if enemy.is_attack_ready():
		var attack_index: int = EnemyBrain.pick_attack(data, distance)
		if attack_index >= 0:
			return EnemyIntent.attack(target.combat_id, attack_index)
	var direction: Vector2 = own_position.direction_to(target.position)
	if direction != Vector2.ZERO and distance > data.stop_distance_tiles + epsilon:
		return EnemyIntent.move(target.combat_id, direction, distance - data.stop_distance_tiles)
	return EnemyIntent.move(target.combat_id, Vector2.ZERO, 0.0)  # Holds, keeping its target.
