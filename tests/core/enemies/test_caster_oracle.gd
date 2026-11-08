extends GutTest
## F-005 AC17–AC19 (and AC20's core half): the frame-rate oracle, at every rate.

const TIME: float = EnemyArena.TIME
const TILES: float = EnemyArena.TILES
const START: Vector2 = Vector2(0, 6.52)
## 2.75 s and a bit: the run ends on a thirtieth (the §5 oracle).
const END_30THS: int = 83


func test_ac17_run_a_standing_still() -> void:
	for rate: int in EnemyArena.RATES:
		var label: String = "%d ticks/s" % rate
		var arena: CasterArena = CasterArena.new()
		var player: PlayerMotor = arena.add_player()
		var caster: EnemyLogic = arena.add_caster(START)
		var watch: CasterWatch = arena.watch_caster(caster)
		arena.play(rate, 0, END_30THS)

		_assert_times(watch.times_entered(EnemyLogic.State.WINDUP), [0, 324], label)
		_assert_times(watch.aim_lock_times, [42], label)
		_assert_times(watch.times_entered(EnemyLogic.State.ACTIVE), [72], label)
		_assert_times(watch.times_entered(EnemyLogic.State.RECOVERY), [84], label)
		assert_eq(watch.at(1)["aim"], Vector2.UP, label)
		var launched: Dictionary = watch.projectile_at(72)
		_assert_tiles(launched["position"], START, "%s: launched where it stands" % label)
		assert_eq(launched["direction"], Vector2.UP, label)
		assert_null(watch.projectile_at(71), "%s: not before the windup end" % label)
		assert_eq(watch.at(72)["state"], EnemyLogic.State.ACTIVE, label)
		assert_eq(watch.at(180)["state"], EnemyLogic.State.IDLE, "%s: recovery over" % label)
		_assert_tiles(watch.projectile_at(191)["position"], Vector2(0, 0.57), label)
		_assert_times(arena.hurt_times, [191], label)
		_assert_times(arena.caster_landed_times, [191], label)
		assert_eq(watch.at(191)["hitstop"], 0.0, "%s: no hitstop before" % label)
		assert_eq(watch.at(192)["hitstop"], 0.0, "%s: nor from the bolt" % label)
		assert_eq(watch.at(192)["projectiles"].size(), 0, "%s: gone at the next step" % label)
		assert_eq(arena.hurt_events[0].direction, Vector2.UP, "%s: along the flight" % label)
		assert_almost_eq(arena.hurt_events[0].knockback_tiles, 0.5, TIME, label)
		_assert_tiles(watch.at(228)["position"], Vector2(0, 5.5208), label)
		_assert_tiles(watch.at(229)["position"], Vector2(0, 5.5), label)
		_assert_tiles(watch.at(323)["position"], Vector2(0, 5.5), "%s: holds" % label)
		assert_eq(watch.at(323)["state"], EnemyLogic.State.CHASE, label)
		_assert_tiles(watch.at(324)["position"], Vector2(0, 5.5), label)
		assert_eq(watch.at(330)["state"], EnemyLogic.State.WINDUP, "%s: at 2.75" % label)
		assert_eq(watch.at(330)["aim"], Vector2.UP, label)
		assert_eq(watch.at(330)["projectiles"].size(), 0, "%s: none in flight" % label)
		assert_eq(player.get_combat_state().get_hp(), 82, label)
		_assert_tiles(player.get_position_tiles(), Vector2(0, -0.5), label)
		assert_eq(arena.hurt_events.size(), 1, "%s: exactly one hit" % label)
		assert_eq(watch.seen_at.keys(), [0], "%s: one projectile so far" % label)


func test_ac17_the_player_knockback_ends_at_its_time() -> void:
	var arena: CasterArena = CasterArena.new()
	var player: PlayerMotor = arena.add_player()
	arena.add_caster(START)
	arena.ticks(211)
	assert_true(player.get_combat_state().has_knockback(), "still pushed at 211/120")
	arena.ticks(1)
	assert_false(player.get_combat_state().has_knockback(), "done at 211.4/120")
	_assert_tiles(player.get_position_tiles(), Vector2(0, -0.5), "")


