# gdlint:disable=max-public-methods
extends GutTest
## F-011 T6 (AC24, AC25, AC27): the shipped floors 1-3 pass validation with the shipped rules,
## match the encounter tables of studio/design/floors.md, and every spawn can walk to P.
## The tables below are written out on purpose: a change to a room's data must change them too.

const FLOOR_ROOM_IDS: Dictionary = {
	1: [&"f1_r1", &"f1_r2", &"f1_r3", &"f1_boss"],
	2: [&"f2_r1", &"f2_r2", &"f2_r3", &"f2_r4", &"f2_boss"],
	3: [&"f3_r1", &"f3_r2", &"f3_r3", &"f3_r4", &"f3_r5", &"f3_boss"],
}

## floors.md encounter table: enemy id -> how many spawn in the room. A boss room is its boss.
const ENCOUNTERS: Dictionary = {
	&"f1_r1": {&"chaser": 2},
	&"f1_r2": {&"chaser": 3},
	&"f1_r3": {&"chaser": 4},
	&"f1_boss": {&"warden": 1},
	&"f2_r1": {&"chaser": 2, &"caster": 1},
	&"f2_r2": {&"chaser": 2, &"caster": 2},
	&"f2_r3": {&"chaser": 1, &"caster": 3},
	&"f2_r4": {&"chaser": 3, &"caster": 2},
	&"f2_boss": {&"hexer": 1},
	&"f3_r1": {&"brute": 1},
	&"f3_r2": {&"brute": 1, &"chaser": 2},
	&"f3_r3": {&"brute": 1, &"caster": 2},
	&"f3_r4": {&"brute": 2},
	&"f3_r5": {&"brute": 1, &"chaser": 2, &"caster": 2},
	&"f3_boss": {&"juggernaut": 1},
}

const BOSSES: Dictionary = {1: &"warden", 2: &"hexer", 3: &"juggernaut"}

## The C9 table of studio/features/F-013-camera-rooms-dash.md: sizes in tiles, borders included,
## and a shipped room has exactly this size. Every floor is redrawn (F-013 T2 to T4).
const SIZES: Dictionary = {
	&"f1_r1": Vector2i(48, 28),
	&"f1_r2": Vector2i(52, 28),
	&"f1_r3": Vector2i(56, 30),
	&"f1_boss": Vector2i(56, 32),
	&"f2_r1": Vector2i(48, 28),
	&"f2_r2": Vector2i(52, 30),
	&"f2_r3": Vector2i(64, 28),
	&"f2_r4": Vector2i(56, 32),
	&"f2_boss": Vector2i(56, 32),
	&"f3_r1": Vector2i(48, 28),
	&"f3_r2": Vector2i(52, 30),
	&"f3_r3": Vector2i(56, 30),
	&"f3_r4": Vector2i(60, 32),
	&"f3_r5": Vector2i(64, 36),
	&"f3_boss": Vector2i(56, 32),
}
## F-013/C10 (a): a combat room has a spawn this near `P` at the start, centre to centre.
const NEAR_SPAWN_MAX_TILES: Vector2 = Vector2(18.0, 9.0)
## F-013/C10 (d): no shipped attack starts further away than this (half a screen is 11.25).
const ATTACK_START_LIMIT_TILES: float = 11.0

## A body in these tests: the biggest regular enemy hurtbox is a brute's 0.6, a bolt is 0.25.
const BOLT_RADIUS_TILES: float = 0.25
const MIN_SPAWN_GAP_TILES: float = 1.5
## floors.md: floor 1 room 3's pairs are more than this far apart.
const PAIRS_APART_TILES: float = 7.0
## F1 room 3's dividing wall is the columns DIVIDER_X and DIVIDER_X + 1.
const DIVIDER_X: int = 27
## F-013/C10 (c): the Juggernaut's room holds an all-walkable rectangle this big around the boss.
const JUGGERNAUT_MIN_OPEN: Vector2i = Vector2i(20, 12)
## F-013/C10 (b): in a brute or Juggernaut room no walkable tile is further than this from a wall
## tile (the larger of the x and y distance), so there is always something to put behind you.
const MAX_WALL_DISTANCE_TILES: int = 8
const HEXER_BLOCK_COUNT: int = 4
## The clear floor between the Hexer's four blocks, so it is an arena and not one big obstacle.
const HEXER_ARENA_TILES: Vector2i = Vector2i(6, 4)
## Floor 3: a brute needs this many walkable tiles in a row to build a charge.
const BRUTE_LANE_TILES: int = 14
## `P` must sit this close to the wall opposite the exit.
const START_EDGE_TILES: float = 3.0

