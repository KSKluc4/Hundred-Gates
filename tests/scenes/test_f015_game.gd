# gdlint:disable=max-public-methods
extends F012GameTest
## F-015 T3 (the game half of AC22-AC24, C3-C5): `Game` alone, with no shell. The death waits for
## `confirm_death()`, a floor can be left by `leave_floor()`, `is_pause_allowed()` says when the
## pause menu may open, and the "You died" banner is gone. On fixture towers, 120 ticks/s.

## The death pause of these tests, in seconds (the shipped one is 1.5).
const DEATH_DELAY: float = 0.5
const DELAY_TICKS: int = 60
## F-015 AC23: twenty seconds of ticked time at 120 ticks/s.
const TWENTY_SECONDS_TICKS: int = 2400
const FIRST_ROOM_TEXT: String = "Floor 1 · Room 1 / 2"
const BOSS_TEXT: String = "Floor 1 · Boss"


func before_each() -> void:
	super.before_each()
	set_death_delay(DEATH_DELAY)


# --- AC23: nothing returns to the town by itself ---


func test_ac23_after_a_death_the_place_stays_the_death_pause_for_twenty_seconds() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	var dead_floor: FloorScene = floor_scene()
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	for _second: int in 20:
		await run_ticks(TWENTY_SECONDS_TICKS / 20)
		assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_eq(session().get_death_time_left(), 0.0, "never negative")
	assert_true(session().can_confirm_death())
	assert_same(floor_scene(), dead_floor, "the floor is still shown")
	assert_null(town())
	assert_eq(hp(), 0, "and the player is still dead")
	assert_true(game().confirm_death(), "and it can still be confirmed")


func test_ac23_confirming_is_refused_before_the_delay_and_accepted_after() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	kill_player()
	await run_ticks(2)
	assert_false(session().can_confirm_death())
	assert_false(game().confirm_death(), "before the delay")
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	await run_ticks(DELAY_TICKS / 2)
	assert_false(game().confirm_death(), "half way")
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	var ready: Callable = func() -> bool: return session().can_confirm_death()
	assert_true(await run_until(ready, DELAY_TICKS * 2), "the delay passed")
	assert_true(game().confirm_death(), "after the delay")
	assert_false(game().confirm_death(), "a second time")


func test_ac23_confirming_shows_the_town_with_a_living_player_at_full_hp() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	var dead_floor: FloorScene = floor_scene()
	kill_player()
	assert_true(await confirm_death_when_ready())
	var back: Callable = func() -> bool: return town() != null
	assert_true(await run_until(back, 10), "the town is shown")
	await run_ticks(1)
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_null(floor_scene())
	assert_false(is_instance_valid(dead_floor), "the floor was freed")
	assert_eq(location(), "Town")
	assert_eq(hp(), max_hp(), "full HP")
	assert_gt(hp(), 0, "living")


func test_ac23_the_progress_is_what_it_was_and_the_gate_offers_the_boss_reached() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 1))
	await enter_floor_through_gate(1)
	skip_to_boss()
	assert_eq(location(), BOSS_TEXT)
	var before: Dictionary = session().get_progress().to_dict()
	kill_player()
	assert_true(await confirm_death_when_ready())
	var back: Callable = func() -> bool: return town() != null
	assert_true(await run_until(back, 10))
	assert_eq_deep(session().get_progress().to_dict(), before)
	assert_true(session().get_progress().is_boss_reached(1))
	assert_false(session().get_progress().is_floor_cleared(1))
	await open_gate_menu()
	assert_eq(
		button_texts(),
		["Floor 1 — from the start", "Floor 1 — at the boss", GateMenu.STAY_TEXT] as Array[String]
	)


func test_ac23_the_swap_waits_for_the_games_next_tick_not_the_call() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	var dead_floor: FloorScene = floor_scene()
	kill_player()
	await run_ticks(2)
	var ready: Callable = func() -> bool: return session().can_confirm_death()
	assert_true(await run_until(ready, DELAY_TICKS * 2))
	assert_true(game().confirm_death())
	assert_eq(session().get_place(), TowerSession.Place.TOWN, "the session knows at once")
	assert_same(floor_scene(), dead_floor, "the old floor is still shown")
	assert_null(town())
	await run_ticks(1)
	assert_not_null(town(), "the town after the game's next tick")
	assert_null(floor_scene())


