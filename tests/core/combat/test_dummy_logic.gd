extends GutTest
## AC18, AC19, C20: the dummy's logic, stepped by hand. Default pulse: telegraph 0.6, active
## 0.1, wait 1.3, so one cycle is 2.0 start to start.

const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const STEP: float = 1.0 / 120.0
const OFF: PulseCycle.Phase = PulseCycle.Phase.OFF
const TELEGRAPH: PulseCycle.Phase = PulseCycle.Phase.TELEGRAPH
const ACTIVE: PulseCycle.Phase = PulseCycle.Phase.ACTIVE
const WAIT: PulseCycle.Phase = PulseCycle.Phase.WAIT

var _rules: PlayerCombatTunables


func before_each() -> void:
	_rules = Harness.rules()


func test_ac18_starts_full_with_its_data() -> void:
	var dummy: DummyLogic = _dummy()
	assert_eq(dummy.get_combat_state().get_hp(), 200)
	assert_eq(dummy.get_team(), Combatant.Team.ENEMY)
	assert_eq(dummy.get_combat_id(), &"dummy_a")
	assert_eq(dummy.get_hurtbox().radius_tiles, 0.5)
	assert_false(dummy.is_ko())


func test_invalid_data_is_refused() -> void:
	var data: DummyData = _data()
	data.max_hp = 0
	var dummy: DummyLogic = DummyLogic.new()
	assert_false(dummy.setup(data, 120, Vector2.ZERO, 0.0, &"dummy_a"))
	assert_push_error("data rejected")


func test_ac18_ko_emits_died_ignores_hits_and_refills_after_the_delay() -> void:
	var dummy: DummyLogic = _dummy()
	watch_signals(dummy.get_combat_state())
	_hit(dummy, 500)
	assert_true(dummy.is_ko())
	assert_false(dummy.can_be_hit())
	assert_signal_emit_count(dummy.get_combat_state(), "died", 1)
	_run(dummy, 0.05)  # Hitstop.
	_run(dummy, 0.9)
	assert_true(dummy.is_ko(), "the delay is 1.0, after hitstop")
	_run(dummy, 0.1)
	assert_false(dummy.is_ko())
	assert_eq(dummy.get_combat_state().get_hp(), 200)
	assert_true(dummy.can_be_hit())


func test_ac12_knockback_uses_the_instance_scale() -> void:
	var loose: DummyLogic = _dummy(1.0)
	_hit(loose, 10, 1.2)
	_run(loose, 0.05)
	_run(loose, 0.125)
	assert_almost_eq(loose.get_position_px().y, Units.tiles_to_px(1.2), 0.01)
	assert_eq(loose.get_knockback_scale(), 1.0)


func test_ac18_loose_dummy_stays_where_it_lands() -> void:
	var loose: DummyLogic = _dummy(1.0)
	_hit(loose, 10, 1.2)
	_run(loose, 0.2)
	var landed: Vector2 = loose.get_position_px()
	_run(loose, 1.0)
	assert_eq(loose.get_position_px(), landed)


func test_c7_hitstop_pauses_the_respawn_timer() -> void:
	var dummy: DummyLogic = _dummy()
	_hit(dummy, 500)
	_run(dummy, 1.0)
	assert_true(dummy.is_ko(), "0.05 of that was hitstop")


func test_ac19_off_by_default_with_no_hitbox() -> void:
	var dummy: DummyLogic = _dummy()
	_run(dummy, 3.0)
	assert_eq(dummy.get_pulse_phase(), OFF)
	assert_null(dummy.get_live_hitbox())


func test_ac19_cycle_runs_telegraph_active_wait_start_to_start() -> void:
	var dummy: DummyLogic = _pulsing()
	var expected: Array[Array] = [
		[0.5, TELEGRAPH],
		[0.1, ACTIVE],
		[0.08, ACTIVE],
		[0.05, WAIT],
		[1.25, WAIT],
		[0.025, TELEGRAPH]
	]
	for sample: Array in expected:
		_run(dummy, sample[0])
		assert_eq(dummy.get_pulse_phase(), sample[1], "after %s more" % sample[0])


func test_ac19_active_pulse_is_a_full_circle_with_its_data() -> void:
	var dummy: DummyLogic = _pulsing()
	assert_null(dummy.get_live_hitbox(), "telegraph")
	_run(dummy, 0.625)
	var hitbox: Hitbox = dummy.get_live_hitbox()
	assert_eq(hitbox.arc_angle_deg, 360.0)
	assert_eq(hitbox.range_tiles, 2.5)
	assert_eq(hitbox.damage, 20)
	assert_eq(hitbox.knockback_tiles, 1.0)
	assert_eq(hitbox.direction, Vector2.DOWN)
	assert_false(hitbox.knockback_from_center, "AC12: a pulse pushes down")
	assert_false(hitbox.is_finisher, "AC13: a pulse is a normal hit")


func test_c20_toggle_off_during_telegraph_stops_at_once() -> void:
	var dummy: DummyLogic = _pulsing()
	_run(dummy, 0.3)
	dummy.set_pulse_enabled(false)
	assert_eq(dummy.get_pulse_phase(), OFF)
	_run(dummy, 3.0)
	assert_null(dummy.get_live_hitbox())


