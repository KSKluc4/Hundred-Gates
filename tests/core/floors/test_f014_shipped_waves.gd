# gdlint:disable=max-public-methods
extends GutTest
## F-014 T7 (core half; AC22, AC23, C14): the 12 shipped combat rooms against the wave table, the
## arrival-point rules, and a scripted run of each on a real CombatSim.
## The table below is written out on purpose: a change to a room's waves must change it too.
## The scripted runs are core runs: the enemies move by their logic and the room's nav grid alone,
## with no wall collision (that is the scene's), which is enough for what they assert.

const ROOM_IDS: Array[StringName] = [
	&"f1_r1",
	&"f1_r2",
	&"f1_r3",
	&"f2_r1",
	&"f2_r2",
	&"f2_r3",
	&"f2_r4",
	&"f3_r1",
	&"f3_r2",
	&"f3_r3",
	&"f3_r4",
	&"f3_r5",
]

const TYPES: Dictionary = {"ch": &"chaser", "ca": &"caster", "br": &"brute"}

## The wave table of F-014 C14: reinforcements by share (the `|` groups), the kill target and
## `max_engaged`.
const WAVE_TABLE: Dictionary = {
	&"f1_r1": {"shares": ["ch ch", "ch ch"], "target": 6, "cap": 2},
	&"f1_r2": {"shares": ["ch ch", "ch ch", "ch ch"], "target": 9, "cap": 2},
	&"f1_r3": {"shares": ["ch ch", "ch ch", "ch ch", "ch ch"], "target": 12, "cap": 3},
	&"f2_r1": {"shares": ["ch ch ca", "ch ca ch", "ch ch ca"], "target": 12, "cap": 3},
	&"f2_r2": {"shares": ["ch ca", "ch ch", "ca ch", "ch ca"], "target": 12, "cap": 3},
	&"f2_r3": {"shares": ["ch ch", "ch ca", "ch ch", "ca ch"], "target": 12, "cap": 3},
	&"f2_r4": {"shares": ["ch ca", "ch ch", "ca ch", "ch ch", "ca ch"], "target": 15, "cap": 3},
	&"f3_r1": {"shares": ["br br"], "target": 3, "cap": 1},
	&"f3_r2": {"shares": ["ch ch", "br ch", "ch ch"], "target": 9, "cap": 3},
	&"f3_r3": {"shares": ["ca br", "ca", "ca"], "target": 7, "cap": 2},
	&"f3_r4": {"shares": ["br", "br"], "target": 4, "cap": 2},
	&"f3_r5": {"shares": ["ch ca", "ch br", "ch ca", "ch ch", "ca ch"], "target": 15, "cap": 3},
}

## AC23: the script's numbers, in seconds and tiles.
const KILL_EVERY_SECONDS: float = 3.0
const PUT_DISTANCE_TILES: float = 3.0
const STEPS_PER_SECOND: int = 120
## A run that has not cleared its room by then fails.
const MAX_RUN_SECONDS: float = 900.0
const EPSILON: float = 1e-6

# --- AC22: the table, the tower ---------------------------------------------------------------


func test_ac22_the_shipped_tower_validates_with_the_shipped_rules() -> void:
	var tower: TowerData = load(Tunables.TOWER_PATH) as TowerData
	assert_eq(tower.validate(Tunables.floors), PackedStringArray())


func test_ac22_the_table_covers_exactly_the_twelve_combat_rooms() -> void:
	var seen: Array[StringName] = []
	for room: RoomData in _all_rooms():
		if not room.is_boss_room:
			seen.append(room.id)
	assert_eq(seen, ROOM_IDS)
	assert_eq(WAVE_TABLE.keys().size(), 12)
	for room_id: StringName in ROOM_IDS:
		assert_true(WAVE_TABLE.has(room_id), str(room_id))


