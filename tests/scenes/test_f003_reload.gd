extends F003SceneTest
## AC24 end to end, through the real F5 key. Works on user:// copies of every data file, so a
## failed test can never damage the real ones.

const HIT_PATHS: Array[String] = [
	"user://test_f003_hit_1.tres", "user://test_f003_hit_2.tres", "user://test_f003_hit_3.tres"
]
const CLASS_PATH: String = "user://test_f003_warrior.tres"
const RULES_PATH: String = "user://test_f003_rules.tres"
const DUMMY_PATH: String = "user://test_f003_dummy.tres"
const SHAKE_PATH: String = "user://test_f003_shake.tres"
const SLOW_WINDUP: float = 0.036
const ACTIVE_AT_240: float = 1.0 / 240.0


func before_each() -> void:
	super.before_each()
	var warrior: ClassData = load(Tunables.WARRIOR_PATH)
	for index: int in HIT_PATHS.size():
		assert_eq(ResourceSaver.save(warrior.attack_chain[index].duplicate(), HIT_PATHS[index]), OK)
	_write_class("id", &"warrior")
	_write(RULES_PATH, Tunables.player_combat, "stick_deadzone", 0.2)
	_write(DUMMY_PATH, load(Tunables.TRAINING_DUMMY_PATH), "max_hp", 200)
	_write(SHAKE_PATH, load(Tunables.SCREEN_SHAKE_PATH), "max_offset_px", 6.0)


func after_each() -> void:
	super.after_each()
	for path: String in HIT_PATHS + [CLASS_PATH, RULES_PATH, DUMMY_PATH, SHAKE_PATH]:
		DirAccess.remove_absolute(path)


func test_ac24_a_valid_reload_replaces_the_whole_group() -> void:
	await spawn(_use_copies)
	_write(RULES_PATH, Tunables.player_combat, "hitstop_normal", 0.07)
	_write(DUMMY_PATH, load(Tunables.TRAINING_DUMMY_PATH), "pulse_damage", 33)
	_write(SHAKE_PATH, load(Tunables.SCREEN_SHAKE_PATH), "max_offset_px", 9.0)
	_write_class("attack_chain_window", 0.5)
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_eq(Tunables.player_combat.hitstop_normal, 0.07)
	assert_eq(_runner.get_sim().get_tunables().hitstop_normal, 0.07)
	assert_eq(_anchored.data.pulse_damage, 33)
	assert_eq(_loose.data.pulse_damage, 33)
	assert_eq(_shake.get_settings().max_offset_px, 9.0)
	assert_eq(_player.class_data.attack_chain_window, 0.5)


func test_ac24_a_valid_edit_to_one_attack_file_is_really_picked_up() -> void:
	await spawn(_use_copies)
	_write_hit(0, "damage", 33)
	press_key(KEY_F5)
	assert_eq(_player.class_data.attack_chain[0].damage, 33, "CACHE_MODE_IGNORE_DEEP")
	await run_ticks(10, true)
	assert_eq(_anchored.logic.get_combat_state().get_hp(), 167)


func test_ac24_an_invalid_value_in_any_one_file_rejects_the_whole_group() -> void:
	var edits: Array[Callable] = [
		_write_hit.bind(1, "active", 0.0),
		_write_class.bind("max_hp", 0),
		_write.bind(RULES_PATH, Tunables.player_combat, "hitstop_normal", -1.0),
		_write.bind(DUMMY_PATH, load(Tunables.TRAINING_DUMMY_PATH), "max_hp", 0),
		_write.bind(SHAKE_PATH, load(Tunables.SCREEN_SHAKE_PATH), "decay_time", 0.0),
	]
	for edit: Callable in edits:
		await spawn(_use_copies)
		var class_before: ClassData = _player.class_data
		var rules_before: PlayerCombatTunables = Tunables.player_combat
		var dummy_before: DummyData = _anchored.data
		var shake_before: ScreenShakeSettings = _shake.get_settings()
		_write(DUMMY_PATH, load(Tunables.TRAINING_DUMMY_PATH), "pulse_damage", 33)
		edit.call()
		press_key(KEY_F5)
		assert_string_contains(await overlay_text(), "reload: reload rejected: ")
		assert_eq(_player.class_data, class_before)
		assert_eq(Tunables.player_combat, rules_before)
		assert_eq(_anchored.data, dummy_before)
		assert_eq(_shake.get_settings(), shake_before)
		_scene.queue_free()
		_write(DUMMY_PATH, load(Tunables.TRAINING_DUMMY_PATH), "max_hp", 200)
		_write(SHAKE_PATH, load(Tunables.SCREEN_SHAKE_PATH), "decay_time", 0.2)
		_write(RULES_PATH, _tunables_before, "hitstop_normal", 0.05)
		_write_class("max_hp", 100)
		_write_hit(1, "active", 0.06)


