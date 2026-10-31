extends GutTest
## AC13 frame-rate independence, AC14 serialization, AC15 independence.

const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const SECONDS: float = 2.2
const PRESS_EVERY_TICKS_AT_30: int = 3
const TOTAL_TICKS_AT_30: int = 66
const FIRE_TOLERANCE: float = 0.000001
const POSITION_TOLERANCE: float = 0.2


func test_ac13_default_data_fires_on_schedule_at_every_rate() -> void:
	var data: ClassData = Harness.warrior()
	var expected: Array[float] = [0.0, 0.5, 1.0, 1.5, 2.0]
	_assert_rate_independent(data, Harness.rules(), expected)


func test_ac13_pr8_data_fires_on_schedule_at_every_rate() -> void:
	var data: ClassData = Harness.warrior()
	data.dash_duration = 0.141
	data.dash_cooldown = 0.329
	var tunables: PlayerCombatTunables = Harness.rules()
	tunables.input_buffer_window = 0.12
	var expected: Array[float] = [0.0, 0.47, 0.94, 1.41, 1.88]
	_assert_rate_independent(data, tunables, expected)


func test_ac14_mid_dash_snapshot_continues_identically() -> void:
	_assert_snapshot_continues([0.0], 6.0 / 120.0)


func test_ac14_tail_snapshot_continues_identically() -> void:
	_assert_snapshot_continues([0.0], 15.0 / 120.0)


func test_ac14_mid_cooldown_snapshot_continues_identically() -> void:
	_assert_snapshot_continues([0.0], 0.3)


func test_ac14_buffered_dash_snapshot_continues_identically() -> void:
	_assert_snapshot_continues([0.0, 0.4], 0.45)


func test_ac14_round_trip_loses_nothing() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Harness.run_with_presses(motor, 120, 0.05, [0.0] as Array[float], Vector2.RIGHT)
	var restored: PlayerMotor = Harness.motor_with()
	restored.from_dict(motor.to_dict())
	assert_eq_deep(restored.to_dict(), motor.to_dict())
	assert_eq(restored.is_invulnerable(), motor.is_invulnerable())
	assert_eq(restored.get_iframe_window(), motor.get_iframe_window())
	assert_eq(restored.get_state(), motor.get_state())


func test_ac14_incomplete_snapshot_is_refused() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	var before: Dictionary = motor.to_dict()
	motor.from_dict({"time": 9.0})
	assert_push_error("snapshot rejected")
	assert_eq_deep(motor.to_dict(), before)


func test_ac15_two_motors_do_not_affect_each_other() -> void:
	var first: PlayerMotor = Harness.motor_with()
	var second: PlayerMotor = Harness.motor_with()
	var alone: PlayerMotor = Harness.motor_with()
	for index: int in 60:
		Harness.step(first, 60, Vector2.RIGHT, Vector2.UP, index == 5)
		Harness.step(second, 60, Vector2.LEFT, Vector2.DOWN, index % 20 == 0)
		Harness.step(alone, 60, Vector2.RIGHT, Vector2.UP, index == 5)
	assert_eq_deep(first.to_dict(), alone.to_dict())
	assert_ne(first.get_position_px(), second.get_position_px())


func _assert_rate_independent(
	data: ClassData, tunables: PlayerCombatTunables, expected_fires: Array[float]
) -> void:
	var final_positions: Array[Vector2] = []
	for rate: int in Harness.RATES:
		var motor: PlayerMotor = Harness.motor_with(data, tunables)
		var fires: Array[float] = Harness.record_fire_times(motor)
		var windows: Array[PackedFloat64Array] = Harness.record_windows(motor)
		_run_scripted_sequence(motor, rate)
		assert_eq(fires.size(), expected_fires.size(), "%d Hz fire count" % rate)
		for index: int in mini(fires.size(), expected_fires.size()):
			var fire_label: String = "%d Hz dash %d" % [rate, index]
			assert_almost_eq(fires[index], expected_fires[index], FIRE_TOLERANCE, fire_label)
			var window_end: float = expected_fires[index] + data.dash_iframe_duration
			assert_almost_eq(windows[index][1], window_end, FIRE_TOLERANCE, fire_label)
		final_positions.append(Harness.position_tiles(motor))
	for position: Vector2 in final_positions:
		assert_almost_eq(position.x, final_positions[0].x, POSITION_TOLERANCE)
		assert_almost_eq(position.y, final_positions[0].y, POSITION_TOLERANCE)


## Mixed moves and aims. Inputs change only at 1/30 s multiples, dash presses every 0.1 s.
func _run_scripted_sequence(motor: PlayerMotor, rate: int) -> void:
	var ticks_per_30th: int = rate / 30
	for tick_index: int in TOTAL_TICKS_AT_30 * ticks_per_30th:
		var thirtieth: int = tick_index / ticks_per_30th
		var is_press: bool = (
			tick_index % ticks_per_30th == 0 and thirtieth % PRESS_EVERY_TICKS_AT_30 == 0
		)
		Harness.step(motor, rate, _move_at(thirtieth), _aim_at(thirtieth), is_press)


func _move_at(thirtieth: int) -> Vector2:
	if thirtieth < 9:
		return Vector2.RIGHT
	if thirtieth < 21:
		return Vector2(1, -1).normalized()
	if thirtieth < 36:
		return Vector2.ZERO
	if thirtieth < 51:
		return Vector2.DOWN * 0.5
	return Vector2.LEFT


func _aim_at(thirtieth: int) -> Vector2:
	return (
		Vector2.RIGHT.rotated(thirtieth / 12 * TAU / 8.0) if thirtieth % 24 < 12 else Vector2.ZERO
	)


func _assert_snapshot_continues(presses: Array, seconds: float) -> void:
	var typed_presses: Array[float] = []
	typed_presses.assign(presses)
	var original: PlayerMotor = Harness.motor_with()
	Harness.run_with_presses(original, 120, seconds, typed_presses, Vector2.RIGHT)
	var restored: PlayerMotor = Harness.motor_with()
	restored.from_dict(original.to_dict())
	for index: int in 30:
		var move: Vector2 = Vector2.UP if index > 12 else Vector2.RIGHT
		var press: bool = index == 20
		Harness.step(original, 120, move, Vector2.LEFT, press)
		Harness.step(restored, 120, move, Vector2.LEFT, press)
		assert_eq_deep(restored.to_dict(), original.to_dict())
