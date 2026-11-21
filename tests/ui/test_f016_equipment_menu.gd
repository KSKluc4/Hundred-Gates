# gdlint:disable=max-public-methods
extends GutTest
## F-016 T4 (AC20, C17, C18): what the Equipment menu lists. The builder (`EquipmentMenu`) takes
## plain values, so it is tested with an inventory and a fixture catalog; the size of the whole
## panel is measured on a real MenuPanel. Texts are written out. The fixture swords (ItemFixtures)
## are `Sword fixture_sword_NN`, damage 30 + (NN - 1) % 15, no weights (the warrior's own
## 10/10/22), and in turn no trait, Max HP +8, Dash cooldown -0.05 s, Mending 0.05 (35 % with the
## 30 % base).

const PANEL_SCENE: PackedScene = preload("res://src/ui/menus/menu_panel.tscn")
const SCREEN: Vector2 = Vector2(640.0, 360.0)
const PAGE_SIZE: int = 8
const BASE_HEAL: float = 0.3

var _catalog: LootCatalog
var _class_data: ClassData
var _panel: MenuPanel


func before_each() -> void:
	_class_data = ItemFixtures.class_data()
	_catalog = ItemFixtures.catalog_of(
		ItemFixtures.starter(),
		[ItemFixtures.floor_loot(1.0, ItemFixtures.valid_swords(17), [], PackedInt32Array())]
	)


func after_each() -> void:
	# F-012/CR-22: the buttons a menu replaced are queued, not gone, until the frame ends.
	await get_tree().process_frame


# --- the ids ---


func test_ac20_a_sword_entry_id_is_sword_colon_the_id_and_parses_back() -> void:
	assert_eq(EquipmentMenu.sword_entry_id(&"twin_edge"), &"sword:twin_edge")
	assert_eq(EquipmentMenu.sword_of(&"sword:twin_edge"), &"twin_edge")
	assert_eq(EquipmentMenu.sword_of(EquipmentMenu.sword_entry_id(&"a")), &"a")


func test_ac20_other_entry_ids_name_no_sword() -> void:
	assert_eq(EquipmentMenu.sword_of(&"equipment_next"), &"")
	assert_eq(EquipmentMenu.sword_of(&"equipment_previous"), &"")
	assert_eq(EquipmentMenu.sword_of(ShellMenus.BACK), &"")
	assert_eq(EquipmentMenu.sword_of(&""), &"")
	assert_eq(EquipmentMenu.sword_of(&"sword:"), &"", "a prefix alone names nothing")
	assert_eq(EquipmentMenu.sword_of(&"xsword:a"), &"", "only a prefix at the start")


func test_ac20_the_page_entry_ids() -> void:
	assert_eq(EquipmentMenu.NEXT_ID, &"equipment_next")
	assert_eq(EquipmentMenu.PREVIOUS_ID, &"equipment_previous")


func test_ac20_the_pause_entry_and_the_heading_are_the_shell_menus() -> void:
	assert_eq(ShellMenus.EQUIPMENT_ID, &"equipment")
	assert_eq(ShellMenus.EQUIPMENT_TEXT, "Equipment")
	assert_eq(ShellMenus.heading(ShellFlow.State.EQUIPMENT), "Equipment")
	assert_eq(ShellMenus.body(ShellFlow.State.EQUIPMENT, "a", "b", 0), "")
	assert_eq(ShellMenus.entries(ShellFlow.State.EQUIPMENT, true, true, true, true).size(), 0)
	assert_eq(ShellMenus.focus(ShellFlow.State.EQUIPMENT, ShellFlow.State.PAUSED), &"")
	assert_eq(ShellMenus.focus(ShellFlow.State.PAUSED, ShellFlow.State.EQUIPMENT), &"equipment")


# --- pages ---


func test_ac20_the_page_count_is_at_least_one() -> void:
	assert_eq(EquipmentMenu.page_count(_inventory(0), PAGE_SIZE), 1, "no swords")
	assert_eq(EquipmentMenu.page_count(_inventory(1), PAGE_SIZE), 1)
	assert_eq(EquipmentMenu.page_count(_inventory(8), PAGE_SIZE), 1, "exactly a page")


func test_ac20_nine_swords_at_a_page_size_of_eight_are_two_pages() -> void:
	assert_eq(EquipmentMenu.page_count(_inventory(9), PAGE_SIZE), 2)
	assert_eq(EquipmentMenu.page_count(_inventory(16), PAGE_SIZE), 2)


func test_ac20_seventeen_swords_are_three_pages() -> void:
	assert_eq(EquipmentMenu.page_count(_inventory(17), PAGE_SIZE), 3)


