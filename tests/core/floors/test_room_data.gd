# gdlint:disable=max-public-methods
extends GutTest
## F-011 T1 (AC1, AC2): RoomData reads its grid and refuses a room that breaks a C16 rule.

var _rules: FloorTunables


func before_each() -> void:
	_rules = RoomFixtures.rules()


# --- AC1: a valid room passes, then one room per rule that breaks only that rule ---


func test_ac1_valid_room_passes() -> void:
	assert_eq(RoomFixtures.valid_room().validate(_rules), PackedStringArray())


func test_ac1_valid_boss_room_passes() -> void:
	assert_eq(RoomFixtures.valid_boss_room().validate(_rules), PackedStringArray())


func test_ac1_rectangular_rejects_a_short_row() -> void:
	var rows: PackedStringArray = RoomFixtures.valid_rows()
	rows[2] = "#.........#"
	var errors: PackedStringArray = _room(rows).validate(_rules)
	_assert_only_rule(errors, "rectangular", "")
	assert_eq(errors.size(), 1, "a ragged grid is reported once and nothing else is read")


func test_ac1_rectangular_rejects_no_rows() -> void:
	_assert_only_rule(_room(PackedStringArray()).validate(_rules), "rectangular", "")


func test_ac1_size_rejects_a_room_below_the_minimum() -> void:
	_rules.min_room_size = Vector2i(13, 8)
	_assert_only_rule(RoomFixtures.valid_room().validate(_rules), "size", "")


func test_ac1_size_rejects_a_room_above_the_maximum() -> void:
	_rules.max_room_size = Vector2i(40, 7)
	_assert_only_rule(RoomFixtures.valid_room().validate(_rules), "size", "")


func test_ac1_border_rejects_floor_on_the_border() -> void:
	# A floor tile on the border is also a lone floor tile, so the corridor rule fires too.
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 5, 0, ".")
	var errors: PackedStringArray = _room(rows).validate(_rules)
	assert_true(_has_error(errors, "border", "(5, 0)"), str(errors))
	for error: String in errors:
		assert_true(
			error.begins_with("border:") or error.begins_with("corridor:"), "unexpected: " + error
		)


func test_ac1_player_start_rejects_none() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 1, 3, ".")
	_assert_only_rule(_room(rows).validate(_rules), "player_start", "found 0")


func test_ac1_player_start_rejects_two() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 2, 4, "P")
	_assert_only_rule(_room(rows).validate(_rules), "player_start", "found 2")


func test_ac1_exit_rejects_a_run_that_is_too_short() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 11, 4, "#")
	_assert_only_rule(_room(rows).validate(_rules), "exit", "found 1")


func test_ac1_exit_rejects_no_exit() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 11, 4, "#")
	rows = RoomFixtures.with_tile(rows, 11, 3, "#")
	_assert_only_rule(_room(rows).validate(_rules), "exit", "found 0")


func test_ac1_exit_rejects_a_tile_off_the_border() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 5, 3, "E")
	_assert_only_rule(_room(rows).validate(_rules), "exit", "(5, 3)")


func test_ac1_exit_rejects_a_corner() -> void:
	# E run along the top, x = 9..11, the last one on the corner (11, 0).
	var rows: PackedStringArray = RoomFixtures.valid_rows()
	rows[0] = "#########EEE"
	rows = RoomFixtures.with_tile(rows, 11, 3, "#")
	rows = RoomFixtures.with_tile(rows, 11, 4, "#")
	var errors: PackedStringArray = _room(rows).validate(_rules)
	_assert_only_rule(errors, "exit", "(11, 0)")
	assert_eq(errors.size(), 1, "the corner is reported as a corner only")


func test_ac1_exit_rejects_tiles_on_two_sides() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 5, 0, "E")
	rows = RoomFixtures.with_tile(rows, 6, 0, "E")
	_assert_only_rule(_room(rows).validate(_rules), "exit", "one side")


func test_ac1_exit_rejects_a_gap_in_the_run() -> void:
	var rows: PackedStringArray = RoomFixtures.valid_rows()
	rows = RoomFixtures.with_tile(rows, 11, 2, "E")
	rows = RoomFixtures.with_tile(rows, 11, 3, "#")
	_assert_only_rule(_room(rows).validate(_rules), "exit", "(11, 4)")


