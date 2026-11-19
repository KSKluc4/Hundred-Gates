# gdlint:disable=max-public-methods
extends GutTest
## F-012 T2 (AC9-AC13): TowerSession decides where the character is: town, floor, death pause.

const DELAY: float = 1.5
## Three rooms per floor: room 0 and 1 are combat rooms, room 2 is the boss room.
const ROOMS_PER_FLOOR: int = 3
const BOSS_ROOM: int = 2

var _tower: TowerData
var _rules: TowerTunables
var _session: TowerSession


func before_each() -> void:
	_tower = TowerFixtures.tower_of(3, ROOMS_PER_FLOOR - 1)
	_rules = TowerFixtures.tower_rules()
	_rules.death_return_delay = DELAY
	_session = _new_session()


# --- AC9 ---


func test_ac9_a_session_starts_in_the_town_with_fresh_progress() -> void:
	assert_eq(_session.get_place(), TowerSession.Place.TOWN)
	assert_eq(_session.get_floor_number(), 0)
	assert_eq(_session.get_start_room(), 0)
	assert_null(_session.get_floor_data())
	assert_eq(_session.get_death_time_left(), 0.0)
	assert_eq(_session.get_progress().get_floor_count(), 3)
	assert_eq(_session.get_progress().get_highest_unlocked(), 1)


func test_ac9_setup_gives_a_new_progress_each_time() -> void:
	var first: TowerProgress = _session.get_progress()
	first.mark_floor_cleared(1)
	_session.setup(_tower, _rules)
	assert_ne(_session.get_progress(), first)
	assert_false(_session.get_progress().is_floor_cleared(1))


func test_ac9_enter_floor_from_the_start_sets_floor_number_start_room_and_data() -> void:
	watch_signals(_session)
	assert_true(_session.enter_floor(1, false))
	assert_eq(_session.get_place(), TowerSession.Place.FLOOR)
	assert_eq(_session.get_floor_number(), 1)
	assert_eq(_session.get_start_room(), 0)
	assert_eq(_session.get_floor_data(), _tower.floors[0])
	assert_signal_emit_count(_session, "place_changed", 1)
	assert_signal_emitted_with_parameters(_session, "place_changed", [TowerSession.Place.FLOOR])


func test_ac9_enter_floor_at_the_boss_starts_in_the_last_room() -> void:
	_session.get_progress().mark_boss_reached(1)
	assert_true(_session.enter_floor(1, true))
	assert_eq(_session.get_start_room(), BOSS_ROOM)
	assert_true(_session.get_floor_data().rooms[_session.get_start_room()].is_boss_room)


func test_ac9_a_later_floor_can_be_entered_once_unlocked() -> void:
	_session.get_progress().mark_floor_cleared(1)
	assert_true(_session.enter_floor(2, false))
	assert_eq(_session.get_floor_number(), 2)
	assert_eq(_session.get_floor_data(), _tower.floors[1])


func test_ac9_a_locked_floor_is_refused() -> void:
	watch_signals(_session)
	assert_false(_session.enter_floor(2, false))
	assert_false(_session.enter_floor(3, false))
	_assert_still_in_town()
	assert_signal_not_emitted(_session, "place_changed")


func test_ac9_a_floor_outside_the_tower_is_refused() -> void:
	for number: int in [0, -1, 4, 99]:
		assert_false(_session.enter_floor(number, false), "floor %d" % number)
		assert_false(_session.enter_floor(number, true), "floor %d at the boss" % number)
	_assert_still_in_town()


func test_ac9_at_the_boss_is_refused_until_that_boss_was_reached() -> void:
	assert_false(_session.enter_floor(1, true))
	_assert_still_in_town()
	_session.get_progress().mark_floor_cleared(1)
	assert_false(_session.enter_floor(2, true), "floor 2's boss is not reached")
	_assert_still_in_town()
	assert_true(_session.enter_floor(1, true), "floor 1's is, cleared floors count")


