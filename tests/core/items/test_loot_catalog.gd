# gdlint:disable=max-public-methods
extends GutTest
## F-016 T1 (AC3, AC8, C5, C6): FloorLoot, LootCatalog, the regular kill count of a floor, and the
## fixtures later tasks build on. One test per refusal of C5, each looking for that refusal's own
## error text.

var _class: ClassData
var _rules: ItemTunables
var _tower: TowerData


func before_each() -> void:
	_class = ItemFixtures.class_data()
	_rules = ItemFixtures.rules()
	_tower = TowerFixtures.tower_of(2, 2)


# --- C6: the regular kill count and the chance per kill (AC8) ---


func test_c6_the_regular_kill_count_adds_the_combat_rooms_and_not_the_boss_room() -> void:
	assert_eq(TowerFixtures.floor_of(1, 3).get_regular_kill_count(), 3)
	assert_eq(TowerFixtures.floor_of(1, 1).get_regular_kill_count(), 1)


func test_c6_a_floor_of_only_the_boss_room_has_no_regular_kill() -> void:
	assert_eq(TowerFixtures.floor_of(1, 0).get_regular_kill_count(), 0)


func test_c6_reinforcements_count_as_kills() -> void:
	var floor_data: FloorData = TowerFixtures.floor_of(1, 2)
	floor_data.rooms[0].reinforcements = [1, 1]
	assert_eq(floor_data.rooms[0].get_kill_target(), 3)
	assert_eq(floor_data.get_regular_kill_count(), 4)


func test_c6_a_null_room_counts_for_nothing() -> void:
	var floor_data: FloorData = TowerFixtures.floor_of(1, 2)
	floor_data.rooms[0] = null
	assert_eq(floor_data.get_regular_kill_count(), 1)


func test_ac8_the_chance_per_kill_is_the_drops_per_run_over_the_regular_kills() -> void:
	var loot: FloorLoot = ItemFixtures.floor_loot(1.0, [], [], PackedInt32Array())
	assert_almost_eq(loot.get_chance_per_kill(TowerFixtures.floor_of(1, 4)), 0.25, 0.000001)
	loot.regular_drops_per_run = 2.0
	assert_almost_eq(loot.get_chance_per_kill(TowerFixtures.floor_of(1, 4)), 0.5, 0.000001)


func test_ac8_changing_a_rooms_kill_target_changes_the_chance_and_not_the_drops_per_run() -> void:
	var loot: FloorLoot = ItemFixtures.floor_loot(1.0, [], [], PackedInt32Array())
	var floor_data: FloorData = TowerFixtures.floor_of(1, 3)
	assert_almost_eq(loot.get_chance_per_kill(floor_data), 1.0 / 3.0, 0.000001)
	floor_data.rooms[0].reinforcements = [1]
	assert_eq(floor_data.get_regular_kill_count(), 4)
	assert_almost_eq(loot.get_chance_per_kill(floor_data), 0.25, 0.000001)
	assert_eq(loot.regular_drops_per_run, 1.0, "the drops per run did not move")


func test_c6_a_floor_with_no_kill_or_no_floor_has_chance_zero() -> void:
	var loot: FloorLoot = ItemFixtures.floor_loot(1.0, [], [], PackedInt32Array())
	assert_eq(loot.get_chance_per_kill(TowerFixtures.floor_of(1, 0)), 0.0)
	assert_eq(loot.get_chance_per_kill(null), 0.0)


func test_c5_the_boss_percent_sum() -> void:
	var loot: FloorLoot = ItemFixtures.floor_loot(1.0, [], [], PackedInt32Array([30, 20, 10]))
	assert_eq(loot.get_boss_percent_sum(), 60)
	assert_eq(FloorLoot.new().get_boss_percent_sum(), 0)


# --- C5: looking things up ---