func test_ac23_a_second_death_after_coming_back_waits_again() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	for _i: int in 2:
		await enter_floor_through_gate(1)
		kill_player()
		await run_ticks(2)
		assert_false(game().confirm_death(), "a fresh delay each time")
		await run_ticks(DELAY_TICKS * 2)
		assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
		assert_true(game().confirm_death())
		await run_ticks(2)
		assert_eq(session().get_place(), TowerSession.Place.TOWN)
		assert_eq(hp(), max_hp())


func test_ac23_confirming_is_refused_in_the_town_and_on_a_floor() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	assert_false(game().confirm_death(), "in the town")
	await enter_floor_through_gate(1)
	await run_ticks(DELAY_TICKS * 2)
	assert_false(game().confirm_death(), "on a floor")
	assert_eq(session().get_place(), TowerSession.Place.FLOOR)
	assert_not_null(floor_scene())


# --- AC22: no banner at a death ---


func test_ac22_a_death_shows_no_banner() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_false(hud().is_banner_visible())
	assert_eq(hud().get_banner_text(), "")
	await run_ticks(DELAY_TICKS * 2)
	assert_false(hud().is_banner_visible(), "and none later in the pause")


func test_ac22_a_heal_banner_showing_at_the_death_is_gone_in_the_tick_of_the_death() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 2))
	await enter_floor_through_gate(1)
	set_hp(40)
	kill_all()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "+30 HP")
	kill_player()
	var died: Callable = func() -> bool:
		return session().get_place() == TowerSession.Place.DEATH_PAUSE
	assert_true(await run_until(died, 10))
	assert_false(hud().is_banner_visible(), "gone at once, in the tick the pause began")
	assert_eq(hud().get_banner_text(), "")


func test_ac22_a_cleared_banner_showing_at_the_death_is_gone_too() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 1))
	await enter_floor_through_gate(1)
	skip_to_boss()
	kill_boss()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "Floor 1 cleared — floor 2 unlocked")
	kill_player()
	var died: Callable = func() -> bool:
		return session().get_place() == TowerSession.Place.DEATH_PAUSE
	assert_true(await run_until(died, 10))
	assert_false(hud().is_banner_visible())


func test_ac22_a_debug_skip_in_the_pause_shows_no_banner() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 1))
	await enter_floor_through_gate(1)
	kill_player()
	await run_ticks(2)
	floor_scene().skip_room()  # What N does: the session ignores it, and so does the HUD.
	await run_ticks(2)
	assert_false(hud().is_banner_visible())


func test_ac22_the_banner_of_the_next_visit_shows_as_before() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 2))
	await enter_floor_through_gate(1)
	kill_player()
	assert_true(await confirm_death_when_ready())
	await run_ticks(2)
	await enter_floor_through_gate(1)
	set_hp(40)
	kill_all()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "+30 HP", "banners work again after a death")


func test_the_game_no_longer_has_a_death_banner_text() -> void:
	var game_script: GDScript = load("res://src/world/game.gd")
	assert_false(game_script.get_script_constant_map().has("DEATH_BANNER"))
	assert_true(game_script.get_script_constant_map().has("HEALED_FORMAT"), "the others stay")


# --- Hud.hide_banner() ---


func test_hide_banner_hides_at_once_with_the_text_empty() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	hud().show_banner("hello", 60.0)
	assert_true(hud().is_banner_visible())
	hud().hide_banner()
	assert_false(hud().is_banner_visible(), "at once, not on the next _process")
	assert_eq(hud().get_banner_text(), "")
	hud().hide_banner()
	assert_false(hud().is_banner_visible(), "twice is the same")


func test_hide_banner_leaves_no_time_behind_for_the_next_banner() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	hud().show_banner("first", 60.0)
	hud().hide_banner()
	hud().show_banner("second", 0.05)
	assert_eq(hud().get_banner_text(), "second")
	await get_tree().create_timer(0.3).timeout
	assert_false(hud().is_banner_visible(), "the new banner ran its own time")


# --- AC24: the kills line and the location line in the death pause ---


