class_name FloorFixtures
extends RefCounted
## F-011 T5: rooms and floors for the scene tests, built in code (no shipped floor files).
## Enemies are copies of the chaser, so a test can change any of it.

## 14 x 10. P at (1, 4). Two spawns: `1` at (9, 4), `2` at (9, 7). Exit: E at (13, 4) and (13, 5).
const ARENA_ROWS: Array[String] = [
	"##############",
	"#............#",
	"#............#",
	"#............#",
	"#P.......1...E",
	"#............E",
	"#............#",
	"#........2...#",
	"#............#",
	"##############",
]

## 16 x 10. P at (1, 4). One spawn at (11, 4), and a 2 x 2 pillar at (7..8, 4..5) between them.
## Exit: E at (15, 4) and (15, 5).
const PILLAR_ROWS: Array[String] = [
	"################",
	"#..............#",
	"#..............#",
	"#..............#",
	"#P.....##..1...E",
	"#......##......E",
	"#..............#",
	"#..............#",
	"#..............#",
	"################",
]

const WEAK_HP: int = 20


## A chaser with its own id and a few HP: two sword hits kill it. It never knocks back.
static func weak_enemy(enemy_id: StringName = &"grunt", hp: int = WEAK_HP) -> EnemyData:
	var data: EnemyData = EnemyArena.chaser_values()
	data.id = enemy_id
	data.max_hp = hp
	data.knockback_scale = 0.0
	return data


static func arena_rows() -> PackedStringArray:
	return PackedStringArray(ARENA_ROWS)


static func pillar_rows() -> PackedStringArray:
	return PackedStringArray(PILLAR_ROWS)


## The arena with only the first spawn: one weak enemy `grunt_1` at (9.5, 4.5).
static func one_enemy_rows() -> PackedStringArray:
	return RoomFixtures.with_tile(arena_rows(), 9, 7, ".")


## Two enemies, `grunt_1` (weak) and `chaser_2` (the shipped chaser).
static func arena_room(room_id: StringName = &"arena") -> RoomData:
	var enemies: Array[EnemyData] = [weak_enemy(), RoomFixtures.chaser()]
	return RoomFixtures.room(room_id, arena_rows(), enemies)


static func one_enemy_room(
	room_id: StringName = &"solo", enemy_id: StringName = &"grunt"
) -> RoomData:
	var enemies: Array[EnemyData] = [weak_enemy(enemy_id)]
	return RoomFixtures.room(room_id, one_enemy_rows(), enemies)


static func pillar_room(room_id: StringName = &"pillar", enemy: EnemyData = null) -> RoomData:
	var enemies: Array[EnemyData] = [enemy if enemy != null else RoomFixtures.chaser()]
	return RoomFixtures.room(room_id, pillar_rows(), enemies)


## 20 x 10. P at (1, 4). A wall 2 tiles thick at x = 9..10 from the top and the bottom border,
## with one 2-tile gap at y = 4..5. One spawn `1` at `spawn` (default (12, 2), east of the wall).
## Exit: E at (19, 4) and (19, 5).
static func divider_rows(spawn: Vector2i = Vector2i(12, 2)) -> PackedStringArray:
	var rows: PackedStringArray = []
	for y: int in 10:
		var row: String = "#" + ".".repeat(18) + "#"
		if y == 0 or y == 9:
			row = "#".repeat(20)
		elif y != 4 and y != 5:
			row = row.substr(0, 9) + "##" + row.substr(11)
		rows.append(row)
	rows[4] = "#P" + ".".repeat(17) + "E"
	rows[5] = "#" + ".".repeat(18) + "E"
	return RoomFixtures.with_tile(rows, spawn.x, spawn.y, "1")


static func divider_room(
	enemy: EnemyData, spawn: Vector2i = Vector2i(12, 2), room_id: StringName = &"divider"
) -> RoomData:
	var enemies: Array[EnemyData] = [enemy]
	return RoomFixtures.room(room_id, divider_rows(spawn), enemies)


## The one-enemy room with its exit on the north border at (6, 0) and (7, 0).
static func north_exit_room(room_id: StringName = &"north") -> RoomData:
	var rows: PackedStringArray = RoomFixtures.with_tile(one_enemy_rows(), 13, 4, "#")
	rows = RoomFixtures.with_tile(rows, 13, 5, "#")
	rows = RoomFixtures.with_tile(rows, 6, 0, "E")
	rows = RoomFixtures.with_tile(rows, 7, 0, "E")
	var enemies: Array[EnemyData] = [weak_enemy()]
	return RoomFixtures.room(room_id, rows, enemies)


## The one-enemy room with its exit on the west border at (0, 4) and (0, 5), P moved to (3, 7).
static func west_exit_room(room_id: StringName = &"west") -> RoomData:
	var rows: PackedStringArray = RoomFixtures.with_tile(one_enemy_rows(), 13, 4, "#")
	rows = RoomFixtures.with_tile(rows, 13, 5, "#")
	rows = RoomFixtures.with_tile(rows, 1, 4, ".")
	rows = RoomFixtures.with_tile(rows, 3, 7, "P")
	rows = RoomFixtures.with_tile(rows, 0, 4, "E")
	rows = RoomFixtures.with_tile(rows, 0, 5, "E")
	var enemies: Array[EnemyData] = [weak_enemy()]
	return RoomFixtures.room(room_id, rows, enemies)


## A boss room whose "boss" is a weak enemy `warden_test`, so a test kills it in one call.
static func boss_room(room_id: StringName = &"boss") -> RoomData:
	var enemies: Array[EnemyData] = [weak_enemy(&"warden_test", 40)]
	return RoomFixtures.room(room_id, one_enemy_rows(), enemies, true)


## `first` rooms, then the boss room, as floor `floor_number`.
static func floor_of(rooms: Array[RoomData], floor_number: int = 1) -> FloorData:
	var data: FloorData = FloorData.new()
	data.floor_number = floor_number
	var list: Array[RoomData] = rooms.duplicate()
	list.append(boss_room())
	data.rooms = list
	return data


## F-014 T4: 24 x 12, P at (1, 5), E at (23, 5) and (23, 6). One placed enemy `1` (a chaser) at
## (21, 10), asleep, and one reinforcement (a chaser). A 2 x 6 pillar at x = 14..15, y = 3..8, with
## a 2-tile gap above and below, stands between the arrival points `S` at (20, 4) and (20, 7) and a
## player at (10.5, 5.5), ten tiles west of them.
static func wave_pillar_room(room_id: StringName = &"wave_pillar") -> RoomData:
	var rows: PackedStringArray = []
	for y: int in 12:
		var row: String = "#" + ".".repeat(22) + "#"
		if y == 0 or y == 11:
			row = "#".repeat(24)
		elif y >= 3 and y <= 8:
			row = row.substr(0, 14) + "##" + row.substr(16)
		rows.append(row)
	rows[5] = "#P" + ".".repeat(12) + "##" + ".".repeat(7) + "E"
	rows[6] = "#" + ".".repeat(13) + "##" + ".".repeat(7) + "E"
	rows = RoomFixtures.with_tile(rows, 20, 4, "S")
	rows = RoomFixtures.with_tile(rows, 20, 7, "S")
	rows = RoomFixtures.with_tile(rows, 21, 10, "1")
	var enemies: Array[EnemyData] = [RoomFixtures.chaser()]
	var data: RoomData = RoomFixtures.room(room_id, rows, enemies)
	data.reinforcements = PackedInt32Array([1])
	return data
