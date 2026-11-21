# gdlint:disable=max-public-methods
extends GutTest
## F-016 T2 (C14, C15, AC7 heal part, AC17 fact, AC18 core part): FloorRun reads the equipped
## sword's max HP and heal bonus, clamps its entry HP down and never up, and says when the room
## before the boss is cleared.

const MAX_HP: int = 100
const VITALITY_MAX_HP: int = 108

var _rules: FloorTunables
var _floor: FloorData
var _run: FloorRun


func before_each() -> void:
	_rules = RoomFixtures.rules()
	_floor = RoomFixtures.valid_floor(2)  # room_1, room_2, boss
	_run = FloorRun.new()
	_run.setup(_floor, _rules, MAX_HP)


# --- C15, AC7: the heal ---


func test_ac7_with_no_bonus_the_heal_is_what_it_was() -> void:
	assert_eq(_run.report_room_cleared(50), 30)


func test_ac7_a_bonus_is_added_to_the_fraction_and_rounded() -> void:
	_run.set_loadout_values(MAX_HP, 0.05)
	assert_eq(_run.report_room_cleared(50), 35, "30 % + 0.05 of 100")
	var boss_bonus: FloorRun = FloorRun.new()
	boss_bonus.setup(_floor, _rules, MAX_HP)
	boss_bonus.set_loadout_values(MAX_HP, 0.10)
	assert_eq(boss_bonus.report_room_cleared(50), 40)


func test_ac7_the_heal_is_a_fraction_of_the_loadouts_max_hp() -> void:
	_run.set_loadout_values(VITALITY_MAX_HP, 0.0)
	assert_eq(_run.report_room_cleared(10), 32, "0.3 of 108 is 32.4")
	var mending: FloorRun = FloorRun.new()
	mending.setup(_floor, _rules, MAX_HP)
	mending.set_loadout_values(80, 0.10)
	assert_eq(mending.report_room_cleared(10), 32, "0.4 of 80")


func test_ac7_the_heal_follows_a_changed_base_fraction() -> void:
	_rules.room_clear_heal_fraction = 0.5
	_run.setup(_floor, _rules, MAX_HP)
	_run.set_loadout_values(MAX_HP, 0.05)
	assert_eq(_run.report_room_cleared(10), 55)


func test_ac7_a_fraction_plus_bonus_above_one_never_heals_more_than_max_hp() -> void:
	_rules.room_clear_heal_fraction = 0.95
	_run.setup(_floor, _rules, MAX_HP)
	_run.set_loadout_values(MAX_HP, 0.10)
	assert_eq(_run.report_room_cleared(1), 99, "no more than the missing 99, and not 105 of 100")


func test_ac7_a_fraction_of_one_heals_to_full_and_not_above() -> void:
	_rules.room_clear_heal_fraction = 1.0
	_run.setup(_floor, _rules, MAX_HP)
	_run.set_loadout_values(MAX_HP, 0.10)
	assert_eq(_run.report_room_cleared(40), 60)
	var fuller: FloorRun = FloorRun.new()
	fuller.setup(_floor, _rules, MAX_HP)
	fuller.set_loadout_values(MAX_HP, 0.05)
	assert_eq(fuller.report_room_cleared(100), 0, "nothing missing")


func test_ac7_the_cap_on_the_fraction_is_exact_for_a_fraction_above_one() -> void:
	_rules.room_clear_heal_fraction = 1.5
	_run.setup(_floor, _rules, MAX_HP)
	assert_eq(_run.report_room_cleared(40), 60, "as before: capped by the missing HP")


func test_ac7_a_dead_player_is_still_not_healed_with_a_bonus() -> void:
	_run.set_loadout_values(MAX_HP, 0.10)
	assert_eq(_run.report_room_cleared(0), 0)
	assert_true(_run.is_room_cleared())


func test_ac7_the_boss_rooms_clear_heals_nothing_with_a_bonus() -> void:
	_run.set_loadout_values(MAX_HP, 0.10)
	_run.report_room_cleared(50)
	_run.advance(50)
	_run.report_room_cleared(50)
	_run.advance(50)
	assert_eq(_run.get_room_index(), 2)
	assert_eq(_run.report_room_cleared(50), 0, "the boss room's clear")
	assert_true(_run.is_floor_cleared())


