class_name F008SceneTest
extends GutTest
## Shared by F-008's scene tests. build() makes a scene in code around the origin: a player,
## then one enemy, then a CombatRunner, in that registration order. No walls.

const PLAYER_SCENE: PackedScene = preload("res://src/entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://src/entities/enemies/enemy.tscn")
const TIME: float = 0.000001
const FAN: Array = [-20.0, 0.0, 20.0]

var _scene: Node2D
var _player: Player
var _enemy: Enemy
var _runner: CombatRunner
var _t0: float = 0.0
var _ticks_per_second_before: int
var _player_rules_before: PlayerCombatTunables
var _enemy_rules_before: EnemyCombatTunables


func before_each() -> void:
	_ticks_per_second_before = Engine.physics_ticks_per_second
	_player_rules_before = Tunables.player_combat
	_enemy_rules_before = Tunables.enemy_combat
	Engine.physics_ticks_per_second = 120


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks_per_second_before
	Tunables.player_combat = _player_rules_before
	Tunables.enemy_combat = _enemy_rules_before


## The caster's data with its bolt turned into a volley of `angles`, a deep copy.
static func volley_caster(angles: Array) -> EnemyData:
	var data: EnemyData = CasterArena.caster_values()
	data.attacks[0].volley_angles_deg = PackedFloat64Array(angles)
	return data


## Player at `player_at`, the enemy at `enemy_at` (tiles), runner. Ends right after the debug
## reset.
func build(data: EnemyData, enemy_at: Vector2, player_at: Vector2 = Vector2.ZERO) -> void:
	_scene = Node2D.new()
	_player = PLAYER_SCENE.instantiate()
	_player.name = "Player"
	_player.position = Units.vector_tiles_to_px(player_at)
	_player.input_enabled = false
	_scene.add_child(_player)
	_enemy = ENEMY_SCENE.instantiate()
	_enemy.name = "Enemy"
	_enemy.combat_id = &"enemy_1"
	_enemy.data = data
	_enemy.position = Units.vector_tiles_to_px(enemy_at)
	_scene.add_child(_enemy)
	_runner = CombatRunner.new()
	_runner.name = "CombatRunner"
	_runner.combatant_paths = [NodePath("../Player"), NodePath("../Enemy")]
	_scene.add_child(_runner)
	add_child_autofree(_scene)
	await get_tree().physics_frame
	_runner.reset()
	_t0 = _runner.get_sim().get_time()


## One runner tick per iteration, with no player input.
func run_ticks(ticks: int) -> void:
	for _i: int in ticks:
		_player.motor.submit(MoveCommand.new(Vector2.ZERO))
		_player.motor.submit(AimCommand.new(Vector2.DOWN))
		await get_tree().physics_frame


## Runs until `condition` holds, at most `limit` ticks. Returns whether it held.
func run_until(condition: Callable, limit: int = 600) -> bool:
	for _i: int in limit:
		if condition.call():
			return true
		await run_ticks(1)
	return condition.call()


func enemy_state() -> EnemyLogic.State:
	return _enemy.logic.get_state()


## C11: one line per bolt in list order, each from `enemy` along that bolt's direction and
## max distance long, and get_aim_line() is the first.
func assert_volley_lines(enemy: Enemy, label: String = "") -> void:
	var attack: EnemyAttackData = enemy.logic.get_running_attack()
	var directions: Array[Vector2] = attack.volley_directions(enemy.logic.get_aim())
	var lines: Array[PackedVector2Array] = enemy.get_aim_lines()
	assert_eq(lines.size(), directions.size(), "%s: one line per bolt" % label)
	var length_px: float = Units.tiles_to_px(attack.projectile_max_distance_tiles)
	for index: int in mini(lines.size(), directions.size()):
		var line: PackedVector2Array = lines[index]
		assert_eq(line.size(), 2)
		assert_eq(line[0], enemy.logic.get_position_px(), "%s: from the enemy" % label)
		var expected: Vector2 = line[0] + directions[index] * length_px
		assert_almost_eq(line[1], expected, Vector2.ONE * 0.001, "%s: line %d" % [label, index])
	if not lines.is_empty():
		assert_eq(enemy.get_aim_line(), lines[0], "%s: get_aim_line() is the first" % label)
