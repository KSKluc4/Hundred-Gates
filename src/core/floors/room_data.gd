class_name RoomData
extends Resource
## One room as an ASCII tile grid (F-011/C6, D-012, G9). One character = one tile.
## `#` wall, `.` floor, `P` player start, `E` exit, `1`-`9` spawn of `enemies[digit - 1]`, `S` an
## arrival point of the room's reinforcements (F-014/C1): floor for every rule.
## Tile (x, y) has its centre at (x + 0.5, y + 0.5) tiles; the top-left corner is (0, 0).

const WALL: String = "#"
const FLOOR: String = "."
const PLAYER_START: String = "P"
const EXIT: String = "E"
const ARRIVAL_POINT: String = "S"
const LEGEND: String = "#.PES123456789"
const CARDINALS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## The 2x2 blocks that contain a tile, as the offset of each block's top-left corner.
const BLOCK_ORIGINS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO
]

@export var id: StringName = &""
## F-017/C12: a packed array is declared with its constructor, not `[]`: the export drops `= []`.
@export var rows: PackedStringArray = PackedStringArray()
@export var enemies: Array[EnemyData] = []
@export var is_boss_room: bool = false
## F-012/C8: a room with no enemies and no spawns, never a boss room (the town). Only a tower's
## town may be one: FloorData refuses it.
@export var is_safe_room: bool = false
## F-014/C1: the enemies that arrive during the fight, in arrival order. Each value is 1-based,
## like a spawn digit: `enemies[value - 1]`. Empty: the room has no waves.
@export var reinforcements: PackedInt32Array = PackedInt32Array()
## F-014/C1: how many enemies may be engaged at once before arrivals pause. 0 means
## `FloorTunables.wave_max_engaged`.
@export var max_engaged: int = 0


## Width of the first row by number of rows. validate() refuses a grid that isn't rectangular.
func get_size() -> Vector2i:
	return Vector2i(rows[0].length() if not rows.is_empty() else 0, rows.size())


## F-011 contract: floor, player start and spawns walk. Wall, exit and outside don't.
func is_walkable(tile: Vector2i) -> bool:
	var tile_char: String = _char_at(tile.x, tile.y)
	return (
		tile_char == FLOOR
		or tile_char == PLAYER_START
		or tile_char == ARRIVAL_POINT  # F-014/C1
		or _is_spawn_char(tile_char)
	)


## Centre of the `P` tile, in tiles. Zero when there is none (validate() refuses that).
func get_player_start_tiles() -> Vector2:
	for y: int in rows.size():
		var x: int = rows[y].find(PLAYER_START)
		if x >= 0:
			return _centre_of(Vector2i(x, y))
	return Vector2.ZERO


func get_exit_tiles() -> Array[Vector2i]:
	return _tiles_where(_is_exit_char)


## F-011/C7: row-major, ids `<EnemyData.id>_<n>`, n counting every spawn tile from 1. A digit
## without an enemy is skipped here and reported by validate().
func get_spawns() -> Array[RoomSpawn]:
	var spawns: Array[RoomSpawn] = []
	var tiles: Array[Vector2i] = _spawn_tiles()
	for index: int in tiles.size():
		var enemy_index: int = _char_at(tiles[index].x, tiles[index].y).to_int() - 1
		if enemy_index >= enemies.size() or enemies[enemy_index] == null:
			continue
		var spawn: RoomSpawn = RoomSpawn.new()
		spawn.enemy = enemies[enemy_index]
		spawn.position_tiles = _centre_of(tiles[index])
		spawn.combat_id = StringName("%s_%d" % [spawn.enemy.id, index + 1])
		spawns.append(spawn)
	return spawns


## F-014/C2: the enemies the room builds, the placed ones and the reinforcements. An entry
## without an enemy is skipped here (as in get_spawns()) and reported by validate().
func get_kill_target() -> int:
	return get_spawns().size() + get_reinforcement_spawns().size()


## F-014/C2: one per reinforcement, in arrival order. Ids go on from the last spawn tile
## (`<EnemyData.id>_<n>`, n counting every spawn tile and then every reinforcement from 1). The
## position is the first arrival point's centre, or zero when there is none (validate() refuses
## that); the director chooses where each one really arrives.
func get_reinforcement_spawns() -> Array[RoomSpawn]:
	var spawns: Array[RoomSpawn] = []
	var points: Array[Vector2] = get_arrival_points_tiles()
	var placed: int = _spawn_tiles().size()
	for index: int in reinforcements.size():
		var enemy_index: int = reinforcements[index] - 1
		if enemy_index < 0 or enemy_index >= enemies.size() or enemies[enemy_index] == null:
			continue
		var spawn: RoomSpawn = RoomSpawn.new()
		spawn.enemy = enemies[enemy_index]
		spawn.position_tiles = points[0] if not points.is_empty() else Vector2.ZERO
		spawn.combat_id = StringName("%s_%d" % [spawn.enemy.id, placed + index + 1])
		spawn.is_reinforcement = true
		spawns.append(spawn)
	return spawns