var _rules: FloorTunables


func before_each() -> void:
	_rules = Tunables.floors


# --- AC24: validation, structure and the encounter tables ---


func test_ac24_floor_1_passes_validation() -> void:
	assert_eq(_load_floor(1).validate(_rules), PackedStringArray())


func test_ac24_floor_2_passes_validation() -> void:
	assert_eq(_load_floor(2).validate(_rules), PackedStringArray())


func test_ac24_floor_3_passes_validation() -> void:
	assert_eq(_load_floor(3).validate(_rules), PackedStringArray())


func test_ac24_each_room_passes_validation_on_its_own() -> void:
	for room: RoomData in _all_rooms():
		assert_eq(room.validate(_rules), PackedStringArray(), str(room.id))


func test_ac24_floors_have_their_number_room_count_and_room_ids() -> void:
	var counts: Dictionary = {1: 4, 2: 5, 3: 6}
	for number: int in FLOOR_ROOM_IDS:
		var floor_data: FloorData = _load_floor(number)
		assert_eq(floor_data.floor_number, number, "floor %d number" % number)
		assert_eq(floor_data.get_room_count(), counts[number], "floor %d room count" % number)
		var ids: Array[StringName] = []
		for room: RoomData in floor_data.rooms:
			ids.append(room.id)
		assert_eq(ids, FLOOR_ROOM_IDS[number] as Array, "floor %d room ids" % number)


func test_ac24_only_the_last_room_of_each_floor_is_a_boss_room() -> void:
	for number: int in FLOOR_ROOM_IDS:
		var rooms: Array[RoomData] = _load_floor(number).rooms
		for index: int in rooms.size():
			var is_last: bool = index == rooms.size() - 1
			assert_eq(rooms[index].is_boss_room, is_last, str(rooms[index].id))


func test_ac24_the_encounter_table_covers_exactly_the_shipped_rooms() -> void:
	var expected: Array[StringName] = []
	for number: int in FLOOR_ROOM_IDS:
		for room_id: StringName in FLOOR_ROOM_IDS[number]:
			expected.append(room_id)
	assert_eq(expected.size(), 15)
	assert_eq(ENCOUNTERS.size(), 15)
	for room_id: StringName in expected:
		assert_true(ENCOUNTERS.has(room_id), "%s in ENCOUNTERS" % room_id)
		assert_true(SIZES.has(room_id), "%s in SIZES" % room_id)


func test_ac24_every_room_matches_the_encounter_table() -> void:
	for room: RoomData in _all_rooms():
		assert_eq(_enemy_counts(room), ENCOUNTERS[room.id], "%s enemies" % room.id)


func test_ac24_each_boss_room_holds_its_floors_boss() -> void:
	for number: int in BOSSES:
		var boss_room: RoomData = _load_floor(number).rooms[-1]
		var spawns: Array[RoomSpawn] = boss_room.get_spawns()
		assert_eq(spawns.size(), 1, "floor %d boss room spawns" % number)
		assert_eq(spawns[0].enemy.id, BOSSES[number], "floor %d boss" % number)


func test_ac24_every_enemies_entry_is_used_by_a_spawn() -> void:
	for room: RoomData in _all_rooms():
		var used: Array[StringName] = []
		for spawn: RoomSpawn in room.get_spawns():
			used.append(spawn.enemy.id)
		for enemy: EnemyData in room.enemies:
			assert_true(used.has(enemy.id), "%s uses enemies entry %s" % [room.id, enemy.id])


func test_ac24_every_spawn_digit_points_at_the_enemy_it_is_listed_for() -> void:
	for room: RoomData in _all_rooms():
		for enemy_index: int in room.enemies.size():
			var digit: String = str(enemy_index + 1)
			var in_grid: int = 0
			for row: String in room.rows:
				in_grid += row.count(digit)
			assert_gt(in_grid, 0, "%s has a spawn %s" % [room.id, digit])


# --- AC25: every spawn can walk to P ---


