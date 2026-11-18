# gdlint:disable=max-public-methods
extends GutTest
## F-011 AC5-AC9 on the NavGrid alone: clear lines, routing around walls, no corner cutting,
## the cached field, and sealed targets. Tile (x, y) has its centre at (x + 0.5, y + 0.5).

const STEP: float = 0.05
const MAX_WALK_STEPS: int = 4000

const OPEN: PackedStringArray = [
	"##########",
	"#........#",
	"#........#",
	"#........#",
	"#........#",
	"##########",
]

## A wall at x=5 from the top, with a gap in the two bottom rows.
const WALLED: PackedStringArray = [
	"############",
	"#....#.....#",
	"#....#.....#",
	"#....#.....#",
	"#....#.....#",
	"#..........#",
	"#..........#",
	"############",
]

## A 2x2 pillar in the middle of the room.
const PILLAR: PackedStringArray = [
	"############",
	"#..........#",
	"#..........#",
	"#....##....#",
	"#....##....#",
	"#..........#",
	"#..........#",
	"############",
]

## One wall tile at (4, 3) in an open room, for grazing corners.
const CORNER: PackedStringArray = [
	"..........",
	"..........",
	"..........",
	"....#.....",
	"..........",
	"..........",
	"..........",
]

## Walls at (1,0) and (0,1): the tile (0,0) is closed in, whatever the diagonal says.
const CLOSED_CORNER: PackedStringArray = [
	".#.",
	"#..",
	"...",
]

## The right half is sealed off by a full-height wall.
const SEALED: PackedStringArray = [
	"....#....",
	"....#....",
	"....#....",
	"....#....",
]


func test_from_rows_reads_walls_and_exit_tiles_as_not_walkable() -> void:
	var grid: NavGrid = NavGrid.from_rows(["#.E", "P1.", "..#"])
	assert_eq(grid.get_size(), Vector2i(3, 3))
	assert_false(grid.is_walkable(Vector2i(0, 0)), "#")
	assert_true(grid.is_walkable(Vector2i(1, 0)), ".")
	assert_false(grid.is_walkable(Vector2i(2, 0)), "E")
	assert_true(grid.is_walkable(Vector2i(0, 1)), "P")
	assert_true(grid.is_walkable(Vector2i(1, 1)), "a spawn digit")
	assert_false(grid.is_walkable(Vector2i(2, 2)), "#")


func test_outside_the_grid_is_not_walkable() -> void:
	var grid: NavGrid = NavGrid.from_rows(OPEN)
	for tile: Vector2i in [Vector2i(-1, 2), Vector2i(2, -1), Vector2i(10, 2), Vector2i(2, 6)]:
		assert_false(grid.is_walkable(tile), str(tile))


func test_tile_of_floors_positions_and_centres_are_half_a_tile_in() -> void:
	var grid: NavGrid = NavGrid.from_rows(OPEN)
	assert_eq(grid.tile_of(Vector2(2.5, 3.5)), Vector2i(2, 3))
	assert_eq(grid.tile_of(Vector2(2.0, 3.0)), Vector2i(2, 3))
	assert_eq(grid.tile_of(Vector2(1.999, 0.0)), Vector2i(1, 0))
	assert_eq(grid.tile_of(Vector2(-0.1, -0.1)), Vector2i(-1, -1))


# AC5 ------------------------------------------------------------------------------------------


func test_ac5_a_line_across_open_floor_is_clear() -> void:
	var grid: NavGrid = NavGrid.from_rows(OPEN)
	assert_true(grid.has_clear_line(Vector2(1.5, 1.5), Vector2(8.5, 1.5), 0.4))
	assert_true(grid.has_clear_line(Vector2(1.5, 1.5), Vector2(8.5, 4.5), 0.4))
	assert_true(grid.has_clear_line(Vector2(3.5, 2.5), Vector2(3.5, 2.5), 0.4), "a point")


func test_ac5_a_line_through_a_wall_is_blocked() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	assert_false(grid.has_clear_line(Vector2(2.5, 2.5), Vector2(8.5, 2.5), 0.1))
	assert_false(grid.has_clear_line(Vector2(2.5, 2.5), Vector2(8.5, 2.5), 0.0))
	assert_true(grid.has_clear_line(Vector2(2.5, 5.5), Vector2(8.5, 5.5), 0.4), "through the gap")


