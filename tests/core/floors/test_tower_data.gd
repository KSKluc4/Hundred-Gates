extends GutTest
## F-012 T1 (AC4): TowerData refuses a tower that isn't a safe town plus floors numbered in order
## with room ids unique across it.

var _rules: FloorTunables


func before_each() -> void:
	_rules = TowerFixtures.rules()


func test_ac4_valid_tower_passes() -> void:
	assert_eq(TowerFixtures.tower_of(3).validate(_rules), PackedStringArray())
	assert_eq(TowerFixtures.tower_of(1).validate(_rules), PackedStringArray())


func test_ac4_get_floor_count_and_get_floor() -> void:
	var tower: TowerData = TowerFixtures.tower_of(3)
	assert_eq(tower.get_floor_count(), 3)
	assert_eq(tower.get_floor(1), tower.floors[0])
	assert_eq(tower.get_floor(3), tower.floors[2])
	assert_eq(tower.get_floor(2).floor_number, 2)


func test_ac4_get_floor_is_null_outside_one_to_count() -> void:
	var tower: TowerData = TowerFixtures.tower_of(3)
	for number: int in [0, -1, 4, 99]:
		assert_null(tower.get_floor(number), "floor %d" % number)
	assert_null(TowerData.new().get_floor(1), "an empty tower has no floors")


func test_ac4_rejects_no_town() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	tower.town = null
	var errors: PackedStringArray = tower.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].begins_with("town: "), errors[0])


func test_ac4_rejects_a_town_that_is_not_a_safe_room() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	tower.town.is_safe_room = false
	var errors: PackedStringArray = tower.validate(_rules)
	assert_true(_has_error(errors, "town: the town must be a safe room"), str(errors))
	assert_true(_has_error(errors, "town: spawn_count:"), "it fails the combat rules: %s" % errors)


func test_ac4_rejects_no_floors() -> void:
	var tower: TowerData = TowerFixtures.tower_of(0)
	var errors: PackedStringArray = tower.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].contains("at least 1 floor"), errors[0])


func test_ac4_rejects_a_null_floor() -> void:
	var tower: TowerData = TowerFixtures.tower_of(3)
	tower.floors[1] = null
	var errors: PackedStringArray = tower.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_eq(errors[0], "floor 2: must not be null")


func test_ac4_rejects_a_floor_number_that_is_not_position_plus_one() -> void:
	var tower: TowerData = TowerFixtures.tower_of(3)
	tower.floors[1].floor_number = 5
	var errors: PackedStringArray = tower.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].begins_with("floor 2: floor_number must be 2, is 5"), errors[0])


func test_ac4_rejects_floors_in_the_wrong_order() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	var first: FloorData = tower.floors[0]
	tower.floors[0] = tower.floors[1]
	tower.floors[1] = first
	var errors: PackedStringArray = tower.validate(_rules)
	assert_true(_has_error(errors, "floor 1: floor_number must be 1, is 2"), str(errors))
	assert_true(_has_error(errors, "floor 2: floor_number must be 2, is 1"), str(errors))


func test_ac4_rejects_a_room_id_used_in_two_floors() -> void:
	var tower: TowerData = TowerFixtures.tower_of(3)
	tower.floors[2].rooms[0] = RoomFixtures.valid_room(&"f1_room_1")
	var errors: PackedStringArray = tower.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(
		errors[0].begins_with("floor 3: room id f1_room_1 is already used by floor 1"), errors[0]
	)


func test_ac4_rejects_a_floor_room_that_reuses_the_town_id() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	tower.floors[0].rooms[0] = RoomFixtures.valid_room(&"town")
	var errors: PackedStringArray = tower.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].begins_with("floor 1: room id town is already used by town"), errors[0])


func test_ac4_a_repeat_inside_one_floor_is_reported_once_by_the_floor() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2, 2)
	tower.floors[0].rooms[1] = RoomFixtures.valid_room(&"f1_room_1")
	var errors: PackedStringArray = tower.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].begins_with("floor 1: rooms[1]: duplicate room id"), errors[0])


func test_ac4_the_f011_fixture_floors_reuse_ids_so_they_are_refused() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	tower.floors[0] = RoomFixtures.valid_floor(1, 1)
	tower.floors[1] = RoomFixtures.valid_floor(1, 2)
	var errors: PackedStringArray = tower.validate(_rules)
	assert_eq(errors.size(), 2, str(errors))
	assert_true(
		_has_error(errors, "floor 2: room id room_1 is already used by floor 1"), str(errors)
	)
	assert_true(_has_error(errors, "floor 2: room id boss is already used by floor 1"), str(errors))


func test_ac4_town_errors_are_prefixed_with_town() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	tower.town.rows = RoomFixtures.with_tile(tower.town.rows, 11, 10, ".")
	var errors: PackedStringArray = tower.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].begins_with("town: player_start:"), errors[0])


func test_ac4_floor_errors_are_prefixed_with_floor_and_its_number() -> void:
	var tower: TowerData = TowerFixtures.tower_of(3)
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 1, 3, ".")
	tower.floors[2].rooms[0] = RoomFixtures.room(&"broken", rows)
	var errors: PackedStringArray = tower.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].begins_with("floor 3: room broken: player_start:"), errors[0])


func test_ac4_a_safe_room_inside_a_floor_is_refused() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2, 2)
	tower.floors[1].rooms[0] = TowerFixtures.safe_room(&"hall")
	var errors: PackedStringArray = tower.validate(_rules)
	assert_true(_has_error(errors, "floor 2: rooms[0] (hall): a safe room"), str(errors))


func test_ac4_every_error_is_returned() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	tower.town = null
	tower.floors[0].floor_number = 7
	tower.floors[1] = null
	var errors: PackedStringArray = tower.validate(_rules)
	assert_true(_has_error(errors, "town: "), str(errors))
	assert_true(_has_error(errors, "floor 1: floor_number must be 1"), str(errors))
	assert_true(_has_error(errors, "floor 2: must not be null"), str(errors))


func _has_error(errors: PackedStringArray, needle: String) -> bool:
	for error: String in errors:
		if error.contains(needle):
			return true
	return false
