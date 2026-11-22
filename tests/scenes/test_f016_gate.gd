extends F016ShellTest
## F-016 T6 (AC23 in the running game, AC25's shell part; C19): the odds at the tower gate, through
## a real `Shell` on a fixture tower. `Game` works the texts out each time the town's gate opens,
## from the character's state and the catalog; `TownScene` passes them on every `open()`, also the
## one after debug N. The fixture boss table is three swords of 45 damage (11/11/23, no trait) at
## 30, 20 and 10 percent, the same on every floor; expected texts are written out.

const BOSS_HEADING: String = "Boss drops:"
const LINE_A: String = "30% chance: Sword fixture_boss_a — 45 (11/11/23) — No trait"
const LINE_B: String = "20% chance: Sword fixture_boss_b — 45 (11/11/23) — No trait"
const LINE_C: String = "10% chance: Sword fixture_boss_c — 45 (11/11/23) — No trait"
const GUARANTEE: String = "Your next win is sure to drop one of these, in these proportions."
const NOTHING: String = "Nothing: 40%"
const FIRST_OF_HUNDRED: String = "50% chance: Sword fixture_boss_a — 45 (11/11/23) — No trait"
const SECOND_OF_HUNDRED: String = "30% chance: Sword fixture_boss_b — 45 (11/11/23) — No trait"
const THIRD_OF_HUNDRED: String = "20% chance: Sword fixture_boss_c — 45 (11/11/23) — No trait"
const DEBUG_NEXT_ROOM: StringName = &"debug_next_room"


## "Boss drops:", the three lines and `last`.
func _odds_with(last: String) -> String:
	return "\n".join([BOSS_HEADING, LINE_A, LINE_B, LINE_C, last])


func _start(floor_count: int = 1, catalog: LootCatalog = null) -> void:
	var tower: TowerData = F016LootTest.loot_tower([1], floor_count)
	var used: LootCatalog = catalog if catalog != null else F016LootTest.quiet_catalog(tower)
	await start_loot_game(tower, used)


## The gate closed by its stay entry and opened again by walking into it, as a person does.
func _reopen_the_gate() -> void:
	menu().cancel()
	assert_false(menu().is_open())
	await run_ticks(2)
	await open_gate_menu()


# --- AC23 ---


func test_ac23_focusing_floor_1_shows_the_boss_table_and_the_guarantee_line() -> void:
	await _start()
	await open_gate_menu()
	assert_true(menu().is_odds_visible())
	assert_eq(menu().get_odds_text(), _odds_with(GUARANTEE))
	assert_eq(menu().get_focus_index(), 0, "the focus is on the floor's entry")


func test_ac23_stay_in_town_hides_the_area_and_the_floor_shows_it_again() -> void:
	await _start()
	await open_gate_menu()
	await tap_key(KEY_DOWN)
	assert_eq(menu().get_focus_index(), 1, "the stay entry")
	assert_false(menu().is_odds_visible())
	assert_eq(menu().get_odds_text(), "")
	await tap_key(KEY_UP)
	assert_true(menu().is_odds_visible())
	assert_eq(menu().get_odds_text(), _odds_with(GUARANTEE))


func test_ac23_after_a_boss_sword_of_the_floor_is_taken_the_gate_says_nothing_40() -> void:
	await _start()
	await open_gate_menu()
	assert_eq(menu().get_odds_text(), _odds_with(GUARANTEE))
	assert_false(loot().is_boss_sword_taken(1))
	loot().report_taken(&"fixture_boss_a", 1)  # What walking onto the boss's sword does.
	await _reopen_the_gate()
	assert_true(menu().is_odds_visible())
	assert_eq(menu().get_odds_text(), _odds_with(NOTHING), "the guarantee line is gone")
	assert_eq(menu().get_odds_text().split("\n")[-1], "Nothing: 40%", "the last line")