func test_ac24_a_kill_in_the_players_death_tick_counts_and_the_lines_then_stay() -> void:
	await spawn_game(WaveFixtures.wave_tower(2))
	await enter_floor_through_gate(1)
	kill(room().get_enemies()[0])
	await run_ticks(1)
	assert_eq(hud().get_kills_text(), "Kills 1 / 5")
	# A trade: between the same two ticks an enemy falls and so does the player.
	kill(room().get_enemies()[1])
	kill_player()
	var died: Callable = func() -> bool:
		return session().get_place() == TowerSession.Place.DEATH_PAUSE
	assert_true(await run_until(died, 10))
	assert_eq(room().get_kill_count(), 2, "the room counts both")
	assert_eq(hud().get_kills_text(), "Kills 2 / 5", "and the line did in the tick of the death")
	assert_eq(location(), FIRST_ROOM_TEXT)
	# The room keeps moving behind the death screen; the lines do not.
	for _i: int in 5:
		await run_ticks(DELAY_TICKS * 2)
		assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
		assert_eq(hud().get_kills_text(), "Kills 2 / 5")
		assert_eq(location(), FIRST_ROOM_TEXT)
	kill(room().get_enemies()[2])
	await run_ticks(2)
	assert_eq(hud().get_kills_text(), "Kills 2 / 5", "a later kill is not counted")
	floor_scene().skip_room()
	assert_eq(hud().get_kills_text(), "Kills 2 / 5")
	assert_eq(location(), FIRST_ROOM_TEXT)


func test_ac24_a_boss_room_shows_no_kills_line_in_the_pause() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	skip_to_boss()
	kill_player()
	await run_ticks(2)
	assert_eq(hud().get_kills_text(), "")
	assert_eq(location(), BOSS_TEXT)
	await run_ticks(DELAY_TICKS * 2)
	assert_eq(hud().get_kills_text(), "")
	assert_eq(location(), BOSS_TEXT)


func test_ac24_the_lines_follow_the_town_again_after_the_confirmation() -> void:
	await spawn_game(WaveFixtures.wave_tower(2))
	await enter_floor_through_gate(1)
	kill_player()
	assert_true(await confirm_death_when_ready())
	await run_ticks(2)
	assert_eq(location(), "Town")
	assert_eq(hud().get_kills_text(), "")


# --- C4: leaving a floor by choice ---


func test_leave_floor_shows_the_town_with_the_progress_unchanged() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 1))
	await enter_floor_through_gate(1)
	skip_to_boss()
	var before: Dictionary = session().get_progress().to_dict()
	var old_floor: FloorScene = floor_scene()
	assert_true(game().leave_floor())
	assert_eq(session().get_place(), TowerSession.Place.TOWN, "the session knows at once")
	assert_same(floor_scene(), old_floor, "the old floor stays until the game's next tick")
	assert_null(town())
	await run_ticks(2)
	assert_not_null(town())
	assert_null(floor_scene())
	assert_false(is_instance_valid(old_floor), "the floor was freed")
	assert_eq(location(), "Town")
	assert_eq(hud().get_kills_text(), "")
	assert_eq_deep(session().get_progress().to_dict(), before)
	assert_true(session().get_progress().is_boss_reached(1), "the boss room entered stays marked")
	await open_gate_menu()
	assert_eq(menu().get_entry_count(), 2, "from the start and at the boss")


func test_leave_floor_after_a_clear_keeps_the_floor_cleared() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 1))
	await enter_floor_through_gate(1)
	skip_to_boss()
	kill_boss()
	await run_ticks(2)
	assert_true(session().get_progress().is_floor_cleared(1))
	assert_true(game().leave_floor())
	await run_ticks(2)
	assert_not_null(town())
	assert_true(session().get_progress().is_floor_cleared(1))
	assert_true(session().get_progress().is_floor_unlocked(2))


func test_leaving_and_entering_the_same_floor_starts_at_room_one_with_full_hp() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 2))
	await enter_floor_through_gate(1)
	floor_scene().skip_room()
	assert_eq(location(), "Floor 1 · Room 2 / 2")
	set_hp(40)
	assert_true(game().leave_floor())
	await run_ticks(2)
	assert_eq(hp(), max_hp(), "the town's player is whole")
	await enter_floor_through_gate(1)
	assert_eq(location(), FIRST_ROOM_TEXT)
	assert_eq(floor_scene().get_run().get_room_index(), 0)
	assert_eq(hp(), max_hp(), "full HP")
	assert_eq(session().get_start_room(), 0)