func test_ac20_a_page_size_below_one_counts_as_one() -> void:
	assert_eq(EquipmentMenu.page_count(_inventory(3), 0), 3)
	assert_eq(EquipmentMenu.page_count(_inventory(3), -4), 3)


func test_ac20_the_page_of_a_sword_follows_the_order_of_acquisition() -> void:
	var inventory: Inventory = _inventory(17)
	assert_eq(EquipmentMenu.page_of(inventory, _id(1), PAGE_SIZE), 0)
	assert_eq(EquipmentMenu.page_of(inventory, _id(8), PAGE_SIZE), 0)
	assert_eq(EquipmentMenu.page_of(inventory, _id(9), PAGE_SIZE), 1)
	assert_eq(EquipmentMenu.page_of(inventory, _id(16), PAGE_SIZE), 1)
	assert_eq(EquipmentMenu.page_of(inventory, _id(17), PAGE_SIZE), 2)


func test_ac20_the_page_of_a_sword_that_is_not_owned_is_the_first() -> void:
	assert_eq(EquipmentMenu.page_of(_inventory(17), &"nothing", PAGE_SIZE), 0)
	assert_eq(EquipmentMenu.page_of(_inventory(0), _id(1), PAGE_SIZE), 0)


func test_ac20_the_page_of_the_equipped_sword() -> void:
	var inventory: Inventory = _inventory(17)
	inventory.equip(_id(12))
	assert_eq(EquipmentMenu.page_of(inventory, inventory.get_equipped_id(), PAGE_SIZE), 1)
	inventory.equip(_id(17))
	assert_eq(EquipmentMenu.page_of(inventory, inventory.get_equipped_id(), PAGE_SIZE), 2)


# --- entries ---


func test_ac20_one_sword_has_its_entry_then_back() -> void:
	var entries: Array[MenuEntry] = _entries(_inventory(1), true, 0)
	assert_eq(_ids(entries), [&"sword:fixture_sword_01", &"back"] as Array[StringName])
	assert_eq(
		_texts(entries),
		["Sword fixture_sword_01 — 30 (7/7/16) — No trait [equipped]", "Back"] as Array[String]
	)
	assert_eq(_enabled(entries), [true, true] as Array[bool])


func test_ac20_the_texts_of_the_four_traits() -> void:
	var entries: Array[MenuEntry] = _entries(_inventory(4), true, 0)
	assert_eq(
		_texts(entries),
		(
			[
				"Sword fixture_sword_01 — 30 (7/7/16) — No trait [equipped]",
				"Sword fixture_sword_02 — 31 (8/7/16) — Max HP +8",
				"Sword fixture_sword_03 — 32 (8/7/17) — Dash cooldown -0.05 s",
				"Sword fixture_sword_04 — 33 (8/8/17) — Room heal 35% of max HP",
				"Back",
			]
			as Array[String]
		)
	)


func test_ac20_a_count_above_one_is_shown_and_one_is_not() -> void:
	var inventory: Inventory = _inventory(2)
	inventory.add(_id(2))
	var entries: Array[MenuEntry] = _entries(inventory, true, 0)
	assert_eq(entries[0].text, "Sword fixture_sword_01 — 30 (7/7/16) — No trait [equipped]")
	assert_eq(entries[1].text, "Sword fixture_sword_02 — 31 (8/7/16) — Max HP +8 ×2")
	inventory.add(_id(2))
	assert_eq(
		_entries(inventory, true, 0)[1].text, "Sword fixture_sword_02 — 31 (8/7/16) — Max HP +8 ×3"
	)


func test_ac20_the_count_comes_before_the_equipped_mark() -> void:
	var inventory: Inventory = _inventory(2)
	inventory.add(_id(2))
	inventory.equip(_id(2))
	assert_eq(
		_entries(inventory, true, 0)[1].text,
		"Sword fixture_sword_02 — 31 (8/7/16) — Max HP +8 ×2 [equipped]"
	)


func test_ac20_only_the_equipped_sword_has_the_mark() -> void:
	var inventory: Inventory = _inventory(3)
	inventory.equip(_id(2))
	var marked: Array[String] = []
	for entry: MenuEntry in _entries(inventory, true, 0):
		if entry.text.ends_with("[equipped]"):
			marked.append(entry.text)
	assert_eq(
		marked, ["Sword fixture_sword_02 — 31 (8/7/16) — Max HP +8 [equipped]"] as Array[String]
	)