func test_ac23_a_table_adding_up_to_100_has_no_nothing_line() -> void:
	var tower: TowerData = F016LootTest.loot_tower([1])
	var catalog: LootCatalog = ItemFixtures.catalog_with(
		tower,
		false,
		F016LootTest.boss_swords(),
		PackedInt32Array([50, 30, 20]),
		ItemFixtures.valid_swords(2)
	)
	await _start(1, catalog)
	await open_gate_menu()
	var lines: Array[String] = [BOSS_HEADING, FIRST_OF_HUNDRED, SECOND_OF_HUNDRED, THIRD_OF_HUNDRED]
	assert_eq(menu().get_odds_text(), "\n".join(lines + [GUARANTEE]))
	loot().report_taken(&"fixture_boss_a", 1)
	await _reopen_the_gate()
	assert_eq(menu().get_odds_text(), "\n".join(lines), "no Nothing line, and no guarantee")


func test_ac23_with_no_catalog_the_odds_are_never_shown() -> void:
	var tower: TowerData = F016LootTest.loot_tower([1])
	await start_loot_game(tower, null)
	assert_eq(game().get_gate_odds(), {})
	await open_gate_menu()
	assert_true(menu().is_open())
	assert_false(menu().is_odds_visible())
	assert_eq(menu().get_odds_text(), "")
	await tap_key(KEY_DOWN)
	assert_false(menu().is_odds_visible())


func test_ac23_the_odds_are_still_there_when_the_gate_reopens_after_debug_n() -> void:
	await _start(2)
	await open_gate_menu()
	assert_eq(menu().get_entry_count(), 1, "only floor 1 is open")
	press_action(DEBUG_NEXT_ROOM)  # Clears the highest unlocked floor: floor 2 opens.
	assert_true(menu().is_open(), "the list was opened again")
	assert_eq(menu().get_entry_count(), 3, "floor 1 from the start, at the boss, and floor 2")
	assert_eq(menu().get_focus_index(), 2, "the focus is on the last floor entry")
	assert_true(menu().is_odds_visible(), "the odds came back with it")
	assert_eq(menu().get_odds_text(), _odds_with(GUARANTEE))
	await tap_key(KEY_UP)
	assert_eq(menu().get_odds_text(), _odds_with(GUARANTEE), "floor 1's entry at the boss, too")
	await tap_key(KEY_UP)
	assert_eq(menu().get_odds_text(), _odds_with(GUARANTEE))


func test_ac23_the_text_is_current_each_time_the_gate_opens() -> void:
	await _start(2)
	await open_gate_menu()
	assert_eq(menu().get_odds_text(), _odds_with(GUARANTEE))
	loot().report_taken(&"fixture_boss_a", 1)
	press_action(DEBUG_NEXT_ROOM)  # Opened again by debug N: floor 1's flag is the new one.
	assert_eq(menu().get_entry_count(), 3)
	assert_eq(menu().get_odds_text(), _odds_with(GUARANTEE), "floor 2's flag was not touched")
	await tap_key(KEY_UP)
	await tap_key(KEY_UP)
	assert_eq(menu().get_focus_index(), 0)
	assert_eq(menu().get_odds_text(), _odds_with(NOTHING), "floor 1's was taken")


## The whole way: the boss dies, its guaranteed sword is taken as the player leaves, and the next
## time the gate opens it says so.
func test_ac23_a_boss_sword_taken_in_play_changes_what_the_gate_says() -> void:
	await _start()
	await open_gate_menu()
	assert_eq(menu().get_odds_text(), _odds_with(GUARANTEE))
	menu().cancel()
	await run_ticks(2)
	await enter_frozen_floor()
	await clear_here()
	put_player_at_door()
	var moved: Callable = func() -> bool: return room().get_room_data().is_boss_room
	assert_true(await run_until(moved, WALK_LIMIT_TICKS, door_outward()), "the boss room")
	await clear_boss_and_leave()
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_true(loot().is_boss_sword_taken(1), "the boss's sword was taken at the door")
	await open_gate_menu()
	assert_eq(menu().get_odds_text(), _odds_with(NOTHING), "the guarantee is spent")


