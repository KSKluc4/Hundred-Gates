extends F006SceneTest
## F-006 T7: the debug scene, f006_brute.tscn, and AC5 end to end in it.

## The brute starts 5 tiles left of the player, on the same row.
const BRUTE_START: Vector2 = Vector2(3.0, 6.0)
const PLAYER_START: Vector2 = Vector2(8.0, 6.0)


func before_each() -> void:
	super()
	Engine.physics_ticks_per_second = 120


func test_the_scene_starts_with_its_combatants_in_order() -> void:
	await spawn_debug_scene()
	assert_eq(_runner.get_setup_errors(), PackedStringArray())
	var ids: Array[StringName] = []
	for combatant: Combatant in _runner.get_sim().get_combatants():
		ids.append(combatant.get_combat_id())
	assert_eq(ids, [&"player_1", &"brute_1", &"chaser_1"] as Array[StringName])
	assert_eq(_brute.get_data_path(), Tunables.BRUTE_PATH)
	assert_eq(_brute.logic.get_data().brain, EnemyData.Brain.BRUTE)
	assert_tiles(brute_tiles(), BRUTE_START)
	assert_tiles(Units.vector_px_to_tiles(_player.global_position), PLAYER_START)
	assert_true(_runner.refill_player_on_died)
	assert_true(_runner.is_shake_on())


func test_the_inner_wall_is_four_tiles_behind_the_player() -> void:
	await spawn_debug_scene()
	var wall: StaticBody2D = _scene.get_node("World/InnerWall")
	var shape: RectangleShape2D = (wall.get_node("CollisionShape2D") as CollisionShape2D).shape
	var face: float = Units.px_to_tiles(wall.global_position.x - shape.size.x / 2.0)
	assert_almost_eq(face - PLAYER_START.x, 4.0, TIME)
	assert_eq(wall.collision_layer, 1, "layer 1 world")


func test_ac5_a_player_in_the_lane_is_hit_once_and_the_charge_runs_on() -> void:
	await spawn_debug_scene()
	var watch: EnemyWatch = watch_brute()
	var damage: Array[HitEvent] = []
	_player.motor.get_combat_state().damaged.connect(
		func(event: HitEvent) -> void: damage.append(event)
	)
	await run_to(2.0)
	assert_eq(damage.size(), 1, "once per attack instance")
	assert_eq(damage[0].damage, 25)
	assert_eq(damage[0].knockback_tiles, 1.5)
	assert_eq(_player.motor.get_combat_state().get_hp(), 75)
	var hitstop: float = _runner.get_sim().get_tunables().hitstop_normal
	var recovery: Array[float] = entered(watch, EnemyLogic.State.RECOVERY)
	assert_almost_eq(recovery[0], 1.3 + hitstop, TIME, "paused by its hitstop, not shortened")
	assert_tiles(brute_tiles(), BRUTE_START + Vector2(6.0, 0), "the full 6 tiles")
	assert_false(_brute.logic.is_wall_stopped())


func test_ac5_a_sideways_dash_after_the_lock_dodges_it() -> void:
	await spawn_debug_scene()
	var hurt: Array[float] = record_hurt()
	await run_to(0.6)
	assert_true(_brute.logic.is_aim_locked())
	await run_ticks(1, false, true, Vector2.DOWN)
	await run_to(2.0)
	assert_eq(hurt.size(), 0, "out of the lane")
	assert_tiles(brute_tiles(), BRUTE_START + Vector2(6.0, 0))
