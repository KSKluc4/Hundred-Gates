class_name F007SceneTest
extends GutTest
## Shared by F-007's scene tests. build() makes a scene in code around the origin (a player, a
## training dummy, then a boss, then a CombatRunner, in that registration order) with the boss
## read from user:// copies, so F5 re-reads them and a failed test can't damage real data.
## spawn_debug_scene() runs the real f007_warden.tscn.
##
## The copied boss is chaser-based: stage 0 lists [filler, root], where filler never triggers
## (band 5-6) and root (band 0-2) is followed by next; one stage at 50 % (shift 1.2) lists
## [stage_swipe]. Swipe timing is the chaser's: windup 0.5 (tracks 0.3), active 0.1,
## recovery 0.6. Nothing reaches the player (range 0.01), so no hitstop shifts the timing.

const DEBUG_SCENE_PATH: String = "res://scenes/debug/f007_warden.tscn"
const PLAYER_SCENE: PackedScene = preload("res://src/entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://src/entities/enemies/enemy.tscn")
const DUMMY_SCENE: PackedScene = preload("res://src/entities/dummy/training_dummy.tscn")
const TIME: float = 0.000001
const NOT_A_RANGE: float = 0.01

const FILLER_PATH: String = "user://test_f007_filler.tres"
const ROOT_PATH: String = "user://test_f007_root.tres"
const NEXT_PATH: String = "user://test_f007_next.tres"
const STAGE_SWIPE_PATH: String = "user://test_f007_stage_swipe.tres"
const STAGE_PATH: String = "user://test_f007_stage.tres"
const STAGE_2_PATH: String = "user://test_f007_stage_2.tres"
const BOSS_PATH: String = "user://test_f007_boss.tres"
const COPY_PATHS: Array[String] = [
	FILLER_PATH, ROOT_PATH, NEXT_PATH, STAGE_SWIPE_PATH, STAGE_PATH, STAGE_2_PATH, BOSS_PATH
]
## In root's band, outside filler's.
const PLAYER_AT: Vector2 = Vector2(0, 1.5)
const DUMMY_AT: Vector2 = Vector2(8, 0)

var _scene: Node2D
var _player: Player
var _dummy: TrainingDummy
var _boss: Enemy
var _runner: CombatRunner
var _t0: float = 0.0
var _ticks_per_second_before: int


func before_each() -> void:
	_ticks_per_second_before = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 120
	write_copies()


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks_per_second_before
	for path: String in COPY_PATHS:
		DirAccess.remove_absolute(path)


## Fresh, valid copies of every boss file, each pointing at the next one's file.
func write_copies() -> void:
	var source: EnemyData = BossValues.chaser_boss()
	var root: EnemyAttackData = source.attacks[0]
	root.lunge_tiles = 0.0
	root.range_tiles = NOT_A_RANGE
	root.trigger_max_tiles = 2.0
	var next: EnemyAttackData = root.follow_up
	next.lunge_tiles = 0.0
	next.range_tiles = NOT_A_RANGE
	_save(next, NEXT_PATH)
	root.follow_up = _fresh(NEXT_PATH)
	_save(root, ROOT_PATH)
	var filler: EnemyAttackData = root.duplicate()
	filler.id = &"filler"
	filler.follow_up = null
	filler.trigger_min_tiles = 5.0
	filler.trigger_max_tiles = 6.0
	_save(filler, FILLER_PATH)
	var stage: EnemyStageData = source.stages[0]
	stage.attacks[0].range_tiles = NOT_A_RANGE
	stage.attacks[0].lunge_tiles = 0.0
	_save(stage.attacks[0], STAGE_SWIPE_PATH)
	stage.attacks = [_fresh(STAGE_SWIPE_PATH)] as Array[EnemyAttackData]
	_save(stage, STAGE_PATH)
	var stage_2: EnemyStageData = stage.duplicate()
	stage_2.enter_at_hp_percent = 25
	_save(stage_2, STAGE_2_PATH)
	source.attacks = [_fresh(FILLER_PATH), _fresh(ROOT_PATH)] as Array[EnemyAttackData]
	source.stages = [_fresh(STAGE_PATH)] as Array[EnemyStageData]
	_save(source, BOSS_PATH)


