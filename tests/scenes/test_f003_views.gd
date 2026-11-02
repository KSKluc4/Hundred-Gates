extends F003SceneTest
## The rest of AC1, then AC16, AC20 and AC21 through the real scene.

const LAST_ACTIVE_TICKS: int = 8


func test_ac1_hp_display_re_syncs_after_a_restore() -> void:
	await spawn(_place_dummy_in_reach)
	var snapshot: Dictionary = _runner.take_snapshot()
	await run_ticks(8, true)
	assert_eq(_anchored.logic.get_combat_state().get_hp(), 190)
	_runner.restore_snapshot(snapshot)
	assert_eq(_anchored.get_hp_text(), "200 / 200")
	assert_string_contains(_player_hp_line(await overlay_text()), "100 / 100")


func test_ac1_debug_arc_comes_back_when_restoring_into_active() -> void:
	await spawn(_place_dummy_out_of_reach)
	await run_ticks(LAST_ACTIVE_TICKS - 2, true)
	assert_eq(_debug_draw.get_live_hitboxes().size(), 1, "the swing is active at 0.1")
	var snapshot: Dictionary = _runner.take_snapshot()
	await run_ticks(10)
	assert_eq(_debug_draw.get_live_hitboxes().size(), 0)
	_runner.restore_snapshot(snapshot)
	assert_eq(_debug_draw.get_live_hitboxes().size(), 1)


func test_ac1_debug_arc_goes_away_when_restoring_out_of_active() -> void:
	await spawn(_place_dummy_out_of_reach)
	var snapshot: Dictionary = _runner.take_snapshot()
	await run_ticks(LAST_ACTIVE_TICKS - 2, true)
	assert_eq(_debug_draw.get_live_hitboxes().size(), 1)
	_runner.restore_snapshot(snapshot)
	assert_eq(_debug_draw.get_live_hitboxes().size(), 0)


func test_ac1_a_restore_clears_damage_numbers_and_shake() -> void:
	await spawn(_place_dummy_in_reach)
	var snapshot: Dictionary = _runner.take_snapshot()
	await run_ticks(8, true)
	assert_eq(_anchored.get_damage_numbers().get_labels().size(), 1)
	assert_gt(_shake.get_current_intensity(), 0.0)
	_runner.restore_snapshot(snapshot)
	assert_eq(_anchored.get_damage_numbers().get_labels().size(), 0)
	assert_eq(_shake.get_current_intensity(), 0.0)


func test_ac31_debug_draw_shows_every_hurtbox() -> void:
	await spawn()
	assert_eq(_debug_draw.get_hurtboxes().size(), 3)


func test_ac16_at_zero_the_player_emits_died_and_the_debug_scene_refills() -> void:
	await spawn(_place_lethal_pulse)
	var state: CombatState = _player.motor.get_combat_state()
	watch_signals(state)
	_runner.toggle_pulse()
	await run_ticks(4)
	assert_signal_emit_count(state, "died", 1)
	assert_eq(state.get_hp(), 100, "refilled")
	assert_true(state.is_hurt_protected(), "and nothing else happened")


func test_ac20_overlay_shows_player_hp_and_the_combat_state() -> void:
	await spawn()
	var text: String = await overlay_text()
	for expected: String in [
		"player hp: 100 / 100",
		"chain: next hit 1",
		"phase: NONE",
		"chain window: 0.00",
		"buffered attack: no",
		"buffered dash: no",
		"hitstop: 0.00",
		"hurt i-frames: 0.00",
		"shake: on",
		"pulse: off",
	]:
		assert_string_contains(text, expected)


func test_ac20_overlay_speed_reads_the_motor() -> void:
	await spawn()
	await run_ticks(20, false, false, Vector2.RIGHT)
	# Read right after the ticks: one more, with no input, would already be slowing down.
	var overlay: MotorDebugOverlay = _scene.get_node("MotorDebugOverlay")
	assert_string_contains(overlay._build_text(), "velocity: 5.00 tiles/s")


func test_ac21_a_normal_hit_by_the_local_player_shakes_at_its_intensity() -> void:
	await spawn(_place_dummy_in_reach)
	await run_ticks(8, true)
	assert_eq(_shake._intensity, 0.2)


func test_ac21_the_finisher_shakes_at_its_own_intensity() -> void:
	await spawn(_place_dummy_in_reach)
	_shake.shake_enabled = false
	await run_ticks(24, true)
	await run_ticks(12, true)
	_shake.shake_enabled = true
	await run_ticks(24, true)
	assert_eq(_player.motor.get_attack_chain().get_attack_id(), &"sword_hit_3")
	assert_eq(_shake._intensity, 0.5)


func test_ac21_damaged_on_the_local_player_shakes_at_its_intensity() -> void:
	await spawn(_place_quick_pulse)
	_runner.toggle_pulse()
	await run_ticks(3)
	assert_eq(_shake._intensity, 0.6)


func test_ac21_with_the_flag_off_there_is_no_shake_at_all() -> void:
	await spawn(_place_dummy_in_reach)
	_shake.apply_settings(_shake_settings(false))
	await run_ticks(8, true)
	assert_eq(_shake.get_current_intensity(), 0.0)
	assert_eq(_shake.offset, Vector2.ZERO)


func test_ac21_the_key_toggles_shake_at_runtime() -> void:
	await spawn(_place_dummy_in_reach)
	press_key(KEY_K)
	assert_string_contains(await overlay_text(), "shake: off")
	await run_ticks(8, true)
	assert_eq(_shake.get_current_intensity(), 0.0)
	press_key(KEY_K)
	assert_string_contains(await overlay_text(), "shake: on")


func test_c10_shake_offset_stays_inside_its_limit_and_decays_to_nothing() -> void:
	await spawn()
	_shake.shake(0.5)
	_shake._process(0.0)
	assert_lte(_shake.offset.length(), 0.5 * 6.0 + 0.0001)
	_shake._process(1.0)
	assert_eq(_shake.offset, Vector2.ZERO)


func test_c10_a_new_shake_takes_the_larger_intensity_never_the_sum() -> void:
	await spawn()
	_shake.shake(0.5)
	_shake.shake(0.2)
	assert_almost_eq(_shake.get_current_intensity(), 0.5, 0.05)
	_shake.shake(0.6)
	assert_almost_eq(_shake.get_current_intensity(), 0.6, 0.05)


func _player_hp_line(text: String) -> String:
	for line: String in text.split("\n"):
		if line.begins_with("player hp"):
			return line
	return ""


func _place_dummy_in_reach() -> void:
	_player.position = Vector2(240, 160)
	_anchored.position = Vector2(240, 176)
	_loose.position = Vector2(40, 40)


func _place_dummy_out_of_reach() -> void:
	_player.position = Vector2(240, 160)
	_anchored.position = Vector2(240, 60)
	_loose.position = Vector2(40, 40)


func _place_quick_pulse() -> void:
	_place_dummy_in_reach()
	_anchored.data = quick_pulse()


func _place_lethal_pulse() -> void:
	_place_dummy_in_reach()
	_anchored.data = quick_pulse(500)


func _shake_settings(enabled: bool) -> ScreenShakeSettings:
	var settings: ScreenShakeSettings = (
		(load(Tunables.SCREEN_SHAKE_PATH) as ScreenShakeSettings).duplicate()
	)
	settings.screen_shake_enabled = enabled
	return settings