func test_ac20_a_catalog_sword_with_its_own_weights_shows_its_own_hits() -> void:
	var heavy: SwordData = ItemFixtures.make_sword(
		&"heavy", 46, SwordData.Kind.HEAVY_FINISHER, PackedInt32Array([1, 1, 4])
	)
	var catalog: LootCatalog = ItemFixtures.catalog_of(heavy, [] as Array[FloorLoot])
	var inventory: Inventory = Inventory.new()
	inventory.add(&"heavy")
	inventory.equip(&"heavy")
	var entries: Array[MenuEntry] = EquipmentMenu.entries(
		inventory, catalog, _class_data, BASE_HEAL, true, 0, PAGE_SIZE
	)
	assert_eq(entries[0].text, "Sword heavy — 46 (8/7/31) — Heavy finisher [equipped]")


func test_ac20_the_first_of_two_pages_has_next_and_no_previous() -> void:
	var entries: Array[MenuEntry] = _entries(_inventory(9), true, 0)
	assert_eq(entries.size(), 10, "8 swords, Next page, Back")
	assert_eq(entries[0].id, &"sword:fixture_sword_01")
	assert_eq(entries[7].id, &"sword:fixture_sword_08")
	assert_eq(entries[8].id, &"equipment_next")
	assert_eq(entries[8].text, "Next page")
	assert_eq(entries[9].id, &"back")


func test_ac20_the_last_of_two_pages_has_previous_and_no_next() -> void:
	var entries: Array[MenuEntry] = _entries(_inventory(9), true, 1)
	assert_eq(
		_ids(entries),
		[&"sword:fixture_sword_09", &"equipment_previous", &"back"] as Array[StringName]
	)
	assert_eq(entries[1].text, "Previous page")


func test_ac20_the_middle_page_of_seventeen_has_both_page_entries_before_back() -> void:
	var entries: Array[MenuEntry] = _entries(_inventory(17), true, 1)
	var expected: Array[StringName] = []
	for number: int in range(9, 17):
		expected.append(EquipmentMenu.sword_entry_id(_id(number)))
	expected.append_array([&"equipment_next", &"equipment_previous", &"back"] as Array[StringName])
	assert_eq(_ids(entries), expected)
	assert_eq(entries[8].text, "Next page")
	assert_eq(entries[9].text, "Previous page")
	assert_eq(entries[10].text, "Back")


func test_ac20_the_last_page_of_seventeen_has_one_sword() -> void:
	assert_eq(
		_ids(_entries(_inventory(17), true, 2)),
		[&"sword:fixture_sword_17", &"equipment_previous", &"back"] as Array[StringName]
	)


func test_ac20_a_single_page_has_no_page_entries() -> void:
	for owned: int in [0, 1, 5, 8]:
		for entry: MenuEntry in _entries(_inventory(owned), true, 0):
			assert_false(
				entry.id == &"equipment_next" or entry.id == &"equipment_previous",
				"%d swords: %s" % [owned, entry.id]
			)


func test_ac20_an_empty_inventory_has_only_back() -> void:
	assert_eq(_ids(_entries(_inventory(0), true, 0)), [&"back"] as Array[StringName])


func test_ac20_a_page_out_of_range_is_clamped() -> void:
	var inventory: Inventory = _inventory(17)
	assert_eq(_ids(_entries(inventory, true, 99)), _ids(_entries(inventory, true, 2)))
	assert_eq(_ids(_entries(inventory, true, -3)), _ids(_entries(inventory, true, 0)))
	assert_eq(_ids(_entries(_inventory(0), true, 5)), [&"back"] as Array[StringName])


func test_ac20_an_owned_sword_the_catalog_does_not_know_is_skipped() -> void:
	var inventory: Inventory = _inventory(2)
	inventory.add(&"not_in_the_catalog")
	inventory.add(_id(3))
	assert_eq(
		_ids(_entries(inventory, true, 0)),
		(
			[
				&"sword:fixture_sword_01",
				&"sword:fixture_sword_02",
				&"sword:fixture_sword_03",
				&"back"
			]
			as Array[StringName]
		)
	)


func test_ac20_no_catalog_lists_no_swords() -> void:
	var entries: Array[MenuEntry] = EquipmentMenu.entries(
		_inventory(3), null, _class_data, BASE_HEAL, true, 0, PAGE_SIZE
	)
	assert_eq(_ids(entries), [&"back"] as Array[StringName])


func test_ac20_the_builder_reads_and_changes_nothing() -> void:
	var inventory: Inventory = _inventory(9)
	inventory.equip(_id(4))
	var before: Dictionary = inventory.to_dict()
	var first: Array[MenuEntry] = _entries(inventory, true, 0)
	var second: Array[MenuEntry] = _entries(inventory, true, 0)
	assert_eq(inventory.to_dict(), before)
	first[0].text = "changed"
	assert_ne(second[0].text, "changed", "every call makes new entries")


# --- locked ---