func test_c5_get_floor_loot_counts_floors_from_1_and_gives_null_outside() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	assert_same(catalog.get_floor_loot(1), catalog.floors[0])
	assert_same(catalog.get_floor_loot(2), catalog.floors[1])
	assert_null(catalog.get_floor_loot(0))
	assert_null(catalog.get_floor_loot(3))
	assert_null(catalog.get_floor_loot(-1))


func test_c5_get_floor_loot_gives_null_for_a_floor_with_no_loot() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	catalog.floors[1] = null
	assert_null(catalog.get_floor_loot(2))


func test_c5_get_sword_finds_the_starter_the_pool_and_the_boss_swords() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	assert_same(catalog.get_sword(ItemFixtures.STARTER_ID), catalog.starter_sword)
	assert_same(catalog.get_sword(&"fixture_sword_01"), catalog.floors[0].regular_swords[0])
	assert_same(catalog.get_sword(&"fixture_boss_2_3"), catalog.floors[1].boss_swords[2])
	assert_null(catalog.get_sword(&"nothing"))
	assert_null(catalog.get_sword(&""))


func test_c5_get_all_swords_lists_each_sword_once_starter_first() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	var all: Array[SwordData] = catalog.get_all_swords()
	# The starter, the pool of 2 (shared by both floors), and 3 boss swords per floor.
	assert_eq(all.size(), 1 + 2 + 3 + 3)
	assert_same(all[0], catalog.starter_sword)
	assert_same(all[1], catalog.floors[0].regular_swords[0])
	assert_same(all[3], catalog.floors[0].boss_swords[0])
	assert_same(all[6], catalog.floors[1].boss_swords[0])


func test_c5_get_all_swords_leaves_out_nulls_and_empty_floors() -> void:
	var catalog: LootCatalog = ItemFixtures.catalog_of(null, [null] as Array[FloorLoot])
	assert_eq(catalog.get_all_swords().size(), 0)


# --- C5: validation ---


func test_c5_a_fixture_catalog_validates() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	assert_eq(catalog.validate(_tower, _class, _rules), PackedStringArray())


func test_c5_an_empty_boss_table_and_an_empty_pool_are_allowed() -> void:
	var catalog: LootCatalog = (
		ItemFixtures
		. catalog_of(
			ItemFixtures.starter(),
			(
				[
					ItemFixtures.floor_loot(0.0, [], [], PackedInt32Array()),
					ItemFixtures.floor_loot(1.0, [], [], PackedInt32Array()),
				]
				as Array[FloorLoot]
			)
		)
	)
	assert_eq(catalog.validate(_tower, _class, _rules), PackedStringArray())


func test_c5_a_floor_with_no_loot_is_allowed() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	catalog.floors[0] = null
	assert_eq(catalog.validate(_tower, _class, _rules), PackedStringArray())


func test_c5_refuses_no_starter() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	catalog.starter_sword = null
	assert_true(_has(catalog.validate(_tower, _class, _rules), "needs a starter sword"))


func test_c5_refuses_a_floor_count_other_than_the_towers() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	var longer: TowerData = TowerFixtures.tower_of(3, 2)
	assert_true(
		_has(catalog.validate(longer, _class, _rules), "the catalog has 2 floors, the tower has 3")
	)
	catalog.floors.append(null)
	catalog.floors.append(null)
	assert_true(
		_has(catalog.validate(_tower, _class, _rules), "the catalog has 4 floors, the tower has 2")
	)


func test_c5_refuses_two_different_swords_with_the_same_id() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	catalog.floors[1].boss_swords[0] = ItemFixtures.make_sword(ItemFixtures.STARTER_ID, 45)
	assert_true(
		_has(catalog.validate(_tower, _class, _rules), "duplicate sword id fixture_starter")
	)


func test_c5_the_same_sword_on_two_floors_is_not_a_duplicate() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	assert_same(catalog.floors[0].regular_swords[0], catalog.floors[1].regular_swords[0])
	assert_false(_has(catalog.validate(_tower, _class, _rules), "duplicate"))


