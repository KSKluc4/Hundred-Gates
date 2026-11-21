# gdlint:disable=max-public-methods,max-file-lines
extends F012GameTest
## F-012 T7 (AC26-AC30, AC32 and C5, C6, C17): the game node on a fixture tower. The shipped tower
## is in test_f012_main.

## The death pause of these tests, in seconds (the shipped one is longer).
const DEATH_DELAY: float = 0.5
const PAUSE_TICKS: int = 60
## Long enough for PAUSE_TICKS of a held key and a few ticks either side, at 120 ticks/s.
const DEATH_PAUSE_SECONDS: float = 1.0
const BOSS_TEXT: String = "Floor 1 · Boss"

## What a probe saw inside a signal handler of the floor scene.
var _seen: Array[Dictionary] = []
var _probe_floor: Variant
var _stick_tilted: bool = false


func before_each() -> void:
	super.before_each()
	_seen = []
	_probe_floor = null
	_stick_tilted = false


func after_each() -> void:
	if _stick_tilted:
		_send_stick_y(0.0)
	await super.after_each()


# --- AC26: the game starts in the town ---


func test_ac26_the_game_starts_in_the_town_with_the_hud_set() -> void:
	await spawn_game(TowerFixtures.tower_of(2))
	assert_eq(game().get_setup_errors(), PackedStringArray(), "no setup errors")
	assert_not_null(town())
	assert_null(floor_scene())
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_eq(session().get_floor_number(), 0)
	assert_eq(location(), "Town")
	assert_eq(hp(), max_hp(), "full HP")
	assert_eq(
		hud().get_health_bar().get_label_text(), "HP %d / %d" % [max_hp(), max_hp()], "the bar too"
	)
	assert_eq(hud().get_health_bar().get_fill_fraction(), 1.0)
	assert_false(hud().is_banner_visible())
	assert_eq(game().process_physics_priority, 2, "after the floor's and the town's 1")


func test_ac26_the_town_gets_the_towers_room_the_sessions_progress_and_the_game_settings() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	await spawn_game(tower, func(node: Game) -> void: node.debug_keys_enabled = false)
	assert_same(town().town_room, tower.town)
	assert_same(town().get_progress(), session().get_progress())
	assert_false(town().player_input_enabled, "the game was built with it off")
	assert_false(town().debug_keys_enabled)
	assert_eq(town().class_data.resource_path, Tunables.WARRIOR_PATH, "null takes the Warrior")
	assert_eq(town().get_parent(), game())


func test_ac26_the_hud_belongs_to_the_game_and_asks_it_for_the_player() -> void:
	await spawn_game(TowerFixtures.tower_of(2))
	assert_eq(hud().get_parent(), game())
	assert_true(hud().player_provider.is_valid())
	assert_same(hud_player(), player())
	assert_same(hud_player(), town().get_room().get_player())


func test_ac26_a_class_set_on_the_game_reaches_the_town_and_the_floor() -> void:
	var tough: ClassData = (load(Tunables.WARRIOR_PATH) as ClassData).duplicate()
	tough.max_hp = 140
	await spawn_game(TowerFixtures.tower_of(1), func(node: Game) -> void: node.class_data = tough)
	assert_eq(max_hp(), 140, "in the town")
	assert_eq(hp(), 140)
	await enter_floor_through_gate(1)
	assert_eq(max_hp(), 140, "and in the floor")
	assert_eq(hp(), 140)


func test_ac26_the_player_input_setting_reaches_the_floor() -> void:
	await spawn_game(
		TowerFixtures.tower_of(1), func(node: Game) -> void: node.player_input_enabled = true
	)
	assert_true(player().input_enabled, "in the town")
	hold_key(KEY_W)
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(
		await run_until(opened, WALK_LIMIT_TICKS), "the player's own input walked to the gate"
	)
	release_held_keys()
	await choose_entry(1)
	assert_not_null(floor_scene())
	assert_true(player().input_enabled, "and in the floor")
	assert_true(floor_scene().player_input_enabled)


# --- Entering a floor ---


func test_the_chosen_floor_is_built_from_the_sessions_answer() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2, 2)
	await spawn_game(tower)
	var old_town: Variant = town()
	await enter_floor_through_gate(1)
	assert_not_null(floor_scene())
	assert_null(town())
	assert_same(floor_scene().floor_data, tower.floors[0])
	assert_eq(floor_scene().start_room, 0)
	assert_eq(floor_scene().get_parent(), game())
	assert_false(floor_scene().death_restarts_room, "D-006: death goes to the town")
	assert_true(floor_scene().debug_keys_enabled, "the game's setting, on by default")
	assert_false(floor_scene().debug_label_visible, "the HUD says where the player is")
	assert_false((floor_scene().get_node("DebugLayer") as CanvasLayer).visible)
	assert_eq(floor_scene().get_setup_errors(), PackedStringArray())
	assert_eq(hp(), max_hp())
	assert_false(is_instance_valid(old_town), "the town was freed")
	assert_eq(session().get_floor_number(), 1)
	assert_eq(session().get_place(), TowerSession.Place.FLOOR)


