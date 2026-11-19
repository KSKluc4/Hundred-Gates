extends F011SceneTest
## F-011 T7 (AC26): the three shipped floors, run from their real debug scenes. Every room loads
## with no setup error, then steps 2 s with every enemy awake (boss rooms too) and a scripted idle
## player, without an engine error or a body on a wall tile, and every enemy must have acted; a
## longer woken-up room per floor; one end-to-end clear of floor 1.

const SCENE_PATH_FORMAT: String = "res://scenes/debug/f011_floor_%d.tscn"  # G5
const FLOOR_PATH_FORMAT: String = "res://data/floors/floor_%d.tres"  # G5
const FLOOR_NUMBERS: Array[int] = [1, 2, 3]
const BOSSES: Dictionary = {1: &"warden", 2: &"hexer", 3: &"juggernaut"}
const PLAYER_ID: StringName = &"player_1"
const LABEL_PATH: NodePath = ^"DebugLayer/FloorDebugLabel"
const BOSS_LAYER_PATH: NodePath = ^"BossBarLayer"
## Seconds stepped in every room, with every enemy awake and the player idle at P.
const ROOM_SECONDS: float = 2.0
## Seconds stepped in a woken-up room.
const WAKE_SECONDS: float = 4.0
## HP the player enters a boss room with when it walked in at SKIP_HP.
const SKIP_HP: int = 40
## A woken-up room's player is topped up below this, so a death can't swap the room mid-run.
const KEEP_ALIVE_HP: int = 30
## A hit that only wakes an enemy that no standing place reaches.
const WAKE_HIT_DAMAGE: int = 1
## The wake spot keeps this far from every spawn: never on top of an enemy.
const SPAWN_CLEARANCE_TILES: float = 1.5
const E2E_EXTRA_TICKS: int = 240

## Per enemy of the room being walked, indexed like its spawns (reset by _watch_awake).
var _acted: Array[bool] = []
var _left: Array[bool] = []
var _topups: int = 0

# --- AC26: every room of every floor ---


func test_ac26_the_debug_scenes_hold_their_floor_from_room_one() -> void:
	for number: int in FLOOR_NUMBERS:
		await _spawn_shipped(number)
		assert_eq(_floor.floor_data.resource_path, FLOOR_PATH_FORMAT % number)
		assert_eq(_floor.floor_data.floor_number, number)
		assert_eq(_floor.start_room, 0)
		assert_eq(_floor.get_setup_errors(), PackedStringArray(), "floor %d" % number)
		assert_eq(_floor.get_run().get_room_index(), 0)
		_floor.queue_free()
		await get_tree().physics_frame


func test_ac26_floor_1_every_room_loads_and_steps_clean() -> void:
	await _walk_floor(1)


func test_ac26_floor_2_every_room_loads_and_steps_clean() -> void:
	await _walk_floor(2)


func test_ac26_floor_3_every_room_loads_and_steps_clean() -> void:
	await _walk_floor(3)


# --- A woken-up room per floor ---


func test_ac26_floor_1_a_woken_room_runs_clean() -> void:
	await _wake_room(1)


func test_ac26_floor_2_a_woken_room_runs_clean() -> void:
	await _wake_room(2)


func test_ac26_floor_3_a_woken_room_runs_clean() -> void:
	await _wake_room(3)


# --- Floor 1, end to end ---


func test_ac26_floor_1_skip_to_the_warden_and_kill_it_clears_the_floor_once() -> void:
	await _spawn_shipped(1)
	var cleared: Array[int] = []
	_floor.floor_cleared.connect(func(number: int) -> void: cleared.append(number))
	var last: int = _floor.floor_data.get_room_count() - 1
	for index: int in last:
		assert_eq(_floor.get_run().get_room_index(), index)
		_floor.skip_room()
	assert_eq(_floor.get_run().get_room_index(), last, "in the boss room")
	assert_true(room().get_room_data().is_boss_room)
	assert_eq(enemy().logic.get_data().id, &"warden")
	assert_eq(hp(), player().motor.get_combat_state().get_max_hp(), "full HP for the boss")
	assert_eq(cleared, [] as Array[int])
	assert_false(_label().contains("FLOOR CLEARED"))
	kill(enemy())
	await run_ticks(2)
	assert_false(enemy().logic.is_alive(), "the Warden is dead")
	assert_true(_floor.get_run().is_floor_cleared())
	assert_eq(cleared, [1] as Array[int], "floor_cleared(1), once")
	assert_string_contains(_label(), "FLOOR CLEARED")
	assert_true(room().is_door_open())
	await run_ticks(E2E_EXTRA_TICKS)
	assert_eq(cleared, [1] as Array[int], "still once")
	assert_eq(get_errors().size(), 0, str(get_errors()))


