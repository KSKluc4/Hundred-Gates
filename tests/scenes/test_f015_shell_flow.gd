# gdlint:disable=max-public-methods,max-file-lines
extends F015ShellTest
## F-015 T6 (AC9, AC18, AC19, AC20, AC26; C12, C14, C15): the shell's menus beyond the pause and the
## resume. The settings (applied, rewritten in place, saved), Settings and Back, the two confirms,
## leaving a floor, quitting to the title, and one press making one step. Menus are driven through
## `choose(id)` and through real key and pad events, posted between two ticks. 120 physics ticks/s,
## the player's input off.

const ESCAPE: Key = KEY_ESCAPE
const PAD_START: JoyButton = JOY_BUTTON_START
const PAD_B: JoyButton = JOY_BUTTON_B
const PAD_A: JoyButton = JOY_BUTTON_A
const FRAMES_TO_FREE: int = 2
## The shake of the test camera is long enough to still run when the test looks at it.
const LONG_DECAY_SECONDS: float = 60.0
const UNWRITABLE_DIR: String = "user://test_f015/no_such_dir"

# --- AC9: the two settings ---


func test_ac9_fullscreen_calls_the_applier_once_per_choice_with_the_new_mode() -> void:
	await spawn_shell()
	choose(ShellMenus.SETTINGS)
	assert_eq(
		window_modes(), [DisplayServer.WINDOW_MODE_WINDOWED] as Array[int], "start's call only"
	)
	choose(ShellMenus.FULLSCREEN)
	assert_true(UserSettings.settings.fullscreen)
	assert_eq(
		window_modes(),
		[DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN] as Array[int]
	)
	choose(ShellMenus.FULLSCREEN)
	assert_false(UserSettings.settings.fullscreen)
	assert_eq(
		window_modes(),
		(
			[
				DisplayServer.WINDOW_MODE_WINDOWED,
				DisplayServer.WINDOW_MODE_FULLSCREEN,
				DisplayServer.WINDOW_MODE_WINDOWED
			]
			as Array[int]
		),
		"once more, with the mode the choice made"
	)


func test_ac9_a_shake_choice_does_not_call_the_applier() -> void:
	await spawn_shell()
	choose(ShellMenus.SETTINGS)
	for _i: int in 3:
		choose(ShellMenus.SHAKE)
	assert_eq(window_modes().size(), 1, "only the call at start")
	assert_false(UserSettings.settings.screen_shake_enabled, "three flips from on")


func test_ac9_a_choice_rewrites_the_entry_in_place_and_the_focus_stays() -> void:
	await spawn_shell()
	choose(ShellMenus.SETTINGS)
	assert_eq(panel().get_entry_text(ShellMenus.SHAKE), ShellMenus.SHAKE_ON_TEXT)
	assert_eq(panel().get_entry_text(ShellMenus.FULLSCREEN), ShellMenus.FULLSCREEN_OFF_TEXT)
	var buttons: Array[int] = entry_button_ids()
	choose(ShellMenus.SHAKE)
	assert_eq(panel().get_entry_text(ShellMenus.SHAKE), ShellMenus.SHAKE_OFF_TEXT)
	assert_eq(panel().get_entry_text(ShellMenus.FULLSCREEN), ShellMenus.FULLSCREEN_OFF_TEXT)
	assert_eq(panel().get_focus_id(), ShellMenus.SHAKE, "the focus stays")
	choose(ShellMenus.FULLSCREEN)
	assert_eq(panel().get_entry_text(ShellMenus.FULLSCREEN), ShellMenus.FULLSCREEN_ON_TEXT)
	assert_eq(panel().get_entry_text(ShellMenus.SHAKE), ShellMenus.SHAKE_OFF_TEXT)
	assert_eq(entry_button_ids(), buttons, "the panel was not opened again: the same buttons")
	assert_eq(panel().get_heading(), ShellMenus.SETTINGS_HEADING)
	assert_true(panel().is_open())
	assert_eq(flow().get_state(), ShellFlow.State.SETTINGS)


