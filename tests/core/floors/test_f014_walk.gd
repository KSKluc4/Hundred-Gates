# gdlint:disable=max-public-methods
extends GutTest
## F-014 AC27 (CR-1): NavGrid.walk_distance() is the length of the shortest path under the grid's
## own step rules. Checked against a shortest-path computation written here, sharing nothing with
## nav_grid.gd: a plain Dijkstra over the tiles with a binary heap, read from the room's rows. The
## pairs are seeded, so a failure reproduces; they include positions inside walls, outside the
## grid, on one tile, and in a sealed pocket. Asking must not change what direction_toward() and
## has_clear_line() answer: NavGridReference (the pre-F-013 code) is asked the same questions.

const GOALS_PER_ROOM: int = 50
const ASKERS_PER_GOAL: int = 40
const OUTSIDE_TILES: float = 3.0
const TOLERANCE: float = 1e-6
## The sealed pocket added to the big room: walkable tiles (30..33, 28..31), walls all round.
const POCKET: Rect2i = Rect2i(30, 28, 4, 4)
const POCKET_WALLS: Rect2i = Rect2i(28, 26, 8, 8)
const ROOM_2_4_PATH: String = "res://data/floors/floor_2/room_4.tres"  # G5
const DIAGONAL: float = 1.4142135623730951


## The reference: its own reading of the rows and its own Dijkstra.
class Walker:
	extends RefCounted

	var rows: PackedStringArray
	var width: int = 0
	var height: int = 0

	func _init(grid_rows: PackedStringArray) -> void:
		rows = grid_rows
		height = rows.size()
		for row: String in rows:
			width = maxi(width, row.length())

	func is_open(x: int, y: int) -> bool:
		if y < 0 or y >= height or x < 0 or x >= rows[y].length():
			return false
		return rows[y][x] != "#" and rows[y][x] != "E"

	## The tile under the position when open, else the open tile whose square is nearest it (ties to
	## the first in row-major order); (-1, -1) when there is none.
	func tile_for(position: Vector2) -> Vector2i:
		var under: Vector2i = Vector2i(floori(position.x), floori(position.y))
		if is_open(under.x, under.y):
			return under
		var best: Vector2i = Vector2i(-1, -1)
		var best_distance: float = INF
		for y: int in height:
			for x: int in width:
				if not is_open(x, y):
					continue
				var nearest: Vector2 = Vector2(
					clampf(position.x, x, x + 1.0), clampf(position.y, y, y + 1.0)
				)
				var distance: float = position.distance_to(nearest)
				if distance < best_distance - 1e-9:
					best_distance = distance
					best = Vector2i(x, y)
		return best

	## Shortest cost from `goal` to every tile (INF where none): orthogonal steps 1, diagonal steps
	## sqrt 2, a diagonal only between two open orthogonal neighbours.
	func costs_from(goal: Vector2i) -> PackedFloat64Array:
		var costs: PackedFloat64Array = PackedFloat64Array()
		costs.resize(width * height)
		costs.fill(INF)
		var heap_cost: Array[float] = [0.0]
		var heap_tile: Array[int] = [goal.y * width + goal.x]
		costs[goal.y * width + goal.x] = 0.0
		while not heap_cost.is_empty():
			var cost: float = heap_cost[0]
			var tile: int = heap_tile[0]
			var last_cost: float = heap_cost.pop_back()
			var last_tile: int = heap_tile.pop_back()
			if not heap_cost.is_empty():
				heap_cost[0] = last_cost
				heap_tile[0] = last_tile
				_sift_down(heap_cost, heap_tile)
			if cost > costs[tile]:
				continue
			var x: int = tile % width
			var y: int = tile / width
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					if not is_open(x + dx, y + dy):
						continue
					var step: float = 1.0
					if dx != 0 and dy != 0:
						if not (is_open(x + dx, y) and is_open(x, y + dy)):
							continue
						step = DIAGONAL
					var next: int = (y + dy) * width + x + dx
					if cost + step < costs[next]:
						costs[next] = cost + step
						heap_cost.append(cost + step)
						heap_tile.append(next)
						_sift_up(heap_cost, heap_tile)
		return costs

	func _sift_up(heap_cost: Array[float], heap_tile: Array[int]) -> void:
		var at: int = heap_cost.size() - 1
		while at > 0:
			var parent: int = (at - 1) / 2
			if heap_cost[parent] <= heap_cost[at]:
				break
			_swap(heap_cost, heap_tile, at, parent)
			at = parent

	func _sift_down(heap_cost: Array[float], heap_tile: Array[int]) -> void:
		var at: int = 0
		var count: int = heap_cost.size()
		while true:
			var smallest: int = at
			for child: int in [at * 2 + 1, at * 2 + 2]:
				if child < count and heap_cost[child] < heap_cost[smallest]:
					smallest = child
			if smallest == at:
				break
			_swap(heap_cost, heap_tile, at, smallest)
			at = smallest

	func _swap(heap_cost: Array[float], heap_tile: Array[int], first: int, second: int) -> void:
		var cost: float = heap_cost[first]
		heap_cost[first] = heap_cost[second]
		heap_cost[second] = cost
		var tile: int = heap_tile[first]
		heap_tile[first] = heap_tile[second]
		heap_tile[second] = tile