func test_entering_at_the_boss_starts_in_the_last_room() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 2))
	session().get_progress().mark_boss_reached(1)
	await enter_floor_through_gate(1, true)
	assert_eq(floor_scene().start_room, 2)
	assert_true(room().get_room_data().is_boss_room)
	assert_eq(location(), BOSS_TEXT)
	assert_eq(hp(), max_hp())


func test_the_gate_choice_is_reported_to_the_session_only() -> void:
	await spawn_game(TowerFixtures.tower_of(2))
	await open_gate_menu()
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	menu().choose(0)
	assert_eq(session().get_place(), TowerSession.Place.FLOOR, "the session knows at once")
	assert_not_null(town(), "what is shown changes on the game's next tick")
	assert_null(floor_scene())
	await run_ticks(1)
	assert_null(town())
	assert_not_null(floor_scene())


# --- AC27: the whole loop ---


func test_ac27_the_full_loop_on_a_fixture_tower() -> void:
	set_death_delay(DEATH_DELAY)
	await spawn_game(TowerFixtures.tower_of(2, 2))
	var progress: TowerProgress = session().get_progress()
	# The gate lists floor 1, from the start.
	await open_gate_menu()
	assert_eq(button_texts(), ["Floor 1 — from the start", GateMenu.STAY_TEXT] as Array[String])
	await choose_entry(1)
	# Floor 1 from the start, room 1 of 2.
	assert_eq(session().get_place(), TowerSession.Place.FLOOR)
	assert_eq(location(), "Floor 1 · Room 1 / 2")
	assert_eq(floor_scene().get_run().get_room_index(), 0)
	assert_eq(hp(), max_hp())
	# The rooms are cleared; entering the boss room marks it reached.
	await clear_room_and_advance()
	assert_eq(location(), "Floor 1 · Room 2 / 2")
	assert_false(progress.is_boss_reached(1), "not yet")
	await clear_room_and_advance()
	assert_eq(location(), BOSS_TEXT)
	assert_true(room().get_room_data().is_boss_room)
	assert_true(progress.is_boss_reached(1), "reached the moment the room was entered")
	assert_false(progress.is_floor_cleared(1))
	# The player dies: no banner (the death screen says it), and the floor is still the scene shown
	# during the pause.
	var dead_floor: FloorScene = floor_scene()
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_false(hud().is_banner_visible(), "no banner at a death (F-015/C5)")
	assert_same(floor_scene(), dead_floor, "the floor scene is still shown")
	assert_true(dead_floor.is_inside_tree())
	assert_null(town())
	assert_eq(hp(), 0, "nobody refilled the player in the pause")
	# The pause ends: the town, at full HP.
	assert_true(await confirm_death_when_ready(), "the death was confirmed")
	var back: Callable = func() -> bool: return town() != null
	assert_true(await run_until(back, PAUSE_TICKS * 3), "the town came back")
	await run_ticks(1)
	assert_null(floor_scene())
	assert_false(is_instance_valid(dead_floor), "the floor was freed")
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_eq(location(), "Town")
	assert_eq(hp(), max_hp(), "full HP")
	# The list now offers floor 1 at the boss.
	await open_gate_menu()
	assert_eq(
		button_texts(),
		(
			[
				"Floor 1 — from the start",
				"Floor 1 — at the boss",
				GateMenu.STAY_TEXT,
			]
			as Array[String]
		)
	)
	await choose_entry(1, true)
	# The boss room, at full HP.
	assert_eq(location(), BOSS_TEXT)
	assert_true(room().get_room_data().is_boss_room)
	assert_eq(hp(), max_hp(), "full HP")
	assert_eq(room().count_living_enemies(), 1, "the boss is alive again")
	# The boss dies: the banner names the cleared and the unlocked floor.
	kill_boss()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "Floor 1 cleared — floor 2 unlocked")
	assert_true(progress.is_floor_cleared(1))
	assert_true(progress.is_floor_unlocked(2))
	# The exit leads to the town, whose list now offers floor 2.
	await leave_by_exit()
	assert_not_null(town())
	assert_null(floor_scene())
	assert_eq(location(), "Town")
	await open_gate_menu()
	assert_eq(
		button_texts(),
		(
			[
				"Floor 1 — from the start (cleared)",
				"Floor 1 — at the boss (cleared)",
				"Floor 2 — from the start",
				GateMenu.STAY_TEXT,
			]
			as Array[String]
		)
	)


# --- AC28: the last floor ---


func test_ac28_clearing_the_last_floor_unlocks_nothing_and_the_exit_still_returns_to_town() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	var progress: TowerProgress = session().get_progress()
	await enter_floor_through_gate(1)
	skip_to_boss()
	kill_boss()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "Floor 1 cleared — no floor above yet")
	assert_true(progress.is_floor_cleared(1))
	assert_eq(progress.get_highest_unlocked(), 1, "nothing was unlocked")
	await leave_by_exit()
	assert_not_null(town())
	assert_eq(location(), "Town")
	await open_gate_menu()
	assert_eq(menu().get_entry_count(), 2, "floor 1 from the start and at the boss, nothing more")


func test_ac28_the_banner_of_a_floor_that_is_not_the_last_names_the_floor_it_opened() -> void:
	await spawn_game(TowerFixtures.tower_of(3, 1))
	session().get_progress().mark_floor_cleared(1)
	await enter_floor_through_gate(2)
	skip_to_boss()
	kill_boss()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "Floor 2 cleared — floor 3 unlocked")


