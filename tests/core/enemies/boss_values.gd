class_name BossValues
extends RefCounted
## F-007 fixtures: a chaser-based boss, every resource its own copy, so a test can change any
## of it. Not the Warden: its data is tested on its own (T6).


## `root` (followed by `next`) in stage 0, one stage at 50 % (shift 1.2) with `stage_swipe`.
## Swipe timing is the chaser's: windup 0.5 (tracks 0.3), active 0.1, recovery 0.6.
static func chaser_boss() -> EnemyData:
	var data: EnemyData = EnemyArena.chaser_values()
	data.id = &"boss"
	data.max_hp = 400
	data.knockback_scale = 0.0
	var root: EnemyAttackData = data.attacks[0]
	root.id = &"root"
	var next: EnemyAttackData = root.duplicate()
	next.id = &"next"
	root.follow_up = next
	var stage_swipe: EnemyAttackData = root.duplicate()
	stage_swipe.id = &"stage_swipe"
	stage_swipe.follow_up = null
	var stages: Array[EnemyStageData] = [stage(50, 1.2, stage_swipe, 3.5, 0.7)]
	data.stages = stages
	return data


## A stage with one attack.
static func stage(
	percent: int, shift: float, attack: EnemyAttackData, speed: float, cooldown: float
) -> EnemyStageData:
	var result: EnemyStageData = EnemyStageData.new()
	result.enter_at_hp_percent = percent
	result.shift_duration = shift
	var attacks: Array[EnemyAttackData] = [attack]
	result.attacks = attacks
	result.move_speed = speed
	result.attack_cooldown = cooldown
	return result


## F-004/C6's restore path, for HP only: between ticks, as if hits had landed.
static func set_hp(enemy: EnemyLogic, hp: int) -> void:
	var snapshot: Dictionary = enemy.to_dict()
	var combat: Dictionary = snapshot["combat"].duplicate()
	combat["hp"] = hp
	snapshot["combat"] = combat
	enemy.from_dict(snapshot)
