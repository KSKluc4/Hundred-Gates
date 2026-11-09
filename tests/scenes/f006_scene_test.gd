class_name F006SceneTest
extends GutTest
## Shared by F-006's physics scene tests: builds a small room in code (walls on layer 1
## `world`, a player, a brute, maybe a chaser, a CombatRunner) around the origin, where float32
## positions are exact enough (F-004 ASSUMPTION-3), and runs scripted ticks.

const PLAYER_SCENE: PackedScene = preload("res://src/entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://src/entities/enemies/enemy.tscn")
const TIME: float = 0.000001
const STEP: float = 1.0 / 120.0
## 0.01 tiles, the F-005 §5 tolerance.
const TILES: float = 0.01

var _scene: Node2D
var _player: Player
var _brute: Enemy
var _chaser: Enemy
var _runner: CombatRunner
## Sim time when the run started: see build().
var _t0: float = 0.0
var _ticks_per_second_before: int


func before_each() -> void:
	_ticks_per_second_before = Engine.physics_ticks_per_second
	_chaser = null


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks_per_second_before


## Positions and wall rectangles in tiles. A chaser is added if `chaser_at` is a Vector2, with
## its AI off so it stays where it was put. Ends right after the debug reset, so every
## combatant starts on the next tick: times are then relative to _t0.
func build(
	walls: Array[Rect2],
	player_at: Vector2,
	brute_at: Vector2,
	brute_data: EnemyData = null,
	chaser_at: Variant = null
) -> void:
	_scene = Node2D.new()
	for rect: Rect2 in walls:
		_scene.add_child(_wall(rect))
	_player = PLAYER_SCENE.instantiate()
	_player.name = "Player"
	_player.position = Units.vector_tiles_to_px(player_at)
	_player.input_enabled = false
	_scene.add_child(_player)
	_brute = _enemy("Brute", &"brute_1", brute_at, brute_data)
	var paths: Array[NodePath] = [NodePath("../Player"), NodePath("../Brute")]
	if chaser_at is Vector2:
		_chaser = _enemy("Chaser", &"chaser_1", chaser_at, EnemyArena.chaser_values())
		paths.append(NodePath("../Chaser"))
	_runner = CombatRunner.new()
	_runner.name = "CombatRunner"
	_runner.combatant_paths = paths
	_scene.add_child(_runner)
	add_child_autofree(_scene)
	await get_tree().physics_frame
	if _chaser != null:
		_chaser.logic.set_ai_enabled(false)
	_runner.reset()
	_t0 = _runner.get_sim().get_time()


## One runner tick per iteration. Presses fall on the first tick.
func run_ticks(
	ticks: int,
	attack: bool = false,
	dash: bool = false,
	move: Vector2 = Vector2.ZERO,
	aim: Vector2 = Vector2.DOWN
) -> void:
	for index: int in ticks:
		_player.motor.submit(MoveCommand.new(move))
		_player.motor.submit(AimCommand.new(aim))
		if dash and index == 0:
			_player.motor.submit(DashCommand.new())
		if attack and index == 0:
			_player.motor.submit(AttackCommand.new())
		await get_tree().physics_frame


## Ticks until the run reaches `time` seconds, at the current tick rate.
func run_to(time: float) -> void:
	while run_time() < time - TIME:
		await run_ticks(1)


func run_time() -> float:
	return _runner.get_sim().get_time() - _t0


## The run's step index, from a sim time.
func step_of(time: float) -> int:
	return roundi((time - _t0) * 120.0)


## Registered last: records the brute at every step start and contact.
func watch_brute() -> EnemyWatch:
	var watch: EnemyWatch = EnemyWatch.new(_brute.logic, _runner.get_sim())
	_runner.get_sim().register(watch)
	return watch


## Registered last: the brute right after each end_step(), by absolute step.
func probe_brute() -> StepEndProbe:
	var probe: StepEndProbe = StepEndProbe.new(_brute.logic, _runner.get_sim())
	_runner.get_sim().register(probe)
	return probe


## The first step of the run (from _t0) at which the brute was wall_stopped right after
## end_step(), or -1.
func stop_step(probe: StepEndProbe) -> int:
	var first: int = -1
	for step: int in probe.after_step:
		if probe.after_step[step]["wall_stopped"] and (first == -1 or step < first):
			first = step
	return first - roundi(_t0 * 120.0) if first != -1 else -1


## Run times at which a state was entered.
func entered(watch: EnemyWatch, state: EnemyLogic.State) -> Array[float]:
	var times: Array[float] = []
	for time: float in watch.times_entered(state):
		if time >= _t0 - TIME:
			times.append(time - _t0)
	return times


## Run times of every hit the player took.
func record_hurt() -> Array[float]:
	var times: Array[float] = []
	_player.motor.get_combat_state().damaged.connect(
		func(_event: HitEvent) -> void: times.append(run_time())
	)
	return times


func brute_tiles() -> Vector2:
	return Units.vector_px_to_tiles(_brute.global_position)


func assert_tiles(actual: Vector2, expected: Vector2, label: String = "") -> void:
	assert_almost_eq(actual.x, expected.x, TILES, label)
	assert_almost_eq(actual.y, expected.y, TILES, label)


func _wall(rect_tiles: Rect2) -> StaticBody2D:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Units.vector_tiles_to_px(rect_tiles.get_center())
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Units.vector_tiles_to_px(rect_tiles.size)
	shape.shape = rect
	wall.add_child(shape)
	return wall


func _enemy(node_name: String, id: StringName, at: Vector2, data: EnemyData) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.name = node_name
	enemy.combat_id = id
	enemy.data = data if data != null else BruteArena.brute_values()
	enemy.position = Units.vector_tiles_to_px(at)
	_scene.add_child(enemy)
	return enemy