func test_ac28_the_banner_text_for_each_case() -> void:
	assert_eq(Game.cleared_banner_text(1, 2, 3), "Floor 1 cleared — floor 2 unlocked")
	assert_eq(Game.cleared_banner_text(3, 0, 3), "Floor 3 cleared — no floor above yet")
	assert_eq(Game.cleared_banner_text(1, 0, 3), "Floor 1 cleared", "a replay")


func test_ac28_a_banner_stays_for_the_banner_duration_and_is_replaced_by_the_next() -> void:
	Tunables.tower.banner_duration = 0.25
	await spawn_game(TowerFixtures.tower_of(2, 1))
	await enter_floor_through_gate(1)
	skip_to_boss()
	kill_boss()
	await run_ticks(2)
	assert_true(hud().is_banner_visible())
	await run_ticks(PAUSE_TICKS * 2)
	assert_false(
		hud().is_banner_visible(), "gone after the tunable's seconds, not the 60 of a test"
	)


# --- A replay ---


func test_a_replayed_floor_shows_no_unlock_and_its_exit_still_returns_to_town() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 1))
	var progress: TowerProgress = session().get_progress()
	await enter_floor_through_gate(1)
	skip_to_boss()
	await clear_boss_and_leave()
	assert_true(progress.is_floor_cleared(1))
	await enter_floor_through_gate(1)
	assert_eq(location(), "Floor 1 · Room 1 / 1", "from the start again")
	skip_to_boss()
	kill_boss()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "Floor 1 cleared")
	assert_string_contains(hud().get_banner_text(), "cleared")
	assert_false(hud().get_banner_text().contains("unlocked"))
	assert_eq(progress.get_highest_unlocked(), 2, "nothing changed")
	await leave_by_exit()
	assert_not_null(town())
	assert_eq(location(), "Town")


# --- AC29: the HUD follows every room and place ---


func test_ac29_the_location_follows_the_town_every_room_the_boss_and_the_way_back() -> void:
	set_death_delay(DEATH_DELAY)
	await spawn_game(TowerFixtures.tower_of(2, 3))
	assert_eq(location(), "Town")
	await enter_floor_through_gate(1)
	assert_eq(location(), "Floor 1 · Room 1 / 3")
	floor_scene().skip_room()
	assert_eq(location(), "Floor 1 · Room 2 / 3")
	floor_scene().skip_room()
	assert_eq(location(), "Floor 1 · Room 3 / 3")
	floor_scene().skip_room()
	assert_eq(location(), BOSS_TEXT)
	await clear_boss_and_leave()
	assert_eq(location(), "Town", "after the exit")
	await enter_floor_through_gate(2)
	assert_eq(location(), "Floor 2 · Room 1 / 3", "floor 2")
	skip_to_boss()
	assert_eq(location(), "Floor 2 · Boss")
	kill_player()
	await run_ticks(2)
	assert_eq(location(), "Floor 2 · Boss", "the floor is still shown during the pause")
	assert_true(await confirm_death_when_ready(), "the death was confirmed")
	var back: Callable = func() -> bool: return town() != null
	assert_true(await run_until(back, PAUSE_TICKS * 3))
	assert_eq(location(), "Town", "after a death")


func test_ac29_the_health_bar_shows_the_current_rooms_player_after_every_swap() -> void:
	set_death_delay(DEATH_DELAY)
	await spawn_game(TowerFixtures.tower_of(1, 2))
	_assert_the_bar_shows(player())
	var town_player: Variant = player()
	await enter_floor_through_gate(1)
	assert_false(is_instance_valid(town_player), "the town's player is gone")
	_assert_the_bar_shows(player())
	var first_player: Variant = player()
	hit(player().motor, 30)
	assert_eq(hud().get_health_bar().get_label_text(), "HP %d / %d" % [max_hp() - 30, max_hp()])
	floor_scene().skip_room()
	await run_ticks(1)  # The old room is freed at the end of the frame (F-011 DEV-13), not at once.
	assert_false(is_instance_valid(first_player), "the first room's player is gone")
	_assert_the_bar_shows(player())
	assert_eq(hp(), max_hp() - 30, "a skip carries the HP on")
	assert_eq(hud().get_health_bar().get_label_text(), "HP %d / %d" % [max_hp() - 30, max_hp()])
	floor_scene().skip_room()
	_assert_the_bar_shows(player())
	assert_eq(hud().get_health_bar().get_label_text(), "HP %d / %d" % [max_hp(), max_hp()])
	kill_player()
	await run_ticks(2)
	assert_eq(hud().get_health_bar().get_label_text(), "HP 0 / %d" % max_hp(), "the dead player")
	assert_eq(hud().get_health_bar().get_fill_fraction(), 0.0)
	assert_true(await confirm_death_when_ready(), "the death was confirmed")
	var back: Callable = func() -> bool: return town() != null
	assert_true(await run_until(back, PAUSE_TICKS * 3))
	_assert_the_bar_shows(player())
	assert_eq(hud().get_health_bar().get_label_text(), "HP %d / %d" % [max_hp(), max_hp()])


