extends F004SceneTest
## AC18: runs A and B of the §5 oracle over real physics, at every rate. AC21: bodies.

const RATES: Array[int] = [30, 60, 120]
## AC21: two radii of 0.4 tiles, less the §5 tolerance.
const MIN_GAP_PX: float = (2.0 * 0.4 - 0.01) * 16.0
const RADIUS_PX: float = 0.4 * 16.0
## Above the pillar, 5.6 tiles from a player straight below it: walks into its top face.
const ABOVE_PILLAR: Vector2 = Vector2(288, 70)
const BELOW_PILLAR: Vector2 = Vector2(288, 160)
const PILLAR_TOP_PX: float = 88.0
## The south wall's inner face, and a chaser whose lunge downward would cross it.
const SOUTH_FACE_PX: float = 320.0
const NEAR_SOUTH_PLAYER: Vector2 = Vector2(240, 312)
const NEAR_SOUTH_CHASER: Vector2 = Vector2(240, 304)

var _positions_agree: bool = true
var _min_gap_px: float = INF
var _contacts: int = 0


func test_ac18_run_a_standing_still_over_real_physics() -> void:
	for rate: int in RATES:
		var label: String = "%d ticks/s" % rate
		Engine.physics_ticks_per_second = rate
		await spawn_fresh(place_oracle_at_origin)
		var watch: EnemyWatch = _watch(_chasers[0].logic)
		var hurt: Array[float] = _record_hurt()
		await run_ticks(78 * rate / 30)

		_assert_steps(_since_start(watch.times_entered(EnemyLogic.State.WINDUP)), [56, 302], label)
		_assert_steps(_since_start(watch.aim_lock_times), [92], label)
		_assert_steps(_since_start(watch.times_entered(EnemyLogic.State.ACTIVE)), [116], label)
		_assert_steps(_since_start(watch.times_entered(EnemyLogic.State.RECOVERY)), [134], label)
		_assert_steps(hurt, [117], label)
		assert_tiles(_at(watch, 56)["position"], Vector2(0, 1.6), label)
		assert_eq(_at(watch, 60)["aim"], Vector2.UP, label)
		assert_tiles(_at(watch, 134)["position"], Vector2(0, 0.8), label)
		assert_tiles(_at(watch, 230)["position"], Vector2(0, 0.2), label)
		assert_tiles(_at(watch, 301)["position"], Vector2(0, 0.2), label)
		assert_eq(_player.motor.get_combat_state().get_hp(), 80, label)
		assert_tiles(tiles_from_centre(_player.global_position), Vector2(0, -0.8), label)
		assert_tiles(tiles_from_centre(_chasers[0].global_position), Vector2(0, 0.2), label)
		assert_eq(_chasers[0].logic.get_state(), EnemyLogic.State.WINDUP, label)
		assert_eq(hurt.size(), 1, "%s: exactly one hit" % label)
		_scene.queue_free()


func test_ac18_run_b_dash_after_the_lock_over_real_physics() -> void:
	for rate: int in RATES:
		var label: String = "%d ticks/s" % rate
		Engine.physics_ticks_per_second = rate
		await spawn_fresh(place_oracle_at_origin)
		var watch: EnemyWatch = _watch(_chasers[0].logic)
		var hurt: Array[float] = _record_hurt()
		var per_30th: int = rate / 30
		await run_ticks(24 * per_30th)
		await run_ticks(per_30th, false, true, Vector2.RIGHT)  # 0.8: dash + right for 1/30 s.
		await run_ticks(50 * per_30th)  # To 2.5.

		_assert_steps(_since_start(watch.times_entered(EnemyLogic.State.WINDUP)), [56, 296], label)
		_assert_steps(_since_start(watch.times_entered(EnemyLogic.State.ACTIVE)), [116], label)
		_assert_steps(_since_start(watch.times_entered(EnemyLogic.State.RECOVERY)), [128], label)
		assert_eq(_at(watch, 120)["hitbox_direction"], Vector2.UP, "%s: locked aim" % label)
		assert_tiles(_at(watch, 128)["position"], Vector2(0, 0.8), label)
		assert_eq(_at(watch, 201)["state"], EnemyLogic.State.CHASE, label)
		assert_tiles(_at(watch, 295)["position"], Vector2(2.0338, 0.2577), label)
		assert_tiles(tiles_from_centre(_player.global_position), Vector2(3, 0), label)
		assert_tiles(tiles_from_centre(_chasers[0].global_position), Vector2(2.0338, 0.2577))
		assert_eq(_chasers[0].logic.get_state(), EnemyLogic.State.WINDUP, label)
		assert_eq(_player.motor.get_combat_state().get_hp(), 100, label)
		assert_eq(hurt.size(), 0, "%s: no hit landed" % label)
		_scene.queue_free()