func test_c15_setup_forgets_the_bonus_of_the_run_before() -> void:
	_run.set_loadout_values(MAX_HP, 0.10)
	_run.setup(_floor, _rules, MAX_HP)
	assert_eq(_run.report_room_cleared(50), 30)


# --- C15, AC18: the entry HP and the max ---


func test_c15_a_higher_max_hp_does_not_raise_the_entry_hp() -> void:
	_run.set_loadout_values(VITALITY_MAX_HP, 0.0)
	assert_eq(_run.get_entry_hp(), MAX_HP, "more max HP is no heal")


func test_c15_a_lower_max_hp_clamps_the_entry_hp_down() -> void:
	_run.setup(_floor, _rules, VITALITY_MAX_HP)
	assert_eq(_run.get_entry_hp(), VITALITY_MAX_HP)
	_run.set_loadout_values(MAX_HP, 0.0)
	assert_eq(_run.get_entry_hp(), MAX_HP)


func test_ac18_a_room_entered_at_105_with_vitality_off_leaves_at_most_100_and_a_good_snapshot(
) -> void:
	_run.setup(_floor, _rules, VITALITY_MAX_HP)
	_run.report_room_cleared(105)
	assert_true(_run.advance(105))
	assert_eq(_run.get_entry_hp(), 105)
	_run.report_room_cleared(105)  # the pre-boss room cleared: the place where swords change
	_run.set_loadout_values(MAX_HP, 0.0)
	assert_lte(_run.get_entry_hp(), MAX_HP)
	assert_eq(_run.get_entry_hp(), 100)
	var snapshot: Dictionary = _run.to_dict()
	var copy: FloorRun = FloorRun.new()
	copy.setup(_floor, _rules, MAX_HP)
	assert_true(copy.from_dict(snapshot), "its own snapshot is accepted back")
	assert_eq(copy.get_entry_hp(), 100)


func test_ac18_without_the_clamp_the_old_entry_hp_would_have_been_refused() -> void:
	# The reason for the clamp: a snapshot of 105 against a max of 100 is refused by from_dict().
	var snapshot: Dictionary = _run.to_dict()
	snapshot[FloorRun.KEY_ENTRY_HP] = 105
	assert_false(_run.from_dict(snapshot))


func test_c15_an_entry_hp_below_the_new_max_is_left_alone() -> void:
	_run.setup(_floor, _rules, VITALITY_MAX_HP)
	_run.report_room_cleared(50)
	_run.advance(50)
	assert_eq(_run.get_entry_hp(), 50)
	_run.set_loadout_values(MAX_HP, 0.0)
	assert_eq(_run.get_entry_hp(), 50)
	_run.set_loadout_values(VITALITY_MAX_HP, 0.0)
	assert_eq(_run.get_entry_hp(), 50, "and not raised again")


func test_c15_the_boss_rooms_full_heal_uses_the_current_max_hp() -> void:
	_run.set_loadout_values(VITALITY_MAX_HP, 0.0)
	_run.report_room_cleared(60)
	_run.advance(60)
	_run.report_room_cleared(60)
	assert_true(_run.advance(60))
	assert_true(_run.get_room().is_boss_room)
	assert_eq(_run.get_entry_hp(), VITALITY_MAX_HP, "the loadout's, not setup()'s")
	_run.set_loadout_values(MAX_HP, 0.0)
	assert_eq(_run.get_entry_hp(), MAX_HP)


func test_c15_a_boss_room_entered_after_the_sword_came_off_is_entered_at_the_lower_max() -> void:
	_run.setup(_floor, _rules, VITALITY_MAX_HP)
	_run.report_room_cleared(90)
	_run.advance(90)
	_run.report_room_cleared(90)
	_run.set_loadout_values(MAX_HP, 0.0)  # switched in the cleared room before the boss
	assert_true(_run.advance(90))
	assert_eq(_run.get_entry_hp(), MAX_HP)