func test_ac22_every_room_has_its_reinforcement_types_in_order() -> void:
	for room_id: StringName in ROOM_IDS:
		var room: RoomData = _room(room_id)
		var expected: Array[StringName] = _flatten(WAVE_TABLE[room_id]["shares"])
		var actual: Array[StringName] = []
		for spawn: RoomSpawn in room.get_reinforcement_spawns():
			actual.append(spawn.enemy.id)
		assert_eq(actual, expected, "%s: reinforcements in order" % room_id)
		assert_eq(
			room.reinforcements.size(), expected.size(), "%s: every entry is an enemy" % room_id
		)


func test_ac22_reinforcements_use_only_types_the_room_places() -> void:
	for room_id: StringName in ROOM_IDS:
		var room: RoomData = _room(room_id)
		var placed: Array[StringName] = []
		for spawn: RoomSpawn in room.get_spawns():
			if not placed.has(spawn.enemy.id):
				placed.append(spawn.enemy.id)
		for spawn: RoomSpawn in room.get_reinforcement_spawns():
			assert_true(placed.has(spawn.enemy.id), "%s: %s" % [room_id, spawn.enemy.id])


func test_ac22_every_room_has_its_kill_target_and_cap() -> void:
	for room_id: StringName in ROOM_IDS:
		var room: RoomData = _room(room_id)
		assert_eq(
			room.get_kill_target(), WAVE_TABLE[room_id]["target"], "%s: kill target" % room_id
		)
		assert_eq(room.max_engaged, WAVE_TABLE[room_id]["cap"], "%s: max_engaged" % room_id)
		assert_eq(room.get_max_engaged(Tunables.floors), WAVE_TABLE[room_id]["cap"])


func test_ac22_boss_rooms_and_the_town_have_no_reinforcements_and_no_arrival_points() -> void:
	var others: Array[RoomData] = [load(Tunables.TOWN_PATH) as RoomData]
	for room: RoomData in _all_rooms():
		if room.is_boss_room:
			others.append(room)
	assert_eq(others.size(), 4, "the town and three bosses")
	for room: RoomData in others:
		assert_eq(room.reinforcements.size(), 0, "%s: no reinforcements" % room.id)
		assert_eq(room.max_engaged, 0, "%s: no cap of its own" % room.id)
		assert_eq(room.get_arrival_points_tiles().size(), 0, "%s: no S" % room.id)
		for row: String in room.rows:
			assert_false(row.contains("S"), "%s: an S in the grid" % room.id)
		assert_eq(room.get_reinforcement_spawns().size(), 0)


func test_ac22_every_combat_room_has_the_arrival_points_it_needs_to_start() -> void:
	for room_id: StringName in ROOM_IDS:
		var points: int = _room(room_id).get_arrival_points_tiles().size()
		assert_gte(points, Tunables.floors.wave_min_arrival_points, str(room_id))
		gut.p("%s: %d arrival points" % [room_id, points])


# --- C14 (a): room to turn around ---------------------------------------------------------------


func test_c14a_no_wall_tile_is_within_two_tiles_of_an_arrival_point() -> void:
	for room_id: StringName in ROOM_IDS:
		var room: RoomData = _room(room_id)
		for point: Vector2 in room.get_arrival_points_tiles():
			var tile: Vector2i = Vector2i(floori(point.x), floori(point.y))
			for dy: int in range(-2, 3):
				for dx: int in range(-2, 3):
					var near: Vector2i = tile + Vector2i(dx, dy)
					assert_false(
						_is_wall_or_outside(room, near),
						"%s: wall %s within 2 of the S at %s" % [room_id, near, tile]
					)


# --- C14 (b): the warning is on screen ---------------------------------------------------------


