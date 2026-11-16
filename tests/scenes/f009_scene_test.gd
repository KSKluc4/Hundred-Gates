class_name F009SceneTest
extends GutTest
## Shared by F-009's scene tests: spawn_debug_scene() runs the real f009_juggernaut.tscn at
## 120 ticks/s, where a tick end is a step end.

const DEBUG_SCENE_PATH: String = "res://scenes/debug/f009_juggernaut.tscn"
const TIME: float = 0.000001
const STEP: float = 1.0 / 120.0

var _scene: Node2D
var _player: Player
var _enemy: Enemy
var _runner: CombatRunner
var _bar: BossBar
var _overlay_label: Label
var _t0: float = 0.0
var _ticks_per_second_before: int


func before_each() -> void:
	_ticks_per_second_before = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 120


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks_per_second_before


## The real debug scene: the Warrior and the Juggernaut. `prepare` runs before it enters the
## tree (move nodes). Ends right after the debug reset.
func spawn_debug_scene(prepare: Callable = Callable()) -> void:
	_scene = (load(DEBUG_SCENE_PATH) as PackedScene).instantiate()
	_player = _scene.get_node("Player")
	_enemy = _scene.get_node("Juggernaut")
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


## Before the scene enters the tree: the player and the Juggernaut at these tiles of the room.
func place(player_tiles: Vector2, enemy_tiles: Vector2) -> void:
	_player.position = Units.vector_tiles_to_px(player_tiles)
	_enemy.position = Units.vector_tiles_to_px(enemy_tiles)


## Registered last, so it records the Juggernaut and its bolts at every contact.
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


func running_id() -> StringName:
	var attack: EnemyAttackData = _enemy.logic.get_running_attack()
	return attack.id if attack != null else &""


func enemy_tiles() -> Vector2:
	return _enemy.logic.get_position_tiles()
