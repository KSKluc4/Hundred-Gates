# gdlint:disable=max-public-methods,max-file-lines
extends F016ShellTest
## F-016 T6 (AC16, AC20's shell part, AC21, AC22; C17): the Equipment menu in the running game,
## through a real `Shell` on a fixture tower with a fixture catalog (F016LootTest.quiet_catalog():
## no regular drop ever comes, so the only swords are the ones a test gives). Real key, pad and
## click events. The panel's choose guard is off (the shared helper's), as in F-015's shell tests;
## where a test must see that the guard did NOT restart it puts a long guard on the panel after the
## menu opened, so that an `open()` would show.
## Expected texts are written out: the starter and the vitality swords are 42 damage (10/10/22), the
## mending one of the 8th pool sword reads `Room heal 35% of max HP` (30 % and 0.05).

const ESCAPE: Key = KEY_ESCAPE
const PAD_B: JoyButton = JOY_BUTTON_B
const PAD_START: JoyButton = JOY_BUTTON_START
const PAD_A: JoyButton = JOY_BUTTON_A
const STARTER: StringName = ItemFixtures.STARTER_ID
const VITALITY: StringName = F016LootTest.VITALITY_ID
const STARTER_ENTRY: StringName = &"sword:fixture_starter"
const VITALITY_ENTRY: StringName = &"sword:fixture_vitality"
const STARTER_TEXT: String = "Sword fixture_starter — 42 (10/10/22) — No trait"
const VITALITY_TEXT: String = "Sword fixture_vitality — 42 (10/10/22) — Max HP +8"
const EQUIPPED: String = " [equipped]"
const CHOOSE_BODY: String = "Choose a sword to equip it."
const LOCKED_BODY: String = (
	"Swords can be changed in town, " + "or in the last room before a boss once it is cleared."
)
const NO_SWORDS_BODY: String = "No swords."
## A guard longer than any test: an `open()` of the panel would turn it on.
const LONG_GUARD_SECONDS: float = 30.0
## Ticks the player is watched for a dash or an attack after the game runs again.
const WATCH_TICKS: int = 10
const DEATH_DELAY: float = 0.1
const DEAD_LIMIT_TICKS: int = 10
const TICK_LIMIT: int = 400
const PAGE_SIZE: int = 8
## 17 swords of the pool and the starter: 18 are owned at most.
const BIG_POOL: int = 17


func after_each() -> void:
	release_click()  # A held click must not leak into the next test.
	await super.after_each()


# --- helpers ---


## The tower with `combat_rooms` combat rooms (one chaser each) and the fixture catalog.
func _start(combat_rooms: Array[int] = [1], input_enabled: bool = false) -> void:
	var tower: TowerData = F016LootTest.loot_tower(combat_rooms)
	await start_loot_game(tower, F016LootTest.quiet_catalog(tower), input_enabled)


## A game whose pool holds `BIG_POOL` swords, `owned_extra` of which are owned besides the starter:
## `fixture_sword_01` and so on, in the order they were acquired.
func _start_with_many(owned_extra: int) -> void:
	var tower: TowerData = F016LootTest.loot_tower([1])
	var catalog: LootCatalog = ItemFixtures.catalog_with(
		tower,
		false,
		F016LootTest.boss_swords(),
		PackedInt32Array(F016LootTest.BOSS_PERCENTS),
		ItemFixtures.valid_swords(BIG_POOL)
	)
	await start_loot_game(tower, catalog)
	for index: int in owned_extra:
		give(_pool_id(index + 1))


func _pool_id(number: int) -> StringName:
	return StringName("%s%02d" % [ItemFixtures.SWORD_ID_PREFIX, number])


func _entry_of(number: int) -> StringName:
	return EquipmentMenu.sword_entry_id(_pool_id(number))


