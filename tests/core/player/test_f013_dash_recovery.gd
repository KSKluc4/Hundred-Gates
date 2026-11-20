# gdlint:disable=max-public-methods
extends GutTest
## F-013 T7 (AC17-AC26): the dash recovery, on the motor alone. The shipped Warrior has a recovery
## of 0.12 s after a 0.15 s dash. The shared harness zeroes it (F-013/C16), so every motor here is
## built from a fresh copy of warrior.tres. Presses and samples fall on multiples of 1/30 s, which
## every tested tick rate hits exactly.

const Combat: GDScript = preload("res://tests/core/combat/combat_harness.gd")
const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const RATES: Array[int] = [30, 60, 120]
const WIDE_RATES: Array[int] = [30, 60, 120, 240]
const NEAR: float = 0.000001
const THIRTIETH: float = 1.0 / 30.0
## The shipped Warrior: the dash ends at 0.15 s and the recovery at 0.27 s.
const DASH_END: float = 0.15
const RECOVERY_END: float = 0.27
const NEVER: float = -1.0
const RECOVERY: PlayerMotor.State = PlayerMotor.State.DASH_RECOVERY

var _fire_times: Array[float] = []
var _attack_starts: Array[float] = []
var _windup: float = 0.0


func before_each() -> void:
	_fire_times = []
	_attack_starts = []
	_windup = _shipped().attack_chain[0].windup


# --- builders ---


## A fresh copy of the shipped file: recovery included, which the harness' copy does not have.
func _shipped() -> ClassData:
	return (Tunables.load_fresh(Tunables.WARRIOR_PATH) as ClassData).duplicate()


## The shipped Warrior with these dash values (the dash and the recovery, in seconds).
func _data(
	dash_duration: float = 0.15,
	recovery: float = 0.12,
	cooldown: float = 0.35,
	iframes: float = 0.11
) -> ClassData:
	var data: ClassData = _shipped()
	data.dash_duration = dash_duration
	data.dash_recovery_duration = recovery
	data.dash_cooldown = cooldown
	data.dash_iframe_duration = iframes
	return data


func _motor(data: ClassData = null, window: float = -1.0) -> PlayerMotor:
	var tunables: PlayerCombatTunables = Harness.rules()
	if window >= 0.0:
		tunables.input_buffer_window = window
	var motor: PlayerMotor = Harness.motor_with(data if data != null else _shipped(), tunables)
	_fire_times = Harness.record_fire_times(motor)
	return motor


func _hit(motor: PlayerMotor, knockback: float = 1.0) -> void:
	var event: HitEvent = HitEvent.new()
	event.attacker_id = &"dummy"
	event.target_id = motor.get_combat_id()
	event.damage = 20
	event.direction = Vector2.DOWN
	event.knockback_tiles = knockback
	motor.apply_hit(event, Harness.rules())


## Ticks at `rate` for `seconds`. Presses fall at the given times (multiples of 1/30 s). `move`
## is held, or `move_at` (end time of the last tick -> Vector2) decides it tick by tick. `probe`
## is called after every tick with the time that tick ended at.
func _play(
	motor: PlayerMotor,
	rate: int,
	seconds: float,
	dashes: Array = [],
	attacks: Array = [],
	move: Vector2 = Vector2.ZERO,
	probe: Callable = Callable(),
	move_at: Callable = Callable()
) -> void:
	var start_tick: int = roundi(_time_of(motor) * rate)
	for index: int in Harness.ticks_for(rate, seconds):
		var tick: int = start_tick + index
		var now: float = float(tick) / rate
		var held: Vector2 = move_at.call(now) if move_at.is_valid() else move
		var is_dash: bool = dashes.any(
			func(time: float) -> bool: return roundi(time * rate) == tick
		)
		var is_attack: bool = attacks.any(
			func(time: float) -> bool: return roundi(time * rate) == tick
		)
		Combat.submit_tick(motor, held, Vector2.ZERO, is_attack, is_dash)
		motor.tick(1.0 / rate)
		_note_attack_start(motor)
		if probe.is_valid():
			probe.call(float(tick + 1) / rate)


func _time_of(motor: PlayerMotor) -> float:
	return motor.to_dict()["time"]


## The motor-clock time an attack started at, worked out the first tick it is seen in its windup.
func _note_attack_start(motor: PlayerMotor) -> void:
	var chain: AttackChain = motor.get_attack_chain()
	if not _attack_starts.is_empty():
		return
	if (
		motor.get_state() == PlayerMotor.State.ATTACKING
		and chain.get_phase() == AttackChain.Phase.WINDUP
	):
		_attack_starts.append(_time_of(motor) - (_windup - chain.get_phase_time_left()))


func _x(motor: PlayerMotor) -> float:
	return Harness.position_tiles(motor).x


func _label(rate: int) -> String:
	return "%d ticks/s" % rate


