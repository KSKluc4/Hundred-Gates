extends GutTest
## C15 and C16 through the real motor and dummy: the worked oracles of AC22 and AC26.

const RATES: Array[int] = [30, 60, 120]
const TIME: float = 0.000001
const TILE: float = 0.01
const STEP: float = 1.0 / 120.0


func test_c15_a_tick_splits_into_equal_steps_on_the_grid() -> void:
	for sample: Array in [[30, 4], [60, 2], [120, 1]]:
		assert_eq(CombatTiming.step_count(1.0 / sample[0], 120), sample[1])
	assert_eq(CombatTiming.step_count(1.0 / 60.0, 240), 4)
	assert_eq(CombatTiming.step_count(0.0, 120), 1, "a step always runs")


func test_c15_time_follows_the_ticks_at_every_rate() -> void:
	for rate: int in RATES:
		var arena: CombatArena = CombatArena.new().build()
		arena.play(rate, 0, 30)
		assert_almost_eq(arena.sim.get_time(), 1.0, TIME, "%d Hz" % rate)


func test_ac22_the_whole_scripted_run_matches_at_every_rate() -> void:
	for rate: int in RATES:
		var arena: CombatArena = CombatArena.new().build()
		var moves: Dictionary = {24: Vector2.RIGHT, 42: Vector2.LEFT, 58: Vector2.RIGHT}
		arena.play(rate, 0, 66, [0, 6, 12, 48], [24, 42, 58], moves)
		var label: String = "%d Hz" % rate
		_assert_times(
			arena.hit_times, [10.0 / 120.0, 34.0 / 120.0, 68.0 / 120.0, 202.0 / 120.0], label
		)
		_assert_times(arena.dash_times, [0.8, 1.4, 1.95], label)
		assert_eq(arena.dummy.get_combat_state().get_hp(), 148, label)
		var position: Vector2 = Units.vector_px_to_tiles(arena.player.get_position_px())
		assert_almost_eq(position.x, 3.0, TILE, label)
		assert_almost_eq(position.y, 0.0, TILE, label)


func test_ac26_contact_after_i_frames_inside_one_tick_hits_once() -> void:
	for rate: int in RATES:
		var arena: CombatArena = CombatArena.new()
		arena.dummy_data = _pulse_data(0.0, 0.2)
		arena.build(Vector2.ZERO)
		arena.dummy.set_pulse_enabled(true)
		arena.play(rate, 0, 6, [], [0], {}, Vector2.RIGHT)
		_assert_times(arena.hurt_times, [14.0 / 120.0], "%d Hz" % rate)
		assert_eq(arena.player.get_combat_state().get_hp(), 80)


func test_ac26_active_phase_inside_one_tick_lands_once() -> void:
	for rate: int in RATES:
		var arena: CombatArena = _arena_with_hit(0.045, STEP)
		arena.play(rate, 0, 3, [0])
		_assert_times(arena.hit_times, [0.05], "%d Hz" % rate)


func test_ac26_hitstop_overshoot_is_carried_exactly() -> void:
	for rate: int in RATES:
		var arena: CombatArena = CombatArena.new()
		arena.rules = CombatArena.MotorHarness.rules()
		arena.rules.hitstop_normal = 0.055
		arena.build()
		arena.play(rate, 0, 5, [0])
		_assert_times(arena.hit_times, [10.0 / 120.0], "%d Hz" % rate)
		var chain: AttackChain = arena.player.get_attack_chain()
		assert_eq(chain.get_phase(), AttackChain.Phase.ACTIVE, "0.1667 is before 0.195")
		assert_almost_eq(
			chain.get_phase_time_left(), 0.195 - 5.0 / 30.0, TIME, "recovery starts at 0.195"
		)


func test_ac26_zero_lead_sword_lands_one_step_after_the_press() -> void:
	for rate: int in RATES:
		var arena: CombatArena = _arena_with_hit(0.0, 2.0 * STEP)
		arena.play(rate, 0, 3, [1])
		_assert_times(arena.hit_times, [1.0 / 30.0 + STEP], "%d Hz" % rate)


func test_ac26_zero_lead_pulse_lands_one_step_after_the_toggle() -> void:
	for rate: int in RATES:
		var arena: CombatArena = CombatArena.new()
		arena.dummy_data = _pulse_data(0.0, 2.0 * STEP)
		arena.build(Vector2.ZERO)
		arena.play(rate, 0, 1)
		arena.dummy.set_pulse_enabled(true)
		arena.play(rate, 1, 3)
		_assert_times(arena.hurt_times, [1.0 / 30.0 + STEP], "%d Hz" % rate)


func test_ac26_window_starting_on_a_contact_lands_on_its_start_exactly_once() -> void:
	for rate: int in RATES:
		var arena: CombatArena = _arena_with_hit(STEP, STEP)
		arena.play(rate, 0, 3, [0])
		_assert_times(arena.hit_times, [STEP], "%d Hz sword" % rate)
		var pulse: CombatArena = CombatArena.new()
		pulse.dummy_data = _pulse_data(STEP, STEP)
		pulse.build(Vector2.ZERO)
		pulse.dummy.set_pulse_enabled(true)
		pulse.play(rate, 0, 3)
		_assert_times(pulse.hurt_times, [STEP], "%d Hz pulse" % rate)