func test_ac9_by_the_keyboard_and_the_pad_the_focus_stays_on_the_entry_chosen() -> void:
	await spawn_shell()
	choose(ShellMenus.SETTINGS)
	await focus_entry_by_keys(ShellMenus.FULLSCREEN)
	await tap_key(KEY_ENTER)
	assert_true(UserSettings.settings.fullscreen)
	assert_eq(panel().get_focus_id(), ShellMenus.FULLSCREEN, "Enter: the focus stays")
	await tap_pad(PAD_A)
	assert_false(UserSettings.settings.fullscreen)
	assert_eq(panel().get_focus_id(), ShellMenus.FULLSCREEN, "pad A: the focus stays")
	await tap_key(KEY_UP)
	await tap_key(KEY_SPACE)
	assert_false(UserSettings.settings.screen_shake_enabled)
	assert_eq(panel().get_focus_id(), ShellMenus.SHAKE)
	assert_eq(window_modes().size(), 3, "start, then the two fullscreen choices")


func test_ac9_each_choice_writes_the_file_at_the_shells_path() -> void:
	await spawn_shell()
	assert_false(FileAccess.file_exists(settings_file()), "nothing is written by loading")
	choose(ShellMenus.SETTINGS)
	choose(ShellMenus.SHAKE)
	assert_true(FileAccess.file_exists(settings_file()), "shake wrote it")
	assert_eq(_saved(), {"shake": false, "fullscreen": false})
	choose(ShellMenus.FULLSCREEN)
	assert_eq(_saved(), {"shake": false, "fullscreen": true})
	choose(ShellMenus.SHAKE)
	assert_eq(_saved(), {"shake": true, "fullscreen": true}, "every choice saves what is now")


func test_ac9_a_new_shell_on_the_same_path_starts_with_the_saved_values() -> void:
	await spawn_shell()
	choose(ShellMenus.SETTINGS)
	choose(ShellMenus.SHAKE)
	choose(ShellMenus.FULLSCREEN)
	shell().queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	UserSettings.reset_to_defaults()
	assert_true(UserSettings.settings.screen_shake_enabled, "back to the defaults in memory")
	window_modes().clear()
	await spawn_shell()
	assert_false(UserSettings.settings.screen_shake_enabled, "the saved shake")
	assert_true(UserSettings.settings.fullscreen, "the saved fullscreen")
	assert_eq(
		window_modes(),
		[DisplayServer.WINDOW_MODE_FULLSCREEN] as Array[int],
		"the applier is called once at start, with the loaded value"
	)
	choose(ShellMenus.SETTINGS)
	assert_eq(panel().get_entry_text(ShellMenus.SHAKE), ShellMenus.SHAKE_OFF_TEXT)
	assert_eq(panel().get_entry_text(ShellMenus.FULLSCREEN), ShellMenus.FULLSCREEN_ON_TEXT)


func test_ac9_an_empty_path_creates_no_file_and_still_applies() -> void:
	var prepare: Callable = func(shell_node: Shell) -> void: shell_node.settings_path = ""
	await spawn_shell(prepare)
	choose(ShellMenus.SETTINGS)
	choose(ShellMenus.SHAKE)
	choose(ShellMenus.FULLSCREEN)
	assert_false(UserSettings.settings.screen_shake_enabled)
	assert_true(UserSettings.settings.fullscreen)
	assert_eq(
		window_modes(),
		[DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN] as Array[int],
		"applied"
	)
	assert_eq(panel().get_entry_text(ShellMenus.SHAKE), ShellMenus.SHAKE_OFF_TEXT)
	assert_false(FileAccess.file_exists(settings_file()), "no file at the test's path")


func test_ac9_a_failed_save_changes_nothing_else() -> void:
	var path: String = "%s/settings.cfg" % UNWRITABLE_DIR
	var prepare: Callable = func(shell_node: Shell) -> void: shell_node.settings_path = path
	await spawn_shell(prepare)
	choose(ShellMenus.SETTINGS)
	choose(ShellMenus.FULLSCREEN)
	choose(ShellMenus.SHAKE)
	assert_false(FileAccess.file_exists(path), "the write failed")
	assert_true(UserSettings.settings.fullscreen, "the setting still applies for this run")
	assert_false(UserSettings.settings.screen_shake_enabled)
	assert_eq(panel().get_entry_text(ShellMenus.FULLSCREEN), ShellMenus.FULLSCREEN_ON_TEXT)
	assert_eq(panel().get_entry_text(ShellMenus.SHAKE), ShellMenus.SHAKE_OFF_TEXT)
	assert_eq(panel().get_focus_id(), ShellMenus.SHAKE)
	assert_eq(flow().get_state(), ShellFlow.State.SETTINGS)
	assert_eq(
		window_modes(),
		[DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN] as Array[int]
	)


