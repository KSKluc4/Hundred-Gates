extends GutTest
## F-011 T1 (AC4): FloorTunables refuses numbers that make no sense.

var _tunables: FloorTunables


func before_each() -> void:
	_tunables = FloorTunables.new()


func test_defaults_are_valid() -> void:
	assert_eq(_tunables.validate(), PackedStringArray())


func test_shipped_file_is_valid_and_matches_the_design() -> void:
	assert_is(load(Tunables.FLOORS_PATH), FloorTunables)
	assert_eq(Tunables.floors.validate(), PackedStringArray())
	assert_almost_eq(Tunables.floors.room_clear_heal_fraction, 0.30, 0.0001)
	assert_true(Tunables.floors.boss_room_full_heal)
	assert_eq(Tunables.floors.max_enemies_per_room, 6)
	assert_eq(Tunables.floors.min_room_size, Vector2i(8, 6))
	assert_eq(Tunables.floors.max_room_size, Vector2i(40, 22))
	assert_eq(Tunables.floors.exit_min_width_tiles, 2)
	assert_almost_eq(Tunables.floors.min_spawn_distance_tiles, 4.0, 0.0001)


func test_ac4_rejects_a_heal_fraction_outside_zero_to_one() -> void:
	_tunables.room_clear_heal_fraction = -0.1
	_assert_one_error("room_clear_heal_fraction")
	_tunables.room_clear_heal_fraction = 1.1
	_assert_one_error("room_clear_heal_fraction")


func test_ac4_accepts_the_ends_of_the_heal_range() -> void:
	_tunables.room_clear_heal_fraction = 0.0
	assert_eq(_tunables.validate(), PackedStringArray())
	_tunables.room_clear_heal_fraction = 1.0
	assert_eq(_tunables.validate(), PackedStringArray())


func test_ac4_rejects_a_non_positive_min_room_size() -> void:
	_tunables.min_room_size = Vector2i(0, 6)
	_assert_one_error("min_room_size must be > 0")
	_tunables.min_room_size = Vector2i(8, -1)
	_assert_one_error("min_room_size must be > 0")


func test_ac4_rejects_a_non_positive_max_room_size() -> void:
	_tunables.min_room_size = Vector2i(1, 1)
	_tunables.max_room_size = Vector2i(40, 0)
	var errors: PackedStringArray = _tunables.validate()
	assert_true(errors[0].contains("max_room_size must be > 0"), str(errors))


func test_ac4_rejects_min_size_above_max_size() -> void:
	_tunables.min_room_size = Vector2i(41, 6)
	_assert_one_error("must not exceed")
	_tunables.min_room_size = Vector2i(8, 23)
	_assert_one_error("must not exceed")


func test_ac4_rejects_fewer_than_one_enemy_per_room() -> void:
	_tunables.max_enemies_per_room = 0
	_assert_one_error("max_enemies_per_room")


func test_rejects_a_narrow_exit_and_a_negative_spawn_distance() -> void:
	_tunables.exit_min_width_tiles = 0
	_assert_one_error("exit_min_width_tiles")
	_tunables.exit_min_width_tiles = 2
	_tunables.min_spawn_distance_tiles = -1.0
	_assert_one_error("min_spawn_distance_tiles")


func test_every_error_is_returned() -> void:
	_tunables.room_clear_heal_fraction = 2.0
	_tunables.max_enemies_per_room = 0
	assert_eq(_tunables.validate().size(), 2)


func _assert_one_error(needle: String) -> void:
	var errors: PackedStringArray = _tunables.validate()
	assert_eq(errors.size(), 1, str(errors))
	if errors.size() == 1:
		assert_true(errors[0].contains(needle), errors[0])
