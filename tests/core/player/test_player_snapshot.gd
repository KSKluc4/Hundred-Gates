extends GutTest
## AC23: restore into fresh objects at the C19 boundary, then the next 60 ticks must match an
## unbroken run, with no target hit twice or skipped.

const RATE: int = 60
const TICKS_AFTER: int = 60
const IN_REACH: Vector2 = Vector2(0.3, 1)
const OUT_OF_REACH: Vector2 = Vector2(0, 30)
const PRESS_TICK: int = 30
const NO_PRESS: int = -1


func test_ac23_mid_windup() -> void:
	var arena: CombatArena = CombatArena.new().build()
	arena.play(RATE, 0, 1, [0])
	assert_eq(arena.player.get_attack_chain().get_phase(), AttackChain.Phase.WINDUP)
	_assert_continues(arena, _fresh())


func test_ac23_mid_hitstop() -> void:
	var arena: CombatArena = CombatArena.new().build()
	arena.play(RATE, 0, 3, [0])
	assert_true(arena.player.get_combat_state().is_in_hitstop())
	_assert_continues(arena, _fresh())


func test_ac23_mid_active_with_a_partial_hit_set() -> void:
	var arena: CombatArena = CombatArena.new().build(Vector2(0, 1), OUT_OF_REACH)
	arena.play(RATE, 0, 5, [0])
	var hitbox: Hitbox = arena.player.get_live_hitbox()
	assert_not_null(hitbox, "active until 0.19")
	assert_true(hitbox.has_hit(&"dummy_anchored"))
	assert_false(hitbox.has_hit(&"dummy_loose"))
	var fresh: CombatArena = CombatArena.new().build(Vector2(0, 1), OUT_OF_REACH)
	assert_true(fresh.sim.from_dict(arena.sim.to_dict()))
	for side: CombatArena in [arena, fresh]:
		side.other.sync_position(Units.vector_tiles_to_px(IN_REACH))
	_run_both(arena, fresh, NO_PRESS)
	assert_eq(arena.dummy.get_combat_state().get_hp(), 190, "the first one is not hit twice")
	assert_eq(arena.other.get_combat_state().get_hp(), 190, "the second one is not skipped")
	assert_eq(fresh.dummy.get_combat_state().get_hp(), 190)
	assert_eq(fresh.other.get_combat_state().get_hp(), 190)


func test_ac23_mid_knockback() -> void:
	var arena: CombatArena = _pulsed(0.0)
	arena.play(RATE, 0, 3)
	assert_eq(arena.player.get_state(), PlayerMotor.State.KNOCKBACK)
	assert_gt(arena.player.get_combat_state().get_knockback_time_left(), 0.0)
	var fresh: CombatArena = _pulsed(0.0)
	_assert_continues(arena, fresh)


func test_ac23_mid_pulse_telegraph() -> void:
	var arena: CombatArena = _pulsed(0.5)
	arena.play(RATE, 0, 3)
	assert_eq(arena.dummy.get_pulse_phase(), PulseCycle.Phase.TELEGRAPH)
	_assert_continues(arena, _pulsed(0.5))


func test_ac23_mid_pulse_active_with_its_hit_set() -> void:
	var arena: CombatArena = _pulsed(0.0)
	arena.play(RATE, 0, 3)
	assert_eq(arena.dummy.get_pulse_phase(), PulseCycle.Phase.ACTIVE)
	assert_true(arena.dummy.get_live_hitbox().has_hit(PlayerMotor.DEFAULT_COMBAT_ID))
	var fresh: CombatArena = _pulsed(0.0)
	_assert_continues(arena, fresh)
	assert_eq(fresh.player.get_combat_state().get_hp(), 80, "not hit twice")


func test_ac23_with_a_buffered_attack_and_dash() -> void:
	var arena: CombatArena = CombatArena.new().build()
	arena.play(RATE, 0, 3, [0, 2], [2])
	assert_true(arena.player.has_buffered_attack())
	assert_true(arena.player.has_buffered_dash())
	_assert_continues(arena, _fresh())


func test_ac23_mid_ko_respawn() -> void:
	var arena: CombatArena = CombatArena.new()
	arena.dummy_data = _weak_dummy()
	arena.build()
	arena.play(RATE, 0, 4, [0])
	assert_true(arena.dummy.is_ko())
	var fresh: CombatArena = CombatArena.new()
	fresh.dummy_data = _weak_dummy()
	fresh.build()
	_assert_continues(arena, fresh)