## Player, dummy, boss, runner. Ends right after the debug reset, like F-006's build().
func build(boss_data: EnemyData = null, boss_at: Vector2 = Vector2.ZERO) -> void:
	_scene = Node2D.new()
	_player = PLAYER_SCENE.instantiate()
	_player.name = "Player"
	_player.position = Units.vector_tiles_to_px(PLAYER_AT)
	_player.input_enabled = false
	_scene.add_child(_player)
	_dummy = DUMMY_SCENE.instantiate()
	_dummy.name = "Dummy"
	_dummy.combat_id = &"dummy_1"
	_dummy.position = Units.vector_tiles_to_px(DUMMY_AT)
	_scene.add_child(_dummy)
	_boss = ENEMY_SCENE.instantiate()
	_boss.name = "Boss"
	_boss.combat_id = &"boss_1"
	_boss.data = boss_data if boss_data != null else load_boss()
	_boss.position = Units.vector_tiles_to_px(boss_at)
	_scene.add_child(_boss)
	_runner = CombatRunner.new()
	_runner.name = "CombatRunner"
	_runner.combatant_paths = [NodePath("../Player"), NodePath("../Dummy"), NodePath("../Boss")]
	_scene.add_child(_runner)
	add_child_autofree(_scene)
	await get_tree().physics_frame
	_runner.reset()
	_t0 = _runner.get_sim().get_time()


func load_boss() -> EnemyData:
	return ResourceLoader.load(BOSS_PATH, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)


## One runner tick per iteration, with no player input.
func run_ticks(ticks: int) -> void:
	for _i: int in ticks:
		_player.motor.submit(MoveCommand.new(Vector2.ZERO))
		_player.motor.submit(AimCommand.new(Vector2.DOWN))
		await get_tree().physics_frame


func run_time() -> float:
	return _runner.get_sim().get_time() - _t0


## Runs until `condition` holds, at most `limit` ticks. Returns whether it held.
func run_until(condition: Callable, limit: int = 600) -> bool:
	for _i: int in limit:
		if condition.call():
			return true
		await run_ticks(1)
	return condition.call()


## Puts the boss in stage 1 at once: its HP at the line, then one step start.
func enter_stage_1() -> void:
	BossValues.set_hp(_boss.logic, 200)
	await run_ticks(1)
	assert_eq(_boss.logic.get_stage_index(), 1, "in stage 1")


func boss_state() -> EnemyLogic.State:
	return _boss.logic.get_state()


## Overwrites one field of a copy on disk.
func write(path: String, field: String, value: Variant) -> void:
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	resource.set(field, value)
	assert_eq(ResourceSaver.save(resource, path), OK)


## A copy as it is on disk now, never from the cache.
func fresh(path: String) -> Resource:
	return _fresh(path)


## Everything an F5 could change, by object or by value.
func reload_touches() -> Dictionary:
	var logic: EnemyLogic = _boss.logic
	return {
		"class": _player.class_data,
		"player_rules": Tunables.player_combat,
		"enemy_rules": Tunables.enemy_combat,
		"dummy": _dummy.data,
		"dummy_state": _dummy.logic.to_dict(),
		"boss": logic.get_data(),
		"stage": logic.get_stage_index(),
		"shift_left": logic.get_stage_shift_left(),
		"attack": logic.get_running_attack(),
		"state": logic.get_state(),
		"cooldown": logic.get_cooldown_remaining(),
		"rate": _runner.get_sim().get_step_rate(),
	}


func _save(resource: Resource, path: String) -> void:
	assert_eq(ResourceSaver.save(resource, path), OK, path)


func _fresh(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
