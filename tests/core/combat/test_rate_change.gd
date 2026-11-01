extends GutTest
## AC24 and C18: the rate check. A running hit or pulse must not lose its contact to a slower
## grid. Window at rate 240: [0.036, 0.0401667), so its contact is 9/240.

const SLOW_WINDUP: float = 0.036
const ACTIVE_AT_240: float = 1.0 / 240.0
const TIME: float = 0.000001


func test_ac24_lowering_the_rate_is_refused_during_a_short_hit() -> void:
	var arena: CombatArena = _sword_at_240()
	arena.play(120, 0, 1, [0])
	assert_eq(arena.sim.rate_change_errors(120).size(), 1)
	assert_eq(arena.sim.get_step_rate(), 240, "nothing changed")
	arena.play(120, 1, 3)
	assert_eq(arena.hit_times.size(), 1)
	assert_almost_eq(arena.hit_times[0], 9.0 / 240.0, TIME)


func test_ac24_lowering_the_rate_is_refused_during_a_short_pulse() -> void:
	var arena: CombatArena = _pulse_at_240()
	arena.dummy.set_pulse_enabled(true)
	arena.play(120, 0, 1)
	var errors: PackedStringArray = arena.sim.rate_change_errors(120)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "dummy_anchored", "the overlay names it")
	arena.play(120, 1, 3)
	assert_eq(arena.hurt_times.size(), 1)
	assert_almost_eq(arena.hurt_times[0], 9.0 / 240.0, TIME)


func test_ac24_the_same_rate_change_passes_once_the_hit_is_in_recovery() -> void:
	var arena: CombatArena = _sword_at_240()
	arena.play(120, 0, 5, [0])
	assert_eq(arena.player.get_attack_chain().get_phase(), AttackChain.Phase.RECOVERY)
	assert_eq(arena.sim.rate_change_errors(120).size(), 0)
	arena.sim.set_step_rate(120)
	assert_eq(arena.sim.get_step_rate(), 120)
	assert_eq(CombatTiming.step_count(1.0 / 60.0, arena.sim.get_step_rate()), 2)


func test_ac24_the_same_rate_change_passes_once_the_pulse_is_in_its_wait() -> void:
	var arena: CombatArena = _pulse_at_240()
	arena.dummy.set_pulse_enabled(true)
	arena.play(120, 0, 3)
	assert_eq(arena.dummy.get_pulse_phase(), PulseCycle.Phase.WAIT)
	assert_eq(arena.sim.rate_change_errors(120).size(), 0)


func test_ac24_raising_the_rate_passes_and_the_hit_finishes_on_its_latched_values() -> void:
	var arena: CombatArena = CombatArena.new().build()
	arena.play(120, 0, 1, [0])
	assert_eq(arena.sim.rate_change_errors(240).size(), 0)
	arena.sim.set_step_rate(240)
	arena.play(120, 1, 3)
	assert_eq(arena.hit_times.size(), 1)
	assert_almost_eq(arena.hit_times[0], 20.0 / 240.0, TIME, "the first contact past 0.08")
	assert_eq(arena.dummy.get_combat_state().get_hp(), 190)


func test_a_rate_that_keeps_a_contact_passes_even_lower() -> void:
	var arena: CombatArena = CombatArena.new()
	arena.rules = CombatArena.MotorHarness.rules()
	arena.rules.combat_step_rate = 240
	arena.build()
	arena.play(120, 0, 1, [0])
	assert_eq(arena.sim.rate_change_errors(120).size(), 0, "0.06 is plenty at 120")


func test_a_step_rate_of_240_runs_twice_the_contacts() -> void:
	assert_eq(CombatTiming.step_count(1.0 / 120.0, 240), 2)
	assert_eq(CombatTiming.step_count(1.0 / 30.0, 240), 8)


func test_c18_new_rules_reach_the_next_hit() -> void:
	var arena: CombatArena = CombatArena.new().build()
	var longer: PlayerCombatTunables = arena.rules.duplicate()
	longer.hitstop_normal = 0.5
	arena.sim.set_tunables(longer)
	arena.play(120, 0, 3, [0])
	assert_gt(arena.player.get_combat_state().get_hitstop_remaining(), 0.4)


func _sword_at_240() -> CombatArena:
	var arena: CombatArena = CombatArena.new()
	arena.rules = CombatArena.MotorHarness.rules()
	arena.rules.combat_step_rate = 240
	arena.class_data = CombatArena.warrior()
	arena.class_data.attack_chain[0].windup = SLOW_WINDUP
	arena.class_data.attack_chain[0].active = ACTIVE_AT_240
	return arena.build()


func _pulse_at_240() -> CombatArena:
	var arena: CombatArena = CombatArena.new()
	arena.rules = CombatArena.MotorHarness.rules()
	arena.rules.combat_step_rate = 240
	arena.dummy_data = CombatArena.dummy_values()
	arena.dummy_data.pulse_telegraph = SLOW_WINDUP
	arena.dummy_data.pulse_active = ACTIVE_AT_240
	arena.dummy_data.pulse_knockback_tiles = 0.0
	return arena.build(Vector2.ZERO)