func test_ac9_the_shell_does_not_listen_to_the_settings_changing() -> void:
	await spawn_shell()
	for connection: Dictionary in UserSettings.settings.changed.get_connections():
		var callable: Callable = connection["callable"]
		assert_ne(callable.get_object(), shell(), "no connection from the shell")
	UserSettings.settings.fullscreen = true  # Not by a choice: nobody applies it.
	UserSettings.settings.screen_shake_enabled = false
	assert_eq(window_modes().size(), 1, "only the call at start")
	assert_false(FileAccess.file_exists(settings_file()), "and nothing saved")


func test_ac9_the_settings_menu_shows_the_values_it_is_opened_with() -> void:
	UserSettings.settings.fullscreen = true
	UserSettings.settings.screen_shake_enabled = false
	var prepare: Callable = func(shell_node: Shell) -> void: shell_node.settings_path = ""
	await spawn_shell(prepare)
	choose(ShellMenus.SETTINGS)
	assert_eq(panel().get_entry_text(ShellMenus.SHAKE), ShellMenus.SHAKE_OFF_TEXT)
	assert_eq(panel().get_entry_text(ShellMenus.FULLSCREEN), ShellMenus.FULLSCREEN_ON_TEXT)
	choose(ShellMenus.BACK)
	choose(ShellMenus.SETTINGS)
	assert_eq(panel().get_entry_text(ShellMenus.SHAKE), ShellMenus.SHAKE_OFF_TEXT, "again")


func test_ac9_settings_from_the_pause_menu_work_the_same_and_the_game_stays_stopped() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await pause_with_escape()
	choose(ShellMenus.SETTINGS)
	choose(ShellMenus.FULLSCREEN)
	choose(ShellMenus.SHAKE)
	assert_eq(_saved(), {"shake": false, "fullscreen": true})
	assert_eq(window_modes().size(), 2, "start, then the fullscreen choice")
	_assert_stopped("after two choices")
	await get_tree().physics_frame
	_assert_stopped("a tick later")


## C13 through the shell: the room's camera follows the setting, also while the game is disabled.
func test_ac9_shake_off_in_the_pause_menu_clears_the_running_shake_at_once() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await enter_floor_through_gate(1)
	var camera: PlaceholderShake = room().get_camera()
	var long: ScreenShakeSettings = camera.get_settings().duplicate()
	long.decay_time = LONG_DECAY_SECONDS
	camera.apply_settings(long)
	hit(player().motor, 5)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(camera.get_current_intensity(), 0.0, "a shake is running")
	assert_ne(camera.offset, Vector2.ZERO, "the picture is off centre")
	await pause_with_escape()
	assert_ne(camera.offset, Vector2.ZERO, "frozen by the pause")
	choose(ShellMenus.SETTINGS)
	choose(ShellMenus.SHAKE)
	assert_false(UserSettings.settings.screen_shake_enabled)
	assert_eq(camera.offset, Vector2.ZERO, "cleared in the choice, the game being disabled")
	assert_eq(camera.get_current_intensity(), 0.0)
	_assert_stopped("the game is still stopped")
	await get_tree().process_frame
	assert_eq(camera.offset, Vector2.ZERO, "and it stays clear")


# --- AC18: Settings and Back ---


func test_ac18_pause_settings_back_returns_to_the_pause_menu_with_the_focus_on_settings() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await pause_with_escape()
	var sim_time: float = _sim_time()
	choose(ShellMenus.SETTINGS)
	assert_eq(flow().get_state(), ShellFlow.State.SETTINGS)
	assert_eq(panel().get_heading(), ShellMenus.SETTINGS_HEADING)
	assert_eq(
		panel().get_entry_ids(),
		[ShellMenus.SHAKE, ShellMenus.FULLSCREEN, ShellMenus.BACK] as Array[StringName]
	)
	assert_eq(panel().get_focus_id(), ShellMenus.SHAKE)
	_assert_stopped("in the settings")
	for _i: int in 5:
		await get_tree().physics_frame
		_assert_stopped("in the settings, a tick later")
	choose(ShellMenus.BACK)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	assert_eq(panel().get_heading(), ShellMenus.PAUSED_HEADING)
	assert_eq(panel().get_focus_id(), ShellMenus.SETTINGS)
	_assert_stopped("back in the pause menu")
	for _i: int in 5:
		await get_tree().physics_frame
		_assert_stopped("back in the pause menu, a tick later")
	assert_eq(_sim_time(), sim_time, "the sim's clock never moved")