# --- Helpers ---


## The real debug scene. `start_room` -1 keeps the scene's own.
func _spawn_shipped(number: int, start_room: int = -1) -> void:
	_floor = (load(SCENE_PATH_FORMAT % number) as PackedScene).instantiate()
	_floor.player_input_enabled = false
	if start_room >= 0:
		_floor.start_room = start_room
	add_child_autofree(_floor)
	await get_tree().physics_frame  # run_ticks must start just before a runner tick.


func _label() -> String:
	return (_floor.get_node(LABEL_PATH) as FloorDebugLabel).get_text_now()


## F-011/AC26 (CR-3): room by room with skip_room(), each stepped ROOM_SECONDS with every enemy
## woken. Every spawn starts outside its own aggro radius from P (ASSUMPTION-8), so without the
## wake no enemy would decide, route or attack in this run.
func _walk_floor(number: int) -> void:
	await _spawn_shipped(number)
	var data: FloorData = _floor.floor_data
	assert_eq(_floor.get_setup_errors(), PackedStringArray(), "floor %d" % number)
	for index: int in data.get_room_count():
		var room_data: RoomData = data.rooms[index]
		_check_loaded(number, index)
		var spawns: Array[RoomSpawn] = room_data.get_spawns()
		for body: Enemy in room().get_enemies():
			_wake(body)
		var watch: Callable = _watch_awake(spawns)
		var problem: String = await _step_clean(ROOM_SECONDS, room_data, watch)
		assert_eq(problem, "", "%s: %s" % [room_data.id, problem])
		assert_eq(get_errors().size(), 0, "%s: %s" % [room_data.id, str(get_errors())])
		_check_acted(room_data, spawns)
		if index == data.get_room_count() - 1:
			break
		if data.rooms[index + 1].is_boss_room:
			set_hp(SKIP_HP)  # The boss room must refill it.
		_floor.skip_room()
		assert_eq(_floor.get_run().get_room_index(), index + 1, "skipped out of %s" % room_data.id)


## Called every tick of a walked room: keeps the player alive (a death would swap the room) and
## records which enemies left their spawn tile and which were seen deciding.
func _watch_awake(spawns: Array[RoomSpawn]) -> Callable:
	_acted.resize(spawns.size())
	_acted.fill(false)
	_left.resize(spawns.size())
	_left.fill(false)
	_topups = 0
	return func() -> void:
		var max_hp: int = player().motor.get_combat_state().get_max_hp()
		if hp() < max_hp:
			set_hp(max_hp)  # Whole again each tick: the run is about the enemies, not a death.
			_topups += 1
		for spawn_index: int in spawns.size():
			var logic: EnemyLogic = enemy(spawn_index).logic
			if _tile_of(logic.get_position_tiles()) != _tile_of(spawns[spawn_index].position_tiles):
				_left[spawn_index] = true
			if _is_acting(logic.get_state()):
				_acted[spawn_index] = true


## Chasing or attacking: what an enemy that decided is doing (not idle, hit-stunned or dead).
func _is_acting(state: EnemyLogic.State) -> bool:
	return (
		state == EnemyLogic.State.CHASE
		or state == EnemyLogic.State.WINDUP
		or state == EnemyLogic.State.ACTIVE
		or state == EnemyLogic.State.RECOVERY
	)


## Every enemy of the room was awake and left its idle state during the run.
func _check_acted(data: RoomData, spawns: Array[RoomSpawn]) -> void:
	var report: PackedStringArray = []
	for spawn_index: int in spawns.size():
		var logic: EnemyLogic = enemy(spawn_index).logic
		var tag: String = "%s: %s" % [data.id, spawns[spawn_index].combat_id]
		assert_true(logic.is_aggroed(), "%s was awake" % tag)
		assert_true(_acted[spawn_index], "%s never chased or attacked" % tag)
		assert_true(_left[spawn_index], "%s never left its spawn tile" % tag)
		report.append(
			(
				"%s acted %s, left spawn %s"
				% [spawns[spawn_index].combat_id, _acted[spawn_index], _left[spawn_index]]
			)
		)
	gut.p("%s awake: %s (HP top-ups: %d)" % [data.id, "; ".join(report), _topups])