func test_c14b_the_first_three_choices_from_every_tile_lie_inside_the_arrival_box() -> void:
	var rules: FloorTunables = Tunables.floors
	var started: int = Time.get_ticks_msec()
	for room_id: StringName in ROOM_IDS:
		var room: RoomData = _room(room_id)
		var points: Array[Vector2] = room.get_arrival_points_tiles()
		var size: Vector2i = room.get_size()
		var worst: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
		var tiles: int = 0
		var failures: int = 0
		for y: int in size.y:
			for x: int in size.x:
				if not room.is_walkable(Vector2i(x, y)):
					continue
				tiles += 1
				var player: Vector2 = Vector2(x + 0.5, y + 0.5)
				var taken: PackedByteArray = PackedByteArray()
				taken.resize(points.size())
				var chosen: Array[int] = []
				for rank: int in 3:
					var index: int = RoomWaves.choose_point(
						points, taken, [player] as Array[Vector2], [] as Array[Vector2], rules
					)
					chosen.append(index)
					if index < 0:
						failures += 1
						if failures <= 3:
							fail_test(
								"%s: no choice %d from tile (%d, %d)" % [room_id, rank + 1, x, y]
							)
						break
					taken[index] = 1
					var offset: Vector2 = (points[index] - player).abs()
					worst[rank].x = maxf(worst[rank].x, offset.x)
					worst[rank].y = maxf(worst[rank].y, offset.y)
					if (
						offset.x > rules.wave_arrival_box_tiles.x + EPSILON
						or offset.y > rules.wave_arrival_box_tiles.y + EPSILON
					):
						failures += 1
						if failures <= 3:
							fail_test(
								(
									(
										"%s: choice %d from tile (%d, %d) is %s away, the box is %s; "
										+ "the three points %s"
									)
									% [
										room_id,
										rank + 1,
										x,
										y,
										offset,
										rules.wave_arrival_box_tiles,
										_points_text(points, chosen)
									]
								)
							)
		assert_eq(failures, 0, "%s: tiles outside the box or without a choice" % room_id)
		gut.p(
			(
				"%s: %d tiles, worst offsets (x, y) of choice 1 %s, 2 %s, 3 %s"
				% [room_id, tiles, worst[0], worst[1], worst[2]]
			)
		)
	gut.p("C14 (b) took %d ms" % (Time.get_ticks_msec() - started))


# --- C14 (c): the shares and the cap --------------------------------------------------------------


func test_c14c_the_shares_by_rule_match_the_tables_groups() -> void:
	for room_id: StringName in ROOM_IDS:
		var room: RoomData = _room(room_id)
		var table_shares: Array = WAVE_TABLE[room_id]["shares"]
		var sizes: Array[int] = _share_sizes(room.get_spawns().size(), room.reinforcements.size())
		var expected_sizes: Array[int] = []
		for share: String in table_shares:
			expected_sizes.append(share.split(" ").size())
		assert_eq(sizes, expected_sizes, "%s: C7 (3b)'s share sizes" % room_id)
		var all: Array[StringName] = []
		for spawn: RoomSpawn in room.get_reinforcement_spawns():
			all.append(spawn.enemy.id)
		var cut: int = 0
		for index: int in sizes.size():
			var group: Array[StringName] = all.slice(cut, cut + sizes[index])
			assert_eq(group, _types(table_shares[index]), "%s: share %d" % [room_id, index + 1])
			cut += sizes[index]


func test_c14c_the_director_releases_exactly_the_tables_shares() -> void:
	for room_id: StringName in ROOM_IDS:
		var room: RoomData = _room(room_id)
		var rig: WaveFixtures.Rig = WaveFixtures.rig_for_room(room)
		var table_shares: Array = WAVE_TABLE[room_id]["shares"]
		assert_eq(rig.waves.get_released_count(), 0, room_id)
		var released: int = 0
		for index: int in rig.placed.size():
			rig.wake(rig.placed[index])
			released += table_shares[index].split(" ").size()
			assert_eq(
				rig.waves.get_released_count(), released, "%s: %d woken" % [room_id, index + 1]
			)


func test_c14c_the_cap_is_at_most_one_plus_the_first_share() -> void:
	for room_id: StringName in ROOM_IDS:
		var room: RoomData = _room(room_id)
		var first_share: int = WAVE_TABLE[room_id]["shares"][0].split(" ").size()
		assert_lte(room.max_engaged, 1 + first_share, "%s: cap vs 1 + first share" % room_id)
		assert_gte(room.max_engaged, 1)