func test_ac18_the_game_is_disabled_at_every_step_of_pause_settings_back() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await pause_with_escape()
	watch_signals(flow())
	choose(ShellMenus.SETTINGS)
	assert_false(shell().is_guarding())
	_assert_stopped("at once")
	choose(ShellMenus.BACK)
	assert_false(shell().is_guarding())
	_assert_stopped("at once")
	assert_signal_emit_count(flow(), "state_changed", 2)


func test_ac18_title_settings_back_returns_to_the_title_with_the_focus_on_settings() -> void:
	await spawn_shell()
	choose(ShellMenus.SETTINGS)
	assert_eq(flow().get_state(), ShellFlow.State.SETTINGS)
	assert_eq(panel().get_heading(), ShellMenus.SETTINGS_HEADING)
	assert_null(shell().get_game(), "no game behind the title's settings")
	assert_eq(_dim_color(), shell().title_color, "an opaque screen behind them too")
	choose(ShellMenus.BACK)
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)
	assert_eq(panel().get_heading(), ShellMenus.TITLE_HEADING)
	assert_eq(panel().get_focus_id(), ShellMenus.SETTINGS)
	assert_eq(_dim_color(), shell().title_color)
	assert_true(space_is_active())


func test_ac18_title_settings_back_by_the_keyboard() -> void:
	await spawn_shell()
	await focus_entry_by_keys(ShellMenus.SETTINGS)
	await tap_key(KEY_ENTER)
	assert_eq(flow().get_state(), ShellFlow.State.SETTINGS)
	await focus_entry_by_keys(ShellMenus.BACK)
	await tap_key(KEY_ENTER)
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)
	assert_eq(panel().get_focus_id(), ShellMenus.SETTINGS)


func test_ac18_escape_in_the_settings_from_pause_goes_back_one_step_only() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await pause_with_escape()
	choose(ShellMenus.SETTINGS)
	watch_signals(flow())
	await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "the pause menu, still open")
	assert_true(panel().is_open())
	assert_eq(panel().get_heading(), ShellMenus.PAUSED_HEADING)
	assert_eq(panel().get_focus_id(), ShellMenus.SETTINGS)
	assert_signal_emit_count(flow(), "state_changed", 1)
	_assert_stopped("the game stays stopped")
	for _i: int in 5:
		await get_tree().physics_frame
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "and stays there")


func test_ac18_escape_in_the_settings_from_the_title_goes_back_to_the_title() -> void:
	await spawn_shell()
	choose(ShellMenus.SETTINGS)
	await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)
	assert_eq(panel().get_focus_id(), ShellMenus.SETTINGS)
	await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.TITLE, "and Escape on the title does nothing")


func test_ac18_pad_b_and_pad_start_in_the_settings_go_back_one_step() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await pause_with_escape()
	for button: JoyButton in [PAD_B, PAD_START]:
		choose(ShellMenus.SETTINGS)
		await tap_pad(button)
		assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "pad button %d" % button)
		assert_eq(panel().get_focus_id(), ShellMenus.SETTINGS)


# --- AC19: Return to town ---


func test_ac19_the_confirm_opens_with_the_focus_on_keep_fighting() -> void:
	await _paused_on_a_floor()
	choose(ShellMenus.LEAVE)
	assert_eq(flow().get_state(), ShellFlow.State.CONFIRM_LEAVE)
	assert_eq(panel().get_heading(), ShellMenus.CONFIRM_LEAVE_HEADING)
	assert_eq(panel().get_body(), ShellMenus.CONFIRM_LEAVE_BODY)
	assert_eq(panel().get_entry_ids(), [ShellMenus.CONFIRM, ShellMenus.CANCEL] as Array[StringName])
	assert_eq(panel().get_entry_text(ShellMenus.CONFIRM), "Return to town")
	assert_eq(panel().get_entry_text(ShellMenus.CANCEL), "Keep fighting")
	assert_eq(panel().get_focus_id(), ShellMenus.CANCEL)
	_assert_stopped("the confirm keeps the game stopped")
	assert_eq(session().get_place(), TowerSession.Place.FLOOR)


func test_ac19_keep_fighting_returns_to_the_pause_menu_and_the_session_stays_on_the_floor() -> void:
	await _paused_on_a_floor()
	var floor_before: FloorScene = floor_scene()
	choose(ShellMenus.LEAVE)
	choose(ShellMenus.CANCEL)
	_assert_back_in_the_pause_menu(floor_before)


