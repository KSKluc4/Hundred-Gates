extends F011SceneTest
## F-015 T2 (AC8, C13): the user's shake setting in the room's camera. The data's flag (the
## `screen_shake_enabled` of screen_shake.tres, which K and a reload set on the node) and the
## player's setting both have to be on. The settings go back to the defaults after each test.


func after_each() -> void:
	UserSettings.reset_to_defaults()
	await super.after_each()


func camera() -> PlaceholderShake:
	return room().get_camera()


func spawn() -> void:
	await spawn_floor(FloorFixtures.floor_of([FloorFixtures.arena_room()]))


func hurt_player() -> void:
	hit(player().motor, 5)


## The camera's _process runs after the frame signal: the second frame is the first with an offset.
func let_the_shake_move() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_with_the_default_setting_a_hit_shakes() -> void:
	await spawn()
	assert_eq(camera().get_current_intensity(), 0.0, "still before the hit")
	hurt_player()
	assert_gt(camera().get_current_intensity(), 0.0)


func test_with_the_setting_off_a_hit_that_shakes_today_does_not() -> void:
	await spawn()
	UserSettings.settings.screen_shake_enabled = false
	hurt_player()
	assert_eq(camera().get_current_intensity(), 0.0)
	for _frame: int in 5:
		await get_tree().process_frame
		assert_eq(camera().offset, Vector2.ZERO)
		assert_eq(camera().get_current_intensity(), 0.0)


func test_a_finisher_shake_is_refused_with_the_setting_off() -> void:
	await spawn()
	UserSettings.settings.screen_shake_enabled = false
	camera().shake(Tunables.player_combat.shake_intensity_finisher)
	assert_eq(camera().get_current_intensity(), 0.0)


func test_turning_the_setting_off_during_a_shake_clears_it_at_once() -> void:
	await spawn()
	hurt_player()
	await let_the_shake_move()
	assert_gt(camera().get_current_intensity(), 0.0, "a shake is running")
	assert_ne(camera().offset, Vector2.ZERO, "the picture is off centre")
	UserSettings.settings.screen_shake_enabled = false
	assert_eq(camera().offset, Vector2.ZERO)
	assert_eq(camera().get_current_intensity(), 0.0)
	await get_tree().process_frame
	assert_eq(camera().offset, Vector2.ZERO, "and it stays clear")


func test_turning_it_off_clears_the_shake_also_when_the_subtree_is_disabled() -> void:
	await spawn()
	hurt_player()
	await let_the_shake_move()
	assert_ne(camera().offset, Vector2.ZERO, "the picture is off centre")
	_floor.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	assert_ne(camera().offset, Vector2.ZERO, "frozen while disabled")
	UserSettings.settings.screen_shake_enabled = false
	assert_eq(camera().offset, Vector2.ZERO)
	assert_eq(camera().get_current_intensity(), 0.0)
	_floor.process_mode = Node.PROCESS_MODE_INHERIT


func test_turning_it_on_again_lets_the_next_hit_shake() -> void:
	await spawn()
	UserSettings.settings.screen_shake_enabled = false
	hurt_player()
	assert_eq(camera().get_current_intensity(), 0.0)
	UserSettings.settings.screen_shake_enabled = true
	assert_eq(camera().get_current_intensity(), 0.0, "turning it on starts nothing")
	camera().shake(Tunables.player_combat.shake_intensity_hit)
	assert_gt(camera().get_current_intensity(), 0.0)


func test_the_next_real_hit_shakes_after_off_and_on() -> void:
	await spawn()
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.screen_shake_enabled = true
	hurt_player()
	assert_gt(camera().get_current_intensity(), 0.0)


func test_a_change_of_another_setting_does_not_end_a_running_shake() -> void:
	await spawn()
	hurt_player()
	assert_gt(camera().get_current_intensity(), 0.0)
	UserSettings.settings.fullscreen = true
	assert_gt(camera().get_current_intensity(), 0.0)


func test_with_the_data_flag_off_the_setting_cannot_turn_shake_on() -> void:
	await spawn()
	var data: ScreenShakeSettings = camera().get_settings().duplicate()
	data.screen_shake_enabled = false
	camera().apply_settings(data)
	hurt_player()
	assert_eq(camera().get_current_intensity(), 0.0, "setting on, data off")
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.screen_shake_enabled = true
	camera().shake(Tunables.player_combat.shake_intensity_hit)
	assert_eq(camera().get_current_intensity(), 0.0, "still off after the setting came back on")
	assert_false(camera().shake_enabled)


func test_k_behaves_as_before_with_the_setting_on() -> void:
	await spawn()
	assert_true(camera().shake_enabled)
	camera().toggle()
	assert_false(camera().shake_enabled)
	hurt_player()
	assert_eq(camera().get_current_intensity(), 0.0)
	camera().toggle()
	assert_true(camera().shake_enabled)
	camera().shake(Tunables.player_combat.shake_intensity_hit)
	assert_gt(camera().get_current_intensity(), 0.0)


func test_k_and_the_setting_do_not_overwrite_each_other() -> void:
	await spawn()
	camera().toggle()  # K off
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.screen_shake_enabled = true
	assert_false(camera().shake_enabled, "the setting did not turn K's flag back on")
	camera().shake(Tunables.player_combat.shake_intensity_hit)
	assert_eq(camera().get_current_intensity(), 0.0, "K is still off")
	camera().toggle()  # K on
	UserSettings.settings.screen_shake_enabled = false
	assert_true(camera().shake_enabled, "the setting did not turn K's flag off")
	camera().shake(Tunables.player_combat.shake_intensity_hit)
	assert_eq(camera().get_current_intensity(), 0.0, "the setting is still off")
	UserSettings.settings.screen_shake_enabled = true
	camera().shake(Tunables.player_combat.shake_intensity_hit)
	assert_gt(camera().get_current_intensity(), 0.0)


func test_a_data_reload_with_the_flag_on_does_not_turn_the_setting_on() -> void:
	await spawn()
	UserSettings.settings.screen_shake_enabled = false
	camera().apply_settings(camera().get_settings())
	assert_true(camera().shake_enabled, "the data's flag, as before")
	hurt_player()
	assert_eq(camera().get_current_intensity(), 0.0)
	assert_false(UserSettings.settings.screen_shake_enabled)


func test_one_connection_per_camera_and_none_after_the_game_is_freed() -> void:
	var changed: Signal = UserSettings.settings.changed
	assert_eq(changed.get_connections().size(), 0, "nothing listens before the floor")
	await spawn()
	assert_eq(changed.get_connections().size(), 1, "the room's camera")
	_floor.restart_room()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(changed.get_connections().size(), 1, "the rebuilt room's camera only")
	_floor.free()
	await get_tree().process_frame
	assert_eq(changed.get_connections().size(), 0, "none after the floor is freed")
