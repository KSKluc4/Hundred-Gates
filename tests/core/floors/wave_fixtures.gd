class_name WaveFixtures
extends RefCounted
## Valid rooms with reinforcements and arrival points, built in code for F-014 tests (no files).
## Built on RoomFixtures; shipped EnemyData only.

## 20 x 12, P at (1, 5), E at (19, 5) and (19, 6). Spawns: `1` at (8, 2), `2` at (13, 7).
## Arrival points `S`, row-major: (16, 3), (6, 4), (6, 9), (16, 9).
const WAVE_ROWS: Array[String] = [
	"####################",
	"#..................#",
	"#.......1..........#",
	"#...............S..#",
	"#.....S............#",
	"#P.................E",
	"#..................E",
	"#............2.....#",
	"#..................#",
	"#.....S.........S..#",
	"#..................#",
	"####################",
]
## `enemies` of wave_room(): `1` is a chaser, `2` a caster.
const REINFORCEMENTS: Array[int] = [1, 2, 1]
## The `S` tiles of WAVE_ROWS, row-major.
const ARRIVAL_TILES: Array[Vector2i] = [
	Vector2i(16, 3), Vector2i(6, 4), Vector2i(6, 9), Vector2i(16, 9)
]


static func rules() -> FloorTunables:
	return RoomFixtures.rules()


static func wave_rows() -> PackedStringArray:
	return PackedStringArray(WAVE_ROWS)


## WAVE_ROWS with every `S` turned into floor: a room with two spawns and no waves.
static func wave_rows_without_arrival_points() -> PackedStringArray:
	var rows: PackedStringArray = wave_rows()
	for tile: Vector2i in ARRIVAL_TILES:
		rows = RoomFixtures.with_tile(rows, tile.x, tile.y, ".")
	return rows


## The room of WAVE_ROWS: chaser and caster, reinforcements [1, 2, 1], `max_engaged` 0. Valid:
## kill target 5, four arrival points.
static func wave_room(room_id: StringName = &"wave_room") -> RoomData:
	var enemies: Array[EnemyData] = [RoomFixtures.chaser(), RoomFixtures.caster()]
	var data: RoomData = RoomFixtures.room(room_id, wave_rows(), enemies)
	data.reinforcements = PackedInt32Array(REINFORCEMENTS)
	return data


## The same grid and enemies with no reinforcements and no `S`: what the room was before waves.
static func wave_room_without_waves(room_id: StringName = &"no_waves") -> RoomData:
	var enemies: Array[EnemyData] = [RoomFixtures.chaser(), RoomFixtures.caster()]
	return RoomFixtures.room(room_id, wave_rows_without_arrival_points(), enemies)


## A room on `rows` (WAVE_ROWS when omitted) with the given reinforcements and chaser, caster.
static func room_with(
	reinforcements: Array[int], rows: PackedStringArray = PackedStringArray()
) -> RoomData:
	var data: RoomData = wave_room()
	if not rows.is_empty():
		data.rows = rows
	data.reinforcements = PackedInt32Array(reinforcements)
	return data


## The room with one tile of its grid replaced (it is changed in place and returned).
static func set_tile(data: RoomData, x: int, y: int, tile_char: String) -> RoomData:
	data.rows = RoomFixtures.with_tile(data.rows, x, y, tile_char)
	return data


## The room with an `S` on each tile (it is changed in place and returned).
static func add_arrival_points(data: RoomData, tiles: Array[Vector2i]) -> RoomData:
	for tile: Vector2i in tiles:
		set_tile(data, tile.x, tile.y, RoomData.ARRIVAL_POINT)
	return data


## The room with an `S` replaced by floor on each tile (changed in place and returned).
static func remove_arrival_points(data: RoomData, tiles: Array[Vector2i]) -> RoomData:
	for tile: Vector2i in tiles:
		set_tile(data, tile.x, tile.y, RoomData.FLOOR)
	return data


## A boss room on RoomFixtures.valid_rows() (one spawn, a warden): a valid boss room with no waves.
static func boss_room(room_id: StringName = &"boss") -> RoomData:
	return RoomFixtures.valid_boss_room(room_id)


## A safe room on the grid of the town fixture's small room: no spawns, no enemies.
static func safe_room(room_id: StringName = &"safe") -> RoomData:
	return TowerFixtures.safe_room(room_id)