func test_ac29_the_provider_never_answers_with_a_freed_player_through_the_whole_loop() -> void:
	set_death_delay(DEATH_DELAY)
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await open_gate_menu()
	menu().choose(0)
	await _run_checking_the_provider(4)
	skip_to_boss()
	kill_player()
	await _run_checking_the_provider(PAUSE_TICKS * 2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE, "it waits for the person")
	assert_true(game().confirm_death())
	await _run_checking_the_provider(PAUSE_TICKS)
	assert_eq(session().get_place(), TowerSession.Place.TOWN, "the loop did come round")
	assert_not_null(town())
	assert_not_null(hud_player())


# --- AC30: nothing is freed inside its own signal ---


func test_ac30_inside_the_floor_exited_handler_the_floor_is_still_shown_and_gone_later() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	skip_to_boss()
	kill_boss()
	await run_ticks(2)
	_probe_floor = floor_scene()
	floor_scene().floor_exited.connect(_probe_exit)
	await leave_by_exit_without_waiting()
	assert_eq(_seen.size(), 1, "the handler ran once")
	_assert_still_shown(_seen[0])
	assert_eq(_seen[0]["place"], TowerSession.Place.TOWN, "the session had been told")
	await run_ticks(2)
	assert_false(is_instance_valid(_probe_floor), "one tick later the floor is gone")
	assert_null(floor_scene())
	assert_not_null(town(), "and the town is shown")


func test_ac30_inside_the_player_died_handler_the_floor_is_still_shown_and_the_pause_keeps_it(
) -> void:
	set_death_delay(DEATH_DELAY)
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	_probe_floor = floor_scene()
	floor_scene().player_died.connect(_probe_death)
	kill_player()
	await run_ticks(2)
	assert_eq(_seen.size(), 1, "the handler ran once")
	_assert_still_shown(_seen[0])
	assert_eq(_seen[0]["place"], TowerSession.Place.DEATH_PAUSE, "the session had been told")
	for _i: int in PAUSE_TICKS / 2:
		await run_ticks(1)
		assert_same(floor_scene(), _probe_floor, "still the floor during the pause")
		assert_null(town())
	assert_true(await confirm_death_when_ready(), "the death was confirmed")
	var back: Callable = func() -> bool: return town() != null
	assert_true(await run_until(back, PAUSE_TICKS * 3))
	await run_ticks(1)
	assert_false(is_instance_valid(_probe_floor), "after the pause the floor is gone")
	assert_null(floor_scene())


func test_ac30_the_town_is_not_freed_inside_its_own_floor_chosen_signal() -> void:
	await spawn_game(TowerFixtures.tower_of(1))
	_probe_floor = town()
	town().floor_chosen.connect(_probe_choice)
	await open_gate_menu()
	menu().choose(0)
	assert_eq(_seen.size(), 1)
	assert_true(_seen[0]["valid"], "inside the handler")
	assert_true(_seen[0]["in_tree"])
	assert_same(town(), _probe_floor)
	await run_ticks(2)
	assert_false(is_instance_valid(_probe_floor), "one tick later")


func test_ac30_a_swap_is_done_on_the_tick_after_the_report_not_in_the_handler_stack() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	skip_to_boss()
	kill_boss()
	await run_ticks(2)
	var old_floor: Variant = floor_scene()
	assert_true(session().report_floor_exited(), "reported by hand, between ticks")
	assert_true(is_instance_valid(old_floor), "the session changed, what is shown did not")
	assert_same(floor_scene(), old_floor)
	await run_ticks(1)
	assert_false(is_instance_valid(old_floor))
	assert_not_null(town())


# --- AC32: invalid data builds nothing ---


func test_ac32_an_invalid_tower_builds_nothing_and_returns_every_error() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	tower.floors[1].floor_number = 5
	tower.town.is_safe_room = false
	await spawn_game(tower)
	var errors: PackedStringArray = game().get_setup_errors()
	assert_gt(errors.size(), 1, str(errors))
	assert_true(_any(errors, "floor 2: floor_number must be 2"), str(errors))
	assert_true(_any(errors, "town: the town must be a safe room"), str(errors))
	for error: String in errors:
		assert_push_error(error)
	_assert_nothing_built()


func test_ac32_a_tower_with_no_floors_is_refused() -> void:
	var tower: TowerData = TowerFixtures.tower_of(1)
	tower.floors = [] as Array[FloorData]
	await spawn_game(tower)
	assert_true(_any(game().get_setup_errors(), "floors:"), str(game().get_setup_errors()))
	for error: String in game().get_setup_errors():
		assert_push_error(error)
	_assert_nothing_built()


func test_ac32_invalid_tower_tunables_build_nothing() -> void:
	Tunables.tower.death_return_delay = -1.0
	await spawn_game(TowerFixtures.tower_of(1))
	var errors: PackedStringArray = game().get_setup_errors()
	assert_true(_any(errors, "tower tunables:"), str(errors))
	for error: String in errors:
		assert_push_error(error)
	_assert_nothing_built()


func test_ac32_the_keys_and_the_hud_do_nothing_without_a_game() -> void:
	var tower: TowerData = TowerFixtures.tower_of(1)
	tower.town = null
	await spawn_game(tower)
	assert_true(_any(game().get_setup_errors(), "town:"), str(game().get_setup_errors()))
	for error: String in game().get_setup_errors():
		assert_push_error(error)
	press_key(KEY_N)
	press_key(KEY_R)
	await get_tree().physics_frame
	assert_eq(hud().get_health_bar().get_label_text(), "", "no player, no text")
	assert_eq(hud().get_health_bar().get_fill_fraction(), 0.0)
	_assert_nothing_built()


