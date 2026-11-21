# gdlint:disable=max-public-methods
extends GutTest
## F-016 T2 (C10-C12, AC9, AC10, AC12, AC27): the roller's mapping over every roll, its draws
## against a reference generator that makes the same calls with the same arguments, the
## statistics of a fixed seed, and the generator's seed and state coming back on a restore.

const SEED: int = 20261121
const KILLS: int = 1000
const PERCENTS: Array[int] = [30, 20, 10]
const SD_LIMIT: float = 4.0

var _roller: LootRoller
var _percents: PackedInt32Array


func before_each() -> void:
	_roller = LootRoller.new()
	_roller.seed_with(SEED)
	_percents = PackedInt32Array(PERCENTS)


func _reference(reference_seed: int = SEED) -> RandomNumberGenerator:
	var reference: RandomNumberGenerator = RandomNumberGenerator.new()
	reference.seed = reference_seed
	return reference


# --- AC9: the pure mapping, over every roll ---------------------------------------------------


func test_ac9_boss_pick_over_one_to_a_hundred_gives_30_20_10_and_40_nothing() -> void:
	var counts: Array[int] = [0, 0, 0, 0]
	for roll: int in range(1, 101):
		var pick: int = LootRoller.boss_pick(roll, _percents)
		counts[pick if pick >= 0 else 3] += 1
	assert_eq(counts, [30, 20, 10, 40] as Array[int])


func test_ac9_boss_pick_over_one_to_the_sum_gives_exactly_30_20_10() -> void:
	var counts: Array[int] = [0, 0, 0]
	for roll: int in range(1, 61):
		var pick: int = LootRoller.boss_pick(roll, _percents)
		assert_gte(pick, 0, "roll %d is a sword" % roll)
		counts[pick] += 1
	assert_eq(counts, [30, 20, 10] as Array[int])


func test_ac9_boss_pick_sword_zero_is_one_to_p0_and_the_next_follows() -> void:
	assert_eq(LootRoller.boss_pick(1, _percents), 0)
	assert_eq(LootRoller.boss_pick(30, _percents), 0)
	assert_eq(LootRoller.boss_pick(31, _percents), 1)
	assert_eq(LootRoller.boss_pick(50, _percents), 1)
	assert_eq(LootRoller.boss_pick(51, _percents), 2)
	assert_eq(LootRoller.boss_pick(60, _percents), 2)
	assert_eq(LootRoller.boss_pick(61, _percents), -1)


func test_ac9_a_roll_above_the_sum_or_below_one_is_nothing() -> void:
	for roll: int in [0, -1, -100, 61, 100, 101, 100000]:
		assert_eq(LootRoller.boss_pick(roll, _percents), -1, "roll %d" % roll)


func test_ac9_boss_pick_with_an_empty_table_is_nothing() -> void:
	assert_eq(LootRoller.boss_pick(1, PackedInt32Array()), -1)
	assert_eq(LootRoller.boss_pick(50, PackedInt32Array()), -1)


func test_ac9_a_table_adding_up_to_a_hundred_never_gives_nothing() -> void:
	var table: PackedInt32Array = PackedInt32Array([60, 40])
	for roll: int in range(1, 101):
		assert_gte(LootRoller.boss_pick(roll, table), 0, "roll %d" % roll)
	assert_eq(LootRoller.boss_pick(101, table), -1)


# --- AC9: the draws, against a reference making the same calls with the same arguments ----------


func test_ac9_a_regular_kill_draws_one_float_and_then_an_index_only_on_a_drop() -> void:
	var reference: RandomNumberGenerator = _reference()
	var chance: float = 0.3
	var pool_size: int = 5
	var drops: int = 0
	var mismatches: int = 0
	for kill: int in KILLS:
		var expected: int = -1
		if reference.randf() < chance:
			expected = reference.randi_range(0, pool_size - 1)
		var got: int = _roller.roll_regular(chance, pool_size)
		mismatches += 0 if got == expected else 1
		drops += 1 if expected >= 0 else 0
		assert_eq(_roller.get_state(), reference.state, "kill %d: the same state" % kill)
		if get_fail_count() > 0:
			return
	assert_eq(mismatches, 0, "every outcome is the reference's")
	assert_between(drops, 1, KILLS - 1, "both a drop and a miss happened")


