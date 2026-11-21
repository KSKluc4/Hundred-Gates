extends GutTest
## F-016 T1 (AC1, C2): SwordMath.split, the integer split of a sword's damage over its hits.

const STANDARD: PackedInt32Array = [10, 10, 22]
## AC1: the standard weights, totals 36 to 49.
const TABLE: Array[Array] = [
	[36, 9, 8, 19],
	[37, 9, 9, 19],
	[38, 9, 9, 20],
	[39, 9, 9, 21],
	[40, 10, 9, 21],
	[41, 10, 10, 21],
	[42, 10, 10, 22],
	[43, 10, 10, 23],
	[44, 11, 10, 23],
	[45, 11, 11, 23],
	[46, 11, 11, 24],
	[47, 11, 11, 25],
	[48, 12, 11, 25],
	[49, 12, 11, 26],
]
const RANDOM_CASES: int = 400
const RANDOM_SEED: int = 16016


func test_ac1_the_standard_weights_give_the_table_for_36_to_49() -> void:
	for row: Array in TABLE:
		var total: int = row[0]
		assert_eq(
			SwordMath.split(total, STANDARD),
			PackedInt32Array([row[1], row[2], row[3]]),
			"the split of %d" % total
		)


func test_ac1_for_the_standard_weights_every_hit_is_non_decreasing_in_the_total() -> void:
	var before: PackedInt32Array = SwordMath.split(36, STANDARD)
	for total: int in range(37, 50):
		var now: PackedInt32Array = SwordMath.split(total, STANDARD)
		for index: int in 3:
			assert_gte(now[index], before[index], "hit %d at %d" % [index, total])
		before = now


func test_ac1_that_monotony_is_not_a_property_of_the_rule_in_general() -> void:
	var weights: PackedInt32Array = [3, 5, 7]
	assert_eq(SwordMath.split(7, weights), PackedInt32Array([2, 2, 3]))
	assert_eq(SwordMath.split(8, weights), PackedInt32Array([1, 3, 4]))


func test_ac1_random_weights_add_up_to_the_total_and_stay_within_one_of_the_exact_share() -> void:
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = RANDOM_SEED  # The test's own source, fixed: nothing in src draws here.
	for case_index: int in RANDOM_CASES:
		var weights: PackedInt32Array = PackedInt32Array()
		for _hit: int in generator.randi_range(1, 4):
			weights.append(generator.randi_range(1, 30))
		var total: int = generator.randi_range(0, 200)
		var hits: PackedInt32Array = SwordMath.split(total, weights)
		var weight_sum: int = 0
		for weight: int in weights:
			weight_sum += weight
		assert_eq(hits.size(), weights.size(), "one entry per weight, case %d" % case_index)
		var hit_sum: int = 0
		for index: int in hits.size():
			hit_sum += hits[index]
			var exact: float = float(total) * weights[index] / weight_sum
			assert_lt(absf(hits[index] - exact), 1.0, "hit %d, case %d" % [index, case_index])
		assert_eq(hit_sum, total, "the hits add up, case %d" % case_index)


func test_c2_an_empty_list_gives_an_empty_array() -> void:
	assert_eq(SwordMath.split(42, PackedInt32Array()), PackedInt32Array())


func test_c2_a_weight_of_zero_gives_an_empty_array() -> void:
	assert_eq(SwordMath.split(42, PackedInt32Array([10, 0, 22])), PackedInt32Array())
	assert_eq(
		SwordMath.split(42, PackedInt32Array([0, 0, 0])), PackedInt32Array(), "no division by 0"
	)


func test_c2_a_negative_weight_gives_an_empty_array() -> void:
	assert_eq(SwordMath.split(42, PackedInt32Array([10, 10, -22])), PackedInt32Array())


func test_c2_a_negative_total_gives_an_empty_array() -> void:
	assert_eq(SwordMath.split(-1, STANDARD), PackedInt32Array())


func test_c2_a_total_of_zero_gives_zeros() -> void:
	assert_eq(SwordMath.split(0, STANDARD), PackedInt32Array([0, 0, 0]))


func test_c2_a_single_weight_gets_the_whole_total() -> void:
	assert_eq(SwordMath.split(17, PackedInt32Array([5])), PackedInt32Array([17]))


func test_c2_equal_remainders_go_to_the_last_hit_first() -> void:
	assert_eq(SwordMath.split(1, PackedInt32Array([1, 1, 1])), PackedInt32Array([0, 0, 1]))
	assert_eq(SwordMath.split(1, PackedInt32Array([1, 1])), PackedInt32Array([0, 1]))


func test_c2_then_the_earliest_in_order() -> void:
	assert_eq(SwordMath.split(2, PackedInt32Array([1, 1, 1])), PackedInt32Array([1, 0, 1]))
	assert_eq(SwordMath.split(3, PackedInt32Array([1, 1, 1, 1])), PackedInt32Array([1, 1, 0, 1]))


func test_c2_a_larger_remainder_beats_the_tie_order() -> void:
	# 5 over 3, 3, 4 (W = 10): shares 1.5, 1.5, 2.0 -> floors 1, 1, 2, one point left; the
	# remainders are 5, 5, 0, so the last hit's order does not help it: hit 0 takes the point.
	assert_eq(SwordMath.split(5, PackedInt32Array([3, 3, 4])), PackedInt32Array([2, 1, 2]))