func _ids(list: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: Variant in list:
		ids.append(id)
	return ids


func _strings(list: Array) -> Array[String]:
	var texts: Array[String] = []
	for text: Variant in list:
		texts.append(text)
	return texts


func _game_is_stopped() -> bool:
	return game().process_mode == Node.PROCESS_MODE_DISABLED and not space_is_active()


## From the Equipment menu back to the pause menu and on to PLAYING, then waits for the guard.
func _leave_the_menus() -> void:
	await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	await wait_for_guard()


# --- AC16: what a character owns ---


func test_ac16_a_new_game_owns_the_starter_equipped_and_the_menu_lists_it() -> void:
	await _start()
	assert_eq(inventory().get_ids(), _ids([STARTER]))
	assert_eq(inventory().get_count(STARTER), 1)
	assert_eq(inventory().get_equipped_id(), STARTER)
	await open_equipment()
	assert_eq(panel().get_heading(), "Equipment")
	assert_eq(panel().get_body(), CHOOSE_BODY)
	assert_eq(panel().get_entry_ids(), _ids([STARTER_ENTRY, ShellMenus.BACK]))
	assert_eq(entry_texts(), _strings([STARTER_TEXT + EQUIPPED, "Back"]))
	assert_eq(panel().get_focus_id(), STARTER_ENTRY, "on the equipped sword")
	assert_true(panel().is_entry_enabled(STARTER_ENTRY), "in town it can be chosen")
	assert_true(panel().is_entry_enabled(ShellMenus.BACK))
	assert_true(_game_is_stopped(), "the game stays stopped while the menu is up")


func test_ac16_the_pause_menu_has_equipment_second_in_town_and_on_a_floor() -> void:
	await _start()
	await pause_with_escape()
	assert_eq(panel().get_entry_ids()[1], ShellMenus.EQUIPMENT_ID)
	assert_eq(panel().get_entry_text(ShellMenus.EQUIPMENT_ID), "Equipment")
	await tap_key(ESCAPE)
	await wait_for_guard()
	await enter_frozen_floor()
	await pause_with_escape()
	assert_eq(panel().get_entry_ids()[1], ShellMenus.EQUIPMENT_ID)


func test_ac16_a_second_pickup_of_an_owned_sword_reads_x2_in_the_list() -> void:
	await _start()
	give(VITALITY)
	await open_equipment()
	assert_eq(panel().get_entry_text(VITALITY_ENTRY), VITALITY_TEXT)
	await _leave_the_menus()
	give(VITALITY)
	await open_equipment()
	assert_eq(panel().get_entry_text(VITALITY_ENTRY), VITALITY_TEXT + " ×2")
	assert_eq(inventory().get_count(VITALITY), 2)
	await _leave_the_menus()
	give(VITALITY)
	await open_equipment()
	assert_eq(panel().get_entry_text(VITALITY_ENTRY), VITALITY_TEXT + " ×3")
	assert_eq(
		panel().get_entry_text(STARTER_ENTRY), STARTER_TEXT + EQUIPPED, "the others as they were"
	)


func test_ac16_the_equipped_one_picked_up_again_reads_its_count_and_the_mark() -> void:
	await _start()
	give(STARTER)
	await open_equipment()
	assert_eq(panel().get_entry_text(STARTER_ENTRY), STARTER_TEXT + " ×2" + EQUIPPED)


func test_ac16_return_to_town_keeps_the_inventory_and_the_equipped_sword() -> void:
	await _start()
	give(VITALITY)
	assert_true(game().equip_sword(VITALITY))
	await enter_frozen_floor()
	await tap_key(ESCAPE)
	choose(ShellMenus.LEAVE)
	choose(ShellMenus.CONFIRM)
	await wait_for_town()
	assert_eq(inventory().get_ids(), _ids([STARTER, VITALITY]))
	assert_eq(inventory().get_equipped_id(), VITALITY)
	assert_eq(max_hp(), VITALITY_MAX_HP, "the town player has the sword's max HP")


func test_ac16_death_keeps_the_inventory_and_the_equipped_sword() -> void:
	set_death_delay(DEATH_DELAY)
	await _start()
	give(VITALITY)
	assert_true(game().equip_sword(VITALITY))
	await enter_frozen_floor()
	kill_player()
	var dead: Callable = func() -> bool: return flow().get_state() == ShellFlow.State.DEAD
	assert_true(await tick_until(dead, DEAD_LIMIT_TICKS), "the death screen opened")
	var ready: Callable = func() -> bool: return panel().is_entry_enabled(ShellMenus.RETURN)
	assert_true(await tick_until(ready, TICK_LIMIT), "the entry became enabled")
	await get_tree().process_frame
	choose(ShellMenus.RETURN)
	await wait_for_town()
	assert_eq(inventory().get_ids(), _ids([STARTER, VITALITY]))
	assert_eq(inventory().get_equipped_id(), VITALITY)


func test_ac16_clearing_a_floor_keeps_the_inventory_and_the_equipped_sword() -> void:
	await _start()
	give(VITALITY)
	assert_true(game().equip_sword(VITALITY))
	await enter_frozen_floor()
	await clear_here()
	put_player_at_door()
	var moved: Callable = func() -> bool: return room().get_room_data().is_boss_room
	assert_true(await run_until(moved, WALK_LIMIT_TICKS, door_outward()), "the boss room")
	await clear_boss_and_leave()
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	# The boss's first win always drops a sword, and leaving its room took it: one more.
	assert_eq(inventory().get_ids().size(), 3)
	assert_eq(inventory().get_ids().slice(0, 2), _ids([STARTER, VITALITY]), "what was owned stays")
	assert_eq(inventory().get_equipped_id(), VITALITY)


func test_ac16_quit_to_title_and_start_again_give_a_fresh_inventory() -> void:
	await _start()
	give(VITALITY)
	give(VITALITY)
	assert_true(game().equip_sword(VITALITY))
	var old_loot: CharacterLoot = loot()
	await tap_key(ESCAPE)
	choose(ShellMenus.QUIT_TO_TITLE)
	choose(ShellMenus.CONFIRM)
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)
	assert_null(shell().get_game(), "the game is gone")
	await start_game()
	assert_not_same(loot(), old_loot, "a new character")
	assert_eq(inventory().get_ids(), _ids([STARTER]), "only the starter")
	assert_eq(inventory().get_count(VITALITY), 0)
	assert_eq(inventory().get_equipped_id(), STARTER)
	await open_equipment()
	assert_eq(entry_texts(), _strings([STARTER_TEXT + EQUIPPED, "Back"]))


