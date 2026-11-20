extends GutTest
## F-013 T8 (C17, AC16): NavGrid got cheaper and must answer exactly what it answered before.
## NavGridReference (nav_grid_reference.gd) is a copy of the old NavGrid. Both are built on the same
## rows and asked the same seeded questions, and every answer must be equal (`==`, no tolerance).
## Directions: many goals, several askers per goal in a shuffled order, so that a half-settled
## field is resumed, then asked again from nearer and from further away. Lines: segments of every
## kind, at the radii the enemies' bodies really have (read from the shipped enemy files) and at
## the bolt's, and segments whose end sits a hair either side of the distance at which it touches
## a wall (CR-1: a clip that leaves out one tile is a wrong answer). The seeds are fixed, so a
## failure reproduces.

const GOALS_PER_ROOM: int = 110
const ASKERS_PER_GOAL: int = 10
const SEGMENTS_PER_ROOM: int = 2000
## F-005: a bolt's radius. The other radii are the shipped enemies' hurtbox radii (_radii()).
const BOLT_RADIUS_TILES: float = 0.25
const ENEMY_DATA_DIR: String = "res://data/enemies"  # G5
## The graze segments: the end (or the start) is `radius + offset * GRAZE_UNIT` from a wall face,
## offset -GRAZE_OFFSETS..GRAZE_OFFSETS, each with GRAZE_SAMPLES random other ends, both ways round.
const GRAZE_UNIT: float = 1e-6
const GRAZE_OFFSETS: int = 5
const GRAZE_SAMPLES: int = 24
const MIN_GRAZE_CHECKS_PER_SIDE: int = 4000
## A "long" graze segment is at least this long on the axis it runs along, where the room allows.
const LONG_SEGMENT_TILES: float = 32.0
const SIDES: int = 4
const SIDE_EAST: int = 0
const SIDE_WEST: int = 1
const SIDE_NORTH: int = 2
const SIDE_SOUTH: int = 3
## How far past the grid random points may land.
const OUTSIDE_TILES: float = 3.0
const SEGMENT_KINDS: int = 9
const GOAL_KINDS: int = 6
const TOGGLES: int = 24
## The biggest shipped room: f3_r5, 64 x 36 with pillars.
const LARGEST_SHIPPED_ROOM_PATH: String = "res://data/floors/floor_3/room_5.tres"  # G5
const WARDEN_ROOM_PATH: String = "res://data/floors/floor_1/boss.tres"  # G5
const BIG_SIZE: Vector2i = Vector2i(64, 36)
## The sealed pocket added to the big room: walkable tiles (30..33, 28..31), walls all round.
const POCKET: Rect2i = Rect2i(30, 28, 4, 4)
const POCKET_WALLS: Rect2i = Rect2i(28, 26, 8, 8)

var _differences: PackedStringArray = PackedStringArray()
## Answers that were a direction and not ZERO, counted by _compare_directions().
var _moving: int = 0
## How many answers differed (`_differences` keeps only the first twenty).
var _mismatches: int = 0


func before_each() -> void:
	_differences = PackedStringArray()
	_moving = 0
	_mismatches = 0


# --- directions ---


func test_directions_equal_the_reference_on_the_fixture_rooms() -> void:
	var total: int = 0
	for index: int in _fixture_rooms().size():
		var room: Array = _fixture_rooms()[index]
		total += _compare_directions(room[0], room[1], 1000 + index, [] as Array[Vector2i])
	assert_eq(_differences, PackedStringArray(), "differences")
	gut.p("fixture rooms: %d direction answers compared, %d were a direction" % [total, _moving])


func test_directions_equal_the_reference_on_a_64_by_36_room_with_blocks_and_a_sealed_pocket(
) -> void:
	var tiles: Array[Vector2i] = []
	for y: int in range(POCKET.position.y, POCKET.end.y):
		for x: int in range(POCKET.position.x, POCKET.end.x):
			tiles.append(Vector2i(x, y))
	var total: int = _compare_directions("blocks 64 x 36", big_rows(true), 2000, tiles)
	assert_eq(_differences, PackedStringArray(), "differences")
	gut.p("64 x 36, blocks and pocket: %d direction answers, %d a direction" % [total, _moving])