func test_c5_refuses_the_same_sword_twice_in_one_pool_or_table() -> void:
	var pooled: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	pooled.floors[0].regular_swords[1] = pooled.floors[0].regular_swords[0]
	assert_true(_has(pooled.validate(_tower, _class, _rules), "in floor 1: regular_swords"))
	var tabled: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	tabled.floors[1].boss_swords[2] = tabled.floors[1].boss_swords[0]
	assert_true(_has(tabled.validate(_tower, _class, _rules), "in floor 2: boss_swords"))


func test_c5_refuses_a_null_sword_in_a_pool_or_table() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	catalog.floors[0].regular_swords[0] = null
	assert_true(
		_has(
			catalog.validate(_tower, _class, _rules), "floor 1: regular_swords[0] must not be null"
		)
	)
	catalog = ItemFixtures.fixture_catalog(_tower)
	catalog.floors[0].boss_swords[1] = null
	assert_true(
		_has(catalog.validate(_tower, _class, _rules), "floor 1: boss_swords[1] must not be null")
	)


func test_c5_refuses_an_invalid_sword_and_says_which() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	catalog.floors[0].boss_swords[1].damage = _rules.max_chain_damage + 1
	var errors: PackedStringArray = catalog.validate(_tower, _class, _rules)
	assert_true(_has(errors, "sword fixture_boss_1_2: damage"), str(errors))
	var starter: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	starter.starter_sword.damage = 0
	assert_true(
		_has(starter.validate(_tower, _class, _rules), "sword fixture_starter: damage must be >= 1")
	)


func test_c5_refuses_percents_and_swords_of_different_sizes() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	catalog.floors[0].boss_percents = PackedInt32Array([30, 20])
	assert_true(
		_has(
			catalog.validate(_tower, _class, _rules),
			"floor 1: boss_percents has 2 entries, boss_swords has 3"
		)
	)
	catalog = ItemFixtures.fixture_catalog(_tower)
	catalog.floors[1].boss_percents = PackedInt32Array([30, 20, 10, 5])
	assert_true(
		_has(catalog.validate(_tower, _class, _rules), "floor 2: boss_percents has 4 entries")
	)


func test_c5_refuses_a_percent_below_1() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	catalog.floors[0].boss_percents = PackedInt32Array([30, 0, 10])
	assert_true(
		_has(catalog.validate(_tower, _class, _rules), "every boss percent must be >= 1, found 0")
	)
	catalog.floors[0].boss_percents = PackedInt32Array([30, -5, 10])
	assert_true(_has(catalog.validate(_tower, _class, _rules), "found -5"))


func test_c5_refuses_percents_adding_up_above_100() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	catalog.floors[0].boss_percents = PackedInt32Array([60, 30, 11])
	assert_true(_has(catalog.validate(_tower, _class, _rules), "add up to 101, above 100"))


func test_c5_percents_adding_up_to_exactly_100_are_valid() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	catalog.floors[0].boss_percents = PackedInt32Array([60, 30, 10])
	assert_eq(catalog.validate(_tower, _class, _rules), PackedStringArray())


func test_c5_refuses_negative_drops_per_run() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	catalog.floors[1].regular_drops_per_run = -0.5
	assert_true(
		_has(
			catalog.validate(_tower, _class, _rules), "floor 2: regular_drops_per_run must be >= 0"
		)
	)


func test_c5_refuses_drops_per_run_on_a_floor_with_no_kill_before_the_boss() -> void:
	var bare: TowerData = TowerFixtures.tower_of(1, 0)
	assert_eq(bare.get_floor(1).get_regular_kill_count(), 0)
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(bare)
	assert_true(
		_has(
			catalog.validate(bare, _class, _rules), "floor 1: drops per run on a floor with no kill"
		)
	)
	catalog.floors[0].regular_drops_per_run = 0.0
	assert_eq(
		catalog.validate(bare, _class, _rules), PackedStringArray(), "zero drops need no kill"
	)