func _assert_times(actual: Array[float], expected: Array[float], label: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s: %s against %s" % [label, actual, expected])
	if actual.size() != expected.size():
		return
	for index: int in actual.size():
		assert_almost_eq(actual[index], expected[index], NEAR, "%s: time %d" % [label, index])


# --- the state and the data ---


func test_c13_the_new_state_is_appended_after_knockback() -> void:
	assert_eq(PlayerMotor.State.IDLE, 0)
	assert_eq(PlayerMotor.State.MOVING, 1)
	assert_eq(PlayerMotor.State.DASHING, 2)
	assert_eq(PlayerMotor.State.ATTACKING, 3)
	assert_eq(PlayerMotor.State.KNOCKBACK, 4)
	assert_eq(PlayerMotor.State.DASH_RECOVERY, 5)


func test_c12_the_shipped_warrior_recovers_for_0_12_s_and_a_new_class_data_for_none() -> void:
	assert_almost_eq(_shipped().dash_recovery_duration, 0.12, NEAR)
	assert_eq(ClassData.new().dash_recovery_duration, 0.0)


# --- AC17: after a full dash the state is DASH_RECOVERY and the player stands still ---


func test_ac17_the_state_reads_dash_recovery_when_dash_ended_is_emitted() -> void:
	for rate: int in WIDE_RATES:
		var motor: PlayerMotor = _motor()
		var seen: Array[int] = []
		var motor_ref: WeakRef = weakref(motor)
		motor.dash_ended.connect(
			func() -> void: seen.append((motor_ref.get_ref() as PlayerMotor).get_state())
		)
		_play(motor, rate, 0.5, [0.0], [], Vector2.RIGHT)
		assert_eq(seen, [int(RECOVERY)] as Array[int], _label(rate))


func test_ac17_the_state_is_dash_recovery_from_the_dash_end_until_0_12_s_later() -> void:
	for rate: int in WIDE_RATES:
		var states: Dictionary = {}
		var motor: PlayerMotor = _motor()
		var probe: Callable = func(now: float) -> void: states[now] = motor.get_state()
		_play(motor, rate, 0.5, [0.0], [], Vector2.RIGHT, probe)
		for now: float in states:
			var inside: bool = now > DASH_END + 0.001 and now < RECOVERY_END - 0.001
			if inside:
				assert_eq(states[now], RECOVERY, "%s at %.4f" % [_label(rate), now])
			if now > RECOVERY_END + 0.001:
				assert_ne(states[now], RECOVERY, "%s at %.4f" % [_label(rate), now])
		assert_ne(motor.get_state(), RECOVERY, "over by 0.5 s")


func test_ac17_the_position_does_not_change_for_the_recovery_whatever_the_movement_input() -> void:
	var around: Array[Vector2] = [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]
	for rate: int in WIDE_RATES:
		var motor: PlayerMotor = _motor()
		var checked: Array[int] = [0]
		var probe: Callable = func(now: float) -> void:
			if now > DASH_END + 0.001 and now < RECOVERY_END - 0.001:
				checked[0] += 1
				var place: Vector2 = Harness.position_tiles(motor)
				assert_almost_eq(place.x, 3.0, NEAR, "%s at %.4f" % [_label(rate), now])
				assert_almost_eq(place.y, 0.0, NEAR, "%s at %.4f" % [_label(rate), now])
				assert_eq(Harness.velocity_tiles(motor), Vector2.ZERO, "no velocity")
		var held: Callable = func(now: float) -> Vector2:
			return Vector2.RIGHT if now < DASH_END else around[int(now * rate) % 4]
		_play(motor, rate, 0.5, [0.0], [], Vector2.ZERO, probe, held)
		assert_gt(checked[0], 0, "%s: the recovery was sampled" % _label(rate))


func test_ac17_walking_starts_when_the_recovery_ends() -> void:
	for rate: int in WIDE_RATES:
		var motor: PlayerMotor = _motor()
		_play(motor, rate, 0.5, [0.0], [], Vector2.RIGHT)
		assert_gt(_x(motor), 3.5, "%s: walking again" % _label(rate))
		assert_almost_eq(
			_x(motor), 4.025, 0.0001, "%s: 3 + a 0.05 s ramp + the cruise" % _label(rate)
		)


func test_ac17_the_recovery_follows_only_a_dash_that_ran_its_full_length() -> void:
	var motor: PlayerMotor = _motor()
	_play(motor, 120, 0.1, [0.0])
	assert_eq(motor.get_state(), PlayerMotor.State.DASHING, "still dashing")
	_play(motor, 120, 0.1)
	assert_eq(motor.get_state(), RECOVERY)


# --- AC18: what fires when the recovery ends ---


func test_ac18_an_attack_pressed_during_recovery_starts_when_it_ends_and_not_before() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor()
		_play(motor, rate, 0.4, [0.0], [0.2])
		_assert_times(_attack_starts, [RECOVERY_END] as Array[float], _label(rate))


func test_ac18_an_attack_pressed_during_the_dash_inside_the_window_starts_when_recovery_ends(
) -> void:
	for press: float in [THIRTIETH, 2.0 * THIRTIETH, 3.0 * THIRTIETH]:
		for rate: int in RATES:
			_attack_starts = []
			var motor: PlayerMotor = _motor()
			_play(motor, rate, 0.4, [0.0], [press])
			_assert_times(
				_attack_starts,
				[RECOVERY_END] as Array[float],
				"%s, press %.4f" % [_label(rate), press]
			)


func test_ac18_an_attack_pressed_earlier_than_the_window_before_the_dash_end_never_starts() -> void:
	for rate: int in RATES:
		# The dash runs 0.30 s: a press at 0.10 s is 0.20 s old at its end, older than 0.12 s.
		var motor: PlayerMotor = _motor(_data(0.30))
		_play(motor, rate, 1.0, [0.0], [0.1])
		assert_eq(_attack_starts, [] as Array[float], _label(rate))
		assert_false(motor.has_buffered_attack(), "dropped")


func test_ac18_a_press_in_the_dash_still_inside_the_window_starts_at_the_recovery_end() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor(_data(0.30))
		_play(motor, rate, 1.0, [0.0], [7.0 * THIRTIETH])
		_assert_times(_attack_starts, [0.30 + 0.12] as Array[float], _label(rate))


func test_ac18_the_window_edge_is_inclusive_across_the_recovery() -> void:
	for rate: int in RATES:
		# A press 0.10 s before the dash end, with a window of 0.10 s: the age stays 0.10 s.
		var motor: PlayerMotor = _motor(_data(0.30), 0.1)
		_play(motor, rate, 1.0, [0.0], [6.0 * THIRTIETH])
		_assert_times(_attack_starts, [0.42] as Array[float], "at the edge, %s" % _label(rate))
		_attack_starts = []
		var short: PlayerMotor = _motor(_data(0.30), 0.0999)
		_play(short, rate, 1.0, [0.0], [6.0 * THIRTIETH])
		assert_eq(_attack_starts, [] as Array[float], "just past it, %s" % _label(rate))


func test_ac18_a_dash_pressed_in_recovery_fires_at_its_end_with_a_short_cooldown() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor(_data(0.15, 0.12, 0.05))
		_play(motor, rate, 0.6, [0.0, 0.2])
		_assert_times(_fire_times, [0.0, RECOVERY_END] as Array[float], _label(rate))


func test_ac18_a_dash_pressed_in_recovery_fires_when_the_cooldown_ends_if_that_is_later() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor(_data(0.15, 0.12, 0.20))
		_play(motor, rate, 0.8, [0.0, 0.2])
		_assert_times(_fire_times, [0.0, 0.35] as Array[float], _label(rate))


func test_ac18_with_the_shipped_cooldown_a_dash_pressed_in_recovery_never_fires() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor()
		_play(motor, rate, 1.0, [0.0, 0.2])
		_assert_times(_fire_times, [0.0] as Array[float], _label(rate))
		assert_false(motor.has_buffered_dash(), "and the press is gone")


func test_ac18_when_both_can_fire_at_the_recovery_end_the_dash_wins_and_the_attack_is_dropped(
) -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor(_data(0.15, 0.12, 0.0))
		_play(motor, rate, 0.6, [0.0, 0.2], [0.1])
		_assert_times(_fire_times, [0.0, RECOVERY_END] as Array[float], _label(rate))
		assert_eq(_attack_starts, [] as Array[float], "no attack: %s" % _label(rate))


func test_ac18_a_dash_that_cannot_fire_yet_does_not_block_an_attack_that_can() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor()
		_play(motor, rate, 0.6, [0.0, 0.2], [0.1])
		_assert_times(_attack_starts, [RECOVERY_END] as Array[float], _label(rate))
		_assert_times(_fire_times, [0.0] as Array[float], _label(rate))


# --- C13 (c): the buffers do not age in the recovery, but do in the dash's last segment ---


func test_c13_the_buffer_ages_stop_for_the_recovery_and_include_the_dash_end() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor(_data(0.15, 0.12, 0.35), 5.0)
		var ages: Dictionary = {}
		var probe: Callable = func(now: float) -> void:
			ages[now] = [
				motor.to_dict()["buffered_attack_age"], motor.to_dict()["buffered_dash_age"]
			]
		_play(motor, rate, 0.26, [0.0, 0.2], [THIRTIETH], Vector2.ZERO, probe)
		var attack_age_at_dash_end: float = DASH_END - THIRTIETH
		for now: float in ages:
			if now > DASH_END + 0.001:
				assert_almost_eq(ages[now][0], attack_age_at_dash_end, NEAR, "attack, %.4f" % now)
				if now > 0.2:
					assert_almost_eq(ages[now][1], 0.0, NEAR, "dash, %.4f" % now)


func test_c13_a_dash_pressed_in_the_dash_keeps_its_age_through_the_recovery() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor(_data(0.15, 0.12, 0.0), 5.0)
		var ages: Dictionary = {}
		var probe: Callable = func(now: float) -> void:
			ages[now] = motor.to_dict()["buffered_dash_age"]
		_play(motor, rate, 0.26, [0.0, THIRTIETH], [], Vector2.ZERO, probe)
		for now: float in ages:
			if now > DASH_END + 0.001:
				assert_almost_eq(
					ages[now], DASH_END - THIRTIETH, NEAR, "%s at %.4f" % [_label(rate), now]
				)


func test_c13_a_dash_its_recovery_and_the_next_action_can_all_fall_inside_one_step() -> void:
	var fine: PlayerMotor = _motor()
	_play(fine, 120, 0.0 + 64.0 / 120.0, [0.0], [THIRTIETH])
	var coarse: PlayerMotor = _motor()
	Combat.submit_tick(coarse, Vector2.ZERO, Vector2.ZERO, false, true)
	coarse.tick(THIRTIETH)
	Combat.submit_tick(coarse, Vector2.ZERO, Vector2.ZERO, true, false)
	coarse.tick(64.0 / 120.0 - THIRTIETH)
	assert_almost_eq(_time_of(coarse), _time_of(fine), NEAR)
	assert_eq(coarse.get_state(), fine.get_state())
	assert_eq(coarse.get_state(), PlayerMotor.State.ATTACKING, "the attack started inside the step")
	var coarse_chain: AttackChain = coarse.get_attack_chain()
	var fine_chain: AttackChain = fine.get_attack_chain()
	assert_eq(coarse_chain.get_phase(), fine_chain.get_phase())
	assert_almost_eq(coarse_chain.get_phase_time_left(), fine_chain.get_phase_time_left(), NEAR)


# --- AC19: the same instant and place at every tick rate ---


func test_ac19_the_recovery_ends_at_the_same_motor_time_at_30_60_120_and_240() -> void:
	for rate: int in WIDE_RATES:
		var motor: PlayerMotor = _motor(_data(0.15, 0.12, 0.0))
		_play(motor, rate, 0.6, [0.0, 0.2])
		_assert_times(_fire_times, [0.0, RECOVERY_END] as Array[float], _label(rate))


func test_ac19_the_time_left_is_the_same_at_every_rate() -> void:
	for rate: int in WIDE_RATES:
		var motor: PlayerMotor = _motor()
		_play(motor, rate, 0.2, [0.0], [], Vector2.RIGHT)
		assert_almost_eq(
			motor.to_dict()["dash_recovery_remaining"], RECOVERY_END - 0.2, NEAR, _label(rate)
		)


func test_ac19_the_position_after_the_recovery_is_the_same_at_every_rate() -> void:
	for rate: int in WIDE_RATES:
		var motor: PlayerMotor = _motor()
		_play(motor, rate, 0.5, [0.0], [], Vector2.RIGHT)
		assert_almost_eq(_x(motor), 4.025, 0.0001, _label(rate))
		assert_almost_eq(Harness.position_tiles(motor).y, 0.0, NEAR)


# --- AC20: a recovery of 0 is the old behaviour ---


func test_ac20_with_no_recovery_the_state_is_never_dash_recovery() -> void:
	for rate: int in WIDE_RATES:
		var motor: PlayerMotor = _motor(_data(0.15, 0.0))
		var seen_in_handler: Array[int] = []
		var motor_ref: WeakRef = weakref(motor)
		motor.dash_ended.connect(
			func() -> void: seen_in_handler.append((motor_ref.get_ref() as PlayerMotor).get_state())
		)
		var worst: Array[int] = [0]
		var probe: Callable = func(_now: float) -> void:
			worst[0] += 1 if motor.get_state() == RECOVERY else 0
		_play(motor, rate, 1.5, [0.0, 0.5, 1.0], [0.2, 1.2], Vector2.RIGHT, probe)
		assert_eq(worst[0], 0, "%s: never in the state" % _label(rate))
		assert_eq(seen_in_handler.size(), 3)
		for state: int in seen_in_handler:
			assert_eq(state, int(PlayerMotor.State.IDLE), "%s: IDLE in the handler" % _label(rate))


func test_ac20_with_no_recovery_the_player_walks_the_instant_the_dash_ends() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor(_data(0.15, 0.0))
		_play(motor, rate, 0.2, [0.0], [], Vector2.RIGHT)
		assert_gt(_x(motor), 3.0 + 0.1, "%s: already walking at 0.2 s" % _label(rate))


# --- AC21: a hit ends the recovery; a hit ends a dash with no recovery ---


func test_ac21_a_hit_in_recovery_applies_its_damage_and_knockback_and_ends_it() -> void:
	var motor: PlayerMotor = _motor()
	_play(motor, 120, 0.2, [0.0], [], Vector2.RIGHT)
	assert_eq(motor.get_state(), RECOVERY)
	var hp: int = motor.get_combat_state().get_hp()
	_hit(motor, 1.0)
	assert_eq(motor.get_combat_state().get_hp(), hp - 20, "the damage")
	assert_eq(motor.get_state(), PlayerMotor.State.KNOCKBACK, "the knockback")
	assert_eq(motor.to_dict()["dash_recovery_remaining"], 0.0, "no recovery left behind")
	var seen: Array[int] = [0]
	var probe: Callable = func(_now: float) -> void:
		seen[0] += 1 if motor.get_state() == RECOVERY else 0
	_play(motor, 120, 0.6, [], [], Vector2.DOWN, probe)
	assert_eq(seen[0], 0, "never back in the recovery")
	assert_gt(Harness.position_tiles(motor).y, 2.5, "knocked back, then walking")


func test_ac21_a_hit_in_recovery_with_no_knockback_returns_to_idle_and_the_player_can_walk(
) -> void:
	var motor: PlayerMotor = _motor()
	_play(motor, 120, 0.2, [0.0], [], Vector2.RIGHT)
	_hit(motor, 0.0)
	assert_eq(motor.get_state(), PlayerMotor.State.IDLE)
	var before: float = _x(motor)
	_play(motor, 120, 0.1, [], [], Vector2.RIGHT)
	assert_gt(_x(motor), before + 0.1, "walking at once, the recovery is not resumed")


func test_ac21_a_dash_ended_by_a_hit_has_no_recovery() -> void:
	for knockback: float in [0.0, 1.0]:
		var motor: PlayerMotor = _motor()
		var seen: Array[int] = []
		var motor_ref: WeakRef = weakref(motor)
		motor.dash_ended.connect(
			func() -> void: seen.append((motor_ref.get_ref() as PlayerMotor).get_state())
		)
		_play(motor, 120, 0.1, [0.0], [], Vector2.RIGHT)
		assert_eq(motor.get_state(), PlayerMotor.State.DASHING)
		_hit(motor, knockback)
		assert_ne(motor.get_state(), RECOVERY, "knockback %s" % knockback)
		assert_eq(seen.size(), 1, "dash_ended once")
		assert_ne(seen[0], int(RECOVERY), "not even inside the handler")
		assert_almost_eq(motor.get_cooldown_remaining(), 0.35, NEAR, "the full cooldown starts")
		assert_eq(motor.to_dict()["dash_recovery_remaining"], 0.0)
		var worst: Array[int] = [0]
		var probe: Callable = func(_now: float) -> void:
			worst[0] += 1 if motor.get_state() == RECOVERY else 0
		_play(motor, 120, 0.6, [], [], Vector2.RIGHT, probe)
		assert_eq(worst[0], 0, "never in the recovery afterwards, knockback %s" % knockback)


# --- AC22: snapshots ---


func test_ac22_a_snapshot_in_the_middle_of_the_recovery_ends_it_at_the_same_instant() -> void:
	for rate: int in RATES:
		var original: PlayerMotor = _motor(_data(0.15, 0.12, 0.0))
		_play(original, rate, 0.2, [0.0], [], Vector2.RIGHT)
		assert_eq(original.get_state(), RECOVERY)
		var restored: PlayerMotor = Harness.motor_with(_data(0.15, 0.12, 0.0))
		restored.from_dict(original.to_dict())
		assert_eq(restored.get_state(), RECOVERY)
		assert_almost_eq(restored.to_dict()["dash_recovery_remaining"], 0.07, NEAR)
		var originals: Array[float] = []
		var restoreds: Array[float] = []
		var stamp: Callable = func(now: float, motor: PlayerMotor, into: Array[float]) -> void:
			if motor.get_state() != RECOVERY and into.is_empty():
				into.append(now)
		_play(original, rate, 0.2, [0.2], [], Vector2.RIGHT, stamp.bind(original, originals))
		_play(restored, rate, 0.2, [0.2], [], Vector2.RIGHT, stamp.bind(restored, restoreds))
		assert_eq(originals.size(), 1)
		assert_eq(restoreds, originals, "the same tick: %s" % _label(rate))
		assert_eq(restored.to_dict(), original.to_dict(), "and the same state: %s" % _label(rate))


func test_ac22_a_snapshot_taken_in_the_recovery_fires_a_buffered_action_at_the_same_time() -> void:
	for rate: int in RATES:
		var original: PlayerMotor = _motor(_data(0.15, 0.12, 0.0))
		_play(original, rate, 0.2, [0.0], [5.0 * THIRTIETH], Vector2.RIGHT)
		var restored: PlayerMotor = Harness.motor_with(_data(0.15, 0.12, 0.0))
		restored.from_dict(original.to_dict())
		_attack_starts = []
		_play(original, rate, 0.2, [], [], Vector2.RIGHT)
		var from_original: Array[float] = _attack_starts.duplicate()
		_attack_starts = []
		_play(restored, rate, 0.2, [], [], Vector2.RIGHT)
		_assert_times(from_original, [RECOVERY_END] as Array[float], "original, %s" % _label(rate))
		_assert_times(_attack_starts, from_original, "restored, %s" % _label(rate))


func test_ac22_a_snapshot_taken_in_the_middle_of_a_dash_is_followed_by_the_same_recovery() -> void:
	for rate: int in RATES:
		var original: PlayerMotor = _motor()
		_play(original, rate, 0.1, [0.0], [], Vector2.RIGHT)
		assert_eq(original.get_state(), PlayerMotor.State.DASHING)
		# Restored into a motor whose own data has no recovery: the latched value comes with the dash.
		var restored: PlayerMotor = Harness.motor_with(_data(0.15, 0.0))
		restored.from_dict(original.to_dict())
		_play(original, rate, 0.1, [], [], Vector2.RIGHT)
		_play(restored, rate, 0.1, [], [], Vector2.RIGHT)
		assert_eq(original.get_state(), RECOVERY, _label(rate))
		assert_eq(restored.get_state(), RECOVERY, "%s: the same recovery" % _label(rate))
		assert_eq(restored.to_dict(), original.to_dict(), _label(rate))


func test_c14_the_snapshot_carries_the_latched_duration_and_the_time_left() -> void:
	assert_true(PlayerMotor.SNAPSHOT_KEYS.has("dash_recovery_duration"))
	assert_true(PlayerMotor.SNAPSHOT_KEYS.has("dash_recovery_remaining"))
	var motor: PlayerMotor = _motor()
	var snapshot: Dictionary = motor.to_dict()
	for key: String in PlayerMotor.SNAPSHOT_KEYS:
		assert_true(snapshot.has(key), key)
	assert_eq(snapshot.size(), PlayerMotor.SNAPSHOT_KEYS.size())
	assert_eq(snapshot["dash_recovery_duration"], 0.0, "nothing latched before a dash")
	_play(motor, 120, 0.2, [0.0])
	snapshot = motor.to_dict()
	assert_almost_eq(snapshot["dash_recovery_duration"], 0.12, NEAR)
	assert_almost_eq(snapshot["dash_recovery_remaining"], 0.07, NEAR)


func test_c14_setup_clears_the_recovery() -> void:
	var motor: PlayerMotor = _motor()
	_play(motor, 120, 0.2, [0.0])
	assert_true(motor.setup(_shipped(), Harness.rules(), Vector2.ZERO))
	assert_eq(motor.to_dict()["dash_recovery_duration"], 0.0)
	assert_eq(motor.to_dict()["dash_recovery_remaining"], 0.0)
	assert_ne(motor.get_state(), RECOVERY)


# --- CR-5: a malformed snapshot does not reach the recovery's clock ---


## A motor at 0.2 s of a shipped dash (in its recovery, 0.07 s left) and its snapshot.
func _recovery_snapshot() -> Dictionary:
	var motor: PlayerMotor = _motor()
	_play(motor, 120, 0.2, [0.0], [], Vector2.RIGHT)
	assert_eq(motor.get_state(), RECOVERY)
	return motor.to_dict()


func _restored(snapshot: Dictionary) -> PlayerMotor:
	var restored: PlayerMotor = Harness.motor_with(_shipped())
	restored.from_dict(snapshot)
	return restored


func test_cr5_a_negative_time_left_is_read_as_zero_and_gives_the_step_no_extra_time() -> void:
	for bad: float in [-0.5, NAN]:
		var snapshot: Dictionary = _recovery_snapshot()
		snapshot["dash_recovery_remaining"] = bad
		var restored: PlayerMotor = _restored(snapshot)
		assert_eq(restored.to_dict()["dash_recovery_remaining"], 0.0, "read as 0: %s" % bad)
		var before: float = _time_of(restored)
		var x_before: float = _x(restored)
		_play(restored, 60, 1.0 / 60.0, [], [], Vector2.RIGHT)
		assert_almost_eq(_time_of(restored), before + 1.0 / 60.0, NEAR, "no extra time: %s" % bad)
		assert_lt(_x(restored) - x_before, 0.1, "walked one tick's worth at most: %s" % bad)
		assert_ne(restored.get_state(), RECOVERY, "and the recovery is over: %s" % bad)


func test_cr5_a_time_left_longer_than_the_latched_duration_is_cut_to_it() -> void:
	var snapshot: Dictionary = _recovery_snapshot()
	snapshot["dash_recovery_remaining"] = 5.0
	var restored: PlayerMotor = _restored(snapshot)
	assert_almost_eq(restored.to_dict()["dash_recovery_remaining"], 0.12, NEAR, "cut to 0.12")
	_play(restored, 60, 0.2, [], [], Vector2.RIGHT)
	assert_ne(restored.get_state(), RECOVERY, "over within the latched duration, not after 5 s")


func test_cr5_a_time_left_with_no_latched_duration_roots_nobody() -> void:
	var snapshot: Dictionary = _recovery_snapshot()
	snapshot["dash_recovery_duration"] = 0.0
	snapshot["dash_recovery_remaining"] = 5.0
	var restored: PlayerMotor = _restored(snapshot)
	assert_eq(restored.to_dict()["dash_recovery_remaining"], 0.0)
	_play(restored, 60, 1.0 / 30.0, [], [], Vector2.RIGHT)
	assert_ne(restored.get_state(), RECOVERY)


func test_cr5_a_time_left_outside_a_recovery_is_cleared_on_restore() -> void:
	var motor: PlayerMotor = _motor()
	for state: PlayerMotor.State in [PlayerMotor.State.IDLE, PlayerMotor.State.DASHING]:
		var snapshot: Dictionary = motor.to_dict()
		snapshot["state"] = state
		snapshot["dash_recovery_remaining"] = 0.5
		snapshot["dash_recovery_duration"] = 0.12
		var restored: PlayerMotor = _restored(snapshot)
		assert_eq(restored.to_dict()["dash_recovery_remaining"], 0.0, "state %s" % state)


func test_cr10_an_infinite_latched_duration_becomes_zero_and_roots_nobody() -> void:
	_assert_latched_duration_read_as_zero(INF)


func test_cr10_a_nan_latched_duration_becomes_zero_and_keeps_the_clock_clean() -> void:
	_assert_latched_duration_read_as_zero(NAN)


func test_cr10_a_negative_latched_duration_becomes_zero() -> void:
	_assert_latched_duration_read_as_zero(-1.0)


func _assert_latched_duration_read_as_zero(bad: float) -> void:
	for left: float in [5.0, 0.05]:
		var snapshot: Dictionary = _recovery_snapshot()
		snapshot["dash_recovery_duration"] = bad
		snapshot["dash_recovery_remaining"] = left
		var restored: PlayerMotor = _restored(snapshot)
		var label: String = "latched %s, %s left" % [bad, left]
		assert_eq(restored.to_dict()["dash_recovery_duration"], 0.0, "read as 0: %s" % label)
		assert_eq(restored.to_dict()["dash_recovery_remaining"], 0.0, "nothing left: %s" % label)
		var before: float = _time_of(restored)
		_play(restored, 60, 1.0 / 60.0, [], [], Vector2.RIGHT)
		assert_almost_eq(_time_of(restored), before + 1.0 / 60.0, NEAR, "a clean clock: %s" % label)
		assert_ne(restored.get_state(), RECOVERY, "not rooted: %s" % label)


func test_cr10_a_finite_positive_latched_duration_is_kept_as_it_is() -> void:
	var snapshot: Dictionary = _recovery_snapshot()
	snapshot["dash_recovery_duration"] = 0.3
	snapshot["dash_recovery_remaining"] = 0.2
	var restored: PlayerMotor = _restored(snapshot)
	assert_almost_eq(restored.to_dict()["dash_recovery_duration"], 0.3, NEAR)
	assert_almost_eq(restored.to_dict()["dash_recovery_remaining"], 0.2, NEAR)


func test_cr5_a_valid_snapshot_restores_exactly_as_before() -> void:
	var snapshot: Dictionary = _recovery_snapshot()
	var restored: PlayerMotor = _restored(snapshot)
	assert_eq(restored.to_dict(), snapshot)
	assert_almost_eq(restored.to_dict()["dash_recovery_remaining"], 0.07, NEAR)


# --- AC23: the duration is latched when the dash fires ---


func test_ac23_changing_the_class_data_in_mid_dash_does_not_change_that_dashs_recovery() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor()
		_play(motor, rate, 0.06, [0.0], [], Vector2.RIGHT)
		assert_true(motor.apply_data(_data(0.15, 0.5), Harness.rules()))
		_play(motor, rate, 0.14, [], [], Vector2.RIGHT)
		assert_eq(motor.get_state(), RECOVERY, _label(rate))
		assert_almost_eq(motor.to_dict()["dash_recovery_duration"], 0.12, NEAR, _label(rate))
		assert_almost_eq(motor.to_dict()["dash_recovery_remaining"], 0.07, NEAR, _label(rate))
		_play(motor, rate, 0.1, [], [], Vector2.RIGHT)
		assert_ne(motor.get_state(), RECOVERY, "over at 0.27 s, not at 0.65 s: %s" % _label(rate))


func test_ac23_the_next_dash_uses_the_new_value() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor()
		_play(motor, rate, 0.06, [0.0], [], Vector2.RIGHT)
		assert_true(motor.apply_data(_data(0.15, 0.5, 0.0), Harness.rules()))
		_play(motor, rate, 0.9 - 0.06, [0.4], [], Vector2.RIGHT)
		assert_almost_eq(motor.to_dict()["dash_recovery_duration"], 0.5, NEAR, _label(rate))


func test_ac23_a_dash_latched_with_no_recovery_gets_none_even_if_the_data_changes_mid_dash(
) -> void:
	var motor: PlayerMotor = _motor(_data(0.15, 0.0))
	_play(motor, 120, 0.06, [0.0], [], Vector2.RIGHT)
	assert_true(motor.apply_data(_data(0.15, 0.5), Harness.rules()))
	_play(motor, 120, 0.2, [], [], Vector2.RIGHT)
	assert_ne(motor.get_state(), RECOVERY)


# --- AC24: i-frames ---


func test_ac24_the_iframe_window_is_the_same_with_and_without_a_recovery() -> void:
	for rate: int in RATES:
		var with_recovery: PlayerMotor = _motor()
		var without: PlayerMotor = _motor(_data(0.15, 0.0))
		var windows: Array[PackedFloat64Array] = Harness.record_windows(with_recovery)
		var plain: Array[PackedFloat64Array] = Harness.record_windows(without)
		_play(with_recovery, rate, 0.1, [0.0])
		_play(without, rate, 0.1, [0.0])
		assert_eq(windows.size(), 1)
		assert_eq(windows, plain, _label(rate))
		assert_almost_eq(windows[0][0], 0.0, NEAR)
		assert_almost_eq(windows[0][1], 0.11, NEAR)


func test_ac24_a_player_in_recovery_is_not_protected_and_a_hit_there_lands() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor()
		var protected_at: Dictionary = {}
		var probe: Callable = func(now: float) -> void:
			protected_at[now] = motor.is_dash_protected()
		_play(motor, rate, 0.3, [0.0], [], Vector2.ZERO, probe)
		for now: float in protected_at:
			if now < 0.11 - 0.001:
				assert_true(protected_at[now], "%s protected at %.4f" % [_label(rate), now])
			elif now > 0.11 + THIRTIETH:
				assert_false(protected_at[now], "%s open at %.4f" % [_label(rate), now])
	var hit_motor: PlayerMotor = _motor()
	_play(hit_motor, 120, 0.2, [0.0])
	var hp: int = hit_motor.get_combat_state().get_hp()
	_hit(hit_motor, 0.0)
	assert_eq(hit_motor.get_combat_state().get_hp(), hp - 20, "not blocked")


# --- AC25: validation ---


func test_ac25_a_negative_recovery_is_refused() -> void:
	var data: ClassData = _shipped()
	data.dash_recovery_duration = -0.01
	var errors: PackedStringArray = data.validate()
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].contains("dash_recovery_duration"), str(errors))
	assert_false(Harness.motor_with(null).setup(data, Harness.rules(), Vector2.ZERO))
	assert_push_error("data rejected")