## C1 in the room's own coordinates. There, float32 rounding puts the 1.6 boundary one step
## later than §5's table (ASSUMPTION-3), but every rate still takes the same decisions.
func test_c1_room_coordinates_give_the_same_run_at_every_rate() -> void:
	var runs: Array[Dictionary] = []
	for rate: int in RATES:
		Engine.physics_ticks_per_second = rate
		await spawn_fresh(place_oracle)
		var watch: EnemyWatch = _watch(_chasers[0].logic)
		var hurt: Array[float] = _record_hurt()
		await run_ticks(78 * rate / 30)
		var windups: Array = _since_start(watch.times_entered(EnemyLogic.State.WINDUP))
		(
			runs
			. append(
				{
					"windups": windups,
					"hurt": hurt,
					"chaser": tiles_from_centre(_chasers[0].global_position),
					"player": tiles_from_centre(_player.global_position),
				}
			)
		)
		_scene.queue_free()
	for index: int in [1, 2]:
		var label: String = "%d vs 30 ticks/s" % RATES[index]
		assert_eq(runs[index]["windups"].size(), runs[0]["windups"].size(), label)
		for windup: int in runs[0]["windups"].size():
			assert_almost_eq(runs[index]["windups"][windup], runs[0]["windups"][windup], TIME)
		assert_eq(runs[index]["hurt"].size(), 1, label)
		assert_almost_eq(runs[index]["hurt"][0], runs[0]["hurt"][0], TIME, label)
		assert_tiles(runs[index]["chaser"], runs[0]["chaser"], label)
		assert_tiles(runs[index]["player"], runs[0]["player"], label)


func test_ac21_the_player_walks_through_a_chaser() -> void:
	await spawn_fresh(_place_in_the_way)
	_runner.toggle_ai()
	var chaser_start: Vector2 = _chasers[0].global_position
	await run_ticks(60, false, false, Vector2.RIGHT)  # About 5 tiles at 60 ticks/s.
	assert_gt(_player.global_position.x, chaser_start.x + Units.tiles_to_px(1.0), "went past")
	assert_eq(_chasers[0].global_position, chaser_start, "and didn't push it")


func test_ac21_the_player_dashes_through_a_chaser() -> void:
	await spawn_fresh(_place_in_the_way)
	_runner.toggle_ai()
	var chaser_start: Vector2 = _chasers[0].global_position
	var player_start: Vector2 = _player.global_position
	await run_ticks(1, false, true, Vector2.RIGHT)
	await run_ticks(20)
	var dash_end: float = player_start.x + Units.tiles_to_px(3.0)
	assert_almost_eq(_player.global_position.x, dash_end, TILE_PX, "the full 3 tiles, past it")
	assert_gt(dash_end, chaser_start.x + RADIUS_PX)
	assert_eq(_chasers[0].global_position, chaser_start)


func test_ac21_three_converging_chasers_never_overlap() -> void:
	await spawn_fresh(_place_converging)
	_watch_bodies()
	await run_ticks(240)  # 4 s: they arrive, crowd and swing.
	assert_gt(_contacts, 400)
	assert_gte(_min_gap_px, MIN_GAP_PX, "closest centres: %.2f px" % _min_gap_px)
	assert_true(_positions_agree, "logic and body agree at every contact")
	for chaser: Enemy in _chasers:
		assert_true(chaser.logic.is_aggroed(), "%s joined in" % chaser.combat_id)


func test_ac21_a_chasing_chaser_stops_at_a_wall() -> void:
	await spawn_fresh(_place_behind_the_pillar)
	_watch_bodies()
	await run_ticks(120)
	var chaser: Enemy = _chasers[0]
	assert_eq(chaser.logic.get_state(), EnemyLogic.State.CHASE, "still trying")
	assert_almost_eq(chaser.global_position.y, PILLAR_TOP_PX - RADIUS_PX, 0.5, "at the pillar")
	assert_almost_eq(chaser.global_position.x, ABOVE_PILLAR.x, TILE_PX, "straight on, no slide")
	assert_true(_positions_agree)


