class_name NavGrid
extends RefCounted
## F-011/C5 (D-012): the room's walls as a tile grid, for brains that must walk around them.
## Pure logic over rows, so a server can run it too (G6). Tile (x, y) has its centre at
## (x + 0.5, y + 0.5) tiles (F-011/C6). A tile is walkable unless it is '#' or 'E'; outside the
## grid is wall. The distance field is derived data: never serialized, never in a snapshot.
## F-013/C17: cheaper, with every answer the same as before. The allowed steps of each tile are
## worked out once, the flow field is settled only as far as a question needs, and a line check
## visits only the tiles near its segment. tests/core/floors/nav_grid_reference.gd keeps the old
## code, and test_f013_nav_equivalence.gd compares the two.

## F-011/C4: the fixed neighbour order, which breaks every tie. Orthogonals first, then diagonals.
const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]
const DIAGONAL_COST: float = sqrt(2.0)
## For NEIGHBOURS[4..7], the bits of the two orthogonal steps (0 up, 1 right, 2 down, 3 left) that
## a diagonal step needs open: up-right, down-right, down-left, up-left (C5).
const DIAGONAL_BETWEEN: Array[int] = [0b0011, 0b0110, 0b1100, 0b1001]
## Costs closer than this are a tie, so float noise can't change which neighbour wins (C4).
const COST_EPSILON: float = 1e-9
## F-013/C17 (c): the slack, in tiles, of the line check's clip. The clip only chooses which tiles
## to test; a tile it keeps by mistake costs microseconds, a tile it drops by mistake is a wrong
## answer. So it must err on the side of keeping, and by more than every rounding it can meet:
## Vector2 holds 32-bit floats, a coordinate of 64 has steps of 7.6e-6, a difference of two such
## coordinates is off by up to 1.5e-5, and the distance test it feeds is off by about as much.
## The largest room is 80 x 46. 1e-3 is some 60 times the worst of that, so the rounding of 32-bit
## coordinates stays far below it for any allowed room, and well beyond. It is the slack of the
## row band (a row is skipped only when the segment is further than the limit by more than this);
## the columns of a visited row have CLIP_TILES on top. It costs at most an extra tile per row.
const CLIP_MARGIN: float = 1e-3
## The whole tiles added at each end of a row's columns, on top of CLIP_MARGIN. Columns only: the
## rows have no such tile.
const CLIP_TILES: int = 1
## `_settled` values: 0 not yet taken off the queue, 1 settled (its cost is final), 2 not yet
## settled and wanted by the question being answered (it stays 2 only when no path reaches it).
const UNSETTLED: int = 0
const SETTLED: int = 1
const WANTED: int = 2

var _width: int = 0
var _height: int = 0
## Row-major, one byte per tile: 1 walkable, 0 wall.
var _walkable: PackedByteArray = PackedByteArray()
## F-013/C17 (a): per tile, bit k set when a step along NEIGHBOURS[k] is allowed (C5: the tile
## is walkable and a diagonal step has both orthogonal neighbours walkable). Computed once.
var _steps: PackedByteArray = PackedByteArray()
## Per neighbour k: how far its tile index is from this one's, and what stepping there costs.
var _step_delta: PackedInt32Array = PackedInt32Array()
var _step_cost_of: PackedFloat64Array = PackedFloat64Array()
## Cached field for the last target tile (C5). Cost to reach the target, INF where it can't. It
## is settled lazily (F-013/C17 b): a tile's cost is final once `_settled` says so, and only
## those are read.
var _field: PackedFloat64Array = PackedFloat64Array()
var _settled: PackedByteArray = PackedByteArray()
var _field_target: Vector2i = Vector2i.ZERO
var _has_field: bool = false
var _builds: int = 0
## The build's priority queue, kept between questions so a field can be resumed. Entries
## `_heap_cost[i]`, `_heap_index[i]` for i < `_heap_count`; the rest of the arrays is spare room.
var _heap_cost: PackedFloat64Array = PackedFloat64Array()
var _heap_index: PackedInt32Array = PackedInt32Array()
var _heap_count: int = 0


