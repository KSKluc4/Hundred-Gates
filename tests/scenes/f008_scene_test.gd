class_name F008SceneTest
extends GutTest
## Shared by F-008's scene tests. build() makes a scene in code around the origin: a player,
## then one enemy, then a CombatRunner, in that registration order. No walls.
## spawn_debug_scene() runs the real f008_hexer.tscn.

const DEBUG_SCENE_PATH: String = "res://scenes/debug/f008_hexer.tscn"
const PLAYER_SCENE: PackedScene = preload("res://src/entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://src/entities/enemies/enemy.tscn")
const TIME: float = 0.000001
const FAN: Array = [-20.0, 0.0, 20.0]

var _scene: Node2D
var _player: Player
var _enemy: Enemy
var _runner: CombatRunner
var _bar: BossBar
var _overlay_label: Label
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


## The real debug scene: the Warrior and the Hexer. `prepare` runs before it enters the tree
## (move nodes, swap data). Ends right after the debug reset, like build().
func spawn_debug_scene(prepare: Callable = Callable()) -> void:
	_scene = (load(DEBUG_SCENE_PATH) as PackedScene).instantiate()
	_player = _scene.get_node("Player")
	_enemy = _scene.get_node("Hexer")
	_runner = _scene.get_node("CombatRunner")
	_bar = _scene.get_node("BossBarLayer/BossBar")
	_overlay_label = _scene.get_node("MotorDebugOverlay/Label")
	_player.input_enabled = false
	if prepare.is_valid():
		prepare.call()
	add_child_autofree(_scene)
	await get_tree().physics_frame
	_runner.reset()
	_t0 = _runner.get_sim().get_time()


## Before the scene enters the tree: the player and the enemy at these tiles of the room.
func place(player_tiles: Vector2, enemy_tiles: Vector2) -> void:
	_player.position = Units.vector_tiles_to_px(player_tiles)
	_enemy.position = Units.vector_tiles_to_px(enemy_tiles)


## Registered last, so it records the enemy and its bolts at every contact.
func watch_enemy() -> CasterWatch:
	var watch: CasterWatch = CasterWatch.new(_enemy.logic, _runner.get_sim())
	_runner.get_sim().register(watch)
	return watch


func press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


## The overlay writes its text on the next process frame.
func overlay_text() -> String:
	await wait_process_frames(1)
	var text: String = _overlay_label.text
	await get_tree().physics_frame
	return text


## Every view is derived from logic: the bolts drawn are exactly logic's, and so are the lines.
func assert_views_match_logic(label: String) -> void:
	var bolts: Array[ProjectileSet.Projectile] = _enemy.logic.get_projectiles().get_projectiles()
	var drawn: PackedVector3Array = _enemy.get_bolts_px()
	assert_eq(drawn.size(), bolts.size(), "%s: bolts drawn" % label)
	for index: int in mini(drawn.size(), bolts.size()):
		var centre: Vector2 = Units.vector_tiles_to_px(bolts[index].position)
		assert_eq(Vector2(drawn[index].x, drawn[index].y), centre, "%s: bolt %d" % [label, index])
	if (
		enemy_state() == EnemyLogic.State.WINDUP
		and _enemy.logic.get_running_attack().is_projectile()
	):
		assert_volley_lines(_enemy, label)
	else:
		assert_eq(_enemy.get_aim_lines().size(), 0, "%s: no line" % label)


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
