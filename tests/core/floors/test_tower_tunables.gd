extends GutTest
## F-012 T1 (AC1): TowerTunables refuses negative times; the shipped file is valid.

var _tunables: TowerTunables


func before_each() -> void:
	_tunables = TowerTunables.new()


func test_ac1_defaults_are_valid() -> void:
	assert_eq(_tunables.validate(), PackedStringArray())


func test_ac1_shipped_file_is_valid_and_has_the_design_values() -> void:
	assert_is(load(Tunables.TOWER_TUNABLES_PATH), TowerTunables)
	assert_is(Tunables.tower, TowerTunables)
	assert_eq(Tunables.tower.validate(), PackedStringArray())
	assert_almost_eq(Tunables.tower.death_return_delay, 1.5, 0.0001)
	assert_almost_eq(Tunables.tower.banner_duration, 2.5, 0.0001)


func test_ac1_rejects_a_negative_death_return_delay() -> void:
	_tunables.death_return_delay = -0.1
	_assert_one_error("death_return_delay")


func test_ac1_rejects_a_negative_banner_duration() -> void:
	_tunables.banner_duration = -0.1
	_assert_one_error("banner_duration")


func test_ac1_accepts_zero() -> void:
	_tunables.death_return_delay = 0.0
	_tunables.banner_duration = 0.0
	assert_eq(_tunables.validate(), PackedStringArray())


func test_ac1_rejects_nan() -> void:
	_tunables.death_return_delay = NAN
	_assert_one_error("death_return_delay")


func test_ac1_every_error_is_returned() -> void:
	_tunables.death_return_delay = -1.0
	_tunables.banner_duration = -1.0
	assert_eq(_tunables.validate().size(), 2)


func _assert_one_error(needle: String) -> void:
	var errors: PackedStringArray = _tunables.validate()
	assert_eq(errors.size(), 1, str(errors))
	if errors.size() == 1:
		assert_true(errors[0].contains(needle), errors[0])