func test_ac18_run_b_dash_through() -> void:
	for rate: int in EnemyArena.RATES:
		var label: String = "%d ticks/s" % rate
		var arena: CasterArena = CasterArena.new()
		var player: PlayerMotor = arena.add_player()
		var caster: EnemyLogic = arena.add_caster(START)
		var watch: CasterWatch = arena.watch_caster(caster)
		arena.play(rate, 0, END_30THS, {47: Vector2.DOWN}, [47])

		for step: int in range(189, 195):
			var dash_y: float = 20.0 * (step - 188) / 120.0
			var bolt: Vector2 = watch.projectile_at(step)["position"]
			assert_lt(
				bolt.distance_to(Vector2(0, dash_y)), 0.6, "%s: overlaps at %d" % [label, step]
			)
		assert_eq(arena.hurt_times.size(), 0, "%s: every overlap skipped" % label)
		_assert_tiles(watch.at(190)["position"], Vector2(0, 6.3117), label)
		_assert_tiles(watch.at(189)["position"], Vector2(0, 6.3325), "%s: still walking" % label)
		_assert_tiles(watch.at(300)["position"], Vector2(0, 6.3117), "%s: holds" % label)
		var last: Dictionary = watch.projectile_at(272)
		_assert_tiles(last["position"], Vector2(0, -3.48), label)
		assert_true(last["spent"], "%s: at max distance" % label)
		assert_false(watch.projectile_at(271)["spent"], label)
		assert_null(watch.projectile_at(273), "%s: gone at the next step" % label)
		_assert_times(watch.times_entered(EnemyLogic.State.WINDUP), [0, 324], label)
		_assert_tiles(watch.at(324)["position"], Vector2(0, 6.3117), label)
		assert_eq(player.get_combat_state().get_hp(), 100, label)
		_assert_tiles(player.get_position_tiles(), Vector2(0, 3), label)


func test_ac18_the_dash_ends_at_its_time() -> void:
	var arena: CasterArena = CasterArena.new()
	var player: PlayerMotor = arena.add_player()
	arena.add_caster(START)
	arena.play(120, 0, 48, {47: Vector2.DOWN}, [47])
	arena.ticks(206 - 192)
	_assert_tiles(player.get_position_tiles(), Vector2(0, 3), "")
	assert_ne(player.get_state(), PlayerMotor.State.DASHING, "ended at 206/120")


func test_ac19_run_c_fake_wall() -> void:
	for rate: int in EnemyArena.RATES:
		var label: String = "%d ticks/s" % rate
		var arena: CasterArena = CasterArena.new()
		var player: PlayerMotor = arena.add_player()
		var caster: EnemyLogic = arena.add_caster(START)
		var watch: CasterWatch = arena.watch_caster(caster)
		arena.move_bodies = _wall_at.bind(caster, 3.0)
		arena.play(rate, 0, 60)

		assert_false(watch.projectile_at(142)["spent"], label)
		var stopped: Dictionary = watch.projectile_at(143)
		assert_true(stopped["spent"], "%s: spent at 143" % label)
		_assert_tiles(stopped["position"], Vector2(0, 3.0), label)
		assert_null(watch.projectile_at(144), "%s: gone at 144" % label)
		assert_eq(player.get_combat_state().get_hp(), 100, label)


## Reports every projectile of `caster` stopped at y = `wall_y`, like a wall's glue would.
func _wall_at(caster: EnemyLogic, wall_y: float) -> void:
	var projectiles: ProjectileSet = caster.get_projectiles()
	for projectile: ProjectileSet.Projectile in projectiles.get_projectiles().duplicate():
		var reached: Vector2 = projectile.position
		reached.y = maxf(reached.y, wall_y)
		projectiles.report_position(projectile.serial, reached)


func _assert_times(actual: Array, expected_steps: Array, label: String) -> void:
	assert_eq(actual.size(), expected_steps.size(), "%s: %s" % [label, actual])
	for index: int in mini(actual.size(), expected_steps.size()):
		assert_almost_eq(float(actual[index]), expected_steps[index] / 120.0, TIME, label)


func _assert_tiles(actual: Vector2, expected: Vector2, label: String) -> void:
	assert_almost_eq(actual.x, expected.x, TILES, label)
	assert_almost_eq(actual.y, expected.y, TILES, label)
