# gdlint:disable=max-public-methods
extends GutTest
## F-016 T2 (C13, AC11, AC12): CharacterLoot gives and equips the starter, keeps the boss swords
## taken by floor, makes the rooms' loot, and restores itself or refuses a snapshot and keeps what
## it had.

const SEED: int = 4242
const FLOORS: int = 3

var _tower: TowerData
var _catalog: LootCatalog
var _character: CharacterLoot


func before_each() -> void:
	_tower = TowerFixtures.tower_of(FLOORS, 2)
	_catalog = ItemFixtures.fixture_catalog(_tower)
	_character = LootFixtures.character(_catalog, SEED)


## A character with something in every part of its state: two swords (one twice), another
## equipped, a boss sword of floor 2 taken, a roller that has moved.
func _played() -> CharacterLoot:
	var played: CharacterLoot = LootFixtures.character(_catalog, SEED)
	var pool: Array[SwordData] = _catalog.get_floor_loot(1).regular_swords
	played.report_taken(pool[0].id, 0)
	played.report_taken(pool[0].id, 0)
	played.report_taken(&"fixture_boss_2_1", 2)
	played.get_inventory().equip(pool[0].id)
	played.get_roller().roll_boss(PackedInt32Array([30, 20, 10]), true)
	return played


# --- setup ---


func test_c13_setup_gives_the_starter_sword_once_and_equips_it() -> void:
	var inventory: Inventory = _character.get_inventory()
	assert_eq(inventory.get_ids(), [ItemFixtures.STARTER_ID] as Array[StringName])
	assert_eq(inventory.get_count(ItemFixtures.STARTER_ID), 1)
	assert_eq(inventory.get_equipped_id(), ItemFixtures.STARTER_ID)
	assert_same(_character.get_equipped_sword(), _catalog.starter_sword)
	assert_same(_character.get_catalog(), _catalog)


func test_c13_setup_seeds_the_roller_and_takes_no_boss_sword() -> void:
	assert_eq(_character.get_roller().get_seed(), SEED)
	for floor_number: int in range(0, FLOORS + 2):
		assert_false(_character.is_boss_sword_taken(floor_number), "floor %d" % floor_number)


func test_c13_without_a_catalog_the_character_owns_nothing() -> void:
	var bare: CharacterLoot = LootFixtures.character(null, 0)
	assert_true(bare.get_inventory().get_ids().is_empty())
	assert_eq(bare.get_inventory().get_equipped_id(), &"")
	assert_null(bare.get_equipped_sword())
	assert_null(bare.get_catalog())
	assert_false(bare.knows_sword(ItemFixtures.STARTER_ID))


func test_c13_a_new_character_is_the_one_a_session_makes_before_set_loot() -> void:
	var fresh: CharacterLoot = CharacterLoot.new()
	assert_true(fresh.get_inventory().get_ids().is_empty())
	assert_eq(fresh.get_roller().get_seed(), 0)
	assert_null(fresh.get_equipped_sword())


func test_c13_setup_again_starts_over_in_the_same_objects() -> void:
	var inventory: Inventory = _character.get_inventory()
	var roller: LootRoller = _character.get_roller()
	_character.report_taken(&"fixture_boss_1_1", 1)
	_character.report_taken(&"fixture_sword_01", 0)
	_character.get_roller().roll_boss(PackedInt32Array([30]), true)
	_character.setup(_catalog, 99)
	assert_same(_character.get_inventory(), inventory)
	assert_same(_character.get_roller(), roller)
	assert_eq(inventory.get_ids(), [ItemFixtures.STARTER_ID] as Array[StringName])
	assert_eq(roller.get_seed(), 99)
	assert_false(_character.is_boss_sword_taken(1))
	_character.setup(null, 0)
	assert_true(inventory.get_ids().is_empty(), "a null catalog empties it")


func test_c13_a_catalog_without_a_starter_gives_nothing() -> void:
	var no_starter: LootCatalog = ItemFixtures.fixture_catalog(_tower)
	no_starter.starter_sword = null
	var character: CharacterLoot = LootFixtures.character(no_starter, 1)
	assert_true(character.get_inventory().get_ids().is_empty())
	assert_null(character.get_equipped_sword())


func test_c13_the_equipped_sword_follows_the_inventory() -> void:
	var pool: Array[SwordData] = _catalog.get_floor_loot(1).regular_swords
	_character.report_taken(pool[1].id, 0)
	assert_true(_character.get_inventory().equip(pool[1].id))
	assert_same(_character.get_equipped_sword(), pool[1])


# --- what was taken ---


func test_c13_a_taken_sword_is_owned_and_a_second_one_is_a_count() -> void:
	_character.report_taken(&"fixture_sword_01", 0)
	_character.report_taken(&"fixture_sword_01", 0)
	assert_eq(_character.get_inventory().get_count(&"fixture_sword_01"), 2)


