extends F003SceneTest
## AC12 walls, AC22's physics run and AC29, over real physics frames.

const NEAR_EAST_WALL: Vector2 = Vector2(456, 160)
const BEYOND_EAST_WALL: Vector2 = Vector2(540, 160)
const OPEN_START: Vector2 = Vector2(100, 160)
const OPEN_FAR_DUMMY: Vector2 = Vector2(184, 160)
const NEAR_SOUTH_WALL: Vector2 = Vector2(240, 306)
const SOUTH_FACE_Y: float = 320.0

var _positions_agree: bool = true
var _contacts: int = 0


func test_ac22_the_whole_run_over_real_physics_at_every_rate() -> void:
	for rate: int in [30, 60, 120]:
		Engine.physics_ticks_per_second = rate
		await spawn(_place_for_ac22)
		var start_time: float = _runner.get_sim().get_time()
		var hits: Array[float] = []
		var dashes: Array[float] = []
		# Lambdas read the sim through self: capturing it would keep the motor alive forever.
		_player.motor.get_combat_state().hit_landed.connect(
			func(_event: HitEvent) -> void: hits.append(_runner.get_sim().get_time() - start_time)
		)
		_player.motor.dash_started.connect(
			func() -> void: dashes.append(_runner.get_sim().get_time() - start_time)
		)
		var moves: Dictionary = {24: Vector2.RIGHT, 42: Vector2.LEFT, 58: Vector2.RIGHT}
		for thirtieth: int in 66:
			await run_ticks(
				rate / 30,
				[0, 6, 12, 48].has(thirtieth),
				[24, 42, 58].has(thirtieth),
				moves.get(thirtieth, Vector2.ZERO)
			)
		var label: String = "%d ticks/s" % rate
		_assert_times(hits, [10.0 / 120.0, 34.0 / 120.0, 68.0 / 120.0, 202.0 / 120.0], label)
		_assert_times(dashes, [0.8, 1.4, 1.95], label)
		assert_eq(_anchored.logic.get_combat_state().get_hp(), 148, label)
		assert_almost_eq(_player.global_position.x, 240.0 + 48.0, TILE_PX, label)
		assert_almost_eq(_player.global_position.y, 160.0, TILE_PX, label)
		_scene.queue_free()


func test_ac29_a_wall_keeps_the_body_out_of_a_hitbox_the_motor_alone_would_reach() -> void:
	await spawn(_place_at.bind(NEAR_EAST_WALL, BEYOND_EAST_WALL))
	_watch_positions()
	_runner.toggle_pulse()
	await run_ticks(1, false, true, Vector2.RIGHT)
	await run_ticks(30)
	assert_eq(_player.motor.get_combat_state().get_hp(), 100, "no hit through the wall")
	assert_gt(_contacts, 30)
	assert_true(_positions_agree, "motor and body agree at every contact")


func test_ac29_control_with_no_wall_the_same_dash_is_hit() -> void:
	await spawn(_place_at.bind(OPEN_START, OPEN_FAR_DUMMY))
	_runner.toggle_pulse()
	await run_ticks(1, false, true, Vector2.RIGHT)
	await run_ticks(30)
	assert_eq(_player.motor.get_combat_state().get_hp(), 80, "this is what the wall prevented")


func test_ac29_a_knocked_back_body_against_a_wall_stays_authoritative() -> void:
	await spawn(_place_for_south_wall)
	_watch_positions()
	_runner.toggle_pulse()
	await run_ticks(40)
	assert_lte(_player.global_position.y, SOUTH_FACE_Y - 6.0)
	assert_eq(_player.motor.get_combat_state().get_hp(), 80)
	assert_true(_positions_agree)


func test_ac12_a_wall_stops_knockback_and_the_state_still_ends_on_time() -> void:
	await spawn(_place_for_south_wall)
	var hit_time: Array[float] = []
	var ended_time: Array[float] = []
	_player.motor.get_combat_state().damaged.connect(
		func(_event: HitEvent) -> void: hit_time.append(_runner.get_sim().get_time())
	)
	_runner.toggle_pulse()
	for _i: int in 40:
		await run_ticks(1)
		var in_knockback: bool = _player.motor.get_state() == PlayerMotor.State.KNOCKBACK
		if not hit_time.is_empty() and not in_knockback and ended_time.is_empty():
			ended_time.append(_runner.get_sim().get_time())
	assert_eq(hit_time.size(), 1)
	var expected: float = hit_time[0] + 0.05 + 0.12
	assert_lte(absf(ended_time[0] - expected), 2.0 / 60.0, "on time, wall or no wall")
	assert_almost_eq(_player.global_position.y, SOUTH_FACE_Y - 6.0, 0.2)


func _place_for_ac22() -> void:
	_player.position = Vector2(240, 160)
	_anchored.position = Vector2(240, 176)
	_loose.position = Vector2(40, 300)


func _place_at(player_position: Vector2, dummy_position: Vector2) -> void:
	_player.position = player_position
	_anchored.position = dummy_position
	_anchored.data = quick_pulse()
	_loose.position = Vector2(40, 40)


func _place_for_south_wall() -> void:
	_player.position = NEAR_SOUTH_WALL
	_anchored.position = NEAR_SOUTH_WALL + Vector2(0, -24)
	_anchored.data = quick_pulse(20, 1.0)
	_loose.position = Vector2(40, 40)


## The resolver asks every combatant for its hitbox at each contact instant.
func _watch_positions() -> void:
	var probe: SimProbe = SimProbe.new()
	probe.on_contact = _check_positions
	_runner.get_sim().register(probe)


func _check_positions() -> void:
	_contacts += 1
	if _player.motor.get_position_px() != _player.global_position:
		_positions_agree = false


func _assert_times(actual: Array[float], expected: Array, label: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s: %s" % [label, actual])
	for index: int in mini(actual.size(), expected.size()):
		assert_almost_eq(actual[index], float(expected[index]), TIME, label)
