extends F005SceneTest
## F-005 AC20: runs A and B of the §5 oracle over real physics, at every rate. No walls are in
## the projectile's path, so the glue's sweeps must change nothing.

const RATES: Array[int] = [30, 60, 120]
const END_30THS: int = 83

var _positions_agree: bool = true


func test_ac20_run_a_standing_still_over_real_physics() -> void:
	for rate: int in RATES:
		var label: String = "%d ticks/s" % rate
		Engine.physics_ticks_per_second = rate
		await spawn_fresh(place_oracle_at_origin)
		var watch: CasterWatch = watch_caster(_casters[0])
		var hurt: Array[float] = record_hurt()
		await run_ticks(END_30THS * rate / 30)

		assert_steps(since_start(watch.times_entered(EnemyLogic.State.WINDUP)), [0, 324], label)
		assert_steps(since_start(watch.aim_lock_times), [42], label)
		assert_steps(since_start(watch.times_entered(EnemyLogic.State.ACTIVE)), [72], label)
		assert_steps(since_start(watch.times_entered(EnemyLogic.State.RECOVERY)), [84], label)
		assert_tiles(projectile_at(watch, 72)["position"], Vector2(0, 6.52), label)
		assert_eq(projectile_at(watch, 72)["direction"], Vector2.UP, label)
		assert_tiles(projectile_at(watch, 191)["position"], Vector2(0, 0.57), label)
		assert_steps(hurt, [191], label)
		assert_eq(at(watch, 192)["projectiles"].size(), 0, "%s: gone" % label)
		assert_eq(at(watch, 192)["hitstop"], 0.0, "%s: no caster hitstop" % label)
		assert_tiles(at(watch, 229)["position"], Vector2(0, 5.5), label)
		assert_tiles(at(watch, 323)["position"], Vector2(0, 5.5), label)
		assert_eq(at(watch, 330)["state"], EnemyLogic.State.WINDUP, label)
		assert_eq(at(watch, 330)["projectiles"].size(), 0, label)
		assert_eq(_player.motor.get_combat_state().get_hp(), 82, label)
		assert_tiles(tiles_from_centre(_player.global_position), Vector2(0, -0.5), label)
		assert_tiles(tiles_from_centre(_casters[0].global_position), Vector2(0, 5.5), label)
		assert_eq(hurt.size(), 1, "%s: exactly one hit" % label)
		_scene.queue_free()


func test_ac20_run_b_dash_through_over_real_physics() -> void:
	for rate: int in RATES:
		var label: String = "%d ticks/s" % rate
		Engine.physics_ticks_per_second = rate
		await spawn_fresh(place_oracle_at_origin)
		var watch: CasterWatch = watch_caster(_casters[0])
		var hurt: Array[float] = record_hurt()
		var per_30th: int = rate / 30
		await run_ticks(47 * per_30th)
		await run_ticks(per_30th, false, true, Vector2.DOWN)  # 1.5667: dash + move for 1/30 s.
		await run_ticks((END_30THS - 48) * per_30th)

		assert_eq(hurt.size(), 0, "%s: dashed through" % label)
		assert_tiles(at(watch, 190)["position"], Vector2(0, 6.3117), label)
		assert_tiles(at(watch, 300)["position"], Vector2(0, 6.3117), label)
		var last: Dictionary = projectile_at(watch, 272)
		assert_tiles(last["position"], Vector2(0, -3.48), label)
		assert_true(last["spent"], label)
		assert_null(projectile_at(watch, 273), label)
		assert_steps(since_start(watch.times_entered(EnemyLogic.State.WINDUP)), [0, 324], label)
		assert_eq(_player.motor.get_combat_state().get_hp(), 100, label)
		assert_tiles(tiles_from_centre(_player.global_position), Vector2(0, 3), label)
		assert_tiles(tiles_from_centre(_casters[0].global_position), Vector2(0, 6.3117), label)
		_scene.queue_free()


func test_c5_logic_and_body_agree_while_it_shoots() -> void:
	await spawn_fresh(place_oracle_at_origin)
	var probe: SimProbe = SimProbe.new()
	probe.on_contact = _check_positions
	_runner.get_sim().register(probe)
	await run_ticks(150)
	assert_true(_positions_agree)


func _check_positions() -> void:
	for enemy: Enemy in _casters:
		if enemy.logic.get_position_px() != enemy.global_position:
			_positions_agree = false
