extends F006SceneTest
## F-006 C7's glue half over real physics: AC6 (a wall stops and stuns the charge), AC7a/b (no
## false stuns from a touching wall or a chaser's body) and AC19 (a segment that starts inside a
## wall). Runs at 120 ticks/s, where a tick end is a step end.

const CHARGE: int = BruteArena.CHARGE
## A 0.5-tile pillar whose face stops the brute's centre at x = 2.97: inside step 126.
const PILLAR: Rect2 = Rect2(3.57, -1.0, 0.5, 2.0)
const STOP_STEP: int = 126


func before_each() -> void:
	super()
	Engine.physics_ticks_per_second = 120


func test_ac6_a_charge_into_a_wall_stops_there_and_stuns() -> void:
	await build([PILLAR] as Array[Rect2], Vector2(5.5, 0), Vector2.ZERO)
	var probe: StepEndProbe = probe_brute()
	var watch: EnemyWatch = watch_brute()
	var hurt: Array[float] = record_hurt()
	await run_ticks(STOP_STEP)
	assert_eq(stop_step(probe), STOP_STEP, "the step it met the wall")
	assert_eq(_brute.logic.get_state(), EnemyLogic.State.RECOVERY)
	assert_true(_brute.logic.is_wall_stopped())
	assert_almost_eq(brute_tiles().x, 2.97, TILES, "at the wall")
	assert_eq(_brute.get_body_color(), _brute.open_color, "the open tint")
	await run_to(3.0)
	var recovery: Array[float] = entered(watch, EnemyLogic.State.RECOVERY)
	assert_eq(recovery.size(), 1)
	assert_almost_eq(recovery[0], 1.05, TIME, "RECOVERY from the stop contact")
	var idle: Array[float] = entered(watch, EnemyLogic.State.IDLE)
	assert_almost_eq(idle[idle.size() - 1], 2.55, TIME, "1.5 s of stun from the stop contact")
	assert_eq(hurt.size(), 0)
	assert_false(_brute.logic.is_wall_stopped())


func test_ac6_a_player_pinned_against_the_wall_is_hit_once_and_the_stun_follows() -> void:
	await build([PILLAR] as Array[Rect2], Vector2(3.2, 0), Vector2.ZERO)
	var probe: StepEndProbe = probe_brute()
	var watch: EnemyWatch = watch_brute()
	var hurt: Array[float] = record_hurt()
	await run_to(3.0)
	assert_eq(hurt.size(), 1, "one hit per attack instance")
	var stop: int = stop_step(probe)
	var hitstop: int = roundi(_runner.get_sim().get_tunables().hitstop_normal * 120.0)
	assert_eq(stop, STOP_STEP + hitstop, "the attacker hitstop delayed it, then the wall")
	var recovery: Array[float] = entered(watch, EnemyLogic.State.RECOVERY)
	assert_almost_eq(recovery[0], stop * STEP, TIME)
	var idle: Array[float] = entered(watch, EnemyLogic.State.IDLE)
	assert_almost_eq(idle[idle.size() - 1], stop * STEP + 1.5, TIME, "the stun")


func test_ac7a_a_charge_sliding_along_a_wall_it_touches_is_no_stop() -> void:
	for gap: float in [0.0, 0.1]:
		var label: String = "wall %s tiles from the body" % gap
		var data: EnemyData = _far_target_data()
		var wall: Rect2 = Rect2(-2.0, 0.6 + gap, 14.0, 1.0)
		await build([wall] as Array[Rect2], Vector2(7.5, 0), Vector2.ZERO, data)
		var probe: StepEndProbe = probe_brute()
		var watch: EnemyWatch = watch_brute()
		await run_to(2.5)
		assert_eq(stop_step(probe), -1, label)
		var recovery: float = entered(watch, EnemyLogic.State.RECOVERY)[0]
		assert_almost_eq(recovery, 1.3, TIME, label)
		var idle: Array[float] = entered(watch, EnemyLogic.State.IDLE)
		assert_almost_eq(idle[idle.size() - 1] - recovery, 0.9, TIME, "%s: normal" % label)
		assert_almost_eq(brute_tiles().x, 6.0, TILES, "%s: the full 6 tiles" % label)
		_scene.queue_free()


func test_ac7b_a_chaser_in_the_lane_never_stuns() -> void:
	await build(
		[] as Array[Rect2], Vector2(7.5, 0), Vector2.ZERO, _far_target_data(), Vector2(3, 0.3)
	)
	var probe: StepEndProbe = probe_brute()
	await run_to(2.5)
	assert_eq(stop_step(probe), -1, "slides along the chaser")
	assert_false(_brute.logic.is_wall_stopped())
	assert_gt(brute_tiles().x, 3.0, "it got past")
	assert_ne(_brute.logic.get_state(), EnemyLogic.State.RECOVERY, "0.9 s, not 1.5")