func test_ac9_the_pool_pick_maps_every_index_to_its_own_sword() -> void:
	var reference: RandomNumberGenerator = _reference()
	var seen: Dictionary[int, bool] = {}
	for _kill: int in KILLS:
		reference.randf()
		var expected: int = reference.randi_range(0, 4)
		var got: int = _roller.roll_regular(1.0, 5)
		assert_eq(got, expected)
		seen[got] = true
	for index: int in 5:
		assert_true(seen.has(index), "index %d came up" % index)
	assert_eq(seen.size(), 5, "and nothing outside 0 to 4")


## CR-6: the pick is `randi_range(0, n - 1)` for every pool size, one draw each (a pool of one
## draws too, and gives 0), each index of a pool of two reached.
func test_cr6_the_pool_pick_follows_the_reference_for_pools_of_one_two_and_three() -> void:
	for pool_size: int in [1, 2, 3]:
		var roller: LootRoller = LootRoller.new()
		roller.seed_with(SEED)
		var reference: RandomNumberGenerator = _reference()
		var seen: Dictionary[int, int] = {}
		for _kill: int in KILLS:
			reference.randf()
			var expected: int = reference.randi_range(0, pool_size - 1)
			var got: int = roller.roll_regular(1.0, pool_size)
			assert_eq(got, expected, "a pool of %d" % pool_size)
			seen[got] = seen.get(got, 0) + 1
		assert_eq(seen.size(), pool_size, "every index of a pool of %d came up" % pool_size)
		assert_eq(
			roller.to_dict(), {LootRoller.KEY_SEED: SEED, LootRoller.KEY_STATE: reference.state}
		)


func test_ac9_a_guaranteed_boss_win_draws_once_over_one_to_the_sum() -> void:
	var reference: RandomNumberGenerator = _reference()
	var mismatches: int = 0
	var picks: Dictionary[int, bool] = {}
	for kill: int in KILLS:
		var expected: int = LootRoller.boss_pick(reference.randi_range(1, 60), _percents)
		var got: int = _roller.roll_boss(_percents, true)
		mismatches += 0 if got == expected else 1
		picks[got] = true
		assert_eq(_roller.get_state(), reference.state, "win %d: the same state" % kill)
		if get_fail_count() > 0:
			return
	assert_eq(mismatches, 0, "every outcome is the reference's")
	assert_false(picks.has(-1), "a guaranteed win never gives nothing")
	assert_eq(picks.size(), 3, "all three swords came up")


func test_ac9_a_repeat_boss_win_draws_once_over_one_to_a_hundred() -> void:
	var reference: RandomNumberGenerator = _reference()
	var mismatches: int = 0
	var picks: Dictionary[int, bool] = {}
	for kill: int in KILLS:
		var expected: int = LootRoller.boss_pick(reference.randi_range(1, 100), _percents)
		var got: int = _roller.roll_boss(_percents, false)
		mismatches += 0 if got == expected else 1
		picks[got] = true
		assert_eq(_roller.get_state(), reference.state, "win %d: the same state" % kill)
		if get_fail_count() > 0:
			return
	assert_eq(mismatches, 0, "every outcome is the reference's")
	assert_eq(picks.size(), 4, "three swords and nothing came up")


func test_ac9_the_two_boss_rolls_differ_in_their_range() -> void:
	# The reference's state cannot tell (1, 100) from (0, 100); the outcomes can.
	var guaranteed: LootRoller = LootRoller.new()
	guaranteed.seed_with(SEED)
	var repeat: LootRoller = LootRoller.new()
	repeat.seed_with(SEED)
	var differing: int = 0
	for _i: int in KILLS:
		if guaranteed.roll_boss(_percents, true) != repeat.roll_boss(_percents, false):
			differing += 1
	assert_gt(differing, 0, "a range of 1 to 60 and one of 1 to 100 give other swords")