func test_ac9_a_call_while_already_on_a_floor_is_refused() -> void:
	_session.get_progress().mark_floor_cleared(1)
	_session.enter_floor(1, false)
	watch_signals(_session)
	assert_false(_session.enter_floor(2, false))
	assert_false(_session.enter_floor(1, false))
	assert_eq(_session.get_floor_number(), 1)
	assert_signal_not_emitted(_session, "place_changed")


func test_ac9_a_call_during_the_death_pause_is_refused() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	assert_false(_session.enter_floor(1, false))
	assert_eq(_session.get_place(), TowerSession.Place.DEATH_PAUSE)


func test_ac9_enter_floor_before_setup_is_refused() -> void:
	assert_false(TowerSession.new().enter_floor(1, false))


# --- AC10 ---


func test_ac10_entering_the_boss_room_marks_it_reached() -> void:
	_session.enter_floor(1, false)
	_session.report_room_entered(0)
	_session.report_room_entered(1)
	assert_false(_session.get_progress().is_boss_reached(1))
	_session.report_room_entered(BOSS_ROOM)
	assert_true(_session.get_progress().is_boss_reached(1))
	assert_false(_session.get_progress().is_floor_cleared(1), "reached is not cleared")


func test_ac10_a_room_index_outside_the_floor_is_ignored() -> void:
	_session.enter_floor(1, false)
	for index: int in [-1, ROOMS_PER_FLOOR, 99]:
		_session.report_room_entered(index)
	assert_false(_session.get_progress().is_boss_reached(1))


func test_ac10_a_room_report_only_counts_on_a_floor() -> void:
	_session.report_room_entered(BOSS_ROOM)
	assert_false(_session.get_progress().is_boss_reached(1), "in the town")
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.report_room_entered(BOSS_ROOM)
	assert_false(_session.get_progress().is_boss_reached(1), "in the death pause")


func test_ac10_the_boss_room_of_the_current_floor_is_the_one_marked() -> void:
	_session.get_progress().mark_floor_cleared(1)
	_session.enter_floor(2, false)
	_session.report_room_entered(BOSS_ROOM)
	assert_true(_session.get_progress().is_boss_reached(2))
	assert_false(_session.get_progress().is_boss_reached(3))


func test_ac10_clearing_a_floor_unlocks_the_next_and_says_so() -> void:
	_session.enter_floor(1, false)
	watch_signals(_session)
	_session.report_floor_cleared()
	assert_true(_session.get_progress().is_floor_cleared(1))
	assert_true(_session.get_progress().is_floor_unlocked(2))
	assert_signal_emit_count(_session, "floor_cleared", 1)
	assert_signal_emitted_with_parameters(_session, "floor_cleared", [1, 2])


func test_ac10_clearing_a_floor_again_unlocks_nothing_new() -> void:
	_clear_floor(1)
	_session.enter_floor(1, false)
	watch_signals(_session)
	_session.report_floor_cleared()
	assert_signal_emit_count(_session, "floor_cleared", 1)
	assert_signal_emitted_with_parameters(_session, "floor_cleared", [1, 0])


func test_ac10_clearing_the_last_floor_unlocks_nothing() -> void:
	_clear_floor(1)
	_clear_floor(2)
	_session.enter_floor(3, false)
	watch_signals(_session)
	_session.report_floor_cleared()
	assert_true(_session.get_progress().is_floor_cleared(3))
	assert_signal_emitted_with_parameters(_session, "floor_cleared", [3, 0])


func test_ac10_a_second_clear_in_the_same_visit_does_nothing() -> void:
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	watch_signals(_session)
	_session.report_floor_cleared()
	assert_signal_not_emitted(_session, "floor_cleared")


func test_ac10_the_clear_flag_starts_over_with_each_visit() -> void:
	_clear_floor(1)
	_session.enter_floor(1, false)
	assert_false(_session.report_floor_exited(), "not cleared in this visit yet")
	watch_signals(_session)
	_session.report_floor_cleared()
	assert_signal_emit_count(_session, "floor_cleared", 1)