func test_leaving_and_entering_at_the_boss_starts_in_the_boss_room() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	skip_to_boss()
	assert_true(game().leave_floor())
	await run_ticks(2)
	await enter_floor_through_gate(1, true)
	assert_eq(location(), BOSS_TEXT)
	assert_true(room().get_room_data().is_boss_room)


func test_leave_floor_is_refused_in_the_town() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	var shown: TownScene = town()
	assert_false(game().leave_floor())
	await run_ticks(2)
	assert_same(town(), shown, "nothing was rebuilt")
	assert_eq(session().get_place(), TowerSession.Place.TOWN)


func test_leave_floor_is_refused_in_the_death_pause() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	kill_player()
	await run_ticks(2)
	assert_false(game().leave_floor(), "with time left")
	await run_ticks(DELAY_TICKS * 2)
	assert_false(game().leave_floor(), "with none left")
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_not_null(floor_scene())
	assert_null(town())


# --- C5: is_pause_allowed() ---


func test_is_pause_allowed_in_the_town_and_on_a_floor() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	assert_true(game().is_pause_allowed(), "in the town")
	await enter_floor_through_gate(1)
	assert_true(game().is_pause_allowed(), "on a floor")
	floor_scene().skip_room()
	assert_true(game().is_pause_allowed(), "in the boss room")


func test_is_pause_allowed_is_false_with_the_gate_list_open() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await open_gate_menu()
	assert_false(game().is_pause_allowed(), "the list is open")
	menu().close()
	assert_true(game().is_pause_allowed(), "and true once it is closed")


func test_is_pause_allowed_is_false_in_the_death_pause() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	kill_player()
	await run_ticks(2)
	assert_false(game().is_pause_allowed(), "with time left")
	await run_ticks(DELAY_TICKS * 2)
	assert_false(game().is_pause_allowed(), "with none left")


func test_is_pause_allowed_is_false_between_a_gate_choice_and_the_floor_being_shown() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await open_gate_menu()
	menu().choose(0)
	assert_eq(session().get_place(), TowerSession.Place.FLOOR, "the session is on the floor")
	assert_null(floor_scene(), "but the town is still what is shown")
	assert_false(game().is_pause_allowed(), "between the choice and the tick that rebuilds")
	await get_tree().physics_frame
	assert_not_null(floor_scene(), "shown")
	assert_true(game().is_pause_allowed())


func test_is_pause_allowed_is_false_between_confirming_a_death_and_the_town_being_shown() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	kill_player()
	await run_ticks(2)
	var ready: Callable = func() -> bool: return session().can_confirm_death()
	assert_true(await run_until(ready, DELAY_TICKS * 2))
	assert_true(game().confirm_death())
	assert_false(game().is_pause_allowed(), "the session says town, the floor is still shown")
	await get_tree().physics_frame
	assert_not_null(town())
	assert_true(game().is_pause_allowed(), "the town is shown")


func test_is_pause_allowed_is_false_between_leaving_a_floor_and_the_town_being_shown() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	assert_true(game().leave_floor())
	assert_false(game().is_pause_allowed())
	await get_tree().physics_frame
	assert_not_null(town())
	assert_true(game().is_pause_allowed())


func test_the_three_methods_say_no_for_a_game_built_on_invalid_data() -> void:
	var tower: TowerData = TowerFixtures.tower_of(1)
	tower.town = null
	await spawn_game(tower)
	for error: String in game().get_setup_errors():
		assert_push_error(error)
	assert_false(game().get_setup_errors().is_empty(), "the data was rejected")
	assert_null(session())
	assert_false(game().is_pause_allowed())
	assert_false(game().confirm_death())
	assert_false(game().leave_floor())


func test_the_three_methods_say_no_for_invalid_tower_tunables() -> void:
	Tunables.tower.death_return_delay = -1.0
	await spawn_game(TowerFixtures.tower_of(1))
	for error: String in game().get_setup_errors():
		assert_push_error(error)
	assert_false(game().get_setup_errors().is_empty())
	assert_false(game().is_pause_allowed())
	assert_false(game().confirm_death())
	assert_false(game().leave_floor())