func test_ac9_the_draws_follow_the_reference_through_a_mixed_run() -> void:
	var reference: RandomNumberGenerator = _reference()
	var got: Array[int] = []
	var expected: Array[int] = []
	for index: int in 300:
		match index % 3:
			0:
				got.append(_roller.roll_regular(0.5, 4))
				expected.append(reference.randi_range(0, 3) if reference.randf() < 0.5 else -1)
			1:
				got.append(_roller.roll_boss(_percents, true))
				expected.append(LootRoller.boss_pick(reference.randi_range(1, 60), _percents))
			_:
				got.append(_roller.roll_boss(_percents, false))
				expected.append(LootRoller.boss_pick(reference.randi_range(1, 100), _percents))
	assert_eq(got, expected)
	assert_eq(_roller.get_state(), reference.state)


func test_ac9_a_chance_of_one_always_drops_and_the_float_is_strictly_below() -> void:
	for _i: int in KILLS:
		assert_gte(_roller.roll_regular(1.0, 3), 0)
	# randf() is in [0, 1): a chance of 0 is never beaten, and rolls nothing without drawing.
	var untouched: Dictionary = _roller.to_dict()
	assert_eq(_roller.roll_regular(0.0, 3), -1)
	assert_eq_deep(_roller.to_dict(), untouched)


func test_ac9_no_loot_to_roll_draws_nothing() -> void:
	var untouched: Dictionary = _roller.to_dict()
	assert_eq(_roller.roll_regular(0.5, 0), -1, "an empty pool")
	assert_eq(_roller.roll_regular(0.0, 5), -1, "zero drops per run")
	assert_eq(_roller.roll_regular(-0.5, 5), -1, "a negative chance")
	assert_eq(_roller.roll_regular(NAN, 5), -1, "a chance that is not a number")
	assert_eq(_roller.roll_boss(PackedInt32Array(), true), -1, "an empty table, guaranteed")
	assert_eq(_roller.roll_boss(PackedInt32Array(), false), -1, "an empty table, repeat")
	assert_eq(_roller.roll_boss(PackedInt32Array([0]), true), -1, "a table with no percent")
	assert_eq_deep(_roller.to_dict(), untouched)


# --- AC10: statistics at a fixed seed -----------------------------------------------------------


func _sd(trials: int, probability: float) -> float:
	return sqrt(trials * probability * (1.0 - probability))


func _assert_near(count: int, trials: int, probability: float, what: String) -> void:
	var expected: float = trials * probability
	var limit: float = SD_LIMIT * _sd(trials, probability)
	assert_between(
		float(count), expected - limit, expected + limit, "%s (expect %.0f)" % [what, expected]
	)


func test_ac10_twenty_thousand_regular_kills_drop_near_the_chance_and_share_the_pool() -> void:
	var trials: int = 20000
	var chance: float = 1.0 / 27.0
	var counts: Array[int] = [0, 0, 0, 0, 0]
	var drops: int = 0
	for _i: int in trials:
		var pick: int = _roller.roll_regular(chance, 5)
		if pick >= 0:
			counts[pick] += 1
			drops += 1
	_assert_near(drops, trials, chance, "drops")
	for index: int in 5:
		_assert_near(counts[index], trials, chance / 5.0, "sword %d" % index)


func test_ac10_repeat_boss_wins_give_each_sword_its_percent_and_nothing_the_rest() -> void:
	var trials: int = 6000
	var counts: Array[int] = [0, 0, 0, 0]
	for _i: int in trials:
		var pick: int = _roller.roll_boss(_percents, false)
		counts[pick if pick >= 0 else 3] += 1
	_assert_near(counts[0], trials, 0.30, "sword 0")
	_assert_near(counts[1], trials, 0.20, "sword 1")
	_assert_near(counts[2], trials, 0.10, "sword 2")
	_assert_near(counts[3], trials, 0.40, "nothing")