# --- C9: the scenes the game shows sit at the world origin ---


func test_c9_the_town_and_the_floor_the_game_shows_sit_at_the_origin_with_no_errors() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	assert_true(town().global_transform.is_equal_approx(Transform2D.IDENTITY), "the town")
	assert_eq(town().get_setup_errors(), PackedStringArray())
	assert_not_null(town().get_room(), "and it built")
	await enter_floor_through_gate(1)
	assert_true(floor_scene().global_transform.is_equal_approx(Transform2D.IDENTITY), "the floor")
	assert_eq(floor_scene().get_setup_errors(), PackedStringArray())
	assert_not_null(room(), "and it built")


# --- C5: death ---


func test_c5_dying_in_the_boss_room_keeps_the_boss_reached() -> void:
	set_death_delay(DEATH_DELAY)
	await spawn_game(TowerFixtures.tower_of(2, 1))
	var progress: TowerProgress = session().get_progress()
	await enter_floor_through_gate(1)
	skip_to_boss()
	assert_true(progress.is_boss_reached(1))
	kill_player()
	assert_true(await confirm_death_when_ready(), "the death was confirmed")
	var back: Callable = func() -> bool: return town() != null
	assert_true(await run_until(back, PAUSE_TICKS * 3))
	assert_true(progress.is_boss_reached(1), "still reached")
	assert_false(progress.is_floor_cleared(1), "and not cleared")
	assert_false(progress.is_floor_unlocked(2))
	await open_gate_menu()
	assert_eq(menu().get_entry_count(), 2, "from the start and at the boss")


func test_c5_a_player_and_a_boss_dying_in_the_same_tick_is_a_death_and_the_floor_is_not_cleared(
) -> void:
	set_death_delay(DEATH_DELAY)
	await spawn_game(TowerFixtures.tower_of(2, 1))
	var progress: TowerProgress = session().get_progress()
	await enter_floor_through_gate(1)
	skip_to_boss()
	kill_boss()
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_eq(hud().get_banner_text(), "", "a death, not a clear: no banner")
	assert_false(progress.is_floor_cleared(1))
	assert_false(progress.is_floor_unlocked(2))
	assert_true(await confirm_death_when_ready(), "the death was confirmed")
	var back: Callable = func() -> bool: return town() != null
	assert_true(await run_until(back, PAUSE_TICKS * 3))
	assert_false(progress.is_floor_cleared(1), "nothing was cleared in the end either")
	assert_true(progress.is_boss_reached(1))


func test_c5_the_death_shows_no_banner_and_the_return_shows_none_either() -> void:
	set_death_delay(0.25)
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	kill_player()
	await run_ticks(2)
	assert_false(hud().is_banner_visible(), "the death screen says it, not the HUD")
	assert_true(await confirm_death_when_ready(), "the death was confirmed")
	var back: Callable = func() -> bool: return town() != null
	assert_true(await run_until(back, PAUSE_TICKS * 3))
	await run_ticks(PAUSE_TICKS * 2)
	assert_false(hud().is_banner_visible(), "and none after the return")


func test_c5_a_second_death_after_coming_back_works_the_same() -> void:
	set_death_delay(DEATH_DELAY)
	await spawn_game(TowerFixtures.tower_of(1, 1))
	for _i: int in 2:
		await enter_floor_through_gate(1)
		kill_player()
		await run_ticks(2)
		assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
		assert_true(await confirm_death_when_ready(), "the death was confirmed")
		var back: Callable = func() -> bool: return town() != null
		assert_true(await run_until(back, PAUSE_TICKS * 3))
		assert_eq(hp(), max_hp())
		await run_ticks(2)


# --- C10, review round 4 (CR-18): the town is built anew, and the stick is already held ---


func test_cr18_a_stick_held_up_through_the_death_pause_does_not_move_the_new_towns_list() -> void:
	set_death_delay(DEATH_DELAY)
	await spawn_game(TowerFixtures.tower_of(2, 1))
	await enter_floor_through_gate(1)
	skip_to_boss()
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	var old_town: TownScene = town()
	_send_stick_y(-1.0)  # Pushed up during the pause, and held: the new menu gets no event.
	assert_true(await confirm_death_when_ready(), "the death was confirmed")
	var back: Callable = func() -> bool: return town() != null and town() != old_town
	assert_true(await run_until(back, PAUSE_TICKS * 3), "a new town was built")
	await open_gate_menu()
	var last: int = menu().get_entry_count() - 1
	assert_eq(last, 1, "from the start and at the boss")
	assert_eq(menu().get_focus_index(), last, "the list opens on the last floor entry")
	for value: float in [-0.8, -0.4, -0.1, 0.0]:  # Plain letting go.
		_send_stick_y(value)
		assert_eq(menu().get_focus_index(), last, "letting go moves nothing (%s)" % value)
	_send_stick_y(-1.0)
	assert_eq(menu().get_focus_index(), last - 1, "a new push still moves one step")