func test_ac11_only_a_boss_sword_sets_its_floors_flag_and_no_other() -> void:
	_character.report_taken(&"fixture_sword_01", 0)
	for floor_number: int in range(1, FLOORS + 1):
		assert_false(
			_character.is_boss_sword_taken(floor_number), "a regular sword: floor %d" % floor_number
		)
	_character.report_taken(&"fixture_boss_2_1", 2)
	assert_false(_character.is_boss_sword_taken(1))
	assert_true(_character.is_boss_sword_taken(2))
	assert_false(_character.is_boss_sword_taken(3))
	_character.report_taken(&"fixture_boss_2_2", 2)
	assert_true(_character.is_boss_sword_taken(2), "taking another keeps it")


func test_c13_knows_sword_is_the_catalogs_swords() -> void:
	assert_true(_character.knows_sword(ItemFixtures.STARTER_ID))
	assert_true(_character.knows_sword(&"fixture_boss_3_3"))
	assert_false(_character.knows_sword(&"nope"))


# --- the rooms' loot ---


func test_c13_a_rooms_loot_knows_its_floor_and_whether_it_is_the_boss_room() -> void:
	var first: RoomLoot = LootFixtures.room_loot(_character, _tower, 2, 0)
	var last_combat: RoomLoot = LootFixtures.room_loot(_character, _tower, 2, 1)
	var boss: RoomLoot = LootFixtures.room_loot(_character, _tower, 2, 2)
	assert_eq(first.get_floor_number(), 2)
	assert_false(first.is_boss_room())
	assert_false(last_combat.is_boss_room())
	assert_true(boss.is_boss_room(), "the floor's last room")


func test_c13_every_room_loot_is_its_own_object() -> void:
	var first: RoomLoot = LootFixtures.room_loot(_character, _tower, 1, 0)
	var second: RoomLoot = LootFixtures.room_loot(_character, _tower, 1, 0)
	assert_ne(first, second)


# --- the snapshot ---


func test_ac12_a_played_character_round_trips() -> void:
	var source: CharacterLoot = _played()
	var copy: CharacterLoot = LootFixtures.character(_catalog, 1)
	assert_true(copy.from_dict(source.to_dict()))
	assert_eq_deep(copy.to_dict(), source.to_dict())
	assert_eq(copy.get_inventory().get_count(_catalog.get_floor_loot(1).regular_swords[0].id), 2)
	assert_eq(
		copy.get_inventory().get_equipped_id(), _catalog.get_floor_loot(1).regular_swords[0].id
	)
	assert_true(copy.is_boss_sword_taken(2))
	assert_false(copy.is_boss_sword_taken(1))


func test_ac12_the_roller_goes_on_where_the_saved_one_was() -> void:
	var source: CharacterLoot = _played()
	var snapshot: Dictionary = source.to_dict()
	var percents: PackedInt32Array = PackedInt32Array([30, 20, 10])
	var later: Array[int] = []
	for _i: int in 50:
		later.append(source.get_roller().roll_boss(percents, true))
	var copy: CharacterLoot = LootFixtures.character(_catalog, 77)
	assert_true(copy.from_dict(snapshot))
	var again: Array[int] = []
	for _i: int in 50:
		again.append(copy.get_roller().roll_boss(percents, true))
	assert_eq(again, later)


func test_ac12_the_empty_state_of_a_character_without_a_catalog_round_trips() -> void:
	var bare: CharacterLoot = LootFixtures.character(null, 0)
	var copy: CharacterLoot = LootFixtures.character(null, 5)
	assert_true(copy.from_dict(bare.to_dict()))
	assert_eq_deep(copy.to_dict(), bare.to_dict())
	assert_eq(copy.get_roller().get_seed(), 0)


func test_ac12_the_snapshot_holds_the_roller_the_inventory_and_the_boss_floors_and_no_catalog(
) -> void:
	# The catalog is not saved: the one that restores must be the one that saved.
	var snapshot: Dictionary = _played().to_dict()
	assert_eq(snapshot.keys().size(), 3)
	for key: String in [
		CharacterLoot.KEY_ROLLER, CharacterLoot.KEY_INVENTORY, CharacterLoot.KEY_BOSS_TAKEN
	]:
		assert_true(snapshot.has(key), key)


## A copy of the played character's snapshot with `key` replaced.
func _with(key: String, value: Variant) -> Dictionary:
	var snapshot: Dictionary = _played().to_dict()
	snapshot[key] = value
	return snapshot


func _inventory_with(owned: Array, equipped: String) -> Dictionary:
	return {Inventory.KEY_OWNED: owned, Inventory.KEY_EQUIPPED: equipped}


func _owned(sword_id: String, count: int = 1) -> Dictionary:
	return {Inventory.KEY_ID: sword_id, Inventory.KEY_COUNT: count}


## Refused, and the played character it was offered to is exactly as it was.
func _assert_refused(snapshot: Dictionary, message: String) -> void:
	var target: CharacterLoot = _played()
	var before: Dictionary = target.to_dict()
	watch_signals(target.get_inventory())
	assert_false(target.from_dict(snapshot), message)
	assert_eq_deep(target.to_dict(), before)
	assert_signal_not_emitted(target.get_inventory(), "changed", message)