func test_ac24_a_missing_file_rejects_the_whole_group() -> void:
	await spawn(_use_copies)
	DirAccess.remove_absolute(DUMMY_PATH)
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "could not load")


func test_ac24_a_reload_during_an_attack_lets_that_hit_finish_on_its_latched_values() -> void:
	await spawn(_use_copies)
	await run_ticks(2, true)
	_write_hit(0, "damage", 33)
	_write_hit(1, "damage", 44)
	press_key(KEY_F5)
	await run_ticks(20)
	assert_eq(_anchored.logic.get_combat_state().get_hp(), 190, "hit 1 keeps its 10")
	await run_ticks(20, true)
	assert_eq(_anchored.logic.get_combat_state().get_hp(), 146, "the next hit uses the new 44")


func test_ac24_a_reload_during_knockback_keeps_that_knockback() -> void:
	await spawn(_use_copies_with_a_knockback_pulse)
	_runner.toggle_pulse()
	await run_ticks(2)
	var state: CombatState = _player.motor.get_combat_state()
	assert_true(state.has_knockback())
	var left: float = state.get_knockback_time_left()
	_write(RULES_PATH, Tunables.player_combat, "knockback_duration", 2.0)
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_lte(state.get_knockback_time_left(), left)
	assert_almost_eq(state.get_knockback_velocity().length(), 1.0 / 0.12, 0.001, "latched")


func test_ac24_lowering_max_hp_below_current_hp_clamps_it() -> void:
	await spawn(_use_copies)
	_write_class("max_hp", 40)
	_write(DUMMY_PATH, load(Tunables.TRAINING_DUMMY_PATH), "max_hp", 30)
	press_key(KEY_F5)
	assert_eq(_player.motor.get_combat_state().get_hp(), 40)
	assert_eq(_anchored.logic.get_combat_state().get_hp(), 30)


func test_c18_the_file_replaces_the_k_toggle() -> void:
	await spawn(_use_copies)
	press_key(KEY_K)
	assert_false(_shake.shake_enabled)
	press_key(KEY_F5)
	assert_true(_shake.shake_enabled, "screen_shake_enabled = true in the file")


func test_c18_a_reload_leaves_a_running_shake_alone_and_the_next_one_takes_the_new_look() -> void:
	await spawn(_use_copies)
	_shake.set_process(false)  # This test drives the time itself.
	_shake.shake(0.5)
	_write_shake_look(0.01, 60.0)
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_eq(_shake.get_settings().decay_time, 0.01, "the new file is in")
	assert_almost_eq(_shake.get_current_intensity(), 0.5, 0.000001, "not 10.0")
	assert_almost_eq(_shake.get_offset_limit_px(), 3.0, 0.000001, "not 60 px, or 300")
	_shake._process(0.1)  # Half of the running shake's 0.2 s.
	assert_almost_eq(_shake.get_current_intensity(), 0.25, 0.000001, "the old decay still runs")
	assert_lte(_shake.offset.length(), 1.5 + 0.000001)
	_shake.shake(0.2)
	assert_almost_eq(_shake.get_offset_limit_px(), 15.0, 0.000001, "0.25 × the new 60 px")
	_shake._process(0.005)  # Half of the new 0.01 s.
	assert_almost_eq(_shake.get_current_intensity(), 0.125, 0.000001, "the new decay")


func test_ac24_rate_240_to_120_is_rejected_during_a_short_hit() -> void:
	await _spawn_at_240()
	var times: Array[float] = _record_hits()
	await run_ticks(2, true)
	var rate_120: PlayerCombatTunables = _rules_at(120)
	_prepare_files_valid_at_120(rate_120)
	press_key(KEY_F5)
	var text: String = await overlay_text()
	assert_string_contains(text, "reload rejected: running hit or pulse on player_1")
	assert_eq(_runner.get_sim().get_step_rate(), 240, "nothing changed")
	await run_ticks(2)
	assert_eq(times.size(), 1)
	assert_almost_eq(times[0], 9.0 / 240.0, TIME, "the running hit still lands")


func test_ac24_rate_240_to_120_is_rejected_during_a_short_pulse() -> void:
	await _spawn_at_240()
	var times: Array[float] = _record_pulses()
	_runner.toggle_pulse()
	await run_ticks(2)
	_prepare_files_valid_at_120(_rules_at(120))
	press_key(KEY_F5)
	var text: String = await overlay_text()
	assert_string_contains(text, "reload rejected: running hit or pulse on dummy_anchored")
	assert_eq(_runner.get_sim().get_step_rate(), 240)
	await run_ticks(2)
	assert_eq(times.size(), 1)
	assert_almost_eq(times[0], 9.0 / 240.0, TIME, "the running pulse still lands")


