# gdlint:disable=max-public-methods,max-file-lines
extends F015ShellTest
## F-015 T6 (AC22, AC23, AC24, AC29's first sentence, AC16's death and leave cases; C7, C21): the
## death screen and its poll, through shell.tscn. The shell follows the session by polling after the
## game's own tick, opens the death screen in the tick the pause begins, enables its one entry once
## the delay has passed, and a confirmed death or a confirmed leave goes through the input guard.
## 120 physics ticks/s unless a test says otherwise; the player's input is off except in the guard
## tests, where it is turned on just before the confirm.

const ESCAPE: Key = KEY_ESCAPE
## The death pause of these tests, in seconds (the shipped one is 1.5): 60 ticks at 120/s.
const DEATH_DELAY: float = 0.5
const DELAY_TICKS: int = 60
## F-015 AC23: twenty seconds of ticked time at 120 ticks/s.
const TWENTY_SECONDS_TICKS: int = 2400
const FIRST_ROOM_TEXT: String = "Floor 1 · Room 1 / 2"
const BOSS_TEXT: String = "Floor 1 · Boss"
const KILLS_TEXT: String = "Kills 0 / 5"
## Ticks the death screen may take to open after the player is dead.
const DEAD_LIMIT_TICKS: int = 10
## F-015 AC16: ticks the player must not dash or attack in once the game runs again, before and
## after the town replaces the floor.
const WATCH_TICKS: int = 10
## The delay of the guard tests, short at any rate.
const SHORT_DELAY: float = 0.1
const SHORT_DELAY_LIMIT_TICKS: int = 60


func before_each() -> void:
	super.before_each()
	set_death_delay(DEATH_DELAY)


func after_each() -> void:
	release_click()
	await super.after_each()


# --- AC22: the death screen opens with the pause ---


func test_ac22_the_screen_opens_in_the_tick_the_session_enters_the_death_pause() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await enter_floor_through_gate(1)
	var frames: Dictionary = {"place": -1, "state": -1}
	session().place_changed.connect(
		func(place: TowerSession.Place) -> void:
			if place == TowerSession.Place.DEATH_PAUSE:
				frames["place"] = Engine.get_physics_frames()
	)
	flow().state_changed.connect(
		func(state: ShellFlow.State, _previous: ShellFlow.State) -> void:
			if state == ShellFlow.State.DEAD:
				frames["state"] = Engine.get_physics_frames()
	)
	assert_false(panel().is_open())
	kill_player()
	for tick: int in DEAD_LIMIT_TICKS:
		await get_tree().physics_frame
		var in_pause: bool = session().get_place() == TowerSession.Place.DEATH_PAUSE
		assert_eq(
			flow().get_state() == ShellFlow.State.DEAD,
			in_pause,
			"after tick %d: the screen is up exactly when the session is in the pause" % tick
		)
	assert_gte(frames["place"], 0, "the session entered the death pause")
	assert_eq(frames["state"], frames["place"], "the same physics tick")
	assert_true(panel().is_open())


func test_ac22_the_screen_says_where_you_died_in_a_wave_room() -> void:
	await _die_on_floor(WaveFixtures.wave_tower(2))
	assert_eq(flow().get_state(), ShellFlow.State.DEAD)
	assert_eq(panel().get_heading(), ShellMenus.DEAD_HEADING)
	assert_eq(panel().get_heading(), "You died")
	assert_eq(
		panel().get_body(),
		"%s\n%s\n%s" % [FIRST_ROOM_TEXT, KILLS_TEXT, "You keep everything you unlocked."],
		"the location, the kills and the keep line"
	)
	assert_eq(
		panel().get_body(), "\n".join([location(), hud().get_kills_text(), ShellMenus.KEEP_LINE])
	)
	assert_eq(panel().get_entry_ids(), [ShellMenus.RETURN] as Array[StringName])
	assert_eq(panel().get_entry_text(ShellMenus.RETURN), "Return to town")
	assert_eq(panel().get_focus_id(), ShellMenus.RETURN)
	assert_eq(_dim().color, shell().dim_color, "the game is behind it: the dim, not the title's")
	assert_true(_dim().visible)


