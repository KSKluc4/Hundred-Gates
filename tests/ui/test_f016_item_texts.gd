# gdlint:disable=max-public-methods
extends GutTest
## F-016 T1 (C18, C19): the exact texts of swords and loot. The strings are written out on
## purpose: a change to a text must change them too. The base heal fraction is 0.3 throughout.

const BASE: float = 0.3

var _class: ClassData


func before_each() -> void:
	_class = load(Tunables.WARRIOR_PATH)


# --- C18: the Equipment menu's texts ---


func test_c18_the_menu_texts() -> void:
	assert_eq(ItemTexts.EQUIPMENT_HEADING, "Equipment")
	assert_eq(ItemTexts.CHOOSE_BODY, "Choose a sword to equip it.")
	assert_eq(
		ItemTexts.LOCKED_BODY,
		"Swords can be changed in town, or in the last room before a boss once it is cleared."
	)
	assert_eq(ItemTexts.NO_SWORDS_BODY, "No swords.")
	assert_eq(ItemTexts.NEXT_PAGE_TEXT, "Next page")
	assert_eq(ItemTexts.PREVIOUS_PAGE_TEXT, "Previous page")


# --- C18: the traits ---


func test_c18_no_trait() -> void:
	assert_eq(ItemTexts.trait_text(_sword(&"recruits_sword"), BASE), "No trait")


func test_c18_heavy_finisher_and_quick_cuts() -> void:
	assert_eq(ItemTexts.trait_text(_sword(&"iron_cleaver"), BASE), "Heavy finisher")
	assert_eq(ItemTexts.trait_text(_sword(&"twin_edge"), BASE), "Quick cuts")


func test_c18_vitality() -> void:
	assert_eq(ItemTexts.trait_text(_sword(&"guards_blade"), BASE), "Max HP +8")


func test_c18_quickstep_has_two_decimals() -> void:
	assert_eq(ItemTexts.trait_text(_sword(&"swift_blade"), BASE), "Dash cooldown -0.05 s")
	assert_eq(ItemTexts.trait_text(_sword(&"wardens_stride"), BASE), "Dash cooldown -0.08 s")


func test_c18_mending_reads_the_base_fraction_plus_the_bonus_as_a_percentage() -> void:
	assert_eq(ItemTexts.trait_text(_sword(&"pilgrims_blade"), BASE), "Room heal 35% of max HP")
	assert_eq(ItemTexts.trait_text(_sword(&"wardens_mercy"), BASE), "Room heal 40% of max HP")


func test_c18_mending_follows_the_base_and_never_reads_above_100() -> void:
	assert_eq(ItemTexts.trait_text(_sword(&"wardens_mercy"), 0.5), "Room heal 60% of max HP")
	assert_eq(ItemTexts.trait_text(_sword(&"wardens_mercy"), 0.95), "Room heal 100% of max HP")
	assert_eq(ItemTexts.trait_text(_sword(&"wardens_mercy"), 1.0), "Room heal 100% of max HP")


# --- C18: a sword's entry ---


func test_c18_a_sword_entry_is_name_damage_hits_and_trait() -> void:
	assert_eq(_entry(&"recruits_sword", 1, false), "Recruit's Sword — 42 (10/10/22) — No trait")
	assert_eq(_entry(&"iron_cleaver", 1, false), "Iron Cleaver — 46 (9/9/28) — Heavy finisher")
	assert_eq(_entry(&"guards_blade", 1, false), "Guard's Blade — 44 (11/10/23) — Max HP +8")
	assert_eq(
		_entry(&"swift_blade", 1, false), "Swift Blade — 44 (11/10/23) — Dash cooldown -0.05 s"
	)
	assert_eq(
		_entry(&"pilgrims_blade", 1, false),
		"Pilgrim's Blade — 44 (11/10/23) — Room heal 35% of max HP"
	)


func test_c18_the_entry_literally_uses_an_em_dash_and_a_multiplication_sign() -> void:
	assert_eq(_entry(&"twin_edge", 2, true), "Twin Edge — 43 (12/12/19) — Quick cuts ×2 [equipped]")


func test_c18_a_count_of_1_or_less_shows_no_count() -> void:
	assert_eq(_entry(&"twin_edge", 1, false), "Twin Edge — 43 (12/12/19) — Quick cuts")
	assert_eq(_entry(&"twin_edge", 0, false), "Twin Edge — 43 (12/12/19) — Quick cuts")


func test_c18_a_count_above_1_adds_a_multiplication_sign_and_the_number() -> void:
	assert_eq(_entry(&"twin_edge", 2, false), "Twin Edge — 43 (12/12/19) — Quick cuts ×2")
	assert_eq(_entry(&"twin_edge", 13, false), "Twin Edge — 43 (12/12/19) — Quick cuts ×13")


func test_c18_the_equipped_mark_comes_last() -> void:
	assert_eq(_entry(&"twin_edge", 1, true), "Twin Edge — 43 (12/12/19) — Quick cuts [equipped]")
	assert_eq(_entry(&"twin_edge", 3, true), "Twin Edge — 43 (12/12/19) — Quick cuts ×3 [equipped]")


# --- C18: the pickup notice ---


func test_c18_found_with_one_name() -> void:
	assert_eq(ItemTexts.found_text(PackedStringArray(["Twin Edge"])), "Found: Twin Edge")


func test_c18_found_with_two_names() -> void:
	assert_eq(
		ItemTexts.found_text(PackedStringArray(["Twin Edge", "Iron Cleaver"])),
		"Found: Twin Edge, Iron Cleaver"
	)


