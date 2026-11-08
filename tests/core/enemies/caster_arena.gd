class_name CasterArena
extends EnemyArena
## EnemyArena with casters, and a move_bodies callable standing in for the glue's wall reports
## (F-005/C5). Data is copied, so a test can change any of it first.

var caster_data: EnemyData = caster_values()
## F-005/C5: called once per step after logic advanced, like the scene's glue. Empty: no walls.
var move_bodies: Callable = Callable()
## Every hit a caster landed, in sim time.
var caster_landed_times: Array[float] = []


## A deep copy: the attack is a separate resource, and tests change it too.
static func caster_values() -> EnemyData:
	var data: EnemyData = (load(Tunables.CASTER_PATH) as EnemyData).duplicate()
	data.attack = data.attack.duplicate()
	return data


func add_caster(position: Vector2, id: StringName = &"caster_1") -> EnemyLogic:
	_ensure_sim()
	var enemy: EnemyLogic = EnemyLogic.new()
	enemy.setup(caster_data, enemy_rules, rules.combat_step_rate, position, id)
	enemy.get_combat_state().hit_landed.connect(_on_caster_landed)
	enemies.append(enemy)
	sim.register(enemy)
	return enemy


## Last, so the enemy has already acted on what it sees.
func watch_caster(enemy: EnemyLogic) -> CasterWatch:
	var caster_watch: CasterWatch = CasterWatch.new(enemy, sim)
	sim.register(caster_watch)
	return caster_watch


## F-004/C6's restore path: changes one snapshot value of a set-up enemy, before any tick.
func restore_value(enemy: EnemyLogic, key: String, value: Variant) -> void:
	var snapshot: Dictionary = enemy.to_dict()
	snapshot[key] = value
	enemy.from_dict(snapshot)


func tick(
	rate: int = 120,
	move: Vector2 = Vector2.ZERO,
	dash: bool = false,
	attack: bool = false,
	aim: Vector2 = Vector2.DOWN
) -> void:
	if not players.is_empty():
		var motor: PlayerMotor = players[0]
		motor.submit(MoveCommand.new(move))
		motor.submit(AimCommand.new(aim))
		if dash:
			motor.submit(DashCommand.new())
		if attack:
			motor.submit(AttackCommand.new())
	sim.tick(1.0 / rate, move_bodies)


func _on_caster_landed(_event: HitEvent) -> void:
	caster_landed_times.append(sim.get_time())
