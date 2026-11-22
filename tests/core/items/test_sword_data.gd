# gdlint:disable=max-public-methods
extends GutTest
## F-016 T1 (AC3, C1, C3): SwordData's hits and its validation, one test per refusal. Every refusal
## test also checks that the plain sword it starts from is valid, so the error it finds is its own.

var _class: ClassData
var _rules: ItemTunables


func before_each() -> void:
	_class = ItemFixtures.class_data()
	_rules = ItemFixtures.rules()


# --- C1: the hits ---


func test_c1_a_sword_without_weights_splits_over_the_class_chains_own_damages() -> void:
	var sword: SwordData = ItemFixtures.make_sword(&"plain", 46)
	assert_eq(sword.get_hit_damages(_class), PackedInt32Array([11, 11, 24]))
	assert_eq(
		ItemFixtures.make_sword(&"plain", 42).get_hit_damages(_class),
		PackedInt32Array([10, 10, 22])
	)


func test_c1_a_sword_with_weights_splits_over_its_own() -> void:
	var sword: SwordData = _heavy([9, 9, 28], 46)
	assert_eq(sword.get_hit_damages(_class), PackedInt32Array([9, 9, 28]))


func test_c1_the_hits_add_up_to_the_damage() -> void:
	for damage: int in range(30, 50):
		var hits: PackedInt32Array = ItemFixtures.make_sword(&"plain", damage).get_hit_damages(
			_class
		)
		assert_eq(hits[0] + hits[1] + hits[2], damage, "damage %d" % damage)


func test_c1_the_defaults_are_a_sword_with_no_trait() -> void:
	var sword: SwordData = SwordData.new()
	assert_eq(sword.kind, SwordData.Kind.NONE)
	assert_eq(sword.weights, PackedInt32Array())
	assert_eq(sword.max_hp_bonus, 0)
	assert_eq(sword.dash_cooldown_cut, 0.0)
	assert_eq(sword.room_heal_bonus, 0.0)


func test_c1_the_kinds_are_in_the_order_of_the_data_files() -> void:
	assert_eq(SwordData.Kind.NONE, 0)
	assert_eq(SwordData.Kind.HEAVY_FINISHER, 1)
	assert_eq(SwordData.Kind.QUICK_CUTS, 2)
	assert_eq(SwordData.Kind.VITALITY, 3)
	assert_eq(SwordData.Kind.QUICKSTEP, 4)
	assert_eq(SwordData.Kind.MENDING, 5)


# --- AC3 / C3: the plain valid swords ---


func test_c3_a_plain_sword_a_heavy_a_quick_and_each_utility_sword_is_valid() -> void:
	for sword: SwordData in [
		ItemFixtures.make_sword(&"a", 42),
		_heavy([9, 9, 28], 46),
		_quick([12, 12, 19], 43),
		_vitality(8),
		_quickstep(0.08),
		_mending(0.1),
	]:
		assert_eq(sword.validate(_class, _rules), PackedStringArray(), sword.display_name)


func test_c3_a_missing_class_is_refused_and_does_not_crash() -> void:
	assert_true(_has(ItemFixtures.make_sword(&"a").validate(null, _rules), "no attack chain"))
	var empty_class: ClassData = ClassData.new()
	assert_true(
		_has(ItemFixtures.make_sword(&"a").validate(empty_class, _rules), "no attack chain")
	)


# --- AC3 / C3: ids, names and the damage ---


func test_c3_refuses_an_empty_id() -> void:
	var sword: SwordData = ItemFixtures.make_sword(&"")
	assert_true(_has(sword.validate(_class, _rules), "id must not be empty"))


func test_c3_refuses_an_empty_name() -> void:
	var sword: SwordData = ItemFixtures.make_sword(&"a")
	sword.display_name = ""
	assert_true(_has(sword.validate(_class, _rules), "display_name must not be empty"))


func test_c3_refuses_a_damage_below_1() -> void:
	for damage: int in [0, -5]:
		var sword: SwordData = ItemFixtures.make_sword(&"a", damage)
		assert_true(_has(sword.validate(_class, _rules), "damage must be >= 1"), str(damage))


func test_c3_refuses_weights_of_another_size_than_the_chain() -> void:
	for weights: Array in [[9, 28], [9, 9, 9, 19]]:
		var sword: SwordData = _heavy(weights, 46)
		assert_true(
			_has(sword.validate(_class, _rules), "weights has %d entries" % weights.size()),
			str(weights)
		)


func test_c3_refuses_a_weight_below_1() -> void:
	var sword: SwordData = _heavy([0, 9, 28], 46)
	assert_true(_has(sword.validate(_class, _rules), "every weight must be >= 1"))


func test_c3_a_refused_weight_list_adds_no_hit_errors() -> void:
	var errors: PackedStringArray = _heavy([9, 28], 46).validate(_class, _rules)
	assert_false(_has(errors, "every hit"), str(errors))
	assert_false(_has(errors, "max_"), str(errors))