func test_ac25_every_spawn_has_a_tile_path_to_the_player_start() -> void:
	for room: RoomData in _all_rooms():
		var nav: NavGrid = NavGrid.from_rows(room.rows)
		var start: Vector2 = room.get_player_start_tiles()
		for spawn: RoomSpawn in room.get_spawns():
			var same_tile: bool = nav.tile_of(spawn.position_tiles) == nav.tile_of(start)
			var direction: Vector2 = nav.direction_toward(spawn.position_tiles, start)
			assert_true(
				same_tile or direction != Vector2.ZERO,
				"%s: %s has no path to P" % [room.id, spawn.combat_id]
			)


# --- AC27: the three boss rooms ---


func test_ac27_hexer_room_has_four_separate_two_by_two_blocks() -> void:
	var room: RoomData = _room(&"f2_boss")
	var blocks: Array[Rect2i] = _interior_wall_blocks(room)
	assert_gte(blocks.size(), HEXER_BLOCK_COUNT, "separate interior wall components")
	var two_by_two: int = 0
	for block: Rect2i in blocks:
		if block.size == Vector2i(2, 2):
			two_by_two += 1
	assert_gte(two_by_two, HEXER_BLOCK_COUNT, "components that are exactly 2 x 2")
	assert_eq(two_by_two, blocks.size(), "the interior walls are only those blocks")


func test_ac27_hexer_room_cover_breaks_the_line_from_boss_to_player() -> void:
	var room: RoomData = _room(&"f2_boss")
	var nav: NavGrid = NavGrid.from_rows(room.rows)
	var boss: Vector2 = room.get_spawns()[0].position_tiles
	assert_false(nav.has_clear_line(boss, room.get_player_start_tiles(), BOLT_RADIUS_TILES))


func test_ac27_hexer_stands_in_the_centre_region_between_the_blocks() -> void:
	var room: RoomData = _room(&"f2_boss")
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	for block: Rect2i in _interior_wall_blocks(room):
		low = Vector2(minf(low.x, block.position.x), minf(low.y, block.position.y))
		high = Vector2(maxf(high.x, block.end.x), maxf(high.y, block.end.y))
	var boss: Vector2 = room.get_spawns()[0].position_tiles
	assert_true(boss.x > low.x and boss.x < high.x, "boss x inside the square of blocks")
	assert_true(boss.y > low.y and boss.y < high.y, "boss y inside the square of blocks")


func test_ac27_hexer_room_clear_area_between_the_blocks_is_an_arena() -> void:
	var room: RoomData = _room(&"f2_boss")
	var blocks: Array[Rect2i] = _interior_wall_blocks(room)
	var middle: Vector2 = Vector2(room.get_size()) / 2.0
	var inner_low: Vector2i = Vector2i(0, 0)
	var inner_high: Vector2i = room.get_size()
	for block: Rect2i in blocks:
		# Each block bounds the clear area on the side of the room centre it faces.
		if Vector2(block.get_center()).x < middle.x:
			inner_low.x = maxi(inner_low.x, block.end.x)
		else:
			inner_high.x = mini(inner_high.x, block.position.x)
		if Vector2(block.get_center()).y < middle.y:
			inner_low.y = maxi(inner_low.y, block.end.y)
		else:
			inner_high.y = mini(inner_high.y, block.position.y)
	var arena: Vector2i = inner_high - inner_low
	assert_gte(arena.x, HEXER_ARENA_TILES.x, "clear width between the blocks")
	assert_gte(arena.y, HEXER_ARENA_TILES.y, "clear height between the blocks")
	for y: int in range(inner_low.y, inner_high.y):
		for x: int in range(inner_low.x, inner_high.x):
			assert_true(room.is_walkable(Vector2i(x, y)), "arena tile (%d, %d)" % [x, y])


## F-013/C10 (b): in every room with a brute or the Juggernaut, no walkable tile is further than
## MAX_WALL_DISTANCE_TILES from a wall tile (border walls count).
func test_c10b_no_floor_tile_is_far_from_a_wall_in_a_brute_or_juggernaut_room() -> void:
	var checked: int = 0
	for room: RoomData in _all_rooms():
		if not _has_enemy(room, &"brute") and not _has_enemy(room, &"juggernaut"):
			continue
		checked += 1
		var worst: int = 0
		var worst_tile: Vector2i = Vector2i.ZERO
		var size: Vector2i = room.get_size()
		for y: int in size.y:
			for x: int in size.x:
				if not room.is_walkable(Vector2i(x, y)):
					continue
				var distance: int = _wall_distance(
					room, Vector2i(x, y), MAX_WALL_DISTANCE_TILES + 1
				)
				if distance > worst:
					worst = distance
					worst_tile = Vector2i(x, y)
		assert_lte(
			worst,
			MAX_WALL_DISTANCE_TILES,
			"%s: tile %s is far from every wall" % [room.id, worst_tile]
		)
	assert_eq(checked, 6, "the six floor 3 rooms")


