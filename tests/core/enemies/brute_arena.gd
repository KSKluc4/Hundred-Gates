class_name BruteArena
extends CasterArena
## CasterArena with brutes (F-006). `move_bodies` stands in for the glue's wall reports. Data is
## copied, so a test can change any of it first.

const STOMP: int = 0
const CHARGE: int = 1

var brute_data: EnemyData = brute_values()


## A deep copy: the attacks are separate resources, and tests change them too.
static func brute_values() -> EnemyData:
	var data: EnemyData = EnemyData.new()
	data.id = &"brute"
	data.brain = EnemyData.Brain.BRUTE
	data.max_hp = 120
	data.hurtbox_radius_tiles = 0.6
	data.knockback_scale = 0.0
	data.move_speed = 2.0
	data.aggro_radius_tiles = 7.0
	data.stop_distance_tiles = 1.5
	data.retreat_distance_tiles = 0.0
	data.attack_cooldown = 1.0
	var stomp: EnemyAttackData = EnemyAttackData.new()
	stomp.id = &"brute_stomp"
	stomp.windup = 0.6
	stomp.active = 0.1
	stomp.recovery = 0.7
	stomp.damage = 20
	stomp.arc_angle_deg = 360.0
	stomp.range_tiles = 1.6
	stomp.knockback_tiles = 1.2
	stomp.trigger_max_tiles = 1.5
	var charge: EnemyAttackData = EnemyAttackData.new()
	charge.id = &"brute_charge"
	charge.windup = 0.8
	charge.aim_track_time = 0.5
	charge.active = 0.5
	charge.recovery = 0.9
	charge.damage = 25
	charge.arc_angle_deg = 120.0
	charge.range_tiles = 0.9
	charge.knockback_tiles = 1.5
	charge.lunge_tiles = 6.0
	charge.trigger_min_tiles = 3.0
	charge.trigger_max_tiles = 7.0
	data.attacks = [stomp, charge]
	return data


func add_brute(position: Vector2, id: StringName = &"brute_1") -> EnemyLogic:
	_ensure_sim()
	var enemy: EnemyLogic = EnemyLogic.new()
	enemy.setup(brute_data, enemy_rules, rules.combat_step_rate, position, id)
	enemies.append(enemy)
	sim.register(enemy)
	return enemy