func test_ac19_escape_in_the_confirm_returns_to_the_pause_menu() -> void:
	await _paused_on_a_floor()
	var floor_before: FloorScene = floor_scene()
	choose(ShellMenus.LEAVE)
	await tap_key(ESCAPE)
	_assert_back_in_the_pause_menu(floor_before)


func test_ac19_keep_fighting_by_the_keyboard_and_the_pad() -> void:
	await _paused_on_a_floor()
	var floor_before: FloorScene = floor_scene()
	choose(ShellMenus.LEAVE)
	await tap_key(KEY_ENTER)  # The focus is on Keep fighting.
	_assert_back_in_the_pause_menu(floor_before)
	choose(ShellMenus.LEAVE)
	await tap_pad(PAD_B)
	_assert_back_in_the_pause_menu(floor_before)
	choose(ShellMenus.LEAVE)
	await tap_pad(PAD_START)
	_assert_back_in_the_pause_menu(floor_before)


func test_ac19_the_leave_entry_is_not_offered_in_the_town() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await pause_with_escape()
	assert_false(panel().get_entry_ids().has(ShellMenus.LEAVE))
	assert_false(flow().ask_leave(false), "and the flow refuses it")
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)


func test_ac19_confirming_shows_the_town_closes_the_menu_and_keeps_the_progress() -> void:
	await _paused_on_a_floor(TowerFixtures.tower_of(2, 1))
	var floor_before: FloorScene = floor_scene()
	var progress: Dictionary = session().get_progress().to_dict()
	var session_before: Dictionary = session().to_dict()
	choose(ShellMenus.LEAVE)
	await get_tree().process_frame  # Between two ticks.
	choose(ShellMenus.CONFIRM)
	assert_eq(session().get_place(), TowerSession.Place.TOWN, "the session knows at once")
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_false(panel().is_open(), "the menu is closed")
	assert_false(_dim().visible)
	assert_true(shell().is_guarding(), "the guard begins")
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED)
	assert_same(floor_scene(), floor_before, "the old floor stays on screen until the game runs")
	await wait_for_town()
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_false(is_instance_valid(floor_before), "the floor was freed")
	assert_eq(location(), "Town")
	assert_eq_deep(session().get_progress().to_dict(), progress)
	assert_ne(session().to_dict(), session_before, "only the place changed")
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT)
	assert_false(panel().is_open())
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_eq(hp(), max_hp(), "a living player at full HP")


func test_ac19_the_same_floor_starts_over_at_room_one_with_full_hp() -> void:
	await _paused_on_a_floor(TowerFixtures.tower_of(1, 2))
	assert_eq(floor_scene().get_run().get_room_index(), 0)
	set_hp(40)
	await run_ticks(2)
	choose(ShellMenus.LEAVE)
	choose(ShellMenus.CONFIRM)
	await wait_for_town()
	await enter_floor_through_gate(1)
	assert_eq(session().get_place(), TowerSession.Place.FLOOR)
	assert_eq(floor_scene().get_run().get_room_index(), 0, "room 1 again")
	assert_eq(hp(), max_hp(), "with full HP")
	assert_eq(location(), "Floor 1 · Room 1 / 2")


func test_ac19_a_boss_reached_stays_and_the_gate_offers_it() -> void:
	await _on_a_floor(TowerFixtures.tower_of(1, 2))
	skip_to_boss()
	assert_true(session().get_progress().is_boss_reached(1))
	var progress: Dictionary = session().get_progress().to_dict()
	await pause_with_escape()
	choose(ShellMenus.LEAVE)
	choose(ShellMenus.CONFIRM)
	await wait_for_town()
	assert_eq_deep(session().get_progress().to_dict(), progress)
	assert_true(session().get_progress().is_boss_reached(1))
	assert_false(session().get_progress().is_floor_cleared(1))
	await open_gate_menu()
	assert_eq(
		button_texts(),
		["Floor 1 — from the start", "Floor 1 — at the boss", GateMenu.STAY_TEXT] as Array[String]
	)
	await choose_entry(1, true)
	assert_eq(location(), "Floor 1 · Boss", "and it starts at the boss")