func test_directions_equal_the_reference_on_the_largest_shipped_room() -> void:
	var room: RoomData = _largest_shipped_room()
	assert_eq(room.get_size(), BIG_SIZE, "f3_r5 is the 64 x 36 room")
	var total: int = _compare_directions("f3_r5", room.rows, 3000, [] as Array[Vector2i])
	assert_eq(_differences, PackedStringArray(), "differences")
	gut.p("f3_r5: %d direction answers, %d a direction" % [total, _moving])


## The goal changes back and forth between two tiles, and every change is compared at once.
func test_directions_equal_the_reference_when_the_goal_toggles_between_two_tiles() -> void:
	var rows: PackedStringArray = big_rows(false)
	var fresh: NavGrid = NavGrid.from_rows(rows)
	var old: NavGridReference = NavGridReference.from_rows(rows)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4000
	var goals: Array[Vector2] = [Vector2(4.5, 4.5), Vector2(58.5, 30.5)]
	var compared: int = 0
	for toggle: int in TOGGLES:
		var goal: Vector2 = goals[toggle % 2]
		for _ask: int in 4:
			var from: Vector2 = _random_point(rng, BIG_SIZE)
			if _ask == 0:
				from = goals[(toggle + 1) % 2]  # From the other goal's tile: far.
			compared += 1
			if fresh.direction_toward(from, goal) != old.direction_toward(from, goal):
				_differences.append("toggle %d: %s -> %s" % [toggle, from, goal])
	assert_eq(_differences, PackedStringArray(), "differences")
	assert_eq(fresh.get_field_builds(), old.get_field_builds(), "one build per new goal")
	assert_eq(fresh.get_field_builds(), TOGGLES, "every change of goal built a field")
	gut.p("toggling goals: %d direction answers compared" % compared)


## C17: `get_field_builds()` keeps its meaning with a lazy field. A resumed field is not a build.
func test_field_builds_count_one_per_new_goal_in_the_lazy_grid() -> void:
	var grid: NavGrid = NavGrid.from_rows(big_rows(false))
	var goal_a: Vector2 = Vector2(4.5, 4.5)
	var goal_b: Vector2 = Vector2(58.5, 30.5)
	assert_eq(grid.get_field_builds(), 0, "nothing asked yet")
	grid.direction_toward(Vector2(8.5, 4.5), goal_a)
	assert_eq(grid.get_field_builds(), 1, "the first goal")
	grid.direction_toward(Vector2(40.5, 20.5), goal_a)  # Resumes the half-settled field.
	grid.direction_toward(Vector2(8.5, 4.5), goal_a)
	grid.direction_toward(Vector2(60.5, 33.5), goal_a)
	assert_eq(grid.get_field_builds(), 1, "the same goal asked from anywhere")
	grid.direction_toward(Vector2(8.5, 4.5), goal_b)
	assert_eq(grid.get_field_builds(), 2, "a new goal")
	grid.direction_toward(Vector2(8.5, 4.5), goal_a)
	assert_eq(grid.get_field_builds(), 3, "back to the first: only the last goal is cached")
	grid.direction_toward(Vector2(8.5, 4.5), Vector2(8.5, 4.5))
	assert_eq(grid.get_field_builds(), 3, "an asker on the goal tile builds nothing")
	grid.direction_toward(Vector2(8.5, 4.5), Vector2(4.9, 4.1))  # The goal's own tile.
	assert_eq(grid.get_field_builds(), 3, "the same tile, another point of it")


# --- lines ---


func test_lines_equal_the_reference_on_the_fixture_rooms() -> void:
	var total: int = 0
	for index: int in _fixture_rooms().size():
		var room: Array = _fixture_rooms()[index]
		total += _compare_lines(room[0], room[1], 5000 + index)
	assert_eq(_differences, PackedStringArray(), "differences")
	gut.p("fixture rooms: %d line answers compared" % total)