# --- AC20: pages and the first focus ---


func test_ac20_with_no_swords_it_opens_on_back_and_says_so() -> void:
	var tower: TowerData = F016LootTest.loot_tower([1])
	await start_loot_game(tower, null)
	assert_true(inventory().get_ids().is_empty(), "no catalog, no sword")
	await open_equipment()
	assert_eq(panel().get_entry_ids(), _ids([ShellMenus.BACK]))
	assert_eq(panel().get_focus_id(), ShellMenus.BACK)
	assert_eq(panel().get_body(), NO_SWORDS_BODY)
	assert_eq(panel().get_heading(), "Equipment")


func test_ac20_nine_owned_swords_are_two_pages_and_it_opens_on_the_equipped_ones() -> void:
	await _start_with_many(8)
	assert_eq(inventory().get_ids().size(), PAGE_SIZE + 1)
	await open_equipment()
	assert_eq(sword_entry_ids().size(), PAGE_SIZE, "the first page holds eight")
	assert_eq(panel().get_entry_ids().size(), PAGE_SIZE + 2, "eight swords, Next page and Back")
	assert_eq(panel().get_entry_ids()[PAGE_SIZE], EquipmentMenu.NEXT_ID)
	assert_eq(panel().get_entry_text(EquipmentMenu.NEXT_ID), "Next page")
	assert_false(panel().get_entry_ids().has(EquipmentMenu.PREVIOUS_ID), "no earlier page")
	assert_eq(panel().get_focus_id(), STARTER_ENTRY, "on the equipped sword")
	assert_eq(
		panel().get_entry_text(_entry_of(8)),
		"",
		"the ninth sword is on the next page, not in this panel"
	)
	await _leave_the_menus()
	assert_true(game().equip_sword(_pool_id(8)), "the ninth sword, in town")
	await open_equipment()
	assert_eq(
		panel().get_entry_ids(),
		_ids([_entry_of(8), EquipmentMenu.PREVIOUS_ID, ShellMenus.BACK]),
		"the second page: its one sword, Previous page, Back"
	)
	assert_eq(
		entry_texts(),
		_strings(
			[
				"Sword fixture_sword_08 — 37 (9/9/19) — Room heal 35% of max HP" + EQUIPPED,
				"Previous page",
				"Back"
			]
		)
	)
	assert_eq(panel().get_focus_id(), _entry_of(8), "opens on the page of the equipped sword")