## F-011/C6: walkable is anything but '#' and 'E'. A short row is wall past its end.
static func from_rows(rows: PackedStringArray) -> NavGrid:
	var grid: NavGrid = NavGrid.new()
	grid._height = rows.size()
	for row: String in rows:
		grid._width = maxi(grid._width, row.length())
	grid._walkable.resize(grid._width * grid._height)
	for y: int in grid._height:
		var row: String = rows[y]
		for x: int in row.length():
			var tile_char: String = row[x]
			var open: bool = tile_char != "#" and tile_char != "E"
			grid._walkable[y * grid._width + x] = 1 if open else 0
	grid._build_steps()
	return grid


func get_size() -> Vector2i:
	return Vector2i(_width, _height)


func is_walkable(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= _width or tile.y >= _height:
		return false
	return _walkable[tile.y * _width + tile.x] == 1


func tile_of(position_tiles: Vector2) -> Vector2i:
	return Vector2i(floori(position_tiles.x), floori(position_tiles.y))


## F-011/C3, AC5: true only if a circle of `radius_tiles` swept from `from` to `to` touches no
## wall tile. Exact: the distance from the segment to each tile in its inflated box, never
## sampled points. Touching counts as blocked, so a zero radius that grazes a corner is blocked.
## F-013/C17 (c): the tests are the same ones, on tiles of that same box, but a row of the box
## only visits the columns the segment passes near, so a long diagonal no longer tests the whole
## rectangle. A tile is left out only when the segment is further from it than the limit by more
## than CLIP_MARGIN: by that much for the tiles of a skipped row, and by a whole tile more for the
## columns left out of a visited row. Rounding of 32-bit coordinates stays far below that margin
## for rooms up to the allowed 80 x 46, and well beyond, so no tile that could have made the line
## blocked is ever left out. The clip never goes beyond the old box either.
func has_clear_line(from: Vector2, to: Vector2, radius_tiles: float) -> bool:
	var limit: float = radius_tiles + Geometry.DISTANCE_EPSILON
	var reach: Vector2 = Vector2.ONE * limit  # A tile that only touches the box counts too.
	var low: Vector2 = Vector2(minf(from.x, to.x), minf(from.y, to.y)) - reach
	var high: Vector2 = Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + reach
	var first_x: int = floori(low.x)
	var last_x: int = floori(high.x)
	var along: Vector2 = to - from
	var band: float = limit + CLIP_MARGIN
	for y: int in range(floori(low.y), floori(high.y) + 1):
		# The part of the segment within `band` of this row of tiles, as a range of t in 0..1.
		var t_first: float = 0.0
		var t_last: float = 1.0
		if along.y == 0.0:
			if from.y < y - band or from.y > y + 1.0 + band:
				continue
		else:
			var t_a: float = (y - band - from.y) / along.y
			var t_b: float = (y + 1.0 + band - from.y) / along.y
			t_first = maxf(0.0, minf(t_a, t_b))
			t_last = minf(1.0, maxf(t_a, t_b))
			if t_first > t_last:
				continue
		# Where that part starts and ends. An end the row did not cut is the segment's own end,
		# not `from + along * t`: `along` is a difference of 32-bit floats, and for a segment of
		# 32 tiles or more its rounding is larger than a margin of 1e-6 (the CR-1 bug).
		var x_first: float = from.x if t_first == 0.0 else from.x + along.x * t_first
		var x_last: float = to.x if t_last == 1.0 else from.x + along.x * t_last
		# A tile whose square is within `limit` of a point at x spans x - limit - 1 .. x + limit.
		# Slack at both ends, the same at each.
		var from_x: int = maxi(first_x, floori(minf(x_first, x_last) - band) - CLIP_TILES)
		var to_x: int = mini(last_x, floori(maxf(x_first, x_last) + band) + CLIP_TILES)
		for x: int in range(from_x, to_x + 1):
			if x >= 0 and y >= 0 and x < _width and y < _height and _walkable[y * _width + x] == 1:
				continue
			if _segment_to_tile_distance(from, to, Vector2i(x, y)) <= limit:
				return false
	return true


## F-011/C5: the unit vector from `from` to the centre of the next tile on the shortest path to
## `to`'s tile. ZERO when both are in one tile or no path exists (AC9). A position inside a wall
## (a body nudged into an edge) counts as the nearest walkable tile.
func direction_toward(from: Vector2, to: Vector2) -> Vector2:
	var goal: Vector2i = _nearest_walkable_tile(to)
	var start: Vector2i = _nearest_walkable_tile(from)
	if goal.x < 0 or start.x < 0 or start == goal:
		return Vector2.ZERO
	_ensure_field(goal)
	var start_index: int = start.y * _width + start.x
	var mask: int = _steps[start_index]
	_settle_around(start_index, mask)
	var best_k: int = -1
	var best_cost: float = INF
	for k: int in NEIGHBOURS.size():
		if mask & (1 << k) == 0:
			continue
		var neighbour_cost: float = _field[start_index + _step_delta[k]]
		if neighbour_cost == INF:
			continue
		var total: float = neighbour_cost + _step_cost_of[k]
		if total < best_cost - COST_EPSILON:  # F-011/C4: a near-tie keeps the earlier neighbour.
			best_cost = total
			best_k = k
	if best_k < 0:
		return Vector2.ZERO
	return from.direction_to(_centre_of(start + NEIGHBOURS[best_k]))


## F-011 AC8: how many distance fields were built. Only a new target tile builds one.
func get_field_builds() -> int:
	return _builds


func _centre_of(tile: Vector2i) -> Vector2:
	return Vector2(tile.x + 0.5, tile.y + 0.5)


## F-013/C17 (a): fills `_steps`, `_step_delta` and `_step_cost_of`. A step along NEIGHBOURS[k] is
## allowed from a walkable tile when the tile it lands on is walkable and, for a diagonal, both
## orthogonal neighbours are too (F-011/C5, no corner cutting). Walls get no steps. The grid is
## read through a copy with a wall frame around it, so no read needs a bounds check.
func _build_steps() -> void:
	_step_delta.resize(NEIGHBOURS.size())
	_step_cost_of.resize(NEIGHBOURS.size())
	var framed_width: int = _width + 2
	var framed_delta: PackedInt32Array = PackedInt32Array()
	framed_delta.resize(NEIGHBOURS.size())
	for k: int in NEIGHBOURS.size():
		var offset: Vector2i = NEIGHBOURS[k]
		_step_delta[k] = offset.y * _width + offset.x
		framed_delta[k] = offset.y * framed_width + offset.x
		_step_cost_of[k] = DIAGONAL_COST if offset.x != 0 and offset.y != 0 else 1.0
	var framed: PackedByteArray = PackedByteArray()
	framed.resize(framed_width * (_height + 2))
	framed.fill(0)
	for y: int in _height:
		for x: int in _width:
			framed[(y + 1) * framed_width + x + 1] = _walkable[y * _width + x]
	_steps.resize(_width * _height)
	_steps.fill(0)
	for y: int in _height:
		for x: int in _width:
			if _walkable[y * _width + x] == 0:
				continue
			var at: int = (y + 1) * framed_width + x + 1
			var mask: int = 0
			for k: int in 4:
				if framed[at + framed_delta[k]] == 1:
					mask |= 1 << k
			# NEIGHBOURS[4..7] are the diagonals, each between two of the orthogonals 0..3.
			for k: int in range(4, 8):
				var between: int = DIAGONAL_BETWEEN[k - 4]
				if mask & between == between and framed[at + framed_delta[k]] == 1:
					mask |= 1 << k
			_steps[y * _width + x] = mask


## The tile itself if walkable, else the walkable tile whose square is nearest the position
## (ties to the first in row-major order). (-1, -1) if the grid has none.
func _nearest_walkable_tile(position_tiles: Vector2) -> Vector2i:
	var tile: Vector2i = tile_of(position_tiles)
	if is_walkable(tile):
		return tile
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for y: int in _height:
		for x: int in _width:
			if _walkable[y * _width + x] == 0:
				continue
			var distance: float = _point_to_tile_distance(position_tiles, Vector2i(x, y))
			if distance < best_distance - COST_EPSILON:
				best_distance = distance
				best = Vector2i(x, y)
	return best


## Dijkstra from `goal` over 8 neighbours (C5). A binary heap of (cost, tile index), the index
## breaking cost ties so the build is the same every time (C4). Cached for the last goal.
## F-013/C17 (b): a new goal only starts the field (the goal in the queue, every other cost INF);
## _settle_around() runs it on, as far as a question needs.
func _ensure_field(goal: Vector2i) -> void:
	if _has_field and _field_target == goal:
		return
	_builds += 1
	_has_field = true
	_field_target = goal
	_field.resize(_width * _height)
	_field.fill(INF)
	_settled.resize(_width * _height)
	_settled.fill(UNSETTLED)
	if _heap_cost.is_empty():
		_heap_cost.resize(64)
		_heap_index.resize(64)
	var goal_index: int = goal.y * _width + goal.x
	_field[goal_index] = 0.0
	_heap_cost[0] = 0.0
	_heap_index[0] = goal_index
	_heap_count = 1


## F-013/C17 (b): runs the field's Dijkstra pass until every neighbour that `mask` allows from
## `tile_index` is settled, or the queue is empty. Tiles leave the queue in the same order as in
## a full pass, because the queue and its (cost, index) order are the same and the passes
## differ only in when they stop. A tile's cost is final the moment it leaves the queue (a later
## tile costs at least as much and every step costs at least 1, so nothing can lower it by more
## than COST_EPSILON), so the neighbours read afterwards hold exactly what a full pass would
## leave there. When the queue empties, every cost is final, INF included. A later call for
## the same goal carries on from the queue as it was left. The heap is written in place on local
## copies of the arrays, which this function owns while it runs.
func _settle_around(tile_index: int, mask: int) -> void:
	# Moved out of the members while this runs, so every write below is in place and not a copy.
	var settled: PackedByteArray = _settled
	var field: PackedFloat64Array = _field
	var heap_cost: PackedFloat64Array = _heap_cost
	var heap_index: PackedInt32Array = _heap_index
	_settled = PackedByteArray()
	_field = PackedFloat64Array()
	_heap_cost = PackedFloat64Array()
	_heap_index = PackedInt32Array()
	var heap_count: int = _heap_count
	var steps: PackedByteArray = _steps
	var step_delta: PackedInt32Array = _step_delta
	var step_cost: PackedFloat64Array = _step_cost_of
	var wanted: int = 0
	for k: int in 8:
		if mask & (1 << k) == 0:
			continue
		var near_index: int = tile_index + step_delta[k]
		if settled[near_index] == UNSETTLED:
			settled[near_index] = WANTED
			wanted += 1
	while wanted > 0 and heap_count > 0:
		var cost: float = heap_cost[0]
		var index: int = heap_index[0]
		heap_count -= 1
		if heap_count > 0:
			var moved_cost: float = heap_cost[heap_count]
			var moved_index: int = heap_index[heap_count]
			var hole: int = 0
			while true:
				var child: int = hole * 2 + 1
				if child >= heap_count:
					break
				var right: int = child + 1
				if right < heap_count:
					var right_cost: float = heap_cost[right]
					var left_cost: float = heap_cost[child]
					if (
						right_cost < left_cost
						or (right_cost == left_cost and heap_index[right] < heap_index[child])
					):
						child = right
				var child_cost: float = heap_cost[child]
				if (
					child_cost < moved_cost
					or (child_cost == moved_cost and heap_index[child] < moved_index)
				):
					heap_cost[hole] = child_cost
					heap_index[hole] = heap_index[child]
					hole = child
				else:
					break
			heap_cost[hole] = moved_cost
			heap_index[hole] = moved_index
		if cost > field[index]:
			continue  # A stale entry: a cheaper one was already settled.
		if settled[index] == WANTED:
			wanted -= 1
		settled[index] = SETTLED
		var allowed: int = steps[index]
		for k: int in 8:
			# Steps are symmetric, so the field walks the same edges the path will take.
			if allowed & (1 << k) == 0:
				continue
			var next_index: int = index + step_delta[k]
			var next_cost: float = cost + step_cost[k]
			if next_cost < field[next_index] - COST_EPSILON:
				field[next_index] = next_cost
				if heap_count == heap_cost.size():
					heap_cost.resize(heap_count * 2)
					heap_index.resize(heap_count * 2)
				var slot: int = heap_count
				heap_count += 1
				while slot > 0:
					var parent: int = (slot - 1) >> 1
					var parent_cost: float = heap_cost[parent]
					if (
						parent_cost < next_cost
						or (parent_cost == next_cost and heap_index[parent] < next_index)
					):
						break
					heap_cost[slot] = parent_cost
					heap_index[slot] = heap_index[parent]
					slot = parent
				heap_cost[slot] = next_cost
				heap_index[slot] = next_index
	# When the queue ran dry, a neighbour still WANTED has no path to the goal: its cost stays INF,
	# which is final, and the flag is never read again (an empty queue stays empty).
	_settled = settled
	_field = field
	_heap_cost = heap_cost
	_heap_index = heap_index
	_heap_count = heap_count


## Distance from a point to the closed square of `tile`. 0 inside.
func _point_to_tile_distance(point: Vector2, tile: Vector2i) -> float:
	var nearest: Vector2 = Vector2(
		clampf(point.x, tile.x, tile.x + 1.0), clampf(point.y, tile.y, tile.y + 1.0)
	)
	return point.distance_to(nearest)


## Distance from segment a-b to the closed square of `tile`: 0 if they meet, else the smallest of
## the endpoints to the square and the square's corners to the segment (exact for convex shapes).
func _segment_to_tile_distance(a: Vector2, b: Vector2, tile: Vector2i) -> float:
	if _segment_meets_tile(a, b, tile):
		return 0.0
	var best: float = minf(_point_to_tile_distance(a, tile), _point_to_tile_distance(b, tile))
	for corner_x: int in [tile.x, tile.x + 1]:
		for corner_y: int in [tile.y, tile.y + 1]:
			var corner: Vector2 = Vector2(corner_x, corner_y)
			best = minf(best, corner.distance_to(_closest_on_segment(corner, a, b)))
	return best


func _closest_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var along: Vector2 = b - a
	var length_squared: float = along.length_squared()
	if length_squared == 0.0:
		return a
	return a + along * clampf((point - a).dot(along) / length_squared, 0.0, 1.0)


## Liang-Barsky clip of segment a-b against the closed square of `tile`.
func _segment_meets_tile(a: Vector2, b: Vector2, tile: Vector2i) -> bool:
	var along: Vector2 = b - a
	var enter: float = 0.0
	var leave: float = 1.0
	var bounds_low: Vector2 = Vector2(tile.x, tile.y)
	var bounds_high: Vector2 = bounds_low + Vector2.ONE
	for axis: int in 2:
		if along[axis] == 0.0:
			if a[axis] < bounds_low[axis] or a[axis] > bounds_high[axis]:
				return false
			continue
		var t_low: float = (bounds_low[axis] - a[axis]) / along[axis]
		var t_high: float = (bounds_high[axis] - a[axis]) / along[axis]
		enter = maxf(enter, minf(t_low, t_high))
		leave = minf(leave, maxf(t_low, t_high))
		if enter > leave:
			return false
	return true
