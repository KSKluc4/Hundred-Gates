# gdlint:disable=max-public-methods
extends GutTest
## F-011 T4 (AC13-AC15): FloorRun carries room index and HP between rooms and applies C12.

const MAX_HP: int = 100

var _rules: FloorTunables
var _floor: FloorData
var _run: FloorRun


func before_each() -> void:
	_rules = RoomFixtures.rules()
	_floor = RoomFixtures.valid_floor(2)  # room_1, room_2, boss
	_run = _new_run()


func test_setup_starts_in_the_first_room_at_full_hp() -> void:
	assert_eq(_run.get_room_index(), 0)
	assert_eq(_run.get_room(), _floor.rooms[0])
	assert_eq(_run.get_entry_hp(), MAX_HP)
	assert_false(_run.is_room_cleared())
	assert_false(_run.is_floor_cleared())


func test_setup_can_start_in_the_boss_room_and_clamps_a_bad_start() -> void:
	_run.setup(_floor, _rules, MAX_HP, 2)
	assert_eq(_run.get_room_index(), 2)
	assert_true(_run.get_room().is_boss_room)
	_run.setup(_floor, _rules, MAX_HP, 9)
	assert_eq(_run.get_room_index(), 2)
	_run.setup(_floor, _rules, MAX_HP, -3)
	assert_eq(_run.get_room_index(), 0)


# --- AC13 ---


func test_ac13_clearing_a_room_heals_the_fraction_once() -> void:
	assert_eq(_run.report_room_cleared(50), 30)
	assert_true(_run.is_room_cleared())
	assert_eq(_run.report_room_cleared(50), 0, "a second report heals nothing")


func test_ac13_room_cleared_is_emitted_once_with_the_room_index() -> void:
	watch_signals(_run)
	_run.report_room_cleared(50)
	_run.report_room_cleared(50)
	assert_signal_emit_count(_run, "room_cleared", 1)
	assert_signal_emitted_with_parameters(_run, "room_cleared", [0])


func test_ac13_heal_is_the_rounded_fraction_of_max_hp() -> void:
	_rules.room_clear_heal_fraction = 0.25
	_run.setup(_floor, _rules, 50)
	assert_eq(_run.report_room_cleared(1), 13, "12.5 rounds up")


func test_ac13_heal_is_capped_so_hp_never_passes_max() -> void:
	assert_eq(_run.report_room_cleared(90), 10)


func test_ac13_a_dead_player_is_not_healed_but_the_room_still_clears() -> void:
	assert_eq(_run.report_room_cleared(0), 0)
	assert_true(_run.is_room_cleared())


func test_ac13_advance_is_refused_before_the_clear() -> void:
	assert_false(_run.advance(80))
	assert_eq(_run.get_room_index(), 0)


func test_ac13_advance_moves_on_and_carries_hp() -> void:
	_run.report_room_cleared(50)
	assert_true(_run.advance(80))
	assert_eq(_run.get_room_index(), 1)
	assert_eq(_run.get_room(), _floor.rooms[1])
	assert_eq(_run.get_entry_hp(), 80)
	assert_false(_run.is_room_cleared(), "the new room starts locked")


func test_ac13_entering_the_boss_room_gives_max_hp() -> void:
	_to_room(1)
	_run.report_room_cleared(40)
	assert_true(_run.advance(70))
	assert_true(_run.get_room().is_boss_room)
	assert_eq(_run.get_entry_hp(), MAX_HP)


func test_ac13_boss_full_heal_can_be_switched_off() -> void:
	_rules.boss_room_full_heal = false
	_to_room(1)
	_run.report_room_cleared(40)
	_run.advance(70)
	assert_eq(_run.get_entry_hp(), 70)


func test_ac13_advance_is_refused_on_the_last_room() -> void:
	_to_room(2)
	_run.report_room_cleared(100)
	assert_false(_run.advance(100))
	assert_eq(_run.get_room_index(), 2)


func test_ac13_clearing_the_boss_room_heals_nothing_and_clears_the_floor_once() -> void:
	_to_room(2)
	watch_signals(_run)
	assert_eq(_run.report_room_cleared(40), 0)
	assert_eq(_run.report_room_cleared(40), 0)
	assert_true(_run.is_floor_cleared())
	assert_signal_emit_count(_run, "floor_cleared", 1)
	assert_signal_emitted_with_parameters(_run, "floor_cleared", [1])


func test_ac13_a_combat_room_clear_does_not_clear_the_floor() -> void:
	watch_signals(_run)
	_run.report_room_cleared(50)
	assert_false(_run.is_floor_cleared())
	assert_signal_not_emitted(_run, "floor_cleared")


func test_restart_room_resets_the_clear_and_gives_max_hp() -> void:
	_run.report_room_cleared(50)
	_run.advance(80)
	_run.restart_room()
	assert_eq(_run.get_room_index(), 1, "same room")
	assert_eq(_run.get_entry_hp(), MAX_HP)
	assert_false(_run.is_room_cleared())