func test_ac20_next_and_previous_page_open_the_panel_again_on_the_pages_first_sword() -> void:
	await _start_with_many(8)
	assert_true(game().equip_sword(_pool_id(3)), "an equipped sword that is not the first")
	await open_equipment()
	assert_eq(panel().get_focus_id(), _entry_of(3))
	var first_page: Array[int] = entry_button_ids()
	choose(EquipmentMenu.NEXT_ID)
	assert_eq(flow().get_state(), ShellFlow.State.EQUIPMENT, "still the Equipment menu")
	assert_ne(entry_button_ids(), first_page, "a page change opens the panel again")
	assert_eq(
		panel().get_entry_ids(), _ids([_entry_of(8), EquipmentMenu.PREVIOUS_ID, ShellMenus.BACK])
	)
	assert_eq(panel().get_focus_id(), _entry_of(8), "on the page's first sword")
	assert_eq(panel().get_heading(), "Equipment")
	assert_eq(panel().get_body(), CHOOSE_BODY)
	var second_page: Array[int] = entry_button_ids()
	choose(EquipmentMenu.PREVIOUS_ID)
	assert_ne(entry_button_ids(), second_page)
	assert_eq(sword_entry_ids().size(), PAGE_SIZE)
	assert_eq(
		panel().get_focus_id(),
		STARTER_ENTRY,
		"on the first page's first sword, not the equipped one"
	)
	assert_true(_game_is_stopped())


func test_ac20_seventeen_swords_the_middle_page_has_both_page_entries() -> void:
	await _start_with_many(16)
	assert_eq(inventory().get_ids().size(), 17)
	assert_true(game().equip_sword(_pool_id(10)))
	await open_equipment()
	var middle: Array[StringName] = []
	for number: int in range(8, 16):
		middle.append(_entry_of(number))
	middle.append(EquipmentMenu.NEXT_ID)
	middle.append(EquipmentMenu.PREVIOUS_ID)
	middle.append(ShellMenus.BACK)
	assert_eq(panel().get_entry_ids(), middle, "eight swords, both page entries and Back")
	assert_eq(panel().get_focus_id(), _entry_of(10), "the page of the equipped sword")
	choose(EquipmentMenu.NEXT_ID)
	assert_eq(
		panel().get_entry_ids(), _ids([_entry_of(16), EquipmentMenu.PREVIOUS_ID, ShellMenus.BACK])
	)
	assert_eq(panel().get_focus_id(), _entry_of(16))
	choose(EquipmentMenu.PREVIOUS_ID)
	assert_eq(panel().get_entry_ids(), middle)
	assert_eq(panel().get_focus_id(), _entry_of(8), "the middle page's first sword")
	choose(EquipmentMenu.PREVIOUS_ID)
	assert_eq(panel().get_focus_id(), STARTER_ENTRY)
	assert_false(panel().get_entry_ids().has(EquipmentMenu.PREVIOUS_ID), "none on the first page")


func test_ac20_pages_are_changed_by_key_pad_and_click_too() -> void:
	await _start_with_many(8)
	await open_equipment()
	await focus_entry_by_keys(EquipmentMenu.NEXT_ID)
	await tap_key(KEY_ENTER)
	assert_eq(panel().get_focus_id(), _entry_of(8), "by key")
	await tap_pad(PAD_A)
	assert_eq(panel().get_focus_id(), _entry_of(8), "A on a sword that is not equipped equips it")
	assert_eq(inventory().get_equipped_id(), _pool_id(8))
	await focus_entry_by_keys(EquipmentMenu.PREVIOUS_ID)
	await tap_pad(PAD_A)
	assert_eq(panel().get_focus_id(), STARTER_ENTRY, "by pad")
	await click_entry(EquipmentMenu.NEXT_ID)
	assert_eq(panel().get_focus_id(), _entry_of(8), "by a real click")
	await click_entry(EquipmentMenu.PREVIOUS_ID)
	assert_eq(panel().get_focus_id(), STARTER_ENTRY)


# --- AC21: choosing a sword ---