func test_ac24_the_same_reload_is_accepted_once_the_hit_is_in_recovery() -> void:
	await _spawn_at_240()
	await run_ticks(8, true)
	assert_eq(_player.motor.get_attack_chain().get_phase(), AttackChain.Phase.RECOVERY)
	_prepare_files_valid_at_120(_rules_at(120))
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_eq(_runner.get_sim().get_step_rate(), 120)
	assert_eq(_player.combat_step_rate, 120)
	var probe: SimProbe = SimProbe.new()
	_runner.get_sim().register(probe)
	await get_tree().physics_frame
	var before: int = probe.steps
	await get_tree().physics_frame
	assert_eq(probe.steps - before, 2, "120 from the next tick, at 60 ticks/s")


func test_ac24_raising_the_rate_during_a_hit_is_accepted_and_the_hit_keeps_its_values() -> void:
	await spawn(_use_copies)
	await run_ticks(2, true)
	_write(RULES_PATH, Tunables.player_combat, "combat_step_rate", 240)
	_write_hit(0, "damage", 33)
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_eq(_runner.get_sim().get_step_rate(), 240)
	await run_ticks(20)
	assert_eq(_anchored.logic.get_combat_state().get_hp(), 190)


func _spawn_at_240() -> void:
	Tunables.player_combat = _rules_at(240)
	_write_hit(0, "windup", SLOW_WINDUP)
	_write_hit(0, "active", ACTIVE_AT_240)
	_write(RULES_PATH, _rules_at(240), "stick_deadzone", 0.2)
	var pulse: DummyData = (load(Tunables.TRAINING_DUMMY_PATH) as DummyData).duplicate()
	pulse.pulse_telegraph = SLOW_WINDUP
	pulse.pulse_active = ACTIVE_AT_240
	pulse.pulse_knockback_tiles = 0.0
	assert_eq(ResourceSaver.save(pulse, DUMMY_PATH), OK)
	await spawn(_use_copies)


func _rules_at(rate: int) -> PlayerCombatTunables:
	var rules: PlayerCombatTunables = _tunables_before.duplicate()
	rules.combat_step_rate = rate
	return rules


func _prepare_files_valid_at_120(rules: PlayerCombatTunables) -> void:
	assert_eq(ResourceSaver.save(rules, RULES_PATH), OK)
	_write_hit(0, "active", 0.06)
	_write(DUMMY_PATH, load(Tunables.TRAINING_DUMMY_PATH), "max_hp", 200)


func _record_hits() -> Array[float]:
	var start: float = _runner.get_sim().get_time()
	var times: Array[float] = []
	_player.motor.get_combat_state().hit_landed.connect(
		func(_event: HitEvent) -> void: times.append(_runner.get_sim().get_time() - start)
	)
	return times


func _record_pulses() -> Array[float]:
	var start: float = _runner.get_sim().get_time()
	var times: Array[float] = []
	_player.motor.get_combat_state().damaged.connect(
		func(_event: HitEvent) -> void: times.append(_runner.get_sim().get_time() - start)
	)
	return times


func _use_copies() -> void:
	_player.position = Vector2(240, 160)
	_anchored.position = Vector2(240, 176)
	_loose.position = Vector2(40, 40)
	_player.class_data = ResourceLoader.load(CLASS_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	_player.tunables_path = RULES_PATH
	_anchored.data = ResourceLoader.load(DUMMY_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	_loose.data = _anchored.data
	_runner.dummy_data_path = DUMMY_PATH
	_runner.shake_settings_path = SHAKE_PATH


func _use_copies_with_a_knockback_pulse() -> void:
	var pulse: DummyData = quick_pulse(20, 1.0)
	assert_eq(ResourceSaver.save(pulse, DUMMY_PATH), OK)
	_use_copies()


func _write(path: String, resource: Resource, field: String, value: Variant) -> void:
	var copy: Resource = resource.duplicate()
	copy.set(field, value)
	assert_eq(ResourceSaver.save(copy, path), OK)


func _write_shake_look(decay_time: float, max_offset_px: float) -> void:
	var settings: ScreenShakeSettings = (load(Tunables.SCREEN_SHAKE_PATH) as Resource).duplicate()
	settings.decay_time = decay_time
	settings.max_offset_px = max_offset_px
	assert_eq(ResourceSaver.save(settings, SHAKE_PATH), OK)


func _write_class(field: String, value: Variant) -> void:
	var data: ClassData = (load(Tunables.WARRIOR_PATH) as ClassData).duplicate()
	var chain: Array[AttackData] = []
	for path: String in HIT_PATHS:
		chain.append(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE))
	data.attack_chain = chain
	data.set(field, value)
	assert_eq(ResourceSaver.save(data, CLASS_PATH), OK)


func _write_hit(index: int, field: String, value: Variant) -> void:
	var path: String = HIT_PATHS[index]
	var hit: AttackData = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	hit.set(field, value)
	assert_eq(ResourceSaver.save(hit, path), OK)