func test_c19_the_sim_refuses_other_ids() -> void:
	var arena: CombatArena = CombatArena.new().build()
	var before: Dictionary = arena.sim.to_dict()
	var other_ids: CombatArena = CombatArena.new().build(Vector2(0, 1), Vector2(0, 3))
	assert_false(arena.sim.from_dict(other_ids.sim.to_dict()))
	assert_push_error("snapshot rejected")
	assert_eq_deep(arena.sim.to_dict(), before)


func test_c19_the_sim_refuses_another_order() -> void:
	var arena: CombatArena = CombatArena.new().build()
	arena.play(RATE, 0, 1, [0])
	var before: Dictionary = arena.sim.to_dict()
	var reversed: CombatArena = CombatArena.new().build(Vector2(0, 1), null, false)
	assert_false(arena.sim.from_dict(reversed.sim.to_dict()))
	assert_push_error("snapshot rejected")
	assert_eq_deep(arena.sim.to_dict(), before)


func test_c19_the_sim_refuses_another_step_rate() -> void:
	var arena: CombatArena = CombatArena.new().build()
	var before: Dictionary = arena.sim.to_dict()
	var faster: CombatArena = CombatArena.new()
	faster.rules = CombatArena.MotorHarness.rules()
	faster.rules.combat_step_rate = 240
	faster.build()
	assert_false(arena.sim.from_dict(faster.sim.to_dict()))
	assert_push_error("snapshot rejected")
	assert_eq_deep(arena.sim.to_dict(), before)


func test_c19_the_sim_refuses_a_snapshot_with_missing_keys() -> void:
	var arena: CombatArena = CombatArena.new().build()
	assert_false(arena.sim.from_dict({"time": 9.0}))
	assert_push_error("snapshot rejected")


func test_c19_a_snapshot_holds_every_combatant_in_order() -> void:
	var arena: CombatArena = CombatArena.new().build(Vector2(0, 1), Vector2(0, 3))
	var snapshot: Dictionary = arena.sim.to_dict()
	assert_eq(snapshot["step_rate"], 120)
	assert_eq_deep(
		snapshot["order"],
		[PlayerMotor.DEFAULT_COMBAT_ID, &"dummy_anchored", &"dummy_loose"] as Array[StringName]
	)
	assert_eq(snapshot["combatants"].size(), 3)


func test_c12_restoring_a_motor_and_a_dummy_tells_the_views() -> void:
	var arena: CombatArena = CombatArena.new().build()
	var snapshot: Dictionary = arena.sim.to_dict()
	watch_signals(arena.player)
	watch_signals(arena.dummy)
	arena.sim.from_dict(snapshot)
	assert_signal_emitted(arena.player, "state_restored")
	assert_signal_emitted(arena.dummy, "state_restored")


func _fresh() -> CombatArena:
	return CombatArena.new().build()


## Telegraph `telegraph`, active 1.0, default knockback, toggled on at 0.
func _pulsed(telegraph: float) -> CombatArena:
	var arena: CombatArena = CombatArena.new()
	arena.dummy_data = CombatArena.dummy_values()
	arena.dummy_data.pulse_telegraph = telegraph
	arena.dummy_data.pulse_active = 1.0
	arena.build(Vector2.ZERO)
	arena.dummy.set_pulse_enabled(true)
	return arena


func _weak_dummy() -> DummyData:
	var data: DummyData = CombatArena.dummy_values()
	data.max_hp = 5
	return data


func _assert_continues(original: CombatArena, fresh: CombatArena) -> void:
	assert_true(fresh.sim.from_dict(original.sim.to_dict()))
	assert_eq_deep(fresh.sim.to_dict(), original.sim.to_dict())
	_run_both(original, fresh)


## Same commands on both, including a press neither saw before, compared after every tick.
func _run_both(original: CombatArena, fresh: CombatArena, press_tick: int = PRESS_TICK) -> void:
	var hits_before: int = original.hit_times.size()
	var hurts_before: int = original.hurt_times.size()
	for index: int in TICKS_AFTER:
		for side: CombatArena in [original, fresh]:
			side.player.submit(MoveCommand.new(Vector2.RIGHT if index < 20 else Vector2.ZERO))
			side.player.submit(AimCommand.new(Vector2.DOWN))
			if index == press_tick:
				side.player.submit(AttackCommand.new())
			side.sim.tick(1.0 / RATE)
		assert_eq_deep(fresh.sim.to_dict(), original.sim.to_dict())
	assert_eq(fresh.hit_times.size(), original.hit_times.size() - hits_before)
	assert_eq(fresh.hurt_times.size(), original.hurt_times.size() - hurts_before)