## A key, a pad press or a real click on the vitality sword equips it: the marks move in place.
func _assert_equips_in_place(method: StringName) -> void:
	await _start()
	give(VITALITY)
	await open_equipment()
	assert_eq(entry_texts(), _strings([STARTER_TEXT + EQUIPPED, VITALITY_TEXT, "Back"]))
	await focus_entry_by_keys(VITALITY_ENTRY)
	panel().choose_guard_seconds = LONG_GUARD_SECONDS
	var buttons: Array[int] = entry_button_ids()
	watch_signals(flow())
	match method:
		&"key":
			await tap_key(KEY_ENTER)
		&"pad":
			await tap_pad(PAD_A)
		&"click":
			await click_entry(VITALITY_ENTRY)
	assert_eq(
		entry_texts(),
		_strings([STARTER_TEXT, VITALITY_TEXT + EQUIPPED, "Back"]),
		"the mark moved, %s" % method
	)
	assert_eq(entry_button_ids(), buttons, "the same buttons: the panel was not opened again")
	assert_false(panel().is_choose_guarded(), "so the choose guard did not restart")
	assert_eq(flow().get_state(), ShellFlow.State.EQUIPMENT)
	assert_signal_not_emitted(flow(), "state_changed")
	assert_eq(inventory().get_equipped_id(), VITALITY)
	assert_eq(game().get_equipped_sword().id, VITALITY)
	assert_eq(max_hp(), VITALITY_MAX_HP, "the town player on screen has it at once")
	assert_eq(hp(), CLASS_MAX_HP, "and no heal")
	assert_true(_game_is_stopped(), "the game stayed stopped")


func test_ac21_in_town_a_key_equips_the_focused_sword_and_the_focus_stays() -> void:
	await _assert_equips_in_place(&"key")
	assert_eq(panel().get_focus_id(), VITALITY_ENTRY, "the focus stayed on the chosen sword")


func test_ac21_in_town_the_pad_equips_the_focused_sword_and_the_focus_stays() -> void:
	await _assert_equips_in_place(&"pad")
	assert_eq(panel().get_focus_id(), VITALITY_ENTRY)


func test_ac21_in_town_a_real_click_equips_the_sword() -> void:
	await _assert_equips_in_place(&"click")


func test_ac21_the_equipped_sword_chosen_again_changes_nothing() -> void:
	await _start()
	give(VITALITY)
	await open_equipment()
	await focus_entry_by_keys(VITALITY_ENTRY)
	await tap_key(KEY_ENTER)
	var texts: Array[String] = entry_texts()
	var buttons: Array[int] = entry_button_ids()
	panel().choose_guard_seconds = LONG_GUARD_SECONDS
	watch_signals(flow())
	await tap_key(KEY_ENTER)
	choose(VITALITY_ENTRY)
	assert_eq(entry_texts(), texts)
	assert_eq(entry_button_ids(), buttons)
	assert_false(panel().is_choose_guarded())
	assert_eq(panel().get_focus_id(), VITALITY_ENTRY)
	assert_eq(inventory().get_equipped_id(), VITALITY)
	assert_eq(max_hp(), VITALITY_MAX_HP)
	assert_signal_not_emitted(flow(), "state_changed")


func test_ac21_the_count_and_the_marks_follow_an_equip_of_a_sword_owned_twice() -> void:
	await _start()
	give(VITALITY)
	give(VITALITY)
	await open_equipment()
	assert_eq(panel().get_entry_text(VITALITY_ENTRY), VITALITY_TEXT + " ×2")
	choose(VITALITY_ENTRY)
	assert_eq(panel().get_entry_text(VITALITY_ENTRY), VITALITY_TEXT + " ×2" + EQUIPPED)
	assert_eq(panel().get_entry_text(STARTER_ENTRY), STARTER_TEXT)


