extends F003SceneTest
## AC19's key, AC30's reset and AC18 in the real scene, through the real keys.

const NEAR_ANCHORED: Vector2 = Vector2(240, 160)


func test_ac19_pulse_is_off_by_default_and_p_toggles_it() -> void:
	await spawn()
	assert_false(_anchored.logic.is_pulse_enabled())
	press_key(KEY_P)
	assert_true(_anchored.logic.is_pulse_enabled())
	assert_false(_loose.logic.is_pulse_enabled(), "only the anchored dummy pulses")
	assert_string_contains(await overlay_text(), "pulse: on")
	press_key(KEY_P)
	assert_false(_anchored.logic.is_pulse_enabled())


func test_ac19_ring_shows_on_the_anchored_dummy_when_toggled_on() -> void:
	await spawn()
	press_key(KEY_P)
	assert_true(_anchored.is_ring_visible())
	assert_false(_loose.is_ring_visible())


func test_ac18_anchored_never_moves_and_loose_is_pushed_and_stays() -> void:
	await spawn(_place_both_in_reach)
	var anchored_start: Vector2 = _anchored.global_position
	var loose_start: Vector2 = _loose.global_position
	await run_ticks(30, true)
	assert_eq(_anchored.logic.get_combat_state().get_hp(), 190)
	assert_eq(_loose.logic.get_combat_state().get_hp(), 190)
	assert_eq(_anchored.global_position, anchored_start)
	var landed: Vector2 = _loose.global_position
	assert_gt(landed.distance_to(loose_start), Units.tiles_to_px(0.29), "0.3 tiles of knockback")
	await run_ticks(30)
	assert_eq(_loose.global_position, landed, "stays where it lands")


func test_ac18_ko_shows_in_the_scene_and_the_dummy_comes_back() -> void:
	var weak: DummyData = (load(Tunables.TRAINING_DUMMY_PATH) as DummyData).duplicate()
	weak.max_hp = 5
	weak.respawn_delay = 0.2
	await spawn(
		func() -> void:
			_place_both_in_reach()
			_anchored.data = weak
	)
	await run_ticks(8, true)
	assert_true(_anchored.logic.is_ko())
	await wait_process_frames(1)
	assert_true(_anchored.is_ko_visible())
	await run_ticks(20)
	await wait_process_frames(1)
	assert_false(_anchored.logic.is_ko())
	assert_false(_anchored.is_ko_visible())
	assert_eq(_anchored.get_hp_text(), "5 / 5")


func test_ac30_r_gives_the_same_state_as_a_fresh_setup() -> void:
	await spawn(_place_both_in_reach)
	var fresh: Dictionary = _runner.take_snapshot()
	await _make_a_mess()
	press_key(KEY_R)
	var after: Dictionary = _runner.take_snapshot()
	# The pulse setting survives on purpose, the rest must match.
	_forget_pulse(fresh)
	_forget_pulse(after)
	fresh["time"] = 0.0
	after["time"] = 0.0
	assert_eq_deep(after, fresh)
	assert_eq(_player.global_position, NEAR_ANCHORED)
	assert_eq(_player.motor.get_position_px(), NEAR_ANCHORED)
	assert_eq(_anchored.get_damage_numbers().get_labels().size(), 0)
	assert_eq(_shake.get_current_intensity(), 0.0)


func test_ac30_pulse_and_shake_settings_survive_and_the_pulse_restarts() -> void:
	await spawn(_place_both_in_reach)
	press_key(KEY_K)
	press_key(KEY_P)
	await run_ticks(50)
	press_key(KEY_R)
	assert_true(_anchored.logic.is_pulse_enabled())
	assert_eq(_anchored.logic.get_pulse_phase(), PulseCycle.Phase.TELEGRAPH)
	assert_false(_shake.shake_enabled)


func test_c20_keys_act_between_ticks_so_a_reset_runs_no_step() -> void:
	await spawn()
	await run_ticks(5, false, false, Vector2.RIGHT)
	press_key(KEY_R)
	assert_eq(_player.motor.get_velocity_tiles(), Vector2.ZERO)
	assert_eq(_player.motor.to_dict()["time"], 0.0)


func test_ac4_the_real_attack_key_reaches_the_motor_as_one_press() -> void:
	await spawn()
	_player.input_enabled = true
	send_key(KEY_J, true)
	await wait_physics_frames(2)
	send_key(KEY_J, false)
	assert_eq(_player.motor.get_state(), PlayerMotor.State.ATTACKING, "J attacks")
	assert_eq(_player.motor.get_attack_chain().get_attack_id(), &"sword_hit_1")
	await wait_physics_frames(45)
	assert_eq(_player.motor.get_state(), PlayerMotor.State.IDLE, "held once, swung once")


func test_ac31_f001_scene_keeps_its_keys_to_itself() -> void:
	var scene: Node = (load("res://scenes/debug/f001_movement.tscn") as PackedScene).instantiate()
	var player: Player = scene.get_node("Player")
	player.input_enabled = false
	add_child_autofree(scene)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var clock: float = player.motor.to_dict()["time"]
	assert_gt(clock, 0.0)
	press_key(KEY_R)
	assert_eq(player.motor.to_dict()["time"], clock, "R does nothing in F-001's scene")


func _make_a_mess() -> void:
	press_key(KEY_P)
	await run_ticks(30, true)  # Hits both dummies and moves the loose one.
	await run_ticks(1, true)
	await run_ticks(40)
	await run_ticks(1, true)
	await run_ticks(1, false, true)  # An attack running, with a dash buffered behind it.
	_anchored.logic.get_combat_state().apply_landed(HitEvent.new(), _player.get_tunables())


func _forget_pulse(snapshot: Dictionary) -> void:
	var entries: Dictionary = snapshot["combatants"]
	for id: StringName in [&"dummy_anchored", &"dummy_loose"]:
		var entry: Dictionary = entries[id]
		entry.erase("pulse")
		entry.erase("pulse_enabled")


func _place_both_in_reach() -> void:
	_player.position = NEAR_ANCHORED
	_anchored.position = NEAR_ANCHORED + Vector2(-6, 14)
	_loose.position = NEAR_ANCHORED + Vector2(6, 14)
