class_name F003SceneTest
extends GutTest
## Shared by F-003's scene tests: spawns the real debug scene and runs scripted ticks.

const SCENE: PackedScene = preload("res://scenes/debug/f003_sword.tscn")
const TIME: float = 0.000001
const TILE_PX: float = 0.16  # 0.01 tiles, the §5 tolerance.

var _scene: Node
var _player: Player
var _anchored: TrainingDummy
var _loose: TrainingDummy
var _runner: CombatRunner
var _overlay_label: Label
var _debug_draw: CombatDebugDraw
var _shake: PlaceholderShake
var _ticks_per_second_before: int
var _tunables_before: PlayerCombatTunables


func before_each() -> void:
	_ticks_per_second_before = Engine.physics_ticks_per_second
	_tunables_before = Tunables.player_combat


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks_per_second_before
	Tunables.player_combat = _tunables_before


## prepare runs before the scene enters the tree: move nodes, swap data.
func spawn(prepare: Callable = Callable()) -> void:
	_scene = SCENE.instantiate()
	_player = _scene.get_node("Player")
	_anchored = _scene.get_node("AnchoredDummy")
	_loose = _scene.get_node("LooseDummy")
	_runner = _scene.get_node("CombatRunner")
	_overlay_label = _scene.get_node("MotorDebugOverlay/Label")
	_debug_draw = _scene.get_node("CombatDebugDraw")
	_shake = _scene.get_node("Player/PlaceholderShake")
	_player.input_enabled = false
	if prepare.is_valid():
		prepare.call()
	add_child_autofree(_scene)
	await get_tree().physics_frame  # run_ticks must start just before a runner tick.


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


## A pulse with no telegraph, so a toggle at the start of a test is live at once.
func quick_pulse(damage: int = 20, knockback: float = 0.0, active: float = 1.0) -> DummyData:
	var data: DummyData = (load(Tunables.TRAINING_DUMMY_PATH) as DummyData).duplicate()
	data.pulse_telegraph = 0.0
	data.pulse_active = active
	data.pulse_damage = damage
	data.pulse_knockback_tiles = knockback
	data.pulse_interval = active + 1.0
	return data


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