func test_ac21_a_sword_of_the_second_page_equips_in_place_and_the_old_mark_is_gone() -> void:
	await _start_with_many(8)
	await open_equipment()
	choose(_entry_of(3))
	assert_eq(inventory().get_equipped_id(), _pool_id(3))
	choose(EquipmentMenu.NEXT_ID)
	panel().choose_guard_seconds = LONG_GUARD_SECONDS
	var buttons: Array[int] = entry_button_ids()
	choose(_entry_of(8))
	assert_eq(inventory().get_equipped_id(), _pool_id(8), "equipped from the second page")
	assert_eq(entry_button_ids(), buttons, "in place")
	assert_true(panel().get_entry_text(_entry_of(8)).ends_with(EQUIPPED))
	choose(EquipmentMenu.PREVIOUS_ID)
	assert_false(
		panel().get_entry_text(_entry_of(3)).ends_with(EQUIPPED), "the old one lost its mark"
	)
	assert_eq(sword_entry_ids().size(), PAGE_SIZE)


## The locked places: a floor outside the cleared room before the boss. Every sword entry is
## disabled and nothing equips, by any of the ways a person has.
func test_ac21_where_equipping_is_not_allowed_nothing_can_be_chosen() -> void:
	await _start([1, 1])
	give(VITALITY)
	await enter_frozen_floor()
	assert_false(game().can_equip_sword())
	await open_equipment()
	assert_eq(panel().get_body(), LOCKED_BODY, "the body says where")
	assert_eq(entry_texts(), _strings([STARTER_TEXT + EQUIPPED, VITALITY_TEXT, "Back"]))
	assert_false(panel().is_entry_enabled(STARTER_ENTRY))
	assert_false(panel().is_entry_enabled(VITALITY_ENTRY))
	assert_true(panel().is_entry_enabled(ShellMenus.BACK), "Back can always be chosen")
	assert_eq(panel().get_focus_id(), STARTER_ENTRY, "a disabled entry can hold the focus")
	await focus_entry_by_keys(VITALITY_ENTRY)
	var texts: Array[String] = entry_texts()
	var buttons: Array[int] = entry_button_ids()
	watch_signals(flow())
	await tap_key(KEY_ENTER)
	await tap_key(KEY_SPACE)
	await tap_pad(PAD_A)
	choose(VITALITY_ENTRY)
	await click_entry(VITALITY_ENTRY)
	await click_entry(STARTER_ENTRY)
	assert_eq(inventory().get_equipped_id(), STARTER, "nothing was equipped")
	assert_eq(game().get_equipped_sword().id, STARTER)
	assert_eq(entry_texts(), texts)
	assert_eq(entry_button_ids(), buttons)
	assert_eq(flow().get_state(), ShellFlow.State.EQUIPMENT)
	assert_signal_not_emitted(flow(), "state_changed")
	assert_eq(max_hp(), CLASS_MAX_HP)
	assert_eq(panel().get_body(), LOCKED_BODY)


## Place by place: the cleared room before the boss is the only room of a floor where it works.
func test_ac21_on_a_floor_only_the_cleared_room_before_the_boss_equips() -> void:
	await _start([1, 1])
	give(VITALITY)
	await enter_frozen_floor()
	assert_eq(await _locked_here(), true, "the first room, not cleared")
	await clear_here()
	assert_eq(await _locked_here(), true, "the first room, cleared: not the one before the boss")
	put_player_at_door()
	var index: int = floor_scene().get_run().get_room_index()
	var moved: Callable = func() -> bool: return floor_scene().get_run().get_room_index() != index
	assert_true(await run_until(moved, WALK_LIMIT_TICKS, door_outward()), "the next room")
	freeze_enemies()
	assert_eq(await _locked_here(), true, "the room before the boss, not cleared")
	await clear_here()
	assert_eq(await _locked_here(), false, "the room before the boss, cleared")


## Opens the Equipment menu here, says whether every sword entry is disabled (and the body is the
## locked one) and goes back to the game. Pausing and resuming changes nothing else.
func _locked_here() -> bool:
	await open_equipment()
	var locked: bool = panel().get_body() == LOCKED_BODY
	for id: StringName in sword_entry_ids():
		assert_eq(panel().is_entry_enabled(id), not locked, "%s, locked: %s" % [id, locked])
	if not locked:
		assert_eq(panel().get_body(), CHOOSE_BODY)
	await _leave_the_menus()
	return locked