func test_ac5_the_radius_decides_how_near_a_wall_may_pass() -> void:
	# Row y=1 runs 0.5 tiles from the wall row above it (its tiles span y 0 to 1).
	var grid: NavGrid = NavGrid.from_rows(OPEN)
	var from: Vector2 = Vector2(1.5, 1.5)
	var to: Vector2 = Vector2(8.5, 1.5)
	assert_true(grid.has_clear_line(from, to, 0.49), "0.01 clear of the wall")
	assert_false(grid.has_clear_line(from, to, 0.51), "0.01 into the wall")
	# F-011/C3: touching counts as blocked, within the shared distance epsilon.
	assert_false(grid.has_clear_line(from, to, 0.5), "exactly touching")
	assert_true(grid.has_clear_line(from, to, 0.5 - 0.0001), "just short of touching")


func test_ac5_radius_applies_to_the_endpoints_not_only_the_middle() -> void:
	# A wall tile (4, 3) spans x 4..5, y 3..4. The segment ends 0.3 left of it.
	var grid: NavGrid = NavGrid.from_rows(CORNER)
	var from: Vector2 = Vector2(0.5, 3.5)
	var to: Vector2 = Vector2(3.7, 3.5)
	assert_true(grid.has_clear_line(from, to, 0.29))
	assert_false(grid.has_clear_line(from, to, 0.31))


func test_ac5_a_segment_that_only_grazes_a_corner_is_blocked() -> void:
	var grid: NavGrid = NavGrid.from_rows(CORNER)
	# y = 4.0 along the tile's bottom-left corner (4, 4): it ends on the corner point.
	assert_false(grid.has_clear_line(Vector2(1.0, 4.0), Vector2(4.0, 4.0), 0.0), "ends on it")
	assert_true(grid.has_clear_line(Vector2(1.0, 4.0), Vector2(3.9, 4.0), 0.0), "stops short")
	assert_false(grid.has_clear_line(Vector2(3.0, 5.0), Vector2(4.0, 4.0), 0.0), "diagonal in")
	assert_true(grid.has_clear_line(Vector2(3.0, 5.0), Vector2(3.9, 4.1), 0.0), "diagonal short")


func test_ac5_the_nearest_point_can_be_a_corner() -> void:
	var grid: NavGrid = NavGrid.from_rows(CORNER)
	# The segment ends at (3.0, 4.3): the wall's nearest point is the corner (4, 4), at
	# sqrt(1 + 0.3 * 0.3) = 1.044.
	var from: Vector2 = Vector2(2.0, 4.3)
	var to: Vector2 = Vector2(3.0, 4.3)
	assert_true(grid.has_clear_line(from, to, 1.04))
	assert_false(grid.has_clear_line(from, to, 1.05))


func test_ac5_outside_the_grid_counts_as_wall() -> void:
	var grid: NavGrid = NavGrid.from_rows(CORNER)
	assert_false(grid.has_clear_line(Vector2(1.5, 1.5), Vector2(-3.0, 1.5), 0.1), "leaves it")
	assert_false(grid.has_clear_line(Vector2(-2.0, 1.5), Vector2(-1.0, 1.5), 0.1), "all outside")
	assert_false(
		grid.has_clear_line(Vector2(0.5, 0.5), Vector2(5.5, 0.5), 0.6), "radius off the top"
	)
	assert_true(grid.has_clear_line(Vector2(0.5, 0.5), Vector2(5.5, 0.5), 0.4), "radius inside it")


func test_ac5_a_segment_starting_inside_a_wall_is_blocked() -> void:
	var grid: NavGrid = NavGrid.from_rows(CORNER)
	assert_false(grid.has_clear_line(Vector2(4.5, 3.5), Vector2(4.6, 3.5), 0.0))
	assert_false(grid.has_clear_line(Vector2(4.5, 3.5), Vector2(8.5, 5.5), 0.3))


func test_ac5_order_of_the_endpoints_does_not_matter() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	for pair: Array in [
		[Vector2(2.5, 2.5), Vector2(8.5, 2.5)],
		[Vector2(2.5, 5.5), Vector2(8.5, 5.5)],
		[Vector2(1.5, 1.5), Vector2(10.5, 6.5)],
	]:
		assert_eq(
			grid.has_clear_line(pair[0], pair[1], 0.4), grid.has_clear_line(pair[1], pair[0], 0.4)
		)


# AC6 ------------------------------------------------------------------------------------------