## F-011/AC26: what a room must have on entry, before any tick.
func _check_loaded(number: int, index: int) -> void:
	var data: FloorData = _floor.floor_data
	var room_data: RoomData = data.rooms[index]
	var tag: String = str(room_data.id)
	assert_eq(_floor.get_run().get_room_index(), index, tag)
	assert_eq(room().get_room_data(), room_data, tag)
	assert_eq(room().get_runner().get_setup_errors(), PackedStringArray(), "%s runner" % tag)
	var expected: Array[StringName] = [PLAYER_ID]
	for spawn: RoomSpawn in room_data.get_spawns():
		expected.append(spawn.combat_id)
	var ids: Array[StringName] = []
	for combatant: Combatant in room().get_runner().get_sim().get_combatants():
		ids.append(combatant.get_combat_id())
	assert_eq(ids, expected, "%s registered ids" % tag)
	assert_not_null(room().get_runner().get_sim().get_nav(), "%s nav grid" % tag)
	assert_true(room().get_runner().is_ai_on(), "%s AI on" % tag)
	assert_eq(room().count_living_enemies(), room_data.get_spawns().size(), "%s alive" % tag)
	var line: String = "Floor %d  room %d / %d" % [number, index + 1, data.get_room_count()]
	assert_string_contains(_label(), line, tag)
	var bar_layer: Node = room().get_node_or_null(BOSS_LAYER_PATH)
	if not room_data.is_boss_room:
		assert_null(bar_layer, "%s has no boss bar" % tag)
		return
	var max_hp: int = player().motor.get_combat_state().get_max_hp()
	assert_eq(hp(), max_hp, "%s: full HP on entry" % tag)
	assert_not_null(bar_layer, "%s boss bar" % tag)
	var bar: BossBar = bar_layer.get_child(0) as BossBar if bar_layer != null else null
	assert_not_null(bar, "%s: the bar is a BossBar" % tag)
	if bar != null:
		assert_eq(bar.boss, room().get_enemies()[0], "%s: the bar points at the boss" % tag)
	assert_eq(room().get_enemies()[0].logic.get_data().id, BOSSES[number], "%s boss id" % tag)


## Steps `seconds` with the player idle. Returns the first problem, "" when clean: a body on a
## tile that isn't walkable, or the room swapped (a death or an exit).
func _step_clean(seconds: float, data: RoomData, on_tick: Callable = Callable()) -> String:
	var started: int = room().get_instance_id()
	for tick: int in int(seconds * RATE):
		await run_ticks(1)
		if room().get_instance_id() != started:
			return "the room was swapped at tick %d" % tick
		var stray: String = _stray_body(data)
		if not stray.is_empty():
			return "tick %d: %s" % [tick, stray]
		if on_tick.is_valid():
			on_tick.call()
	return ""


func _tile_of(tiles: Vector2) -> Vector2i:
	return Vector2i(floori(tiles.x), floori(tiles.y))


## A body whose logic position is on a tile that isn't walkable (wall, door or outside).
func _stray_body(data: RoomData) -> String:
	var at: Vector2 = player().motor.get_position_tiles()
	if not data.is_walkable(_tile_of(at)):
		return "player at %s" % at
	for body: Enemy in room().get_enemies():
		var spot: Vector2 = body.logic.get_position_tiles()
		if body.logic.is_alive() and not data.is_walkable(_tile_of(spot)):
			return "%s at %s" % [body.combat_id, spot]
	return ""


# --- The woken-up room ---


