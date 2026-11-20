extends F012GameTest
## F-014 T7 (AC23, scene half): room 1-1 of the shipped tower, entered from the town and played by
## a script in the real game: the HUD counts, the reinforcements arrive on their points, the cap
## holds, the exit opens at the kill target and the next room starts its own count. One room is
## enough here: the core test plays all twelve (test_f014_shipped_waves).
##
## The script, 120 ticks a second: the player's HP is refilled every tick (except before the last
## kill, so that the room's heal shows); each enemy is killed 1 s after it was first engaged; when
## nobody is engaged, nothing is pending and every released reinforcement has started, the player
## is put 3 tiles from the nearest placed chaser that still sleeps, on the line toward where the
## player was.

const START_DISTANCE_TILES: float = 3.0
const KILL_AFTER_TICKS: int = 120
const RUN_LIMIT_TICKS: int = 5000
const LAST_KILL_HP: int = 60
const TARGET: int = 6
const NEXT_TARGET: int = 9
## Half a tile: where a body that has just arrived may have got to.
const ARRIVAL_SLACK_PX: float = 8.0

var _heals: Array[int] = []


func _on_healed(amount: int) -> void:
	_heals.append(amount)


## Everything the script saw, for the asserts.
class Seen:
	extends RefCounted
	var texts: Array[String] = []
	var pending_ticks: int = 0
	var pending_outside_box: Array[String] = []
	var arrivals: int = 0
	var arrival_problems: Array[String] = []
	var starts: int = 0
	var cap_problems: Array[String] = []
	var door_open_early: bool = false
	var most_engaged: int = 0
	var cleared_at: int = -1


func test_ac23_room_1_1_of_the_shipped_tower_played_in_the_game() -> void:
	await spawn_main()
	await enter_floor_through_gate(1)
	assert_eq(location(), "Floor 1 · Room 1 / 3")
	assert_eq(hud().get_kills_text(), "Kills 0 / 6")
	assert_eq(room().get_kill_target(), TARGET)
	floor_scene().healed.connect(_on_healed)
	var seen: Seen = await _play_the_room()
	assert_gte(seen.cleared_at, 0, "the room was cleared within %d ticks" % RUN_LIMIT_TICKS)
	# The HUD counted every kill, in order, one at a time.
	var expected: Array[String] = []
	for count: int in TARGET + 1:
		expected.append(Hud.kills_text(count, TARGET))
	assert_eq(seen.texts, expected, "Kills 0 / 6 up to Kills 6 / 6")
	# The warnings: seen, and on screen from where the player stood.
	assert_gt(seen.pending_ticks, 0, "a warning was pending at some tick")
	assert_eq(seen.pending_outside_box, [] as Array[String], "every warning inside the box")
	# The arrivals: nodes on their points, drawn, with collision.
	assert_eq(seen.arrivals, 4, "all four reinforcements arrived")
	assert_eq(seen.arrival_problems, [] as Array[String])
	assert_eq(seen.starts, 4)
	# The cap, through an arrival.
	var cap: int = room().get_room_data().get_max_engaged(Tunables.floors)
	assert_eq(cap, 2)
	assert_eq(seen.cap_problems, [] as Array[String])
	assert_eq(seen.most_engaged, cap, "the cap was reached")
	# The exit stayed shut until the last kill, and opened with it.
	assert_false(seen.door_open_early, "the door opened early")
	assert_true(room().is_door_open())
	assert_true(room().is_cleared())
	assert_eq(hud().get_kills_text(), "Kills 6 / 6")
	assert_eq(get_errors().size(), 0, str(get_errors()))
	await _leave_and_check_the_next_room()


# --- the script ---------------------------------------------------------------------------------


func _play_the_room() -> Seen:
	var seen: Seen = Seen.new()
	var placed: Array[Enemy] = _placed()
	var reserve: Array[Enemy] = room().get_reserve_enemies()
	var was_waiting: Dictionary = {}
	for node: Enemy in reserve:
		was_waiting[node] = true
	var next_index: int = 0
	var last_text: String = ""
	var start: Vector2 = room().get_room_data().get_player_start_tiles()
	_put_near(_nearest(placed, start), start)
	var ticks: int = 0
	while ticks < RUN_LIMIT_TICKS:
		if room().get_kill_count() < TARGET - 1:
			set_hp(max_hp())
		elif hp() > LAST_KILL_HP:
			set_hp(LAST_KILL_HP)  # The last one falls to a player who is hurt: the heal shows.
		await run_ticks(1)
		ticks += 1
		_observe(seen, was_waiting, next_index)
		next_index = room().get_waves().get_next_index()
		var text: String = hud().get_kills_text()
		if text != last_text:
			seen.texts.append(text)
			last_text = text
		if room().is_cleared():
			seen.cleared_at = ticks
			await run_ticks(2)  # The door opens in the tick the room is cleared.
			return seen
		_kill_the_ones_due(ticks)
		if _nobody_is_on_the_way():
			var sleeper: Enemy = _nearest(_sleeping(placed), player().motor.get_position_tiles())
			if sleeper != null:
				_put_near(sleeper, player().motor.get_position_tiles())
	return seen


