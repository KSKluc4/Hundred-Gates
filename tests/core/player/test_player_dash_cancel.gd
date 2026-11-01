extends GutTest
## AC8 and the rest of C17's press table.

const Combat: GDScript = preload("res://tests/core/combat/combat_harness.gd")
const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const RECOVERY: AttackChain.Phase = AttackChain.Phase.RECOVERY


func test_ac8_ready_dash_cancels_recovery_and_resets_the_chain() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		var fires: Array[float] = Harness.record_fire_times(motor)
		Combat.play(motor, rate, 0, 7, [0], [6])
		assert_eq(fires.size(), 1)
		assert_almost_eq(fires[0], 0.2, Combat.TIME_TOLERANCE, "%d Hz" % rate)
		assert_eq(motor.get_state(), PlayerMotor.State.DASHING)
		assert_eq(motor.get_attack_chain().get_next_index(), 0)
		assert_eq(Combat.phase(motor), AttackChain.Phase.NONE)


func test_ac8_dash_waits_for_its_cooldown_then_cancels() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		var fires: Array[float] = Harness.record_fire_times(motor)
		# Dash to 0.15, cooldown to 0.5. Hit 1 at 0.2667: recovery from 0.4067 to 0.5867.
		Combat.play(motor, rate, 0, 14, [8], [0, 12])
		assert_eq(fires.size(), 1, "still cooling down at 14/30")
		assert_eq(Combat.phase(motor), RECOVERY, "the recovery keeps running")
		assert_true(motor.has_buffered_dash())
		Combat.play(motor, rate, 14, 16)
		assert_eq(fires.size(), 2)
		assert_almost_eq(fires[1], 0.5, Combat.TIME_TOLERANCE, "%d Hz" % rate)
		assert_eq(motor.get_attack_chain().get_next_index(), 0)


func test_ac8_dash_whose_cooldown_ends_too_late_is_dropped_and_changes_nothing() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		var fires: Array[float] = Harness.record_fire_times(motor)
		Combat.play(motor, rate, 0, 16, [8], [0, 10])
		assert_eq(fires.size(), 1, "%d Hz" % rate)
		assert_false(motor.has_buffered_dash())
		assert_eq(Combat.phase(motor), RECOVERY, "untouched")
		assert_eq(motor.get_attack_chain().get_next_index(), 1, "untouched")


func test_ac8_dash_in_windup_fires_at_the_first_instant_of_recovery() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		var fires: Array[float] = Harness.record_fire_times(motor)
		Combat.play(motor, rate, 0, 5, [0], [1])
		assert_eq(fires.size(), 1)
		assert_almost_eq(fires[0], 0.14, Combat.TIME_TOLERANCE, "%d Hz" % rate)


func test_c11_cooldown_keeps_counting_during_attacks() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 6, [], [0])
	var before: float = motor.get_cooldown_remaining()
	Combat.play(motor, 120, 6, 9, [6])
	assert_almost_eq(motor.get_cooldown_remaining(), before - 0.1, Combat.TIME_TOLERANCE)


func test_c17_finisher_recovery_can_be_cancelled_by_dash() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		var fires: Array[float] = Harness.record_fire_times(motor)
		Combat.play(motor, rate, 0, 23, [0, 6, 12], [22])
		assert_eq(fires.size(), 1, "%d Hz" % rate)
		assert_eq(motor.get_state(), PlayerMotor.State.DASHING)
		assert_eq(motor.get_attack_chain().get_next_index(), 0)


func test_ac27_both_buffered_at_recovery_the_dash_wins_and_the_attack_is_gone() -> void:
	for presses: Array in [[1, 2], [2, 1]]:
		for rate: int in Combat.RATES:
			var motor: PlayerMotor = Harness.motor_with()
			var fires: Array[float] = Harness.record_fire_times(motor)
			Combat.play(motor, rate, 0, 3, [0, presses[0]], [presses[1]])
			assert_true(motor.has_buffered_attack())
			assert_true(motor.has_buffered_dash())
			Combat.play(motor, rate, 3, 11)
			assert_eq(fires.size(), 1, "%d Hz" % rate)
			assert_false(motor.has_buffered_attack(), "discarded, not waiting for the dash end")
			assert_ne(motor.get_state(), PlayerMotor.State.ATTACKING)


func test_ac27_a_dash_on_cooldown_does_not_block_a_ready_attack() -> void:
	for rate: int in Combat.RATES:
		var tunables: PlayerCombatTunables = Harness.rules()
		tunables.input_buffer_window = 0.2
		var motor: PlayerMotor = Harness.motor_with(null, tunables)
		var fires: Array[float] = Harness.record_fire_times(motor)
		# Dash to 0.15, cooldown to 0.5. Hit 1 at 0.2: recovery from 0.34. Both pressed in
		# windup and active. The attack fires at 0.34, the dash stays buffered.
		Combat.play(motor, rate, 0, 11, [6, 9], [0, 9])
		assert_eq(Combat.hit_name(motor), &"sword_hit_2", "%d Hz" % rate)
		assert_true(motor.has_buffered_dash(), "stays buffered, aging as usual")
		assert_eq(fires.size(), 1)


func test_ac27_a_dash_fired_from_the_chain_window_resets_the_chain() -> void:
	for rate: int in Combat.RATES:
		var motor: PlayerMotor = Harness.motor_with()
		Combat.play(motor, rate, 0, 10, [0])
		assert_eq(motor.get_attack_chain().get_next_index(), 1, "the window is open")
		Combat.play(motor, rate, 10, 11, [], [10])
		assert_eq(motor.get_attack_chain().get_next_index(), 0, "%d Hz" % rate)
		assert_eq(motor.get_attack_chain().get_window_remaining(), 0.0)


func test_c5_round_trip_keeps_the_whole_attack() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 3, [0, 2], [2], Vector2.ZERO, Vector2.LEFT)
	var restored: PlayerMotor = Harness.motor_with()
	restored.from_dict(motor.to_dict())
	assert_eq_deep(restored.to_dict(), motor.to_dict())
	for tick_index: int in 60:
		Combat.submit_tick(motor, Vector2.ZERO, Vector2.ZERO, tick_index == 20)
		Combat.submit_tick(restored, Vector2.ZERO, Vector2.ZERO, tick_index == 20)
		motor.tick(1.0 / 120.0)
		restored.tick(1.0 / 120.0)
		assert_eq_deep(restored.to_dict(), motor.to_dict())