func test_ac10_guaranteed_boss_wins_give_each_sword_its_share_and_never_nothing() -> void:
	var trials: int = 6000
	var counts: Array[int] = [0, 0, 0, 0]
	for _i: int in trials:
		var pick: int = _roller.roll_boss(_percents, true)
		counts[pick if pick >= 0 else 3] += 1
	assert_eq(counts[3], 0, "never nothing")
	_assert_near(counts[0], trials, 0.5, "sword 0")
	_assert_near(counts[1], trials, 1.0 / 3.0, "sword 1")
	_assert_near(counts[2], trials, 1.0 / 6.0, "sword 2")


# --- AC12, C12: seed and state -----------------------------------------------------------------


func test_c12_a_roller_nobody_seeded_is_seeded_with_zero() -> void:
	var fresh: LootRoller = LootRoller.new()
	var zero: LootRoller = LootRoller.new()
	zero.seed_with(0)
	assert_eq(fresh.get_seed(), 0)
	assert_eq(fresh.get_state(), zero.get_state())
	assert_eq_deep(fresh.to_dict(), zero.to_dict())
	var other: LootRoller = LootRoller.new()
	for _i: int in 50:
		assert_eq(fresh.roll_boss(_percents, false), other.roll_boss(_percents, false))


func test_c12_the_same_seed_gives_the_same_draws_and_another_seed_other_ones() -> void:
	var same: LootRoller = LootRoller.new()
	same.seed_with(SEED)
	var other: LootRoller = LootRoller.new()
	other.seed_with(SEED + 1)
	var from_same: Array[int] = []
	var from_roller: Array[int] = []
	var from_other: Array[int] = []
	for _i: int in 100:
		from_roller.append(_roller.roll_boss(_percents, true))
		from_same.append(same.roll_boss(_percents, true))
		from_other.append(other.roll_boss(_percents, true))
	assert_eq(from_roller, from_same)
	assert_ne(from_roller, from_other)
	assert_eq_deep(_roller.to_dict(), same.to_dict())


func test_c12_the_snapshot_holds_the_seed_and_the_state() -> void:
	var snapshot: Dictionary = _roller.to_dict()
	assert_eq(snapshot[LootRoller.KEY_SEED], SEED)
	assert_eq(snapshot[LootRoller.KEY_STATE], _roller.get_state())
	_roller.roll_boss(_percents, true)
	assert_ne(_roller.to_dict()[LootRoller.KEY_STATE], snapshot[LootRoller.KEY_STATE])
	assert_eq(_roller.to_dict()[LootRoller.KEY_SEED], SEED, "drawing leaves the seed")


func _mixed_draws(roller: LootRoller, count: int) -> Array[int]:
	var draws: Array[int] = []
	for index: int in count:
		match index % 3:
			0:
				draws.append(roller.roll_regular(0.5, 4))
			1:
				draws.append(roller.roll_boss(_percents, true))
			_:
				draws.append(roller.roll_boss(_percents, false))
	return draws


func test_ac12_a_roller_restored_at_any_point_draws_what_the_original_draws_next() -> void:
	for drawn_before: int in [0, 1, 2, 7, 100, 333]:
		var original: LootRoller = LootRoller.new()
		original.seed_with(SEED)
		_mixed_draws(original, drawn_before)
		var snapshot: Dictionary = original.to_dict()
		var later: Array[int] = _mixed_draws(original, 200)
		var fresh: LootRoller = LootRoller.new()
		assert_true(fresh.from_dict(snapshot))
		assert_eq(_mixed_draws(fresh, 200), later, "after %d draws" % drawn_before)
		assert_eq(
			fresh.get_state(), original.get_state(), "after %d draws: the same state" % drawn_before
		)


func test_ac12_a_restore_into_a_roller_that_has_moved_on_goes_back() -> void:
	var snapshot: Dictionary = _roller.to_dict()
	var expected: Array[int] = _mixed_draws(_roller, 60)
	var moved: LootRoller = LootRoller.new()
	moved.seed_with(999)
	_mixed_draws(moved, 500)
	assert_true(moved.from_dict(snapshot))
	assert_eq(moved.get_seed(), SEED)
	assert_eq(_mixed_draws(moved, 60), expected)