func test_ac19_a_cleared_floor_stays_cleared_when_it_is_left_by_choice() -> void:
	await _on_a_floor(TowerFixtures.tower_of(2, 1))
	skip_to_boss()
	kill_boss()
	await run_ticks(2)
	assert_true(session().get_progress().is_floor_cleared(1), "cleared during this visit")
	var progress: Dictionary = session().get_progress().to_dict()
	await pause_with_escape()
	choose(ShellMenus.LEAVE)
	choose(ShellMenus.CONFIRM)
	await wait_for_town()
	assert_eq_deep(session().get_progress().to_dict(), progress)
	assert_true(session().get_progress().is_floor_cleared(1))
	assert_true(session().get_progress().is_floor_unlocked(2))


func test_ac19_the_confirm_by_the_keyboard() -> void:
	await _paused_on_a_floor()
	choose(ShellMenus.LEAVE)
	await focus_entry_by_keys(ShellMenus.CONFIRM)
	await tap_key(KEY_ENTER)
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	await wait_for_town()


## C21: the game is asked first and the flow follows only when it said yes. A refusal cannot come
## from the menus (the entry is only offered on a floor), so the session is moved behind the shell's
## back while the confirm is open: the game then refuses, and nothing changes.
func test_c21_a_refused_leave_changes_nothing_and_the_confirm_stays() -> void:
	await _paused_on_a_floor()
	choose(ShellMenus.LEAVE)
	assert_true(game().leave_floor(), "the session is taken to the town behind the confirm")
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	watch_signals(flow())
	choose(ShellMenus.CONFIRM)  # The game now refuses: the session is not on a floor.
	assert_signal_not_emitted(flow(), "state_changed")
	assert_eq(flow().get_state(), ShellFlow.State.CONFIRM_LEAVE, "the flow did not move")
	assert_true(panel().is_open(), "the menu stays")
	assert_eq(panel().get_heading(), ShellMenus.CONFIRM_LEAVE_HEADING)
	assert_false(shell().is_guarding(), "no guard began")
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED)


# --- AC20: Quit to title ---


func test_ac20_the_confirm_opens_with_the_focus_on_cancel() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await pause_with_escape()
	choose(ShellMenus.QUIT_TO_TITLE)
	assert_eq(flow().get_state(), ShellFlow.State.CONFIRM_QUIT)
	assert_eq(panel().get_heading(), ShellMenus.CONFIRM_QUIT_HEADING)
	assert_eq(panel().get_body(), ShellMenus.CONFIRM_QUIT_BODY)
	assert_eq(panel().get_entry_ids(), [ShellMenus.CONFIRM, ShellMenus.CANCEL] as Array[StringName])
	assert_eq(panel().get_entry_text(ShellMenus.CONFIRM), "Quit to title")
	assert_eq(panel().get_entry_text(ShellMenus.CANCEL), "Cancel")
	assert_eq(panel().get_focus_id(), ShellMenus.CANCEL)
	_assert_stopped("the confirm keeps the game stopped")


func test_ac20_cancel_and_escape_return_to_the_pause_menu() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await pause_with_escape()
	for method: StringName in [&"entry", &"escape", &"pad_b", &"pad_start", &"enter"]:
		choose(ShellMenus.QUIT_TO_TITLE)
		match method:
			&"entry":
				choose(ShellMenus.CANCEL)
			&"escape":
				await tap_key(ESCAPE)
			&"pad_b":
				await tap_pad(PAD_B)
			&"pad_start":
				await tap_pad(PAD_START)
			&"enter":
				await tap_key(KEY_ENTER)  # The focus is on Cancel.
		assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "by %s" % method)
		assert_eq(panel().get_heading(), ShellMenus.PAUSED_HEADING)
		assert_eq(panel().get_focus_id(), ShellMenus.QUIT_TO_TITLE, "by %s" % method)
		assert_not_null(shell().get_game(), "the game is still there")
		_assert_stopped("by %s" % method)


func test_ac20_confirming_removes_the_game_at_once_and_shows_the_title() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await pause_with_escape()
	var old_game: Game = shell().get_game()
	choose(ShellMenus.QUIT_TO_TITLE)
	assert_false(space_is_active())
	choose(ShellMenus.CONFIRM)
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)
	assert_null(shell().get_game())
	assert_null(shell().get_node_or_null("Game"), "out of the tree in the choice")
	assert_null(old_game.get_parent())
	assert_true(old_game.is_queued_for_deletion(), "freed with queue_free()")
	assert_true(space_is_active(), "the physics space is active again before the title shows")
	assert_true(panel().is_open())
	assert_eq(panel().get_heading(), ShellMenus.TITLE_HEADING)
	assert_eq(panel().get_body(), "", "a title with no failed Start has an empty body")
	assert_eq(panel().get_focus_id(), ShellMenus.START)
	assert_eq(_dim_color(), shell().title_color, "the opaque screen, as there is no game behind it")
	assert_false(shell().is_guarding())
	await get_tree().process_frame
	assert_false(is_instance_valid(old_game), "gone after the next frame")
	assert_eq(shell().get_child_count(), 1, "nothing but the menu layer is left")


