# gdlint:disable=max-public-methods
extends GutTest
## F-016 T2 (C14, AC12, AC16, AC17 in core): the session owns the character's loot, keeps it through
## every change of place, says where a sword may be changed, and restores it all-or-nothing.

const DELAY: float = 1.5
## Two combat rooms and the boss room on every floor of the fixture tower.
const BOSS_ROOM: int = 2
const SEED: int = 9001

var _tower: TowerData
var _rules: TowerTunables
var _catalog: LootCatalog
var _session: TowerSession
var _spare: SwordData


func before_each() -> void:
	_tower = TowerFixtures.tower_of(3, 2)
	_rules = TowerFixtures.tower_rules()
	_rules.death_return_delay = DELAY
	_catalog = ItemFixtures.fixture_catalog(_tower)
	_spare = _catalog.get_floor_loot(1).regular_swords[0]
	_session = _new_session()
	_session.set_loot(_catalog, SEED)
	_session.get_loot().report_taken(_spare.id, 0)  # owned, not equipped


func _new_session() -> TowerSession:
	var session: TowerSession = TowerSession.new()
	session.setup(_tower, _rules)
	return session


func _equipped() -> StringName:
	return _session.get_loot().get_inventory().get_equipped_id()


## A floor run on the session's current floor, in room `room_index`, cleared or not.
func _run_in(room_index: int, cleared: bool) -> FloorRun:
	var run: FloorRun = FloorRun.new()
	run.setup(_session.get_floor_data(), RoomFixtures.rules(), 100, 0)
	for _i: int in room_index:
		run.report_room_cleared(100)
		run.advance(100)
	if cleared:
		run.report_room_cleared(100)
	return run


# --- C14: what the session owns ---


func test_c14_a_session_has_a_character_with_no_catalog_and_seed_zero_until_set_loot() -> void:
	var session: TowerSession = _new_session()
	var loot: CharacterLoot = session.get_loot()
	assert_not_null(loot)
	assert_null(loot.get_catalog())
	assert_true(loot.get_inventory().get_ids().is_empty())
	assert_eq(loot.get_roller().get_seed(), 0)


func test_c14_a_session_that_was_never_set_up_has_the_same_empty_character() -> void:
	var session: TowerSession = TowerSession.new()
	assert_not_null(session.get_loot())
	assert_eq(session.get_loot().get_roller().get_seed(), 0)


func test_c14_set_loot_gives_the_starter_equipped_and_seeds_the_roller() -> void:
	var loot: CharacterLoot = _session.get_loot()
	assert_same(loot.get_catalog(), _catalog)
	assert_eq(loot.get_roller().get_seed(), SEED)
	assert_eq(loot.get_inventory().get_count(ItemFixtures.STARTER_ID), 1)
	assert_eq(_equipped(), ItemFixtures.STARTER_ID)


func test_c14_set_loot_starts_the_same_character_over_and_does_not_replace_it() -> void:
	var loot: CharacterLoot = _session.get_loot()
	var inventory: Inventory = loot.get_inventory()
	_session.set_loot(_catalog, 5)
	assert_same(_session.get_loot(), loot)
	assert_same(loot.get_inventory(), inventory)
	assert_false(inventory.has(_spare.id), "what was owned is gone")
	assert_eq(loot.get_roller().get_seed(), 5)
	_session.set_loot(null, 0)
	assert_true(inventory.get_ids().is_empty(), "no catalog, nothing owned")


func test_ac16_setup_again_gives_a_fresh_character() -> void:
	var before: CharacterLoot = _session.get_loot()
	_session.setup(_tower, _rules)
	assert_not_same(_session.get_loot(), before)
	assert_null(_session.get_loot().get_catalog())
	assert_true(_session.get_loot().get_inventory().get_ids().is_empty())
	assert_eq(_session.get_loot().get_roller().get_seed(), 0)


# --- AC16: what keeps the loot ---


func _assert_loot_kept(message: String) -> void:
	var inventory: Inventory = _session.get_loot().get_inventory()
	assert_eq(inventory.get_count(ItemFixtures.STARTER_ID), 1, message)
	assert_eq(inventory.get_count(_spare.id), 1, message)
	assert_eq(_equipped(), _spare.id, message)
	assert_true(_session.get_loot().is_boss_sword_taken(2), message)


func _keep_something() -> void:
	_session.get_loot().report_taken(&"fixture_boss_2_1", 2)
	_session.get_loot().get_inventory().equip(_spare.id)


func test_ac16_death_and_the_return_to_town_keep_the_loot() -> void:
	_keep_something()
	_session.enter_floor(1, false)
	_session.report_player_died()
	_assert_loot_kept("in the death pause")
	_session.tick(DELAY)
	assert_true(_session.confirm_death())
	_assert_loot_kept("back in town")