func test_ac25_nan_is_refused_zero_and_the_shipped_value_are_accepted() -> void:
	var data: ClassData = _shipped()
	data.dash_recovery_duration = NAN
	assert_eq(data.validate().size(), 1, "NaN")
	data.dash_recovery_duration = 0.0
	assert_eq(data.validate(), PackedStringArray(), "zero")
	assert_eq(_shipped().validate(), PackedStringArray(), "the shipped file")


# --- AC26: facing and cooldown during the recovery ---


func test_ac26_the_facing_follows_the_aim_during_recovery() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor()
		_play(motor, rate, 0.2, [0.0], [], Vector2.RIGHT)
		assert_eq(motor.get_state(), RECOVERY)
		motor.submit(MoveCommand.new(Vector2.RIGHT))
		motor.submit(AimCommand.new(Vector2.LEFT))
		motor.tick(1.0 / rate)
		assert_eq(motor.get_facing(), Vector2.LEFT, _label(rate))
		assert_eq(motor.get_state(), RECOVERY, "still rooted")
		assert_almost_eq(_x(motor), 3.0, NEAR)


func test_ac26_the_facing_follows_the_move_input_too_when_there_is_no_aim() -> void:
	var motor: PlayerMotor = _motor()
	_play(motor, 120, 0.2, [0.0], [], Vector2.RIGHT)
	motor.submit(MoveCommand.new(Vector2.UP))
	motor.tick(1.0 / 120.0)
	assert_eq(motor.get_facing(), Vector2.UP)


func test_ac26_the_cooldown_has_run_down_by_the_recovery_when_it_ends() -> void:
	for rate: int in WIDE_RATES:
		# A dash of 0.10 s and a recovery of 0.10 s: the recovery ends at 0.20 s, a tick boundary.
		var motor: PlayerMotor = _motor(_data(0.10, 0.10, 0.35, 0.05))
		var at_end: Array[float] = []
		var probe: Callable = func(now: float) -> void:
			if absf(now - 0.20) < 0.0001:
				at_end.append(motor.get_cooldown_remaining())
		_play(motor, rate, 0.3, [0.0], [], Vector2.ZERO, probe)
		assert_eq(at_end.size(), 1, _label(rate))
		assert_almost_eq(
			at_end[0], 0.35 - 0.10, NEAR, "the recovery's length is gone: %s" % _label(rate)
		)


func test_ac26_the_cooldown_counts_from_the_dash_end_through_the_recovery() -> void:
	for rate: int in RATES:
		var motor: PlayerMotor = _motor()
		_play(motor, rate, 0.2, [0.0])
		assert_almost_eq(
			motor.get_cooldown_remaining(), 0.35 - (0.2 - DASH_END), NEAR, _label(rate)
		)