func test_c18_found_with_more_than_two_names_gives_the_first_two_and_a_count() -> void:
	assert_eq(
		ItemTexts.found_text(PackedStringArray(["Twin Edge", "Iron Cleaver", "Swift Blade"])),
		"Found: Twin Edge, Iron Cleaver +1 more"
	)
	assert_eq(
		ItemTexts.found_text(PackedStringArray(["A", "B", "C", "D", "E"])), "Found: A, B +3 more"
	)


func test_c18_found_with_no_names_is_empty() -> void:
	assert_eq(ItemTexts.found_text(PackedStringArray()), "")


# --- C19: the odds at the gate ---


func test_c19_the_floor_1_odds_before_a_boss_sword_was_taken() -> void:
	var expected: String = (
		"Boss drops:\n"
		+ "30% chance: Warden's Mercy — 45 (11/11/23) — Room heal 40% of max HP\n"
		+ "20% chance: Warden's Stride — 45 (11/11/23) — Dash cooldown -0.08 s\n"
		+ "10% chance: Warden's Verdict — 47 (9/9/29) — Heavy finisher\n"
		+ "Your next win is sure to drop one of these, in these proportions."
	)
	assert_eq(ItemTexts.odds_text(_floor_loot(1), _class, BASE, true), expected)


func test_c19_the_floor_1_odds_after_a_boss_sword_was_taken() -> void:
	var expected: String = (
		"Boss drops:\n"
		+ "30% chance: Warden's Mercy — 45 (11/11/23) — Room heal 40% of max HP\n"
		+ "20% chance: Warden's Stride — 45 (11/11/23) — Dash cooldown -0.08 s\n"
		+ "10% chance: Warden's Verdict — 47 (9/9/29) — Heavy finisher\n"
		+ "Nothing: 40%"
	)
	assert_eq(ItemTexts.odds_text(_floor_loot(1), _class, BASE, false), expected)


func test_c19_the_floor_3_lines() -> void:
	var lines: PackedStringArray = ItemTexts.odds_text(_floor_loot(3), _class, BASE, false).split(
		"\n"
	)
	assert_eq(lines.size(), 5)
	assert_eq(lines[1], "30% chance: Juggernaut's Maul — 49 (10/10/29) — Heavy finisher")
	assert_eq(lines[2], "20% chance: Juggernaut's Fangs — 46 (13/13/20) — Quick cuts")
	assert_eq(lines[3], "10% chance: Juggernaut's Rush — 48 (12/11/25) — Dash cooldown -0.08 s")


func test_c19_a_table_adding_up_to_100_has_no_nothing_line() -> void:
	var loot: FloorLoot = _floor_loot(1).duplicate()
	loot.boss_percents = PackedInt32Array([60, 30, 10])
	var text: String = ItemTexts.odds_text(loot, _class, BASE, false)
	assert_false(text.contains("Nothing"), text)
	assert_true(text.ends_with("10% chance: Warden's Verdict — 47 (9/9/29) — Heavy finisher"), text)
	assert_true(text.contains("60% chance: Warden's Mercy"), text)


func test_c19_a_table_adding_up_to_100_still_has_the_guarantee_line_while_guaranteed() -> void:
	var loot: FloorLoot = _floor_loot(1).duplicate()
	loot.boss_percents = PackedInt32Array([60, 30, 10])
	var text: String = ItemTexts.odds_text(loot, _class, BASE, true)
	assert_true(
		text.ends_with("Your next win is sure to drop one of these, in these proportions."), text
	)


func test_c19_a_null_or_empty_table_gives_no_text() -> void:
	assert_eq(ItemTexts.odds_text(null, _class, BASE, true), "")
	assert_eq(ItemTexts.odds_text(null, _class, BASE, false), "")
	var empty: FloorLoot = ItemFixtures.floor_loot(1.0, [], [], PackedInt32Array())
	assert_eq(ItemTexts.odds_text(empty, _class, BASE, true), "")
	assert_eq(ItemTexts.odds_text(empty, _class, BASE, false), "")


func test_c19_a_regular_pool_alone_gives_no_odds() -> void:
	var loot: FloorLoot = ItemFixtures.floor_loot(
		1.0, ItemFixtures.valid_swords(2), [], PackedInt32Array()
	)
	assert_eq(ItemTexts.odds_text(loot, _class, BASE, true), "")


func test_c19_the_odds_follow_the_base_heal_fraction() -> void:
	var text: String = ItemTexts.odds_text(_floor_loot(1), _class, 0.5, false)
	assert_true(text.contains("Room heal 60% of max HP"), text)


# --- helpers ---


func _sword(sword_id: StringName) -> SwordData:
	return load("res://data/items/swords/%s.tres" % sword_id)


func _entry(sword_id: StringName, count: int, equipped: bool) -> String:
	var sword: SwordData = _sword(sword_id)
	return ItemTexts.sword_text(sword, sword.get_hit_damages(_class), count, equipped, BASE)


func _floor_loot(floor_number: int) -> FloorLoot:
	return (load(Tunables.LOOT_CATALOG_PATH) as LootCatalog).get_floor_loot(floor_number)


## CR-9: what joins the `Found:` notice to a heal or a clear of the same moment lives here, pinned
## as a literal (a space, a middle dot, a space).
func test_cr9_the_banner_join_is_a_middle_dot_between_spaces() -> void:
	assert_eq(ItemTexts.BANNER_JOIN, " · ")
	assert_eq(ItemTexts.BANNER_JOIN.length(), 3)
