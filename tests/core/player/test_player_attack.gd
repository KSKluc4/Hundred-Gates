extends GutTest
## AC2-AC7: phases, locked aim, chaining, buffering, finisher, rooting. Hit 1 by default
## data: windup to 0.08, active to 0.14, recovery to 0.32, chain window to 0.39.

const Combat: GDScript = preload("res://tests/core/combat/combat_harness.gd")
const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const PHASE_NONE: AttackChain.Phase = AttackChain.Phase.NONE
const WINDUP: AttackChain.Phase = AttackChain.Phase.WINDUP
const ACTIVE: AttackChain.Phase = AttackChain.Phase.ACTIVE
const RECOVERY: AttackChain.Phase = AttackChain.Phase.RECOVERY


func test_ac2_phases_run_in_order_for_their_exact_durations() -> void:
	var expected: Array[Array] = [
		[2, WINDUP], [3, ACTIVE], [4, ACTIVE], [5, RECOVERY], [9, RECOVERY]
	]
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		var at: int = 0
		for sample: Array in expected:
			Combat.play(motor, rate, at, sample[0], [0])
			at = sample[0]
			assert_eq(Combat.phase(motor), sample[1], "%d Hz at %d/30" % [rate, at])
			assert_eq(motor.get_state(), PlayerMotor.State.ATTACKING)
		Combat.play(motor, rate, at, 10)
		assert_eq(Combat.phase(motor), PHASE_NONE, "%d Hz, recovery is over" % rate)
		assert_ne(motor.get_state(), PlayerMotor.State.ATTACKING)


func test_ac2_hitbox_exists_only_during_active() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	assert_null(motor.get_live_hitbox(), "before")
	Combat.play(motor, 120, 0, 2, [0])
	assert_null(motor.get_live_hitbox(), "windup")
	Combat.play(motor, 120, 2, 3)
	var hitbox: Hitbox = motor.get_live_hitbox()
	assert_not_null(hitbox, "active")
	assert_eq(hitbox.owner_id, PlayerMotor.DEFAULT_COMBAT_ID)
	assert_eq(hitbox.team, Combatant.Team.PLAYER)
	assert_eq(hitbox.damage, 10)
	assert_eq(hitbox.arc_angle_deg, 100.0)
	assert_almost_eq(hitbox.range_tiles, 1.4, 0.0001)
	Combat.play(motor, 120, 3, 5)
	assert_null(motor.get_live_hitbox(), "recovery")


func test_ac3_direction_is_locked_at_the_first_instant_of_windup() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		Combat.play(motor, rate, 0, 1, [0], [], Vector2.ZERO, Vector2.RIGHT)
		Combat.play(motor, rate, 1, 3, [], [], Vector2.ZERO, Vector2.UP)
		assert_eq(motor.get_facing(), Vector2.UP, "facing keeps updating")
		assert_eq(motor.get_live_hitbox().direction, Vector2.RIGHT, "%d Hz" % rate)


func test_ac4_attack_during_recovery_starts_the_next_hit_at_once() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		Combat.play(motor, rate, 0, 6, [0])
		assert_eq(Combat.phase(motor), RECOVERY)
		Combat.play(motor, rate, 6, 7, [6])
		assert_eq(Combat.hit_name(motor), &"sword_hit_2", "%d Hz" % rate)
		assert_eq(Combat.phase(motor), WINDUP)


func test_ac4_recovery_press_chains_even_with_a_shorter_window() -> void:
	var data: ClassData = Harness.warrior()
	data.attack_chain_window = 0.01
	var motor: PlayerMotor = Harness.motor_with(data)
	Combat.play(motor, 120, 0, 9, [0, 8])
	assert_eq(Combat.hit_name(motor), &"sword_hit_2", "0.2667 is past the window, not recovery")


func test_ac4_attack_after_recovery_inside_the_window_starts_the_next_hit() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		Combat.play(motor, rate, 0, 10, [0])
		assert_eq(Combat.phase(motor), PHASE_NONE, "0.3333 is after recovery")
		Combat.play(motor, rate, 10, 11, [10])
		assert_eq(Combat.hit_name(motor), &"sword_hit_2", "%d Hz" % rate)


func test_ac4_attack_after_the_window_starts_hit_1() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		Combat.play(motor, rate, 0, 12, [0])
		assert_eq(motor.get_attack_chain().get_next_index(), 0, "the window closed at 0.39")
		Combat.play(motor, rate, 12, 13, [12])
		assert_eq(Combat.hit_name(motor), &"sword_hit_1", "%d Hz" % rate)


func test_ac5_press_in_windup_fires_at_the_first_instant_of_recovery() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		Combat.play(motor, rate, 0, 2, [0, 1])
		assert_true(motor.has_buffered_attack())
		Combat.play(motor, rate, 2, 5)
		assert_false(motor.has_buffered_attack())
		assert_eq(Combat.hit_name(motor), &"sword_hit_2", "%d Hz" % rate)
		var elapsed: float = 5.0 / 30.0 - 0.14
		assert_almost_eq(
			motor.get_attack_chain().get_phase_time_left(),
			0.08 - elapsed,
			Combat.TIME_TOLERANCE,
			"hit 2 began at 0.14"
		)


