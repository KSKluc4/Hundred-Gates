class_name EnemyBrain
extends RefCounted
## The only per-archetype code (F-004 §3). Holds no state: it reads a CombatView and its own
## enemy, and answers with an EnemyIntent. Everything every enemy shares lives in EnemyLogic.


## Null for a value this build doesn't know. EnemyData.validate() rejects that first.
static func for_data(data: EnemyData) -> EnemyBrain:
	match data.brain:
		EnemyData.Brain.CHASER:
			return ChaserBrain.new()
		EnemyData.Brain.CASTER:
			return CasterBrain.new()
		EnemyData.Brain.BRUTE:
			return BruteBrain.new()
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


## F-006/C4: the index of the first attack in list order whose trigger band holds `distance`,
## or -1 if none does. Never random: the player reads the next attack from position (§3).
static func pick_attack(data: EnemyData, distance: float) -> int:
	return pick_attack_in(data.attacks, distance)


## F-007/C4: the same rule on any list, so a brain can pass the current stage's attacks.
static func pick_attack_in(attacks: Array[EnemyAttackData], distance: float) -> int:
	var epsilon: float = Geometry.DISTANCE_EPSILON
	for index: int in attacks.size():
		var attack: EnemyAttackData = attacks[index]
		if (
			distance >= attack.trigger_min_tiles - epsilon
			and distance <= attack.trigger_max_tiles + epsilon
		):
			return index
	return -1


## F-011/C3 (D-012): where to walk to reach `target_position`. The straight direction when there
## is no NavGrid or the line is clear for this enemy's own body; the grid's path direction when a
## wall is in the way. No path (ZERO) falls back to straight (AC9). Never read by attack choice.
static func steer(view: CombatView, enemy: EnemyLogic, target_position: Vector2) -> Vector2:
	var own_position: Vector2 = enemy.get_position_tiles()
	var straight: Vector2 = own_position.direction_to(target_position)
	if view.nav == null:
		return straight
	if view.nav.has_clear_line(
		own_position, target_position, enemy.get_data().hurtbox_radius_tiles
	):
		return straight
	var routed: Vector2 = view.nav.direction_toward(own_position, target_position)
	return routed if routed != Vector2.ZERO else straight


## F-004/C4: asked once, at a step start where the enemy is free.
func decide(_enemy: EnemyLogic, _view: CombatView) -> EnemyIntent:
	return EnemyIntent.idle()
