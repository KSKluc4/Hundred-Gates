extends GutTest
## AC14, AC15, AC16 and C17's hit rules, on the motor alone. CombatSim calls apply_hit()
## at a contact instant, the tests here call it between ticks.

const Combat: GDScript = preload("res://tests/core/combat/combat_harness.gd")
const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const KNOCKBACK: PlayerMotor.State = PlayerMotor.State.KNOCKBACK
const TICK: float = 1.0 / 120.0


func test_ac15_a_hit_interrupts_any_attack_and_resets_the_chain() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 3, [0])
	assert_not_null(motor.get_live_hitbox())
	_hit(motor)
	assert_eq(Combat.phase(motor), AttackChain.Phase.NONE)
	assert_eq(motor.get_attack_chain().get_next_index(), 0)
	assert_null(motor.get_live_hitbox())
	assert_eq(motor.get_state(), KNOCKBACK)


func test_c17_a_hit_keeps_the_buffers() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 2, [0, 1], [1])
	_hit(motor)
	assert_true(motor.has_buffered_attack())
	assert_true(motor.has_buffered_dash())


func test_ac15_movement_is_ignored_during_knockback() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	_hit(motor, Vector2.DOWN, 1.2)
	_run_seconds(motor, 0.05, Vector2.RIGHT)  # Hitstop.
	_run_seconds(motor, 0.1, Vector2.RIGHT)  # Still inside: knockback ends at 0.12 of it.
	var position: Vector2 = Harness.position_tiles(motor)
	assert_almost_eq(position.y, 1.0, 0.01)
	assert_almost_eq(position.x, 0.0, 0.0001, "move input did nothing")
	assert_eq(motor.get_state(), KNOCKBACK)


func test_ac12_knockback_starts_after_hitstop_at_constant_speed_and_ends_on_time() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	_hit(motor, Vector2.DOWN, 1.2)
	_run_seconds(motor, 0.05)
	assert_eq(Harness.position_tiles(motor), Vector2.ZERO, "still in hitstop")
	_run_seconds(motor, 0.05)
	assert_almost_eq(Harness.position_tiles(motor).y, 1.2 * 0.05 / 0.12, 0.001)
	assert_eq(motor.get_state(), KNOCKBACK)
	_run_seconds(motor, 0.075)
	assert_almost_eq(Harness.position_tiles(motor).y, 1.2, 0.001)
	assert_ne(motor.get_state(), KNOCKBACK)
	assert_eq(Harness.velocity_tiles(motor), Vector2.ZERO)


func test_ac12_player_knockback_uses_its_own_scale() -> void:
	var data: ClassData = Harness.warrior()
	data.knockback_scale = 0.5
	assert_eq(Harness.motor_with(data).get_knockback_scale(), 0.5)


func test_c17_zero_knockback_skips_the_state_and_control_returns_after_hitstop() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 1, [0])
	_hit(motor, Vector2.DOWN, 0.0)
	assert_ne(motor.get_state(), KNOCKBACK)
	assert_eq(Combat.phase(motor), AttackChain.Phase.NONE, "the hit still interrupts")
	_run_seconds(motor, 0.05)
	assert_eq(Harness.position_tiles(motor), Vector2.ZERO)
	_run_seconds(motor, 0.05, Vector2.RIGHT)
	assert_gt(Harness.position_tiles(motor).x, 0.0)


func test_ac5_press_during_knockback_fires_as_hit_1_when_it_ends() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	_hit(motor)
	_run_seconds(motor, 0.1)
	_press(motor, true, false)
	_run_seconds(motor, 0.08)
	assert_eq(motor.get_state(), PlayerMotor.State.ATTACKING)
	assert_eq(Combat.hit_name(motor), &"sword_hit_1")


func test_ac27_both_buffered_at_the_end_of_knockback_the_dash_wins() -> void:
	for attack_first: bool in [true, false]:
		var motor: PlayerMotor = Harness.motor_with()
		var fires: Array[float] = Harness.record_fire_times(motor)
		_hit(motor)
		_run_seconds(motor, 0.1)
		_press(motor, attack_first, not attack_first)
		_press(motor, not attack_first, attack_first)
		_run_seconds(motor, 0.08)
		assert_eq(fires.size(), 1)
		assert_eq(motor.get_state(), PlayerMotor.State.DASHING)
		assert_false(motor.has_buffered_attack(), "discarded")


