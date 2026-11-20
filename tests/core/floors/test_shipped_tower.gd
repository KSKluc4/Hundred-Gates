# gdlint:disable=max-public-methods
extends GutTest
## F-012 T6 (AC25): the shipped town and tower pass validation with the shipped rules and match
## studio/design/floors.md "Town (phase 1)", as F-013/C11 overrides it. The numbers below are
## written out on purpose: a change to the data must change them too.

## F-013/C11: 64 x 36, a tile is 16 px, so the town is 1024 x 576 px and the view is 640 x 360.
const TOWN_SIZE: Vector2i = Vector2i(64, 36)
## The gate is 4 tiles wide on the north border: x 30..33 on row 0.
const GATE_TILES: Array[Vector2i] = [
	Vector2i(30, 0), Vector2i(31, 0), Vector2i(32, 0), Vector2i(33, 0)
]
## F-013/C11: `P` is the tile (32, 9), so the gate is on screen at the start.
const PLAYER_START_TILE: Vector2i = Vector2i(32, 9)
## The gate must be at most this many rows above `P` (the view is 22.5 rows high).
const GATE_MAX_ROWS_ABOVE_P: int = 9
## F-013/C11: the two 2 x 2 blocks that flank the path to the gate.
const FLANK_BLOCK_RECTS: Array[Rect2i] = [Rect2i(26, 4, 2, 2), Rect2i(36, 4, 2, 2)]
## F-013/C11: the four 3 x 3 blocks in the lower half.
const BIG_BLOCK_RECTS: Array[Rect2i] = [
	Rect2i(14, 20, 3, 3), Rect2i(47, 20, 3, 3), Rect2i(14, 28, 3, 3), Rect2i(47, 28, 3, 3)
]
const FLOOR_PATHS: Array[String] = [
	Tunables.FLOOR_1_PATH, Tunables.FLOOR_2_PATH, Tunables.FLOOR_3_PATH
]
const BIG_BLOCK_SIZE: Vector2i = Vector2i(3, 3)
## F-013/C7: the shipped value, rounded up from the 640 x 360 view in 16 px tiles.
const SHIPPED_SCREEN_TILES: Vector2i = Vector2i(40, 23)
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


func test_c11_town_is_64_by_36_tiles_border_included() -> void:
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


func test_c11_player_start_is_tile_32_9_and_the_gate_is_on_screen_at_the_start() -> void:
	var town: RoomData = _town()
	var start: Vector2 = town.get_player_start_tiles()
	assert_eq(Vector2i(floori(start.x), floori(start.y)), PLAYER_START_TILE, "the P tile")
	assert_eq(start, Vector2(32.5, 9.5), "its centre")
	for tile: Vector2i in town.get_exit_tiles():
		assert_lte(
			PLAYER_START_TILE.y - tile.y,
			GATE_MAX_ROWS_ABOVE_P,
			"gate tile %s is near P's row" % tile
		)


func test_ac25_player_start_is_horizontally_under_the_gate() -> void:
	var town: RoomData = _town()
	var start: Vector2 = town.get_player_start_tiles()
	var gate: Array[Vector2i] = town.get_exit_tiles()
	var gate_centre_x: float = (gate[0].x + gate[-1].x + 1) / 2.0
	assert_gte(floori(start.x), gate[0].x, "P is not left of the gate")
	assert_lte(floori(start.x), gate[-1].x, "P is not right of the gate")
	# A 4-wide gate in a 64-wide room has its centre on a tile edge: P sits half a tile off it.
	assert_lte(absf(start.x - gate_centre_x), 0.5, "P within half a tile of the gate's centre line")


func test_c11_town_has_exactly_the_six_blocks_at_c11s_tiles() -> void:
	var town: RoomData = _town()
	var blocks: Array[Rect2i] = _interior_wall_blocks(town)
	assert_eq(blocks.size(), 6, "separate interior wall components")
	for block: Rect2i in FLANK_BLOCK_RECTS + BIG_BLOCK_RECTS:
		assert_true(blocks.has(block), "a block at %s" % block)
	# 2 x 2 blocks and 3 x 3 blocks only: their bounding boxes are full, so no tile is extra.
	assert_eq(_interior_wall_tiles(town).size(), 2 * 4 + 4 * 9, "the interior walls are only those")
	var two_by_two: int = 0
	var three_by_three: int = 0
	for block: Rect2i in blocks:
		two_by_two += 1 if block.size == Vector2i(2, 2) else 0
		three_by_three += 1 if block.size == BIG_BLOCK_SIZE else 0
	assert_eq(two_by_two, 2, "2 x 2 blocks")
	assert_eq(three_by_three, 4, "3 x 3 blocks")


