class_name RoomFixtures
extends RefCounted
## Valid rooms and floors built in code for F-011 tests (no files). Shipped EnemyData only.

## 12 x 8. P at (1, 3). Exit: E at (11, 3) and (11, 4). One spawn, `1`, at (9, 5).
const VALID_ROWS: Array[String] = [
	"############",
	"#..........#",
	"#..........#",
	"#P.........E",
	"#..........E",
	"#........1.#",
	"#..........#",
	"############",
]


static func rules() -> FloorTunables:
	return Tunables.floors.duplicate()


static func chaser() -> EnemyData:
	return load(Tunables.CHASER_PATH)


static func caster() -> EnemyData:
	return load(Tunables.CASTER_PATH)


static func brute() -> EnemyData:
	return load(Tunables.BRUTE_PATH)


static func warden() -> EnemyData:
	return load(Tunables.WARDEN_PATH)


static func valid_rows() -> PackedStringArray:
	return PackedStringArray(VALID_ROWS)


## `enemies` defaults to one chaser, for the single spawn of VALID_ROWS.
static func room(
	room_id: StringName,
	rows: PackedStringArray,
	enemies: Array[EnemyData] = [],
	is_boss_room: bool = false
) -> RoomData:
	var data: RoomData = RoomData.new()
	data.id = room_id
	data.rows = rows
	var list: Array[EnemyData] = enemies
	if list.is_empty():
		list = [warden() if is_boss_room else chaser()]
	data.enemies = list
	data.is_boss_room = is_boss_room
	return data


static func valid_room(room_id: StringName = &"room") -> RoomData:
	return room(room_id, valid_rows())


static func valid_boss_room(room_id: StringName = &"boss") -> RoomData:
	return room(room_id, valid_rows(), [warden()], true)


## `combat_rooms` combat rooms (ids `room_1`...) then a boss room `boss`.
static func valid_floor(combat_rooms: int = 1, floor_number: int = 1) -> FloorData:
	var data: FloorData = FloorData.new()
	data.floor_number = floor_number
	var list: Array[RoomData] = []
	for index: int in combat_rooms:
		list.append(valid_room(StringName("room_%d" % (index + 1))))
	list.append(valid_boss_room())
	data.rooms = list
	return data


## The rows with one tile replaced.
static func with_tile(
	rows: PackedStringArray, x: int, y: int, tile_char: String
) -> PackedStringArray:
	var copy: PackedStringArray = rows.duplicate()
	var row: String = copy[y]
	copy[y] = row.substr(0, x) + tile_char + row.substr(x + 1)
	return copy
