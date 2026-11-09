class_name BruteArena
extends CasterArena
## CasterArena with brutes (F-006). `move_bodies` stands in for the glue's wall reports. Data is
## copied, so a test can change any of it first.

const STOMP: int = 0
const CHARGE: int = 1

var brute_data: EnemyData = brute_values()
## The BruteWallStub installed as move_bodies, if any.
var wall_stub: RefCounted = null


## A deep copy: the attacks are separate resources, and tests change them too.
static func brute_values() -> EnemyData:
	var data: EnemyData = (load(Tunables.BRUTE_PATH) as EnemyData).duplicate()
	var attacks: Array[EnemyAttackData] = []
	for attack: EnemyAttackData in data.attacks:
		attacks.append(attack.duplicate())
	data.attacks = attacks
	return data


func add_brute(position: Vector2, id: StringName = &"brute_1") -> EnemyLogic:
	_ensure_sim()
	var enemy: EnemyLogic = EnemyLogic.new()
	enemy.setup(brute_data, enemy_rules, rules.combat_step_rate, position, id)
	enemies.append(enemy)
	sim.register(enemy)
	return enemy