func test_ac5_press_too_old_at_recovery_is_discarded() -> void:
	for rate: int in Combat.RATES:
		var tunables: PlayerCombatTunables = Harness.rules()
		tunables.input_buffer_window = 0.05
		var motor: PlayerMotor = Harness.motor_with(null, tunables)
		Combat.play(motor, rate, 0, 6, [0, 1])
		assert_false(motor.has_buffered_attack())
		assert_eq(Combat.hit_name(motor), &"sword_hit_1", "%d Hz" % rate)
		assert_eq(Combat.phase(motor), RECOVERY)


func test_ac5_press_during_a_dash_fires_as_hit_1_when_it_ends() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		Combat.play(motor, rate, 0, 3, [2], [0])
		assert_eq(motor.get_state(), PlayerMotor.State.DASHING)
		assert_true(motor.has_buffered_attack())
		Combat.play(motor, rate, 3, 5)
		assert_eq(motor.get_state(), PlayerMotor.State.ATTACKING, "%d Hz" % rate)
		assert_eq(Combat.hit_name(motor), &"sword_hit_1")


func test_ac5_newest_press_replaces_the_buffered_one() -> void:
	for rate: int in Combat.RATES:
		var tunables: PlayerCombatTunables = Harness.rules()
		tunables.input_buffer_window = 0.08
		var motor: PlayerMotor = Harness.motor_with(null, tunables)
		Combat.play(motor, rate, 0, 5, [0, 1, 3])
		assert_eq(Combat.hit_name(motor), &"sword_hit_2", "the 1/30 press alone would expire")


func test_ac6_finisher_uses_its_own_file() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	_reach_finisher_recovery(motor, 120)
	assert_eq(Combat.hit_name(motor), &"sword_hit_3")
	assert_true(motor.get_attack_chain().is_finisher())
	assert_almost_eq(
		motor.get_attack_chain().get_phase_time_left(), 0.96 - 22.0 / 30.0, Combat.TIME_TOLERANCE
	)


func test_ac6_attack_cannot_cancel_a_finisher_recovery() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		_reach_finisher_recovery(motor, rate)
		Combat.play(motor, rate, 22, 23, [22])
		assert_eq(Combat.phase(motor), RECOVERY, "%d Hz" % rate)
		assert_eq(Combat.hit_name(motor), &"sword_hit_3")


func test_ac6_press_in_finisher_recovery_starts_hit_1_once_it_ends() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		_reach_finisher_recovery(motor, rate)
		Combat.play(motor, rate, 22, 29, [26])
		assert_eq(Combat.hit_name(motor), &"sword_hit_1", "%d Hz" % rate)
		assert_eq(Combat.phase(motor), WINDUP)


func test_ac6_hit_after_a_finisher_is_hit_1_even_inside_its_window() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	_reach_finisher_recovery(motor, 120)
	Combat.play(motor, 120, 22, 30)
	assert_eq(Combat.phase(motor), PHASE_NONE)
	Combat.play(motor, 120, 30, 31, [30])
	assert_eq(Combat.hit_name(motor), &"sword_hit_1")


func test_ac7_rooted_while_attacking_and_free_again_inside_the_window() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		Combat.play(motor, rate, 0, 1, [0], [], Vector2.RIGHT)
		var at_start: Vector2 = Harness.position_tiles(motor)
		Combat.play(motor, rate, 1, 9, [], [], Vector2.RIGHT)
		assert_eq(Harness.velocity_tiles(motor), Vector2.ZERO, "%d Hz" % rate)
		assert_almost_eq(Harness.position_tiles(motor).x, at_start.x, 0.0001, "ignored")
		Combat.play(motor, rate, 9, 11, [], [], Vector2.RIGHT)
		assert_gt(Harness.velocity_tiles(motor).x, 0.0, "moving, still inside the window")
		assert_eq(motor.get_attack_chain().get_next_index(), 1)


func test_ac7_velocity_decelerates_with_move_decel_time() -> void:
	var data: ClassData = Harness.warrior()
	data.move_decel_time = 0.4
	var motor: PlayerMotor = Harness.motor_with(data)
	Harness.run(motor, 120, 0.3, Vector2.RIGHT)
	var speed: float = Harness.velocity_tiles(motor).x
	Combat.play(motor, 120, 0, 3, [0])
	assert_almost_eq(Harness.velocity_tiles(motor).x, speed - 5.0 * 0.1 / 0.4, 0.001)


func test_c18_a_running_hit_keeps_its_latched_values() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 1, [0])
	var data: ClassData = Harness.warrior()
	var chain: Array[AttackData] = []
	for hit: AttackData in data.attack_chain:
		var slow: AttackData = hit.duplicate()
		slow.windup = 1.0
		slow.damage = 99
		chain.append(slow)
	data.attack_chain = chain
	assert_true(motor.apply_data(data, Harness.rules()))
	Combat.play(motor, 120, 1, 3)
	assert_eq(motor.get_live_hitbox().damage, 10, "the hit in progress finishes unchanged")
	Combat.play(motor, 120, 3, 6, [5])
	assert_eq(Combat.phase(motor), WINDUP)
	assert_gt(motor.get_attack_chain().get_phase_time_left(), 0.5, "the next hit reads new data")


func _reach_finisher_recovery(motor: PlayerMotor, rate: int) -> void:
	Combat.play(motor, rate, 0, 22, [0, 6, 12])
