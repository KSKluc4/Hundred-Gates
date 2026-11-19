extends GutTest
## F-013 T1 (AC6): CameraTunables refuses a speed of 0 or less and a negative margin; the shipped
## file is valid and has the design values.

var _tunables: CameraTunables


func before_each() -> void:
	_tunables = CameraTunables.new()


func test_ac6_defaults_are_valid_and_match_the_design_values() -> void:
	assert_eq(_tunables.validate(), PackedStringArray())
	assert_true(_tunables.follow_smoothing_enabled)
	assert_almost_eq(_tunables.follow_smoothing_speed, 8.0, 0.0001)
	assert_eq(_tunables.outside_margin_tiles, 2)


func test_ac6_shipped_file_is_valid_and_has_the_design_values() -> void:
	assert_is(load(Tunables.CAMERA_TUNABLES_PATH), CameraTunables)
	assert_is(Tunables.camera, CameraTunables)
	assert_eq(Tunables.camera.validate(), PackedStringArray())
	assert_true(Tunables.camera.follow_smoothing_enabled)
	assert_almost_eq(Tunables.camera.follow_smoothing_speed, 8.0, 0.0001)
	assert_eq(Tunables.camera.outside_margin_tiles, 2)


func test_ac6_the_autoload_serves_the_file_itself() -> void:
	assert_same(Tunables.camera, load(Tunables.CAMERA_TUNABLES_PATH))


func test_ac6_rejects_a_speed_of_zero() -> void:
	_tunables.follow_smoothing_speed = 0.0
	_assert_one_error("follow_smoothing_speed")


func test_ac6_rejects_a_negative_speed() -> void:
	_tunables.follow_smoothing_speed = -0.5
	_assert_one_error("follow_smoothing_speed")


func test_ac6_rejects_nan_speed() -> void:
	_tunables.follow_smoothing_speed = NAN
	_assert_one_error("follow_smoothing_speed")


func test_ac6_accepts_a_tiny_positive_speed() -> void:
	_tunables.follow_smoothing_speed = 0.001
	assert_eq(_tunables.validate(), PackedStringArray())


func test_ac6_rejects_a_negative_margin() -> void:
	_tunables.outside_margin_tiles = -1
	_assert_one_error("outside_margin_tiles")


func test_ac6_accepts_a_margin_of_zero() -> void:
	_tunables.outside_margin_tiles = 0
	assert_eq(_tunables.validate(), PackedStringArray())


func test_ac6_every_error_is_returned() -> void:
	_tunables.follow_smoothing_speed = 0.0
	_tunables.outside_margin_tiles = -3
	assert_eq(_tunables.validate().size(), 2)


func test_ac6_smoothing_off_is_valid() -> void:
	_tunables.follow_smoothing_enabled = false
	assert_eq(_tunables.validate(), PackedStringArray())


func _assert_one_error(needle: String) -> void:
	var errors: PackedStringArray = _tunables.validate()
	assert_eq(errors.size(), 1, str(errors))
	if errors.size() == 1:
		assert_true(errors[0].contains(needle), errors[0])
