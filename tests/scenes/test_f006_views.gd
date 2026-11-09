extends F006SceneTest
## F-006 AC17 (C12): the charge lane, the stomp's circle, the stun's tint and text, all derived
## from logic, and re-synced after a restore or a reset.

const LANE_PX: float = (6.0 + 0.9) * 16.0
const PILLAR: Rect2 = BruteScript.PILLAR


func before_each() -> void:
	super()
	Engine.physics_ticks_per_second = 120


func test_ac17_the_charge_lane_tracks_then_locks() -> void:
	await build([] as Array[Rect2], Vector2(5.0, 0), Vector2.ZERO)
	await run_ticks(30)  # 0.25 s: tracking.
	assert_eq(_brute.get_telegraph(), Enemy.Telegraph.TRACKING)
	_assert_lane()
	await run_ticks(20, false, false, Vector2.DOWN)  # The player walks: the lane follows.
	assert_eq(_brute.get_telegraph(), Enemy.Telegraph.TRACKING)
	assert_gt(_brute.logic.get_aim().y, 0.0, "turned toward the player")
	_assert_lane()
	await run_ticks(20)  # 0.58 s: past the 0.5 s lock.
	assert_eq(_brute.get_telegraph(), Enemy.Telegraph.LOCKED)
	var locked_aim: Vector2 = _brute.logic.get_aim()
	_assert_lane()
	await run_ticks(20, false, false, Vector2.UP)
	assert_eq(_brute.logic.get_aim(), locked_aim, "locked: the lane no longer moves")
	_assert_lane()
	await run_ticks(10)  # 0.83 s: active, the lane is gone.
	assert_eq(_brute.get_telegraph(), Enemy.Telegraph.ACTIVE)
	assert_eq(_brute.get_aim_line().size(), 0)


func test_ac17_the_stomp_shows_its_circle_and_no_lane() -> void:
	await build([] as Array[Rect2], Vector2(1.0, 0), Vector2.ZERO)
	await run_ticks(10)
	var stomp: EnemyAttackData = _brute.logic.get_running_attack()
	assert_eq(stomp.id, &"brute_stomp")
	assert_eq(_brute.get_telegraph(), Enemy.Telegraph.LOCKED, "aim_track_time 0 locks at once")
	assert_eq(stomp.arc_angle_deg, 360.0)
	assert_eq(_brute.get_aim_line().size(), 0, "no lunge, no lane")
	await wait_process_frames(1)  # It draws without error.
	await run_ticks(65)  # 0.63 s: active.
	assert_eq(_brute.get_telegraph(), Enemy.Telegraph.ACTIVE)


func test_ac17_the_stun_shows_the_open_tint_and_its_text() -> void:
	await build([PILLAR] as Array[Rect2], Vector2(5.5, 0), Vector2.ZERO)
	await run_ticks(BruteScript.STOP_STEP)
	assert_eq(_brute.get_body_color(), _brute.open_color)
	assert_string_starts_with(_brute.get_debug_text(), "RECOVERY (stun)\n")
	await wait_process_frames(1)
	assert_string_starts_with(_label().text, "RECOVERY (stun)\n")
	await run_to(2.6)
	assert_false(_brute.get_debug_text().contains("(stun)"))


func test_ac17_a_normal_recovery_has_no_stun_text() -> void:
	await build([] as Array[Rect2], Vector2(5.0, 0), Vector2.ZERO)
	await run_to(1.5)
	assert_eq(_brute.logic.get_state(), EnemyLogic.State.RECOVERY)
	assert_string_starts_with(_brute.get_debug_text(), "RECOVERY\n")


func test_ac17_views_resync_after_a_restore_and_a_reset() -> void:
	await build([PILLAR] as Array[Rect2], Vector2(5.5, 0), Vector2.ZERO)
	await run_ticks(30)
	var tracking: Dictionary = _runner.take_snapshot()
	await run_ticks(BruteScript.STOP_STEP - 30 + 10)
	var stunned: Dictionary = _runner.take_snapshot()
	await run_to(3.0)
	assert_false(_brute.get_debug_text().contains("(stun)"))
	assert_true(_runner.restore_snapshot(stunned))
	assert_string_starts_with(_label().text, "RECOVERY (stun)\n", "re-synced at once")
	assert_eq(_brute.get_body_color(), _brute.open_color)
	assert_eq(_brute.get_aim_line().size(), 0)
	assert_true(_runner.restore_snapshot(tracking))
	assert_eq(_brute.get_telegraph(), Enemy.Telegraph.TRACKING)
	_assert_lane()
	assert_string_starts_with(_label().text, "WINDUP\n")
	assert_true(_runner.restore_snapshot(stunned))
	_runner.reset()
	assert_string_starts_with(_label().text, "IDLE\n")
	assert_eq(_brute.get_body_color(), _brute.body_color)
	assert_eq(_brute.get_aim_line().size(), 0)


func _assert_lane() -> void:
	var line: PackedVector2Array = _brute.get_aim_line()
	assert_eq(line.size(), 2)
	if line.size() != 2:
		return
	assert_eq(line[0], _brute.logic.get_position_px(), "from the brute")
	assert_almost_eq(line[0].distance_to(line[1]), LANE_PX, 0.001, "lunge + range")
	var direction: Vector2 = (line[1] - line[0]).normalized()
	assert_almost_eq(direction.x, _brute.logic.get_aim().x, 0.0001, "along the aim")
	assert_almost_eq(direction.y, _brute.logic.get_aim().y, 0.0001, "along the aim")


func _label() -> Label:
	return _brute.get_node("DebugLabel")