func test_lines_equal_the_reference_on_a_64_by_36_room_with_blocks_and_a_sealed_pocket() -> void:
	var total: int = _compare_lines("blocks 64 x 36", big_rows(true), 6000)
	assert_eq(_differences, PackedStringArray(), "differences")
	gut.p("64 x 36 with blocks and a pocket: %d line answers compared" % total)


func test_lines_equal_the_reference_on_the_largest_shipped_room() -> void:
	var room: RoomData = _largest_shipped_room()
	var total: int = _compare_lines("f3_r5", room.rows, 7000)
	assert_eq(_differences, PackedStringArray(), "differences")
	gut.p("f3_r5: %d line answers compared" % total)


## The empty 64 x 36 room: long clear diagonals, where the old scan visited the whole box.
func test_lines_equal_the_reference_in_an_empty_room() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for y: int in BIG_SIZE.y:
		var border: bool = y == 0 or y == BIG_SIZE.y - 1
		rows.append("#".repeat(BIG_SIZE.x) if border else "#" + ".".repeat(BIG_SIZE.x - 2) + "#")
	var total: int = _compare_lines("empty 64 x 36", rows, 8000)
	assert_eq(_differences, PackedStringArray(), "differences")
	gut.p("empty 64 x 36: %d line answers compared" % total)


## CR-1/CR-2: the end of a long segment a hair either side of the distance at which it touches a
## wall, on all four sides, at every enemy radius, with the graze at the end and at the start.
func test_lines_equal_the_reference_when_an_end_grazes_a_wall_on_every_side() -> void:
	var rooms: Array = _fixture_rooms()
	rooms.append(["blocks 64 x 36", big_rows(true)])
	rooms.append(["f3_r5", _largest_shipped_room().rows])
	rooms.append(["f1_boss", load(WARDEN_ROOM_PATH).rows])
	rooms.append(["empty 64 x 36", empty_rows(BIG_SIZE)])
	rooms.append(["empty 64 x 12", empty_rows(Vector2i(64, 12))])
	var total: int = 0
	for index: int in rooms.size():
		total += _compare_grazes(rooms[index][0], rooms[index][1], 9000 + index, GRAZE_SAMPLES)
	assert_eq(_differences, PackedStringArray(), "differences")
	assert_eq(_mismatches, 0, "differences in all")
	gut.p("%d graze answers compared in %d rooms" % [total, rooms.size()])


## The reviewer's first case: a 64 x 12 empty room, a segment of 40 tiles, radius 0.7.
func test_cr1_a_64_by_12_room_at_radius_0_7_the_reviewers_segment() -> void:
	var rows: PackedStringArray = empty_rows(Vector2i(64, 12))
	var from: Vector2 = Vector2(22.367403, 3.0021656)
	var to: Vector2 = Vector2(62.3, 7.769074)
	var old: NavGridReference = NavGridReference.from_rows(rows)
	assert_false(old.has_clear_line(from, to, 0.7), "the old code: blocked by the east wall")
	assert_eq(NavGrid.from_rows(rows).has_clear_line(from, to, 0.7), false, "the new code agrees")


## The reviewer's second case: the Warden's room, radius 0.7, the target at x = 54.3 (0.7 from the
## east wall's face at 55), the asker anywhere in the west 22 columns: 20,000 checks.
func test_cr1_the_wardens_room_with_the_target_at_x_54_3_and_the_asker_in_the_west() -> void:
	var rows: PackedStringArray = (load(WARDEN_ROOM_PATH) as RoomData).rows
	var fresh: NavGrid = NavGrid.from_rows(rows)
	var old: NavGridReference = NavGridReference.from_rows(rows)
	var size: Vector2i = fresh.get_size()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9100
	var blocked: int = 0
	for _check: int in 20000:
		var from: Vector2 = Vector2(rng.randf_range(1.0, 23.0), rng.randf_range(1.0, size.y - 1.0))
		var to: Vector2 = Vector2(54.3, rng.randf_range(1.0, size.y - 1.0))
		var wanted: bool = old.has_clear_line(from, to, 0.7)
		blocked += 0 if wanted else 1
		if fresh.has_clear_line(from, to, 0.7) != wanted:
			_mismatches += 1
	assert_eq(_mismatches, 0, "of 20000 checks differ")
	assert_gt(blocked, 0, "some of them are blocked")