func test_ac6_walks_around_a_wall_to_the_target_tile() -> void:
	_assert_walk(WALLED, Vector2(1.5, 1.5), Vector2(9.5, 1.5))
	_assert_walk(WALLED, Vector2(9.5, 1.5), Vector2(1.5, 1.5))
	_assert_walk(WALLED, Vector2(4.5, 1.5), Vector2(6.5, 4.5))


func test_ac6_walks_around_a_pillar() -> void:
	_assert_walk(PILLAR, Vector2(2.5, 3.5), Vector2(9.5, 4.5))
	_assert_walk(PILLAR, Vector2(9.5, 3.5), Vector2(2.5, 3.5))
	_assert_walk(PILLAR, Vector2(6.0, 2.2), Vector2(6.0, 5.8))


func test_ac6_walks_from_off_centre_positions() -> void:
	_assert_walk(WALLED, Vector2(4.05, 1.05), Vector2(6.95, 3.95))
	_assert_walk(PILLAR, Vector2(3.95, 2.95), Vector2(7.05, 5.05))


func test_ac6_in_the_open_it_walks_the_shortest_way() -> void:
	var grid: NavGrid = NavGrid.from_rows(OPEN)
	assert_eq(grid.direction_toward(Vector2(1.5, 1.5), Vector2(6.5, 1.5)), Vector2.RIGHT)
	assert_eq(grid.direction_toward(Vector2(1.5, 1.5), Vector2(1.5, 4.5)), Vector2.DOWN)
	var diagonal: Vector2 = grid.direction_toward(Vector2(1.5, 1.5), Vector2(4.5, 4.5))
	assert_almost_eq(diagonal.x, Vector2(1, 1).normalized().x, 0.000001, "a diagonal step first")
	assert_almost_eq(diagonal.y, Vector2(1, 1).normalized().y, 0.000001)


func test_ac6_the_answer_is_a_unit_vector() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	for position: Vector2 in [Vector2(1.5, 1.5), Vector2(4.2, 3.9), Vector2(9.5, 6.5)]:
		var direction: Vector2 = grid.direction_toward(position, Vector2(6.5, 1.5))
		assert_almost_eq(direction.length(), 1.0, 0.000001, str(position))


func test_ac6_same_tile_is_zero() -> void:
	var grid: NavGrid = NavGrid.from_rows(OPEN)
	assert_eq(grid.direction_toward(Vector2(2.1, 2.1), Vector2(2.9, 2.9)), Vector2.ZERO)


func test_ac6_a_position_inside_a_wall_uses_the_nearest_walkable_tile() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	# Nudged 0.1 into the wall column x=5 from its left edge: nearest open tile is (4, 2).
	var direction: Vector2 = grid.direction_toward(Vector2(5.1, 2.5), Vector2(1.5, 2.5))
	assert_eq(direction, Vector2.LEFT, "back toward the target, via tile (3, 2)")
	# The same from the target side of a wall, standing 0.1 into the wall from its right edge.
	var right: Vector2 = grid.direction_toward(Vector2(5.9, 2.5), Vector2(9.5, 2.5))
	assert_eq(right, Vector2.RIGHT)


func test_ac6_a_target_inside_a_wall_uses_its_nearest_walkable_tile() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	var direction: Vector2 = grid.direction_toward(Vector2(2.5, 2.5), Vector2(5.1, 2.5))
	assert_eq(direction, Vector2.RIGHT, "aims at (4, 2), the nearest open tile")


func test_out_of_grid_positions_do_not_crash_and_route_to_the_nearest_tile() -> void:
	var grid: NavGrid = NavGrid.from_rows(OPEN)
	var direction: Vector2 = grid.direction_toward(Vector2(-4.0, 2.5), Vector2(6.5, 2.5))
	assert_almost_eq(direction.length(), 1.0, 0.000001)
	assert_gt(direction.x, 0.0)


# AC7 ------------------------------------------------------------------------------------------


func test_ac7_no_diagonal_between_two_diagonal_walls() -> void:
	var grid: NavGrid = NavGrid.from_rows(CLOSED_CORNER)
	assert_eq(
		grid.direction_toward(Vector2(0.5, 0.5), Vector2(1.5, 1.5)),
		Vector2.ZERO,
		"(0,0) is closed in: its only exit would be the diagonal"
	)
	assert_eq(grid.direction_toward(Vector2(1.5, 1.5), Vector2(0.5, 0.5)), Vector2.ZERO)


