# gdlint:disable=max-public-methods
extends GutTest
## F-014 T1 (AC1, AC2, AC3): a room lists reinforcements and arrival points, RoomData derives the
## kill target and the arrival spawns from them and refuses every broken wave rule (C1-C4).

var _rules: FloorTunables


func before_each() -> void:
	_rules = WaveFixtures.rules()


# --- AC1: what the room reports ---


func test_ac1_a_room_with_three_reinforcements_has_a_kill_target_of_five() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	assert_eq(room.get_spawns().size(), 2)
	assert_eq(room.reinforcements, PackedInt32Array([1, 2, 1]))
	assert_eq(room.get_kill_target(), 5)


func test_ac1_reinforcement_spawns_are_in_order_numbered_on_from_the_spawns() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	var spawns: Array[RoomSpawn] = room.get_reinforcement_spawns()
	assert_eq(spawns.size(), 3)
	var ids: Array[StringName] = []
	var kinds: Array[EnemyData] = []
	for spawn: RoomSpawn in spawns:
		ids.append(spawn.combat_id)
		kinds.append(spawn.enemy)
	assert_eq(ids, [&"chaser_3", &"caster_4", &"chaser_5"] as Array[StringName])
	assert_eq(kinds, [room.enemies[0], room.enemies[1], room.enemies[0]] as Array[EnemyData])


func test_ac1_a_reinforcement_spawn_starts_on_the_first_arrival_point_and_is_marked() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	for spawn: RoomSpawn in room.get_reinforcement_spawns():
		assert_true(spawn.is_reinforcement)
		assert_eq(spawn.position_tiles, Vector2(16.5, 3.5))
	for spawn: RoomSpawn in room.get_spawns():
		assert_false(spawn.is_reinforcement, "a placed enemy is not a reinforcement")
	assert_false(RoomSpawn.new().is_reinforcement, "false by default")


func test_ac1_arrival_points_are_the_s_tile_centres_row_major() -> void:
	assert_eq(
		WaveFixtures.wave_room().get_arrival_points_tiles(),
		(
			[Vector2(16.5, 3.5), Vector2(6.5, 4.5), Vector2(6.5, 9.5), Vector2(16.5, 9.5)]
			as Array[Vector2]
		)
	)


func test_ac1_the_spawns_are_what_they_were_without_waves() -> void:
	var with_waves: Array[RoomSpawn] = WaveFixtures.wave_room().get_spawns()
	var without: Array[RoomSpawn] = WaveFixtures.wave_room_without_waves().get_spawns()
	assert_eq(with_waves.size(), 2)
	assert_eq(without.size(), 2)
	for index: int in 2:
		assert_eq(with_waves[index].combat_id, without[index].combat_id)
		assert_eq(with_waves[index].position_tiles, without[index].position_tiles)
		assert_eq(with_waves[index].enemy, without[index].enemy)
	assert_eq(with_waves[0].combat_id, &"chaser_1")
	assert_eq(with_waves[1].combat_id, &"caster_2")
	assert_eq(with_waves[0].position_tiles, Vector2(8.5, 2.5))
	assert_eq(with_waves[1].position_tiles, Vector2(13.5, 7.5))


func test_ac1_a_room_without_waves_has_the_numbers_of_a_room_without_waves() -> void:
	var room: RoomData = WaveFixtures.wave_room_without_waves()
	assert_eq(room.reinforcements, PackedInt32Array())
	assert_eq(room.max_engaged, 0)
	assert_eq(room.get_kill_target(), 2)
	assert_eq(room.get_reinforcement_spawns().size(), 0)
	assert_eq(room.get_arrival_points_tiles().size(), 0)
	assert_eq(RoomFixtures.valid_room().get_kill_target(), 1)