func test_c20_toggle_off_during_active_removes_the_hitbox_and_its_hit_set() -> void:
	var dummy: DummyLogic = _pulsing()
	_run(dummy, 0.625)
	dummy.get_live_hitbox().mark_hit(&"player_1")
	dummy.set_pulse_enabled(false)
	assert_null(dummy.get_live_hitbox())
	dummy.set_pulse_enabled(true)
	_run(dummy, 0.625)
	assert_false(dummy.get_live_hitbox().has_hit(&"player_1"))


func test_c20_toggle_on_always_starts_a_new_cycle_at_telegraph() -> void:
	var dummy: DummyLogic = _pulsing()
	_run(dummy, 1.0)
	assert_eq(dummy.get_pulse_phase(), WAIT)
	dummy.set_pulse_enabled(false)
	dummy.set_pulse_enabled(true)
	assert_eq(dummy.get_pulse_phase(), TELEGRAPH)


func test_c20_ko_stops_the_pulse_while_the_toggle_stays_on() -> void:
	var dummy: DummyLogic = _pulsing()
	_run(dummy, 0.625)
	_hit(dummy, 500)
	assert_eq(dummy.get_pulse_phase(), OFF)
	assert_null(dummy.get_live_hitbox())
	assert_true(dummy.is_pulse_enabled())


func test_c20_respawn_with_the_toggle_on_starts_at_telegraph() -> void:
	var dummy: DummyLogic = _pulsing()
	_hit(dummy, 500)
	_run(dummy, 1.05)
	assert_false(dummy.is_ko())
	assert_eq(dummy.get_pulse_phase(), TELEGRAPH)


func test_c20_toggling_on_during_ko_waits_for_the_respawn() -> void:
	var dummy: DummyLogic = _dummy()
	_hit(dummy, 500)
	dummy.set_pulse_enabled(true)
	assert_eq(dummy.get_pulse_phase(), OFF)
	_run(dummy, 1.05)
	assert_eq(dummy.get_pulse_phase(), TELEGRAPH)


func test_c20_the_hit_set_clears_at_the_next_telegraph() -> void:
	var dummy: DummyLogic = _pulsing()
	_run(dummy, 0.625)
	dummy.get_live_hitbox().mark_hit(&"player_1")
	assert_true(dummy.get_live_hitbox().has_hit(&"player_1"), "for the whole active phase")
	_run(dummy, 2.0)
	assert_false(dummy.get_live_hitbox().has_hit(&"player_1"))


func test_c7_hitstop_pauses_the_pulse() -> void:
	var dummy: DummyLogic = _pulsing()
	_hit(dummy, 1)
	_run(dummy, 0.6)
	assert_eq(dummy.get_pulse_phase(), TELEGRAPH, "0.05 of that was hitstop")
	_run(dummy, 0.075)
	assert_eq(dummy.get_pulse_phase(), ACTIVE)


func test_c18_pulse_in_progress_is_latched_and_new_values_apply_next_pulse() -> void:
	var dummy: DummyLogic = _pulsing()
	_run(dummy, 0.3)
	var data: DummyData = _data()
	data.pulse_damage = 77
	assert_true(dummy.apply_data(data, 120))
	_run(dummy, 0.325)
	assert_eq(dummy.get_live_hitbox().damage, 20)
	_run(dummy, 2.0)
	assert_eq(dummy.get_live_hitbox().damage, 77)


func test_c18_reload_clamps_hp_and_invalid_data_changes_nothing() -> void:
	var dummy: DummyLogic = _dummy()
	var data: DummyData = _data()
	data.max_hp = 50
	assert_true(dummy.apply_data(data, 120))
	assert_eq(dummy.get_combat_state().get_hp(), 50)
	data = _data()
	data.pulse_radius_tiles = 0.0
	assert_false(dummy.apply_data(data, 120))
	assert_push_error("data rejected")
	assert_eq(dummy.get_combat_state().get_max_hp(), 50)


func _dummy(knockback_scale: float = 0.0) -> DummyLogic:
	var dummy: DummyLogic = DummyLogic.new()
	dummy.setup(_data(), 120, Vector2.ZERO, knockback_scale, &"dummy_a")
	return dummy


func _pulsing() -> DummyLogic:
	var dummy: DummyLogic = _dummy()
	dummy.set_pulse_enabled(true)
	return dummy


func _data() -> DummyData:
	return (load(Tunables.TRAINING_DUMMY_PATH) as DummyData).duplicate()


func _run(dummy: DummyLogic, seconds: float) -> void:
	for _i: int in roundi(seconds * 120.0):
		dummy.step(STEP)
		dummy.finish_tick()


func _hit(dummy: DummyLogic, damage: int, knockback: float = 0.0) -> void:
	var event: HitEvent = HitEvent.new()
	event.attacker_id = &"player_1"
	event.target_id = dummy.get_combat_id()
	event.damage = damage
	event.direction = Vector2.DOWN
	event.knockback_tiles = knockback * dummy.get_knockback_scale()
	dummy.apply_hit(event, _rules)