func test_ac1_exit_rejects_a_run_not_touching_floor() -> void:
	# A 2 x 2 block of wall inside the room, against the exit tiles.
	var rows: PackedStringArray = RoomFixtures.valid_rows()
	for tile: Vector2i in [Vector2i(9, 3), Vector2i(10, 3), Vector2i(9, 4), Vector2i(10, 4)]:
		rows = RoomFixtures.with_tile(rows, tile.x, tile.y, "#")
	var errors: PackedStringArray = _room(rows).validate(_rules)
	_assert_only_rule(errors, "exit", "(11, 3)")
	assert_true(_has_error(errors, "exit", "(11, 4)"))


func test_ac1_reachable_rejects_floor_walled_off_from_p() -> void:
	var rows: PackedStringArray = PackedStringArray(
		[
			"############",
			"#....##....#",
			"#....##....#",
			"#P...##....E",
			"#....##....E",
			"#....##....#",
			"#...1##....#",
			"############",
		]
	)
	var errors: PackedStringArray = _room(rows).validate(_rules)
	_assert_only_rule(errors, "reachable", "(7, 1)")
	assert_false(_has_error(errors, "reachable", "(1, 1)"), "the left half is P's own")


func test_ac1_corridor_rejects_a_one_tile_gap() -> void:
	var rows: PackedStringArray = PackedStringArray(
		[
			"############",
			"#....##....#",
			"#....##....#",
			"#P.........E",
			"#....##....E",
			"#....##..1.#",
			"#....##....#",
			"############",
		]
	)
	var errors: PackedStringArray = _room(rows).validate(_rules)
	_assert_only_rule(errors, "corridor", "(5, 3)")
	assert_true(_has_error(errors, "corridor", "(6, 3)"))
	assert_eq(errors.size(), 2)


func test_ac1_pinch_rejects_two_wall_corners_one_tile_apart() -> void:
	var rows: PackedStringArray = PackedStringArray(
		[
			"################",
			"#..............#",
			"#.........1....#",
			"#..............#",
			"########.......#",
			"########.......#",
			"#........#######",
			"#........#######",
			"#..............#",
			"#P.............E",
			"#..............E",
			"################",
		]
	)
	# The west wall (rows 4-5, x <= 7) and the east wall (rows 6-7, x >= 9) leave one opening.
	var errors: PackedStringArray = _room(rows).validate(_rules)
	_assert_only_rule(errors, "pinch", "(8, 5) and (8, 6)")
	assert_eq(errors.size(), 1, "one pair, reported once")


func test_ac1_pinch_rejects_the_same_opening_turned_on_its_side() -> void:
	var rows: PackedStringArray = PackedStringArray(
		[
			"############",
			"#...##...P.#",
			"#...##.....#",
			"#...##.....#",
			"#...##.....#",
			"#...##.....#",
			"#...##.....#",
			"#...##.....#",
			"#..........#",
			"#.....##...#",
			"#.1...##...#",
			"#.....##...#",
			"#.....##...#",
			"#.....##...#",
			"#.....##...#",
			"#########EE#",
		]
	)
	# The reproduction turned a quarter: the pair is now side by side.
	var errors: PackedStringArray = _room(rows).validate(_rules)
	_assert_only_rule(errors, "pinch", "(5, 8) and (6, 8)")
	assert_eq(errors.size(), 1, "one pair, reported once")


func test_ac1_pinch_accepts_a_two_tile_gap() -> void:
	var rows: PackedStringArray = PackedStringArray(
		[
			"################",
			"#..............#",
			"#.........1....#",
			"#..............#",
			"########.......#",
			"########.......#",
			"#.........######",
			"#.........######",
			"#..............#",
			"#P.............E",
			"#..............E",
			"################",
		]
	)
	# The east wall moved one tile: the opening is 2 wide.
	assert_eq(_room(rows).validate(_rules), PackedStringArray())


