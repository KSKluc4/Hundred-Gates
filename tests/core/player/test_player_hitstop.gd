extends GutTest
## C7: hitstop freezes one entity's clock and all its timers, and nothing else.

const Combat: GDScript = preload("res://tests/core/combat/combat_harness.gd")
const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const TICK: float = 1.0 / 120.0
const SIX_TICKS: int = 6


func test_c7_attack_phase_pauses() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 3, [0])
	var left: float = motor.get_attack_chain().get_phase_time_left()
	_stop(motor)
	_ticks(motor, SIX_TICKS)
	assert_eq(motor.get_attack_chain().get_phase_time_left(), left)


func test_c7_chain_window_pauses() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 10, [0])
	var left: float = motor.get_attack_chain().get_window_remaining()
	_stop(motor)
	_ticks(motor, SIX_TICKS)
	assert_eq(motor.get_attack_chain().get_window_remaining(), left)


func test_c7_dash_pauses_with_no_displacement() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 1, [], [0], Vector2.RIGHT)
	var position: Vector2 = Harness.position_tiles(motor)
	_stop(motor)
	_ticks(motor, SIX_TICKS)
	assert_eq(Harness.position_tiles(motor), position)
	assert_eq(motor.get_state(), PlayerMotor.State.DASHING)


func test_c7_cooldown_and_clock_pause() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 6, [], [0])
	var before: Dictionary = motor.to_dict()
	_stop(motor)
	_ticks(motor, SIX_TICKS)
	assert_eq(motor.get_cooldown_remaining(), before["cooldown_remaining"])
	assert_eq(motor.to_dict()["time"], before["time"])


func test_c7_buffer_ages_pause() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 2, [0, 1], [1])
	var before: Dictionary = motor.to_dict()
	_stop(motor)
	_ticks(motor, SIX_TICKS)
	assert_eq(motor.to_dict()["buffered_attack_age"], before["buffered_attack_age"])
	assert_eq(motor.to_dict()["buffered_dash_age"], before["buffered_dash_age"])


func test_c7_velocity_stays_frozen_and_the_decel_carries_on_afterwards() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Harness.run(motor, 120, 0.3, Vector2.RIGHT)
	var position: Vector2 = Harness.position_tiles(motor)
	_stop(motor)
	_ticks(motor, SIX_TICKS)
	assert_eq(Harness.velocity_tiles(motor).x, 5.0, "frozen")
	assert_eq(Harness.position_tiles(motor), position)
	_ticks(motor, 1)
	assert_lt(Harness.velocity_tiles(motor).x, 5.0, "decelerating again")


func test_c7_facing_still_updates() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	_stop(motor)
	Combat.submit_tick(motor, Vector2.ZERO, Vector2.LEFT)
	motor.tick(TICK)
	assert_eq(motor.get_facing(), Vector2.LEFT)


func test_c7_a_press_during_hitstop_fires_when_it_ends() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	var tight: PlayerCombatTunables = Harness.rules()
	tight.input_buffer_window = 0.0
	motor.apply_data(Harness.warrior(), tight)
	_stop(motor)
	Combat.submit_tick(motor, Vector2.ZERO, Vector2.ZERO, true)
	motor.tick(TICK)
	assert_true(motor.has_buffered_attack(), "stored, age paused, even with a window of 0")
	_ticks(motor, SIX_TICKS - 1)
	assert_true(motor.has_buffered_attack(), "the end of hitstop lands on the end of this tick")
	_ticks(motor, 1)
	assert_eq(motor.get_state(), PlayerMotor.State.ATTACKING)


func test_c15_overshoot_is_carried_when_hitstop_ends_mid_step() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	var rules: PlayerCombatTunables = Harness.rules()
	rules.hitstop_normal = 0.055
	motor.apply_data(Harness.warrior(), rules)
	Combat.play(motor, 120, 0, 3, [0])
	var left: float = motor.get_attack_chain().get_phase_time_left()
	motor.get_combat_state().apply_landed(_event(), rules)
	_ticks(motor, 7)
	assert_almost_eq(
		motor.get_attack_chain().get_phase_time_left(),
		left - (7.0 * TICK - 0.055),
		Combat.TIME_TOLERANCE
	)


func test_ac13_no_live_hitbox_during_hitstop() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Combat.play(motor, 120, 0, 3, [0])
	assert_not_null(motor.get_live_hitbox())
	_stop(motor)
	assert_null(motor.get_live_hitbox())
	_ticks(motor, SIX_TICKS)
	assert_not_null(motor.get_live_hitbox(), "live again, the active time was not used up")


func test_c7_one_motor_in_hitstop_leaves_another_alone() -> void:
	var stopped: PlayerMotor = Harness.motor_with()
	var other: PlayerMotor = Harness.motor_with()
	_stop(stopped)
	for _i: int in SIX_TICKS:
		Combat.submit_tick(stopped, Vector2.RIGHT, Vector2.ZERO)
		Combat.submit_tick(other, Vector2.RIGHT, Vector2.ZERO)
		stopped.tick(TICK)
		other.tick(TICK)
	assert_eq(Harness.position_tiles(stopped), Vector2.ZERO)
	assert_gt(Harness.position_tiles(other).x, 0.0)


func _stop(motor: PlayerMotor) -> void:
	motor.get_combat_state().apply_landed(_event(), Harness.rules())


func _ticks(motor: PlayerMotor, count: int) -> void:
	for _i: int in count:
		motor.tick(TICK)


func _event() -> HitEvent:
	var event: HitEvent = HitEvent.new()
	event.attacker_id = PlayerMotor.DEFAULT_COMBAT_ID
	event.target_id = &"dummy"
	event.damage = 10
	event.direction = Vector2.DOWN
	return event