func test_ac1_max_engaged_zero_means_the_tunable() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	assert_eq(room.get_max_engaged(_rules), 3, "the shipped wave_max_engaged")
	_rules.wave_max_engaged = 5
	assert_eq(room.get_max_engaged(_rules), 5)
	room.max_engaged = 2
	assert_eq(room.get_max_engaged(_rules), 2, "the room's own value wins")


func test_ac1_a_reinforcement_with_no_enemy_is_left_out_of_the_derived_values() -> void:
	var room: RoomData = WaveFixtures.room_with([1, 3, 2])
	var spawns: Array[RoomSpawn] = room.get_reinforcement_spawns()
	assert_eq(spawns.size(), 2, "the 3 has no enemy and is reported by validate()")
	assert_eq(spawns[0].combat_id, &"chaser_3")
	assert_eq(spawns[1].combat_id, &"caster_5", "the numbering still counts the skipped entry")
	assert_eq(room.get_kill_target(), 4)


func test_ac1_s_is_walkable_like_floor() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	for tile: Vector2i in WaveFixtures.ARRIVAL_TILES:
		assert_true(room.is_walkable(tile), str(tile))
	assert_true(RoomData.LEGEND.contains("S"))
	assert_eq(room.validate(_rules), PackedStringArray(), "a room with S passes every old rule")


func test_ac1_s_is_floor_for_reachability_corridors_and_pinches() -> void:
	# An S behind a wall is unreachable from P.
	var sealed: PackedStringArray = PackedStringArray(
		[
			"############",
			"#....##....#",
			"#....##....#",
			"#P...##.S..E",
			"#....##....E",
			"#....##....#",
			"#...1##.S..#",
			"############",
		]
	)
	var errors: PackedStringArray = WaveFixtures.room_with([1], sealed).validate(_rules)
	assert_true(_has_error(errors, "reachable", "(8, 3)"), str(errors))
	assert_true(_has_error(errors, "reachable", "(8, 6)"), str(errors))
	# An S in a one-tile gap is a floor tile of a corridor.
	var gap: PackedStringArray = PackedStringArray(
		[
			"############",
			"#....##....#",
			"#....##....#",
			"#P...S.....E",
			"#....##....E",
			"#....##..1.#",
			"#....##....#",
			"############",
		]
	)
	errors = WaveFixtures.room_with([1], gap).validate(_rules)
	assert_true(_has_error(errors, "corridor", "(5, 3)"), str(errors))
	# Two floor tiles side by side, one of them an S, still need a shared 2 x 2 block.
	var pinch: PackedStringArray = PackedStringArray(
		[
			"################",
			"#..............#",
			"#.........1....#",
			"#..............#",
			"########S......#",
			"########.......#",
			"#........#######",
			"#........#######",
			"#..............#",
			"#P.............E",
			"#..............E",
			"################",
		]
	)
	errors = WaveFixtures.room_with([1], pinch).validate(_rules)
	assert_true(_has_error(errors, "pinch", "(8, 5) and (8, 6)"), str(errors))


func test_ac1_the_wave_values_are_off_by_default() -> void:
	var room: RoomData = RoomData.new()
	assert_eq(room.reinforcements, PackedInt32Array())
	assert_eq(room.max_engaged, 0)


# --- AC2: each rule of C3, alone and together ---


func test_ac2_the_fixture_room_is_valid() -> void:
	assert_eq(WaveFixtures.wave_room().validate(_rules), PackedStringArray())


func test_ac2_a_reinforcement_value_above_the_enemies_is_refused() -> void:
	var room: RoomData = WaveFixtures.room_with([1, 3, 1])
	_assert_exactly(
		room.validate(_rules), ["waves: reinforcements[1] is 3 but enemies has 2 entries"]
	)


func test_ac2_a_reinforcement_value_below_one_is_refused() -> void:
	_assert_exactly(
		WaveFixtures.room_with([0, 1, 1]).validate(_rules),
		["waves: reinforcements[0] is 0 but enemies has 2 entries"]
	)
	_assert_exactly(
		WaveFixtures.room_with([1, 1, -2]).validate(_rules),
		["waves: reinforcements[2] is -2 but enemies has 2 entries"]
	)


