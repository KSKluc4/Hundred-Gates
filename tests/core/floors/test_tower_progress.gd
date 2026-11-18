# gdlint:disable=max-public-methods
extends GutTest
## F-012 T2 (AC6, AC7, AC8): TowerProgress unlocks floors in order, keeps what was reached, lists
## what the gate offers and round-trips through a dictionary.

var _progress: TowerProgress


func before_each() -> void:
	_progress = _new_progress(3)


# --- AC6 ---


func test_ac6_a_fresh_progress_has_only_floor_1_unlocked() -> void:
	assert_eq(_progress.get_floor_count(), 3)
	assert_true(_progress.is_floor_unlocked(1))
	assert_false(_progress.is_floor_unlocked(2))
	assert_false(_progress.is_floor_unlocked(3))
	assert_eq(_progress.get_highest_unlocked(), 1)
	for number: int in [1, 2, 3]:
		assert_false(_progress.is_floor_cleared(number), "cleared %d" % number)
		assert_false(_progress.is_boss_reached(number), "reached %d" % number)


func test_ac6_a_fresh_progress_lists_floor_1_from_the_start_only() -> void:
	var entries: Array[TowerEntry] = _progress.get_entries()
	assert_eq(_describe(entries), ["1 start"])
	assert_false(entries[0].is_cleared)


func test_ac6_a_reached_boss_adds_an_entry_after_the_start_entry() -> void:
	assert_true(_progress.mark_boss_reached(1))
	assert_true(_progress.is_boss_reached(1))
	assert_eq(_describe(_progress.get_entries()), ["1 start", "1 boss"])
	assert_false(_progress.is_floor_unlocked(2), "reaching a boss unlocks nothing")


func test_ac6_clearing_a_floor_unlocks_the_next_and_emits_once() -> void:
	_progress.mark_boss_reached(1)
	watch_signals(_progress)
	assert_true(_progress.mark_floor_cleared(1))
	assert_true(_progress.is_floor_cleared(1))
	assert_true(_progress.is_floor_unlocked(2))
	assert_false(_progress.is_floor_unlocked(3))
	assert_signal_emit_count(_progress, "floor_unlocked", 1)
	assert_signal_emitted_with_parameters(_progress, "floor_unlocked", [2])


func test_ac6_entries_after_a_clear_are_in_order_and_say_cleared() -> void:
	_progress.mark_boss_reached(1)
	_progress.mark_floor_cleared(1)
	var entries: Array[TowerEntry] = _progress.get_entries()
	assert_eq(_describe(entries), ["1 start", "1 boss", "2 start"])
	assert_true(entries[0].is_cleared)
	assert_true(entries[1].is_cleared)
	assert_false(entries[2].is_cleared)


func test_ac6_entries_run_floors_ascending_start_before_boss() -> void:
	_progress.mark_floor_cleared(1)
	_progress.mark_boss_reached(2)
	_progress.mark_floor_cleared(2)
	_progress.mark_boss_reached(3)
	assert_eq(
		_describe(_progress.get_entries()),
		["1 start", "1 boss", "2 start", "2 boss", "3 start", "3 boss"]
	)


func test_ac6_clearing_marks_the_boss_reached_too() -> void:
	assert_false(_progress.is_boss_reached(1))
	_progress.mark_floor_cleared(1)
	assert_true(_progress.is_boss_reached(1))
	assert_eq(_describe(_progress.get_entries()), ["1 start", "1 boss", "2 start"])


func test_ac6_the_highest_unlocked_floor_follows_the_clears_and_stops_at_the_top() -> void:
	_progress.mark_floor_cleared(1)
	assert_eq(_progress.get_highest_unlocked(), 2)
	_progress.mark_floor_cleared(2)
	assert_eq(_progress.get_highest_unlocked(), 3)
	_progress.mark_floor_cleared(3)
	assert_eq(_progress.get_highest_unlocked(), 3)


func test_ac6_queries_outside_1_to_count_are_false() -> void:
	for number: int in [0, -1, 4, 99]:
		assert_false(_progress.is_floor_unlocked(number), "unlocked %d" % number)
		assert_false(_progress.is_floor_cleared(number), "cleared %d" % number)
		assert_false(_progress.is_boss_reached(number), "reached %d" % number)


