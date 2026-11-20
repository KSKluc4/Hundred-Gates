class_name TowerFixtures
extends RefCounted
## Valid safe rooms, towns, floors and towers built in code for F-012 tests (no files). Built on
## RoomFixtures; every room id is unique across a tower (F-012/C9).

## The town of floors.md: 24 x 14, the gate 4 tiles wide centred on a border, P in the lower
## half, two 2 x 2 blocks beside the path to a north gate.
const TOWN_SIZE: Vector2i = Vector2i(24, 14)
const GATE_WIDTH: int = 4
const TOWN_PLAYER_START: Vector2i = Vector2i(11, 10)
const FLANK_BLOCKS: Array[Vector2i] = [Vector2i(7, 4), Vector2i(15, 4)]


static func rules() -> FloorTunables:
	return RoomFixtures.rules()


static func tower_rules() -> TowerTunables:
	return Tunables.tower.duplicate()


## RoomFixtures.valid_rows() with its one spawn turned into floor: 12 x 8, P at (1, 3), E at
## (11, 3) and (11, 4).
static func safe_rows() -> PackedStringArray:
	return RoomFixtures.with_tile(RoomFixtures.valid_rows(), 9, 5, ".")


static func safe_room(room_id: StringName = &"safe") -> RoomData:
	return safe_room_with(room_id, safe_rows())


## A safe room (no enemies) with any grid.
static func safe_room_with(room_id: StringName, rows: PackedStringArray) -> RoomData:
	var data: RoomData = RoomData.new()
	data.id = room_id
	data.rows = rows
	data.enemies = [] as Array[EnemyData]
	data.is_safe_room = true
	return data


## The town grid with the gate on one border: Vector2i.UP (north, the default), DOWN, LEFT or
## RIGHT. Only the gate moves; P and the blocks stay where they are.
static func town_rows(gate_side: Vector2i = Vector2i.UP) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for y: int in TOWN_SIZE.y:
		if y == 0 or y == TOWN_SIZE.y - 1:
			rows.append("#".repeat(TOWN_SIZE.x))
		else:
			rows.append("#" + ".".repeat(TOWN_SIZE.x - 2) + "#")
	for origin: Vector2i in FLANK_BLOCKS:
		for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			rows = RoomFixtures.with_tile(rows, origin.x + offset.x, origin.y + offset.y, "#")
	rows = RoomFixtures.with_tile(rows, TOWN_PLAYER_START.x, TOWN_PLAYER_START.y, "P")
	for tile: Vector2i in gate_tiles(gate_side):
		rows = RoomFixtures.with_tile(rows, tile.x, tile.y, "E")
	return rows


## The `E` tiles of town_rows(gate_side), row-major.
static func gate_tiles(gate_side: Vector2i = Vector2i.UP) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for step: int in GATE_WIDTH:
		var along_x: int = (TOWN_SIZE.x - GATE_WIDTH) / 2 + step
		var along_y: int = (TOWN_SIZE.y - GATE_WIDTH) / 2 + step
		if gate_side == Vector2i.UP:
			tiles.append(Vector2i(along_x, 0))
		elif gate_side == Vector2i.DOWN:
			tiles.append(Vector2i(along_x, TOWN_SIZE.y - 1))
		elif gate_side == Vector2i.LEFT:
			tiles.append(Vector2i(0, along_y))
		else:
			tiles.append(Vector2i(TOWN_SIZE.x - 1, along_y))
	return tiles


static func town_room(room_id: StringName = &"town", gate_side: Vector2i = Vector2i.UP) -> RoomData:
	return safe_room_with(room_id, town_rows(gate_side))


## Floor `floor_number` with `combat_rooms` combat rooms (ids `f<n>_room_1`...) then a boss room
## `f<n>_boss`. Unlike RoomFixtures.valid_floor(), ids differ from floor to floor.
static func floor_of(floor_number: int, combat_rooms: int = 1) -> FloorData:
	var data: FloorData = FloorData.new()
	data.floor_number = floor_number
	var list: Array[RoomData] = []
	for index: int in combat_rooms:
		var room_id: StringName = StringName("f%d_room_%d" % [floor_number, index + 1])
		list.append(RoomFixtures.valid_room(room_id))
	list.append(RoomFixtures.valid_boss_room(StringName("f%d_boss" % floor_number)))
	data.rooms = list
	return data


## A valid tower: the town `town` and `floor_count` floors from floor_of().
static func tower_of(floor_count: int, combat_rooms_per_floor: int = 1) -> TowerData:
	var data: TowerData = TowerData.new()
	data.town = town_room()
	var list: Array[FloorData] = []
	for number: int in range(1, floor_count + 1):
		list.append(floor_of(number, combat_rooms_per_floor))
	data.floors = list
	return data