## The reviewer's third case: grazing probes on a 64 x 36 room, each side, many checks.
func test_cr1_grazing_probes_on_a_64_by_36_room_on_each_side() -> void:
	var total: int = _compare_grazes("64 x 36", empty_rows(BIG_SIZE), 9200, 4 * GRAZE_SAMPLES)
	assert_eq(_differences, PackedStringArray(), "differences")
	assert_eq(_mismatches, 0, "differences in all")
	gut.p("64 x 36 probes: %d graze answers compared" % total)


# --- the rooms ---


## A walled room of `size` with nothing inside.
static func empty_rows(size: Vector2i) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for y: int in size.y:
		var border: bool = y == 0 or y == size.y - 1
		rows.append("#".repeat(size.x) if border else "#" + ".".repeat(size.x - 2) + "#")
	return rows


func _largest_shipped_room() -> RoomData:
	return load(LARGEST_SHIPPED_ROOM_PATH) as RoomData


## 64 x 36, border walls and 3 x 3 blocks in staggered rows. With `pocket`, a sealed pocket of
## floor in the south middle: POCKET, inside a wall of POCKET_WALLS.
static func big_rows(pocket: bool) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for y: int in BIG_SIZE.y:
		var line: String = ""
		for x: int in BIG_SIZE.x:
			var wall: bool = x == 0 or y == 0 or x == BIG_SIZE.x - 1 or y == BIG_SIZE.y - 1
			for column: int in [10, 22, 34, 46]:
				for row: int in [6, 16, 26]:
					var left: int = column + (6 if (row / 10) % 2 == 1 else 0)
					wall = wall or (x >= left and x < left + 3 and y >= row and y < row + 3)
			if pocket and POCKET_WALLS.has_point(Vector2i(x, y)):
				wall = not POCKET.has_point(Vector2i(x, y))
			line += "#" if wall else "."
		rows.append(line)
	return rows


## [label, rows] for each room built in code by the other floor tests, and a few small ones for
## the awkward corners: walls on diagonals, a long wall with a gap, a sealed half, a room with
## no way through, and a row shorter than the others.
func _fixture_rooms() -> Array:
	return [
		["RoomFixtures.valid_rows", RoomFixtures.valid_rows()],
		["FloorFixtures.arena", FloorFixtures.arena_rows()],
		["FloorFixtures.pillar", PackedStringArray(FloorFixtures.PILLAR_ROWS)],
		["TowerFixtures.town", TowerFixtures.town_rows()],
		[
			"diagonal walls",
			PackedStringArray(
				[
					"##########",
					"#....#...#",
					"#.....#..#",
					"#..#.....#",
					"#...#..#.#",
					"#.....#..#",
					"#........#",
					"##########"
				]
			)
		],
		[
			"wall with a gap",
			PackedStringArray(
				[
					"############",
					"#....#.....#",
					"#....#.....#",
					"#....#.....#",
					"#....#.....#",
					"#..........#",
					"#..........#",
					"############"
				]
			)
		],
		[
			"sealed half",
			PackedStringArray(["....#....", "....#....", "....#....", "....#....", "....#...."])
		],
		["closed corner", PackedStringArray([".#.", "#..", "..."])],
		["short row", PackedStringArray(["######", "#....", "#..#.", "######"])],
		["all wall", PackedStringArray(["###", "###"])],
	]


# --- comparisons ---