func test_ac7_one_wall_beside_the_diagonal_also_forbids_it() -> void:
	var grid: NavGrid = NavGrid.from_rows([".#.", "...", "..."])
	# From (0,0) to (1,1): the step right is a wall, so the diagonal is out. It goes down.
	assert_eq(grid.direction_toward(Vector2(0.5, 0.5), Vector2(1.5, 1.5)), Vector2.DOWN)
	var other: NavGrid = NavGrid.from_rows(["...", "#..", "..."])
	assert_eq(other.direction_toward(Vector2(0.5, 0.5), Vector2(1.5, 1.5)), Vector2.RIGHT)


func test_ac7_the_diagonal_is_taken_when_both_orthogonals_are_open() -> void:
	var grid: NavGrid = NavGrid.from_rows(["...", "...", "..."])
	var direction: Vector2 = grid.direction_toward(Vector2(0.5, 0.5), Vector2(1.5, 1.5))
	assert_almost_eq(direction.x, Vector2(1, 1).normalized().x, 0.000001)
	assert_almost_eq(direction.y, Vector2(1, 1).normalized().y, 0.000001)


func test_ac7_a_walked_path_never_clips_a_wall_corner() -> void:
	# A staircase of diagonal-only gaps: every step must go round, never through.
	var rows: PackedStringArray = [
		"......",
		".#....",
		"..#...",
		"...#..",
		"....#.",
		"......",
	]
	_assert_walk(rows, Vector2(0.5, 0.5), Vector2(5.5, 5.5))
	_assert_walk(rows, Vector2(5.5, 0.5), Vector2(0.5, 5.5))


# AC8 ------------------------------------------------------------------------------------------


func test_ac8_the_field_is_built_once_per_target_tile() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	assert_eq(grid.get_field_builds(), 0, "nothing built before the first question")
	grid.direction_toward(Vector2(1.5, 1.5), Vector2(9.5, 1.5))
	assert_eq(grid.get_field_builds(), 1)
	grid.direction_toward(Vector2(2.5, 3.5), Vector2(9.5, 1.5))
	grid.direction_toward(Vector2(1.5, 5.5), Vector2(9.9, 1.1))  # Same tile, other point.
	grid.direction_toward(Vector2(8.5, 5.5), Vector2(9.0, 1.0))
	assert_eq(grid.get_field_builds(), 1, "same target tile: no rebuild")
	grid.direction_toward(Vector2(1.5, 1.5), Vector2(9.5, 2.5))
	assert_eq(grid.get_field_builds(), 2, "a new target tile rebuilds")
	grid.direction_toward(Vector2(1.5, 1.5), Vector2(9.5, 2.5))
	assert_eq(grid.get_field_builds(), 2)


func test_ac8_questions_that_need_no_field_do_not_build_one() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	grid.direction_toward(Vector2(2.1, 2.1), Vector2(2.9, 2.9))  # One tile.
	grid.has_clear_line(Vector2(1.5, 1.5), Vector2(3.5, 1.5), 0.4)
	assert_eq(grid.get_field_builds(), 0)


func test_ac8_two_askers_get_the_same_answers_in_either_order() -> void:
	var target: Vector2 = Vector2(9.5, 1.5)
	var first: Vector2 = Vector2(1.5, 1.5)
	var second: Vector2 = Vector2(2.5, 6.5)
	var forward: NavGrid = NavGrid.from_rows(WALLED)
	var forward_first: Vector2 = forward.direction_toward(first, target)
	var forward_second: Vector2 = forward.direction_toward(second, target)
	var backward: NavGrid = NavGrid.from_rows(WALLED)
	var backward_second: Vector2 = backward.direction_toward(second, target)
	var backward_first: Vector2 = backward.direction_toward(first, target)
	assert_eq(forward_first, backward_first)
	assert_eq(forward_second, backward_second)


func test_ac8_an_answer_does_not_depend_on_which_fields_were_built_before() -> void:
	var fresh: NavGrid = NavGrid.from_rows(PILLAR)
	var used: NavGrid = NavGrid.from_rows(PILLAR)
	used.direction_toward(Vector2(2.5, 2.5), Vector2(9.5, 5.5))
	used.direction_toward(Vector2(2.5, 2.5), Vector2(1.5, 5.5))
	for from: Vector2 in [Vector2(2.5, 3.5), Vector2(5.9, 2.1), Vector2(9.5, 1.5)]:
		for to: Vector2 in [Vector2(9.5, 4.5), Vector2(1.5, 1.5)]:
			assert_eq(used.direction_toward(from, to), fresh.direction_toward(from, to))