func test_ac10_a_clear_report_in_the_town_or_the_pause_does_nothing() -> void:
	watch_signals(_session)
	_session.report_floor_cleared()
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.report_floor_cleared()
	assert_signal_not_emitted(_session, "floor_cleared")
	assert_false(_session.get_progress().is_floor_cleared(1))


func test_ac10_clearing_marks_the_boss_reached_even_without_a_room_report() -> void:
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	assert_true(_session.get_progress().is_boss_reached(1))


# --- AC11 ---


func test_ac11_exit_is_refused_before_the_floor_is_cleared_in_this_visit() -> void:
	_session.enter_floor(1, false)
	watch_signals(_session)
	assert_false(_session.report_floor_exited())
	assert_eq(_session.get_place(), TowerSession.Place.FLOOR)
	assert_signal_not_emitted(_session, "place_changed")


func test_ac11_exit_after_the_clear_goes_to_the_town() -> void:
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	watch_signals(_session)
	assert_true(_session.report_floor_exited())
	_assert_still_in_town()
	assert_signal_emit_count(_session, "place_changed", 1)
	assert_signal_emitted_with_parameters(_session, "place_changed", [TowerSession.Place.TOWN])


func test_ac11_a_second_exit_report_is_refused() -> void:
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	_session.report_floor_exited()
	watch_signals(_session)
	assert_false(_session.report_floor_exited())
	assert_signal_not_emitted(_session, "place_changed")


func test_ac11_reports_in_the_town_change_nothing() -> void:
	watch_signals(_session)
	assert_false(_session.report_floor_exited())
	_session.report_player_died()
	_session.report_room_entered(BOSS_ROOM)
	_session.report_floor_cleared()
	_assert_still_in_town()
	assert_signal_not_emitted(_session, "place_changed")
	assert_signal_not_emitted(_session, "floor_cleared")