func test_ac21_a_lunging_chaser_stops_at_a_wall() -> void:
	await spawn_fresh(_place_lunge_into_the_south_wall)
	_watch_bodies()
	var watch: EnemyWatch = _watch(_chasers[0].logic)
	await run_ticks(45)  # 0.75 s: windup 0.5, active 0.1 + hitstop, then recovery.
	_assert_steps(_since_start(watch.times_entered(EnemyLogic.State.ACTIVE)), [60], "on time")
	# The swing hits the player at its first contact: 0.05 s of hitstop pause the active.
	_assert_steps(_since_start(watch.times_entered(EnemyLogic.State.RECOVERY)), [78], "on time")
	assert_eq(_chasers[0].logic.get_state(), EnemyLogic.State.RECOVERY)
	var stopped: float = SOUTH_FACE_PX - RADIUS_PX
	assert_almost_eq(_chasers[0].global_position.y, stopped, 0.5, "the wall stops the lunge")
	assert_lt(stopped, NEAR_SOUTH_CHASER.y + Units.tiles_to_px(0.8), "short of a full lunge")
	assert_true(_positions_agree)


func _place_in_the_way() -> void:
	_player.position = CENTRE + Vector2(-32, 0)
	_chasers[0].position = CENTRE
	_chasers[1].position = FAR_WEST
	_chasers[2].position = FAR_EAST


## All three within aggro, from one side, close together so they crowd near the player.
func _place_converging() -> void:
	_player.position = CENTRE
	_chasers[0].position = CENTRE + Vector2(-64, 8)
	_chasers[1].position = CENTRE + Vector2(-60, -16)
	_chasers[2].position = CENTRE + Vector2(-56, 28)


func _place_behind_the_pillar() -> void:
	_player.position = BELOW_PILLAR
	_chasers[0].position = ABOVE_PILLAR
	_chasers[1].position = FAR_WEST
	_chasers[2].position = Vector2(456, 300)


func _place_lunge_into_the_south_wall() -> void:
	_player.position = NEAR_SOUTH_PLAYER
	_chasers[0].position = NEAR_SOUTH_CHASER
	_chasers[1].position = FAR_WEST
	_chasers[2].position = FAR_EAST


## Registered last, so it records what each enemy decided at every step start.
func _watch(logic: EnemyLogic) -> EnemyWatch:
	var watch: EnemyWatch = EnemyWatch.new(logic, _runner.get_sim())
	_runner.get_sim().register(watch)
	return watch


## A watch keys its contacts by step since the sim started: this is by step since the run did.
func _at(watch: EnemyWatch, step_index: int) -> Dictionary:
	return watch.at(step_index + roundi(_t0 * 120.0))


func _since_start(times: Array) -> Array:
	var shifted: Array = []
	for time: float in times:
		if time >= _t0:
			shifted.append(time - _t0)
	return shifted


## The resolver asks every combatant for its hitbox at each contact instant.
func _watch_bodies() -> void:
	var probe: SimProbe = SimProbe.new()
	probe.on_contact = _check_bodies
	_runner.get_sim().register(probe)


func _check_bodies() -> void:
	_contacts += 1
	for index: int in _chasers.size():
		var chaser: Enemy = _chasers[index]
		if chaser.logic.get_position_px() != chaser.global_position:
			_positions_agree = false
		for other: int in range(index + 1, _chasers.size()):
			var gap: float = chaser.global_position.distance_to(_chasers[other].global_position)
			_min_gap_px = minf(_min_gap_px, gap)


func _record_hurt() -> Array[float]:
	var times: Array[float] = []
	# Through self: capturing the sim would keep it alive forever.
	_player.motor.get_combat_state().damaged.connect(
		func(_event: HitEvent) -> void: times.append(run_time())
	)
	return times


func _assert_steps(actual: Array, expected_steps: Array, label: String) -> void:
	assert_eq(actual.size(), expected_steps.size(), "%s: %s" % [label, actual])
	for index: int in mini(actual.size(), expected_steps.size()):
		assert_almost_eq(float(actual[index]), expected_steps[index] / 120.0, TIME, label)