func test_ac20_start_after_quitting_begins_with_fresh_progress() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(2, 1))
	await start_game()
	session().get_progress().mark_floor_cleared(1)
	assert_true(session().get_progress().is_floor_unlocked(2), "floor 2 was unlocked")
	await pause_with_escape()
	choose(ShellMenus.QUIT_TO_TITLE)
	choose(ShellMenus.CONFIRM)
	await get_tree().process_frame
	await start_game()
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_true(session().get_progress().is_floor_unlocked(1))
	assert_false(session().get_progress().is_floor_unlocked(2), "only floor 1 is unlocked")
	assert_false(session().get_progress().is_floor_cleared(1))
	assert_eq(session().get_progress().get_highest_unlocked(), 1)


func test_ac20_two_rounds_of_quit_and_start_leave_no_game_no_orphan_and_no_error() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(2, 1))
	await get_tree().process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for round_number: int in 2:
		await start_game()
		session().get_progress().mark_floor_cleared(1)
		await pause_with_escape()
		choose(ShellMenus.QUIT_TO_TITLE)
		choose(ShellMenus.CONFIRM)
		for _i: int in FRAMES_TO_FREE:
			await get_tree().process_frame
		assert_null(shell().get_node_or_null("Game"), "no Game node, round %d" % round_number)
		assert_eq(shell().get_child_count(), 1, "round %d" % round_number)
		assert_eq(panel().get_heading(), ShellMenus.TITLE_HEADING)
		assert_true(space_is_active())
	assert_eq(
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		orphans,
		"no orphan node is left by two rounds"
	)
	await start_game()
	assert_false(session().get_progress().is_floor_unlocked(2), "the third game is fresh too")


func test_ac20_the_game_leaves_no_connection_to_the_settings_behind() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await enter_floor_through_gate(1)
	assert_gt(UserSettings.settings.changed.get_connections().size(), 0, "the camera listens")
	await pause_with_escape()
	choose(ShellMenus.QUIT_TO_TITLE)
	choose(ShellMenus.CONFIRM)
	for _i: int in FRAMES_TO_FREE:
		await get_tree().process_frame
	assert_eq(UserSettings.settings.changed.get_connections().size(), 0, "none after the game")


func test_ac20_quit_to_title_from_a_floor_and_back_in_by_start() -> void:
	await _paused_on_a_floor()
	choose(ShellMenus.QUIT_TO_TITLE)
	choose(ShellMenus.CONFIRM)
	await get_tree().process_frame
	await start_game()
	assert_eq(session().get_place(), TowerSession.Place.TOWN, "a new game starts in the town")
	assert_eq(location(), "Town")
	await pause_with_escape()
	assert_false(panel().get_entry_ids().has(ShellMenus.LEAVE), "a town menu, as at the start")


func test_ac20_quit_to_title_by_the_keyboard() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await pause_with_escape()
	await focus_entry_by_keys(ShellMenus.QUIT_TO_TITLE)
	await tap_key(KEY_ENTER)
	assert_eq(flow().get_state(), ShellFlow.State.CONFIRM_QUIT)
	await focus_entry_by_keys(ShellMenus.CONFIRM)
	await tap_key(KEY_ENTER)
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)
	assert_null(shell().get_game())
	assert_eq(quit_calls(), 0, "the game itself was not quit")


# --- AC26: one press, one step ---


func test_ac26_one_escape_from_the_quit_confirm_lands_in_the_pause_menu() -> void:
	await _assert_one_step_back(&"quit", &"escape")


func test_ac26_one_pad_start_from_the_quit_confirm_lands_in_the_pause_menu() -> void:
	await _assert_one_step_back(&"quit", &"pad_start")


func test_ac26_one_pad_b_from_the_quit_confirm_lands_in_the_pause_menu() -> void:
	await _assert_one_step_back(&"quit", &"pad_b")


