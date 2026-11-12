class_name CasterBrain
extends EnemyBrain
## Ranged area denial: keeps 3–6 tiles from the target and shoots (F-005/C7, design doc). No
## memory, so no hysteresis band (§3). Walks straight toward or away: no path finding.


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
	# C7: shooting beats retreating, at any distance, so a cornered caster still shoots.
	if enemy.is_attack_ready():
		var attacks: Array[EnemyAttackData] = enemy.get_current_attacks()  # F-007/C4.
		var attack_index: int = EnemyBrain.pick_attack_in(attacks, distance)
		if attack_index >= 0:
			return EnemyIntent.attack(target.combat_id, attack_index)
	var direction: Vector2 = own_position.direction_to(target.position)
	return _keep_distance(data, target.combat_id, direction, distance)


## C7 steps 4-6: back off below the retreat distance, walk in above the stop distance, hold in
## between. Never past the band's edge in one step. A zero direction holds.
func _keep_distance(
	data: EnemyData, target_id: StringName, direction: Vector2, distance: float
) -> EnemyIntent:
	var epsilon: float = Geometry.DISTANCE_EPSILON
	if direction == Vector2.ZERO:
		return EnemyIntent.move(target_id, Vector2.ZERO, 0.0)
	if distance < data.retreat_distance_tiles - epsilon:
		return EnemyIntent.move(target_id, -direction, data.retreat_distance_tiles - distance)
	if distance > data.stop_distance_tiles + epsilon:
		return EnemyIntent.move(target_id, direction, distance - data.stop_distance_tiles)
	return EnemyIntent.move(target_id, direction, 0.0)