func test_c13_an_owned_id_the_catalog_does_not_have_is_refused() -> void:
	var owned: Array = [_owned(String(ItemFixtures.STARTER_ID)), _owned("not_in_the_catalog")]
	_assert_refused(
		_with(CharacterLoot.KEY_INVENTORY, _inventory_with(owned, String(ItemFixtures.STARTER_ID))),
		"unknown sword"
	)


func test_c13_a_taken_floor_outside_the_catalogs_floors_is_refused() -> void:
	for floor_number: int in [0, -1, FLOORS + 1, 99]:
		_assert_refused(
			_with(CharacterLoot.KEY_BOSS_TAKEN, [floor_number]), "floor %d" % floor_number
		)


func test_c13_a_taken_floor_that_is_not_an_integer_or_is_listed_twice_is_refused() -> void:
	_assert_refused(_with(CharacterLoot.KEY_BOSS_TAKEN, ["2"]), "text")
	_assert_refused(_with(CharacterLoot.KEY_BOSS_TAKEN, [2.0]), "a float")
	_assert_refused(_with(CharacterLoot.KEY_BOSS_TAKEN, [1, 1]), "twice")


func test_c13_with_a_catalog_a_state_with_nothing_equipped_is_refused() -> void:
	var owned: Array = [_owned(String(ItemFixtures.STARTER_ID))]
	_assert_refused(
		_with(CharacterLoot.KEY_INVENTORY, _inventory_with(owned, "")), "owned, nothing equipped"
	)
	_assert_refused(
		_with(CharacterLoot.KEY_INVENTORY, _inventory_with([], "")), "the empty inventory"
	)


func test_c13_without_a_catalog_anything_but_the_empty_inventory_is_refused() -> void:
	var bare: CharacterLoot = LootFixtures.character(null, 0)
	var before: Dictionary = bare.to_dict()
	var snapshot: Dictionary = _played().to_dict()
	assert_false(bare.from_dict(snapshot), "an inventory with swords")
	assert_eq_deep(bare.to_dict(), before)
	var floors_only: Dictionary = bare.to_dict()
	floors_only[CharacterLoot.KEY_BOSS_TAKEN] = [1]
	assert_false(bare.from_dict(floors_only), "a floor that no catalog has")
	assert_eq_deep(bare.to_dict(), before)


func test_c13_the_rollers_seed_and_state_are_free_in_both_cases() -> void:
	var odd: Dictionary = {
		LootRoller.KEY_SEED: -9223372036854775808, LootRoller.KEY_STATE: 9223372036854775807
	}
	var with_catalog: Dictionary = _played().to_dict()
	with_catalog[CharacterLoot.KEY_ROLLER] = odd
	assert_true(LootFixtures.character(_catalog, 1).from_dict(with_catalog))
	var without: Dictionary = LootFixtures.character(null, 0).to_dict()
	without[CharacterLoot.KEY_ROLLER] = odd
	assert_true(LootFixtures.character(null, 0).from_dict(without))


func test_c13_malformed_shapes_are_refused() -> void:
	_assert_refused({}, "nothing")
	_assert_refused(_without(CharacterLoot.KEY_ROLLER), "no roller")
	_assert_refused(_without(CharacterLoot.KEY_INVENTORY), "no inventory")
	_assert_refused(_without(CharacterLoot.KEY_BOSS_TAKEN), "no boss floors")
	_assert_refused(_with(CharacterLoot.KEY_ROLLER, "x"), "roller not a dictionary")
	_assert_refused(_with(CharacterLoot.KEY_INVENTORY, [1]), "inventory not a dictionary")
	_assert_refused(_with(CharacterLoot.KEY_BOSS_TAKEN, {}), "floors not a list")
	_assert_refused(_with(CharacterLoot.KEY_ROLLER, {LootRoller.KEY_SEED: 1}), "half a roller")
	_assert_refused(
		_with(CharacterLoot.KEY_ROLLER, {LootRoller.KEY_SEED: 1.5, LootRoller.KEY_STATE: 2}),
		"a float seed"
	)
	var bad_count: Array = [_owned(String(ItemFixtures.STARTER_ID), 0)]
	_assert_refused(
		_with(
			CharacterLoot.KEY_INVENTORY, _inventory_with(bad_count, String(ItemFixtures.STARTER_ID))
		),
		"a count of 0"
	)
	var not_owned: Array = [_owned(String(ItemFixtures.STARTER_ID))]
	_assert_refused(
		_with(CharacterLoot.KEY_INVENTORY, _inventory_with(not_owned, "fixture_sword_01")),
		"equipped, not owned"
	)


func _without(key: String) -> Dictionary:
	var snapshot: Dictionary = _played().to_dict()
	snapshot.erase(key)
	return snapshot