func test_ac23_a_floor_without_a_table_has_no_entry_and_shows_nothing() -> void:
	var tower: TowerData = F016LootTest.loot_tower([1], 2)
	var catalog: LootCatalog = F016LootTest.quiet_catalog(tower)
	catalog.floors[1] = null
	await _start(2, catalog)
	var odds: Dictionary = game().get_gate_odds()
	assert_eq(odds.keys(), [1], "floor 2 has no table, so no text")
	assert_eq(odds[1], _odds_with(GUARANTEE))
	session().get_progress().mark_boss_reached(1)
	session().get_progress().mark_floor_cleared(1)
	await open_gate_menu()
	assert_eq(menu().get_entry_count(), 3)
	assert_eq(menu().get_focus_index(), 2, "floor 2, the last entry")
	assert_false(menu().is_odds_visible(), "no table, nothing shown")
	await tap_key(KEY_UP)
	assert_true(menu().is_odds_visible(), "floor 1 at the boss")
	assert_eq(menu().get_odds_text(), _odds_with(GUARANTEE))


func test_ac23_a_floor_with_an_empty_boss_table_has_no_entry() -> void:
	var tower: TowerData = F016LootTest.loot_tower([1])
	var catalog: LootCatalog = ItemFixtures.catalog_with(
		tower, false, [] as Array[SwordData], PackedInt32Array(), ItemFixtures.valid_swords(2)
	)
	await _start(1, catalog)
	assert_eq(game().get_gate_odds(), {}, "an empty table says nothing")
	await open_gate_menu()
	assert_false(menu().is_odds_visible())


func test_ac23_the_odds_are_the_games_the_gate_only_passes_them_on() -> void:
	await _start()
	assert_eq(game().get_gate_odds(), {1: _odds_with(GUARANTEE)})
	loot().report_taken(&"fixture_boss_c", 1)
	assert_eq(game().get_gate_odds(), {1: _odds_with(NOTHING)})


func test_ac23_a_town_built_after_a_return_from_a_floor_asks_again() -> void:
	await _start()
	await enter_frozen_floor()
	loot().report_taken(&"fixture_boss_b", 1)  # A boss sword taken on that floor.
	await tap_key(KEY_ESCAPE)
	choose(ShellMenus.LEAVE)
	choose(ShellMenus.CONFIRM)
	await wait_for_town()
	await open_gate_menu()
	assert_eq(menu().get_odds_text(), _odds_with(NOTHING), "a new town, the flag as it is now")


# --- AC25's shell part ---


func test_ac25_a_catalog_with_an_error_makes_start_fail_on_the_title_like_other_data() -> void:
	var tower: TowerData = F016LootTest.loot_tower([1])
	var catalog: LootCatalog = F016LootTest.quiet_catalog(tower)
	catalog.starter_sword = null
	var expected: PackedStringArray = catalog.validate(
		tower, ItemFixtures.class_data(), Tunables.items
	)
	assert_gt(expected.size(), 0, "the premise: the catalog has an error")
	await spawn_loot_shell(tower, catalog)
	watch_signals(flow())
	choose(ShellMenus.START)
	for error: String in expected:
		assert_push_error("loot catalog: %s" % error)
	assert_eq(flow().get_state(), ShellFlow.State.TITLE, "the title stays up")
	assert_signal_not_emitted(flow(), "state_changed")
	assert_true(panel().is_open())
	assert_eq(
		panel().get_body(),
		"Could not start: the game data has %d error(s). See the log." % expected.size(),
		"the same line as for a tower with errors"
	)
	assert_eq(panel().get_focus_id(), ShellMenus.START)
	assert_null(shell().get_game(), "no game")
	assert_true(space_is_active(), "the physics space is active")
	assert_false(shell().is_guarding())
	await get_tree().process_frame
	assert_null(shell().get_node_or_null("Game"), "no Game node is left after a frame")


func test_ac25_a_start_that_works_after_a_failed_one_forgets_the_line() -> void:
	var tower: TowerData = F016LootTest.loot_tower([1])
	var bad: LootCatalog = F016LootTest.quiet_catalog(tower)
	bad.starter_sword = null
	await spawn_loot_shell(tower, bad)
	choose(ShellMenus.START)
	for error: String in bad.validate(tower, ItemFixtures.class_data(), Tunables.items):
		assert_push_error("loot catalog: %s" % error)
	assert_ne(panel().get_body(), "")
	Tunables.loot_catalog = F016LootTest.quiet_catalog(tower)
	await start_game()
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_eq(inventory().get_equipped_id(), ItemFixtures.STARTER_ID)