func test_ac22_the_screen_has_no_kills_line_in_a_boss_room() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(2, 1))
	await start_game()
	await enter_floor_through_gate(1)
	skip_to_boss()
	assert_eq(location(), BOSS_TEXT)
	kill_player()
	await _wait_for_death_screen()
	assert_eq(
		panel().get_body(),
		"%s\n%s" % [BOSS_TEXT, ShellMenus.KEEP_LINE],
		"two lines: the location and the keep line"
	)


func test_ac22_a_heal_banner_showing_at_the_death_is_gone() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(2, 2))
	await start_game()
	await enter_floor_through_gate(1)
	set_hp(40)
	kill_all()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "+30 HP", "a banner is showing")
	kill_player()
	await _wait_for_death_screen()
	assert_false(hud().is_banner_visible(), "no banner under the death screen")
	assert_eq(hud().get_banner_text(), "")


func test_ac22_a_cleared_banner_showing_at_the_death_is_gone_too() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(2, 1))
	await start_game()
	await enter_floor_through_gate(1)
	skip_to_boss()
	kill_boss()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "Floor 1 cleared — floor 2 unlocked")
	kill_player()
	await _wait_for_death_screen()
	assert_false(hud().is_banner_visible())


func test_ac22_the_entry_is_disabled_and_nothing_chooses_it_until_the_delay_has_passed() -> void:
	await _die_on_floor(TowerFixtures.tower_of(1, 1))
	assert_false(panel().is_entry_enabled(ShellMenus.RETURN), "disabled at first")
	assert_false(session().can_confirm_death())
	assert_eq(panel().get_focus_id(), ShellMenus.RETURN, "the focus is on it, disabled")
	watch_signals(flow())
	choose(ShellMenus.RETURN)
	await tap_key(KEY_ENTER)
	await tap_key(KEY_SPACE)
	await tap_pad(JOY_BUTTON_A)
	await hold_click_between_ticks()
	choose(ShellMenus.RETURN)
	release_click()
	assert_signal_not_emitted(flow(), "state_changed")
	assert_eq(flow().get_state(), ShellFlow.State.DEAD)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_false(shell().is_guarding())
	assert_true(panel().is_open())


func test_ac22_the_entry_is_enabled_without_the_menu_being_rebuilt_once_the_delay_passed() -> void:
	await _die_on_floor(TowerFixtures.tower_of(1, 1))
	var buttons: Array[int] = entry_button_ids()
	var disabled_ticks: int = 0
	var enabled_at: int = -1
	for tick: int in DELAY_TICKS * 2:
		var enabled: bool = panel().is_entry_enabled(ShellMenus.RETURN)
		assert_eq(
			enabled, session().can_confirm_death(), "tick %d: enabled exactly when it can be" % tick
		)
		if enabled and enabled_at < 0:
			enabled_at = tick
		if not enabled:
			disabled_ticks += 1
		await get_tree().physics_frame
	assert_gt(disabled_ticks, DELAY_TICKS / 2, "it stayed disabled for the delay")
	assert_gte(enabled_at, 0, "and then it was enabled")
	assert_true(panel().is_entry_enabled(ShellMenus.RETURN))
	assert_eq(entry_button_ids(), buttons, "the same buttons: the menu was not rebuilt")
	assert_eq(panel().get_focus_id(), ShellMenus.RETURN, "the focus stayed on it")
	assert_eq(flow().get_state(), ShellFlow.State.DEAD, "and nothing returned to town by itself")


func test_ac22_with_a_delay_of_zero_the_entry_is_enabled_at_once() -> void:
	set_death_delay(0.0)
	await _die_on_floor(TowerFixtures.tower_of(1, 1))
	assert_true(session().can_confirm_death())
	assert_true(panel().is_entry_enabled(ShellMenus.RETURN), "enabled as the screen opens")


func test_ac22_the_enabled_entry_chosen_by_the_entry_returns_to_town() -> void:
	await _assert_death_chosen_by(&"entry")