func _rooms() -> Dictionary:
	var rooms: Dictionary = {}
	rooms["valid room"] = RoomFixtures.valid_rows()
	rooms["arena"] = FloorFixtures.arena_rows()
	rooms["pillars"] = FloorFixtures.pillar_rows()
	rooms["divider"] = FloorFixtures.divider_rows()
	rooms["wave room"] = WaveFixtures.wave_rows()
	rooms["town, 64 x 36 with blocks"] = (load(Tunables.TOWN_PATH) as RoomData).rows
	rooms["room 2-4"] = (load(ROOM_2_4_PATH) as RoomData).rows
	rooms["town with a sealed pocket"] = _with_pocket((load(Tunables.TOWN_PATH) as RoomData).rows)
	return rooms


func _with_pocket(rows: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = rows.duplicate()
	for y: int in range(POCKET_WALLS.position.y, POCKET_WALLS.end.y):
		for x: int in range(POCKET_WALLS.position.x, POCKET_WALLS.end.x):
			var tile: String = "." if POCKET.has_point(Vector2i(x, y)) else "#"
			result = RoomFixtures.with_tile(result, x, y, tile)
	return result


## A random position, a quarter of them on a tile centre, over the grid and a margin outside it.
func _random_position(random: RandomNumberGenerator, walker: Walker) -> Vector2:
	var x: float = random.randf_range(-OUTSIDE_TILES, walker.width + OUTSIDE_TILES)
	var y: float = random.randf_range(-OUTSIDE_TILES, walker.height + OUTSIDE_TILES)
	if random.randi() % 4 == 0:
		return Vector2(floorf(x) + 0.5, floorf(y) + 0.5)
	return Vector2(x, y)


# --- AC27: the distance ---------------------------------------------------------------------------


func test_ac27_walk_distance_equals_an_independent_shortest_path_on_every_room() -> void:
	var rooms: Dictionary = _rooms()
	for label: String in rooms:
		var rows: PackedStringArray = rooms[label]
		var grid: NavGrid = NavGrid.from_rows(rows)
		var walker: Walker = Walker.new(rows)
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = hash(label)
		var pairs: int = 0
		var finite: int = 0
		var unreachable: int = 0
		var wrong: int = 0
		for _goal: int in GOALS_PER_ROOM:
			var goal_position: Vector2 = _random_position(random, walker)
			var goal: Vector2i = walker.tile_for(goal_position)
			var costs: PackedFloat64Array = (
				walker.costs_from(goal) if goal.x >= 0 else PackedFloat64Array()
			)
			for _asker: int in ASKERS_PER_GOAL:
				var from: Vector2 = _random_position(random, walker)
				var start: Vector2i = walker.tile_for(from)
				var expected: float = INF
				if goal.x >= 0 and start.x >= 0:
					expected = costs[start.y * walker.width + start.x]
				var got: float = grid.walk_distance(from, goal_position)
				pairs += 1
				var same: bool = (
					is_inf(expected) and is_inf(got)
					or (not is_inf(expected) and absf(expected - got) <= TOLERANCE)
				)
				if not same:
					wrong += 1
					if wrong <= 3:
						fail_test(
							(
								"%s: from %s to %s: got %s, expected %s"
								% [label, from, goal_position, got, expected]
							)
						)
				if is_inf(expected):
					unreachable += 1
				else:
					finite += 1
		assert_gte(pairs, 2000, "%s: pairs" % label)
		assert_eq(wrong, 0, "%s: pairs that differ" % label)
		assert_gt(finite, pairs / 2, "%s: most pairs have a path" % label)
		if label == "town with a sealed pocket":
			assert_gt(unreachable, 0, "the pocket makes some pairs unreachable")


func test_ac27_one_tile_is_a_walk_of_zero_and_the_nearest_walkable_tile_stands_in_for_a_wall(
) -> void:
	var grid: NavGrid = NavGrid.from_rows(RoomFixtures.valid_rows())
	assert_eq(grid.walk_distance(Vector2(3.1, 3.2), Vector2(3.9, 3.8)), 0.0, "one tile")
	assert_eq(grid.walk_distance(Vector2(3.5, 3.5), Vector2(3.5, 3.5)), 0.0)
	# (-5, 3.5) is outside, west of the open tile (1, 3): it stands in for that tile.
	assert_almost_eq(
		grid.walk_distance(Vector2(-5.0, 3.5), Vector2(6.5, 3.5)),
		grid.walk_distance(Vector2(1.5, 3.5), Vector2(6.5, 3.5)),
		TOLERANCE
	)
	assert_almost_eq(grid.walk_distance(Vector2(1.5, 3.5), Vector2(6.5, 3.5)), 5.0, TOLERANCE)
	# A wall tile (0, 0) corner: the nearest open tile is (1, 1), one diagonal step from (2, 2).
	assert_almost_eq(grid.walk_distance(Vector2(0.5, 0.5), Vector2(2.5, 2.5)), DIAGONAL, TOLERANCE)
	assert_almost_eq(grid.walk_distance(Vector2(1.5, 1.5), Vector2(3.5, 1.5)), 2.0, TOLERANCE)
	assert_almost_eq(
		grid.walk_distance(Vector2(1.5, 1.5), Vector2(3.5, 2.5)), DIAGONAL + 1.0, TOLERANCE
	)


func test_ac27_a_walk_is_the_same_both_ways() -> void:
	var rows: PackedStringArray = (load(ROOM_2_4_PATH) as RoomData).rows
	var grid: NavGrid = NavGrid.from_rows(rows)
	var walker: Walker = Walker.new(rows)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 24
	for _i: int in 200:
		var a: Vector2 = _random_position(random, walker)
		var b: Vector2 = _random_position(random, walker)
		var there: float = grid.walk_distance(a, b)
		var back: float = grid.walk_distance(b, a)
		assert_true(
			(is_inf(there) and is_inf(back)) or absf(there - back) <= TOLERANCE, "%s %s" % [a, b]
		)


func test_ac27_a_sealed_pocket_cannot_be_walked_to_or_from() -> void:
	var grid: NavGrid = NavGrid.from_rows(_with_pocket((load(Tunables.TOWN_PATH) as RoomData).rows))
	var inside: Vector2 = Vector2(31.5, 29.5)
	var outside: Vector2 = Vector2(32.5, 9.5)
	assert_true(is_inf(grid.walk_distance(inside, outside)))
	assert_true(is_inf(grid.walk_distance(outside, inside)))
	assert_almost_eq(grid.walk_distance(inside, Vector2(33.5, 29.5)), 2.0, TOLERANCE)
	assert_gt(grid.walk_distance(outside, Vector2(40.5, 9.5)), 7.0)


func test_ac27_a_grid_with_no_walkable_tile_has_no_walks() -> void:
	var grid: NavGrid = NavGrid.from_rows(PackedStringArray(["###", "#E#", "###"]))
	assert_true(is_inf(grid.walk_distance(Vector2(1.5, 1.5), Vector2(0.5, 0.5))))
	var empty: NavGrid = NavGrid.from_rows(PackedStringArray())
	assert_true(is_inf(empty.walk_distance(Vector2.ZERO, Vector2.ONE)))


func test_ac27_asking_a_walk_builds_one_field_per_new_goal() -> void:
	var grid: NavGrid = NavGrid.from_rows(WaveFixtures.wave_rows())
	assert_eq(grid.get_field_builds(), 0)
	grid.walk_distance(Vector2(3.5, 3.5), Vector2(10.5, 6.5))
	assert_eq(grid.get_field_builds(), 1)
	grid.walk_distance(Vector2(15.5, 9.5), Vector2(10.5, 6.5))
	grid.walk_distance(Vector2(2.5, 2.5), Vector2(10.9, 6.1))  # The same tile as the goal above.
	assert_eq(grid.get_field_builds(), 1, "other askers, the same goal")
	grid.direction_toward(Vector2(3.5, 3.5), Vector2(10.5, 6.5))
	assert_eq(grid.get_field_builds(), 1, "a direction toward the same goal uses the same field")
	grid.walk_distance(Vector2(3.5, 3.5), Vector2(11.5, 6.5))
	assert_eq(grid.get_field_builds(), 2, "a new goal tile")
	grid.walk_distance(Vector2(3.5, 3.5), Vector2(3.5, 3.5))
	assert_eq(grid.get_field_builds(), 2, "one tile builds nothing")


# --- AC27: asking changes no other answer --------------------------------------------------------


func test_ac27_walks_between_directions_and_lines_change_no_answer_of_the_reference() -> void:
	var compared: int = 0
	var moving: int = 0
	var rooms: Dictionary = _rooms()
	for label: String in rooms:
		var rows: PackedStringArray = rooms[label]
		var grid: NavGrid = NavGrid.from_rows(rows)
		var reference: NavGridReference = NavGridReference.from_rows(rows)
		var walker: Walker = Walker.new(rows)
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = hash(label) + 7
		var goal: Vector2 = _random_position(random, walker)
		for step: int in 1500:
			if random.randi() % 12 == 0:
				goal = _random_position(random, walker)
			var asker: Vector2 = _random_position(random, walker)
			match random.randi() % 3:
				0:
					# Any goal, not the current one: the field it builds is the next question's.
					grid.walk_distance(
						asker, _random_position(random, walker) if random.randi() % 2 == 0 else goal
					)
				1:
					var direction: Vector2 = grid.direction_toward(asker, goal)
					assert_eq(
						direction,
						reference.direction_toward(asker, goal),
						"%s step %d" % [label, step]
					)
					compared += 1
					if direction != Vector2.ZERO:
						moving += 1
				2:
					var radius: float = [0.25, 0.4, 0.6][random.randi() % 3]
					assert_eq(
						grid.has_clear_line(asker, goal, radius),
						reference.has_clear_line(asker, goal, radius),
						"%s step %d" % [label, step]
					)
					compared += 1
	assert_gt(compared, 8000, "many answers were compared")
	assert_gt(moving, 1000, "and many of them were directions")
	assert_eq(get_errors().size(), 0)
