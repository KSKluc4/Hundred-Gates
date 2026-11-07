extends F004SceneTest
## AC22 and AC23 through the real keys and views: I, R, F5, HP bar, damage numbers, death look,
## debug label and telegraph, and every view re-syncing after a restore and a reset (C14).

## 1.25 tiles below the player: in range at once, so chaser_1 starts a windup on the first step.
const IN_RANGE: Vector2 = Vector2(0, 20)
## One tile below the player: inside the sword's first hit, aiming down.
const IN_REACH: Vector2 = Vector2(0, 16)


func test_ac22_i_toggles_ai_for_every_enemy() -> void:
	await spawn_fresh(place_oracle)
	assert_string_contains(await overlay_text(), "ai: on")
	press_key(KEY_I)
	for chaser: Enemy in _chasers:
		assert_false(chaser.logic.is_ai_enabled(), String(chaser.combat_id))
	assert_string_contains(await overlay_text(), "ai: off")
	press_key(KEY_I)
	for chaser: Enemy in _chasers:
		assert_true(chaser.logic.is_ai_enabled(), String(chaser.combat_id))
	assert_string_contains(await overlay_text(), "ai: on")


func test_ac22_with_ai_off_an_aggro_range_chaser_holds_still() -> void:
	await spawn_fresh(place_oracle)
	press_key(KEY_I)
	var start: Vector2 = _chasers[0].global_position
	await run_ticks(60)
	assert_eq(_chasers[0].global_position, start)
	assert_eq(_chasers[0].logic.get_state(), EnemyLogic.State.IDLE)
	assert_eq(_player.motor.get_combat_state().get_hp(), 100)


func test_ac22_r_gives_the_same_state_as_a_fresh_setup_and_keeps_the_ai_setting() -> void:
	await spawn_fresh(_place_in_reach)
	var fresh: Dictionary = _runner.take_snapshot()
	await run_ticks(10, true)  # The sword hits chaser_1, which then swings back.
	await run_ticks(50)
	assert_lt(_chasers[0].logic.get_combat_state().get_hp(), 50, "a mess was made")
	press_key(KEY_I)
	press_key(KEY_R)
	var after: Dictionary = _runner.take_snapshot()
	for chaser: Enemy in _chasers:
		assert_false(chaser.logic.is_ai_enabled(), "the AI setting survives")
		assert_eq(chaser.global_position, chaser.logic.get_position_px())
		assert_eq(chaser.get_damage_numbers().get_labels().size(), 0)
	_forget_ai(fresh)
	_forget_ai(after)
	fresh["time"] = 0.0
	after["time"] = 0.0
	assert_eq_deep(after, fresh)
	assert_eq(_chasers[0].global_position, CENTRE + IN_REACH)


func test_ac22_f5_reloads_in_this_scene() -> void:
	await spawn_fresh()
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")


func test_ac22_hp_bar_damage_number_and_debug_label() -> void:
	await spawn_fresh(_place_in_reach)
	press_key(KEY_I)
	var chaser: Enemy = _chasers[0]
	assert_eq(chaser.get_hp_fraction(), 1.0)
	await run_ticks(10, true)
	assert_eq(chaser.logic.get_combat_state().get_hp(), 40)
	assert_almost_eq(chaser.get_hp_fraction(), 0.8, 0.000001, "the bar follows HP")
	assert_eq(chaser.get_damage_numbers().get_labels().size(), 1, "a damage number")
	press_key(KEY_I)
	await run_ticks(20)  # The push ends and it comes back for the player.
	await wait_process_frames(1)
	var label: String = (chaser.get_node("DebugLabel") as Label).text
	assert_string_contains(label, EnemyLogic.State.find_key(chaser.logic.get_state()))
	assert_string_contains(label, "cd %.2f" % chaser.logic.get_cooldown_remaining())
	assert_string_contains(label, "> player_1")


func test_ac22_death_look_and_body() -> void:
	await spawn_fresh(_place_weak_in_reach)
	press_key(KEY_I)
	var chaser: Enemy = _chasers[0]
	watch_signals(chaser.logic.get_combat_state())
	await run_ticks(10, true)
	assert_signal_emit_count(chaser.logic.get_combat_state(), "died", 1)
	assert_eq(chaser.logic.get_state(), EnemyLogic.State.DEAD)
	assert_eq(chaser.get_body_color(), chaser.dead_color)
	assert_eq(chaser.get_hp_fraction(), 0.0)
	assert_eq(chaser.collision_layer, 0)
	assert_eq(chaser.collision_mask, 0)
	assert_eq(chaser.get_telegraph(), Enemy.Telegraph.NONE)
	assert_true(_runner.get_sim().get_combatants().has(chaser.logic), "still registered")