## F-014/C2: the centres of the `S` tiles, row-major.
func get_arrival_points_tiles() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for tile: Vector2i in _tiles_where(_is_arrival_char):
		points.append(_centre_of(tile))
	return points


## F-014/C2: `max_engaged`, or the tunable when the room leaves it at 0.
func get_max_engaged(rules: FloorTunables) -> int:
	return max_engaged if max_engaged > 0 else rules.wave_max_engaged


## F-011/C8, C16. Empty result means valid. Every error starts with the rule's name and, where
## it applies, names the tile `(x, y)`. All errors are returned, not the first.
func validate(rules: FloorTunables) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not _is_rectangular():
		errors.append("rectangular: every row must be the same length, and there must be rows")
		return errors  # nothing below can read a ragged grid
	_check_size(rules, errors)
	_check_legend(errors)
	_check_border(errors)
	_check_player_start(errors)
	_check_exit(rules, errors)
	_check_reachable(errors)
	_check_corridors(errors)
	_check_pinches(errors)
	_check_thin_walls(errors)
	_check_spawns(rules, errors)
	_check_waves(rules, errors)
	return errors


func _check_size(rules: FloorTunables, errors: PackedStringArray) -> void:
	var size: Vector2i = get_size()
	var fits: bool = (
		size.x >= rules.min_room_size.x
		and size.y >= rules.min_room_size.y
		and size.x <= rules.max_room_size.x
		and size.y <= rules.max_room_size.y
	)
	if not fits:
		errors.append(
			(
				"size: room is %d x %d, must be between %d x %d and %d x %d"
				% [
					size.x,
					size.y,
					rules.min_room_size.x,
					rules.min_room_size.y,
					rules.max_room_size.x,
					rules.max_room_size.y
				]
			)
		)


## Not a C16 rule: a character outside the legend, or a digit with no enemy, can't be built.
func _check_legend(errors: PackedStringArray) -> void:
	var size: Vector2i = get_size()
	for y: int in size.y:
		for x: int in size.x:
			var tile_char: String = _char_at(x, y)
			if not LEGEND.contains(tile_char):
				errors.append(
					"legend: tile %s has unknown character '%s'" % [_name(x, y), tile_char]
				)
			elif _is_spawn_char(tile_char) and tile_char.to_int() > enemies.size():
				errors.append(
					(
						"legend: tile %s spawns '%s' but enemies has %d entries"
						% [_name(x, y), tile_char, enemies.size()]
					)
				)
	for index: int in enemies.size():
		if enemies[index] == null:
			errors.append("legend: enemies[%d] must not be null" % index)


func _check_border(errors: PackedStringArray) -> void:
	var size: Vector2i = get_size()
	for y: int in size.y:
		for x: int in size.x:
			if not _is_border(x, y):
				continue
			var tile_char: String = _char_at(x, y)
			if tile_char != WALL and tile_char != EXIT:
				errors.append(
					"border: tile %s must be # or E, found '%s'" % [_name(x, y), tile_char]
				)


func _check_player_start(errors: PackedStringArray) -> void:
	var count: int = _tiles_where(_is_player_char).size()
	if count != 1:
		errors.append("player_start: exactly one P is required, found %d" % count)


## C16: one straight run on the border, not on a corner, long enough, touching floor. A corner
## tile is reported only as a corner, so each rule can fail on its own.
func _check_exit(rules: FloorTunables, errors: PackedStringArray) -> void:
	var exits: Array[Vector2i] = get_exit_tiles()
	if exits.size() < rules.exit_min_width_tiles:
		errors.append(
			"exit: needs at least %d E tiles, found %d" % [rules.exit_min_width_tiles, exits.size()]
		)
	if exits.is_empty():
		return
	var all_on_border: bool = true
	for tile: Vector2i in exits:
		if not _is_border(tile.x, tile.y):
			all_on_border = false
			errors.append("exit: tile %s is not on the border" % _name(tile.x, tile.y))
		elif _is_corner(tile):
			errors.append("exit: tile %s is on a corner" % _name(tile.x, tile.y))
		elif not is_walkable(tile + _inward(tile)):
			errors.append("exit: tile %s does not touch a walkable tile" % _name(tile.x, tile.y))
	if all_on_border:
		_check_exit_run(exits, errors)