func test_ac6_setup_starts_over() -> void:
	_progress.mark_floor_cleared(1)
	_progress.setup(2)
	assert_eq(_progress.get_floor_count(), 2)
	assert_false(_progress.is_floor_cleared(1))
	assert_false(_progress.is_floor_unlocked(2))


func test_ac6_a_progress_with_no_floors_lists_nothing() -> void:
	var empty: TowerProgress = _new_progress(0)
	assert_eq(empty.get_entries().size(), 0)
	assert_eq(empty.get_highest_unlocked(), 0)
	assert_false(empty.is_floor_unlocked(1))


# --- AC7 ---


func test_ac7_marks_on_a_locked_or_unknown_floor_are_refused_and_change_nothing() -> void:
	var before: Dictionary = _progress.to_dict()
	watch_signals(_progress)
	for number: int in [2, 3, 0, -1, 4]:
		assert_false(_progress.mark_boss_reached(number), "boss %d" % number)
		assert_false(_progress.mark_floor_cleared(number), "clear %d" % number)
	assert_eq_deep(_progress.to_dict(), before)
	assert_signal_not_emitted(_progress, "floor_unlocked")


func test_ac7_a_second_identical_mark_returns_false_and_emits_nothing() -> void:
	assert_true(_progress.mark_boss_reached(1))
	assert_false(_progress.mark_boss_reached(1))
	assert_true(_progress.mark_floor_cleared(1))
	watch_signals(_progress)
	assert_false(_progress.mark_floor_cleared(1))
	assert_signal_not_emitted(_progress, "floor_unlocked")


func test_ac7_reaching_a_boss_after_the_clear_changes_nothing() -> void:
	_progress.mark_floor_cleared(1)
	assert_false(_progress.mark_boss_reached(1))


func test_ac7_clearing_after_reaching_still_counts_as_a_change() -> void:
	_progress.mark_boss_reached(1)
	assert_true(_progress.mark_floor_cleared(1))


func test_ac7_clearing_the_last_floor_emits_no_floor_unlocked() -> void:
	_progress.mark_floor_cleared(1)
	_progress.mark_floor_cleared(2)
	watch_signals(_progress)
	assert_true(_progress.mark_floor_cleared(3))
	assert_true(_progress.is_floor_cleared(3))
	assert_signal_not_emitted(_progress, "floor_unlocked")


func test_ac7_nothing_ever_un_clears() -> void:
	_progress.mark_floor_cleared(1)
	_progress.mark_boss_reached(1)
	_progress.mark_floor_cleared(1)
	assert_true(_progress.is_floor_cleared(1))
	assert_true(_progress.is_boss_reached(1))


# --- AC8 ---


func test_ac8_to_dict_then_from_dict_reproduces_every_query() -> void:
	_progress.mark_floor_cleared(1)
	_progress.mark_boss_reached(2)
	var fresh: TowerProgress = _new_progress(3)
	assert_true(fresh.from_dict(_progress.to_dict()))
	for number: int in [0, 1, 2, 3, 4]:
		assert_eq(
			fresh.is_floor_unlocked(number), _progress.is_floor_unlocked(number), "u%d" % number
		)
		assert_eq(
			fresh.is_floor_cleared(number), _progress.is_floor_cleared(number), "c%d" % number
		)
		assert_eq(fresh.is_boss_reached(number), _progress.is_boss_reached(number), "r%d" % number)
	assert_eq(fresh.get_highest_unlocked(), _progress.get_highest_unlocked())
	assert_eq(_describe(fresh.get_entries()), _describe(_progress.get_entries()))
	assert_eq_deep(fresh.to_dict(), _progress.to_dict())


func test_ac8_from_dict_emits_nothing() -> void:
	_progress.mark_floor_cleared(1)
	var fresh: TowerProgress = _new_progress(3)
	watch_signals(fresh)
	fresh.from_dict(_progress.to_dict())
	assert_signal_not_emitted(fresh, "floor_unlocked")