func test_ac7b_overlapping_a_chaser_at_a_segment_start_is_no_stop() -> void:
	var chaser_at: Vector2 = Vector2(0, 5)
	await build([] as Array[Rect2], Vector2(7.5, 0), Vector2.ZERO, _far_target_data(), chaser_at)
	var probe: StepEndProbe = probe_brute()
	await run_ticks(110)
	_put_chaser_at(brute_tiles() + Vector2(0.3, 0.1))  # Overlapping the brute's body.
	await run_ticks(1)
	_put_chaser_at(brute_tiles() + Vector2(0.2, -0.1))
	await run_to(2.5)
	assert_eq(stop_step(probe), -1)
	assert_false(_brute.logic.is_wall_stopped())


func test_ac19_a_radius_reload_into_a_parallel_wall_is_a_stop() -> void:
	await build(
		[Rect2(-2.0, 0.7, 14.0, 1.0)] as Array[Rect2],
		Vector2(7.5, 0),
		Vector2.ZERO,
		_far_target_data()
	)
	var probe: StepEndProbe = probe_brute()
	await run_ticks(110)
	assert_eq(stop_step(probe), -1, "touching nothing yet")
	_reload_radius(1.0)
	await run_ticks(1)
	assert_eq(stop_step(probe), 111, "the next lunge step starts inside the wall")
	assert_true(_brute.logic.is_wall_stopped())
	assert_eq(_brute.logic.get_state(), EnemyLogic.State.RECOVERY)


func test_ac19_on_the_last_lunge_step_too() -> void:
	await build(
		[Rect2(-2.0, 0.7, 14.0, 1.0)] as Array[Rect2],
		Vector2(7.5, 0),
		Vector2.ZERO,
		_far_target_data()
	)
	var probe: StepEndProbe = probe_brute()
	var watch: EnemyWatch = watch_brute()
	await run_ticks(155)
	assert_eq(_brute.logic.get_state(), EnemyLogic.State.ACTIVE, "one lunge step left")
	_reload_radius(1.0)
	await run_ticks(1)
	assert_eq(stop_step(probe), 156)
	var after: Dictionary = probe.after_step[156 + roundi(_t0 * 120.0)]
	assert_eq(after["state"], EnemyLogic.State.RECOVERY)
	assert_true(after["wall_stopped"])
	await run_to(3.0)
	var idle: Array[float] = entered(watch, EnemyLogic.State.IDLE)
	assert_almost_eq(idle[idle.size() - 1], 1.3 + 1.5, TIME, "the stun follows")


func test_ac19_also_when_the_charge_points_away_from_the_wall() -> void:
	var behind: Rect2 = Rect2(-1.7, -2.0, 1.0, 4.0)  # Its face 0.7 tiles behind the brute.
	await build([behind] as Array[Rect2], Vector2(7.5, 0), Vector2.ZERO, _far_target_data())
	var probe: StepEndProbe = probe_brute()
	await run_ticks(96)
	_reload_radius(1.0)
	await run_ticks(1)
	assert_eq(stop_step(probe), 97, "the first lunge step starts inside the wall")
	assert_true(_brute.logic.is_wall_stopped())


func test_ac19_controls_without_the_reload_there_is_no_stop() -> void:
	var walls: Array = [Rect2(-2.0, 0.7, 14.0, 1.0), Rect2(-1.7, -2.0, 1.0, 4.0)]
	for wall: Rect2 in walls:
		await build([wall] as Array[Rect2], Vector2(7.5, 0), Vector2.ZERO, _far_target_data())
		var probe: StepEndProbe = probe_brute()
		await run_to(2.5)
		assert_eq(stop_step(probe), -1, str(wall))
		assert_almost_eq(brute_tiles().x, 6.0, TILES, str(wall))
		_scene.queue_free()


func test_ac19_control_overlapping_only_a_chaser_is_no_stop() -> void:
	var chaser_at: Vector2 = Vector2(3.0, 1.1)  # 1.1 from the lane: clear until the reload.
	await build([] as Array[Rect2], Vector2(7.5, 0), Vector2.ZERO, _far_target_data(), chaser_at)
	var probe: StepEndProbe = probe_brute()
	await run_ticks(128)  # The brute is at x = 3.2, beside the chaser.
	_reload_radius(1.0)
	await run_to(2.5)
	assert_eq(stop_step(probe), -1)
	assert_false(_brute.logic.is_wall_stopped())


## A target 7.5 tiles out: still in the charge's band and aggro radius, but beyond its reach
## (6 + 0.9 + 0.35), so no hitstop shifts the timeline.
func _far_target_data() -> EnemyData:
	var data: EnemyData = BruteArena.brute_values()
	data.aggro_radius_tiles = 8.0
	data.attacks[CHARGE].trigger_max_tiles = 8.0
	return data


## The glue's half of a reload (CombatRunner._apply_reload()), between ticks.
func _reload_radius(radius: float) -> void:
	var data: EnemyData = _brute.logic.get_data().duplicate()
	data.hurtbox_radius_tiles = radius
	var rate: int = _runner.get_sim().get_step_rate()
	_brute.apply_reloaded_data(data, Tunables.enemy_combat, rate)
	assert_eq(_brute.logic.get_data().hurtbox_radius_tiles, radius, "accepted")


func _put_chaser_at(tiles: Vector2) -> void:
	_chaser.logic.sync_position(Units.vector_tiles_to_px(tiles))
	_chaser.sync_body_from_logic()