# --- C5, review round 1 (CR-4): the dead player and the keys during the pause ---


func test_cr4_during_the_death_pause_nothing_the_person_does_has_any_effect() -> void:
	set_death_delay(DEATH_PAUSE_SECONDS)
	await spawn_game(
		TowerFixtures.tower_of(1, 1), func(node: Game) -> void: node.player_input_enabled = true
	)
	# The player's own input walks to the gate and takes the only entry.
	hold_key(KEY_W)
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(
		await run_until(opened, WALK_LIMIT_TICKS), "the player's own input reached the gate"
	)
	release_held_keys()
	await choose_entry(1)
	assert_true(player().input_enabled, "in the floor, alive: the input is on")
	enemy().logic.set_ai_enabled(false)  # Nobody pushes the body: any motion would be input.
	var dead_floor: FloorScene = floor_scene()
	var dead_room: Room = room()
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_false(player().input_enabled, "a dead player takes no input")
	var start: Vector2 = player().motor.get_position_tiles()
	# A held movement key, a dodge, an attack, and R and N pressed in the middle of the pause.
	await hold_key_between_ticks(KEY_W)
	await hold_key_between_ticks(KEY_J)
	await hold_key_between_ticks(KEY_SPACE)
	var states: Array[int] = []
	for tick: int in PAUSE_TICKS:
		if tick == PAUSE_TICKS / 2:
			press_key(KEY_R)
			press_key(KEY_N)
		await get_tree().physics_frame
		if not states.has(player().motor.get_state()):
			states.append(player().motor.get_state())
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE, "still in the pause")
	assert_same(floor_scene(), dead_floor, "the same floor scene")
	assert_same(room(), dead_room, "and the same room: R did not rebuild it")
	assert_eq(dead_floor.get_run().get_room_index(), 0, "N did not move on")
	assert_eq(hp(), 0, "still dead")
	assert_eq(player().motor.get_position_tiles(), start, "did not walk or dash")
	assert_eq(states, [PlayerMotor.State.IDLE] as Array[int], "never moving, dashing or attacking")
	assert_false(hud().is_banner_visible(), "no banner in the pause")
	# The delay passes and the person confirms, with the keys let go: the town, at full HP and
	# with input.
	release_held_keys()
	assert_true(await confirm_death_when_ready(), "the death was confirmed")
	var back: Callable = func() -> bool: return town() != null
	assert_true(await run_until(back, PAUSE_TICKS * 4), "the town came back")
	await run_ticks(1)
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_false(is_instance_valid(dead_floor), "the floor was freed")
	assert_eq(hp(), max_hp(), "full HP")
	assert_true(player().input_enabled, "and the input as the game was built with it")


# --- C6: an uncleared room's exit does nothing ---


func test_c6_the_exit_of_an_uncleared_boss_room_does_nothing() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 1))
	await enter_floor_through_gate(1)
	skip_to_boss()
	enemy().logic.set_ai_enabled(false)
	put_player_at(Vector2(room().get_room_data().get_exit_tiles()[0]) + Vector2(0.5, 0.5))
	await run_ticks(PAUSE_TICKS)
	assert_eq(session().get_place(), TowerSession.Place.FLOOR)
	assert_not_null(floor_scene())
	assert_null(town())
	assert_false(session().report_floor_exited(), "and the session refuses it as well")


func test_c6_the_exit_of_an_uncleared_combat_room_does_nothing() -> void:
	await spawn_game(TowerFixtures.tower_of(1, 2))
	await enter_floor_through_gate(1)
	enemy().logic.set_ai_enabled(false)
	var first_room: Room = room()
	put_player_at(Vector2(room().get_room_data().get_exit_tiles()[0]) + Vector2(0.5, 0.5))
	await run_ticks(PAUSE_TICKS)
	assert_same(room(), first_room, "no next room")
	assert_eq(floor_scene().get_run().get_room_index(), 0)
	assert_eq(session().get_place(), TowerSession.Place.FLOOR)
	assert_false(session().get_progress().is_boss_reached(1))


func test_c6_leaving_by_the_exit_of_a_cleared_combat_room_goes_to_the_next_room_not_the_town(
) -> void:
	await spawn_game(TowerFixtures.tower_of(1, 2))
	await enter_floor_through_gate(1)
	await clear_room_and_advance()
	assert_eq(session().get_place(), TowerSession.Place.FLOOR)
	assert_eq(location(), "Floor 1 · Room 2 / 2")


# --- C17: debug keys ---


func test_c17_with_the_debug_keys_off_n_and_r_do_nothing_in_the_town_and_in_a_floor() -> void:
	await spawn_game(
		TowerFixtures.tower_of(3, 3), func(node: Game) -> void: node.debug_keys_enabled = false
	)
	var progress: TowerProgress = session().get_progress()
	press_key(KEY_N)
	assert_false(progress.is_floor_cleared(1), "N in the town")
	assert_false(progress.is_boss_reached(1))
	await enter_floor_through_gate(1)
	assert_false(floor_scene().debug_keys_enabled)
	var first_room: Room = room()
	press_key(KEY_N)
	assert_eq(floor_scene().get_run().get_room_index(), 0, "N in a floor")
	assert_same(room(), first_room)
	floor_scene().skip_room()
	var second_room: Room = room()
	press_key(KEY_R)
	assert_same(room(), second_room, "R in a floor")
	assert_eq(floor_scene().get_run().get_room_index(), 1)


