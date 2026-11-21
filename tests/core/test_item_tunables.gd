extends GutTest
## F-016 T1 (C4): ItemTunables and the shipped data/tunables/items.tres.

var _tunables: ItemTunables


func before_each() -> void:
	_tunables = ItemTunables.new()


func test_c4_the_class_defaults_are_the_design_values() -> void:
	assert_eq(_tunables.max_chain_damage, 49)
	assert_eq(_tunables.max_light_hits_damage, 29)
	assert_eq(_tunables.max_finisher_damage, 29)
	assert_eq(_tunables.max_hp_bonus_cap, 8)
	assert_almost_eq(_tunables.min_dash_cooldown, 0.2, 0.0001)
	assert_almost_eq(_tunables.pickup_radius_tiles, 0.8, 0.0001)
	assert_eq(_tunables.equipment_page_size, 8)
	assert_eq(_tunables.validate(), PackedStringArray())


func test_c4_the_shipped_file_is_an_item_tunables_with_the_design_values() -> void:
	var loaded: Resource = load(Tunables.ITEM_TUNABLES_PATH)
	assert_is(loaded, ItemTunables)
	assert_same(Tunables.items, loaded, "the autoload exposes the shipped file")
	assert_eq(Tunables.items.validate(), PackedStringArray())
	assert_eq(Tunables.items.max_chain_damage, 49)
	assert_eq(Tunables.items.max_light_hits_damage, 29)
	assert_eq(Tunables.items.max_finisher_damage, 29)
	assert_eq(Tunables.items.max_hp_bonus_cap, 8)
	assert_almost_eq(Tunables.items.min_dash_cooldown, 0.2, 0.0001)
	assert_almost_eq(Tunables.items.pickup_radius_tiles, 0.8, 0.0001)
	assert_eq(Tunables.items.equipment_page_size, 8)


func test_c4_the_autoload_path_is_the_shipped_file() -> void:
	assert_eq(Tunables.ITEM_TUNABLES_PATH, "res://data/tunables/items.tres")
	assert_true(FileAccess.file_exists(Tunables.ITEM_TUNABLES_PATH))


func test_c4_refuses_a_chain_cap_below_1() -> void:
	_tunables.max_chain_damage = 0
	_assert_one_error("max_chain_damage")


func test_c4_refuses_a_light_hits_cap_below_1() -> void:
	_tunables.max_light_hits_damage = 0
	_assert_one_error("max_light_hits_damage")


func test_c4_refuses_a_finisher_cap_below_1() -> void:
	_tunables.max_finisher_damage = 0
	_assert_one_error("max_finisher_damage")


func test_c4_refuses_a_max_hp_cap_below_1() -> void:
	_tunables.max_hp_bonus_cap = 0
	_assert_one_error("max_hp_bonus_cap")


func test_c4_refuses_a_negative_minimum_cooldown_and_accepts_zero() -> void:
	_tunables.min_dash_cooldown = -0.1
	_assert_one_error("min_dash_cooldown")
	_tunables.min_dash_cooldown = 0.0
	assert_eq(_tunables.validate(), PackedStringArray())


func test_c4_refuses_a_pickup_radius_of_zero_or_less() -> void:
	_tunables.pickup_radius_tiles = 0.0
	_assert_one_error("pickup_radius_tiles")
	_tunables.pickup_radius_tiles = -1.0
	_assert_one_error("pickup_radius_tiles")


func test_c4_refuses_a_page_size_below_1() -> void:
	_tunables.equipment_page_size = 0
	_assert_one_error("equipment_page_size")


func test_c4_refuses_nan() -> void:
	_tunables.min_dash_cooldown = NAN
	_assert_one_error("min_dash_cooldown")


func test_c4_every_error_is_returned() -> void:
	_tunables.max_chain_damage = 0
	_tunables.pickup_radius_tiles = 0.0
	_tunables.equipment_page_size = 0
	assert_eq(_tunables.validate().size(), 3)


func _assert_one_error(needle: String) -> void:
	var errors: PackedStringArray = _tunables.validate()
	assert_eq(errors.size(), 1, str(errors))
	if errors.size() == 1:
		assert_true(errors[0].contains(needle), errors[0])