func test_ac20_where_equipping_is_not_allowed_every_sword_is_disabled() -> void:
	var entries: Array[MenuEntry] = _entries(_inventory(17), false, 1)
	for entry: MenuEntry in entries:
		if EquipmentMenu.sword_of(entry.id) != &"":
			assert_false(entry.enabled, "%s is grey" % entry.id)
		else:
			assert_true(entry.enabled, "%s stays usable" % entry.id)
	assert_eq(entries.size(), 11)


func test_ac20_a_locked_menu_keeps_the_texts_of_the_swords() -> void:
	var locked: Array[MenuEntry] = _entries(_inventory(4), false, 0)
	var unlocked: Array[MenuEntry] = _entries(_inventory(4), true, 0)
	assert_eq(_texts(locked), _texts(unlocked))
	assert_eq(_ids(locked), _ids(unlocked))


# --- the body ---


func test_ac20_the_body_says_what_choosing_does() -> void:
	assert_eq(EquipmentMenu.body(_inventory(3), true), "Choose a sword to equip it.")


func test_ac20_the_locked_body_says_where_swords_can_be_changed() -> void:
	assert_eq(
		EquipmentMenu.body(_inventory(3), false),
		"Swords can be changed in town, or in the last room before a boss once it is cleared."
	)


func test_ac20_the_body_with_no_swords() -> void:
	assert_eq(EquipmentMenu.body(_inventory(0), true), "No swords.")


# --- the size of the panel ---


func test_ac20_the_middle_page_of_seventeen_with_the_locked_body_is_inside_the_screen() -> void:
	var inventory: Inventory = _inventory(17)
	inventory.equip(_id(12))
	_open_panel(
		EquipmentMenu.body(inventory, false), _entries(inventory, false, 1), ShellMenus.BACK
	)
	await get_tree().process_frame
	var rect: Rect2 = _panel_rect()
	gut.p("Equipment panel, middle page of 17, locked body: %s" % rect)
	assert_eq(_panel.get_entry_ids().size(), 11, "8 swords, both page entries, Back")
	assert_eq(_panel.get_heading(), "Equipment")
	assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(rect), "the whole panel is on the screen")


func test_ac20_the_middle_page_of_seventeen_with_the_choose_body_is_inside_the_screen() -> void:
	var inventory: Inventory = _inventory(17)
	_open_panel(
		EquipmentMenu.body(inventory, true), _entries(inventory, true, 1), EquipmentMenu.NEXT_ID
	)
	await get_tree().process_frame
	var rect: Rect2 = _panel_rect()
	gut.p("Equipment panel, middle page of 17, choose body: %s" % rect)
	assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(rect))


func test_ac20_the_locked_body_is_two_lines() -> void:
	var inventory: Inventory = _inventory(17)
	_open_panel(
		EquipmentMenu.body(inventory, false), _entries(inventory, false, 1), ShellMenus.BACK
	)
	await get_tree().process_frame
	var body: Label = _panel.get_node("Panel/Content/Body")
	assert_eq(body.get_line_count(), 2, "the layout the size check measures")


# --- helpers ---


## An inventory of the first `count` fixture swords, in order; the first one equipped when there is
## one.
func _inventory(count: int) -> Inventory:
	var inventory: Inventory = Inventory.new()
	for number: int in range(1, count + 1):
		inventory.add(_id(number))
	if count > 0:
		inventory.equip(_id(1))
	return inventory


func _id(number: int) -> StringName:
	return StringName("%s%02d" % [ItemFixtures.SWORD_ID_PREFIX, number])


func _entries(inventory: Inventory, can_equip: bool, page: int) -> Array[MenuEntry]:
	return EquipmentMenu.entries(
		inventory, _catalog, _class_data, BASE_HEAL, can_equip, page, PAGE_SIZE
	)


func _ids(entries: Array[MenuEntry]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: MenuEntry in entries:
		ids.append(entry.id)
	return ids


func _texts(entries: Array[MenuEntry]) -> Array[String]:
	var texts: Array[String] = []
	for entry: MenuEntry in entries:
		texts.append(entry.text)
	return texts


func _enabled(entries: Array[MenuEntry]) -> Array[bool]:
	var flags: Array[bool] = []
	for entry: MenuEntry in entries:
		flags.append(entry.enabled)
	return flags


func _open_panel(body_text: String, entries: Array[MenuEntry], focus_id: StringName) -> void:
	_panel = PANEL_SCENE.instantiate()
	add_child_autofree(_panel)
	_panel.open(ShellMenus.heading(ShellFlow.State.EQUIPMENT), body_text, entries, focus_id)


## The whole panel (heading, body and entries) in the canvas.
func _panel_rect() -> Rect2:
	return (_panel.get_node("Panel") as PanelContainer).get_global_rect()