## F-013/C10 (c): the Juggernaut's room holds an all-walkable rectangle JUGGERNAUT_MIN_OPEN big
## that contains the boss's spawn tile.
func test_c10c_juggernaut_room_holds_a_clear_20_by_12_floor_that_contains_the_boss() -> void:
	var room: RoomData = _room(&"f3_boss")
	var spawn: Vector2i = Vector2i(room.get_spawns()[0].position_tiles)
	var found: bool = false
	var low: Vector2i = spawn - JUGGERNAUT_MIN_OPEN + Vector2i.ONE
	for y: int in range(low.y, spawn.y + 1):
		for x: int in range(low.x, spawn.x + 1):
			found = found or _is_all_walkable(room, Rect2i(Vector2i(x, y), JUGGERNAUT_MIN_OPEN))
	assert_true(found, "a clear %s rectangle holds the boss at %s" % [JUGGERNAUT_MIN_OPEN, spawn])


func test_ac27_warden_room_has_no_interior_wall() -> void:
	assert_eq(_interior_wall_tiles(_room(&"f1_boss")).size(), 0)


func test_ac27_every_boss_starts_outside_its_own_aggro_so_the_fight_starts_with_a_read() -> void:
	for number: int in BOSSES:
		var room: RoomData = _load_floor(number).rooms[-1]
		var spawn: RoomSpawn = room.get_spawns()[0]
		var distance: float = spawn.position_tiles.distance_to(room.get_player_start_tiles())
		assert_gt(distance, spawn.enemy.aggro_radius_tiles, "%s distance to P" % room.id)


# --- Guidance pins ---


func test_pin_spawns_are_at_least_one_and_a_half_tiles_apart() -> void:
	for room: RoomData in _all_rooms():
		var spawns: Array[RoomSpawn] = room.get_spawns()
		for first: int in spawns.size():
			for second: int in range(first + 1, spawns.size()):
				var gap: float = spawns[first].position_tiles.distance_to(
					spawns[second].position_tiles
				)
				assert_gte(gap, MIN_SPAWN_GAP_TILES, "%s: %s and %s" % [room.id, first, second])


func test_pin_spawns_start_outside_their_own_aggro_radius_from_the_player() -> void:
	for room: RoomData in _all_rooms():
		var start: Vector2 = room.get_player_start_tiles()
		for spawn: RoomSpawn in room.get_spawns():
			var distance: float = spawn.position_tiles.distance_to(start)
			assert_gt(distance, spawn.enemy.aggro_radius_tiles, str(spawn.combat_id))


func test_pin_player_start_and_exit_are_on_opposite_sides() -> void:
	for room: RoomData in _all_rooms():
		var size: Vector2i = room.get_size()
		var start: Vector2 = room.get_player_start_tiles()
		var exit_tile: Vector2i = room.get_exit_tiles()[0]
		# The distance from P to the wall opposite the exit, and how far P is from the exit wall.
		var from_far_wall: float
		var from_exit_wall: float
		if exit_tile.x == size.x - 1:
			from_far_wall = start.x
			from_exit_wall = size.x - start.x
		elif exit_tile.x == 0:
			from_far_wall = size.x - start.x
			from_exit_wall = start.x
		elif exit_tile.y == size.y - 1:
			from_far_wall = start.y
			from_exit_wall = size.y - start.y
		else:
			from_far_wall = size.y - start.y
			from_exit_wall = start.y
		assert_lte(from_far_wall, START_EDGE_TILES, "%s: P near its own side" % room.id)
		assert_gt(from_exit_wall, from_far_wall, "%s: exit on the other side" % room.id)