## All exit tiles on one side of the border, with no gap between them.
func _check_exit_run(exits: Array[Vector2i], errors: PackedStringArray) -> void:
	var size: Vector2i = get_size()
	var sides: Array[Callable] = [
		func(tile: Vector2i) -> bool: return tile.y == 0,
		func(tile: Vector2i) -> bool: return tile.y == size.y - 1,
		func(tile: Vector2i) -> bool: return tile.x == 0,
		func(tile: Vector2i) -> bool: return tile.x == size.x - 1,
	]
	var vertical_side: bool = false
	var found: bool = false
	for side_index: int in sides.size():
		if exits.all(sides[side_index]):
			found = true
			vertical_side = side_index >= 2
			break
	if not found:
		errors.append("exit: E tiles must lie on one side of the border")
		return
	for index: int in range(1, exits.size()):
		var gap: Vector2i = exits[index] - exits[index - 1]
		if (gap.y if vertical_side else gap.x) != 1:
			errors.append(
				(
					"exit: E tiles must be one unbroken run, gap before tile %s"
					% _name(exits[index].x, exits[index].y)
				)
			)


## C16: flood fill from P, four ways. Needs exactly one P to mean anything.
func _check_reachable(errors: PackedStringArray) -> void:
	var starts: Array[Vector2i] = _tiles_where(_is_player_char)
	if starts.size() != 1:
		return
	var size: Vector2i = get_size()
	var reached: PackedByteArray = PackedByteArray()
	reached.resize(size.x * size.y)
	var open: Array[Vector2i] = [starts[0]]
	reached[starts[0].y * size.x + starts[0].x] = 1
	while not open.is_empty():
		var tile: Vector2i = open.pop_back()
		for step: Vector2i in CARDINALS:
			var next: Vector2i = tile + step
			if is_walkable(next) and reached[next.y * size.x + next.x] == 0:
				reached[next.y * size.x + next.x] = 1
				open.append(next)
	for y: int in size.y:
		for x: int in size.x:
			if is_walkable(Vector2i(x, y)) and reached[y * size.x + x] == 0:
				errors.append("reachable: tile %s can't be reached from P" % _name(x, y))


## C16: bodies are up to 0.8 tiles, so no floor tile may sit outside a 2x2 block of floor.
func _check_corridors(errors: PackedStringArray) -> void:
	var size: Vector2i = get_size()
	for y: int in size.y:
		for x: int in size.x:
			if is_walkable(Vector2i(x, y)) and not _in_block(Vector2i(x, y), is_walkable):
				errors.append(
					"corridor: floor tile %s is not in a 2x2 block of floor" % _name(x, y)
				)


## F-011/C16 (CR-2): two walkable tiles side by side must share a fully walkable 2x2 block, or two
## wall corners one tile apart leave a 1-tile opening that a 1.2-tile body enters and never leaves.
## Each pair is reported once, top or left tile first. A tile already refused by `corridor` is
## skipped, so a 1-tile corridor is one fault and not two; every room this rule refuses still fails.
func _check_pinches(errors: PackedStringArray) -> void:
	var size: Vector2i = get_size()
	for y: int in size.y:
		for x: int in size.x:
			var tile: Vector2i = Vector2i(x, y)
			if not is_walkable(tile) or not _in_block(tile, is_walkable):
				continue
			for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var other: Vector2i = tile + step
				if (
					is_walkable(other)
					and _in_block(other, is_walkable)
					and not _share_block(tile, other)
				):
					errors.append(
						(
							"pinch: floor tiles %s and %s share no 2x2 block of floor"
							% [_name(tile.x, tile.y), _name(other.x, other.y)]
						)
					)


## C16: melee can't reach through a wall, and a wall tile alone would be an easy dodge. Only
## interior walls are checked, but the block may borrow the border.
func _check_thin_walls(errors: PackedStringArray) -> void:
	var size: Vector2i = get_size()
	for y: int in size.y:
		for x: int in size.x:
			if _is_border(x, y) or _char_at(x, y) != WALL:
				continue
			if not _in_block(Vector2i(x, y), _is_wall):
				errors.append("thin_wall: wall tile %s is not in a 2x2 block of wall" % _name(x, y))


