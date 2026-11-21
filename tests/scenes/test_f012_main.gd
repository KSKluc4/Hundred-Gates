extends F012GameTest
## F-012 T7 (AC26, AC31): the real scenes/main.tscn with the shipped tower. The rules of the loop
## are tested on fixture towers in test_f012_game. F-015/T7: main.tscn now opens on the title
## screen and the game is the shell's child; spawn_main() chooses Start, so every test here runs on
## the game that Start builds (the title screen itself is test_f015_main).

const FLOOR_PATH_FORMAT: String = "res://data/floors/floor_%d.tres"  # G5
const FLOOR_NUMBERS: Array[int] = [1, 2, 3]
const BOSSES: Dictionary = {1: &"warden", 2: &"hexer", 3: &"juggernaut"}
const OVERLAY_NODE: NodePath = ^"DebugOverlay"
const SHELL_NODE: NodePath = ^"Shell"

# --- AC26: main.tscn, once started, is in the town ---


func test_ac26_main_after_start_is_in_the_town_with_the_hud_showing_town_and_full_hp() -> void:
	await spawn_main()
	assert_eq(game().get_setup_errors(), PackedStringArray(), "no setup errors")
	assert_eq(game().get_parent(), main_scene().get_node(SHELL_NODE), "the shell's child")
	assert_eq(game().get_parent().get_parent(), main_scene())
	assert_not_null(town())
	assert_null(floor_scene())
	assert_same(game().tower_data, load(Tunables.TOWER_PATH), "the shipped tower")
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_eq(location(), "Town")
	assert_eq(hp(), max_hp())
	assert_eq(hud().get_health_bar().get_label_text(), "HP %d / %d" % [max_hp(), max_hp()])
	assert_eq(hud().get_health_bar().get_fill_fraction(), 1.0)
	assert_eq(get_errors().size(), 0, str(get_errors()))


func test_ac26_main_still_holds_the_debug_overlay() -> void:
	await spawn_main()
	assert_true(main_scene().get_node_or_null(OVERLAY_NODE) is DebugOverlay)
	assert_true(main_scene().get_node_or_null(SHELL_NODE) is Shell)
	assert_eq(main_scene().get_child_count(), 2, "the overlay and the shell")
	assert_eq(main_scene().name, &"Main")


func test_ac26_the_shipped_town_is_walkable_and_its_gate_lists_floor_1() -> void:
	await spawn_main()
	assert_eq(town().get_setup_errors(), PackedStringArray())
	await open_gate_menu()
	assert_eq(button_texts(), ["Floor 1 — from the start", GateMenu.STAY_TEXT] as Array[String])


func test_ac26_the_health_bar_does_not_cover_the_debug_overlay() -> void:
	await spawn_main()
	var overlay: DebugOverlay = main_scene().get_node(OVERLAY_NODE)
	assert_true(overlay.visible, "the shipped tunables show the overlay on start")
	await wait_process_frames(2)  # The overlay's label gets its text and size.
	var overlay_rect: Rect2 = (overlay.get_node("Label") as Label).get_global_rect()
	assert_gt(overlay_rect.size.y, 0.0, "the overlay has its text")
	var bar_rect: Rect2 = hud().get_health_bar().get_global_rect()
	assert_false(bar_rect.intersects(overlay_rect), "bar %s, overlay %s" % [bar_rect, overlay_rect])
	assert_true(get_viewport().get_visible_rect().encloses(bar_rect), "the bar is on screen")


func test_ac26_the_health_bar_text_is_on_screen_and_centred_on_the_bar() -> void:
	await spawn_main()
	await wait_process_frames(2)
	var bar: HealthBar = hud().get_health_bar()
	var text_rect: Rect2 = (bar.get_node("Label") as Label).get_global_rect()
	assert_true(get_viewport().get_visible_rect().encloses(text_rect), "the text: %s" % text_rect)
	var bar_centre: float = bar.get_global_rect().get_center().y
	assert_almost_eq(text_rect.get_center().y, bar_centre, 2.0, "text %s" % text_rect)


func test_ac26_the_health_bar_does_not_cover_the_boss_bar_and_its_label() -> void:
	await spawn_main()
	for _i: int in FLOOR_NUMBERS.size():
		press_key(KEY_N)
	for number: int in FLOOR_NUMBERS:
		await enter_floor_through_gate(number, true)
		_assert_boss_room(number)
		await wait_process_frames(2)  # The boss bar's label gets its text and size.
		var boss_bar: BossBar = room().get_node("BossBarLayer").get_child(0)
		var boss_rect: Rect2 = Rect2(boss_bar.get_global_position(), boss_bar.bar_size_px)
		boss_rect = boss_rect.merge((boss_bar.get_node("Label") as Label).get_global_rect())
		var bar_rect: Rect2 = hud().get_health_bar().get_global_rect()
		assert_false(bar_rect.intersects(boss_rect), "bar %s, boss %s" % [bar_rect, boss_rect])
		var text_rect: Rect2 = (hud().get_health_bar().get_node("Label") as Label).get_global_rect()
		assert_false(text_rect.intersects(boss_rect), "text %s, boss %s" % [text_rect, boss_rect])
		await clear_boss_and_leave()