## Asks both grids the same questions for GOALS_PER_ROOM goals. Returns how many answers were
## compared; every difference is added to `_differences`.
func _compare_directions(
	label: String, rows: PackedStringArray, seed_value: int, pocket: Array[Vector2i]
) -> int:
	var fresh: NavGrid = NavGrid.from_rows(rows)
	var old: NavGridReference = NavGridReference.from_rows(rows)
	var size: Vector2i = fresh.get_size()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var compared: int = 0
	for goal_number: int in GOALS_PER_ROOM:
		var goal: Vector2 = _goal(rng, goal_number, size, old, pocket)
		for from: Vector2 in _askers(rng, goal, size, old, pocket):
			var got: Vector2 = fresh.direction_toward(from, goal)
			var wanted: Vector2 = old.direction_toward(from, goal)
			compared += 1
			_moving += 1 if wanted != Vector2.ZERO else 0
			if got != wanted and _differences.size() < 20:
				_differences.append(
					"%s: %s -> %s gave %s, was %s" % [label, from, goal, got, wanted]
				)
	assert_eq(fresh.get_field_builds(), old.get_field_builds(), "%s: builds" % label)
	assert_gte(compared, 100 * 8, "%s: goals x askers" % label)
	return compared


## Every segment of every kind, at every radius, to both grids.
func _compare_lines(label: String, rows: PackedStringArray, seed_value: int) -> int:
	var fresh: NavGrid = NavGrid.from_rows(rows)
	var old: NavGridReference = NavGridReference.from_rows(rows)
	var size: Vector2i = fresh.get_size()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var radii: Array[float] = _radii()
	assert_gte(radii.size(), 8, "0, the bolt and the six body radii of the shipped enemies")
	var compared: int = 0
	var blocked: int = 0
	for number: int in SEGMENTS_PER_ROOM:
		var ends: Array[Vector2] = _segment(rng, number, size)
		for radius: float in radii:
			var got: bool = fresh.has_clear_line(ends[0], ends[1], radius)
			var wanted: bool = old.has_clear_line(ends[0], ends[1], radius)
			compared += 1
			blocked += 0 if wanted else 1
			if got != wanted:
				_mismatches += 1
				if _differences.size() < 20:
					_differences.append(
						(
							"%s: %s to %s radius %s gave %s, was %s"
							% [label, ends[0], ends[1], radius, got, wanted]
						)
					)
	assert_gte(compared, SEGMENTS_PER_ROOM, "%s: line checks" % label)
	gut.p("%s: %d of %d line answers were blocked" % [label, blocked, compared])
	return compared


## Every graze check of a room: for each side, each radius, each offset and `samples` random other
## ends, a long segment and a short one, the graze at the end and at the start. Returns how many
## answers were compared.
func _compare_grazes(label: String, rows: PackedStringArray, seed_value: int, samples: int) -> int:
	var fresh: NavGrid = NavGrid.from_rows(rows)
	var old: NavGridReference = NavGridReference.from_rows(rows)
	var size: Vector2i = fresh.get_size()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var radii: Array[float] = _radii()
	var compared: int = 0
	for side: int in SIDES:
		var per_side: int = 0
		for radius: float in radii:
			for offset: int in range(-GRAZE_OFFSETS, GRAZE_OFFSETS + 1):
				for sample: int in samples:
					for at_start: bool in [false, true]:
						var ends: Array[Vector2] = _graze_segment(
							rng, side, radius, offset, size, at_start, sample % 2 == 0
						)
						var wanted: bool = old.has_clear_line(ends[0], ends[1], radius)
						per_side += 1
						if fresh.has_clear_line(ends[0], ends[1], radius) != wanted:
							_mismatches += 1
							if _differences.size() < 20:
								_differences.append(
									(
										"%s side %d: %s to %s radius %s was %s"
										% [label, side, ends[0], ends[1], radius, wanted]
									)
								)
		assert_gte(per_side, MIN_GRAZE_CHECKS_PER_SIDE, "%s: checks on side %d" % [label, side])
		compared += per_side
	return compared