func test_ac8_the_snapshot_is_a_copy() -> void:
	var snapshot: Dictionary = _progress.to_dict()
	snapshot[TowerProgress.KEY_CLEARED][0] = true
	assert_false(_progress.is_floor_cleared(1))


func test_ac8_a_wrong_floor_count_is_refused() -> void:
	var other: TowerProgress = _new_progress(2)
	other.mark_floor_cleared(1)
	_assert_refused(other.to_dict())
	var snapshot: Dictionary = _snapshot_after_clearing(1)
	snapshot[TowerProgress.KEY_FLOOR_COUNT] = 4
	_assert_refused(snapshot)


func test_ac8_a_cleared_floor_above_an_uncleared_one_is_refused() -> void:
	var snapshot: Dictionary = _progress.to_dict()
	snapshot[TowerProgress.KEY_CLEARED] = [false, true, false]
	snapshot[TowerProgress.KEY_REACHED] = [false, true, false]
	_assert_refused(snapshot)


func test_ac8_a_boss_reached_on_a_locked_floor_is_refused() -> void:
	var snapshot: Dictionary = _progress.to_dict()
	snapshot[TowerProgress.KEY_REACHED] = [false, false, true]
	_assert_refused(snapshot)


func test_ac8_a_cleared_floor_whose_boss_is_not_reached_is_refused() -> void:
	var snapshot: Dictionary = _progress.to_dict()
	snapshot[TowerProgress.KEY_CLEARED] = [true, false, false]
	snapshot[TowerProgress.KEY_REACHED] = [false, false, false]
	_assert_refused(snapshot)


func test_ac8_the_flag_lists_must_fit_the_floor_count() -> void:
	var short: Dictionary = _progress.to_dict()
	short[TowerProgress.KEY_CLEARED] = [false, false]
	_assert_refused(short)
	var long: Dictionary = _progress.to_dict()
	long[TowerProgress.KEY_REACHED] = [false, false, false, false]
	_assert_refused(long)


func test_ac8_missing_keys_and_wrong_types_are_refused() -> void:
	_assert_refused({})
	for key: String in [
		TowerProgress.KEY_FLOOR_COUNT, TowerProgress.KEY_CLEARED, TowerProgress.KEY_REACHED
	]:
		var snapshot: Dictionary = _snapshot_after_clearing(1)
		snapshot.erase(key)
		_assert_refused(snapshot)
	var not_bool: Dictionary = _progress.to_dict()
	not_bool[TowerProgress.KEY_CLEARED] = [0, 0, 0]
	_assert_refused(not_bool)
	var not_array: Dictionary = _progress.to_dict()
	not_array[TowerProgress.KEY_REACHED] = "no"
	_assert_refused(not_array)
	var float_count: Dictionary = _progress.to_dict()
	float_count[TowerProgress.KEY_FLOOR_COUNT] = 3.0
	_assert_refused(float_count)


func test_ac8_from_dict_before_setup_is_refused() -> void:
	assert_false(TowerProgress.new().from_dict(_progress.to_dict()))


func _new_progress(floor_count: int) -> TowerProgress:
	var progress: TowerProgress = TowerProgress.new()
	progress.setup(floor_count)
	return progress


func _snapshot_after_clearing(floor_number: int) -> Dictionary:
	var progress: TowerProgress = _new_progress(3)
	progress.mark_floor_cleared(floor_number)
	return progress.to_dict()


## from_dict() says no and the state is what it was.
func _assert_refused(snapshot: Dictionary) -> void:
	_progress.mark_boss_reached(1)
	var before: Dictionary = _progress.to_dict()
	assert_false(_progress.from_dict(snapshot), str(snapshot))
	assert_eq_deep(_progress.to_dict(), before)


## "<floor> start" or "<floor> boss" for each entry, in order.
func _describe(entries: Array[TowerEntry]) -> Array[String]:
	var lines: Array[String] = []
	for entry: TowerEntry in entries:
		lines.append("%d %s" % [entry.floor_number, "boss" if entry.at_boss else "start"])
	return lines
