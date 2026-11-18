# gdlint:disable=max-public-methods
extends GutTest
## F-012 T6 (AC25): the shipped town and tower pass validation with the shipped rules and match
## studio/design/floors.md "Town (phase 1)". The numbers below are written out on purpose: a change
## to the data must change them too.

const TOWN_SIZE: Vector2i = Vector2i(24, 14)
## The gate is 4 tiles wide, centred on the north border: x 10..13 on row 0.
const GATE_TILES: Array[Vector2i] = [
	Vector2i(10, 0), Vector2i(11, 0), Vector2i(12, 0), Vector2i(13, 0)
]
const FLOOR_PATHS: Array[String] = [
	Tunables.FLOOR_1_PATH, Tunables.FLOOR_2_PATH, Tunables.FLOOR_3_PATH
]
const BLOCK_SIZE: Vector2i = Vector2i(2, 2)
## A walk toward the gate moves this far per step, and gives up after this many steps.
const WALK_STEP_TILES: float = 0.25
const WALK_MAX_STEPS: int = 400

var _rules: FloorTunables


func before_each() -> void:
	_rules = Tunables.floors


# --- AC25: the town ---


func test_ac25_town_path_constants_name_the_shipped_files() -> void:
	assert_eq(Tunables.TOWN_PATH, "res://data/floors/town.tres")
	assert_eq(Tunables.TOWER_PATH, "res://data/floors/tower.tres")
	assert_true(ResourceLoader.exists(Tunables.TOWN_PATH), "town file exists")
	assert_true(ResourceLoader.exists(Tunables.TOWER_PATH), "tower file exists")


func test_ac25_town_loads_as_a_room_data_called_town() -> void:
	var town: RoomData = _town()
	assert_eq(town.id, &"town")


func test_ac25_town_is_a_safe_room_and_not_a_boss_room() -> void:
	var town: RoomData = _town()
	assert_true(town.is_safe_room, "is_safe_room")
	assert_false(town.is_boss_room, "is_boss_room")


func test_ac25_town_has_no_enemies_and_no_spawns() -> void:
	var town: RoomData = _town()
	assert_eq(town.enemies.size(), 0, "enemies")
	assert_eq(town.get_spawns().size(), 0, "get_spawns()")
	for row: String in town.rows:
		for digit: String in "123456789":
			assert_false(row.contains(digit), "no spawn digit %s in '%s'" % [digit, row])


func test_ac25_town_is_24_by_14_tiles_border_included() -> void:
	assert_eq(_town().get_size(), TOWN_SIZE)


func test_ac25_town_passes_validation_with_the_shipped_rules() -> void:
	assert_eq(_town().validate(_rules), PackedStringArray())


func test_ac25_town_holds_only_wall_floor_the_gate_and_one_player_start() -> void:
	var town: RoomData = _town()
	var legend: String = "#.PE"
	var starts: int = 0
	for row: String in town.rows:
		for index: int in row.length():
			assert_true(legend.contains(row[index]), "'%s' is in the town legend" % row[index])
			if row[index] == RoomData.PLAYER_START:
				starts += 1
	assert_eq(starts, 1, "one P")


func test_ac25_town_exit_tiles_are_exactly_the_four_north_border_tiles() -> void:
	assert_eq(_town().get_exit_tiles(), GATE_TILES)


func test_ac25_gate_is_centred_on_the_north_border() -> void:
	var exits: Array[Vector2i] = _town().get_exit_tiles()
	assert_eq(exits.size(), 4, "gate width")
	var left_wall: int = exits[0].x
	var right_wall: int = TOWN_SIZE.x - 1 - exits[-1].x
	assert_eq(left_wall, right_wall, "as many border tiles each side of the gate")
	for tile: Vector2i in exits:
		assert_eq(tile.y, 0, "gate tile %s on the north border" % tile)


func test_ac25_player_start_is_in_the_lower_half() -> void:
	var start: Vector2 = _town().get_player_start_tiles()
	assert_gt(start.y, float(TOWN_SIZE.y) / 2.0, "P below the middle row")
	assert_lt(start.y, float(TOWN_SIZE.y - 1), "P inside the south wall")


func test_ac25_player_start_is_horizontally_under_the_gate() -> void:
	var town: RoomData = _town()
	var start: Vector2 = town.get_player_start_tiles()
	var gate: Array[Vector2i] = town.get_exit_tiles()
	var gate_centre_x: float = (gate[0].x + gate[-1].x + 1) / 2.0
	assert_gte(floori(start.x), gate[0].x, "P is not left of the gate")
	assert_lte(floori(start.x), gate[-1].x, "P is not right of the gate")
	# A 4-wide gate in a 24-wide room has its centre on a tile edge: P sits half a tile off it.
	assert_lte(absf(start.x - gate_centre_x), 0.5, "P within half a tile of the gate's centre line")