func test_ac22_the_enabled_entry_chosen_with_enter_returns_to_town() -> void:
	await _assert_death_chosen_by(&"enter")


func test_ac22_the_enabled_entry_chosen_with_space_returns_to_town() -> void:
	await _assert_death_chosen_by(&"space")


func test_ac22_the_enabled_entry_chosen_with_pad_a_returns_to_town() -> void:
	await _assert_death_chosen_by(&"pad_a")


func _assert_death_chosen_by(method: StringName) -> void:
	set_death_delay(0.0)
	await _die_on_floor(TowerFixtures.tower_of(1, 1))
	assert_true(panel().is_entry_enabled(ShellMenus.RETURN))
	match method:
		&"entry":
			choose(ShellMenus.RETURN)
		&"enter":
			await tap_key(KEY_ENTER)
		&"space":
			await tap_key(KEY_SPACE)
		&"pad_a":
			await tap_pad(JOY_BUTTON_A)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "by %s" % method)
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	await wait_for_town()


## C21: the game is asked first. A refusal changes nothing: the entry is forced open here, which
## only a stale frame between two ticks could do for a real player.
func test_c21_a_refused_confirm_changes_nothing_and_the_screen_stays() -> void:
	await _die_on_floor(TowerFixtures.tower_of(1, 1))
	assert_false(session().can_confirm_death())
	panel().set_entry_enabled(ShellMenus.RETURN, true)
	watch_signals(flow())
	choose(ShellMenus.RETURN)
	assert_signal_not_emitted(flow(), "state_changed")
	assert_eq(flow().get_state(), ShellFlow.State.DEAD, "the flow did not move")
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_false(shell().is_guarding())
	assert_true(panel().is_open())
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(panel().is_entry_enabled(ShellMenus.RETURN), "the next tick puts it right again")


func test_ac22_behind_the_screen_the_game_keeps_running() -> void:
	await _die_on_floor(TowerFixtures.tower_of(1, 1))
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT)
	assert_true(space_is_active())
	assert_false(shell().is_guarding())
	var before: float = room().get_runner().get_sim().get_time()
	for _i: int in 10:
		await get_tree().physics_frame
	assert_gt(room().get_runner().get_sim().get_time(), before, "the room keeps moving")
	assert_eq(flow().get_state(), ShellFlow.State.DEAD)


# --- AC23: Return to town on the death screen ---


func test_ac23_choosing_it_shows_the_town_with_a_living_player_at_full_hp() -> void:
	await _die_on_floor(TowerFixtures.tower_of(2, 1))
	var dead_floor: FloorScene = floor_scene()
	var progress: Dictionary = session().get_progress().to_dict()
	assert_true(await tick_until(func() -> bool: return session().can_confirm_death(), 200))
	var ready: Callable = func() -> bool: return panel().is_entry_enabled(ShellMenus.RETURN)
	assert_true(await tick_until(ready, 2), "enabled in the tick it can be confirmed")
	await get_tree().process_frame  # Between two ticks.
	choose(ShellMenus.RETURN)
	assert_eq(session().get_place(), TowerSession.Place.TOWN, "the session knows at once")
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_false(panel().is_open(), "the menu is closed")
	assert_false(_dim().visible)
	assert_true(shell().is_guarding())
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED, "held back, as for every way in")
	assert_false(space_is_active())
	assert_same(floor_scene(), dead_floor, "the old floor stays on screen until the game runs")
	await wait_for_town()
	assert_false(is_instance_valid(dead_floor), "the floor was freed")
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_eq(location(), "Town")
	assert_eq(hp(), max_hp(), "full HP")
	assert_gt(hp(), 0, "living")
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_false(panel().is_open())
	assert_eq_deep(session().get_progress().to_dict(), progress)