func test_ac26_a_hurtbox_entering_during_attacker_hitstop_waits_for_it_to_end() -> void:
	for rate: int in RATES:
		var arena: CombatArena = CombatArena.new().build(Vector2(0, 1), Vector2(0, 30))
		arena.play(rate, 0, 2, [0])
		arena.play(rate, 2, 3)
		_assert_times(arena.hit_times, [10.0 / 120.0], "%d Hz, first target" % rate)
		# Inside the arc from now on, while the attacker is stopped until 0.1333.
		arena.other.sync_position(Units.vector_tiles_to_px(Vector2(0.2, 1)))
		arena.play(rate, 3, 5)
		# Hitstop ends exactly on the contact at 16/120, and a boundary counts as reached.
		_assert_times(arena.hit_times, [10.0 / 120.0, 16.0 / 120.0], "%d Hz, second" % rate)


func test_ac2_a_miss_changes_nothing() -> void:
	var arena: CombatArena = CombatArena.new().build(Vector2(0, -3))
	arena.play(120, 0, 15, [0])
	assert_eq(arena.hit_times.size(), 0)
	assert_eq(arena.dummy.get_combat_state().get_hp(), 200)


func test_ac10_one_instance_hits_once_and_each_hit_is_its_own_instance() -> void:
	for rate: int in RATES:
		var arena: CombatArena = CombatArena.new().build()
		arena.play(rate, 0, 30, [0, 6, 12])
		assert_eq(arena.hit_times.size(), 3, "%d Hz" % rate)
		assert_eq(arena.dummy.get_combat_state().get_hp(), 158)


func test_ac11_hit_landed_carries_the_whole_event() -> void:
	var arena: CombatArena = CombatArena.new().build()
	arena.play(120, 0, 4, [0])
	var event: HitEvent = arena.events[0]
	assert_eq(event.attacker_id, PlayerMotor.DEFAULT_COMBAT_ID)
	assert_eq(event.target_id, &"dummy_anchored")
	assert_eq(event.damage, 10)
	assert_false(event.is_finisher)
	assert_eq(event.direction, Vector2.DOWN)


func test_ac13_one_attack_on_two_targets_gives_one_hitstop() -> void:
	var arena: CombatArena = CombatArena.new().build(Vector2(0, 1), Vector2(0.3, 1))
	arena.play(120, 0, 3, [0])
	assert_eq(arena.hit_times.size(), 2, "both at one contact")
	assert_eq(arena.hit_times[0], arena.hit_times[1])
	var left: float = arena.player.get_combat_state().get_hitstop_remaining()
	assert_almost_eq(left, 0.05 - (0.1 - 10.0 / 120.0), TIME, "one, not two")


func test_ac13_finisher_uses_its_own_hitstop() -> void:
	var arena: CombatArena = CombatArena.new().build()
	arena.play(120, 0, 17, [0, 6, 12])
	assert_true(arena.events[2].is_finisher)
	var left: float = arena.player.get_combat_state().get_hitstop_remaining()
	assert_almost_eq(left, 0.1 - (17.0 / 30.0 - 68.0 / 120.0), TIME)


func test_ac13_other_entities_keep_moving_and_ticking_during_a_hitstop() -> void:
	var arena: CombatArena = CombatArena.new().build()
	var bystander: PlayerMotor = PlayerMotor.new()
	bystander.setup(arena.class_data, arena.rules, Vector2(9, 9), Vector2.DOWN, &"player_2")
	arena.sim.register(bystander)
	arena.dummy.set_pulse_enabled(true)
	arena.play(120, 0, 3, [0])
	assert_true(arena.player.get_combat_state().is_in_hitstop())
	assert_true(arena.dummy.get_combat_state().is_in_hitstop())
	var before_clock: float = bystander.to_dict()["time"]
	var before_position: Vector2 = bystander.get_position_px()
	bystander.submit(MoveCommand.new(Vector2.RIGHT))
	arena.sim.tick(1.0 / 60.0)
	assert_almost_eq(bystander.to_dict()["time"], before_clock + 1.0 / 60.0, TIME)
	assert_gt(bystander.get_position_px().x, before_position.x)
	assert_false(bystander.get_combat_state().is_in_hitstop())


func _assert_times(actual: Array[float], expected: Array, label: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s: %s" % [label, actual])
	for index: int in mini(actual.size(), expected.size()):
		assert_almost_eq(actual[index], float(expected[index]), TIME, label)


func _arena_with_hit(windup: float, active: float) -> CombatArena:
	var arena: CombatArena = CombatArena.new()
	arena.class_data = CombatArena.warrior()
	arena.class_data.attack_chain[0].windup = windup
	arena.class_data.attack_chain[0].active = active
	return arena.build()


func _pulse_data(telegraph: float, active: float) -> DummyData:
	var data: DummyData = CombatArena.dummy_values()
	data.pulse_telegraph = telegraph
	data.pulse_active = active
	data.pulse_radius_tiles = 20.0
	data.pulse_knockback_tiles = 0.0
	return data