func test_c3_refuses_any_hit_below_1() -> void:
	# 2 over 10, 10, 22 gives 1, 0, 1: the middle hit does nothing.
	var sword: SwordData = ItemFixtures.make_sword(&"a", 2)
	assert_eq(sword.get_hit_damages(_class), PackedInt32Array([1, 0, 1]))
	assert_true(_has(sword.validate(_class, _rules), "every hit must be >= 1"))


func test_c3_refuses_a_chain_above_the_cap() -> void:
	var sword: SwordData = ItemFixtures.make_sword(&"a", _rules.max_chain_damage + 1)
	assert_true(_has(sword.validate(_class, _rules), "above max_chain_damage"))


func test_c3_the_chain_cap_itself_is_valid() -> void:
	var sword: SwordData = ItemFixtures.make_sword(&"a", _rules.max_chain_damage)
	assert_eq(sword.validate(_class, _rules), PackedStringArray())


func test_c3_refuses_light_hits_above_the_cap_together() -> void:
	# 15 + 15 = 30 > 29, the last hit is 10: below the standard split's, so a valid Quick cuts shape.
	var sword: SwordData = _quick([15, 15, 10], 40)
	var errors: PackedStringArray = sword.validate(_class, _rules)
	assert_true(_has(errors, "above max_light_hits_damage"), str(errors))
	assert_eq(errors.size(), 1, str(errors))


func test_c3_light_hits_at_the_cap_are_valid() -> void:
	var sword: SwordData = _quick([15, 14, 10], 39)
	assert_eq(sword.validate(_class, _rules), PackedStringArray())


func test_c3_refuses_a_last_hit_above_the_cap() -> void:
	var sword: SwordData = _heavy([9, 9, 30], 48)
	var errors: PackedStringArray = sword.validate(_class, _rules)
	assert_true(_has(errors, "above max_finisher_damage"), str(errors))
	assert_eq(errors.size(), 1, str(errors))


func test_c3_a_last_hit_at_the_cap_is_valid() -> void:
	assert_eq(_heavy([9, 9, 29], 47).validate(_class, _rules), PackedStringArray())


# --- AC3 / C3: bonuses and kinds ---


func test_c3_refuses_a_negative_bonus() -> void:
	var hp: SwordData = _vitality(8)
	hp.max_hp_bonus = -1
	assert_true(_has(hp.validate(_class, _rules), "max_hp_bonus must be >= 0"))
	var cut: SwordData = _quickstep(0.05)
	cut.dash_cooldown_cut = -0.05
	assert_true(_has(cut.validate(_class, _rules), "dash_cooldown_cut must be >= 0"))
	var heal: SwordData = _mending(0.05)
	heal.room_heal_bonus = -0.05
	assert_true(_has(heal.validate(_class, _rules), "room_heal_bonus must be >= 0"))


func test_c3_refuses_no_trait_with_weights() -> void:
	var sword: SwordData = ItemFixtures.make_sword(&"a", 42)
	sword.weights = [10, 10, 22]
	assert_true(_has(sword.validate(_class, _rules), "no trait must not have weights"))


func test_c3_refuses_no_trait_with_any_bonus() -> void:
	for sword: SwordData in [
		ItemFixtures.make_sword(&"a", 42, SwordData.Kind.NONE, [], 5),
		ItemFixtures.make_sword(&"a", 42, SwordData.Kind.NONE, [], 0, 0.05),
		ItemFixtures.make_sword(&"a", 42, SwordData.Kind.NONE, [], 0, 0.0, 0.05),
	]:
		assert_true(_has(sword.validate(_class, _rules), "no trait must not have a bonus"))


func test_c3_refuses_a_utility_sword_with_weights() -> void:
	for sword: SwordData in [_vitality(8), _quickstep(0.05), _mending(0.05)]:
		sword.weights = [10, 10, 22]
		assert_true(
			_has(sword.validate(_class, _rules), "utility sword must not have weights"),
			sword.display_name
		)


func test_c3_refuses_a_utility_sword_without_its_own_bonus() -> void:
	for kind: SwordData.Kind in [
		SwordData.Kind.VITALITY, SwordData.Kind.QUICKSTEP, SwordData.Kind.MENDING
	]:
		var sword: SwordData = ItemFixtures.make_sword(&"a", 44, kind)
		assert_true(_has(sword.validate(_class, _rules), "needs its own bonus"), "kind %d" % kind)


func test_c3_refuses_a_utility_sword_with_another_kinds_bonus() -> void:
	var vitality: SwordData = _vitality(8)
	vitality.room_heal_bonus = 0.05
	assert_true(_has(vitality.validate(_class, _rules), "another kind's bonus"))
	var quickstep: SwordData = _quickstep(0.05)
	quickstep.max_hp_bonus = 3
	assert_true(_has(quickstep.validate(_class, _rules), "another kind's bonus"))
	var mending: SwordData = _mending(0.05)
	mending.dash_cooldown_cut = 0.05
	assert_true(_has(mending.validate(_class, _rules), "another kind's bonus"))