func test_ac12_godots_generator_state_restores_only_when_the_seed_is_set_first() -> void:
	# What the roller relies on, measured: assigning the seed resets the state.
	var generator: RandomNumberGenerator = _reference()
	for _i: int in 10:
		generator.randf()
	var saved_seed: int = generator.seed
	var saved_state: int = generator.state
	var expected: Array[float] = [generator.randf(), generator.randf()]
	generator.seed = saved_seed
	assert_ne(generator.state, saved_state, "setting the seed rewinds the state")
	generator.state = saved_state
	assert_eq([generator.randf(), generator.randf()], expected, "setting the state resumes")
	var wrong_order: RandomNumberGenerator = RandomNumberGenerator.new()
	wrong_order.state = saved_state
	wrong_order.seed = saved_seed
	assert_ne(wrong_order.state, saved_state, "the other order loses the state")


func test_ac12_any_seed_and_state_survive_a_round_trip() -> void:
	for odd_seed: int in [0, 1, -1, 4611686018427387904, 9223372036854775807, -9223372036854775808]:
		var original: LootRoller = LootRoller.new()
		original.seed_with(odd_seed)
		_mixed_draws(original, 17)
		var snapshot: Dictionary = original.to_dict()
		assert_typeof(snapshot[LootRoller.KEY_SEED], TYPE_INT)
		assert_typeof(snapshot[LootRoller.KEY_STATE], TYPE_INT)
		var fresh: LootRoller = LootRoller.new()
		assert_true(fresh.from_dict(snapshot), "seed %d" % odd_seed)
		assert_eq_deep(fresh.to_dict(), snapshot)
		assert_eq(_mixed_draws(fresh, 30), _mixed_draws(original, 30), "seed %d" % odd_seed)


func test_c12_a_snapshot_with_any_two_integers_is_accepted() -> void:
	var fresh: LootRoller = LootRoller.new()
	assert_true(fresh.from_dict({LootRoller.KEY_SEED: -5, LootRoller.KEY_STATE: -7}))
	assert_eq(fresh.get_state(), -7)
	assert_true(fresh.from_dict({LootRoller.KEY_SEED: 0, LootRoller.KEY_STATE: 0}))


func test_c12_a_malformed_snapshot_is_refused_and_changes_nothing() -> void:
	var before: Dictionary = _roller.to_dict()
	var bad: Array[Dictionary] = [
		{},
		{LootRoller.KEY_SEED: 1},
		{LootRoller.KEY_STATE: 1},
		{LootRoller.KEY_SEED: 1.0, LootRoller.KEY_STATE: 2},
		{LootRoller.KEY_SEED: 1, LootRoller.KEY_STATE: "2"},
		{LootRoller.KEY_SEED: null, LootRoller.KEY_STATE: 2},
	]
	for snapshot: Dictionary in bad:
		assert_false(_roller.from_dict(snapshot), str(snapshot))
		assert_eq_deep(_roller.to_dict(), before)


# --- AC27: nothing else in core draws ------------------------------------------------------------


func _scripts_under(path: String, found: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(path):
		if file_name.ends_with(".gd"):
			found.append("%s/%s" % [path, file_name])
	for directory: String in DirAccess.get_directories_at(path):
		_scripts_under("%s/%s" % [path, directory], found)


func test_ac27_no_file_of_core_but_the_roller_draws() -> void:
	var scripts: Array[String] = []
	_scripts_under("res://src/core", scripts)
	assert_gt(scripts.size(), 50, "the scan found the core's sources")
	assert_true(scripts.has("res://src/core/items/loot_roller.gd"), "and the roller among them")
	var tokens: Array[String] = ["randi", "randf", "randomize", "RandomNumberGenerator"]
	var offenders: Array[String] = []
	for script: String in scripts:
		var text: String = FileAccess.get_file_as_string(script)
		for token: String in tokens:
			if text.contains(token) and script != "res://src/core/items/loot_roller.gd":
				offenders.append("%s: %s" % [script, token])
	assert_eq(offenders, [] as Array[String], "only loot_roller.gd names a draw")
	var roller_text: String = FileAccess.get_file_as_string("res://src/core/items/loot_roller.gd")
	assert_true(roller_text.contains("RandomNumberGenerator"), "the roller does")