func test_ac2_every_bad_reinforcement_value_is_its_own_error() -> void:
	_assert_exactly(
		WaveFixtures.room_with([5, 1, 0]).validate(_rules),
		[
			"waves: reinforcements[0] is 5 but enemies has 2 entries",
			"waves: reinforcements[2] is 0 but enemies has 2 entries",
		]
	)


func test_ac2_reinforcements_in_a_boss_room_are_refused() -> void:
	var room: RoomData = WaveFixtures.boss_room()
	room.reinforcements = PackedInt32Array([1, 1])
	_assert_exactly(
		room.validate(_rules), ["waves: a boss room can't have reinforcements, found 2"]
	)


func test_ac2_reinforcements_in_a_safe_room_are_refused() -> void:
	var room: RoomData = WaveFixtures.safe_room()
	room.reinforcements = PackedInt32Array([1])
	_assert_exactly(
		room.validate(_rules), ["waves: a safe room can't have reinforcements, found 1"]
	)


func test_ac2_an_arrival_point_in_a_boss_room_is_refused_naming_the_tile() -> void:
	var room: RoomData = WaveFixtures.boss_room()
	WaveFixtures.add_arrival_points(room, [Vector2i(5, 1)] as Array[Vector2i])
	_assert_exactly(
		room.validate(_rules),
		["waves: arrival point at (5, 1), a boss room can't have arrival points"]
	)


func test_ac2_an_arrival_point_in_a_safe_room_is_refused_naming_the_tile() -> void:
	var room: RoomData = WaveFixtures.safe_room()
	WaveFixtures.add_arrival_points(room, [Vector2i(5, 1), Vector2i(8, 5)] as Array[Vector2i])
	_assert_exactly(
		room.validate(_rules),
		[
			"waves: arrival point at (5, 1), a safe room can't have arrival points",
			"waves: arrival point at (8, 5), a safe room can't have arrival points",
		]
	)


func test_ac2_fewer_arrival_points_than_the_minimum_is_refused() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	WaveFixtures.remove_arrival_points(
		room, [Vector2i(6, 9), Vector2i(16, 9), Vector2i(6, 4)] as Array[Vector2i]
	)
	_assert_exactly(
		room.validate(_rules),
		["waves: 3 reinforcements need at least 2 arrival points (S), found 1"]
	)
	WaveFixtures.remove_arrival_points(room, [Vector2i(16, 3)] as Array[Vector2i])
	_assert_exactly(
		room.validate(_rules),
		["waves: 3 reinforcements need at least 2 arrival points (S), found 0"]
	)


func test_ac2_the_minimum_arrival_points_is_a_tunable() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	_rules.wave_min_arrival_points = 5
	_assert_exactly(
		room.validate(_rules),
		["waves: 3 reinforcements need at least 5 arrival points (S), found 4"]
	)
	_rules.wave_min_arrival_points = 4
	assert_eq(room.validate(_rules), PackedStringArray(), "exactly the minimum is enough")


func test_ac2_arrival_points_without_reinforcements_are_refused_one_error_per_tile() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	room.reinforcements = PackedInt32Array()
	_assert_exactly(
		room.validate(_rules),
		[
			"waves: arrival point at (16, 3) but the room has no reinforcements",
			"waves: arrival point at (6, 4) but the room has no reinforcements",
			"waves: arrival point at (6, 9) but the room has no reinforcements",
			"waves: arrival point at (16, 9) but the room has no reinforcements",
		]
	)