func test_pin_floor_1_room_3_has_two_pairs_more_than_seven_tiles_apart() -> void:
	var room: RoomData = _room(&"f1_r3")
	var near_pair: Array[Vector2] = []
	var far_pair: Array[Vector2] = []
	for spawn: RoomSpawn in room.get_spawns():
		if spawn.position_tiles.x < DIVIDER_X:
			near_pair.append(spawn.position_tiles)
		elif spawn.position_tiles.x > DIVIDER_X + 2:
			far_pair.append(spawn.position_tiles)
	assert_eq(near_pair.size(), 2, "chasers on P's side of the wall")
	assert_eq(far_pair.size(), 2, "chasers beyond the wall")
	var nearest: float = INF
	for near: Vector2 in near_pair:
		for far: Vector2 in far_pair:
			nearest = minf(nearest, near.distance_to(far))
	assert_gt(nearest, PAIRS_APART_TILES, "nearest chasers of different pairs")


func test_pin_floor_1_room_3_wall_has_two_gaps_each_two_tiles_wide_or_more() -> void:
	var room: RoomData = _room(&"f1_r3")
	var nav: NavGrid = NavGrid.from_rows(room.rows)
	for column: int in [DIVIDER_X, DIVIDER_X + 1]:
		var runs: Array[int] = _open_runs_in_column(nav, column)
		assert_eq(runs.size(), 2, "column %d: gaps in the wall" % column)
		for run: int in runs:
			assert_gte(run, 2, "column %d: gap width" % column)
	var start: Vector2 = room.get_player_start_tiles()
	for spawn: RoomSpawn in room.get_spawns():
		if spawn.position_tiles.x > DIVIDER_X + 2:
			assert_false(
				nav.has_clear_line(spawn.position_tiles, start, BOLT_RADIUS_TILES),
				"the far pair is behind the wall: %s" % spawn.combat_id
			)


func test_pin_floor_2_casters_stand_behind_chasers_or_behind_cover() -> void:
	var rooms: Array[RoomData] = _load_floor(2).rooms
	for room: RoomData in rooms.slice(0, rooms.size() - 1):
		var nav: NavGrid = NavGrid.from_rows(room.rows)
		var start: Vector2 = room.get_player_start_tiles()
		var nearest_caster: float = INF
		var farthest_chaser: float = 0.0
		for spawn: RoomSpawn in room.get_spawns():
			var distance: float = spawn.position_tiles.distance_to(start)
			if spawn.enemy.id == &"caster":
				nearest_caster = minf(nearest_caster, distance)
			else:
				farthest_chaser = maxf(farthest_chaser, distance)
		if room.id == &"f2_r1":
			assert_gt(nearest_caster, farthest_chaser, "f2_r1: the caster is behind the chasers")
			continue
		for spawn: RoomSpawn in room.get_spawns():
			if spawn.enemy.id == &"caster":
				assert_false(
					nav.has_clear_line(spawn.position_tiles, start, BOLT_RADIUS_TILES),
					"cover between P and %s" % spawn.combat_id
				)


func test_pin_floor_3_brute_rooms_keep_a_long_straight_lane() -> void:
	for room: RoomData in _load_floor(3).rooms:
		if not _enemy_counts(room).has(&"brute") and room.id != &"f3_boss":
			continue
		var best: int = 0
		for y: int in room.rows.size():
			var run: int = 0
			for x: int in room.rows[y].length():
				run = run + 1 if room.is_walkable(Vector2i(x, y)) else 0
				best = maxi(best, run)
		assert_gte(best, BRUTE_LANE_TILES, "%s: longest straight walkable row" % room.id)


func test_pin_every_room_has_exactly_the_c9_table_size() -> void:
	for room: RoomData in _all_rooms():
		assert_eq(room.get_size(), SIZES[room.id], "%s size" % room.id)


## F-013/C10 (a): the first target is close. Combat rooms only: a boss room names its own spawn.
func test_c10a_a_combat_room_has_a_spawn_near_the_player_start() -> void:
	var checked: int = 0
	for room: RoomData in _all_rooms():
		if room.is_boss_room:
			continue
		checked += 1
		var start: Vector2 = room.get_player_start_tiles()
		var nearest: Vector2 = Vector2(INF, INF)
		var found: bool = false
		for spawn: RoomSpawn in room.get_spawns():
			var away: Vector2 = (spawn.position_tiles - start).abs()
			if away.x <= NEAR_SPAWN_MAX_TILES.x and away.y <= NEAR_SPAWN_MAX_TILES.y:
				found = true
			if away.length() < nearest.length():
				nearest = away
		assert_true(
			found,
			"%s: no spawn within %s of P (nearest %s)" % [room.id, NEAR_SPAWN_MAX_TILES, nearest]
		)
	assert_eq(checked, 12, "the 12 combat rooms of the tower")


