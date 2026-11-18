class_name BruteBrain
extends EnemyBrain
## Heavy space control (F-006/C5, design doc): stomps when you hug it, charges from mid range,
## walks in between. Never retreats. Walls are the body's problem, unless a NavGrid says the line
## is blocked (F-011/C3).


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
		var attacks: Array[EnemyAttackData] = enemy.get_current_attacks()  # F-007/C4.
		var attack_index: int = EnemyBrain.pick_attack_in(attacks, distance)
		if attack_index >= 0:
			return EnemyIntent.attack(target.combat_id, attack_index)
	var direction: Vector2 = EnemyBrain.steer(view, enemy, target.position)  # F-011/C3.
	if direction != Vector2.ZERO and distance > data.stop_distance_tiles + epsilon:
		return EnemyIntent.move(target.combat_id, direction, distance - data.stop_distance_tiles)
	return EnemyIntent.move(target.combat_id, Vector2.ZERO, 0.0)  # Holds, keeping its target.