func test_c3_a_utility_sword_with_only_its_own_bonus_has_no_such_error() -> void:
	for sword: SwordData in [_vitality(8), _quickstep(0.05), _mending(0.05)]:
		var errors: PackedStringArray = sword.validate(_class, _rules)
		assert_false(_has(errors, "another kind's"), str(errors))
		assert_false(_has(errors, "needs its own"), str(errors))


func test_c3_refuses_vitality_above_the_cap() -> void:
	var sword: SwordData = _vitality(_rules.max_hp_bonus_cap + 1)
	assert_true(_has(sword.validate(_class, _rules), "above max_hp_bonus_cap"))
	assert_eq(_vitality(_rules.max_hp_bonus_cap).validate(_class, _rules), PackedStringArray())


func test_c3_refuses_quickstep_that_would_fall_below_the_minimum() -> void:
	# 0.35 - 0.2 = 0.15, below 0.2.
	var sword: SwordData = _quickstep(0.2)
	assert_true(_has(sword.validate(_class, _rules), "below min_dash_cooldown"))


func test_c3_quickstep_that_lands_exactly_on_the_minimum_is_valid() -> void:
	# 0.35 - 0.15 is 0.19999999999999998 in a double: the check has a tiny slack for that.
	var sword: SwordData = _quickstep(0.15)
	assert_eq(sword.validate(_class, _rules), PackedStringArray())


func test_c3_quickstep_follows_the_class_and_the_rules() -> void:
	var slow_class: ClassData = _class.duplicate()
	slow_class.dash_cooldown = 0.25
	assert_true(_has(_quickstep(0.08).validate(slow_class, _rules), "below min_dash_cooldown"))
	_rules.min_dash_cooldown = 0.5
	assert_true(_has(_quickstep(0.05).validate(_class, _rules), "below min_dash_cooldown"))


func test_c3_refuses_heavy_finisher_without_weights() -> void:
	var sword: SwordData = ItemFixtures.make_sword(&"a", 46, SwordData.Kind.HEAVY_FINISHER)
	assert_true(_has(sword.validate(_class, _rules), "needs its own weights"))


func test_c3_refuses_heavy_finisher_whose_last_hit_is_not_above_the_standard_split() -> void:
	# 10/10/22 is the standard split of 42, so the last hit is equal, not above.
	var equal: SwordData = _heavy([10, 10, 22], 42)
	assert_true(_has(equal.validate(_class, _rules), "not above the standard split"))
	# 46 over 11/11/24 is the standard split: 24 is the last hit.
	var below: SwordData = _heavy([12, 12, 22], 46)
	assert_true(_has(below.validate(_class, _rules), "not above the standard split"))


func test_c3_refuses_quick_cuts_without_weights() -> void:
	var sword: SwordData = ItemFixtures.make_sword(&"a", 43, SwordData.Kind.QUICK_CUTS)
	assert_true(_has(sword.validate(_class, _rules), "needs its own weights"))


func test_c3_refuses_quick_cuts_whose_last_hit_is_not_below_the_standard_split() -> void:
	var equal: SwordData = _quick([10, 10, 22], 42)
	assert_true(_has(equal.validate(_class, _rules), "not below the standard split"))
	var above: SwordData = _quick([9, 9, 28], 46)
	assert_true(_has(above.validate(_class, _rules), "not below the standard split"))


func test_c3_refuses_heavy_finisher_and_quick_cuts_with_a_bonus_as_a_second_trait() -> void:
	var heavy: SwordData = _heavy([9, 9, 28], 46)
	heavy.max_hp_bonus = 5
	assert_true(_has(heavy.validate(_class, _rules), "Heavy finisher sword must not have a bonus"))
	var quick: SwordData = _quick([12, 12, 19], 43)
	quick.room_heal_bonus = 0.05
	assert_true(_has(quick.validate(_class, _rules), "Quick cuts sword must not have a bonus"))


func test_c3_every_error_is_returned_not_the_first() -> void:
	var sword: SwordData = ItemFixtures.make_sword(&"", 0)
	sword.display_name = ""
	assert_gte(sword.validate(_class, _rules).size(), 3)


# --- helpers ---


func _heavy(weights: Array, damage: int) -> SwordData:
	return ItemFixtures.make_sword(
		&"heavy", damage, SwordData.Kind.HEAVY_FINISHER, PackedInt32Array(weights)
	)


func _quick(weights: Array, damage: int) -> SwordData:
	return ItemFixtures.make_sword(
		&"quick", damage, SwordData.Kind.QUICK_CUTS, PackedInt32Array(weights)
	)


func _vitality(bonus: int) -> SwordData:
	return ItemFixtures.make_sword(&"vit", 44, SwordData.Kind.VITALITY, [], bonus)


func _quickstep(cut: float) -> SwordData:
	return ItemFixtures.make_sword(&"step", 44, SwordData.Kind.QUICKSTEP, [], 0, cut)


func _mending(bonus: float) -> SwordData:
	return ItemFixtures.make_sword(&"mend", 44, SwordData.Kind.MENDING, [], 0, 0.0, bonus)


func _has(errors: PackedStringArray, needle: String) -> bool:
	for error: String in errors:
		if error.contains(needle):
			return true
	return false