func test_ac23_a_boss_room_reached_in_the_run_is_offered_at_the_boss() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(2, 1))
	await start_game()
	await enter_floor_through_gate(1)
	skip_to_boss()
	var progress: Dictionary = session().get_progress().to_dict()
	kill_player()
	await _wait_for_death_screen()
	await _confirm_when_ready()
	await wait_for_town()
	assert_eq_deep(session().get_progress().to_dict(), progress)
	assert_true(session().get_progress().is_boss_reached(1))
	await open_gate_menu()
	assert_eq(
		button_texts(),
		["Floor 1 — from the start", "Floor 1 — at the boss", GateMenu.STAY_TEXT] as Array[String]
	)


func test_ac23_after_twenty_seconds_on_the_death_screen_nothing_has_returned_to_town() -> void:
	await _die_on_floor(TowerFixtures.tower_of(1, 1))
	var dead_floor: FloorScene = floor_scene()
	for second: int in 20:
		for _i: int in TWENTY_SECONDS_TICKS / 20:
			await get_tree().physics_frame
		assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE, "second %d" % second)
		assert_eq(flow().get_state(), ShellFlow.State.DEAD)
	assert_true(panel().is_open())
	assert_true(panel().is_entry_enabled(ShellMenus.RETURN), "enabled, and waiting")
	assert_eq(panel().get_focus_id(), ShellMenus.RETURN)
	assert_eq(session().get_death_time_left(), 0.0)
	assert_same(floor_scene(), dead_floor, "the floor is still shown")
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT)
	choose(ShellMenus.RETURN)
	assert_eq(session().get_place(), TowerSession.Place.TOWN, "and it can still be confirmed")


func test_ac23_a_second_death_after_coming_back_works_the_same() -> void:
	set_death_delay(SHORT_DELAY)
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	for round_number: int in 2:
		await enter_floor_through_gate(1)
		kill_player()
		await _wait_for_death_screen()
		assert_false(
			panel().is_entry_enabled(ShellMenus.RETURN), "a fresh delay, round %d" % round_number
		)
		await _confirm_when_ready()
		await wait_for_town()
		assert_eq(hp(), max_hp())
		assert_eq(flow().get_state(), ShellFlow.State.PLAYING)


# --- AC24: the lines the screen reads ---


func test_ac24_a_kill_in_the_players_death_tick_counts_on_the_screens_kills_line() -> void:
	await spawn_shell_on(WaveFixtures.wave_tower(2))
	await start_game()
	await enter_floor_through_gate(1)
	kill(room().get_enemies()[0])
	await run_ticks(1)
	assert_eq(hud().get_kills_text(), "Kills 1 / 5")
	# A trade: between the same two ticks an enemy falls and so does the player.
	kill(room().get_enemies()[1])
	kill_player()
	await _wait_for_death_screen()
	assert_eq(room().get_kill_count(), 2, "the room counts both")
	var body: String = "%s\n%s\n%s" % [FIRST_ROOM_TEXT, "Kills 2 / 5", ShellMenus.KEEP_LINE]
	assert_eq(panel().get_body(), body, "the screen has the line as it was fed in the tick")
	assert_eq(hud().get_kills_text(), "Kills 2 / 5")
	assert_eq(location(), FIRST_ROOM_TEXT)
	# The room keeps moving behind the screen; the lines do not.
	for _i: int in 5:
		for _tick: int in DELAY_TICKS * 2:
			await get_tree().physics_frame
		assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
		assert_eq(hud().get_kills_text(), "Kills 2 / 5")
		assert_eq(location(), FIRST_ROOM_TEXT)
		assert_eq(panel().get_body(), body)
	kill(room().get_enemies()[2])
	await run_ticks(2)
	assert_eq(hud().get_kills_text(), "Kills 2 / 5", "a later kill changes nothing on it")
	assert_eq(panel().get_body(), body)


# --- AC29: a session restored into the death pause ---