func test_c15_restarting_a_room_returns_to_the_current_max_hp() -> void:
	_run.set_loadout_values(VITALITY_MAX_HP, 0.0)
	_run.restart_room()
	assert_eq(_run.get_entry_hp(), VITALITY_MAX_HP)


func test_c15_an_advance_clamps_what_the_player_carries_to_the_current_max() -> void:
	_run.set_loadout_values(80, 0.0)
	_run.report_room_cleared(50)
	assert_true(_run.advance(95))
	assert_eq(_run.get_entry_hp(), 80)


func test_c15_the_loadout_values_are_not_in_the_snapshot() -> void:
	_run.set_loadout_values(VITALITY_MAX_HP, 0.10)
	var snapshot: Dictionary = _run.to_dict()
	assert_eq(snapshot.keys().size(), 5)
	for key: String in [
		FloorRun.KEY_FLOOR_NUMBER,
		FloorRun.KEY_ROOM_INDEX,
		FloorRun.KEY_ENTRY_HP,
		FloorRun.KEY_ROOM_CLEARED,
		FloorRun.KEY_FLOOR_CLEARED,
	]:
		assert_true(snapshot.has(key), key)


func test_c15_from_dict_accepts_an_entry_hp_up_to_the_loadouts_max() -> void:
	_run.set_loadout_values(VITALITY_MAX_HP, 0.0)
	var snapshot: Dictionary = _run.to_dict()
	snapshot[FloorRun.KEY_ENTRY_HP] = 105
	assert_true(_run.from_dict(snapshot))
	assert_eq(_run.get_entry_hp(), 105)


# --- C14: the room before the boss ---


func test_c14_before_setup_there_is_no_such_room() -> void:
	assert_false(FloorRun.new().is_pre_boss_room_cleared())


func test_c14_only_the_cleared_room_before_the_boss_room_counts() -> void:
	assert_false(_run.is_pre_boss_room_cleared(), "room 0, not cleared")
	_run.report_room_cleared(100)
	assert_false(_run.is_pre_boss_room_cleared(), "room 0, cleared: an earlier room")
	_run.advance(100)
	assert_false(_run.is_pre_boss_room_cleared(), "room 1, not cleared")
	_run.report_room_cleared(100)
	assert_true(_run.is_pre_boss_room_cleared(), "room 1, cleared")
	_run.advance(100)
	assert_false(_run.is_pre_boss_room_cleared(), "the boss room, not cleared")
	_run.report_room_cleared(100)
	assert_false(_run.is_pre_boss_room_cleared(), "the boss room, cleared")


func test_c14_a_floor_entered_at_the_boss_never_has_it() -> void:
	_run.setup(_floor, _rules, MAX_HP, 2)
	assert_false(_run.is_pre_boss_room_cleared())
	_run.report_room_cleared(100)
	assert_false(_run.is_pre_boss_room_cleared())


func test_c14_a_floor_of_one_combat_room_has_it_in_that_room() -> void:
	_run.setup(RoomFixtures.valid_floor(1), _rules, MAX_HP)
	assert_false(_run.is_pre_boss_room_cleared())
	_run.report_room_cleared(100)
	assert_true(_run.is_pre_boss_room_cleared(), "the only room before the boss")


func test_c14_a_restored_cleared_room_before_the_boss_counts() -> void:
	_run.report_room_cleared(100)
	_run.advance(100)
	_run.report_room_cleared(100)
	var snapshot: Dictionary = _run.to_dict()
	var copy: FloorRun = FloorRun.new()
	copy.setup(_floor, _rules, MAX_HP)
	assert_true(copy.from_dict(snapshot))
	assert_true(copy.is_pre_boss_room_cleared())


func test_c14_restarting_the_room_after_a_death_makes_it_uncleared_again() -> void:
	_run.report_room_cleared(100)
	_run.advance(100)
	_run.report_room_cleared(100)
	_run.restart_room()
	assert_false(_run.is_pre_boss_room_cleared())