func test_c11_blocks_are_symmetric_about_the_gate_centre_line() -> void:
	var town: RoomData = _town()
	var gate: Array[Vector2i] = town.get_exit_tiles()
	var gate_centre_x: float = (gate[0].x + gate[-1].x + 1) / 2.0
	assert_eq(_interior_wall_blocks(town).size(), 6, "six blocks")
	for tile: Vector2i in _interior_wall_tiles(town):
		# Mirror across x = gate_centre_x: tile column x maps to (2 * centre - 1) - x.
		var mirrored: Vector2i = Vector2i(int(2.0 * gate_centre_x) - 1 - tile.x, tile.y)
		assert_eq(town.rows[mirrored.y][mirrored.x], RoomData.WALL, "mirror of wall %s" % tile)
	var blocks: Array[Rect2i] = _interior_wall_blocks(town)
	for block: Rect2i in blocks:
		var mirrored_x: int = int(2.0 * gate_centre_x) - block.end.x
		assert_true(
			blocks.has(Rect2i(mirrored_x, block.position.y, block.size.x, block.size.y)),
			"block %s has a mirror image of its own size" % block
		)


func test_c11_the_two_by_two_blocks_flank_the_path_from_the_player_to_the_gate() -> void:
	var town: RoomData = _town()
	var gate: Array[Vector2i] = town.get_exit_tiles()
	var start: Vector2i = Vector2i(town.get_player_start_tiles())
	var west: int = 0
	var east: int = 0
	for block: Rect2i in _interior_wall_blocks(town):
		if block.size != Vector2i(2, 2):
			continue
		var is_west: bool = block.end.x <= gate[0].x
		var is_east: bool = block.position.x > gate[-1].x
		assert_true(
			is_west or is_east, "block %s is beside the gate, not in front of it" % block.position
		)
		west += 1 if is_west else 0
		east += 1 if is_east else 0
		assert_true(
			block.position.y >= 1 and block.end.y <= start.y,
			"block %s is between the gate row and P" % block.position
		)
	assert_eq(west, 1, "one 2 x 2 block west of the gate")
	assert_eq(east, 1, "one 2 x 2 block east of the gate")


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
		assert_true(gate.is_engaged(), "engaged at %s" % tile)
		gate.release()  # F-012/C10: the engagement ends before the latch can see the player leave.
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


# --- F-013 AC9: the one-screen rule on the shipped tower ---


func test_ac9_the_shipped_tower_is_valid_with_the_one_screen_rule_on() -> void:
	var tower: TowerData = _tower()
	assert_ne(tower.screen_size_tiles, Vector2i.ZERO, "the rule is on")
	assert_eq(tower.validate(_rules), PackedStringArray())


func test_ac9_the_shipped_screen_size_is_40_by_23_tiles() -> void:
	assert_eq(_tower().screen_size_tiles, SHIPPED_SCREEN_TILES)


func test_ac9_the_shipped_screen_size_covers_the_project_viewport() -> void:
	var view: Vector2i = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	var needed: Vector2i = Vector2i(
		ceili(float(view.x) / Units.TILE_SIZE_PX), ceili(float(view.y) / Units.TILE_SIZE_PX)
	)
	assert_eq(_tower().screen_size_tiles, needed, "the viewport %s, rounded up in tiles" % view)


func test_ac9_every_shipped_room_and_the_town_is_at_least_one_screen() -> void:
	var tower: TowerData = _tower()
	var rooms: Array[RoomData] = [tower.town]
	for floor_data: FloorData in tower.floors:
		rooms.append_array(floor_data.rooms)
	assert_eq(rooms.size(), 16, "the town and the 15 floor rooms")
	for room: RoomData in rooms:
		var size: Vector2i = room.get_size()
		assert_gte(size.x, tower.screen_size_tiles.x, "%s width" % room.id)
		assert_gte(size.y, tower.screen_size_tiles.y, "%s height" % room.id)


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
