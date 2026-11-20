# gdlint:disable=max-public-methods
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


# --- F-013 T5 (AC10, C7): the one-screen rule ---


func test_ac10_the_screen_size_defaults_to_no_rule() -> void:
	assert_eq(TowerData.new().screen_size_tiles, Vector2i.ZERO)
	var tower: TowerData = TowerFixtures.tower_of(3)
	assert_eq(tower.screen_size_tiles, Vector2i.ZERO)
	assert_eq(
		tower.validate(_rules), PackedStringArray(), "the fixture rooms are 12 x 8 and 24 x 14"
	)


func test_ac10_with_no_rule_any_room_the_floor_rules_accept_is_accepted() -> void:
	var tower: TowerData = _screen_tower(Vector2i(8, 6), [[Vector2i(8, 6), Vector2i(8, 6)]])
	assert_eq(tower.screen_size_tiles, Vector2i.ZERO)
	assert_eq(tower.validate(_rules), PackedStringArray())


func test_ac10_rooms_exactly_one_screen_large_are_accepted() -> void:
	var tower: TowerData = _screen_tower(Vector2i(20, 10), [[Vector2i(20, 10), Vector2i(20, 10)]])
	tower.screen_size_tiles = Vector2i(20, 10)
	assert_eq(tower.validate(_rules), PackedStringArray())


func test_ac10_larger_rooms_are_accepted() -> void:
	var tower: TowerData = _screen_tower(Vector2i(30, 16), [[Vector2i(24, 12), Vector2i(22, 11)]])
	tower.screen_size_tiles = Vector2i(20, 10)
	assert_eq(tower.validate(_rules), PackedStringArray())


func test_ac10_a_town_narrower_than_the_screen_is_one_error_naming_it() -> void:
	var tower: TowerData = _screen_tower(Vector2i(19, 10), [[Vector2i(20, 10), Vector2i(20, 10)]])
	tower.screen_size_tiles = Vector2i(20, 10)
	assert_eq(
		tower.validate(_rules),
		PackedStringArray(["town: screen: room town is 19 x 10, smaller than one screen (20 x 10)"])
	)


func test_ac10_a_town_lower_than_the_screen_is_one_error_naming_it() -> void:
	var tower: TowerData = _screen_tower(Vector2i(20, 9), [[Vector2i(20, 10), Vector2i(20, 10)]])
	tower.screen_size_tiles = Vector2i(20, 10)
	assert_eq(
		tower.validate(_rules),
		PackedStringArray(["town: screen: room town is 20 x 9, smaller than one screen (20 x 10)"])
	)


func test_ac10_a_floor_room_smaller_than_the_screen_names_the_floor_and_the_room() -> void:
	var tower: TowerData = _screen_tower(
		Vector2i(20, 10),
		[
			[Vector2i(20, 10), Vector2i(20, 10)],
			[Vector2i(20, 10), Vector2i(18, 10), Vector2i(20, 10)],
		]
	)
	tower.screen_size_tiles = Vector2i(20, 10)
	assert_eq(
		tower.validate(_rules),
		PackedStringArray(
			["floor 2: screen: room f2_room_2 is 18 x 10, smaller than one screen (20 x 10)"]
		)
	)


func test_ac10_a_boss_room_smaller_than_the_screen_is_refused_too() -> void:
	var tower: TowerData = _screen_tower(Vector2i(20, 10), [[Vector2i(20, 10), Vector2i(20, 9)]])
	tower.screen_size_tiles = Vector2i(20, 10)
	assert_eq(
		tower.validate(_rules),
		PackedStringArray(
			["floor 1: screen: room f1_boss is 20 x 9, smaller than one screen (20 x 10)"]
		)
	)


func test_ac10_a_room_short_on_both_axes_is_one_error_not_two() -> void:
	var tower: TowerData = _screen_tower(Vector2i(20, 10), [[Vector2i(20, 10), Vector2i(10, 8)]])
	tower.screen_size_tiles = Vector2i(20, 10)
	assert_eq(tower.validate(_rules).size(), 1, str(tower.validate(_rules)))