func test_c4_ties_between_equal_routes_go_to_the_fixed_neighbour_order() -> void:
	# Around the pillar the way above and the way below are equally long. Same answer always.
	var grid: NavGrid = NavGrid.from_rows(PILLAR)
	var from: Vector2 = Vector2(3.5, 3.9)
	var to: Vector2 = Vector2(8.5, 3.9)
	var answer: Vector2 = grid.direction_toward(from, to)
	for _i: int in 5:
		assert_eq(NavGrid.from_rows(PILLAR).direction_toward(from, to), answer)
		assert_eq(grid.direction_toward(from, to), answer)


# AC9 ------------------------------------------------------------------------------------------


func test_ac9_a_sealed_off_target_has_no_direction() -> void:
	var grid: NavGrid = NavGrid.from_rows(SEALED)
	assert_eq(grid.direction_toward(Vector2(1.5, 1.5), Vector2(7.5, 1.5)), Vector2.ZERO)
	assert_eq(grid.direction_toward(Vector2(7.5, 1.5), Vector2(1.5, 1.5)), Vector2.ZERO)
	assert_ne(
		grid.direction_toward(Vector2(0.5, 0.5), Vector2(3.5, 3.5)), Vector2.ZERO, "same side"
	)


func test_ac9_a_grid_with_no_open_tile_has_no_direction() -> void:
	var grid: NavGrid = NavGrid.from_rows(["###", "###"])
	assert_eq(grid.direction_toward(Vector2(1.5, 1.5), Vector2(2.5, 0.5)), Vector2.ZERO)
	var empty: NavGrid = NavGrid.from_rows(PackedStringArray())
	assert_eq(empty.get_size(), Vector2i.ZERO)
	assert_eq(empty.direction_toward(Vector2(1.5, 1.5), Vector2(2.5, 0.5)), Vector2.ZERO)
	assert_false(empty.has_clear_line(Vector2(0, 0), Vector2(1, 1), 0.1))


## Walks `from` to `to` in STEP moves along direction_toward. Never inside a wall tile, ends in
## the target's tile, and walks at most 1.5 times the shortest tile path.
func _assert_walk(rows: PackedStringArray, from: Vector2, to: Vector2) -> void:
	var grid: NavGrid = NavGrid.from_rows(rows)
	var label: String = "%s -> %s" % [from, to]
	var position: Vector2 = from
	var walked: float = 0.0
	var steps: int = 0
	while grid.tile_of(position) != grid.tile_of(to) and steps < MAX_WALK_STEPS:
		var direction: Vector2 = grid.direction_toward(position, to)
		if direction == Vector2.ZERO:
			break
		position += direction * STEP
		walked += STEP
		steps += 1
		if not grid.is_walkable(grid.tile_of(position)):
			fail_test("%s: entered wall tile %s at %s" % [label, grid.tile_of(position), position])
			return
	assert_eq(grid.tile_of(position), grid.tile_of(to), "%s: reached the target tile" % label)
	var shortest: float = _shortest_tile_path(rows, grid.tile_of(from), grid.tile_of(to))
	assert_lte(walked, shortest * 1.5, "%s: walked %.2f, shortest %.2f" % [label, walked, shortest])


## An independent reference: relax every edge until nothing improves. 8-way, a diagonal only
## when both orthogonals are open, centre to centre.
func _shortest_tile_path(rows: PackedStringArray, from: Vector2i, to: Vector2i) -> float:
	var grid: NavGrid = NavGrid.from_rows(rows)
	var size: Vector2i = grid.get_size()
	var cost: Dictionary = {from: 0.0}
	var changed: bool = true
	while changed:
		changed = false
		for y: int in size.y:
			for x: int in size.x:
				var tile: Vector2i = Vector2i(x, y)
				if not cost.has(tile):
					continue
				for dy: int in [-1, 0, 1]:
					for dx: int in [-1, 0, 1]:
						if dx == 0 and dy == 0:
							continue
						var next: Vector2i = tile + Vector2i(dx, dy)
						if not grid.is_walkable(next):
							continue
						if dx != 0 and dy != 0:
							if not (
								grid.is_walkable(tile + Vector2i(dx, 0))
								and grid.is_walkable(tile + Vector2i(0, dy))
							):
								continue
						var step: float = 1.0 if dx == 0 or dy == 0 else sqrt(2.0)
						if not cost.has(next) or cost[next] > cost[tile] + step + 1e-9:
							cost[next] = cost[tile] + step
							changed = true
	return cost.get(to, INF)