func test_ac25_town_has_exactly_two_two_by_two_blocks() -> void:
	var blocks: Array[Rect2i] = _interior_wall_blocks(_town())
	assert_eq(blocks.size(), 2, "separate interior wall components")
	for block: Rect2i in blocks:
		assert_eq(block.size, BLOCK_SIZE, "block at %s is 2 x 2" % block.position)
	assert_eq(_interior_wall_tiles(_town()).size(), 8, "the interior walls are only those blocks")


func test_ac25_blocks_are_symmetric_about_the_gate_centre_line() -> void:
	var town: RoomData = _town()
	var gate: Array[Vector2i] = town.get_exit_tiles()
	var gate_centre_x: float = (gate[0].x + gate[-1].x + 1) / 2.0
	var blocks: Array[Rect2i] = _interior_wall_blocks(town)
	assert_eq(blocks.size(), 2, "two blocks")
	var left: Rect2i = blocks[0] if blocks[0].position.x < blocks[1].position.x else blocks[1]
	var right: Rect2i = blocks[1] if blocks[0].position.x < blocks[1].position.x else blocks[0]
	assert_eq(left.position.y, right.position.y, "same row")
	assert_lt(float(left.end.x), gate_centre_x, "left block is left of the centre line")
	assert_gt(float(right.position.x), gate_centre_x, "right block is right of the centre line")
	assert_eq(
		gate_centre_x - float(left.end.x),
		float(right.position.x) - gate_centre_x,
		"both blocks are the same distance from the centre line"
	)
	for tile: Vector2i in _interior_wall_tiles(town):
		# Mirror across x = gate_centre_x: tile column x maps to (2 * centre - 1) - x.
		var mirrored: Vector2i = Vector2i(int(2.0 * gate_centre_x) - 1 - tile.x, tile.y)
		assert_eq(town.rows[mirrored.y][mirrored.x], RoomData.WALL, "mirror of wall %s" % tile)


func test_ac25_blocks_flank_the_path_from_the_player_to_the_gate() -> void:
	var town: RoomData = _town()
	var gate: Array[Vector2i] = town.get_exit_tiles()
	var start: Vector2i = Vector2i(town.get_player_start_tiles())
	for block: Rect2i in _interior_wall_blocks(town):
		assert_true(
			block.end.x <= gate[0].x or block.position.x > gate[-1].x,
			"block %s is beside the gate, not in front of it" % block.position
		)
		assert_true(
			block.position.y >= 1 and block.end.y <= start.y,
			"block %s is between the gate row and P" % block.position
		)


func test_ac25_every_column_under_the_gate_is_open_down_to_the_player_row() -> void:
	# From the tile inside the gate down to P's row: the path to the gate is not blocked.
	var town: RoomData = _town()
	var start: Vector2i = Vector2i(town.get_player_start_tiles())
	for tile: Vector2i in town.get_exit_tiles():
		for y: int in range(1, start.y + 1):
			assert_true(town.is_walkable(Vector2i(tile.x, y)), "(%d, %d) is open" % [tile.x, y])


func test_ac25_return_position_from_each_gate_tile_is_the_walkable_tile_below_it() -> void:
	var town: RoomData = _town()
	var gate: TownGate = TownGate.new()
	gate.setup(town)
	for tile: Vector2i in town.get_exit_tiles():
		var from: Vector2 = Vector2(tile) + Vector2(0.5, 0.5)
		var back: Vector2 = gate.get_return_position_tiles(from)
		var back_tile: Vector2i = Vector2i(floori(back.x), floori(back.y))
		assert_eq(back, Vector2(tile.x + 0.5, 1.5), "return from gate tile %s" % tile)
		assert_true(town.is_walkable(back_tile), "return tile %s is walkable" % back_tile)


func test_ac25_gate_latch_fires_on_each_gate_tile_and_not_on_the_floor_below() -> void:
	var town: RoomData = _town()
	var gate: TownGate = TownGate.new()
	gate.setup(town)
	assert_false(gate.check(town.get_player_start_tiles()), "P is not on the gate")
	for tile: Vector2i in town.get_exit_tiles():
		assert_true(gate.check(Vector2(tile) + Vector2(0.5, 0.5)), "enters at %s" % tile)
		assert_false(gate.check(Vector2(tile.x + 0.5, 1.5)), "just inside is not the gate")


func test_ac25_nav_grid_has_a_path_from_the_player_start_to_the_tile_inside_the_gate() -> void:
	var town: RoomData = _town()
	var nav: NavGrid = NavGrid.from_rows(town.rows)
	var start: Vector2 = town.get_player_start_tiles()
	for tile: Vector2i in town.get_exit_tiles():
		var goal: Vector2 = Vector2(tile.x + 0.5, 1.5)
		var position: Vector2 = start
		var steps: int = 0
		while nav.tile_of(position) != nav.tile_of(goal) and steps < WALK_MAX_STEPS:
			var direction: Vector2 = nav.direction_toward(position, goal)
			if direction == Vector2.ZERO:
				break
			position += direction * WALK_STEP_TILES
			steps += 1
		assert_eq(nav.tile_of(position), nav.tile_of(goal), "P reaches the tile below %s" % tile)