func test_ac1_pinch_reports_each_pair_once() -> void:
	var rows: PackedStringArray = PackedStringArray(
		[
			"################",
			"#..............#",
			"#.........1....#",
			"#..............#",
			"########.......#",
			"########.......#",
			"#........#######",
			"#........#######",
			"#..............#",
			"#..............#",
			"########.......#",
			"########.......#",
			"#........#######",
			"#........#######",
			"#..............#",
			"#P.............E",
			"#..............E",
			"################",
		]
	)
	var errors: PackedStringArray = _room(rows).validate(_rules)
	_assert_only_rule(errors, "pinch", "(8, 5) and (8, 6)")
	assert_true(_has_error(errors, "pinch", "(8, 11) and (8, 12)"), str(errors))
	assert_eq(errors.size(), 2, "two pairs, once each: " + str(errors))


func test_ac1_pinch_leaves_a_one_tile_corridor_to_the_corridor_rule() -> void:
	var rows: PackedStringArray = PackedStringArray(
		[
			"############",
			"#....##....#",
			"#....##....#",
			"#P.........E",
			"#....##....E",
			"#....##..1.#",
			"#....##....#",
			"############",
		]
	)
	for error: String in _room(rows).validate(_rules):
		assert_false(error.begins_with("pinch:"), "a corridor tile is not also a pinch: " + error)


func test_ac1_thin_wall_rejects_a_lone_wall_tile() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 6, 4, "#")
	_assert_only_rule(_room(rows).validate(_rules), "thin_wall", "(6, 4)")


func test_ac1_thin_wall_rejects_a_one_tile_thick_wall() -> void:
	var rows: PackedStringArray = RoomFixtures.valid_rows()
	for y: int in [1, 2]:
		rows = RoomFixtures.with_tile(rows, 6, y, "#")
	var errors: PackedStringArray = _room(rows).validate(_rules)
	_assert_only_rule(errors, "thin_wall", "(6, 1)")
	assert_true(_has_error(errors, "thin_wall", "(6, 2)"))


func test_ac1_thick_interior_wall_is_valid() -> void:
	var rows: PackedStringArray = RoomFixtures.valid_rows()
	for tile: Vector2i in [Vector2i(5, 3), Vector2i(6, 3), Vector2i(5, 4), Vector2i(6, 4)]:
		rows = RoomFixtures.with_tile(rows, tile.x, tile.y, "#")
	assert_eq(_room(rows).validate(_rules), PackedStringArray())


func test_ac1_spawn_distance_rejects_a_spawn_near_p() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 3, 3, "1")
	_assert_only_rule(_room(rows).validate(_rules), "spawn_distance", "(3, 3)")


func test_ac1_spawn_distance_accepts_exactly_the_minimum() -> void:
	# (5, 3) is 4.0 tiles from P at (1, 3).
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 5, 3, "1")
	assert_eq(_room(rows).validate(_rules), PackedStringArray())


func test_ac1_spawn_count_rejects_no_spawn_in_a_combat_room() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 9, 5, ".")
	_assert_only_rule(_room(rows).validate(_rules), "spawn_count", "found 0")


func test_ac1_spawn_count_rejects_more_than_the_maximum() -> void:
	_rules.max_enemies_per_room = 1
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 9, 2, "1")
	_assert_only_rule(_room(rows).validate(_rules), "spawn_count", "1 to 1")


func test_ac1_spawn_count_rejects_two_spawns_in_a_boss_room() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 9, 2, "1")
	var room: RoomData = RoomFixtures.room(&"boss", rows, [RoomFixtures.warden()], true)
	_assert_only_rule(room.validate(_rules), "spawn_count", "exactly 1")


func test_ac1_spawn_count_rejects_no_spawn_in_a_boss_room() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 9, 5, ".")
	var room: RoomData = RoomFixtures.room(&"boss", rows, [RoomFixtures.warden()], true)
	_assert_only_rule(room.validate(_rules), "spawn_count", "found 0")


func test_ac1_legend_rejects_an_unknown_character() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 5, 3, "x")
	_assert_only_rule(_room(rows).validate(_rules), "legend", "(5, 3)")


func test_ac1_legend_rejects_a_digit_with_no_enemy() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 9, 2, "2")
	_assert_only_rule(_room(rows).validate(_rules), "legend", "(9, 2)")


func test_ac1_legend_rejects_a_null_enemy() -> void:
	var room: RoomData = RoomFixtures.valid_room()
	room.enemies = [null] as Array[EnemyData]
	_assert_only_rule(room.validate(_rules), "legend", "enemies[0]")