func test_ac21_in_the_cleared_room_before_the_boss_it_works_and_the_player_changes_at_once(
) -> void:
	await _start()
	give(VITALITY)
	await enter_frozen_floor()
	await clear_here()
	assert_true(game().can_equip_sword())
	await open_equipment()
	assert_eq(panel().get_body(), CHOOSE_BODY)
	assert_true(panel().is_entry_enabled(VITALITY_ENTRY))
	await focus_entry_by_keys(VITALITY_ENTRY)
	panel().choose_guard_seconds = LONG_GUARD_SECONDS
	var buttons: Array[int] = entry_button_ids()
	await tap_key(KEY_ENTER)
	assert_eq(entry_texts(), _strings([STARTER_TEXT, VITALITY_TEXT + EQUIPPED, "Back"]))
	assert_eq(entry_button_ids(), buttons, "in place")
	assert_false(panel().is_choose_guarded())
	assert_eq(max_hp(), VITALITY_MAX_HP, "the player on screen changed at once, still paused")
	assert_eq(hp(), CLASS_MAX_HP, "and was not healed")
	assert_eq(floor_scene().get_run().get_entry_hp(), CLASS_MAX_HP)
	assert_true(_game_is_stopped())
	await _leave_the_menus()
	put_player_at_door()
	var moved: Callable = func() -> bool: return room().get_room_data().is_boss_room
	assert_true(await run_until(moved, WALK_LIMIT_TICKS, door_outward()), "the boss room")
	assert_eq(max_hp(), VITALITY_MAX_HP, "the boss room is entered at the new max HP")
	assert_eq(hp(), VITALITY_MAX_HP)


# --- AC22: the pause and the guard ---


## A pause that equips nothing leaves the world as it was: the Equipment menu is opened, looked at
## for a while and left.
func _assert_a_pause_with_no_equip_changes_nothing(on_floor: bool) -> void:
	await _start()
	give(VITALITY)
	if on_floor:
		await enter_frozen_floor()
	await run_ticks(30, Vector2.RIGHT, Vector2.RIGHT)
	await get_tree().process_frame
	var before: Dictionary = world_snapshot()
	press_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	choose(ShellMenus.EQUIPMENT_ID)
	assert_eq(flow().get_state(), ShellFlow.State.EQUIPMENT)
	for _i: int in 30:
		await get_tree().physics_frame
		assert_true(_game_is_stopped())
	choose(ShellMenus.BACK)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	press_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	var after: Dictionary = world_snapshot()
	assert_eq(after["sim"], before["sim"], "the sim's snapshot")
	assert_eq(after["session"], before["session"], "the session's snapshot")
	assert_eq(after["positions"], before["positions"])
	assert_eq(after["time"], before["time"])
	await wait_for_guard()
	await run_ticks(10)
	assert_gt(world_snapshot()["time"], before["time"], "and the game goes on")
	assert_true(space_is_active())


func test_ac22_a_pause_with_no_equip_changes_nothing_in_town() -> void:
	await _assert_a_pause_with_no_equip_changes_nothing(false)


func test_ac22_a_pause_with_no_equip_changes_nothing_on_a_floor() -> void:
	await _assert_a_pause_with_no_equip_changes_nothing(true)


## After an equip the person goes back and resumes with a key that is also the dash (Space, pad A)
## or a click that is also the attack: the two-tick guard holds, the press never dashes or attacks,
## and the space comes back. (The press that chooses the sword is the menu's alone and never reaches
## the game; the one the guard is about is the one that resumes.)
func _assert_resume_after_an_equip_does_not_act(method: StringName) -> void:
	await _start([1], true)
	give(VITALITY)
	await pause_with_escape()
	choose(ShellMenus.EQUIPMENT_ID)
	choose(VITALITY_ENTRY)
	assert_eq(inventory().get_equipped_id(), VITALITY)
	assert_true(_game_is_stopped(), "the game stays stopped through the equip")
	await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	assert_eq(panel().get_focus_id(), ShellMenus.EQUIPMENT_ID)
	assert_true(_game_is_stopped())
	await focus_entry_by_keys(ShellMenus.RESUME)
	match method:
		&"pad":
			await hold_pad_between_ticks(PAD_A)
		&"space":
			await hold_key_between_ticks(KEY_SPACE)
		&"click":
			await hold_click_between_ticks()
			choose(ShellMenus.RESUME)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "the press resumed")
	assert_true(shell().is_guarding(), "the guard began with the choice")
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED, "not enabled by the choice")
	await wait_for_guard()
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT, "the game runs again")
	for tick: int in WATCH_TICKS:
		await get_tree().physics_frame
		assert_ne(player().motor.get_state(), PlayerMotor.State.DASHING, "tick %d" % tick)
		assert_ne(player().motor.get_state(), PlayerMotor.State.ATTACKING, "tick %d" % tick)
	assert_true(space_is_active(), "the physics space is back")
	assert_eq(max_hp(), VITALITY_MAX_HP, "and the sword is what was equipped")


