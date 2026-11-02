extends F003SceneTest
## F-003/C12, C19 (CR-2): after a restore the toggle reads the restored dummy, so the overlay
## tells the truth and one P press acts on the real pulse.


func test_restoring_an_on_snapshot_over_an_off_setting() -> void:
	await spawn()
	press_key(KEY_P)
	var snapshot: Dictionary = _runner.take_snapshot()
	press_key(KEY_P)
	assert_true(_runner.restore_snapshot(snapshot))
	assert_true(_anchored.logic.is_pulse_enabled())
	assert_string_contains(await overlay_text(), "pulse: on")
	press_key(KEY_P)
	assert_false(_anchored.logic.is_pulse_enabled(), "one press turns the real pulse off")
	assert_string_contains(await overlay_text(), "pulse: off")


func test_restoring_an_off_snapshot_over_an_on_setting() -> void:
	await spawn()
	var snapshot: Dictionary = _runner.take_snapshot()
	press_key(KEY_P)
	assert_true(_runner.restore_snapshot(snapshot))
	assert_false(_anchored.logic.is_pulse_enabled())
	assert_string_contains(await overlay_text(), "pulse: off")
	press_key(KEY_P)
	assert_true(_anchored.logic.is_pulse_enabled(), "one press turns the real pulse on")
	assert_string_contains(await overlay_text(), "pulse: on")


func test_restoring_an_on_snapshot_into_a_fresh_scene() -> void:
	await spawn()
	press_key(KEY_P)
	await run_ticks(3)
	var snapshot: Dictionary = _runner.take_snapshot()
	_scene.free()
	await spawn()
	assert_string_contains(await overlay_text(), "pulse: off")
	assert_true(_runner.restore_snapshot(snapshot))
	assert_true(_anchored.logic.is_pulse_enabled())
	assert_string_contains(await overlay_text(), "pulse: on")
	press_key(KEY_P)
	assert_false(_anchored.logic.is_pulse_enabled(), "one press turns the real pulse off")
	assert_string_contains(await overlay_text(), "pulse: off")


func test_the_loose_dummy_stays_out_of_it_after_a_restore() -> void:
	await spawn()
	var snapshot: Dictionary = _runner.take_snapshot()
	press_key(KEY_P)
	_runner.restore_snapshot(snapshot)
	press_key(KEY_P)
	assert_false(_loose.logic.is_pulse_enabled(), "only the anchored dummy pulses")
