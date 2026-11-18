extends GutTest
## F-012 T1 (AC2, AC3): a safe room has no spawns, no enemies and is no boss room; every other
## room rule still applies to it; a floor refuses one.

var _rules: FloorTunables


func before_each() -> void:
	_rules = TowerFixtures.rules()


# --- AC2 ---


func test_ac2_a_safe_room_with_no_spawns_and_no_enemies_passes() -> void:
	var room: RoomData = TowerFixtures.safe_room()
	assert_true(room.is_safe_room)
	assert_eq(room.validate(_rules), PackedStringArray())


func test_ac2_the_town_fixture_passes_with_the_gate_on_every_border() -> void:
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var room: RoomData = TowerFixtures.town_room(&"town", side)
		assert_eq(room.validate(_rules), PackedStringArray(), str(side))
		assert_eq(room.get_exit_tiles(), TowerFixtures.gate_tiles(side), str(side))


func test_ac2_is_safe_room_is_off_by_default() -> void:
	assert_false(RoomData.new().is_safe_room)
	assert_false(RoomFixtures.valid_room().is_safe_room)


func test_ac2_a_spawn_is_rejected_naming_the_rule() -> void:
	var room: RoomData = TowerFixtures.safe_room_with(&"safe", RoomFixtures.valid_rows())
	room.enemies = [RoomFixtures.chaser()] as Array[EnemyData]
	var errors: PackedStringArray = room.validate(_rules)
	assert_true(_has_error(errors, "spawn_count", "found 1"), str(errors))


func test_ac2_enemies_in_the_list_are_rejected_naming_the_rule() -> void:
	var room: RoomData = TowerFixtures.safe_room()
	room.enemies = [RoomFixtures.chaser()] as Array[EnemyData]
	var errors: PackedStringArray = room.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(_has_error(errors, "safe_room", "enemies"), str(errors))


func test_ac2_a_boss_room_flag_is_rejected_naming_the_rule() -> void:
	var room: RoomData = TowerFixtures.safe_room()
	room.is_boss_room = true
	var errors: PackedStringArray = room.validate(_rules)
	assert_eq(errors.size(), 1, "no boss spawn_count error on top: %s" % errors)
	assert_true(_has_error(errors, "safe_room", "boss"), str(errors))


func test_ac2_each_failure_is_its_own_error() -> void:
	var room: RoomData = TowerFixtures.safe_room_with(&"safe", RoomFixtures.valid_rows())
	room.enemies = [RoomFixtures.chaser()] as Array[EnemyData]
	room.is_boss_room = true
	var errors: PackedStringArray = room.validate(_rules)
	assert_true(_has_error(errors, "spawn_count", ""), str(errors))
	assert_true(_has_error(errors, "safe_room", "enemies"), str(errors))
	assert_true(_has_error(errors, "safe_room", "boss"), str(errors))


func test_ac2_a_safe_room_without_p_is_rejected() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(TowerFixtures.safe_rows(), 1, 3, ".")
	var errors: PackedStringArray = TowerFixtures.safe_room_with(&"safe", rows).validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(_has_error(errors, "player_start", "found 0"), str(errors))


func test_ac2_a_safe_room_without_an_exit_is_rejected() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(TowerFixtures.safe_rows(), 11, 3, "#")
	rows = RoomFixtures.with_tile(rows, 11, 4, "#")
	var errors: PackedStringArray = TowerFixtures.safe_room_with(&"safe", rows).validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(_has_error(errors, "exit", "found 0"), str(errors))


func test_ac2_a_safe_room_still_obeys_the_size_and_wall_rules() -> void:
	_rules.max_room_size = Vector2i(10, 8)
	assert_true(_has_error(TowerFixtures.safe_room().validate(_rules), "size", ""))
	var rows: PackedStringArray = RoomFixtures.with_tile(TowerFixtures.safe_rows(), 6, 4, "#")
	var errors: PackedStringArray = TowerFixtures.safe_room_with(&"safe", rows).validate(
		RoomFixtures.rules()
	)
	assert_true(_has_error(errors, "thin_wall", "(6, 4)"), str(errors))


func test_ac2_a_room_that_is_not_safe_validates_as_before() -> void:
	var no_spawn: RoomData = RoomFixtures.valid_room()
	no_spawn.rows = TowerFixtures.safe_rows()
	var errors: PackedStringArray = no_spawn.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(_has_error(errors, "spawn_count", "a combat room needs"), str(errors))
	var boss_without_spawn: RoomData = RoomFixtures.valid_boss_room()
	boss_without_spawn.rows = TowerFixtures.safe_rows()
	errors = boss_without_spawn.validate(_rules)
	assert_true(_has_error(errors, "spawn_count", "a boss room needs"), str(errors))


# --- AC3 ---


func test_ac3_a_floor_with_a_safe_room_is_rejected_naming_index_and_id() -> void:
	var floor_data: FloorData = TowerFixtures.floor_of(1, 2)
	floor_data.rooms[1] = TowerFixtures.safe_room(&"hall")
	var errors: PackedStringArray = floor_data.validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].contains("rooms[1] (hall): a safe room"), errors[0])


func test_ac3_a_floor_without_a_safe_room_still_passes() -> void:
	assert_eq(TowerFixtures.floor_of(1, 2).validate(_rules), PackedStringArray())


func _has_error(errors: PackedStringArray, rule: String, needle: String) -> bool:
	for error: String in errors:
		if error.begins_with(rule + ":") and (needle.is_empty() or error.contains(needle)):
			return true
	return false
