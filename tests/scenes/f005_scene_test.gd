class_name F005SceneTest
extends GutTest
## Shared by F-005's scene tests: spawns the real caster scene and runs scripted ticks.

const SCENE: PackedScene = preload("res://scenes/debug/f005_caster.tscn")
const TIME: float = 0.000001
const TILE_PX: float = 0.16  # 0.01 tiles, the §5 tolerance.
## Room centre, and corners far beyond any aggro radius from it.
const CENTRE: Vector2 = Vector2(240, 160)
const FAR_WEST: Vector2 = Vector2(24, 24)
const FAR_EAST: Vector2 = Vector2(456, 24)
## The §5 oracle's caster: 6.52 tiles below the player.
const ORACLE_OFFSET: Vector2 = Vector2(0, 6.52 * 16.0)

var _scene: Node
var _player: Player
var _casters: Array[Enemy] = []
var _chaser: Enemy
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
	_origin = Vector2.ZERO


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks_per_second_before
	Tunables.player_combat = _tunables_before
	Tunables.enemy_combat = _enemy_rules_before


## prepare runs before the scene enters the tree: move nodes, swap data.
func spawn(prepare: Callable = Callable()) -> void:
	_scene = SCENE.instantiate()
	_player = _scene.get_node("Player")
	_casters = [_scene.get_node("Caster1"), _scene.get_node("Caster2")]
	_chaser = _scene.get_node("Chaser1")
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


## The §5 oracle: player at the centre, caster_1 6.52 tiles below, the others parked in the
## corners where they never notice anyone.
func place_oracle() -> void:
	_player.position = CENTRE
	_casters[0].position = CENTRE + ORACLE_OFFSET
	park_others()


## caster_2 and the chaser, out of everyone's way.
func park_others() -> void:
	_casters[1].position = FAR_WEST
	_chaser.position = FAR_EAST


## The oracle at its own coordinates: the room moved so the player starts at (0, 0).
## F-004 ASSUMPTION-3: positions are float32, so exact boundaries only fall where §5 says
## near the origin. A node keeps its local position, so each body moves, not the scene's root.
func place_oracle_at_origin() -> void:
	place_oracle()
	_origin = CENTRE
	(_scene.get_node("World") as Node2D).position = -_origin
	_player.position -= _origin
	for enemy: Enemy in [_casters[0], _casters[1], _chaser]:
		enemy.position -= _origin


## Relative to the room's centre, in tiles.
func tiles_from_centre(position_px: Vector2) -> Vector2:
	return Units.vector_px_to_tiles(position_px - CENTRE + _origin)


## Registered last, so it records what the caster decided and its projectiles at every contact.
func watch_caster(enemy: Enemy) -> CasterWatch:
	var watch: CasterWatch = CasterWatch.new(enemy.logic, _runner.get_sim())
	_runner.get_sim().register(watch)
	return watch


## A watch keys its contacts by step since the sim started: this is by step since the run did.
func at(watch: CasterWatch, step_index: int) -> Dictionary:
	return watch.at(step_index + roundi(_t0 * 120.0))


func projectile_at(watch: CasterWatch, step_index: int, serial: int = 0) -> Variant:
	return watch.projectile_at(step_index + roundi(_t0 * 120.0), serial)


func since_start(times: Array) -> Array:
	var shifted: Array = []
	for time: float in times:
		if time >= _t0 - TIME:
			shifted.append(time - _t0)
	return shifted


## Run times of every hit the player took.
func record_hurt() -> Array[float]:
	var times: Array[float] = []
	# Through self: capturing the sim would keep it alive forever.
	_player.motor.get_combat_state().damaged.connect(
		func(_event: HitEvent) -> void: times.append(run_time())
	)
	return times


func press_key(key: Key) -> void:
	_send_key(key, true)
	_send_key(key, false)
	Input.flush_buffered_events()


func _send_key(key: Key, pressed: bool) -> void:
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


## A deep copy of the caster's data, so a test can change any of it.
func caster_copy() -> EnemyData:
	return CasterArena.caster_values()


func assert_tiles(actual: Vector2, expected: Vector2, label: String = "") -> void:
	assert_almost_eq(actual.x, expected.x, 0.01, label)
	assert_almost_eq(actual.y, expected.y, 0.01, label)


func assert_steps(actual: Array, expected_steps: Array, label: String) -> void:
	assert_eq(actual.size(), expected_steps.size(), "%s: %s" % [label, actual])
	for index: int in mini(actual.size(), expected_steps.size()):
		assert_almost_eq(float(actual[index]), expected_steps[index] / 120.0, TIME, label)
