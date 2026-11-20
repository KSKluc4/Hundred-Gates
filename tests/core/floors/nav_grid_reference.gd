class_name NavGridReference
extends RefCounted
## F-011/C5 (D-012): the room's walls as a tile grid, for brains that must walk around them.
## Pure logic over rows, so a server can run it too (G6). Tile (x, y) has its centre at
## (x + 0.5, y + 0.5) tiles (F-011/C6). A tile is walkable unless it is '#' or 'E'; outside the
## grid is wall. The distance field is derived data: never serialized, never in a snapshot.

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
## Costs closer than this are a tie, so float noise can't change which neighbour wins (C4).
const COST_EPSILON: float = 1e-9

var _width: int = 0
var _height: int = 0
## Row-major, one byte per tile: 1 walkable, 0 wall.
var _walkable: PackedByteArray = PackedByteArray()
## Cached field for the last target tile (C5). Cost to reach the target, INF where it can't.
var _field: PackedFloat64Array = PackedFloat64Array()
var _field_target: Vector2i = Vector2i.ZERO
var _has_field: bool = false
var _builds: int = 0
## Scratch for the build's priority queue; empty between builds.
var _heap_cost: PackedFloat64Array = PackedFloat64Array()
var _heap_index: PackedInt32Array = PackedInt32Array()


## F-011/C6: walkable is anything but '#' and 'E'. A short row is wall past its end.
static func from_rows(rows: PackedStringArray) -> NavGridReference:
	var grid: NavGridReference = NavGridReference.new()
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
func has_clear_line(from: Vector2, to: Vector2, radius_tiles: float) -> bool:
	var limit: float = radius_tiles + Geometry.DISTANCE_EPSILON
	var reach: Vector2 = Vector2.ONE * limit  # A tile that only touches the box counts too.
	var low: Vector2 = Vector2(minf(from.x, to.x), minf(from.y, to.y)) - reach
	var high: Vector2 = Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + reach
	for y: int in range(floori(low.y), floori(high.y) + 1):
		for x: int in range(floori(low.x), floori(high.x) + 1):
			if is_walkable(Vector2i(x, y)):
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
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_cost: float = INF
	for offset: Vector2i in NEIGHBOURS:
		if not _can_step(start, offset):
			continue
		var tile: Vector2i = start + offset
		var neighbour_cost: float = _field[tile.y * _width + tile.x]
		if neighbour_cost == INF:
			continue
		var total: float = neighbour_cost + _step_cost(offset)
		if total < best_cost - COST_EPSILON:  # F-011/C4: a near-tie keeps the earlier neighbour.
			best_cost = total
			best_tile = tile
	if best_tile.x < 0:
		return Vector2.ZERO
	return from.direction_to(_centre_of(best_tile))


## F-011 AC8: how many distance fields were built. Only a new target tile builds one.
func get_field_builds() -> int:
	return _builds


func _centre_of(tile: Vector2i) -> Vector2:
	return Vector2(tile.x + 0.5, tile.y + 0.5)


func _step_cost(offset: Vector2i) -> float:
	return DIAGONAL_COST if offset.x != 0 and offset.y != 0 else 1.0


## F-011/C5: a diagonal step needs both orthogonal neighbours walkable. No corner cutting.
func _can_step(tile: Vector2i, offset: Vector2i) -> bool:
	if not is_walkable(tile + offset):
		return false
	if offset.x != 0 and offset.y != 0:
		return (
			is_walkable(tile + Vector2i(offset.x, 0)) and is_walkable(tile + Vector2i(0, offset.y))
		)
	return true


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
func _ensure_field(goal: Vector2i) -> void:
	if _has_field and _field_target == goal:
		return
	_builds += 1
	_has_field = true
	_field_target = goal
	_field.resize(_width * _height)
	_field.fill(INF)
	_heap_cost.clear()
	_heap_index.clear()
	var goal_index: int = goal.y * _width + goal.x
	_field[goal_index] = 0.0
	_heap_push(0.0, goal_index)
	while not _heap_index.is_empty():
		var cost: float = _heap_cost[0]
		var index: int = _heap_index[0]
		_heap_pop()
		if cost > _field[index]:
			continue  # A stale entry: a cheaper one was already settled.
		var tile: Vector2i = Vector2i(index % _width, index / _width)
		for offset: Vector2i in NEIGHBOURS:
			# Steps are symmetric, so the field walks the same edges the path will take.
			if not _can_step(tile, offset):
				continue
			var next: Vector2i = tile + offset
			var next_index: int = next.y * _width + next.x
			var next_cost: float = cost + _step_cost(offset)
			if next_cost < _field[next_index] - COST_EPSILON:
				_field[next_index] = next_cost
				_heap_push(next_cost, next_index)


func _heap_less(a: int, b: int) -> bool:
	if _heap_cost[a] != _heap_cost[b]:
		return _heap_cost[a] < _heap_cost[b]
	return _heap_index[a] < _heap_index[b]


func _heap_push(cost: float, index: int) -> void:
	_heap_cost.append(cost)
	_heap_index.append(index)
	var child: int = _heap_index.size() - 1
	while child > 0:
		var parent: int = (child - 1) / 2
		if not _heap_less(child, parent):
			break
		_heap_swap(child, parent)
		child = parent


func _heap_pop() -> void:
	var last: int = _heap_index.size() - 1
	_heap_swap(0, last)
	_heap_cost.resize(last)
	_heap_index.resize(last)
	var parent: int = 0
	while true:
		var smallest: int = parent
		var left: int = parent * 2 + 1
		if left < last and _heap_less(left, smallest):
			smallest = left
		if left + 1 < last and _heap_less(left + 1, smallest):
			smallest = left + 1
		if smallest == parent:
			break
		_heap_swap(parent, smallest)
		parent = smallest


func _heap_swap(a: int, b: int) -> void:
	var cost: float = _heap_cost[a]
	var index: int = _heap_index[a]
	_heap_cost[a] = _heap_cost[b]
	_heap_index[a] = _heap_index[b]
	_heap_cost[b] = cost
	_heap_index[b] = index


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