## C16: spawn distance from P, and how many spawns a combat or boss room holds (F-012/C8: a safe
## room holds none).
func _check_spawns(rules: FloorTunables, errors: PackedStringArray) -> void:
	var tiles: Array[Vector2i] = _spawn_tiles()
	var starts: Array[Vector2i] = _tiles_where(_is_player_char)
	if starts.size() == 1:
		for tile: Vector2i in tiles:
			var distance: float = _centre_of(tile).distance_to(_centre_of(starts[0]))
			if not distance >= rules.min_spawn_distance_tiles:
				errors.append(
					(
						"spawn_distance: spawn at %s is %.2f tiles from P, needs at least %s"
						% [_name(tile.x, tile.y), distance, rules.min_spawn_distance_tiles]
					)
				)
	if is_safe_room:
		_check_safe_room(tiles.size(), errors)
	elif is_boss_room:
		if tiles.size() != 1:
			errors.append("spawn_count: a boss room needs exactly 1 spawn, found %d" % tiles.size())
	elif tiles.size() < 1 or tiles.size() > rules.max_enemies_per_room:
		errors.append(
			(
				"spawn_count: a combat room needs 1 to %d spawns, found %d"
				% [rules.max_enemies_per_room, tiles.size()]
			)
		)


## F-012/C8: replaces the combat and boss spawn counts. Each failure is its own error.
func _check_safe_room(spawn_count: int, errors: PackedStringArray) -> void:
	if spawn_count != 0:
		errors.append("spawn_count: a safe room needs 0 spawns, found %d" % spawn_count)
	if not enemies.is_empty():
		errors.append("safe_room: enemies must be empty, has %d entries" % enemies.size())
	if is_boss_room:
		errors.append("safe_room: a safe room can't also be a boss room")


## F-014/C3: reinforcements and arrival points. A room with neither (and `max_engaged` 0) gets no
## error here. A boss room and a safe room can't hold waves: they get the error for that and not
## the ones that follow from it (a missing or orphaned arrival point, a value out of range, the
## kill target), so each rule can fail on its own.
func _check_waves(rules: FloorTunables, errors: PackedStringArray) -> void:
	var points: Array[Vector2i] = _tiles_where(_is_arrival_char)
	var combat_room: bool = not is_boss_room and not is_safe_room
	if max_engaged < 0:
		errors.append("waves: max_engaged is %d, must be >= 0" % max_engaged)
	_check_wave_room_kind(points, errors)
	if combat_room:
		_check_wave_counts(points.size(), rules, errors)
		for index: int in reinforcements.size():
			if reinforcements[index] < 1 or reinforcements[index] > enemies.size():
				errors.append(
					(
						"waves: reinforcements[%d] is %d but enemies has %d entries"
						% [index, reinforcements[index], enemies.size()]
					)
				)
		if not points.is_empty() and reinforcements.is_empty():
			for tile: Vector2i in points:
				errors.append(
					(
						"waves: arrival point at %s but the room has no reinforcements"
						% _name(tile.x, tile.y)
					)
				)
	_check_arrival_spacing(points, rules, errors)


## F-014/C3: reinforcements and `S` tiles in a boss room or a safe room.
func _check_wave_room_kind(points: Array[Vector2i], errors: PackedStringArray) -> void:
	var kinds: Dictionary[String, bool] = {"boss": is_boss_room, "safe": is_safe_room}
	for kind: String in kinds:
		if not kinds[kind]:
			continue
		if not reinforcements.is_empty():
			errors.append(
				(
					"waves: a %s room can't have reinforcements, found %d"
					% [kind, reinforcements.size()]
				)
			)
		for tile: Vector2i in points:
			errors.append(
				(
					"waves: arrival point at %s, a %s room can't have arrival points"
					% [_name(tile.x, tile.y), kind]
				)
			)


## F-014/C3: enough arrival points for the reinforcements, and a kill target within the limit.
func _check_wave_counts(point_count: int, rules: FloorTunables, errors: PackedStringArray) -> void:
	if reinforcements.is_empty():
		return
	if not point_count >= rules.wave_min_arrival_points:
		errors.append(
			(
				"waves: %d reinforcements need at least %d arrival points (S), found %d"
				% [reinforcements.size(), rules.wave_min_arrival_points, point_count]
			)
		)
	var kill_target: int = get_kill_target()
	if not kill_target <= rules.max_kill_target:
		errors.append(
			"waves: kill target is %d, at most %d allowed" % [kill_target, rules.max_kill_target]
		)


