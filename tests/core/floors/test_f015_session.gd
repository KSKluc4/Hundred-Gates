# gdlint:disable=max-public-methods
extends GutTest
## F-015 T3 (AC3-AC5, C3, C4): the death waits for a confirmation, a floor can be left by choice,
## and the snapshot still round-trips in every place. Pure logic on a fixture tower.

const DELAY: float = 1.5
## Three rooms per floor: room 0 and 1 are combat rooms, room 2 is the boss room.
const ROOMS_PER_FLOOR: int = 3
const BOSS_ROOM: int = 2
const STEP: float = 1.0 / 60.0

var _tower: TowerData
var _rules: TowerTunables
var _session: TowerSession


func before_each() -> void:
	_tower = TowerFixtures.tower_of(3, ROOMS_PER_FLOOR - 1)
	_rules = TowerFixtures.tower_rules()
	_rules.death_return_delay = DELAY
	_session = _new_session()


# --- AC3: the death waits ---


func test_ac3_the_pause_stays_at_zero_for_any_number_of_ticks_past_the_delay() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.tick(DELAY)
	for _i: int in 600:
		_session.tick(STEP)
	_session.tick(1000.0)
	assert_eq(_session.get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_eq(_session.get_death_time_left(), 0.0, "never negative")
	assert_eq(_session.to_dict()[TowerSession.KEY_DEATH_TIME_LEFT], 0.0, "nor in the snapshot")
	assert_eq(_session.get_floor_number(), 1, "the floor is still the one shown")


func test_ac3_one_big_tick_past_the_delay_does_not_go_negative() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.tick(DELAY * 100.0)
	assert_eq(_session.get_death_time_left(), 0.0)
	assert_eq(_session.get_place(), TowerSession.Place.DEATH_PAUSE)


func test_ac3_the_time_still_counts_down_before_the_delay() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	assert_almost_eq(_session.get_death_time_left(), DELAY, 0.0001)
	_session.tick(1.0)
	assert_almost_eq(_session.get_death_time_left(), 0.5, 0.0001)


func test_ac3_can_confirm_is_false_before_the_delay_and_true_after() -> void:
	_session.enter_floor(1, false)
	assert_false(_session.can_confirm_death(), "on a floor")
	_session.report_player_died()
	assert_false(_session.can_confirm_death(), "in the tick of the death")
	_session.tick(DELAY - 0.25)
	assert_false(_session.can_confirm_death(), "just before the delay")
	_session.tick(0.25)
	assert_true(_session.can_confirm_death(), "at the delay")
	_session.tick(5.0)
	assert_true(_session.can_confirm_death(), "and it stays true")


func test_ac3_confirm_is_refused_before_the_delay_and_changes_nothing() -> void:
	_session.get_progress().mark_boss_reached(1)
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.tick(1.0)
	var before: Dictionary = _session.to_dict()
	watch_signals(_session)
	assert_false(_session.confirm_death())
	assert_eq(_session.get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_eq_deep(_session.to_dict(), before)
	assert_signal_not_emitted(_session, "place_changed")


func test_ac3_confirm_after_the_delay_goes_to_the_town_with_the_progress_as_it_was() -> void:
	_session.enter_floor(1, false)
	_session.report_room_entered(BOSS_ROOM)
	_session.report_player_died()
	var progress_before: Dictionary = _session.get_progress().to_dict()
	_session.tick(DELAY + 3.0)
	watch_signals(_session)
	assert_true(_session.confirm_death())
	assert_eq(_session.get_place(), TowerSession.Place.TOWN)
	assert_eq(_session.get_floor_number(), 0)
	assert_eq(_session.get_start_room(), 0)
	assert_eq(_session.get_death_time_left(), 0.0)
	assert_null(_session.get_floor_data())
	assert_eq_deep(_session.get_progress().to_dict(), progress_before)
	assert_true(_session.get_progress().is_boss_reached(1))
	assert_signal_emit_count(_session, "place_changed", 1)
	assert_signal_emitted_with_parameters(_session, "place_changed", [TowerSession.Place.TOWN])


func test_ac3_a_second_confirm_is_refused() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.tick(DELAY)
	_session.confirm_death()
	watch_signals(_session)
	assert_false(_session.confirm_death())
	assert_signal_not_emitted(_session, "place_changed")


func test_ac3_after_the_confirmation_the_floor_can_be_entered_again() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.tick(DELAY)
	_session.confirm_death()
	assert_true(_session.enter_floor(1, false))
	assert_eq(_session.get_place(), TowerSession.Place.FLOOR)
	assert_eq(_session.get_death_time_left(), 0.0)
	assert_false(_session.can_confirm_death())


func test_ac3_with_a_delay_of_zero_confirming_is_possible_in_the_tick_of_the_death() -> void:
	_rules.death_return_delay = 0.0
	_session.setup(_tower, _rules)
	_session.enter_floor(1, false)
	_session.report_player_died()
	assert_eq(_session.get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_true(_session.can_confirm_death(), "at once")
	assert_eq(_session.get_death_time_left(), 0.0)
	_session.tick(STEP)
	assert_eq(_session.get_place(), TowerSession.Place.DEATH_PAUSE, "a tick does not end it")
	assert_true(_session.confirm_death())
	assert_eq(_session.get_place(), TowerSession.Place.TOWN)


func test_ac3_a_negative_delay_counts_as_zero() -> void:
	_rules.death_return_delay = -2.0
	_session.setup(_tower, _rules)
	_session.enter_floor(1, false)
	_session.report_player_died()
	assert_eq(_session.get_death_time_left(), 0.0)
	assert_true(_session.can_confirm_death())


func test_ac3_confirm_is_refused_in_the_town_and_on_a_floor() -> void:
	watch_signals(_session)
	assert_false(_session.can_confirm_death())
	assert_false(_session.confirm_death(), "in the town")
	_session.enter_floor(1, false)
	_session.tick(DELAY * 10.0)
	assert_false(_session.can_confirm_death())
	assert_false(_session.confirm_death(), "on a floor")
	assert_eq(_session.get_place(), TowerSession.Place.FLOOR)
	assert_signal_emit_count(_session, "place_changed", 1, "only the entering")


func test_ac3_a_confirm_before_setup_is_refused() -> void:
	var bare: TowerSession = TowerSession.new()
	assert_false(bare.can_confirm_death())
	assert_false(bare.confirm_death())
	assert_false(bare.leave_floor())


func test_ac3_everything_else_of_the_death_rule_holds_in_the_pause() -> void:
	# F-012/C5: reports during the pause change nothing, a death and a clear in one tick is a death.
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.report_floor_cleared()
	_session.report_room_entered(BOSS_ROOM)
	_session.tick(DELAY + 1.0)
	_session.report_player_died()
	assert_eq(_session.get_death_time_left(), 0.0, "a second report does not restart the count")
	assert_false(_session.report_floor_exited())
	assert_false(_session.enter_floor(1, false))
	assert_false(_session.leave_floor())
	assert_false(_session.get_progress().is_floor_cleared(1))
	assert_false(_session.get_progress().is_boss_reached(1))
	assert_eq(_session.get_place(), TowerSession.Place.DEATH_PAUSE)


# --- AC4: leaving a floor by choice ---


func test_ac4_leaving_from_a_floor_goes_to_the_town() -> void:
	_session.enter_floor(1, false)
	watch_signals(_session)
	assert_true(_session.leave_floor())
	assert_eq(_session.get_place(), TowerSession.Place.TOWN)
	assert_eq(_session.get_floor_number(), 0)
	assert_eq(_session.get_start_room(), 0)
	assert_null(_session.get_floor_data())
	assert_eq(_session.get_death_time_left(), 0.0)
	assert_signal_emit_count(_session, "place_changed", 1)
	assert_signal_emitted_with_parameters(_session, "place_changed", [TowerSession.Place.TOWN])


func test_ac4_a_boss_room_entered_during_the_visit_stays_marked() -> void:
	_session.enter_floor(1, false)
	_session.report_room_entered(BOSS_ROOM)
	assert_true(_session.leave_floor())
	assert_true(_session.get_progress().is_boss_reached(1))
	assert_false(_session.get_progress().is_floor_cleared(1), "reached is not cleared")
	assert_true(_session.enter_floor(1, true), "the gate offers it at the boss")
	assert_eq(_session.get_start_room(), BOSS_ROOM)


func test_ac4_a_floor_cleared_during_the_visit_stays_cleared() -> void:
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	assert_true(_session.leave_floor())
	assert_true(_session.get_progress().is_floor_cleared(1))
	assert_true(_session.get_progress().is_floor_unlocked(2))
	assert_true(_session.enter_floor(2, false))


func test_ac4_it_changes_no_progress_at_all() -> void:
	_session.get_progress().mark_floor_cleared(1)
	_session.get_progress().mark_boss_reached(2)
	_session.enter_floor(2, false)
	var before: Dictionary = _session.get_progress().to_dict()
	assert_true(_session.leave_floor())
	assert_eq_deep(_session.get_progress().to_dict(), before)


func test_ac4_it_is_refused_in_the_town() -> void:
	watch_signals(_session)
	assert_false(_session.leave_floor())
	assert_eq(_session.get_place(), TowerSession.Place.TOWN)
	assert_signal_not_emitted(_session, "place_changed")


func test_ac4_it_is_refused_in_the_death_pause_before_and_after_the_delay() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	watch_signals(_session)
	assert_false(_session.leave_floor(), "time left")
	_session.tick(DELAY + 1.0)
	assert_false(_session.leave_floor(), "no time left")
	assert_eq(_session.get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_eq(_session.get_floor_number(), 1)
	assert_signal_not_emitted(_session, "place_changed")


func test_ac4_a_second_call_is_refused() -> void:
	_session.enter_floor(1, false)
	_session.leave_floor()
	watch_signals(_session)
	assert_false(_session.leave_floor())
	assert_signal_not_emitted(_session, "place_changed")


func test_ac4_entering_again_starts_the_floor_at_room_zero() -> void:
	_session.enter_floor(1, false)
	_session.report_room_entered(1)
	_session.leave_floor()
	assert_true(_session.enter_floor(1, false))
	assert_eq(_session.get_place(), TowerSession.Place.FLOOR)
	assert_eq(_session.get_floor_number(), 1)
	assert_eq(_session.get_start_room(), 0)


func test_ac4_the_clear_flag_of_the_visit_does_not_follow_the_character_out() -> void:
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	_session.leave_floor()
	_session.enter_floor(1, false)
	assert_false(_session.report_floor_exited(), "a new visit, not cleared yet")
	watch_signals(_session)
	_session.report_floor_cleared()
	assert_signal_emit_count(_session, "floor_cleared", 1, "and it can be cleared again")


func test_ac4_the_exit_after_a_clear_still_works_as_before() -> void:
	_session.enter_floor(1, false)
	_session.report_floor_cleared()
	assert_true(_session.report_floor_exited())
	assert_eq(_session.get_place(), TowerSession.Place.TOWN)
	assert_false(_session.report_floor_exited())


func test_ac4_the_exit_is_still_refused_before_the_clear() -> void:
	_session.enter_floor(1, false)
	assert_false(_session.report_floor_exited())
	assert_eq(_session.get_place(), TowerSession.Place.FLOOR)


# --- AC5: the snapshot, in every place ---


func test_ac5_a_town_snapshot_round_trips() -> void:
	_session.get_progress().mark_floor_cleared(1)
	_assert_round_trip(_session)


func test_ac5_a_floor_snapshot_round_trips() -> void:
	_session.enter_floor(1, false)
	_assert_round_trip(_session)


func test_ac5_a_floor_at_the_boss_round_trips() -> void:
	_session.get_progress().mark_boss_reached(1)
	_session.enter_floor(1, true)
	_assert_round_trip(_session)


func test_ac5_a_death_pause_with_time_left_round_trips() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.tick(0.4)
	var copy: TowerSession = _assert_round_trip(_session)
	assert_almost_eq(copy.get_death_time_left(), DELAY - 0.4, 0.0001)
	assert_false(copy.can_confirm_death())
	assert_false(copy.confirm_death())


func test_ac5_a_death_pause_with_the_delay_untouched_round_trips() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	var copy: TowerSession = _assert_round_trip(_session)
	assert_almost_eq(copy.get_death_time_left(), DELAY, 0.0001)


func test_ac5_a_death_pause_with_no_time_left_round_trips_and_can_be_confirmed() -> void:
	_session.enter_floor(1, false)
	_session.report_room_entered(BOSS_ROOM)
	_session.report_player_died()
	_session.tick(DELAY + 10.0)
	var snapshot: Dictionary = _session.to_dict()
	assert_eq(snapshot[TowerSession.KEY_DEATH_TIME_LEFT], 0.0)
	var copy: TowerSession = _assert_round_trip(_session)
	assert_eq(copy.get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_eq(copy.get_death_time_left(), 0.0)
	assert_true(copy.can_confirm_death())
	watch_signals(copy)
	assert_true(copy.confirm_death())
	assert_eq(copy.get_place(), TowerSession.Place.TOWN)
	assert_true(copy.get_progress().is_boss_reached(1), "the progress came along")
	assert_signal_emit_count(copy, "place_changed", 1)


func test_ac5_restoring_into_the_death_pause_with_no_time_left_says_so_once() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.tick(DELAY)
	var copy: TowerSession = _new_session()
	watch_signals(copy)
	assert_true(copy.from_dict(_session.to_dict()))
	assert_signal_emit_count(copy, "place_changed", 1)
	assert_signal_emitted_with_parameters(copy, "place_changed", [TowerSession.Place.DEATH_PAUSE])
	assert_true(copy.can_confirm_death())


func test_ac5_a_pause_with_a_delay_of_zero_round_trips_and_can_be_confirmed() -> void:
	_rules.death_return_delay = 0.0
	_session.setup(_tower, _rules)
	_session.enter_floor(1, false)
	_session.report_player_died()
	var copy: TowerSession = _assert_round_trip(_session)
	assert_true(copy.can_confirm_death())
	assert_true(copy.confirm_death())


func test_ac5_a_snapshot_taken_after_a_leave_or_a_confirm_is_a_town_snapshot() -> void:
	_session.enter_floor(1, false)
	_session.leave_floor()
	assert_eq(_session.to_dict()[TowerSession.KEY_PLACE], int(TowerSession.Place.TOWN))
	_assert_round_trip(_session)
	_session.enter_floor(1, false)
	_session.report_player_died()
	_session.tick(DELAY)
	_session.confirm_death()
	assert_eq(_session.to_dict()[TowerSession.KEY_PLACE], int(TowerSession.Place.TOWN))
	assert_eq(_session.to_dict()[TowerSession.KEY_DEATH_TIME_LEFT], 0.0)
	_assert_round_trip(_session)


func test_ac5_the_fit_rules_for_the_time_left_are_unchanged() -> void:
	_session.enter_floor(1, false)
	_session.report_player_died()
	var pause: Dictionary = _session.to_dict()
	for bad: float in [-0.1, DELAY + 0.1]:
		_assert_refused(pause, TowerSession.KEY_DEATH_TIME_LEFT, bad)
	_assert_refused(pause, TowerSession.KEY_DEATH_TIME_LEFT, "soon")
	var floor_snapshot: Dictionary = _new_floor_snapshot()
	_assert_refused(floor_snapshot, TowerSession.KEY_DEATH_TIME_LEFT, 0.5)


func test_ac5_the_snapshot_keeps_its_keys() -> void:
	var keys: Array = [
		TowerSession.KEY_PLACE,
		TowerSession.KEY_FLOOR,
		TowerSession.KEY_START_ROOM,
		TowerSession.KEY_DEATH_TIME_LEFT,
		TowerSession.KEY_PROGRESS,
		TowerSession.KEY_CLEARED_IN_RUN,
		TowerSession.KEY_LOOT,  # F-016/C14: the character's loot is part of the session
	]
	_session.enter_floor(1, false)
	assert_eq(_session.to_dict().keys().size(), keys.size())
	for key: String in keys:
		assert_true(_session.to_dict().has(key), key)


# --- helpers ---


func _new_session() -> TowerSession:
	var session: TowerSession = TowerSession.new()
	session.setup(_tower, _rules)
	return session


func _new_floor_snapshot() -> Dictionary:
	var session: TowerSession = _new_session()
	session.enter_floor(1, false)
	return session.to_dict()


## Restores `source`'s snapshot into a new session and checks the whole state matches.
func _assert_round_trip(source: TowerSession) -> TowerSession:
	var copy: TowerSession = _new_session()
	assert_true(copy.from_dict(source.to_dict()), "the snapshot fits")
	assert_eq(copy.get_place(), source.get_place())
	assert_eq(copy.get_floor_number(), source.get_floor_number())
	assert_eq(copy.get_start_room(), source.get_start_room())
	assert_almost_eq(copy.get_death_time_left(), source.get_death_time_left(), 0.0001)
	assert_eq(copy.can_confirm_death(), source.can_confirm_death())
	assert_eq_deep(copy.to_dict(), source.to_dict())
	return copy


## from_dict() with `key` set to `value` says no and changes nothing.
func _assert_refused(base: Dictionary, key: String, value: Variant) -> void:
	var snapshot: Dictionary = base.duplicate(true)
	snapshot[key] = value
	var target: TowerSession = _new_session()
	var before: Dictionary = target.to_dict()
	assert_false(target.from_dict(snapshot), "%s = %s" % [key, str(value)])
	assert_eq_deep(target.to_dict(), before)