# --- AC23: the way to P -------------------------------------------------------------------------


func test_ac23_every_arrival_point_has_a_way_toward_p() -> void:
	for room_id: StringName in ROOM_IDS:
		var room: RoomData = _room(room_id)
		var nav: NavGrid = NavGrid.from_rows(room.rows)
		for point: Vector2 in room.get_arrival_points_tiles():
			var direction: Vector2 = nav.direction_toward(point, room.get_player_start_tiles())
			assert_ne(direction, Vector2.ZERO, "%s: no way from %s to P" % [room_id, point])


# --- AC23: the scripted run of every room ------------------------------------------------------


func test_ac23_room_1_1_played_by_the_script() -> void:
	_assert_room_played(&"f1_r1")


func test_ac23_room_1_2_played_by_the_script() -> void:
	_assert_room_played(&"f1_r2")


func test_ac23_room_1_3_played_by_the_script() -> void:
	_assert_room_played(&"f1_r3")


func test_ac23_room_2_1_played_by_the_script() -> void:
	_assert_room_played(&"f2_r1")


func test_ac23_room_2_2_played_by_the_script() -> void:
	_assert_room_played(&"f2_r2")


func test_ac23_room_2_3_played_by_the_script() -> void:
	_assert_room_played(&"f2_r3")


func test_ac23_room_2_4_played_by_the_script() -> void:
	_assert_room_played(&"f2_r4")


func test_ac23_room_3_1_played_by_the_script() -> void:
	_assert_room_played(&"f3_r1")


func test_ac23_room_3_2_played_by_the_script() -> void:
	_assert_room_played(&"f3_r2")


func test_ac23_room_3_3_played_by_the_script() -> void:
	_assert_room_played(&"f3_r3")


func test_ac23_room_3_4_played_by_the_script() -> void:
	_assert_room_played(&"f3_r4")


func test_ac23_room_3_5_played_by_the_script() -> void:
	_assert_room_played(&"f3_r5")


## Plays the room by AC23's script and asserts what it lists. The script, after every tick:
## the player's HP is refilled (by the rig); when 3 s have passed since the player was last
## put somewhere, the enemy engaged longest is killed (and the clock goes on in 3 s steps);
## when nobody is engaged, nothing is pending and every released reinforcement has started, the
## player is put 3 tiles from the nearest placed enemy that still sleeps, on the line toward
## where the player was. At the start the player is put 3 tiles from the placed enemy nearest to
## `P`, on the line toward `P`.
func _assert_room_played(room_id: StringName) -> void:
	var room: RoomData = _room(room_id)
	var rig: WaveFixtures.Rig = WaveFixtures.rig_for_room(room)
	var cap: int = room.get_max_engaged(rig.rules)
	var kill_interval: int = roundi(KILL_EVERY_SECONDS * STEPS_PER_SECOND)
	var max_steps: int = roundi(MAX_RUN_SECONDS * STEPS_PER_SECOND)
	var engaged_since: Dictionary = {}
	var start: Vector2 = room.get_player_start_tiles()
	_put_near_nearest(rig, rig.placed, start, start)
	var next_kill: int = kill_interval
	var step: int = 0
	var cleared: bool = false
	var count_mismatches: int = 0
	var stuck: bool = false
	while step < max_steps:
		rig.tick()
		step += 1
		for enemy: EnemyLogic in rig.all_enemies():
			if enemy.is_alive() and enemy.is_aggroed() and not engaged_since.has(enemy):
				engaged_since[enemy] = step
		var count: int = rig.waves.get_kill_count()
		if count != _dead_count(rig):
			count_mismatches += 1
		if count == rig.waves.get_kill_target():
			cleared = true
			break
		if step >= next_kill:
			var oldest: EnemyLogic = _engaged_longest(rig, engaged_since)
			if oldest != null:
				rig.kill(oldest)
			next_kill += kill_interval
			if rig.waves.get_kill_count() == rig.waves.get_kill_target():
				cleared = true  # The last one fell to the script's own kill.
				break
		if _nobody_is_on_the_way(rig):
			var sleeper: EnemyLogic = _nearest_sleeper(rig, rig.player.get_position_tiles())
			if sleeper == null:
				stuck = true
				break
			_put_near(rig, sleeper, rig.player.get_position_tiles())
			next_kill = step + kill_interval
	assert_true(cleared, "%s: not cleared in %d s (stuck: %s)" % [room_id, MAX_RUN_SECONDS, stuck])
	assert_eq(count_mismatches, 0, "%s: kill count disagreed with the dead" % room_id)
	assert_eq(rig.waves.get_kill_count(), rig.waves.get_kill_target(), room_id)
	for enemy: EnemyLogic in rig.all_enemies():
		assert_eq(
			enemy.get_state(),
			EnemyLogic.State.DEAD,
			"%s: %s is dead" % [room_id, enemy.get_combat_id()]
		)
	_assert_the_waves_kept_their_rules(room_id, room, rig, cap)
	_report(room_id, step, rig, cap)