func test_ac2_an_arrival_point_too_near_p_is_refused_naming_the_tile() -> void:
	# P is (1, 5): the centre of (3, 6) is 2.24 tiles from it, the minimum is 4.
	var room: RoomData = WaveFixtures.wave_room()
	WaveFixtures.add_arrival_points(room, [Vector2i(3, 6)] as Array[Vector2i])
	_assert_exactly(
		room.validate(_rules),
		["waves: arrival point at (3, 6) is 2.24 tiles from P, needs at least 4.0"]
	)


func test_ac2_an_arrival_point_exactly_the_minimum_from_p_is_accepted() -> void:
	# (5, 5) is 4.0 tiles from P. The point at (6, 4) is 1.41 from it, so it moves there.
	var room: RoomData = WaveFixtures.wave_room()
	WaveFixtures.remove_arrival_points(room, [Vector2i(6, 4)] as Array[Vector2i])
	WaveFixtures.add_arrival_points(room, [Vector2i(5, 5)] as Array[Vector2i])
	assert_eq(room.validate(_rules), PackedStringArray())
	_rules.min_spawn_distance_tiles = 4.5
	_assert_exactly(
		room.validate(_rules),
		["waves: arrival point at (5, 5) is 4.00 tiles from P, needs at least 4.5"]
	)


func test_ac2_two_arrival_points_too_near_each_other_are_refused_naming_both() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	WaveFixtures.add_arrival_points(room, [Vector2i(17, 3)] as Array[Vector2i])
	_assert_exactly(
		room.validate(_rules),
		["waves: arrival points at (16, 3) and (17, 3) are 1.00 tiles apart, needs at least 1.5"]
	)
	var diagonal: RoomData = WaveFixtures.wave_room()
	WaveFixtures.add_arrival_points(diagonal, [Vector2i(17, 4)] as Array[Vector2i])
	_assert_exactly(
		diagonal.validate(_rules),
		["waves: arrival points at (16, 3) and (17, 4) are 1.41 tiles apart, needs at least 1.5"]
	)


func test_ac2_arrival_points_exactly_the_gap_apart_are_accepted() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	WaveFixtures.add_arrival_points(room, [Vector2i(18, 3)] as Array[Vector2i])
	_rules.wave_spawn_gap_tiles = 2.0
	assert_eq(room.validate(_rules), PackedStringArray(), "2.0 apart with a gap of 2.0")
	_rules.wave_spawn_gap_tiles = 2.5
	assert_eq(room.validate(_rules).size(), 1, "2.0 apart with a gap of 2.5")


func test_ac2_an_arrival_point_too_near_a_spawn_is_refused_naming_both_tiles() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	WaveFixtures.add_arrival_points(room, [Vector2i(9, 2)] as Array[Vector2i])
	_assert_exactly(
		room.validate(_rules),
		[
			"waves: arrival point at (9, 2) is 1.00 tiles from the spawn at (8, 2), needs at least 1.5"
		]
	)


func test_ac2_a_negative_max_engaged_is_refused_naming_the_value() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	room.max_engaged = -1
	_assert_exactly(room.validate(_rules), ["waves: max_engaged is -1, must be >= 0"])
	room.max_engaged = 0
	assert_eq(room.validate(_rules), PackedStringArray(), "0 means the tunable")
	room.max_engaged = 6
	assert_eq(room.validate(_rules), PackedStringArray(), "no upper limit but the kill target")


func test_ac2_a_kill_target_above_the_maximum_is_refused_naming_both_numbers() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	_rules.max_kill_target = 4
	_assert_exactly(room.validate(_rules), ["waves: kill target is 5, at most 4 allowed"])
	_rules.max_kill_target = 5
	assert_eq(room.validate(_rules), PackedStringArray(), "exactly the maximum is allowed")


func test_ac2_max_enemies_per_room_still_counts_only_the_spawn_tiles() -> void:
	# F-014/C3: two placed enemies and three reinforcements, with a limit of two placed.
	_rules.max_enemies_per_room = 2
	assert_eq(WaveFixtures.wave_room().validate(_rules), PackedStringArray())
	_rules.max_enemies_per_room = 1
	var errors: PackedStringArray = WaveFixtures.wave_room().validate(_rules)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(_has_error(errors, "spawn_count", "1 to 1"), str(errors))


