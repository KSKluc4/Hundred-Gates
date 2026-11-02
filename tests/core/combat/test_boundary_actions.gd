extends GutTest
## F-003/C15, C17 (CR-1): an action due exactly on a step's end fires before that instant's
## contact, at every rate. Each case puts a live pulse on the player at that same instant, so
## the proof is the HP at the contact, not only the fire time.

const Combat: GDScript = preload("res://tests/core/combat/combat_harness.gd")
const MotorHarness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const SOUTH: Vector2 = Vector2(0, 5)
const NORTH: Vector2 = Vector2(0, -5)
const LATE_CONTACT_AT_01: float = 26.0 / 120.0  # 0.1 + 0.11 of i-frames, on the grid.
const LATE_CONTACT_AT_05: float = 74.0 / 120.0  # 0.5 + 0.11 of i-frames, on the grid.
const LATE_CONTACT_AT_02: float = 38.0 / 120.0  # 0.2 + 0.11 of i-frames, on the grid.


func test_ready_dash_fires_at_recovery_start_before_that_contact() -> void:
	for rate: int in Combat.RATES:
		var arena: CombatArena = _short_hit_arena(_pulse_arena(0.1)).build(SOUTH)
		var motor_clock: Array[float] = MotorHarness.record_fire_times(arena.player)
		arena.dummy.set_pulse_enabled(true)
		arena.play(rate, 0, 5, [0], [1])
		_assert_times(arena.dash_times, [0.1], "%d Hz: fires as recovery starts" % rate)
		_assert_times(motor_clock, [0.1], "%d Hz: on the motor's own clock too" % rate)
		_assert_times(arena.hurt_times, [], "%d Hz: protected at 0.1" % rate)
		arena.play(rate, 5, 8)
		_assert_times(arena.hurt_times, [LATE_CONTACT_AT_01], "%d Hz: the tail is hit" % rate)
		assert_eq(arena.player.get_combat_state().get_hp(), 80)


func test_waiting_dash_fires_at_cooldown_expiry_before_that_contact() -> void:
	for rate: int in Combat.RATES:
		var arena: CombatArena = _pulse_arena(0.5).build(SOUTH)
		arena.dummy.set_pulse_enabled(true)
		arena.play(rate, 0, 17, [], [0, 12])
		_assert_times(arena.dash_times, [0.0, 0.5], "%d Hz: fires at expiry" % rate)
		_assert_times(arena.hurt_times, [], "%d Hz: protected at 0.5" % rate)
		arena.play(rate, 17, 20)
		_assert_times(arena.hurt_times, [LATE_CONTACT_AT_05], "%d Hz: the tail is hit" % rate)


func test_dash_stored_in_hitstop_fires_at_its_end_before_that_contact() -> void:
	for rate: int in Combat.RATES:
		var arena: CombatArena = _pulse_arena(0.1)
		arena.rules = MotorHarness.rules()
		arena.rules.hitstop_normal = 0.1  # From the hit at 0.1, ends on a contact at 0.2.
		arena.rules.player_hurt_iframes = 0.0
		arena.build(SOUTH, NORTH)
		arena.dummy.set_pulse_enabled(true)
		arena.play(rate, 0, 3)
		_assert_times(arena.hurt_times, [0.1], "%d Hz: the first pulse lands" % rate)
		arena.other.set_pulse_enabled(true)  # Goes live at 0.2, as the hitstop ends.
		arena.play(rate, 3, 8, [], [5])
		_assert_times(arena.dash_times, [0.2], "%d Hz: no fire inside hitstop" % rate)
		_assert_times(arena.hurt_times, [0.1], "%d Hz: protected at 0.2" % rate)
		arena.play(rate, 8, 11)
		_assert_times(arena.hurt_times, [0.1, LATE_CONTACT_AT_02], "%d Hz: the tail" % rate)


func test_dash_wins_at_that_contact_and_the_attack_is_discarded() -> void:
	for rate: int in Combat.RATES:
		var arena: CombatArena = _short_hit_arena(_pulse_arena(0.1)).build(SOUTH)
		arena.dummy.set_pulse_enabled(true)
		arena.play(rate, 0, 5, [0, 2], [1])
		_assert_times(arena.dash_times, [0.1], "%d Hz: the dash fires" % rate)
		_assert_times(arena.hurt_times, [], "%d Hz: protected at 0.1" % rate)
		assert_false(arena.player.has_buffered_attack(), "%d Hz: discarded" % rate)
		assert_eq(arena.player.get_state(), PlayerMotor.State.DASHING)


func test_attack_with_no_windup_lands_on_the_contact_at_its_fire_instant() -> void:
	for rate: int in Combat.RATES:
		var arena: CombatArena = _short_hit_arena(CombatArena.new())
		arena.class_data.attack_chain[1].windup = 0.0
		arena.build()
		arena.play(rate, 0, 7, [0, 1])
		# Hit 1 lands on 0.05 and pauses the clock to 0.1, so its recovery starts at 0.15.
		_assert_times(arena.hit_times, [0.05, 0.15], "%d Hz: hit 2 fires and lands" % rate)


func _pulse_arena(telegraph: float) -> CombatArena:
	var arena: CombatArena = CombatArena.new()
	arena.dummy_data = CombatArena.dummy_values()
	arena.dummy_data.pulse_telegraph = telegraph
	arena.dummy_data.pulse_active = 0.2
	arena.dummy_data.pulse_radius_tiles = 20.0
	arena.dummy_data.pulse_knockback_tiles = 0.0
	return arena


## Hit 1's recovery starts at 0.1, a multiple of the step and off the 1/30 s grid's ticks.
func _short_hit_arena(arena: CombatArena) -> CombatArena:
	arena.class_data = CombatArena.warrior()
	arena.class_data.attack_chain[0].windup = 0.05
	arena.class_data.attack_chain[0].active = 0.05
	return arena


func _assert_times(actual: Array[float], expected: Array, label: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s: %s" % [label, actual])
	if actual.size() != expected.size():
		return
	for index: int in expected.size():
		assert_almost_eq(actual[index], float(expected[index]), Combat.TIME_TOLERANCE, label)
