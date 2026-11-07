class_name F004SceneTest
extends GutTest
## Shared by F-004's scene tests: spawns the real chaser scene and runs scripted ticks.

const SCENE: PackedScene = preload("res://scenes/debug/f004_chaser.tscn")
const TIME: float = 0.000001
const TILE_PX: float = 0.16  # 0.01 tiles, the §5 tolerance.
## Room centre, and two corners far beyond any aggro radius from it.
const CENTRE: Vector2 = Vector2(240, 160)
const FAR_WEST: Vector2 = Vector2(24, 24)
const FAR_EAST: Vector2 = Vector2(456, 24)

var _scene: Node
var _player: Player
var _chasers: Array[Enemy] = []
var _runner: CombatRunner
var _overlay_label: Label
var _debug_draw: CombatDebugDraw
## Where the room's (0, 0) went: see place_oracle_at_origin().
var _origin: Vector2 = Vector2.ZERO
## Sim time when the run started: see spawn_fresh().
var _t0: float = 0.0
var _ticks_per_second_before: int
var _tunables_before: PlayerCombatTunables
var _enemy_rules_before: EnemyCombatTunables


func before_each() -> void:
	_ticks_per_second_before = Engine.physics_ticks_per_second
	_tunables_before = Tunables.player_combat
	_enemy_rules_before = Tunables.enemy_combat


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks_per_second_before
	Tunables.player_combat = _tunables_before
	Tunables.enemy_combat = _enemy_rules_before


## prepare runs before the scene enters the tree: move nodes, swap data.
func spawn(prepare: Callable = Callable()) -> void:
	_scene = SCENE.instantiate()
	_player = _scene.get_node("Player")
	_chasers = [_scene.get_node("Chaser1"), _scene.get_node("Chaser2"), _scene.get_node("Chaser3")]
	_runner = _scene.get_node("CombatRunner")
	_overlay_label = _scene.get_node("MotorDebugOverlay/Label")
	_debug_draw = _scene.get_node("CombatDebugDraw")
	_player.input_enabled = false
	if prepare.is_valid():
		prepare.call()
	add_child_autofree(_scene)
	await get_tree().physics_frame  # run_ticks must start just before a runner tick.


## spawn(), then the debug reset, so every combatant starts on the next tick whatever the
## engine did while the scene entered the tree. Times are then relative to _t0.
func spawn_fresh(prepare: Callable = Callable()) -> void:
	await spawn(prepare)
	_runner.reset()
	_t0 = _runner.get_sim().get_time()


## Sim time since spawn_fresh().
func run_time() -> float:
	return _runner.get_sim().get_time() - _t0


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


## The §5 oracle's single chaser: player at the centre, chaser_1 3 tiles below, the other two
## parked in the corners where they never notice anyone.
func place_oracle() -> void:
	_player.position = CENTRE
	_chasers[0].position = CENTRE + Units.vector_tiles_to_px(Vector2(0, 3))
	_chasers[1].position = FAR_WEST
	_chasers[2].position = FAR_EAST


## The oracle at its own coordinates: the room moved so the player starts at (0, 0).
## F-004 ASSUMPTION-3: positions are float32, so an exact distance boundary reached by
## accumulated steps only falls where §5 says near the origin. A node keeps its local
## position, so each body moves, not the scene's root.
func place_oracle_at_origin() -> void:
	place_oracle()
	_origin = CENTRE
	(_scene.get_node("World") as Node2D).position = -_origin
	_player.position -= _origin
	for chaser: Enemy in _chasers:
		chaser.position -= _origin


## Relative to the player's start, in tiles.
func tiles_from_centre(position_px: Vector2) -> Vector2:
	return Units.vector_px_to_tiles(position_px - CENTRE + _origin)


func press_key(key: Key) -> void:
	send_key(key, true)
	send_key(key, false)
	Input.flush_buffered_events()


func send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


## The overlay writes its text on the next process frame.
func overlay_text() -> String:
	await wait_process_frames(1)
	var text: String = _overlay_label.text
	await get_tree().physics_frame
	return text


## A deep copy of the chaser's data, so a test can change any of it.
func chaser_copy() -> EnemyData:
	return EnemyArena.chaser_values()


func assert_tiles(actual: Vector2, expected: Vector2, label: String = "") -> void:
	assert_almost_eq(actual.x, expected.x, 0.01, label)
	assert_almost_eq(actual.y, expected.y, 0.01, label)