func test_ac29_a_session_put_into_the_death_pause_shows_the_screen_on_the_next_tick() -> void:
	set_death_delay(0.3)
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	assert_true(session().from_dict(_death_snapshot(0.0)))
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "the shell has not had its tick yet")
	assert_false(panel().is_open())
	await get_tree().physics_frame  # The tick the call was made in.
	assert_eq(flow().get_state(), ShellFlow.State.DEAD, "the screen on the shell's next tick")
	assert_true(panel().is_open())
	assert_eq(panel().get_heading(), ShellMenus.DEAD_HEADING)
	assert_eq(panel().get_body(), "Town\n%s" % ShellMenus.KEEP_LINE, "the lines the HUD has")
	assert_true(panel().is_entry_enabled(ShellMenus.RETURN), "nothing left to wait for")
	choose(ShellMenus.RETURN)
	assert_eq(session().get_place(), TowerSession.Place.TOWN, "and it can be confirmed")
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	await wait_for_town()
	assert_eq(location(), "Town")


func test_ac29_a_restored_pause_with_time_left_waits_and_then_can_be_confirmed() -> void:
	set_death_delay(0.3)
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	assert_true(session().from_dict(_death_snapshot(0.3)))
	await get_tree().physics_frame
	assert_eq(flow().get_state(), ShellFlow.State.DEAD)
	assert_false(panel().is_entry_enabled(ShellMenus.RETURN), "time is left")
	choose(ShellMenus.RETURN)
	assert_eq(flow().get_state(), ShellFlow.State.DEAD, "refused while it is disabled")
	await _confirm_when_ready()
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)


# --- C21 (both directions): the pause ended by something other than the entry ---


func test_c21_a_confirm_made_directly_on_the_game_takes_the_flow_out_of_the_death_screen() -> void:
	await _die_on_floor(TowerFixtures.tower_of(1, 1))
	var dead_floor: FloorScene = floor_scene()
	var ready: Callable = func() -> bool: return session().can_confirm_death()
	assert_true(await tick_until(ready, DELAY_TICKS * 2), "the delay passed")
	await get_tree().process_frame  # Between two ticks.
	assert_true(game().confirm_death(), "not through the entry")
	assert_eq(flow().get_state(), ShellFlow.State.DEAD, "the shell has not had its tick yet")
	await get_tree().physics_frame  # The start of the next tick: it has not run yet.
	await get_tree().physics_frame  # And now it has.
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "left the screen in the next tick")
	assert_false(panel().is_open(), "the panel is closed")
	assert_true(shell().is_guarding(), "through the guard, like every way into PLAYING")
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED)
	await wait_for_town()
	assert_false(is_instance_valid(dead_floor))
	assert_eq(hp(), max_hp(), "a living player at full HP")
	assert_gt(hp(), 0)
	# A later death opens the death screen again.
	await enter_floor_through_gate(1)
	kill_player()
	await _wait_for_death_screen()
	assert_true(panel().is_open())
	assert_eq(panel().get_heading(), ShellMenus.DEAD_HEADING)


func test_c21_a_session_restored_into_the_town_takes_the_flow_out_of_the_death_screen() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	var in_town: Dictionary = session().to_dict()
	await enter_floor_through_gate(1)
	kill_player()
	await _wait_for_death_screen()
	assert_true(session().from_dict(in_town))
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	await get_tree().physics_frame
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_false(panel().is_open())
	assert_true(shell().is_guarding())
	await wait_for_town()
	assert_eq(location(), "Town")
	assert_eq(hp(), max_hp())


func test_c21_a_session_restored_onto_a_floor_takes_the_flow_out_of_the_death_screen() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await enter_floor_through_gate(1)
	var on_floor: Dictionary = session().to_dict()
	var dead_id: int = floor_scene().get_instance_id()
	kill_player()
	await _wait_for_death_screen()
	assert_true(session().from_dict(on_floor))
	assert_eq(session().get_place(), TowerSession.Place.FLOOR)
	await get_tree().physics_frame
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_false(panel().is_open())
	assert_true(shell().is_guarding())
	await wait_for_guard()
	var fresh: Callable = func() -> bool:
		return floor_scene() != null and instance_from_id(dead_id) == null
	assert_true(await tick_until(fresh), "a new floor replaced the dead one")
	assert_eq(hp(), max_hp())
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)