func _assert_the_waves_kept_their_rules(
	room_id: StringName, room: RoomData, rig: WaveFixtures.Rig, cap: int
) -> void:
	assert_eq(
		rig.recorder.arrivals.size(),
		room.reinforcements.size(),
		"%s: every reinforcement arrives" % room_id
	)
	var sizes: Array[int] = _share_sizes(rig.placed.size(), rig.reserve.size())
	var samples: Array[Dictionary] = rig.recorder.samples
	for start: Dictionary in rig.recorder.starts:
		var sample: Dictionary = samples[start["step"] - 1]
		assert_eq(sample["step"], start["step"])
		assert_lte(
			sample["engaged"] + sample["pending"],
			cap,
			(
				"%s: engaged + pending after the warning of %s at step %d"
				% [room_id, start["id"], start["step"]]
			)
		)
		var share: int = _share_of(sizes, start["index"])
		assert_gte(
			sample["woken"],
			share + 1,
			(
				"%s: share %d of %s started with %d placed enemies woken"
				% [room_id, share + 1, start["id"], sample["woken"]]
			)
		)
	var most: int = 0
	for sample: Dictionary in samples:
		most = maxi(most, sample["engaged"])
	assert_gte(
		most, cap, "%s: the most engaged at once (%d) never reached the cap" % [room_id, most]
	)


func _report(room_id: StringName, steps: int, rig: WaveFixtures.Rig, cap: int) -> void:
	var seconds: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var most: int = 0
	for sample: Dictionary in rig.recorder.samples:
		var engaged: int = sample["engaged"]
		most = maxi(most, engaged)
		if engaged >= 1:
			seconds[mini(engaged, 3)] += 1.0 / STEPS_PER_SECOND
	var line: String = (
		"%s: cleared in %.1f s, cap %d, most engaged %d, "
		% [room_id, float(steps) / STEPS_PER_SECOND, cap, most]
	)
	line += (
		"seconds with 1 / 2 / 3+ engaged: %.1f / %.1f / %.1f" % [seconds[1], seconds[2], seconds[3]]
	)
	gut.p(line)


# --- the script's helpers -----------------------------------------------------------------------


func _nobody_is_on_the_way(rig: WaveFixtures.Rig) -> bool:
	for enemy: EnemyLogic in rig.all_enemies():
		if enemy.is_alive() and enemy.is_aggroed():
			return false
	return (
		rig.waves.get_pending().is_empty()
		and rig.waves.get_next_index() >= rig.waves.get_released_count()
	)