func test_ac22_after_an_equip_the_input_guard_holds_for_space() -> void:
	await _assert_resume_after_an_equip_does_not_act(&"space")


func test_ac22_after_an_equip_the_input_guard_holds_for_pad_a() -> void:
	await _assert_resume_after_an_equip_does_not_act(&"pad")


func test_ac22_after_an_equip_the_input_guard_holds_for_a_click() -> void:
	await _assert_resume_after_an_equip_does_not_act(&"click")


func test_ac22_the_guard_is_two_of_the_shells_ticks_after_an_equip_too() -> void:
	await _start()
	give(VITALITY)
	await open_equipment()
	choose(VITALITY_ENTRY)
	await tap_key(ESCAPE)
	await get_tree().process_frame
	choose(ShellMenus.RESUME)
	assert_true(shell().is_guarding(), "from the choice")
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(space_is_active())
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED, "not before the second tick ends")
	await get_tree().physics_frame
	assert_false(shell().is_guarding())
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT)
	await get_tree().physics_frame
	assert_true(space_is_active(), "the space follows one tick later (F-015 DEV-6)")


func test_ac22_the_equip_in_the_cleared_room_survives_the_resume_on_a_floor() -> void:
	await _start()
	give(VITALITY)
	await enter_frozen_floor()
	await clear_here()
	await open_equipment()
	choose(VITALITY_ENTRY)
	await _leave_the_menus()
	await run_ticks(10)
	assert_true(space_is_active())
	assert_eq(max_hp(), VITALITY_MAX_HP)
	assert_eq(floor_scene().get_run().get_entry_hp(), CLASS_MAX_HP)


# --- AC19/AC22: the way out of the menu ---


## Escape, pad B, pad Start and the Back entry all land on the pause menu, on `Equipment`, with the
## game still stopped; the settings' own Back is unchanged.
func _assert_leaves_by(method: StringName) -> void:
	await _start()
	await open_equipment()
	watch_signals(flow())
	match method:
		&"escape":
			await tap_key(ESCAPE)
		&"pad_b":
			await tap_pad(PAD_B)
		&"pad_start":
			await tap_pad(PAD_START)
		&"back":
			choose(ShellMenus.BACK)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "one step back, by %s" % method)
	assert_signal_emit_count(flow(), "state_changed", 1)
	assert_eq(panel().get_heading(), ShellMenus.PAUSED_HEADING)
	assert_eq(panel().get_focus_id(), ShellMenus.EQUIPMENT_ID, "the focus is on Equipment")
	assert_true(_game_is_stopped(), "the game stayed stopped")


func test_ac22_escape_in_the_equipment_menu_goes_back_to_the_pause_menu() -> void:
	await _assert_leaves_by(&"escape")


func test_ac22_pad_b_in_the_equipment_menu_goes_back_to_the_pause_menu() -> void:
	await _assert_leaves_by(&"pad_b")


func test_ac22_pad_start_in_the_equipment_menu_goes_back_to_the_pause_menu() -> void:
	await _assert_leaves_by(&"pad_start")


func test_ac22_the_back_entry_in_the_equipment_menu_goes_back_to_the_pause_menu() -> void:
	await _assert_leaves_by(&"back")


func test_ac22_back_in_the_settings_still_closes_the_settings() -> void:
	await _start()
	await pause_with_escape()
	choose(ShellMenus.SETTINGS)
	assert_eq(flow().get_state(), ShellFlow.State.SETTINGS)
	choose(ShellMenus.BACK)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	assert_eq(panel().get_focus_id(), ShellMenus.SETTINGS)
	assert_true(_game_is_stopped())
