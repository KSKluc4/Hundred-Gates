extends GutTest
## F-016 T1 (C7, AC5 loadout part): PlayerLoadout turns class and sword into the four values.

var _class: ClassData
var _rules: ItemTunables


func before_each() -> void:
	_class = ItemFixtures.class_data()
	_rules = ItemFixtures.rules()


func test_ac5_with_a_null_sword_every_value_is_the_classes() -> void:
	var loadout: PlayerLoadout = PlayerLoadout.of(_class, null, _rules)
	for index: int in _class.attack_chain.size():
		assert_eq(
			loadout.get_hit_damage(index), _class.attack_chain[index].damage, "hit %d" % index
		)
	assert_eq(loadout.get_max_hp(), _class.max_hp)
	assert_eq(loadout.get_dash_cooldown(), _class.dash_cooldown)
	assert_eq(loadout.get_room_heal_bonus(), 0.0)
	assert_null(loadout.get_sword())


func test_ac5_the_starter_sword_gives_the_classes_values_too() -> void:
	var starter: SwordData = load("res://data/items/swords/recruits_sword.tres")
	var loadout: PlayerLoadout = PlayerLoadout.of(_class, starter, _rules)
	for index: int in _class.attack_chain.size():
		assert_eq(
			loadout.get_hit_damage(index), _class.attack_chain[index].damage, "hit %d" % index
		)
	assert_eq(loadout.get_max_hp(), _class.max_hp)
	assert_eq(loadout.get_dash_cooldown(), _class.dash_cooldown)
	assert_eq(loadout.get_room_heal_bonus(), 0.0)
	assert_same(loadout.get_sword(), starter)


func test_c7_the_swords_split_gives_the_hits() -> void:
	var sword: SwordData = ItemFixtures.make_sword(
		&"a", 46, SwordData.Kind.HEAVY_FINISHER, [9, 9, 28]
	)
	var loadout: PlayerLoadout = PlayerLoadout.of(_class, sword, _rules)
	assert_eq(loadout.get_hit_damage(0), 9)
	assert_eq(loadout.get_hit_damage(1), 9)
	assert_eq(loadout.get_hit_damage(2), 28)


func test_c7_a_sword_without_weights_splits_over_the_class_chain() -> void:
	var loadout: PlayerLoadout = PlayerLoadout.of(_class, ItemFixtures.make_sword(&"a", 45), _rules)
	assert_eq(loadout.get_hit_damage(0), 11)
	assert_eq(loadout.get_hit_damage(1), 11)
	assert_eq(loadout.get_hit_damage(2), 23)


func test_c7_a_hit_the_chain_does_not_have_reads_minus_one() -> void:
	var with_sword: PlayerLoadout = PlayerLoadout.of(
		_class, ItemFixtures.make_sword(&"a", 45), _rules
	)
	var without: PlayerLoadout = PlayerLoadout.of(_class, null, _rules)
	for loadout: PlayerLoadout in [with_sword, without]:
		assert_eq(loadout.get_hit_damage(3), -1)
		assert_eq(loadout.get_hit_damage(-1), -1)


func test_c7_vitality_adds_to_the_max_hp() -> void:
	var sword: SwordData = ItemFixtures.make_sword(&"a", 44, SwordData.Kind.VITALITY, [], 8)
	assert_eq(PlayerLoadout.of(_class, sword, _rules).get_max_hp(), _class.max_hp + 8)


func test_c7_quickstep_takes_the_cut_off_the_cooldown() -> void:
	var sword: SwordData = ItemFixtures.make_sword(&"a", 44, SwordData.Kind.QUICKSTEP, [], 0, 0.08)
	assert_almost_eq(
		PlayerLoadout.of(_class, sword, _rules).get_dash_cooldown(),
		_class.dash_cooldown - 0.08,
		0.00001
	)


func test_c7_the_cooldown_never_goes_below_the_minimum() -> void:
	var slow: ClassData = _class.duplicate()
	slow.dash_cooldown = 0.25
	var sword: SwordData = ItemFixtures.make_sword(&"a", 44, SwordData.Kind.QUICKSTEP, [], 0, 0.08)
	assert_eq(PlayerLoadout.of(slow, sword, _rules).get_dash_cooldown(), _rules.min_dash_cooldown)
	_rules.min_dash_cooldown = 0.1
	assert_almost_eq(PlayerLoadout.of(slow, sword, _rules).get_dash_cooldown(), 0.17, 0.00001)


func test_c7_with_no_cut_the_class_cooldown_is_kept_even_below_the_minimum() -> void:
	var quick: ClassData = _class.duplicate()
	quick.dash_cooldown = 0.1
	var no_sword: PlayerLoadout = PlayerLoadout.of(quick, null, _rules)
	assert_eq(no_sword.get_dash_cooldown(), 0.1, "no sword")
	var plain: SwordData = ItemFixtures.make_sword(&"a", 44)
	assert_eq(
		PlayerLoadout.of(quick, plain, _rules).get_dash_cooldown(), 0.1, "a sword with no cut"
	)


func test_c7_mending_gives_its_bonus() -> void:
	var sword: SwordData = ItemFixtures.make_sword(
		&"a", 44, SwordData.Kind.MENDING, [], 0, 0.0, 0.1
	)
	assert_almost_eq(PlayerLoadout.of(_class, sword, _rules).get_room_heal_bonus(), 0.1, 0.00001)


func test_c7_a_loadout_reads_the_class_it_was_built_from() -> void:
	var other: ClassData = _class.duplicate()
	other.max_hp = 150
	other.dash_cooldown = 0.5
	var sword: SwordData = ItemFixtures.make_sword(&"a", 44, SwordData.Kind.VITALITY, [], 8)
	var loadout: PlayerLoadout = PlayerLoadout.of(other, sword, _rules)
	assert_eq(loadout.get_max_hp(), 158)
	assert_eq(loadout.get_dash_cooldown(), 0.5)


func test_c7_without_rules_there_is_no_floor_for_the_cooldown() -> void:
	var sword: SwordData = ItemFixtures.make_sword(&"a", 44, SwordData.Kind.QUICKSTEP, [], 0, 0.3)
	assert_almost_eq(PlayerLoadout.of(_class, sword, null).get_dash_cooldown(), 0.05, 0.00001)