# --- AC31: the three shipped floors, end to end ---


func test_ac31_floor_1_from_the_start_to_the_boss_and_back_to_town() -> void:
	await _floor_end_to_end(1)


func test_ac31_floor_2_from_the_start_to_the_boss_and_back_to_town() -> void:
	await _floor_end_to_end(2)


func test_ac31_floor_3_from_the_start_to_the_boss_and_back_to_town() -> void:
	await _floor_end_to_end(3)


func test_ac31_after_the_debug_unlock_every_floor_can_be_entered_at_the_boss() -> void:
	await spawn_main()
	for _i: int in FLOOR_NUMBERS.size():
		press_key(KEY_N)
	var progress: TowerProgress = session().get_progress()
	for number: int in FLOOR_NUMBERS:
		assert_true(progress.is_floor_cleared(number), "floor %d" % number)
		assert_true(progress.is_boss_reached(number))
	await open_gate_menu()
	assert_eq(menu().get_entry_count(), 6, "every floor, from the start and at the boss")
	menu().cancel()
	for number: int in FLOOR_NUMBERS:
		await enter_floor_through_gate(number, true)
		_assert_boss_room(number)
		await clear_boss_and_leave()
		assert_not_null(town(), "floor %d: back in the town" % number)
	assert_eq(get_errors().size(), 0, str(get_errors()))


func test_ac31_every_floor_starts_in_its_first_room_with_no_setup_errors() -> void:
	await spawn_main()
	for _i: int in FLOOR_NUMBERS.size():
		press_key(KEY_N)
	for number: int in FLOOR_NUMBERS:
		await enter_floor_through_gate(number)
		_assert_first_room(number)
		skip_to_boss()
		await clear_boss_and_leave()


# --- helpers ---


## One floor of the shipped tower, with the floors below it opened by the debug key (N in the
## town): from the start to the boss, the boss killed, the exit, the town with the next floor
## unlocked; then the same floor at the boss, which is now reached.
func _floor_end_to_end(number: int) -> void:
	await spawn_main()
	var progress: TowerProgress = session().get_progress()
	for _i: int in number - 1:
		press_key(KEY_N)
	assert_eq(progress.get_highest_unlocked(), number)
	assert_false(progress.is_boss_reached(number))
	await enter_floor_through_gate(number)
	_assert_first_room(number)
	skip_to_boss()
	_assert_boss_room(number)
	assert_true(progress.is_boss_reached(number), "reached by entering the room")
	kill_boss()
	await run_ticks(2)
	assert_false(enemy().logic.is_alive(), "the boss is dead")
	assert_true(progress.is_floor_cleared(number))
	assert_eq(progress.is_floor_unlocked(number + 1), number < FLOOR_NUMBERS.size())
	assert_string_contains(hud().get_banner_text(), "Floor %d cleared" % number)
	await leave_by_exit()
	assert_not_null(town(), "the exit leads to the town")
	assert_null(floor_scene())
	assert_eq(location(), "Town")
	assert_eq(hp(), max_hp())
	assert_eq(progress.get_highest_unlocked(), mini(number + 1, FLOOR_NUMBERS.size()))
	await _floor_at_the_boss(number)
	assert_eq(get_errors().size(), 0, str(get_errors()))


## The boss room entered through the gate, a replay: its exit returns to the town as well.
func _floor_at_the_boss(number: int) -> void:
	await enter_floor_through_gate(number, true)
	_assert_boss_room(number)
	assert_eq(session().get_start_room(), floor_scene().floor_data.get_room_count() - 1)
	assert_eq(hp(), max_hp(), "full HP")
	await clear_boss_and_leave()
	assert_not_null(town(), "floor %d: the exit of a replayed boss room" % number)
	assert_eq(location(), "Town")


func _assert_first_room(number: int) -> void:
	assert_eq(floor_scene().get_setup_errors(), PackedStringArray(), "floor %d" % number)
	assert_eq(floor_scene().floor_data.resource_path, FLOOR_PATH_FORMAT % number)
	assert_eq(floor_scene().floor_data.floor_number, number)
	assert_eq(floor_scene().get_run().get_room_index(), 0)
	var combat_rooms: int = floor_scene().floor_data.get_room_count() - 1
	assert_eq(location(), "Floor %d · Room 1 / %d" % [number, combat_rooms])
	assert_eq(hp(), max_hp())


func _assert_boss_room(number: int) -> void:
	assert_eq(floor_scene().get_setup_errors(), PackedStringArray(), "floor %d" % number)
	assert_true(room().get_room_data().is_boss_room, "floor %d" % number)
	assert_eq(enemy().logic.get_data().id, BOSSES[number])
	assert_eq(location(), "Floor %d · Boss" % number)
	assert_eq(hp(), max_hp())
	assert_true(enemy().logic.is_alive())