func test_c5_refuses_a_chance_per_kill_above_1() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	# Two kills a floor: 2.5 drops per run is a chance of 1.25 per kill.
	catalog.floors[0].regular_drops_per_run = 2.5
	assert_true(
		_has(
			catalog.validate(_tower, _class, _rules),
			"floor 1: 2.50 drops per run over 2 kills is a chance above 1"
		)
	)


func test_c5_a_chance_of_exactly_1_is_valid() -> void:
	var catalog: LootCatalog = ItemFixtures.catalog_with(
		_tower, true, [] as Array[SwordData], PackedInt32Array()
	)
	assert_eq(catalog.floors[0].get_chance_per_kill(_tower.get_floor(1)), 1.0)
	assert_eq(catalog.validate(_tower, _class, _rules), PackedStringArray())


func test_c5_every_error_is_returned_not_the_first() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	catalog.starter_sword = null
	catalog.floors[0].boss_percents = PackedInt32Array([0, 20, 10])
	catalog.floors[1].regular_drops_per_run = -1.0
	assert_gte(catalog.validate(_tower, _class, _rules).size(), 3)


# --- the fixtures ---


func test_fixtures_17_distinct_valid_swords() -> void:
	var swords: Array[SwordData] = ItemFixtures.valid_swords(17)
	assert_eq(swords.size(), 17)
	var ids: Array[StringName] = []
	var names: Array[String] = []
	for sword: SwordData in swords:
		assert_eq(sword.validate(_class, _rules), PackedStringArray(), str(sword.id))
		assert_false(ids.has(sword.id), "id %s once" % sword.id)
		assert_false(names.has(sword.display_name), "name %s once" % sword.display_name)
		ids.append(sword.id)
		names.append(sword.display_name)


func test_fixtures_a_certain_catalog_has_chance_1_and_an_impossible_one_chance_0() -> void:
	var boss: Array[SwordData] = [ItemFixtures.make_sword(&"boss_a", 45)]
	var certain: LootCatalog = ItemFixtures.catalog_with(
		_tower, true, boss, PackedInt32Array([100])
	)
	var impossible: LootCatalog = ItemFixtures.catalog_with(
		_tower, false, boss, PackedInt32Array([100])
	)
	for number: int in [1, 2]:
		assert_eq(certain.get_floor_loot(number).get_chance_per_kill(_tower.get_floor(number)), 1.0)
		assert_eq(
			impossible.get_floor_loot(number).get_chance_per_kill(_tower.get_floor(number)), 0.0
		)
	assert_eq(certain.validate(_tower, _class, _rules), PackedStringArray())
	assert_eq(impossible.validate(_tower, _class, _rules), PackedStringArray())


func test_fixtures_the_given_boss_table_is_on_every_floor() -> void:
	var boss: Array[SwordData] = [
		ItemFixtures.make_sword(&"boss_a", 45), ItemFixtures.make_sword(&"boss_b", 46)
	]
	var catalog: LootCatalog = ItemFixtures.catalog_with(
		_tower, false, boss, PackedInt32Array([50, 25])
	)
	for number: int in [1, 2]:
		assert_eq(catalog.get_floor_loot(number).boss_swords, boss)
		assert_eq(catalog.get_floor_loot(number).boss_percents, PackedInt32Array([50, 25]))


func test_fixtures_a_fixture_catalog_gives_the_tower_its_boss_tables() -> void:
	var catalog: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	assert_eq(catalog.floors.size(), 2)
	for number: int in [1, 2]:
		var loot: FloorLoot = catalog.get_floor_loot(number)
		assert_eq(loot.boss_percents, PackedInt32Array([30, 20, 10]))
		assert_eq(loot.regular_swords.size(), 2)
		assert_eq(loot.regular_drops_per_run, 1.0)


func _has(errors: PackedStringArray, needle: String) -> bool:
	for error: String in errors:
		if error.contains(needle):
			return true
	return false