func test_ac16_leaving_a_floor_by_choice_keeps_the_loot() -> void:
	_keep_something()
	_session.enter_floor(1, false)
	assert_true(_session.leave_floor())
	_assert_loot_kept("after leave_floor")


func test_ac16_clearing_a_floor_keeps_the_loot() -> void:
	_keep_something()
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	_assert_loot_kept("on the cleared floor")
	assert_true(_session.report_floor_exited())
	_assert_loot_kept("after the exit")


func test_ac16_a_restored_session_keeps_the_loot_through_the_place_it_was_in() -> void:
	_keep_something()
	_session.enter_floor(1, false)
	var copy: TowerSession = _new_session()
	copy.set_loot(_catalog, 1)
	assert_true(copy.from_dict(_session.to_dict()))
	assert_eq(copy.get_loot().get_inventory().get_equipped_id(), _spare.id)


# --- AC17: where a sword may be changed ---


func test_ac17_in_town_a_sword_may_always_be_changed() -> void:
	assert_true(_session.can_equip(false))
	assert_true(_session.can_equip(true), "the fact passed in is ignored there")
	assert_true(_session.equip_sword(_spare.id, false))
	assert_eq(_equipped(), _spare.id)
	assert_true(_session.equip_sword(ItemFixtures.STARTER_ID, false))
	assert_eq(_equipped(), ItemFixtures.STARTER_ID)


func test_ac17_on_a_floor_only_the_fact_passed_in_decides() -> void:
	_session.enter_floor(1, false)
	assert_false(_session.can_equip(false))
	assert_true(_session.can_equip(true))
	assert_false(_session.equip_sword(_spare.id, false))
	assert_eq(_equipped(), ItemFixtures.STARTER_ID, "refused: nothing changed")
	assert_true(_session.equip_sword(_spare.id, true))
	assert_eq(_equipped(), _spare.id)


func test_ac17_in_the_death_pause_never() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	assert_false(_session.can_equip(false))
	assert_false(_session.can_equip(true))
	assert_false(_session.equip_sword(_spare.id, true))
	assert_eq(_equipped(), ItemFixtures.STARTER_ID)
	_session.tick(DELAY)
	assert_false(_session.can_equip(true), "also once it can be confirmed")


func test_ac17_never_a_sword_that_is_not_owned() -> void:
	var not_owned: StringName = &"fixture_boss_1_1"
	assert_false(_session.equip_sword(not_owned, true), "in town")
	_session.enter_floor(1, false)
	assert_false(_session.equip_sword(not_owned, true), "on a floor")
	assert_false(_session.equip_sword(&"nothing_at_all", true))
	assert_eq(_equipped(), ItemFixtures.STARTER_ID)


func test_ac17_the_sword_already_equipped_is_a_yes_where_equipping_is_allowed() -> void:
	assert_true(_session.equip_sword(ItemFixtures.STARTER_ID, false))
	_session.enter_floor(1, false)
	assert_false(_session.equip_sword(ItemFixtures.STARTER_ID, false), "not allowed there")


func test_ac17_the_cleared_room_before_the_boss_and_no_other_room_of_the_floor() -> void:
	_session.enter_floor(1, false)
	var cases: Array[Array] = [
		[0, false, false, "the first room, not cleared"],
		[0, true, false, "an earlier cleared room"],
		[1, false, false, "the room before the boss, not cleared"],
		[1, true, true, "the room before the boss, cleared"],
		[BOSS_ROOM, false, false, "the boss room"],
		[BOSS_ROOM, true, false, "the boss room, cleared"],
	]
	for case: Array in cases:
		var run: FloorRun = _run_in(case[0], case[1])
		assert_eq(_session.can_equip(run.is_pre_boss_room_cleared()), case[2], str(case[3]))
		assert_eq(
			_session.equip_sword(_spare.id, run.is_pre_boss_room_cleared()), case[2], str(case[3])
		)
		_session.equip_sword(ItemFixtures.STARTER_ID, true)  # back, for the next case


func test_ac17_a_floor_entered_at_the_boss_has_no_place_to_equip() -> void:
	_session.get_progress().mark_boss_reached(1)
	assert_true(_session.enter_floor(1, true))
	var run: FloorRun = FloorRun.new()
	run.setup(_session.get_floor_data(), RoomFixtures.rules(), 100, _session.get_start_room())
	assert_eq(run.get_room_index(), BOSS_ROOM)
	assert_false(_session.can_equip(run.is_pre_boss_room_cleared()))
	run.report_room_cleared(100)
	assert_false(_session.can_equip(run.is_pre_boss_room_cleared()), "cleared too")


# --- the snapshot ---


func test_c14_the_snapshot_holds_the_loot() -> void:
	var snapshot: Dictionary = _session.to_dict()
	assert_true(snapshot.has(TowerSession.KEY_LOOT))
	assert_eq_deep(snapshot[TowerSession.KEY_LOOT], _session.get_loot().to_dict())
	assert_eq(snapshot.keys().size(), 7)