func test_ac22_a_restore_and_a_reset_bring_a_dead_chaser_back_to_life() -> void:
	await spawn_fresh(_place_weak_in_reach)
	press_key(KEY_I)
	var chaser: Enemy = _chasers[0]
	var alive: Dictionary = _runner.take_snapshot()
	await run_ticks(10, true)
	assert_eq(chaser.logic.get_state(), EnemyLogic.State.DEAD)
	assert_true(_runner.restore_snapshot(alive))
	_assert_alive_look(chaser, "restore")
	await run_ticks(10, true)
	assert_eq(chaser.logic.get_state(), EnemyLogic.State.DEAD)
	press_key(KEY_R)
	_assert_alive_look(chaser, "reset")


func test_ac23_telegraph_tracks_then_locks_then_strikes_then_opens() -> void:
	await spawn_fresh(_place_in_range)
	var chaser: Enemy = _chasers[0]
	await run_ticks(10)  # 0.17: tracking.
	assert_eq(chaser.get_telegraph(), Enemy.Telegraph.TRACKING)
	assert_eq(chaser.logic.get_aim(), Vector2.UP, "points at the player")
	assert_eq(chaser.get_body_color(), chaser.body_color)
	await run_ticks(15)  # 0.42: past the 0.3 lock.
	assert_eq(chaser.get_telegraph(), Enemy.Telegraph.LOCKED)
	await run_ticks(10)  # 0.58: active, after the hit's 0.05 s of hitstop (no hitbox in it).
	assert_eq(chaser.get_telegraph(), Enemy.Telegraph.ACTIVE)
	assert_eq(_debug_draw.get_live_hitboxes().size(), 1, "the debug sector too")
	await run_ticks(15)  # 0.83: recovery, the punish window.
	assert_eq(chaser.logic.get_state(), EnemyLogic.State.RECOVERY)
	assert_eq(chaser.get_telegraph(), Enemy.Telegraph.NONE)
	assert_eq(chaser.get_body_color(), chaser.open_color)


func test_ac22_every_view_re_syncs_after_a_restore() -> void:
	await spawn_fresh(_place_in_range)
	var chaser: Enemy = _chasers[0]
	await run_ticks(10)
	var tracking: Dictionary = _runner.take_snapshot()
	await run_ticks(40)  # Into recovery, after the swing hit the player.
	assert_eq(chaser.get_body_color(), chaser.open_color)
	assert_true(_runner.restore_snapshot(tracking))
	assert_eq(chaser.get_telegraph(), Enemy.Telegraph.TRACKING)
	assert_eq(chaser.get_body_color(), chaser.body_color)
	assert_string_contains((chaser.get_node("DebugLabel") as Label).text, "WINDUP")
	assert_eq(chaser.global_position, chaser.logic.get_position_px())
	assert_eq(_player.global_position, _player.motor.get_position_px())


func _assert_alive_look(chaser: Enemy, label: String) -> void:
	assert_ne(chaser.logic.get_state(), EnemyLogic.State.DEAD, label)
	assert_eq(chaser.get_body_color(), chaser.body_color, label)
	assert_eq(chaser.get_hp_fraction(), 1.0, label)
	assert_eq(chaser.collision_layer, 4, "%s: enemy layer" % label)
	assert_eq(chaser.collision_mask, 5, "%s: world + enemy" % label)
	assert_string_contains((chaser.get_node("DebugLabel") as Label).text, "IDLE", label)


func _forget_ai(snapshot: Dictionary) -> void:
	var entries: Dictionary = snapshot["combatants"]
	for id: StringName in [&"chaser_1", &"chaser_2", &"chaser_3"]:
		(entries[id] as Dictionary).erase("ai_enabled")


func _place_in_range() -> void:
	place_oracle()
	_chasers[0].position = CENTRE + IN_RANGE


func _place_in_reach() -> void:
	place_oracle()
	_chasers[0].position = CENTRE + IN_REACH


func _place_weak_in_reach() -> void:
	_place_in_reach()
	var weak: EnemyData = chaser_copy()
	weak.max_hp = 5
	_chasers[0].data = weak
