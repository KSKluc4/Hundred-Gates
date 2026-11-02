class_name EnemyIntent
extends RefCounted
## What a brain decided at one step start (F-004 §3). Holds for that whole step (C4). AI goes
## through this, not through commands: it runs where the logic runs (F-004 §10 Q2).

## Empty means no target: the enemy idles. Any target means it's aggroed.
var target_id: StringName = &""
var move_direction: Vector2 = Vector2.ZERO
## F-004/C5: the most this step may move, on top of what move_speed allows.
var max_move_distance: float = 0.0
var start_attack: bool = false


static func idle() -> EnemyIntent:
	return EnemyIntent.new()


static func move(target: StringName, direction: Vector2, max_distance: float) -> EnemyIntent:
	var intent: EnemyIntent = EnemyIntent.new()
	intent.target_id = target
	intent.move_direction = direction
	intent.max_move_distance = max_distance
	return intent


static func attack(target: StringName) -> EnemyIntent:
	var intent: EnemyIntent = EnemyIntent.new()
	intent.target_id = target
	intent.start_attack = true
	return intent


func has_target() -> bool:
	return target_id != &""