## A segment with one end `radius + offset * GRAZE_UNIT` from the face of a border wall on `side`
## (a circle of that radius just touches the wall, or just misses it, or just overlaps it) and the
## other end somewhere in the room: at least LONG_SEGMENT_TILES away along the axis where `long`
## and the room allows. `at_start` puts the graze at the first end and not the last.
func _graze_segment(
	rng: RandomNumberGenerator,
	side: int,
	radius: float,
	offset: int,
	size: Vector2i,
	at_start: bool,
	long: bool
) -> Array[Vector2]:
	var shift: float = radius + offset * GRAZE_UNIT
	var graze: Vector2 = Vector2(
		rng.randf_range(1.0, size.x - 1.0), rng.randf_range(1.0, size.y - 1.0)
	)
	var other: Vector2 = Vector2(
		rng.randf_range(1.0, size.x - 1.0), rng.randf_range(1.0, size.y - 1.0)
	)
	if side == SIDE_EAST:
		graze.x = size.x - 1.0 - shift
		if long and graze.x - LONG_SEGMENT_TILES >= 1.0:
			other.x = rng.randf_range(1.0, graze.x - LONG_SEGMENT_TILES)
	elif side == SIDE_WEST:
		graze.x = 1.0 + shift
		if long and graze.x + LONG_SEGMENT_TILES <= size.x - 1.0:
			other.x = rng.randf_range(graze.x + LONG_SEGMENT_TILES, size.x - 1.0)
	elif side == SIDE_NORTH:
		graze.y = 1.0 + shift
		if long and graze.y + LONG_SEGMENT_TILES <= size.y - 1.0:
			other.y = rng.randf_range(graze.y + LONG_SEGMENT_TILES, size.y - 1.0)
	else:
		graze.y = size.y - 1.0 - shift
		if long and graze.y - LONG_SEGMENT_TILES >= 1.0:
			other.y = rng.randf_range(1.0, graze.y - LONG_SEGMENT_TILES)
	if at_start:
		return [graze, other]
	return [other, graze]