## F-013/C10 (d): no attack starts off screen. Every attack of every enemy of every shipped room:
## its list, each stage's list, and every follow-up reached from those.
func test_c10d_no_shipped_attack_starts_further_than_the_limit() -> void:
	var seen: Array[EnemyAttackData] = []
	var longest: float = 0.0
	for room: RoomData in _all_rooms():
		for enemy: EnemyData in room.enemies:
			var attacks: Array[EnemyAttackData] = enemy.attacks.duplicate()
			for stage: EnemyStageData in enemy.stages:
				attacks.append_array(stage.attacks)
			_collect_attacks(attacks, seen)
	assert_gt(seen.size(), 0, "the walk found attacks")
	for attack: EnemyAttackData in seen:
		longest = maxf(longest, attack.trigger_max_tiles)
		assert_lt(
			attack.trigger_max_tiles,
			ATTACK_START_LIMIT_TILES,
			"%s starts at up to %s tiles" % [attack.resource_path, attack.trigger_max_tiles]
		)
	gut.p("%d attacks checked, longest trigger range %s tiles" % [seen.size(), longest])


# --- helpers ---


func _load_floor(number: int) -> FloorData:
	var paths: Dictionary = {
		1: Tunables.FLOOR_1_PATH, 2: Tunables.FLOOR_2_PATH, 3: Tunables.FLOOR_3_PATH
	}
	var loaded: FloorData = load(paths[number]) as FloorData
	assert_not_null(loaded, "floor %d loads as FloorData" % number)
	return loaded


func _all_rooms() -> Array[RoomData]:
	var rooms: Array[RoomData] = []
	for number: int in FLOOR_ROOM_IDS:
		rooms.append_array(_load_floor(number).rooms)
	return rooms


func _room(room_id: StringName) -> RoomData:
	for room: RoomData in _all_rooms():
		if room.id == room_id:
			return room
	fail_test("no shipped room %s" % room_id)
	return RoomData.new()


func _has_enemy(room: RoomData, enemy_id: StringName) -> bool:
	for enemy: EnemyData in room.enemies:
		if enemy.id == enemy_id:
			return true
	return false


## The larger of the x and y distance from `tile` to the nearest wall tile; `limit` when none is
## that near. Scans square rings outwards, so a tile near a wall is cheap.
func _wall_distance(room: RoomData, tile: Vector2i, limit: int) -> int:
	for radius: int in range(1, limit):
		for offset: int in range(-radius, radius + 1):
			var ring: Array[Vector2i] = [
				tile + Vector2i(offset, -radius),
				tile + Vector2i(offset, radius),
				tile + Vector2i(-radius, offset),
				tile + Vector2i(radius, offset),
			]
			for spot: Vector2i in ring:
				if _inside(room, spot) and room.rows[spot.y][spot.x] == RoomData.WALL:
					return radius
	return limit


func _inside(room: RoomData, tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < room.get_size().x and tile.y < room.get_size().y


func _is_all_walkable(room: RoomData, area: Rect2i) -> bool:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if not room.is_walkable(Vector2i(x, y)):
				return false
	return true


## `attacks` and every follow-up chain reached from them, each attack once, into `into`.
func _collect_attacks(attacks: Array[EnemyAttackData], into: Array[EnemyAttackData]) -> void:
	for attack: EnemyAttackData in attacks:
		if attack == null or into.has(attack):
			continue
		into.append(attack)
		if attack.follow_up != null:
			_collect_attacks([attack.follow_up] as Array[EnemyAttackData], into)


## Enemy id -> spawn count, as a StringName-keyed dictionary like ENCOUNTERS.
func _enemy_counts(room: RoomData) -> Dictionary:
	var counts: Dictionary = {}
	for spawn: RoomSpawn in room.get_spawns():
		counts[spawn.enemy.id] = int(counts.get(spawn.enemy.id, 0)) + 1
	return counts


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


## Lengths of the runs of walkable tiles down one column.
func _open_runs_in_column(nav: NavGrid, column: int) -> Array[int]:
	var runs: Array[int] = []
	var run: int = 0
	for y: int in nav.get_size().y:
		if nav.is_walkable(Vector2i(column, y)):
			run += 1
		elif run > 0:
			runs.append(run)
			run = 0
	if run > 0:
		runs.append(run)
	return runs