func test_ac26_one_escape_from_the_leave_confirm_lands_in_the_pause_menu() -> void:
	await _assert_one_step_back(&"leave", &"escape")


func test_ac26_one_pad_start_from_the_leave_confirm_lands_in_the_pause_menu() -> void:
	await _assert_one_step_back(&"leave", &"pad_start")


func test_ac26_one_pad_b_from_the_leave_confirm_lands_in_the_pause_menu() -> void:
	await _assert_one_step_back(&"leave", &"pad_b")


func test_ac26_one_escape_from_the_settings_lands_in_the_pause_menu() -> void:
	await _assert_one_step_back(&"settings", &"escape")


func test_ac26_one_pad_start_from_the_settings_lands_in_the_pause_menu() -> void:
	await _assert_one_step_back(&"settings", &"pad_start")


func test_ac26_one_pad_b_from_the_settings_lands_in_the_pause_menu() -> void:
	await _assert_one_step_back(&"settings", &"pad_b")


## The menu is reached by its entries; one press goes back one step and the next ticks add none.
func _assert_one_step_back(menu_name: StringName, press: StringName) -> void:
	await _paused_on_a_floor()
	var led_here: StringName = ShellMenus.SETTINGS
	match menu_name:
		&"quit":
			choose(ShellMenus.QUIT_TO_TITLE)
			led_here = ShellMenus.QUIT_TO_TITLE
		&"leave":
			choose(ShellMenus.LEAVE)
			led_here = ShellMenus.LEAVE
		_:
			choose(ShellMenus.SETTINGS)
	var menu_state: ShellFlow.State = flow().get_state()
	assert_ne(menu_state, ShellFlow.State.PAUSED, "a menu is open")
	watch_signals(flow())
	match press:
		&"escape":
			await tap_key(ESCAPE)
		&"pad_start":
			await tap_pad(PAD_START)
		_:
			await tap_pad(PAD_B)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "one step back, not two")
	assert_signal_emit_count(flow(), "state_changed", 1, "one press, one change")
	assert_eq(panel().get_heading(), ShellMenus.PAUSED_HEADING)
	assert_eq(panel().get_focus_id(), led_here)
	_assert_stopped("the game stays stopped")
	assert_false(shell().is_guarding(), "and no guard began")
	for _i: int in 5:
		await get_tree().physics_frame
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "nothing followed")
	assert_signal_emit_count(flow(), "state_changed", 1)
	assert_eq(session().get_place(), TowerSession.Place.FLOOR)


# --- helpers ---


## A shell on `tower` (one floor of one room and a boss when null), started, in room 1 of floor 1.
func _on_a_floor(tower: TowerData = null) -> void:
	await spawn_shell_on(tower if tower != null else TowerFixtures.tower_of(1, 1))
	await start_game()
	await enter_floor_through_gate(1)


## _on_a_floor() with the pause menu open.
func _paused_on_a_floor(tower: TowerData = null) -> void:
	await _on_a_floor(tower)
	await pause_with_escape()


func _assert_back_in_the_pause_menu(floor_before: FloorScene) -> void:
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	assert_eq(panel().get_heading(), ShellMenus.PAUSED_HEADING)
	assert_eq(panel().get_focus_id(), ShellMenus.LEAVE, "the focus is on Return to town")
	assert_eq(session().get_place(), TowerSession.Place.FLOOR, "the session is still on the floor")
	assert_same(floor_scene(), floor_before, "and the same floor is shown")
	_assert_stopped("the game stays stopped")


## The game is disabled and the physics space stopped.
func _assert_stopped(message: String) -> void:
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED, "disabled: %s" % message)
	assert_false(space_is_active(), "the physics space is stopped: %s" % message)


func _sim_time() -> float:
	var shown: Room = town().get_room() if town() != null else floor_scene().get_room()
	return shown.get_runner().get_sim().get_time()


func _dim() -> ColorRect:
	return shell().get_node(Shell.DIM_PATH)


func _dim_color() -> Color:
	return _dim().color


## The values of the file at the shell's path: the two settings.
func _saved() -> Dictionary:
	var file: ConfigFile = ConfigFile.new()
	assert_eq(file.load(settings_file()), OK, "the settings file can be read")
	return {
		"shake": file.get_value(UserSettings.SECTION, GameSettings.KEY_SCREEN_SHAKE_ENABLED),
		"fullscreen": file.get_value(UserSettings.SECTION, GameSettings.KEY_FULLSCREEN),
	}