func test_c17_with_the_debug_keys_on_n_in_the_town_unlocks_floor_2_once() -> void:
	await spawn_game(TowerFixtures.tower_of(3, 1))
	var progress: TowerProgress = session().get_progress()
	press_key(KEY_N)
	assert_true(progress.is_floor_cleared(1))
	assert_true(progress.is_floor_unlocked(2))
	assert_false(progress.is_floor_cleared(2), "the game did not handle the key a second time")
	assert_eq(progress.get_highest_unlocked(), 2)
	await open_gate_menu()
	assert_eq(menu().get_entry_count(), 3, "floor 1 start, floor 1 boss, floor 2 start")


func test_c17_with_the_debug_keys_on_n_in_a_floor_skips_exactly_one_room_and_r_restarts_it(
) -> void:
	await spawn_game(TowerFixtures.tower_of(1, 3))
	await enter_floor_through_gate(1)
	press_key(KEY_N)
	assert_eq(floor_scene().get_run().get_room_index(), 1, "one room, not two")
	assert_eq(location(), "Floor 1 · Room 2 / 3")
	var before: Room = room()
	press_key(KEY_R)
	assert_ne(room(), before, "R built the room again")
	assert_eq(floor_scene().get_run().get_room_index(), 1)
	assert_eq(session().get_place(), TowerSession.Place.FLOOR)


# --- AC33 (Gate B, Q10): the HUD says how much HP came back ---


func test_ac33_a_cleared_room_shows_the_heal_and_the_bar_shows_the_healed_value() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 2))
	await enter_floor_through_gate(1)
	set_hp(40)
	kill_all()
	await run_ticks(2)
	assert_true(hud().is_banner_visible())
	assert_eq(hud().get_banner_text(), "+30 HP")
	assert_eq(hp(), 70)
	assert_eq(hud().get_health_bar().get_label_text(), "HP 70 / 100", "the bar shows the new value")
	assert_almost_eq(hud().get_health_bar().get_fill_fraction(), 0.7, 0.001)


func test_ac33_the_banner_says_what_was_really_healed() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 2))
	await enter_floor_through_gate(1)
	set_hp(90)
	kill_all()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "+10 HP", "capped at max")
	assert_eq(hp(), 100)


func test_ac33_the_text_is_one_constant_with_a_format() -> void:
	assert_eq(Game.HEALED_FORMAT, "+%d HP")
	assert_eq(Game.HEALED_FORMAT % 30, "+30 HP")


func test_ac33_clearing_a_room_at_full_hp_shows_no_heal_banner() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 2))
	await enter_floor_through_gate(1)
	kill_all()
	await run_ticks(2)
	assert_true(room().is_door_open(), "the room was cleared")
	assert_false(hud().is_banner_visible())
	assert_eq(hud().get_banner_text(), "")


func test_ac33_a_heal_banner_goes_after_the_banner_duration() -> void:
	Tunables.tower.banner_duration = 0.25
	await spawn_game(TowerFixtures.tower_of(2, 2))
	await enter_floor_through_gate(1)
	set_hp(40)
	kill_all()
	await run_ticks(2)
	assert_true(hud().is_banner_visible())
	await run_ticks(PAUSE_TICKS * 2)
	assert_false(hud().is_banner_visible())


func test_ac33_entering_the_boss_room_below_max_shows_the_refill() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 1))
	await enter_floor_through_gate(1)
	kill_all()
	await run_ticks(2)
	assert_false(hud().is_banner_visible(), "full HP: the clear healed nothing")
	set_hp(55)
	await _walk_into_the_next_room()
	assert_true(room().get_room_data().is_boss_room)
	assert_eq(hp(), 100)
	assert_eq(hud().get_banner_text(), "+45 HP")
	assert_eq(hud().get_health_bar().get_label_text(), "HP 100 / 100")
	assert_eq(location(), BOSS_TEXT)


func test_ac33_the_boss_refill_replaces_the_clears_own_heal_banner() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 1))
	await enter_floor_through_gate(1)
	set_hp(40)
	kill_all()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "+30 HP")
	set_hp(55)  # Hurt again before the door.
	await _walk_into_the_next_room()
	assert_eq(hud().get_banner_text(), "+45 HP", "the newer heal is the one shown")


func test_ac33_skipping_into_the_boss_room_shows_the_refill_only() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 2))
	await enter_floor_through_gate(1)
	set_hp(60)
	floor_scene().skip_room()
	assert_false(hud().is_banner_visible(), "the skip healed nothing, and the next room is normal")
	floor_scene().skip_room()
	assert_true(room().get_room_data().is_boss_room)
	assert_eq(hud().get_banner_text(), "+40 HP")
	assert_eq(hp(), 100)


func test_ac33_a_debug_restart_shows_no_heal_banner() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 2))
	await enter_floor_through_gate(1)
	set_hp(30)
	floor_scene().restart_room()
	assert_eq(hp(), 100)
	assert_false(hud().is_banner_visible())


