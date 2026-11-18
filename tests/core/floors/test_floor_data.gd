extends GutTest
## F-011 T1 (AC3): FloorData refuses a floor that isn't a chain of rooms ending in the boss room.

var _rules: FloorTunables


func before_each() -> void:
	_rules = RoomFixtures.rules()


func test_ac3_valid_floor_passes() -> void:
	assert_eq(RoomFixtures.valid_floor(2).validate(_rules), PackedStringArray())
	assert_eq(RoomFixtures.valid_floor(2).get_room_count(), 3)


func test_ac3_rejects_fewer_than_two_rooms() -> void:
	var floor_data: FloorData = RoomFixtures.valid_floor(0)
	assert_eq(floor_data.get_room_count(), 1)
	_assert_one_error(floor_data.validate(_rules), "at least 2 rooms")
	floor_data.rooms = [] as Array[RoomData]
	assert_true(_has_error(floor_data.validate(_rules), "at least 2 rooms"))


func test_ac3_rejects_a_null_room() -> void:
	var floor_data: FloorData = RoomFixtures.valid_floor(2)
	floor_data.rooms[0] = null
	_assert_one_error(floor_data.validate(_rules), "rooms[0] must not be null")


func test_ac3_rejects_a_boss_room_that_is_not_last() -> void:
	var floor_data: FloorData = RoomFixtures.valid_floor(2)
	floor_data.rooms[0] = RoomFixtures.valid_boss_room(&"early_boss")
	_assert_one_error(floor_data.validate(_rules), "early_boss): a boss room must be the last")


func test_ac3_rejects_a_last_room_that_is_not_a_boss_room() -> void:
	var floor_data: FloorData = RoomFixtures.valid_floor(2)
	floor_data.rooms[2] = RoomFixtures.valid_room(&"last")
	_assert_one_error(floor_data.validate(_rules), "last): the last room must be a boss room")


func test_ac3_rejects_duplicate_room_ids() -> void:
	var floor_data: FloorData = RoomFixtures.valid_floor(2)
	floor_data.rooms[1] = RoomFixtures.valid_room(&"room_1")
	_assert_one_error(floor_data.validate(_rules), "duplicate room id room_1")


func test_ac3_prefixes_room_errors_with_the_room_id() -> void:
	var floor_data: FloorData = RoomFixtures.valid_floor(2)
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 1, 3, ".")
	floor_data.rooms[1] = RoomFixtures.room(&"broken", rows)
	var errors: PackedStringArray = floor_data.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].begins_with("room broken: player_start:"), errors[0])


func test_ac3_returns_every_error() -> void:
	var floor_data: FloorData = RoomFixtures.valid_floor(2)
	floor_data.rooms[1] = RoomFixtures.valid_room(&"room_1")
	floor_data.rooms[2] = RoomFixtures.valid_room(&"last")
	var errors: PackedStringArray = floor_data.validate(_rules)
	assert_true(_has_error(errors, "duplicate room id"), str(errors))
	assert_true(_has_error(errors, "must be a boss room"), str(errors))


func _assert_one_error(errors: PackedStringArray, needle: String) -> void:
	assert_eq(errors.size(), 1, str(errors))
	assert_true(_has_error(errors, needle), "no error contains '%s': %s" % [needle, errors])


func _has_error(errors: PackedStringArray, needle: String) -> bool:
	for error: String in errors:
		if error.contains(needle):
			return true
	return false