func test_ac10_every_small_room_is_named_town_first_then_floors_in_order() -> void:
	var tower: TowerData = _screen_tower(
		Vector2i(19, 10),
		[
			[Vector2i(20, 10), Vector2i(12, 10), Vector2i(20, 10)],
			[Vector2i(20, 9), Vector2i(20, 10)],
		]
	)
	tower.screen_size_tiles = Vector2i(20, 10)
	assert_eq(
		tower.validate(_rules),
		PackedStringArray(
			[
				"town: screen: room town is 19 x 10, smaller than one screen (20 x 10)",
				"floor 1: screen: room f1_room_2 is 12 x 10, smaller than one screen (20 x 10)",
				"floor 2: screen: room f2_room_1 is 20 x 9, smaller than one screen (20 x 10)",
			]
		)
	)


func test_ac10_the_fixture_tower_fails_a_screen_larger_than_its_rooms() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	tower.screen_size_tiles = Vector2i(40, 23)
	var errors: PackedStringArray = tower.validate(_rules)
	assert_eq(errors.size(), 5, "the town, and two rooms on each floor: %s" % errors)
	assert_true(_has_error(errors, "town: screen: room town is 24 x 14"), str(errors))
	assert_true(_has_error(errors, "(40 x 23)"), str(errors))


func test_ac10_the_screen_rule_adds_to_the_other_errors() -> void:
	var tower: TowerData = _screen_tower(Vector2i(20, 10), [[Vector2i(20, 10), Vector2i(18, 10)]])
	tower.screen_size_tiles = Vector2i(20, 10)
	tower.floors[0].floor_number = 4
	var errors: PackedStringArray = tower.validate(_rules)
	assert_true(_has_error(errors, "floor 1: floor_number must be 1, is 4"), str(errors))
	assert_true(_has_error(errors, "floor 1: screen: room f1_boss is 18 x 10"), str(errors))


func test_ac10_a_missing_town_or_floor_does_not_break_the_check() -> void:
	var tower: TowerData = _screen_tower(Vector2i(20, 10), [[Vector2i(20, 10), Vector2i(20, 10)]])
	tower.screen_size_tiles = Vector2i(20, 10)
	tower.town = null
	tower.floors.append(null)
	var errors: PackedStringArray = tower.validate(_rules)
	assert_eq(errors.size(), 2, str(errors))
	assert_true(_has_error(errors, "town: the tower needs a town"), str(errors))
	assert_true(_has_error(errors, "floor 2: must not be null"), str(errors))


## A tower with its own room sizes: a safe town `town_size`, then one floor per entry of
## `floor_sizes`, each a list of room sizes whose last is the boss room. Ids: `town`,
## `f<n>_room_<k>`,
## `f<n>_boss`. `screen_size_tiles` is left at zero.
func _screen_tower(town_size: Vector2i, floor_sizes: Array) -> TowerData:
	var data: TowerData = TowerData.new()
	data.town = TowerFixtures.safe_room_with(&"town", _open_rows(town_size, false))
	var list: Array[FloorData] = []
	for index: int in floor_sizes.size():
		var floor_data: FloorData = FloorData.new()
		floor_data.floor_number = index + 1
		var rooms: Array[RoomData] = []
		var sizes: Array = floor_sizes[index]
		for room_index: int in sizes.size():
			var is_boss: bool = room_index == sizes.size() - 1
			var room_id: StringName = StringName(
				"f%d_boss" % (index + 1) if is_boss else "f%d_room_%d" % [index + 1, room_index + 1]
			)
			rooms.append(
				RoomFixtures.room(room_id, _open_rows(sizes[room_index], true), [], is_boss)
			)
		floor_data.rooms = rooms
		list.append(floor_data)
	data.floors = list
	return data


## A walled room: `P` at (1, 3), a 2-tile exit on the east border at rows 3 and 4 and, when
## `with_spawn`, a `1` near the east wall.
func _open_rows(size: Vector2i, with_spawn: bool) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for y: int in size.y:
		if y == 0 or y == size.y - 1:
			rows.append("#".repeat(size.x))
		else:
			rows.append("#" + ".".repeat(size.x - 2) + "#")
	rows = RoomFixtures.with_tile(rows, 1, 3, "P")
	rows = RoomFixtures.with_tile(rows, size.x - 1, 3, "E")
	rows = RoomFixtures.with_tile(rows, size.x - 1, 4, "E")
	if with_spawn:
		rows = RoomFixtures.with_tile(rows, size.x - 3, 2, "1")
	return rows