func test_ac25_every_walkable_town_tile_has_a_path_from_the_player_start() -> void:
	var town: RoomData = _town()
	var nav: NavGrid = NavGrid.from_rows(town.rows)
	var start: Vector2 = town.get_player_start_tiles()
	for y: int in TOWN_SIZE.y:
		for x: int in TOWN_SIZE.x:
			if not town.is_walkable(Vector2i(x, y)):
				continue
			var target: Vector2 = Vector2(x + 0.5, y + 0.5)
			var same_tile: bool = nav.tile_of(target) == nav.tile_of(start)
			assert_true(
				same_tile or nav.direction_toward(start, target) != Vector2.ZERO,
				"no path from P to (%d, %d)" % [x, y]
			)


# --- AC25: the tower ---


func test_ac25_tower_loads_as_a_tower_data() -> void:
	assert_not_null(_tower())


func test_ac25_tower_passes_validation_with_the_shipped_rules() -> void:
	assert_eq(_tower().validate(_rules), PackedStringArray())


func test_ac25_tower_town_is_the_shipped_town() -> void:
	var tower: TowerData = _tower()
	assert_not_null(tower.town, "the tower has a town")
	assert_eq(tower.town.resource_path, Tunables.TOWN_PATH)
	assert_same(tower.town, _town())


func test_ac25_tower_has_exactly_three_floors() -> void:
	var tower: TowerData = _tower()
	assert_eq(tower.floors.size(), 3)
	assert_eq(tower.get_floor_count(), 3)


func test_ac25_tower_floors_are_floors_1_2_3_in_order() -> void:
	var tower: TowerData = _tower()
	for index: int in FLOOR_PATHS.size():
		var floor_data: FloorData = tower.floors[index]
		assert_not_null(floor_data, "floor %d is set" % (index + 1))
		assert_eq(floor_data.floor_number, index + 1, "floor number at position %d" % index)
		assert_eq(floor_data.resource_path, FLOOR_PATHS[index], "path of floor %d" % (index + 1))
		assert_same(floor_data, load(FLOOR_PATHS[index]) as FloorData)
		assert_same(tower.get_floor(index + 1), floor_data)
	assert_null(tower.get_floor(0), "no floor 0")
	assert_null(tower.get_floor(4), "no floor 4")


func test_ac25_room_ids_are_unique_across_the_whole_tower() -> void:
	var tower: TowerData = _tower()
	var ids: Array[StringName] = [tower.town.id]
	for floor_data: FloorData in tower.floors:
		for room: RoomData in floor_data.rooms:
			assert_false(ids.has(room.id), "room id %s is used once" % room.id)
			ids.append(room.id)
	assert_eq(ids.size(), 1 + 4 + 5 + 6, "the town and the 15 floor rooms")


func test_ac25_the_town_is_not_a_room_of_any_floor() -> void:
	for floor_data: FloorData in _tower().floors:
		for room: RoomData in floor_data.rooms:
			assert_false(room.is_safe_room, "%s is not a safe room" % room.id)


func test_ac25_shipped_tower_tunables_validate() -> void:
	assert_eq(Tunables.tower.validate(), PackedStringArray())


# --- helpers ---


func _town() -> RoomData:
	var loaded: RoomData = load(Tunables.TOWN_PATH) as RoomData
	assert_not_null(loaded, "town loads as RoomData")
	return loaded if loaded != null else RoomData.new()


func _tower() -> TowerData:
	var loaded: TowerData = load(Tunables.TOWER_PATH) as TowerData
	assert_not_null(loaded, "tower loads as TowerData")
	return loaded if loaded != null else TowerData.new()


func _interior_wall_tiles(room: RoomData) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var size: Vector2i = room.get_size()
	for y: int in range(1, size.y - 1):
		for x: int in range(1, size.x - 1):
			if room.rows[y][x] == RoomData.WALL:
				tiles.append(Vector2i(x, y))
	return tiles


## The bounding box of each four-way connected group of interior wall tiles.
func _interior_wall_blocks(room: RoomData) -> Array[Rect2i]:
	var left: Array[Vector2i] = _interior_wall_tiles(room)
	var blocks: Array[Rect2i] = []
	while not left.is_empty():
		var open: Array[Vector2i] = [left.pop_back()]
		var box: Rect2i = Rect2i(open[0], Vector2i.ONE)
		while not open.is_empty():
			var tile: Vector2i = open.pop_back()
			box = box.expand(tile).expand(tile + Vector2i.ONE)
			for step: Vector2i in RoomData.CARDINALS:
				var index: int = left.find(tile + step)
				if index >= 0:
					open.append(left[index])
					left.remove_at(index)
		blocks.append(box)
	return blocks