func test_ac2_several_wave_rules_broken_at_once_are_all_returned_in_order() -> void:
	var room: RoomData = WaveFixtures.room_with([1, 3, 1])
	room.max_engaged = -1
	_rules.max_kill_target = 3
	WaveFixtures.add_arrival_points(
		room, [Vector2i(9, 2), Vector2i(17, 3), Vector2i(3, 6)] as Array[Vector2i]
	)
	# Points, row-major: (9, 2) (16, 3) (17, 3) (6, 4) (3, 6) (6, 9) (16, 9). The kill target is 4:
	# two placed and two reinforcements with an enemy (the 3 has none).
	_assert_exactly(
		room.validate(_rules),
		[
			"waves: max_engaged is -1, must be >= 0",
			"waves: kill target is 4, at most 3 allowed",
			"waves: reinforcements[1] is 3 but enemies has 2 entries",
			"waves: arrival point at (9, 2) is 1.00 tiles from the spawn at (8, 2), needs at least 1.5",
			"waves: arrival points at (16, 3) and (17, 3) are 1.00 tiles apart, needs at least 1.5",
			"waves: arrival point at (3, 6) is 2.24 tiles from P, needs at least 4.0",
		]
	)


func test_ac2_wave_errors_come_after_the_old_ones_and_do_not_hide_them() -> void:
	var room: RoomData = WaveFixtures.wave_room()
	WaveFixtures.set_tile(room, 1, 5, ".")  # no P
	room.max_engaged = -3
	_assert_exactly(
		room.validate(_rules),
		[
			"player_start: exactly one P is required, found 0",
			"waves: max_engaged is -3, must be >= 0",
		]
	)


func test_ac2_a_boss_room_and_a_safe_room_get_only_the_error_of_what_they_hold() -> void:
	# Reinforcements and arrival points together in a boss room: one error each, no count or
	# orphan errors on top, so every wave rule can fail on its own.
	var room: RoomData = WaveFixtures.boss_room()
	room.reinforcements = PackedInt32Array([1])
	WaveFixtures.add_arrival_points(room, [Vector2i(5, 1)] as Array[Vector2i])
	_assert_exactly(
		room.validate(_rules),
		[
			"waves: a boss room can't have reinforcements, found 1",
			"waves: arrival point at (5, 1), a boss room can't have arrival points",
		]
	)


func test_ac2_a_room_with_no_waves_gets_exactly_the_errors_it_got_before() -> void:
	var rows: PackedStringArray = RoomFixtures.valid_rows()
	var no_p: PackedStringArray = RoomFixtures.with_tile(rows, 1, 3, ".")
	var no_spawn: PackedStringArray = RoomFixtures.with_tile(rows, 9, 5, ".")
	var cases: Array[Dictionary] = [
		{"room": RoomFixtures.valid_room(), "errors": []},
		{"room": RoomFixtures.valid_boss_room(), "errors": []},
		{"room": WaveFixtures.wave_room_without_waves(), "errors": []},
		{"room": TowerFixtures.safe_room(), "errors": []},
		{
			"room": RoomFixtures.room(&"r", no_p),
			"errors": ["player_start: exactly one P is required, found 0"]
		},
		{
			"room": RoomFixtures.room(&"r", no_spawn),
			"errors": ["spawn_count: a combat room needs 1 to 6 spawns, found 0"]
		},
		{
			"room": RoomFixtures.room(&"r", RoomFixtures.with_tile(no_p, 9, 5, ".")),
			"errors":
			[
				"player_start: exactly one P is required, found 0",
				"spawn_count: a combat room needs 1 to 6 spawns, found 0",
			]
		},
		{
			"room": RoomFixtures.room(&"r", RoomFixtures.with_tile(rows, 6, 4, "#")),
			"errors": ["thin_wall: wall tile (6, 4) is not in a 2x2 block of wall"]
		},
		{
			"room": RoomFixtures.room(&"r", RoomFixtures.with_tile(rows, 3, 3, "1")),
			"errors": ["spawn_distance: spawn at (3, 3) is 2.00 tiles from P, needs at least 4.0"]
		},
		{
			"room": RoomFixtures.room(&"r", RoomFixtures.with_tile(rows, 5, 3, "x")),
			"errors": ["legend: tile (5, 3) has unknown character 'x'"]
		},
		{
			"room": RoomFixtures.room(&"r", RoomFixtures.with_tile(rows, 5, 3, "s")),
			"errors": ["legend: tile (5, 3) has unknown character 's'"]
		},
	]
	for index: int in cases.size():
		var room: RoomData = cases[index]["room"]
		var errors: PackedStringArray = room.validate(_rules)
		assert_eq(errors, PackedStringArray(cases[index]["errors"]), "case %d" % index)
		for error: String in errors:
			assert_false(error.begins_with("waves:"), "case %d: %s" % [index, error])