func _observe(seen: Seen, was_waiting: Dictionary, previous_next_index: int) -> void:
	var waves: RoomWaves = room().get_waves()
	var at: Vector2 = player().motor.get_position_tiles()
	var box: Vector2 = Tunables.floors.wave_arrival_box_tiles
	var pending: Array[RoomWaves.Pending] = waves.get_pending()
	if not pending.is_empty():
		seen.pending_ticks += 1
	for entry: RoomWaves.Pending in pending:
		var offset: Vector2 = (entry.point - at).abs()
		if offset.x > box.x + 1e-6 or offset.y > box.y + 1e-6:
			seen.pending_outside_box.append(
				"%s at %s from the player at %s" % [entry.enemy_id, entry.point, at]
			)
	var engaged: int = 0
	for node: Enemy in room().get_enemies():
		if node.logic.is_alive() and node.logic.is_aggroed():
			engaged += 1
	seen.most_engaged = maxi(seen.most_engaged, engaged)
	if waves.get_next_index() > previous_next_index:
		seen.starts += waves.get_next_index() - previous_next_index
		var cap: int = room().get_room_data().get_max_engaged(Tunables.floors)
		if engaged + pending.size() > cap:
			seen.cap_problems.append(
				"engaged %d + pending %d above %d" % [engaged, pending.size(), cap]
			)
	for node: Enemy in room().get_reserve_enemies():
		if was_waiting[node] and not node.logic.is_waiting():
			was_waiting[node] = false
			seen.arrivals += 1
			_check_arrival(seen, node)
	if not room().is_cleared() and room().is_door_open():
		seen.door_open_early = true


func _check_arrival(seen: Seen, node: Enemy) -> void:
	var points: Array[Vector2] = room().get_room_data().get_arrival_points_tiles()
	var nearest: float = INF
	for point: Vector2 in points:
		nearest = minf(nearest, node.global_position.distance_to(Units.vector_tiles_to_px(point)))
	if nearest > ARRIVAL_SLACK_PX:
		seen.arrival_problems.append(
			"%s is %.1f px from every arrival point" % [node.combat_id, nearest]
		)
	if not (node.visible and node.is_body_drawn()):
		seen.arrival_problems.append("%s is not drawn" % node.combat_id)
	if node.collision_layer == 0:
		seen.arrival_problems.append("%s has no collision" % node.combat_id)


## Each engaged enemy goes 1 s (120 ticks) after the tick it was first seen engaged.
func _kill_the_ones_due(ticks: int) -> void:
	for node: Enemy in room().get_enemies():
		if not (node.logic.is_alive() and node.logic.is_aggroed()):
			continue
		if not node.has_meta(&"engaged_tick"):
			node.set_meta(&"engaged_tick", ticks)
		elif ticks - int(node.get_meta(&"engaged_tick")) >= KILL_AFTER_TICKS:
			kill(node)


func _nobody_is_on_the_way() -> bool:
	for node: Enemy in room().get_enemies():
		if node.logic.is_alive() and node.logic.is_aggroed():
			return false
	var waves: RoomWaves = room().get_waves()
	return waves.get_pending().is_empty() and waves.get_next_index() >= waves.get_released_count()


func _placed() -> Array[Enemy]:
	var placed: Array[Enemy] = []
	for node: Enemy in room().get_enemies():
		if not room().get_reserve_enemies().has(node):
			placed.append(node)
	return placed


func _sleeping(nodes: Array[Enemy]) -> Array[Enemy]:
	var asleep: Array[Enemy] = []
	for node: Enemy in nodes:
		if node.logic.is_alive() and not node.logic.is_aggroed():
			asleep.append(node)
	return asleep


func _nearest(nodes: Array[Enemy], from: Vector2) -> Enemy:
	var best: Enemy = null
	for node: Enemy in nodes:
		if (
			best == null
			or (
				from.distance_to(node.logic.get_position_tiles())
				< from.distance_to(best.logic.get_position_tiles())
			)
		):
			best = node
	return best


## 3 tiles from the enemy, on the line toward `toward`.
func _put_near(node: Enemy, toward: Vector2) -> void:
	var at: Vector2 = node.logic.get_position_tiles()
	put_player_at(at + at.direction_to(toward) * START_DISTANCE_TILES)


# --- the way out --------------------------------------------------------------------------------


func _leave_and_check_the_next_room() -> void:
	var index: int = floor_scene().get_run().get_room_index()
	put_player_at_door()
	var moved: Callable = func() -> bool: return floor_scene().get_run().get_room_index() != index
	assert_true(await run_until(moved, WALK_LIMIT_TICKS, door_outward()), "the next room")
	assert_eq(location(), "Floor 1 · Room 2 / 3")
	assert_eq(hud().get_kills_text(), Hud.kills_text(0, NEXT_TARGET), "Kills 0 / 9, at once")
	assert_eq(_heals.size(), 1, "the heal message came once: %s" % [_heals])
	assert_eq(_heals[0], 30, "30 % of 100 HP")
	assert_eq(hud().get_banner_text(), "+30 HP")
	await run_ticks(5)
	assert_eq(_heals.size(), 1, "and only once")
	assert_eq(hud().get_kills_text(), Hud.kills_text(0, NEXT_TARGET))
