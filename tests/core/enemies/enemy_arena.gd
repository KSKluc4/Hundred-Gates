class_name EnemyArena
extends RefCounted
## Players and enemies on a real CombatSim, with no scene (F-004 §5). Registration order is
## the order of the add_ calls. Data is copied, so a test can change any of it first.

const RATES: Array[int] = [30, 60, 120]
const TIME: float = 0.000001
const TILES: float = 0.01
const STEP: float = 1.0 / 120.0

var sim: CombatSim = CombatSim.new()
var rules: PlayerCombatTunables = Tunables.player_combat.duplicate()
var enemy_rules: EnemyCombatTunables = Tunables.enemy_combat.duplicate()
var class_data: ClassData = CombatArena.warrior()
var chaser_data: EnemyData = chaser_values()
var players: Array[PlayerMotor] = []
var enemies: Array[EnemyLogic] = []
## Every hit a player took, in sim time.
var hurt_times: Array[float] = []
var hurt_events: Array[HitEvent] = []
## Every hit a player's sword landed, in sim time.
var sword_times: Array[float] = []


## A deep copy: the attack is a separate resource, and tests change it too.
static func chaser_values() -> EnemyData:
	var data: EnemyData = (load(Tunables.CHASER_PATH) as EnemyData).duplicate()
	data.attack = data.attack.duplicate()
	return data


func add_player(position: Vector2 = Vector2.ZERO, id: StringName = &"player_1") -> PlayerMotor:
	_ensure_sim()
	var motor: PlayerMotor = PlayerMotor.new()
	motor.setup(class_data, rules, position, Vector2.DOWN, id)
	motor.get_combat_state().damaged.connect(_on_player_damaged)
	motor.get_combat_state().hit_landed.connect(_on_sword_landed)
	players.append(motor)
	sim.register(motor)
	return motor


func add_chaser(position: Vector2, id: StringName = &"chaser_1") -> EnemyLogic:
	_ensure_sim()
	var enemy: EnemyLogic = EnemyLogic.new()
	enemy.setup(chaser_data, enemy_rules, rules.combat_step_rate, position, id)
	enemies.append(enemy)
	sim.register(enemy)
	return enemy


## Last, so the enemy has already acted on what it sees.
func watch(enemy: EnemyLogic) -> EnemyWatch:
	var enemy_watch: EnemyWatch = EnemyWatch.new(enemy, sim)
	sim.register(enemy_watch)
	return enemy_watch


## From one thirtieth to another at `rate` ticks/s. Commands go to the first player, and
## presses fall on their thirtieth (the §5 oracle). `moves` holds a direction per thirtieth.
func play(
	rate: int,
	from_30ths: int,
	to_30ths: int,
	moves: Dictionary = {},
	dashes: Array = [],
	attacks: Array = [],
	aim: Vector2 = Vector2.DOWN
) -> void:
	var ticks_per_30th: int = rate / 30
	for tick_index: int in range(from_30ths * ticks_per_30th, to_30ths * ticks_per_30th):
		var thirtieth: int = tick_index / ticks_per_30th
		var on_30th: bool = tick_index % ticks_per_30th == 0
		tick(
			rate,
			moves.get(thirtieth, Vector2.ZERO),
			on_30th and dashes.has(thirtieth),
			on_30th and attacks.has(thirtieth),
			aim
		)


## One tick, with its commands. `ticks` holds a run of them with no presses.
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
	sim.tick(1.0 / rate)


func ticks(count: int, rate: int = 120) -> void:
	for _i: int in count:
		tick(rate)


func _ensure_sim() -> void:
	if sim.get_step_rate() == 0:
		sim.setup(rules.combat_step_rate, rules)


func _on_player_damaged(event: HitEvent) -> void:
	hurt_times.append(sim.get_time())
	hurt_events.append(event)


func _on_sword_landed(_event: HitEvent) -> void:
	sword_times.append(sim.get_time())