func test_ac2_wave_tunables_never_add_an_error_to_a_room_with_no_waves() -> void:
	# Even tunables no wave room could meet change nothing where there are no waves.
	_rules.max_kill_target = 1
	_rules.wave_min_arrival_points = 99
	_rules.wave_spawn_gap_tiles = 50.0
	assert_eq(WaveFixtures.wave_room_without_waves().validate(_rules), PackedStringArray())
	assert_eq(RoomFixtures.valid_boss_room().validate(_rules), PackedStringArray())
	assert_eq(TowerFixtures.safe_room().validate(_rules), PackedStringArray())


# --- AC3: the tunables ---


func test_ac3_the_defaults_are_the_design_values() -> void:
	var fresh: FloorTunables = FloorTunables.new()
	assert_eq(fresh.wave_max_engaged, 3)
	assert_almost_eq(fresh.wave_spawn_warning_duration, 0.8, 0.0001)
	assert_almost_eq(fresh.wave_spawn_interval, 1.5, 0.0001)
	assert_almost_eq(fresh.wave_min_spawn_distance_tiles, 6.0, 0.0001)
	assert_almost_eq(fresh.wave_spawn_gap_tiles, 1.5, 0.0001)
	assert_eq(fresh.wave_min_arrival_points, 2)
	assert_eq(fresh.max_kill_target, 30)
	assert_eq(fresh.wave_arrival_box_tiles, Vector2(19, 10))
	assert_eq(fresh.validate(), PackedStringArray())


func test_ac3_the_shipped_file_holds_the_design_values() -> void:
	var shipped: FloorTunables = load(Tunables.FLOORS_PATH)
	assert_eq(shipped.wave_max_engaged, 3)
	assert_almost_eq(shipped.wave_spawn_warning_duration, 0.8, 0.0001)
	assert_almost_eq(shipped.wave_spawn_interval, 1.5, 0.0001)
	assert_almost_eq(shipped.wave_min_spawn_distance_tiles, 6.0, 0.0001)
	assert_almost_eq(shipped.wave_spawn_gap_tiles, 1.5, 0.0001)
	assert_eq(shipped.wave_min_arrival_points, 2)
	assert_eq(shipped.max_kill_target, 30)
	assert_eq(shipped.wave_arrival_box_tiles, Vector2(19, 10))
	assert_eq(shipped.validate(), PackedStringArray())


func _assert_exactly(errors: PackedStringArray, expected: Array[String]) -> void:
	assert_eq(errors, PackedStringArray(expected), str(errors))


func _has_error(errors: PackedStringArray, rule: String, needle: String) -> bool:
	for error: String in errors:
		if error.begins_with(rule + ":") and (needle.is_empty() or error.contains(needle)):
			return true
	return false