## F-011/AC26: the non-boss room with the most enemy types (then the most enemies, then the
## later one), the player where the most enemies' aggro reaches, 4 s.
func _wake_room(number: int) -> void:
	await _spawn_shipped(number)
	var index: int = _busiest_room(_floor.floor_data)
	_floor.queue_free()
	await get_tree().physics_frame
	await _spawn_shipped(number, index)
	var data: RoomData = room().get_room_data()
	assert_eq(_floor.get_run().get_room_index(), index)
	var spot: Vector2 = _wake_spot(data)
	put_player_at(spot)
	var spawns: Array[RoomSpawn] = data.get_spawns()
	var hit_ids: Array[StringName] = []
	for spawn_index: int in spawns.size():
		var reach: float = spawns[spawn_index].enemy.aggro_radius_tiles
		if spawns[spawn_index].position_tiles.distance_to(spot) > reach:
			_wake(enemy(spawn_index))  # No standing place reaches them all.
			hit_ids.append(spawns[spawn_index].combat_id)
	var left: Array[bool] = []
	left.resize(spawns.size())
	left.fill(false)
	var closest: Array[float] = []
	closest.resize(spawns.size())
	closest.fill(INF)
	var topups: Array[int] = [0]
	var watch: Callable = func() -> void:
		var max_hp: int = player().motor.get_combat_state().get_max_hp()
		if hp() < KEEP_ALIVE_HP:
			set_hp(max_hp)
			topups[0] += 1
		for spawn_index: int in spawns.size():
			var now: Vector2i = _tile_of(enemy(spawn_index).logic.get_position_tiles())
			if now != _tile_of(spawns[spawn_index].position_tiles):
				left[spawn_index] = true
			var gap: float = enemy(spawn_index).logic.get_position_tiles().distance_to(
				player().motor.get_position_tiles()
			)
			closest[spawn_index] = minf(closest[spawn_index], gap)
	var problem: String = await _step_clean(WAKE_SECONDS, data, watch)
	assert_eq(problem, "", "%s woken: %s" % [data.id, problem])
	assert_eq(get_errors().size(), 0, "%s woken: %s" % [data.id, str(get_errors())])
	assert_true(left.has(true), "%s: an enemy left its spawn tile" % data.id)
	for spawn_index: int in spawns.size():
		assert_true(
			enemy(spawn_index).logic.is_aggroed(),
			"%s: %s woke" % [data.id, spawns[spawn_index].combat_id]
		)
	gut.p("%s woken at %s (wake hits: %s, HP top-ups: %d)" % [data.id, spot, hit_ids, topups[0]])
	for spawn_index: int in spawns.size():
		var logic: EnemyLogic = enemy(spawn_index).logic
		gut.p(
			(
				"  %s: left spawn %s, closest %.2f, now %s, state %s"
				% [
					spawns[spawn_index].combat_id,
					left[spawn_index],
					closest[spawn_index],
					logic.get_position_tiles(),
					EnemyLogic.State.keys()[logic.get_state()]
				]
			)
		)


## A 1-damage hit through EnemyLogic.apply_hit, which is what sets aggro (F-004/C7).
func _wake(target: Enemy) -> void:
	var event: HitEvent = HitEvent.new()
	event.attacker_id = &"test"
	event.target_id = target.logic.get_combat_id()
	event.damage = WAKE_HIT_DAMAGE
	event.direction = Vector2.RIGHT
	target.logic.apply_hit(event, Tunables.player_combat)


func _busiest_room(data: FloorData) -> int:
	var best: int = 0
	var best_score: int = -1
	for index: int in data.get_room_count() - 1:  # The boss room is last.
		var room_data: RoomData = data.rooms[index]
		var kinds: Array[StringName] = []
		for spawn: RoomSpawn in room_data.get_spawns():
			if not kinds.has(spawn.enemy.id):
				kinds.append(spawn.enemy.id)
		var score: int = kinds.size() * 100 + room_data.get_spawns().size()
		if score >= best_score:
			best = index
			best_score = score
	return best


## The open tile (all 8 neighbours walkable too) whose worst gap to an enemy's aggro radius is
## the smallest: where the player stands inside as many radii as the room allows.
func _wake_spot(data: RoomData) -> Vector2:
	var best: Vector2 = data.get_player_start_tiles()
	var best_gap: float = INF
	var size: Vector2i = data.get_size()
	for y: int in range(1, size.y - 1):
		for x: int in range(1, size.x - 1):
			if not _is_open(data, Vector2i(x, y)):
				continue
			var centre: Vector2 = Vector2(x + 0.5, y + 0.5)
			var gap: float = -INF
			var crowded: bool = false
			for spawn: RoomSpawn in data.get_spawns():
				var away: float = spawn.position_tiles.distance_to(centre)
				crowded = crowded or away < SPAWN_CLEARANCE_TILES
				gap = maxf(gap, away - spawn.enemy.aggro_radius_tiles)
			if not crowded and gap < best_gap - 0.0001:
				best_gap = gap
				best = centre
	return best


func _is_open(data: RoomData, tile: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if not data.is_walkable(tile + Vector2i(dx, dy)):
				return false
	return true