func test_ac1_every_error_is_returned_not_the_first() -> void:
	var rows: PackedStringArray = RoomFixtures.with_tile(RoomFixtures.valid_rows(), 1, 3, ".")
	rows = RoomFixtures.with_tile(rows, 9, 5, ".")
	var errors: PackedStringArray = _room(rows).validate(_rules)
	assert_true(_has_error(errors, "player_start", ""), str(errors))
	assert_true(_has_error(errors, "spawn_count", ""), str(errors))


# --- AC2: what the glue reads ---


func test_ac2_get_size_is_width_by_height() -> void:
	assert_eq(RoomFixtures.valid_room().get_size(), Vector2i(12, 8))


func test_ac2_get_spawns_are_row_major_with_c7_ids_and_tile_centres() -> void:
	var rows: PackedStringArray = RoomFixtures.valid_rows()
	rows = RoomFixtures.with_tile(rows, 8, 1, "2")
	rows = RoomFixtures.with_tile(rows, 5, 1, "1")
	rows = RoomFixtures.with_tile(rows, 3, 6, "1")
	var enemies: Array[EnemyData] = [RoomFixtures.chaser(), RoomFixtures.caster()]
	var spawns: Array[RoomSpawn] = RoomFixtures.room(&"r", rows, enemies).get_spawns()
	# Row 1: (5, 1) then (8, 1); row 5: (9, 5); row 6: (3, 6).
	assert_eq(spawns.size(), 4)
	var ids: Array[StringName] = []
	var positions: Array[Vector2] = []
	var kinds: Array[EnemyData] = []
	for spawn: RoomSpawn in spawns:
		ids.append(spawn.combat_id)
		positions.append(spawn.position_tiles)
		kinds.append(spawn.enemy)
	assert_eq(ids, [&"chaser_1", &"caster_2", &"chaser_3", &"chaser_4"] as Array[StringName])
	assert_eq(
		positions,
		(
			[Vector2(5.5, 1.5), Vector2(8.5, 1.5), Vector2(9.5, 5.5), Vector2(3.5, 6.5)]
			as Array[Vector2]
		)
	)
	assert_eq(kinds, [enemies[0], enemies[1], enemies[0], enemies[0]] as Array[EnemyData])


func test_ac2_player_start_is_the_tile_centre() -> void:
	assert_eq(RoomFixtures.valid_room().get_player_start_tiles(), Vector2(1.5, 3.5))


func test_ac2_exit_tiles_match_the_grid() -> void:
	assert_eq(
		RoomFixtures.valid_room().get_exit_tiles(),
		[Vector2i(11, 3), Vector2i(11, 4)] as Array[Vector2i]
	)


func test_ac2_is_walkable_by_character() -> void:
	var room: RoomData = RoomFixtures.valid_room()
	assert_true(room.is_walkable(Vector2i(2, 2)), "floor")
	assert_true(room.is_walkable(Vector2i(1, 3)), "player start")
	assert_true(room.is_walkable(Vector2i(9, 5)), "spawn")
	assert_false(room.is_walkable(Vector2i(0, 0)), "wall")
	assert_false(room.is_walkable(Vector2i(11, 3)), "exit")
	assert_false(room.is_walkable(Vector2i(-1, 3)), "outside, left")
	assert_false(room.is_walkable(Vector2i(12, 3)), "outside, right")
	assert_false(room.is_walkable(Vector2i(3, 8)), "outside, below")


func _room(rows: PackedStringArray) -> RoomData:
	return RoomFixtures.room(&"test_room", rows)


## Every error starts with `rule:` and at least one mentions `needle` (a tile like "(5, 3)").
func _assert_only_rule(errors: PackedStringArray, rule: String, needle: String) -> void:
	assert_gt(errors.size(), 0, "expected a %s error" % rule)
	for error: String in errors:
		assert_true(
			error.begins_with(rule + ":"), "expected only %s errors, got: %s" % [rule, error]
		)
	assert_true(
		_has_error(errors, rule, needle), "no %s error mentions %s: %s" % [rule, needle, errors]
	)


func _has_error(errors: PackedStringArray, rule: String, needle: String) -> bool:
	for error: String in errors:
		if error.begins_with(rule + ":") and (needle.is_empty() or error.contains(needle)):
			return true
	return false