## 0, the bolt's radius and every distinct hurtbox radius of the shipped EnemyData files: the
## radii the enemy brains pass to has_clear_line().
func _radii() -> Array[float]:
	var radii: Array[float] = [0.0, BOLT_RADIUS_TILES]
	for file_name: String in DirAccess.get_files_at(ENEMY_DATA_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var data: EnemyData = load("%s/%s" % [ENEMY_DATA_DIR, file_name]) as EnemyData
		if data != null and not radii.has(data.hurtbox_radius_tiles):
			radii.append(data.hurtbox_radius_tiles)
	radii.sort()
	return radii


# --- the seeded questions ---


func _random_point(rng: RandomNumberGenerator, size: Vector2i) -> Vector2:
	return Vector2(
		rng.randf_range(-OUTSIDE_TILES, size.x + OUTSIDE_TILES),
		rng.randf_range(-OUTSIDE_TILES, size.y + OUTSIDE_TILES)
	)


func _random_tile_centre(rng: RandomNumberGenerator, size: Vector2i) -> Vector2:
	return Vector2(rng.randi_range(0, size.x - 1) + 0.5, rng.randi_range(0, size.y - 1) + 0.5)


## A tile centre of the wanted kind (walkable or wall), by trying; any tile after 200 tries.
func _tile_centre_where(
	rng: RandomNumberGenerator, size: Vector2i, grid: NavGridReference, walkable: bool
) -> Vector2:
	var centre: Vector2 = _random_tile_centre(rng, size)
	for _try: int in 200:
		if grid.is_walkable(grid.tile_of(centre)) == walkable:
			return centre
		centre = _random_tile_centre(rng, size)
	return centre


## Goal number `number`: its kind cycles through a random point, a walkable tile, a wall tile, a
## point outside the grid, a pocket tile (a random tile where there is none), a point exactly
## on a tile corner.
func _goal(
	rng: RandomNumberGenerator,
	number: int,
	size: Vector2i,
	grid: NavGridReference,
	pocket: Array[Vector2i]
) -> Vector2:
	var goal: Vector2 = _random_point(rng, size)
	match number % GOAL_KINDS:
		1:
			goal = _tile_centre_where(rng, size, grid, true)
		2:
			goal = _tile_centre_where(rng, size, grid, false)
		3:
			var out: Vector2 = _random_point(rng, size)
			var side: int = rng.randi_range(0, 3)
			goal = [
				Vector2(-1.5 - rng.randf(), out.y),
				Vector2(size.x + 1.5 + rng.randf(), out.y),
				Vector2(out.x, -1.5 - rng.randf()),
				Vector2(out.x, size.y + 1.5 + rng.randf()),
			][side]
		4:
			if pocket.is_empty():
				goal = _tile_centre_where(rng, size, grid, true)
			else:
				goal = Vector2(pocket[rng.randi_range(0, pocket.size() - 1)]) + Vector2(0.5, 0.5)
		5:
			goal = Vector2(rng.randi_range(0, size.x), rng.randi_range(0, size.y))
	return goal


## ASKERS_PER_GOAL askers in a shuffled order: far, near, on the goal's tile, next to it, in a
## wall, outside the grid, in the pocket when there is one, and random points. The shuffle means
## the field is asked from nearer after it was settled for a far asker, and the other way round.
func _askers(
	rng: RandomNumberGenerator,
	goal: Vector2,
	size: Vector2i,
	grid: NavGridReference,
	pocket: Array[Vector2i]
) -> Array[Vector2]:
	var list: Array[Vector2] = [
		_tile_centre_where(rng, size, grid, true),
		goal + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)),
		goal,
		goal + Vector2(1.0, 0.0),
		goal + Vector2(0.0, -1.0),
		_tile_centre_where(rng, size, grid, false),
		Vector2(-0.5, rng.randf_range(0.0, size.y)),
		_random_point(rng, size),
		_random_point(rng, size),
		_tile_centre_where(rng, size, grid, true),
	]
	if not pocket.is_empty():
		list[9] = Vector2(pocket[rng.randi_range(0, pocket.size() - 1)]) + Vector2(0.5, 0.5)
	assert_eq(list.size(), ASKERS_PER_GOAL)
	# A shuffle that does not depend on Array.shuffle()'s own generator.
	for index: int in range(list.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var kept: Vector2 = list[index]
		list[index] = list[other]
		list[other] = kept
	return list


## Segment number `number`: its kind cycles through random floats, tile centres, horizontal,
## vertical, exactly diagonal, zero length, one end outside the grid, quarter-tile coordinates
## (touches and grazes are exact there) and whole-number corners.
func _segment(rng: RandomNumberGenerator, number: int, size: Vector2i) -> Array[Vector2]:
	var first: Vector2 = _random_point(rng, size)
	var second: Vector2 = _random_point(rng, size)
	match number % SEGMENT_KINDS:
		1:
			first = _random_tile_centre(rng, size)
			second = _random_tile_centre(rng, size)
		2:
			second = Vector2(second.x, first.y)
		3:
			second = Vector2(first.x, second.y)
		4:
			var run: float = float(rng.randi_range(-12, 12))
			first = _random_tile_centre(rng, size)
			second = first + Vector2(run, run if rng.randi_range(0, 1) == 0 else -run)
		5:
			first = (
				_random_point(rng, size)
				if rng.randi_range(0, 1) == 0
				else _random_tile_centre(rng, size)
			)
			second = first
		6:
			first = _random_tile_centre(rng, size)
			second = (
				first
				+ (
					Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
					* (size.x + 10.0)
				)
			)
		7:
			first = Vector2(rng.randi_range(0, size.x * 4), rng.randi_range(0, size.y * 4)) * 0.25
			second = Vector2(rng.randi_range(0, size.x * 4), rng.randi_range(0, size.y * 4)) * 0.25
		8:
			first = Vector2(rng.randi_range(0, size.x), rng.randi_range(0, size.y))
			second = Vector2(rng.randi_range(0, size.x), rng.randi_range(0, size.y))
			if rng.randi_range(0, 1) == 0:
				var diagonal: float = second.x - first.x
				second = Vector2(
					second.x, first.y + (diagonal if rng.randi_range(0, 1) == 0 else -diagonal)
				)
		_:
			pass
	return [first, second]