func test_c21_the_entrys_own_confirm_changes_the_flow_exactly_once() -> void:
	await _die_on_floor(TowerFixtures.tower_of(1, 1))
	var ready: Callable = func() -> bool: return panel().is_entry_enabled(ShellMenus.RETURN)
	assert_true(await tick_until(ready, DELAY_TICKS * 2))
	await get_tree().process_frame
	watch_signals(flow())
	choose(ShellMenus.RETURN)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	await wait_for_town()
	for _i: int in WATCH_TICKS:
		await get_tree().physics_frame
	assert_signal_emit_count(flow(), "state_changed", 1, "the poll adds no second change")
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)


# --- AC16: the input guard on the death screen and on the leave confirm ---


func test_ac16_death_confirmed_with_space_at_60() -> void:
	await _assert_death_confirm_is_guarded(&"space", 60)


func test_ac16_death_confirmed_with_space_at_120() -> void:
	await _assert_death_confirm_is_guarded(&"space", 120)


func test_ac16_death_confirmed_with_pad_a_at_60() -> void:
	await _assert_death_confirm_is_guarded(&"pad_a", 60)


func test_ac16_death_confirmed_with_pad_a_at_120() -> void:
	await _assert_death_confirm_is_guarded(&"pad_a", 120)


func test_ac16_death_confirmed_with_enter_at_60() -> void:
	await _assert_death_confirm_is_guarded(&"enter", 60)


func test_ac16_death_confirmed_with_enter_at_120() -> void:
	await _assert_death_confirm_is_guarded(&"enter", 120)


func test_ac16_death_confirmed_with_a_click_at_60() -> void:
	await _assert_death_confirm_is_guarded(&"click", 60)


func test_ac16_death_confirmed_with_a_click_at_120() -> void:
	await _assert_death_confirm_is_guarded(&"click", 120)


func test_ac16_leave_confirmed_with_space_at_60() -> void:
	await _assert_leave_confirm_is_guarded(&"space", 60)


func test_ac16_leave_confirmed_with_space_at_120() -> void:
	await _assert_leave_confirm_is_guarded(&"space", 120)


func test_ac16_leave_confirmed_with_pad_a_at_60() -> void:
	await _assert_leave_confirm_is_guarded(&"pad_a", 60)


func test_ac16_leave_confirmed_with_pad_a_at_120() -> void:
	await _assert_leave_confirm_is_guarded(&"pad_a", 120)


func test_ac16_leave_confirmed_with_enter_at_60() -> void:
	await _assert_leave_confirm_is_guarded(&"enter", 60)


func test_ac16_leave_confirmed_with_enter_at_120() -> void:
	await _assert_leave_confirm_is_guarded(&"enter", 120)


func test_ac16_leave_confirmed_with_a_click_at_60() -> void:
	await _assert_leave_confirm_is_guarded(&"click", 60)


func test_ac16_leave_confirmed_with_a_click_at_120() -> void:
	await _assert_leave_confirm_is_guarded(&"click", 120)


func _assert_death_confirm_is_guarded(method: StringName, rate: int) -> void:
	Engine.physics_ticks_per_second = rate
	set_death_delay(SHORT_DELAY)
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await enter_floor_through_gate(1)
	kill_player()
	await _wait_for_death_screen()
	var ready: Callable = func() -> bool: return panel().is_entry_enabled(ShellMenus.RETURN)
	assert_true(await tick_until(ready, SHORT_DELAY_LIMIT_TICKS), "the entry is enabled")
	game().player_input_enabled = true  # The town built next has a player that reads input.
	await _press_to_confirm(method, ShellMenus.RETURN)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "%s confirmed the death" % method)
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	await _assert_guarded_until_the_game_runs()
	await _assert_no_dash_or_attack_until_the_town_has_run()


func _assert_leave_confirm_is_guarded(method: StringName, rate: int) -> void:
	Engine.physics_ticks_per_second = rate
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await enter_floor_through_gate(1)
	await pause_with_escape()
	choose(ShellMenus.LEAVE)
	await focus_entry_by_keys(ShellMenus.CONFIRM)
	player().input_enabled = true  # The floor's player is alive: if the game ran, it would act.
	game().player_input_enabled = true
	await _press_to_confirm(method, ShellMenus.CONFIRM)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "%s confirmed the leave" % method)
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	await _assert_guarded_until_the_game_runs()
	await _assert_no_dash_or_attack_until_the_town_has_run()


