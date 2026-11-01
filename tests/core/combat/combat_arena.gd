class_name CombatArena
extends RefCounted
## A player and up to two dummies on a real CombatSim, with no scene. Records hits and dash
## fires in sim time. Commands change only at multiples of 1/30 s (the §5 oracle).

const MotorHarness: GDScript = preload("res://tests/core/player/motor_harness.gd")

var sim: CombatSim = CombatSim.new()
var player: PlayerMotor = PlayerMotor.new()
var dummy: DummyLogic = DummyLogic.new()
var other: DummyLogic = DummyLogic.new()
var rules: PlayerCombatTunables
var class_data: ClassData
var dummy_data: DummyData
var dummy_scale: float = 0.0
var hit_times: Array[float] = []
var hurt_times: Array[float] = []
var dash_times: Array[float] = []
var events: Array[HitEvent] = []


static func warrior() -> ClassData:
	var data: ClassData = (load(Tunables.WARRIOR_PATH) as ClassData).duplicate()
	var chain: Array[AttackData] = []
	for attack: AttackData in data.attack_chain:
		chain.append(attack.duplicate())
	data.attack_chain = chain
	return data


static func dummy_values() -> DummyData:
	return (load(Tunables.TRAINING_DUMMY_PATH) as DummyData).duplicate()


## player_first: the registration order. C16's trades must not depend on it.
func build(
	dummy_position: Vector2 = Vector2(0, 1),
	other_position: Variant = null,
	player_first: bool = true
) -> CombatArena:
	rules = rules if rules != null else MotorHarness.rules()
	class_data = class_data if class_data != null else warrior()
	dummy_data = dummy_data if dummy_data != null else dummy_values()
	var rate: int = rules.combat_step_rate
	player.setup(class_data, rules, Vector2.ZERO)
	dummy.setup(dummy_data, rate, dummy_position, dummy_scale, &"dummy_anchored")
	sim.setup(rate, rules)
	if player_first:
		sim.register(player)
	sim.register(dummy)
	if other_position != null:
		other.setup(dummy_data, rate, other_position, dummy_scale, &"dummy_loose")
		sim.register(other)
	if not player_first:
		sim.register(player)
	listen()
	return self


func listen() -> void:
	player.get_combat_state().hit_landed.connect(_on_hit_landed)
	player.get_combat_state().damaged.connect(_on_player_damaged)
	player.dash_started.connect(_on_dash_started)


## Runs from one thirtieth to another at `rate` ticks/s. Presses fire on their thirtieth.
func play(
	rate: int,
	from_30ths: int,
	to_30ths: int,
	attacks: Array = [],
	dashes: Array = [],
	moves: Dictionary = {},
	aim: Vector2 = Vector2.DOWN
) -> void:
	var ticks_per_30th: int = rate / 30
	var delta: float = 1.0 / rate
	for tick_index: int in range(from_30ths * ticks_per_30th, to_30ths * ticks_per_30th):
		var thirtieth: int = tick_index / ticks_per_30th
		var on_30th: bool = tick_index % ticks_per_30th == 0
		player.submit(MoveCommand.new(moves.get(thirtieth, Vector2.ZERO)))
		player.submit(AimCommand.new(aim))
		if on_30th and dashes.has(thirtieth):
			player.submit(DashCommand.new())
		if on_30th and attacks.has(thirtieth):
			player.submit(AttackCommand.new())
		sim.tick(delta)


func _on_hit_landed(event: HitEvent) -> void:
	hit_times.append(sim.get_time())
	events.append(event)


func _on_player_damaged(_event: HitEvent) -> void:
	hurt_times.append(sim.get_time())


func _on_dash_started() -> void:
	dash_times.append(sim.get_time())