func test_ac27_cooldown_not_ready_at_the_end_of_knockback_the_attack_fires() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 6, [], [0])
	assert_gt(motor.get_cooldown_remaining(), 0.2)
	_hit(motor)
	_run_seconds(motor, 0.1)
	_press(motor, true, true)
	_run_seconds(motor, 0.08)
	assert_eq(motor.get_state(), PlayerMotor.State.ATTACKING)
	assert_true(motor.has_buffered_dash(), "stays buffered")


func test_ac27_tail_hit_ends_the_dash_and_starts_the_full_cooldown() -> void:
	var data: ClassData = Harness.warrior()
	var motor: PlayerMotor = Harness.motor_with(data)
	watch_signals(motor)
	_press(motor, false, true)
	_run_seconds(motor, 0.125, Vector2.RIGHT)
	assert_eq(motor.get_state(), PlayerMotor.State.DASHING)
	assert_false(motor.is_dash_protected(), "in the tail")
	assert_signal_not_emitted(motor, "dash_ended")
	_hit(motor)
	assert_signal_emitted(motor, "dash_ended")
	assert_eq(Harness.velocity_tiles(motor), Vector2.ZERO)
	assert_eq(motor.get_state(), KNOCKBACK)
	assert_eq(motor.get_cooldown_remaining(), data.dash_cooldown)


func test_c11_cooldown_counts_during_knockback() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 6, [], [0])
	var before: float = motor.get_cooldown_remaining()
	_hit(motor)
	_run_seconds(motor, 0.05)
	assert_eq(motor.get_cooldown_remaining(), before, "hitstop pauses it")
	_run_seconds(motor, 0.1)
	assert_almost_eq(motor.get_cooldown_remaining(), before - 0.1, Combat.TIME_TOLERANCE)


func test_ac14_hurt_iframes_start_on_the_hit_and_run_during_knockback() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	_hit(motor)
	var state: CombatState = motor.get_combat_state()
	assert_false(motor.can_be_hit())
	_run_seconds(motor, 0.05)
	assert_eq(state.get_hurt_iframes_remaining(), 0.6, "paused in hitstop")
	_run_seconds(motor, 0.1)
	assert_almost_eq(state.get_hurt_iframes_remaining(), 0.5, Combat.TIME_TOLERANCE)


func test_ac14_protected_up_to_the_last_step_before_t_plus_065() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	_hit(motor)
	for _i: int in 77:
		motor.tick(TICK)
	assert_false(motor.can_be_hit(), "77/120 is the last contact before 0.65")
	motor.tick(TICK)
	assert_true(motor.can_be_hit(), "78/120 = 0.65")


func test_c15_dash_protection_is_half_open_and_exact() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	_press(motor, false, true)  # The press tick is the first of the 13.
	for _i: int in 12:
		motor.tick(TICK)
	assert_true(motor.is_dash_protected(), "13/120 < 0.11")
	motor.tick(TICK)
	assert_false(motor.is_dash_protected(), "14/120 > 0.11")


func test_ac16_player_starts_at_max_hp_and_loses_hp_to_a_hit() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	assert_eq(motor.get_combat_state().get_hp(), 100)
	_hit(motor)
	assert_eq(motor.get_combat_state().get_hp(), 80)


func test_c18_reload_clamps_hp_keeps_knockback_and_hurt_iframes() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	_hit(motor)
	var state: CombatState = motor.get_combat_state()
	var before: float = state.get_knockback_time_left()
	var data: ClassData = Harness.warrior()
	data.max_hp = 50
	assert_true(motor.apply_data(data, Harness.rules()))
	assert_eq(state.get_hp(), 50)
	assert_eq(state.get_knockback_time_left(), before)
	assert_true(state.is_hurt_protected())


func _hit(motor: PlayerMotor, direction: Vector2 = Vector2.DOWN, knockback: float = 1.0) -> void:
	var event: HitEvent = HitEvent.new()
	event.attacker_id = &"dummy"
	event.target_id = motor.get_combat_id()
	event.damage = 20
	event.direction = direction
	event.knockback_tiles = knockback
	motor.apply_hit(event, Harness.rules())


func _press(motor: PlayerMotor, attack: bool, dash: bool) -> void:
	Combat.submit_tick(motor, Vector2.ZERO, Vector2.ZERO, attack, dash)
	motor.tick(TICK)


func _run_seconds(motor: PlayerMotor, seconds: float, move: Vector2 = Vector2.ZERO) -> void:
	for _i: int in roundi(seconds * 120.0):
		Combat.submit_tick(motor, move, Vector2.ZERO)
		motor.tick(TICK)