func test_ac33_the_floor_cleared_banner_is_what_shows_after_the_boss_dies() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 1))
	await enter_floor_through_gate(1)
	set_hp(60)
	floor_scene().skip_room()
	assert_eq(hud().get_banner_text(), "+40 HP", "the refill is still up when the boss dies")
	set_hp(50)
	kill_boss()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "Floor 1 cleared — floor 2 unlocked")
	assert_eq(hp(), 50, "a boss clear heals nothing, so no heal banner followed")
	await run_ticks(PAUSE_TICKS)
	assert_eq(hud().get_banner_text(), "Floor 1 cleared — floor 2 unlocked")


func test_ac33_the_boss_dying_with_no_heal_banner_before_shows_the_cleared_text() -> void:
	await spawn_game(TowerFixtures.tower_of(2, 1))
	await enter_floor_through_gate(1)
	floor_scene().skip_room()  # Full HP: the refill is 0, nothing is shown.
	assert_false(hud().is_banner_visible())
	kill_boss()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "Floor 1 cleared — floor 2 unlocked")


func test_ac33_a_heal_in_the_death_pause_shows_no_banner() -> void:
	set_death_delay(DEATH_PAUSE_SECONDS)
	await spawn_game(TowerFixtures.tower_of(2, 1))
	await enter_floor_through_gate(1)
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_false(hud().is_banner_visible())
	# A debug skip during the pause enters the boss room: the player carries 0 HP there and the
	# room's entry HP is full, which is a heal to the floor scene but not to the person watching.
	floor_scene().skip_room()
	assert_true(room().get_room_data().is_boss_room, "the skip did swap the room")
	await run_ticks(2)
	assert_false(hud().is_banner_visible(), "still no banner")
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)


func test_ac33_dying_after_a_heal_hides_the_heal_banner() -> void:
	set_death_delay(DEATH_PAUSE_SECONDS)
	await spawn_game(TowerFixtures.tower_of(2, 2))
	await enter_floor_through_gate(1)
	set_hp(40)
	kill_all()
	await run_ticks(2)
	assert_eq(hud().get_banner_text(), "+30 HP")
	kill_player()
	await run_ticks(2)
	assert_false(hud().is_banner_visible(), "the heal banner is gone, and nothing replaced it")


# --- helpers ---


## Stands at the cleared room's door and walks out of it until the run is in the next room.
func _walk_into_the_next_room() -> void:
	var index: int = floor_scene().get_run().get_room_index()
	put_player_at_door()
	var moved: Callable = func() -> bool: return floor_scene().get_run().get_room_index() != index
	assert_true(await run_until(moved, WALK_LIMIT_TICKS, door_outward()), "the next room")


func leave_by_exit_without_waiting() -> void:
	put_player_at_door()
	var gone: Callable = func() -> bool: return not _seen.is_empty()
	assert_true(await run_until(gone, WALK_LIMIT_TICKS, door_outward()), "the exit was reached")


func _probe_exit(_floor_number: int) -> void:
	_seen.append(_look_at_the_floor())


func _probe_death() -> void:
	_seen.append(_look_at_the_floor())


func _probe_choice(_floor_number: int, _at_boss: bool) -> void:
	(
		_seen
		. append(
			{
				"valid": is_instance_valid(_probe_floor),
				"in_tree":
				is_instance_valid(_probe_floor) and (_probe_floor as Node).is_inside_tree(),
			}
		)
	)


## What is true of the old floor scene while it is inside one of its own signals.
func _look_at_the_floor() -> Dictionary:
	return {
		"valid": is_instance_valid(_probe_floor),
		"in_tree": is_instance_valid(_probe_floor) and (_probe_floor as Node).is_inside_tree(),
		"shown": game().get_floor_scene() == _probe_floor,
		"town_shown": town() != null,
		"place": session().get_place(),
		"room_valid": is_instance_valid((_probe_floor as FloorScene).get_room()),
	}


func _assert_still_shown(seen: Dictionary) -> void:
	assert_true(seen["valid"], "valid inside the handler")
	assert_true(seen["in_tree"], "in the tree inside the handler")
	assert_true(seen["shown"], "still the scene the game shows")
	assert_false(seen["town_shown"], "and no town yet")
	assert_true(seen["room_valid"], "with its room")


func _assert_the_bar_shows(shown: Player) -> void:
	assert_true(is_instance_valid(shown))
	assert_same(hud_player(), shown, "the provider answers with the shown player")
	var state: CombatState = shown.motor.get_combat_state()
	assert_eq(
		hud().get_health_bar().get_label_text(), "HP %d / %d" % [state.get_hp(), state.get_max_hp()]
	)


## Every tick: the provider answers null or a live player.
func _run_checking_the_provider(ticks: int) -> void:
	for _i: int in ticks:
		var answer: Variant = hud_player()
		assert_true(answer == null or is_instance_valid(answer), "never a freed player")
		await run_ticks(1)


func _assert_nothing_built() -> void:
	assert_null(session())
	assert_null(town())
	assert_null(floor_scene())
	assert_null(game().get_player())
	assert_false(game().is_physics_processing(), "nothing steps")
	assert_eq(game().get_child_count(), 1, "only the HUD")
	assert_not_null(hud())


func _any(errors: PackedStringArray, part: String) -> bool:
	for error: String in errors:
		if error.contains(part):
			return true
	return false


func _send_stick_y(value: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_stick_tilted = true