## F-014/C3: an `S` too near P, near another `S`, or near a spawn tile (centres).
func _check_arrival_spacing(
	points: Array[Vector2i], rules: FloorTunables, errors: PackedStringArray
) -> void:
	var starts: Array[Vector2i] = _tiles_where(_is_player_char)
	var spawn_tiles: Array[Vector2i] = _spawn_tiles()
	for index: int in points.size():
		var point: Vector2i = points[index]
		if starts.size() == 1:
			var from_start: float = _centre_of(point).distance_to(_centre_of(starts[0]))
			if not from_start >= rules.min_spawn_distance_tiles:
				errors.append(
					(
						"waves: arrival point at %s is %.2f tiles from P, needs at least %s"
						% [_name(point.x, point.y), from_start, rules.min_spawn_distance_tiles]
					)
				)
		for other: Vector2i in points.slice(index + 1):
			var apart: float = _centre_of(point).distance_to(_centre_of(other))
			if not apart >= rules.wave_spawn_gap_tiles:
				errors.append(
					(
						"waves: arrival points at %s and %s are %.2f tiles apart, needs at least %s"
						% [
							_name(point.x, point.y),
							_name(other.x, other.y),
							apart,
							rules.wave_spawn_gap_tiles
						]
					)
				)
		for spawn_tile: Vector2i in spawn_tiles:
			var from_spawn: float = _centre_of(point).distance_to(_centre_of(spawn_tile))
			if not from_spawn >= rules.wave_spawn_gap_tiles:
				(
					errors
					. append(
						(
							"waves: arrival point at %s is %.2f tiles from the spawn at %s, needs at least %s"
							% [
								_name(point.x, point.y),
								from_spawn,
								_name(spawn_tile.x, spawn_tile.y),
								rules.wave_spawn_gap_tiles
							]
						)
					)
				)


## True when some 2x2 block holding `tile` has `test` true on all four tiles.
func _in_block(tile: Vector2i, test: Callable) -> bool:
	for origin: Vector2i in BLOCK_ORIGINS:
		var corner: Vector2i = tile + origin
		if (
			test.call(corner)
			and test.call(corner + Vector2i.RIGHT)
			and test.call(corner + Vector2i.DOWN)
			and test.call(corner + Vector2i.ONE)
		):
			return true
	return false


## True when one fully walkable 2x2 block holds both tiles (which touch along an edge).
func _share_block(first: Vector2i, second: Vector2i) -> bool:
	for origin: Vector2i in BLOCK_ORIGINS:
		var corner: Vector2i = first + origin
		var covers_second: bool = (
			second.x >= corner.x
			and second.x <= corner.x + 1
			and second.y >= corner.y
			and second.y <= corner.y + 1
		)
		if (
			covers_second
			and is_walkable(corner)
			and is_walkable(corner + Vector2i.RIGHT)
			and is_walkable(corner + Vector2i.DOWN)
			and is_walkable(corner + Vector2i.ONE)
		):
			return true
	return false


func _is_rectangular() -> bool:
	if rows.is_empty() or rows[0].is_empty():
		return false
	for row: String in rows:
		if row.length() != rows[0].length():
			return false
	return true


func _is_wall(tile: Vector2i) -> bool:
	return _char_at(tile.x, tile.y) == WALL


func _is_border(x: int, y: int) -> bool:
	var size: Vector2i = get_size()
	return x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1


func _is_corner(tile: Vector2i) -> bool:
	var size: Vector2i = get_size()
	return (tile.x == 0 or tile.x == size.x - 1) and (tile.y == 0 or tile.y == size.y - 1)


## Direction from a non-corner border tile into the room.
func _inward(tile: Vector2i) -> Vector2i:
	var size: Vector2i = get_size()
	if tile.y == 0:
		return Vector2i.DOWN
	if tile.y == size.y - 1:
		return Vector2i.UP
	return Vector2i.RIGHT if tile.x == 0 else Vector2i.LEFT


func _spawn_tiles() -> Array[Vector2i]:
	return _tiles_where(_is_spawn_char)


## Row-major (top row first, left to right).
func _tiles_where(test: Callable) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y: int in rows.size():
		for x: int in rows[y].length():
			if test.call(rows[y][x]):
				tiles.append(Vector2i(x, y))
	return tiles


func _is_spawn_char(tile_char: String) -> bool:
	return tile_char.length() == 1 and tile_char >= "1" and tile_char <= "9"


func _is_arrival_char(tile_char: String) -> bool:
	return tile_char == ARRIVAL_POINT


func _is_exit_char(tile_char: String) -> bool:
	return tile_char == EXIT


func _is_player_char(tile_char: String) -> bool:
	return tile_char == PLAYER_START


## "" outside the grid or past the end of a short row.
func _char_at(x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return ""
	return rows[y][x]


func _centre_of(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


func _name(x: int, y: int) -> String:
	return "(%d, %d)" % [x, y]