func test_restart_after_the_boss_does_not_announce_the_floor_twice() -> void:
	_to_room(2)
	_run.report_room_cleared(100)
	_run.restart_room()
	watch_signals(_run)
	_run.report_room_cleared(100)
	assert_signal_not_emitted(_run, "floor_cleared")


# --- AC14 ---


func test_ac14_exit_is_never_reached_before_the_clear() -> void:
	assert_false(_run.is_exit_reached(Vector2(11.5, 3.5)))
	assert_false(_run.is_exit_reached(Vector2(11.5, 4.5)))
	assert_false(_run.is_exit_reached(Vector2(5.5, 3.5)))


func test_ac14_after_the_clear_only_exit_tiles_count() -> void:
	_run.report_room_cleared(100)
	assert_true(_run.is_exit_reached(Vector2(11.5, 3.5)))
	assert_true(_run.is_exit_reached(Vector2(11.0, 4.99)), "tile edges belong to the tile")
	assert_false(_run.is_exit_reached(Vector2(10.99, 3.5)), "one step short")
	assert_false(_run.is_exit_reached(Vector2(11.5, 2.99)))
	assert_false(_run.is_exit_reached(Vector2(5.5, 3.5)))
	assert_false(_run.is_exit_reached(Vector2(-0.5, 3.5)), "outside the room")


func test_ac14_the_exit_follows_the_current_room() -> void:
	# Room 2 has its exit on the top side, at (5, 0) and (6, 0), and walls where room 1's was.
	var rows: PackedStringArray = RoomFixtures.valid_rows()
	rows = RoomFixtures.with_tile(rows, 11, 3, "#")
	rows = RoomFixtures.with_tile(rows, 11, 4, "#")
	rows = RoomFixtures.with_tile(rows, 5, 0, "E")
	rows = RoomFixtures.with_tile(rows, 6, 0, "E")
	_floor.rooms[1] = RoomFixtures.room(&"room_2", rows)
	_run.setup(_floor, _rules, MAX_HP)
	_run.report_room_cleared(100)
	_run.advance(100)
	_run.report_room_cleared(100)
	assert_false(_run.is_exit_reached(Vector2(11.5, 3.5)), "room 1's exit is gone")
	assert_true(_run.is_exit_reached(Vector2(5.5, 0.5)))


# --- AC15 ---


func test_ac15_to_dict_then_from_dict_reproduces_the_state() -> void:
	_run.report_room_cleared(50)
	_run.advance(80)
	_run.report_room_cleared(80)
	var snapshot: Dictionary = _run.to_dict()
	var fresh: FloorRun = _new_run()
	assert_true(fresh.from_dict(snapshot))
	assert_eq(fresh.get_room_index(), 1)
	assert_eq(fresh.get_entry_hp(), 80)
	assert_true(fresh.is_room_cleared())
	assert_false(fresh.is_floor_cleared())
	assert_eq_deep(fresh.to_dict(), snapshot)
	assert_true(fresh.is_exit_reached(Vector2(11.5, 3.5)), "the restored room knows its exit")


func test_ac15_the_floor_cleared_flag_is_restored() -> void:
	_to_room(2)
	_run.report_room_cleared(100)
	var fresh: FloorRun = _new_run()
	assert_true(fresh.from_dict(_run.to_dict()))
	assert_true(fresh.is_floor_cleared())
	assert_eq(fresh.get_room_index(), 2)


func test_ac15_an_out_of_range_room_index_is_refused_and_changes_nothing() -> void:
	_run.report_room_cleared(50)
	_run.advance(80)
	var before: Dictionary = _run.to_dict()
	for bad_index: int in [3, 99, -1]:
		var snapshot: Dictionary = before.duplicate()
		snapshot["room_index"] = bad_index
		assert_false(_run.from_dict(snapshot), "index %d" % bad_index)
		assert_eq_deep(_run.to_dict(), before)


func test_ac15_other_unfit_snapshots_are_refused_too() -> void:
	var before: Dictionary = _run.to_dict()
	var too_much_hp: Dictionary = before.duplicate()
	too_much_hp["entry_hp"] = MAX_HP + 1
	var negative_hp: Dictionary = before.duplicate()
	negative_hp["entry_hp"] = -1
	var missing_key: Dictionary = before.duplicate()
	missing_key.erase("room_cleared")
	var wrong_type: Dictionary = before.duplicate()
	wrong_type["room_index"] = "1"
	for snapshot: Dictionary in [too_much_hp, negative_hp, missing_key, wrong_type, {}]:
		assert_false(_run.from_dict(snapshot), str(snapshot))
	assert_eq_deep(_run.to_dict(), before)


func test_ac15_from_dict_before_setup_is_refused() -> void:
	assert_false(FloorRun.new().from_dict(_run.to_dict()))


func _new_run() -> FloorRun:
	var run: FloorRun = FloorRun.new()
	run.setup(_floor, _rules, MAX_HP)
	return run


## Walks to room `index`, clearing each room on the way with full HP.
func _to_room(index: int) -> void:
	while _run.get_room_index() < index:
		_run.report_room_cleared(MAX_HP)
		_run.advance(MAX_HP)
