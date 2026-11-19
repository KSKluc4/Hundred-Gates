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
	assert_eq(Tunables.floors.max_room_size, Vector2i(80, 46))
	assert_eq(Tunables.floors.exit_min_width_tiles, 2)
	assert_almost_eq(Tunables.floors.min_spawn_distance_tiles, 4.0, 0.0001)
	# F-014/C4
	assert_eq(Tunables.floors.wave_max_engaged, 3)
	assert_almost_eq(Tunables.floors.wave_spawn_warning_duration, 0.8, 0.0001)
	assert_almost_eq(Tunables.floors.wave_spawn_interval, 1.5, 0.0001)
	assert_almost_eq(Tunables.floors.wave_min_spawn_distance_tiles, 6.0, 0.0001)
	assert_almost_eq(Tunables.floors.wave_spawn_gap_tiles, 1.5, 0.0001)
	assert_eq(Tunables.floors.wave_min_arrival_points, 2)
	assert_eq(Tunables.floors.max_kill_target, 30)
	assert_eq(Tunables.floors.wave_arrival_box_tiles, Vector2(19, 10))


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


# --- F-014 T1 (AC3): the wave tunables ---


func test_ac3_rejects_a_wave_max_engaged_below_one() -> void:
	_tunables.wave_max_engaged = 0
	_assert_one_error("wave_max_engaged must be >= 1")
	_tunables.wave_max_engaged = 1
	assert_eq(_tunables.validate(), PackedStringArray())


func test_ac3_rejects_a_negative_warning_duration_and_accepts_zero() -> void:
	_tunables.wave_spawn_warning_duration = -0.1
	_assert_one_error("wave_spawn_warning_duration must be >= 0")
	_tunables.wave_spawn_warning_duration = 0.0
	assert_eq(_tunables.validate(), PackedStringArray())


func test_ac3_rejects_a_negative_spawn_interval_and_accepts_zero() -> void:
	_tunables.wave_spawn_interval = -1.0
	_assert_one_error("wave_spawn_interval must be >= 0")
	_tunables.wave_spawn_interval = 0.0
	assert_eq(_tunables.validate(), PackedStringArray())


func test_ac3_rejects_a_negative_min_spawn_distance_and_accepts_zero() -> void:
	_tunables.wave_min_spawn_distance_tiles = -0.5
	_assert_one_error("wave_min_spawn_distance_tiles must be >= 0")
	_tunables.wave_min_spawn_distance_tiles = 0.0
	assert_eq(_tunables.validate(), PackedStringArray())


func test_ac3_rejects_a_negative_spawn_gap_and_accepts_zero() -> void:
	_tunables.wave_spawn_gap_tiles = -2.0
	_assert_one_error("wave_spawn_gap_tiles must be >= 0")
	_tunables.wave_spawn_gap_tiles = 0.0
	assert_eq(_tunables.validate(), PackedStringArray())


func test_ac3_rejects_fewer_than_one_arrival_point_and_a_kill_target_limit_below_one() -> void:
	_tunables.wave_min_arrival_points = 0
	_assert_one_error("wave_min_arrival_points must be >= 1")
	_tunables.wave_min_arrival_points = 1
	assert_eq(_tunables.validate(), PackedStringArray())
	_tunables.max_kill_target = 0
	_assert_one_error("max_kill_target must be >= 1")
	_tunables.max_kill_target = 1
	assert_eq(_tunables.validate(), PackedStringArray())


func test_ac3_rejects_an_arrival_box_that_is_not_positive_on_both_axes() -> void:
	_tunables.wave_arrival_box_tiles = Vector2(0.0, 10.0)
	_assert_one_error("wave_arrival_box_tiles must be > 0")
	_tunables.wave_arrival_box_tiles = Vector2(19.0, -1.0)
	_assert_one_error("wave_arrival_box_tiles must be > 0")
	_tunables.wave_arrival_box_tiles = Vector2(0.5, 0.5)
	assert_eq(_tunables.validate(), PackedStringArray())


func test_ac3_a_nan_fails_every_float_check() -> void:
	_tunables.wave_spawn_warning_duration = NAN
	_assert_one_error("wave_spawn_warning_duration")
	_tunables.wave_spawn_warning_duration = 0.8
	_tunables.wave_spawn_interval = NAN
	_assert_one_error("wave_spawn_interval")
	_tunables.wave_spawn_interval = 1.5
	_tunables.wave_min_spawn_distance_tiles = NAN
	_assert_one_error("wave_min_spawn_distance_tiles")
	_tunables.wave_min_spawn_distance_tiles = 6.0
	_tunables.wave_spawn_gap_tiles = NAN
	_assert_one_error("wave_spawn_gap_tiles")
	_tunables.wave_spawn_gap_tiles = 1.5
	_tunables.wave_arrival_box_tiles = Vector2(NAN, 10.0)
	_assert_one_error("wave_arrival_box_tiles")
	_tunables.wave_arrival_box_tiles = Vector2(19.0, NAN)
	_assert_one_error("wave_arrival_box_tiles")


func test_ac3_every_bad_wave_value_is_its_own_error() -> void:
	_tunables.wave_max_engaged = 0
	_tunables.wave_spawn_warning_duration = -1.0
	_tunables.wave_spawn_interval = -1.0
	_tunables.wave_min_spawn_distance_tiles = -1.0
	_tunables.wave_spawn_gap_tiles = -1.0
	_tunables.wave_min_arrival_points = 0
	_tunables.max_kill_target = 0
	_tunables.wave_arrival_box_tiles = Vector2.ZERO
	assert_eq(_tunables.validate().size(), 8, str(_tunables.validate()))


func _assert_one_error(needle: String) -> void:
	var errors: PackedStringArray = _tunables.validate()
	assert_eq(errors.size(), 1, str(errors))
	if errors.size() == 1:
		assert_true(errors[0].contains(needle), errors[0])