func test_ac11_reports_in_the_death_pause_change_nothing() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	watch_signals(_session)
	assert_false(_session.report_floor_exited())
	_session.report_floor_cleared()
	_session.report_room_entered(BOSS_ROOM)
	assert_eq(_session.get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_signal_not_emitted(_session, "place_changed")
	assert_signal_not_emitted(_session, "floor_cleared")
	assert_false(_session.get_progress().is_boss_reached(1))


func test_ac11_a_cleared_visit_followed_by_a_death_still_returns_to_town_with_progress() -> void:
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	_session.report_player_died()
	assert_false(_session.report_floor_exited(), "the pause is not a floor")
	_tick_until_town(1.0 / 60.0)
	assert_true(_session.get_progress().is_floor_cleared(1))
	assert_true(_session.get_progress().is_floor_unlocked(2))


# --- AC12 ---


func test_ac12_a_death_starts_the_pause_and_keeps_the_floor_on_show() -> void:
	_session.get_progress().mark_floor_cleared(1)
	_session.enter_floor(2, false)
	watch_signals(_session)
	_session.report_player_died()
	assert_eq(_session.get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_almost_eq(_session.get_death_time_left(), DELAY, 0.0001)
	assert_eq(_session.get_floor_number(), 2)
	assert_eq(_session.get_floor_data(), _tower.floors[1])
	assert_signal_emit_count(_session, "place_changed", 1)
	assert_signal_emitted_with_parameters(
		_session, "place_changed", [TowerSession.Place.DEATH_PAUSE]
	)


func test_ac12_ticking_reaches_the_town_within_one_step_of_the_delay() -> void:
	for steps_per_second: int in [30, 60, 120]:
		var step: float = 1.0 / steps_per_second
		_session.setup(_tower, _rules)
		_session.enter_floor(1, false)
		_session.report_player_died()
		var elapsed: float = _tick_until_town(step)
		assert_gte(elapsed, DELAY - 0.000001, "not early at %d Hz" % steps_per_second)
		assert_lte(elapsed, DELAY + step + 0.000001, "within a step at %d Hz" % steps_per_second)


func test_ac12_the_pause_counts_down_and_the_town_comes_once() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.tick(1.0)
	assert_eq(_session.get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_almost_eq(_session.get_death_time_left(), 0.5, 0.0001)
	watch_signals(_session)
	_session.tick(0.5)
	assert_eq(_session.get_place(), TowerSession.Place.TOWN)
	_session.tick(1.0)
	assert_signal_emit_count(_session, "place_changed", 1)
	assert_signal_emitted_with_parameters(_session, "place_changed", [TowerSession.Place.TOWN])


func test_ac12_after_the_pause_the_floor_is_gone_and_the_timer_is_zero() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.tick(DELAY + 1.0)
	_assert_still_in_town()


func test_ac12_a_delay_of_zero_reaches_the_town_on_the_next_tick() -> void:
	_rules.death_return_delay = 0.0
	_session.setup(_tower, _rules)
	_session.enter_floor(1, false)
	_session.report_player_died()
	assert_eq(_session.get_place(), TowerSession.Place.DEATH_PAUSE, "not inside the report")
	_session.tick(0.0)
	assert_eq(_session.get_place(), TowerSession.Place.TOWN)


func test_ac12_a_boss_reached_before_dying_is_still_reached() -> void:
	_session.enter_floor(1, false)
	_session.report_room_entered(BOSS_ROOM)
	_session.report_player_died()
	_tick_until_town(1.0 / 60.0)
	assert_true(_session.get_progress().is_boss_reached(1))
	assert_true(_session.enter_floor(1, true), "and the gate offers it")
	assert_eq(_session.get_start_room(), BOSS_ROOM)


func test_ac12_a_second_death_report_during_the_pause_does_not_restart_the_timer() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.tick(1.0)
	watch_signals(_session)
	_session.report_player_died()
	assert_almost_eq(_session.get_death_time_left(), 0.5, 0.0001)
	assert_signal_not_emitted(_session, "place_changed")


func test_ac12_a_death_report_in_the_town_does_nothing() -> void:
	watch_signals(_session)
	_session.report_player_died()
	_assert_still_in_town()
	assert_signal_not_emitted(_session, "place_changed")


func test_ac12_tick_does_nothing_outside_the_death_pause() -> void:
	_session.tick(10.0)
	_assert_still_in_town()
	_session.enter_floor(1, false)
	_session.tick(10.0)
	assert_eq(_session.get_place(), TowerSession.Place.FLOOR)
	assert_eq(_session.get_death_time_left(), 0.0)


func test_ac12_a_clear_after_the_death_in_the_same_tick_is_not_counted() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.report_floor_cleared()
	assert_false(_session.get_progress().is_floor_cleared(1))
	assert_false(_session.get_progress().is_floor_unlocked(2))


# --- AC13 ---


func test_ac13_a_town_snapshot_round_trips() -> void:
	_session.get_progress().mark_floor_cleared(1)
	_assert_round_trip(_session)


func test_ac13_a_floor_snapshot_round_trips() -> void:
	_session.get_progress().mark_floor_cleared(1)
	_session.enter_floor(2, false)
	var copy: TowerSession = _assert_round_trip(_session)
	assert_eq(copy.get_place(), TowerSession.Place.FLOOR)
	assert_eq(copy.get_floor_number(), 2)
	assert_eq(copy.get_start_room(), 0)
	assert_eq(copy.get_floor_data(), _tower.floors[1])


func test_ac13_a_boss_start_round_trips() -> void:
	_session.get_progress().mark_boss_reached(1)
	_session.enter_floor(1, true)
	var copy: TowerSession = _assert_round_trip(_session)
	assert_eq(copy.get_start_room(), BOSS_ROOM)


func test_ac13_a_death_pause_round_trips_with_the_time_left() -> void:
	_session.enter_floor(1, false)
	_session.report_room_entered(BOSS_ROOM)
	_session.report_player_died()
	_session.tick(0.4)
	var copy: TowerSession = _assert_round_trip(_session)
	assert_eq(copy.get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_almost_eq(copy.get_death_time_left(), DELAY - 0.4, 0.0001)
	assert_true(copy.get_progress().is_boss_reached(1))
	copy.tick(DELAY)
	assert_eq(copy.get_place(), TowerSession.Place.TOWN, "the restored pause runs out")


func test_ac13_the_snapshot_includes_the_progress() -> void:
	_session.get_progress().mark_floor_cleared(1)
	assert_eq_deep(_session.to_dict()[TowerSession.KEY_PROGRESS], _session.get_progress().to_dict())


func test_ac13_restoring_keeps_the_same_progress_object() -> void:
	var progress: TowerProgress = _session.get_progress()
	var source: TowerSession = _new_session()
	source.get_progress().mark_floor_cleared(1)
	assert_true(_session.from_dict(source.to_dict()))
	assert_eq(_session.get_progress(), progress)
	assert_true(progress.is_floor_cleared(1))


func test_ac13_restoring_a_different_place_says_so_once() -> void:
	_session.enter_floor(1, false)
	var floor_snapshot: Dictionary = _session.to_dict()
	var copy: TowerSession = _new_session()
	watch_signals(copy)
	assert_true(copy.from_dict(floor_snapshot))
	assert_signal_emit_count(copy, "place_changed", 1)
	assert_signal_emitted_with_parameters(copy, "place_changed", [TowerSession.Place.FLOOR])
	assert_true(copy.from_dict(floor_snapshot))
	assert_signal_emit_count(copy, "place_changed", 1, "the same place again says nothing")


func test_ac13_a_floor_cleared_this_visit_keeps_that_across_a_restore() -> void:
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	var copy: TowerSession = _assert_round_trip(_session)
	assert_true(copy.to_dict()[TowerSession.KEY_CLEARED_IN_RUN])
	watch_signals(copy)
	copy.report_floor_cleared()
	assert_signal_not_emitted(copy, "floor_cleared", "it already happened this visit")
	assert_eq(copy.get_place(), TowerSession.Place.FLOOR)
	assert_true(copy.report_floor_exited(), "the exit is open: no soft lock (G7)")
	assert_eq(copy.get_place(), TowerSession.Place.TOWN)
	assert_eq(copy.get_floor_number(), 0)


func test_ac13_a_floor_not_cleared_this_visit_stays_that_way_across_a_restore() -> void:
	_session.enter_floor(1, false)
	var copy: TowerSession = _assert_round_trip(_session)
	assert_false(copy.to_dict()[TowerSession.KEY_CLEARED_IN_RUN])
	assert_false(copy.report_floor_exited())
	copy.report_floor_cleared()
	assert_true(copy.report_floor_exited())


func test_ac13_a_replayed_cleared_floor_is_not_cleared_this_visit_until_it_is() -> void:
	# The progress says cleared (an earlier visit), the visit says not: both survive a restore.
	_clear_floor(1)
	_session.enter_floor(1, false)
	var copy: TowerSession = _assert_round_trip(_session)
	assert_true(copy.get_progress().is_floor_cleared(1))
	assert_false(copy.report_floor_exited())


func test_ac13_a_restore_replaces_a_flag_that_was_already_set() -> void:
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	assert_true(_session.from_dict(_floor_snapshot()))
	assert_false(_session.report_floor_exited(), "the snapshot says not cleared this visit")


func test_ac13_the_death_pause_saves_the_flag_as_false() -> void:
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	_session.report_player_died()
	assert_false(_session.to_dict()[TowerSession.KEY_CLEARED_IN_RUN], "true only on a floor")
	_assert_round_trip(_session)


func test_ac13_a_flag_that_is_not_a_bool_is_refused() -> void:
	for bad: Variant in [1, 0, "true", null, 1.0]:
		_assert_refused(_cleared_floor_snapshot(), TowerSession.KEY_CLEARED_IN_RUN, bad)


func test_ac13_a_cleared_flag_in_the_town_is_refused() -> void:
	_assert_refused(_session.to_dict(), TowerSession.KEY_CLEARED_IN_RUN, true)


func test_ac13_a_cleared_flag_in_the_death_pause_is_refused() -> void:
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	_session.report_player_died()
	_assert_refused(_session.to_dict(), TowerSession.KEY_CLEARED_IN_RUN, true)


func test_ac13_a_cleared_flag_on_a_floor_the_progress_says_is_not_cleared_is_refused() -> void:
	_assert_refused(_floor_snapshot(), TowerSession.KEY_CLEARED_IN_RUN, true)


func test_ac13_an_unknown_place_is_refused() -> void:
	for place: Variant in [3, -1, "floor", 1.0, null]:
		_assert_refused(_floor_snapshot(), TowerSession.KEY_PLACE, place)


func test_ac13_a_floor_out_of_range_is_refused() -> void:
	for number: int in [0, -1, 4, 99]:
		_assert_refused(_floor_snapshot(), TowerSession.KEY_FLOOR, number)


func test_ac13_a_locked_floor_is_refused() -> void:
	_assert_refused(_floor_snapshot(), TowerSession.KEY_FLOOR, 2)


func test_ac13_a_town_snapshot_with_a_floor_is_refused() -> void:
	var snapshot: Dictionary = _session.to_dict()
	_assert_refused(snapshot, TowerSession.KEY_FLOOR, 1)
	_assert_refused(snapshot, TowerSession.KEY_START_ROOM, BOSS_ROOM)


func test_ac13_a_start_room_that_is_neither_first_nor_last_is_refused() -> void:
	for index: int in [1, 3, -1, 99]:
		_assert_refused(_floor_snapshot(), TowerSession.KEY_START_ROOM, index)


func test_ac13_the_last_room_without_the_boss_reached_is_refused() -> void:
	_assert_refused(_floor_snapshot(), TowerSession.KEY_START_ROOM, BOSS_ROOM)


func test_ac13_the_last_room_with_the_boss_reached_is_accepted() -> void:
	_session.get_progress().mark_boss_reached(1)
	_session.enter_floor(1, false)
	var snapshot: Dictionary = _session.to_dict()
	snapshot[TowerSession.KEY_START_ROOM] = BOSS_ROOM
	assert_true(_new_session().from_dict(snapshot))


func test_ac13_a_time_left_outside_zero_to_the_delay_is_refused() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	var pause: Dictionary = _session.to_dict()
	for bad: float in [-0.1, DELAY + 0.1]:
		_assert_refused(pause, TowerSession.KEY_DEATH_TIME_LEFT, bad)
	_assert_refused(pause, TowerSession.KEY_DEATH_TIME_LEFT, "soon")


func test_ac13_a_time_left_outside_a_death_pause_is_refused() -> void:
	_assert_refused(_floor_snapshot(), TowerSession.KEY_DEATH_TIME_LEFT, 0.5)
	_assert_refused(_session.to_dict(), TowerSession.KEY_DEATH_TIME_LEFT, 0.5)


func test_ac13_a_progress_that_does_not_fit_is_refused() -> void:
	var wrong_count: TowerProgress = TowerProgress.new()
	wrong_count.setup(2)
	_assert_refused(_floor_snapshot(), TowerSession.KEY_PROGRESS, wrong_count.to_dict())
	var skipped: Dictionary = _floor_snapshot()[TowerSession.KEY_PROGRESS].duplicate()
	skipped[TowerProgress.KEY_CLEARED] = [false, true, false]
	_assert_refused(_floor_snapshot(), TowerSession.KEY_PROGRESS, skipped)
	_assert_refused(_floor_snapshot(), TowerSession.KEY_PROGRESS, "none")


func test_ac13_missing_keys_are_refused() -> void:
	_assert_refused({}, "", null)
	for key: String in [
		TowerSession.KEY_PLACE,
		TowerSession.KEY_FLOOR,
		TowerSession.KEY_START_ROOM,
		TowerSession.KEY_DEATH_TIME_LEFT,
		TowerSession.KEY_PROGRESS,
	]:
		var snapshot: Dictionary = _floor_snapshot()
		snapshot.erase(key)
		_assert_refused(snapshot, "", null)


func test_ac13_from_dict_before_setup_is_refused() -> void:
	assert_false(TowerSession.new().from_dict(_session.to_dict()))


func test_ac13_a_refused_snapshot_leaves_the_progress_alone_too() -> void:
	var snapshot: Dictionary = _floor_snapshot()
	var progress: Dictionary = _session.get_progress().to_dict()
	progress[TowerProgress.KEY_CLEARED] = [true, false, false]
	progress[TowerProgress.KEY_REACHED] = [true, false, false]
	snapshot[TowerSession.KEY_PROGRESS] = progress
	snapshot[TowerSession.KEY_FLOOR] = 3  # the progress is fine, the place is not
	var before: Dictionary = _session.to_dict()
	assert_false(_session.from_dict(snapshot))
	assert_eq_deep(_session.to_dict(), before)


func _new_session() -> TowerSession:
	var session: TowerSession = TowerSession.new()
	session.setup(_tower, _rules)
	return session


## Enters `floor_number` from the town, clears it and walks out: the next floor is unlocked.
func _clear_floor(floor_number: int) -> void:
	assert_true(_session.enter_floor(floor_number, false), "enter floor %d" % floor_number)
	_session.report_floor_cleared()
	assert_true(_session.report_floor_exited(), "exit floor %d" % floor_number)


func _assert_still_in_town() -> void:
	assert_eq(_session.get_place(), TowerSession.Place.TOWN)
	assert_eq(_session.get_floor_number(), 0)
	assert_eq(_session.get_start_room(), 0)
	assert_null(_session.get_floor_data())
	assert_eq(_session.get_death_time_left(), 0.0)


## Ticks `step` at a time until the town; returns the time ticked. Stops after 10 s.
func _tick_until_town(step: float) -> float:
	var elapsed: float = 0.0
	while _session.get_place() == TowerSession.Place.DEATH_PAUSE and elapsed < 10.0:
		_session.tick(step)
		elapsed += step
	assert_eq(_session.get_place(), TowerSession.Place.TOWN, "the pause ended")
	return elapsed


## A snapshot of a session on floor 1, entered from the start; floors 2 and 3 are locked.
func _floor_snapshot() -> Dictionary:
	var session: TowerSession = _new_session()
	session.enter_floor(1, false)
	return session.to_dict()


## A snapshot of a session on floor 1 that cleared it this visit.
func _cleared_floor_snapshot() -> Dictionary:
	var session: TowerSession = _new_session()
	session.enter_floor(1, false)
	session.report_floor_cleared()
	return session.to_dict()


## Restores `source`'s snapshot into a new session and checks the whole state matches.
func _assert_round_trip(source: TowerSession) -> TowerSession:
	var copy: TowerSession = _new_session()
	assert_true(copy.from_dict(source.to_dict()))
	assert_eq(copy.get_place(), source.get_place())
	assert_eq(copy.get_floor_number(), source.get_floor_number())
	assert_eq(copy.get_start_room(), source.get_start_room())
	assert_almost_eq(copy.get_death_time_left(), source.get_death_time_left(), 0.0001)
	assert_eq_deep(copy.to_dict(), source.to_dict())
	return copy


## from_dict() with `key` set to `value` says no and changes nothing (key "" = as given).
func _assert_refused(base: Dictionary, key: String, value: Variant) -> void:
	var snapshot: Dictionary = base.duplicate(true)
	if not key.is_empty():
		snapshot[key] = value
	var target: TowerSession = _new_session()
	target.get_progress().mark_boss_reached(1)
	var before: Dictionary = target.to_dict()
	assert_false(target.from_dict(snapshot), "%s = %s" % [key, str(value)])
	assert_eq_deep(target.to_dict(), before)