## A key or a pad button that is also the dash, Enter, or a click that is also the attack, down
## between two ticks and held; the click is followed in the same frame by the choice itself.
func _press_to_confirm(method: StringName, id: StringName) -> void:
	match method:
		&"space":
			await hold_key_between_ticks(KEY_SPACE)
		&"enter":
			await hold_key_between_ticks(KEY_ENTER)
		&"pad_a":
			await hold_pad_between_ticks(JOY_BUTTON_A)
		&"click":
			await hold_click_between_ticks()
			choose(id)
		_:
			fail_test("no such way to confirm: %s" % method)


## From the choice: the guard, the game disabled and the space stopped for the shell's two ticks,
## enabled in the second, never in the choice itself.
func _assert_guarded_until_the_game_runs() -> void:
	assert_true(shell().is_guarding(), "from the choice")
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED, "the choice did not enable it")
	assert_false(space_is_active())
	await get_tree().physics_frame  # The start of the first tick.
	assert_true(shell().is_guarding())
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED)
	await get_tree().physics_frame  # The start of the second: the shell enables the game in it.
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED, "not before the second tick ends")
	await get_tree().physics_frame
	assert_false(shell().is_guarding(), "until the game runs")
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT)


## Ticks after the game runs again: the player (the floor's until the town replaces it, then the
## town's) neither dashes nor attacks, before and after the swap, and the pause menu does not open.
func _assert_no_dash_or_attack_until_the_town_has_run() -> void:
	await _watch_ticks()
	var shown: Callable = func() -> bool: return town() != null and floor_scene() == null
	assert_true(await tick_until(shown), "the town is shown")
	await _watch_ticks()
	assert_not_null(player(), "a player stands in the town")
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "and the pause menu did not open")
	assert_false(panel().is_open())


func _watch_ticks() -> void:
	for tick: int in WATCH_TICKS:
		await get_tree().physics_frame
		_assert_no_action("tick %d" % tick)


func _assert_no_action(message: String) -> void:
	var body: Player = player()
	if body == null:
		return
	assert_ne(body.motor.get_state(), PlayerMotor.State.DASHING, "no dash, %s" % message)
	assert_ne(body.motor.get_state(), PlayerMotor.State.ATTACKING, "no attack, %s" % message)


# --- helpers ---


## On floor 1 of `tower`, dead, with the death screen up.
func _die_on_floor(tower: TowerData) -> void:
	await spawn_shell_on(tower)
	await start_game()
	await enter_floor_through_gate(1)
	kill_player()
	await _wait_for_death_screen()


func _wait_for_death_screen() -> void:
	var dead: Callable = func() -> bool: return flow().get_state() == ShellFlow.State.DEAD
	assert_true(await tick_until(dead, DEAD_LIMIT_TICKS), "the death screen opened")


## Ticks until the entry is enabled, then chooses it.
func _confirm_when_ready() -> void:
	var ready: Callable = func() -> bool: return panel().is_entry_enabled(ShellMenus.RETURN)
	assert_true(await tick_until(ready, SHORT_DELAY_LIMIT_TICKS * 4), "the entry became enabled")
	await get_tree().process_frame
	choose(ShellMenus.RETURN)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "the choice confirmed the death")


## The session's own snapshot with the place put into the death pause on floor 1.
func _death_snapshot(time_left: float) -> Dictionary:
	var snapshot: Dictionary = session().to_dict()
	snapshot[TowerSession.KEY_PLACE] = int(TowerSession.Place.DEATH_PAUSE)
	snapshot[TowerSession.KEY_FLOOR] = 1
	snapshot[TowerSession.KEY_START_ROOM] = 0
	snapshot[TowerSession.KEY_DEATH_TIME_LEFT] = time_left
	return snapshot


func _dim() -> ColorRect:
	return shell().get_node(Shell.DIM_PATH)