func test_ac12_a_session_restores_its_loot_in_every_place() -> void:
	_keep_something()
	_session.get_loot().get_roller().roll_boss(PackedInt32Array([30, 20, 10]), true)
	var places: Array[Callable] = [
		func() -> void: pass,
		func() -> void: _session.enter_floor(1, false),
		func() -> void: _session.report_player_died(),
	]
	for enter: Callable in places:
		enter.call()
		var snapshot: Dictionary = _session.to_dict()
		var copy: TowerSession = _new_session()
		copy.set_loot(_catalog, 123)
		assert_true(copy.from_dict(snapshot), "place %d" % _session.get_place())
		assert_eq_deep(copy.to_dict(), snapshot)


func test_ac12_a_restored_session_draws_what_the_saved_one_draws_next() -> void:
	_session.enter_floor(1, false)
	var snapshot: Dictionary = _session.to_dict()
	var percents: PackedInt32Array = PackedInt32Array([30, 20, 10])
	var later: Array[int] = []
	for _i: int in 40:
		later.append(_session.get_loot().get_roller().roll_boss(percents, true))
	var copy: TowerSession = _new_session()
	copy.set_loot(_catalog, 1)
	assert_true(copy.from_dict(snapshot))
	var again: Array[int] = []
	for _i: int in 40:
		again.append(copy.get_loot().get_roller().roll_boss(percents, true))
	assert_eq(again, later)


func test_ac12_the_empty_state_of_a_session_without_a_catalog_round_trips() -> void:
	var bare: TowerSession = _new_session()
	var copy: TowerSession = _new_session()
	assert_true(copy.from_dict(bare.to_dict()))
	assert_eq_deep(copy.to_dict(), bare.to_dict())


func test_ac12_a_snapshot_without_the_loot_is_refused() -> void:
	var snapshot: Dictionary = _session.to_dict()
	snapshot.erase(TowerSession.KEY_LOOT)
	_assert_refused(snapshot, "no loot key")
	_assert_refused(_with_loot("loot"), "loot that is no dictionary")
	_assert_refused(_with_loot([]), "loot that is a list")


func _with_loot(value: Variant) -> Dictionary:
	var snapshot: Dictionary = _session.to_dict()
	snapshot[TowerSession.KEY_LOOT] = value
	return snapshot


## Refused, and the session and its loot are exactly as they were.
func _assert_refused(snapshot: Dictionary, message: String) -> void:
	var before: Dictionary = _session.to_dict()
	watch_signals(_session)
	assert_false(_session.from_dict(snapshot), message)
	assert_eq_deep(_session.to_dict(), before)
	assert_signal_not_emitted(_session, "place_changed", message)


func test_ac12_a_loot_state_the_character_refuses_refuses_the_whole_session() -> void:
	# A snapshot that would move the session to a cleared floor 1, with a loot that owns a sword
	# the catalog does not have: nothing of it is taken, the progress included.
	var other: TowerSession = _new_session()
	other.set_loot(_catalog, 1)
	other.enter_floor(1, false)
	other.report_floor_cleared()
	var snapshot: Dictionary = other.to_dict()
	var loot: Dictionary = snapshot[TowerSession.KEY_LOOT].duplicate(true)
	loot[CharacterLoot.KEY_INVENTORY][Inventory.KEY_OWNED].append(
		{Inventory.KEY_ID: "not_in_the_catalog", Inventory.KEY_COUNT: 1}
	)
	snapshot[TowerSession.KEY_LOOT] = loot
	_assert_refused(snapshot, "an unknown sword")
	assert_false(_session.get_progress().is_floor_cleared(1))


func test_ac12_a_snapshot_with_a_catalogs_loot_is_refused_by_a_session_without_one() -> void:
	var bare: TowerSession = _new_session()
	var before: Dictionary = bare.to_dict()
	assert_false(bare.from_dict(_session.to_dict()))
	assert_eq_deep(bare.to_dict(), before)


func test_ac12_a_good_loot_with_a_bad_place_is_refused_and_the_loot_stays() -> void:
	var snapshot: Dictionary = _session.to_dict()
	snapshot[TowerSession.KEY_FLOOR] = 3  # a floor that is locked
	snapshot[TowerSession.KEY_PLACE] = int(TowerSession.Place.FLOOR)
	var loot: Dictionary = snapshot[TowerSession.KEY_LOOT].duplicate(true)
	loot[CharacterLoot.KEY_BOSS_TAKEN] = [2]
	snapshot[TowerSession.KEY_LOOT] = loot
	_assert_refused(snapshot, "a locked floor")
	assert_false(_session.get_loot().is_boss_sword_taken(2))