func _engaged_longest(rig: WaveFixtures.Rig, engaged_since: Dictionary) -> EnemyLogic:
	var best: EnemyLogic = null
	for enemy: EnemyLogic in rig.all_enemies():
		if not (enemy.is_alive() and enemy.is_aggroed()):
			continue
		if best == null or engaged_since[enemy] < engaged_since[best]:
			best = enemy
	return best


## The nearest to `from` of the placed enemies that are alive and still asleep.
func _nearest_sleeper(rig: WaveFixtures.Rig, from: Vector2) -> EnemyLogic:
	var best: EnemyLogic = null
	for enemy: EnemyLogic in rig.placed:
		if not enemy.is_alive() or enemy.is_aggroed():
			continue
		if (
			best == null
			or (
				from.distance_to(enemy.get_position_tiles())
				< from.distance_to(best.get_position_tiles()) - EPSILON
			)
		):
			best = enemy
	return best


## Puts the player 3 tiles from the placed enemy nearest to `from`, on the line toward `toward`.
func _put_near_nearest(
	rig: WaveFixtures.Rig, enemies: Array[EnemyLogic], from: Vector2, toward: Vector2
) -> void:
	var best: EnemyLogic = null
	for enemy: EnemyLogic in enemies:
		if (
			best == null
			or (
				from.distance_to(enemy.get_position_tiles())
				< from.distance_to(best.get_position_tiles()) - EPSILON
			)
		):
			best = enemy
	_put_near(rig, best, toward)


func _put_near(rig: WaveFixtures.Rig, enemy: EnemyLogic, toward: Vector2) -> void:
	var at: Vector2 = enemy.get_position_tiles()
	rig.put_player(at + at.direction_to(toward) * PUT_DISTANCE_TILES)


func _dead_count(rig: WaveFixtures.Rig) -> int:
	var count: int = 0
	for enemy: EnemyLogic in rig.all_enemies():
		if enemy.get_state() == EnemyLogic.State.DEAD:
			count += 1
	return count


## C7 (3b): the reserve over the placed enemies, the larger shares first.
func _share_sizes(placed: int, reserve: int) -> Array[int]:
	var sizes: Array[int] = []
	for index: int in placed:
		sizes.append(reserve / placed + (1 if index < reserve % placed else 0))
	return sizes


func _share_of(sizes: Array[int], reserve_index: int) -> int:
	var cut: int = 0
	for share: int in sizes.size():
		cut += sizes[share]
		if reserve_index < cut:
			return share
	return sizes.size() - 1


func _types(share: String) -> Array[StringName]:
	var types: Array[StringName] = []
	for abbreviation: String in share.split(" "):
		types.append(TYPES[abbreviation])
	return types


func _flatten(shares: Array) -> Array[StringName]:
	var types: Array[StringName] = []
	for share: String in shares:
		types.append_array(_types(share))
	return types


func _points_text(points: Array[Vector2], chosen: Array[int]) -> String:
	var parts: Array[String] = []
	for index: int in chosen:
		parts.append(str(points[index]) if index >= 0 else "none")
	return ", ".join(parts)


func _is_wall_or_outside(room: RoomData, tile: Vector2i) -> bool:
	if (
		tile.y < 0
		or tile.y >= room.rows.size()
		or tile.x < 0
		or tile.x >= room.rows[tile.y].length()
	):
		return true
	return room.rows[tile.y][tile.x] == RoomData.WALL


func _load_floor(number: int) -> FloorData:
	var paths: Dictionary = {
		1: Tunables.FLOOR_1_PATH, 2: Tunables.FLOOR_2_PATH, 3: Tunables.FLOOR_3_PATH
	}
	return load(paths[number]) as FloorData


func _all_rooms() -> Array[RoomData]:
	var rooms: Array[RoomData] = []
	for number: int in [1, 2, 3]:
		rooms.append_array(_load_floor(number).rooms)
	return rooms


func _room(room_id: StringName) -> RoomData:
	for room: RoomData in _all_rooms():
		if room.id == room_id:
			return room
	fail_test("no shipped room %s" % room_id)
	return RoomData.new()
