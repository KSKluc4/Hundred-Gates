extends GutTest
## F-011 T5 (AC16): a Room built from a RoomData: one wall body per run of `#`, the door over
## the `E` tiles, the player at P, one Enemy per spawn, and a new CombatRunner as the last child.

var _rules: FloorTunables


func before_each() -> void:
	_rules = RoomFixtures.rules()


func test_ac16_one_wall_body_per_horizontal_run_of_wall() -> void:
	var data: RoomData = FloorFixtures.pillar_room()
	var built: Room = await _build(data)
	var expected: Array[Rect2i] = []
	for y: int in data.rows.size():
		var x: int = 0
		while x < data.rows[y].length():
			if data.rows[y][x] != RoomData.WALL:
				x += 1
				continue
			var start: int = x
			while x < data.rows[y].length() and data.rows[y][x] == RoomData.WALL:
				x += 1
			expected.append(Rect2i(start, y, x - start, 1))
	var actual: Array[Rect2i] = []
	for wall: StaticBody2D in built.get_wall_bodies():
		actual.append(_tiles_of(wall))
		assert_eq(wall.collision_layer, 1, "layer 1, `world`")
		assert_true(wall.get_node("Visual") is ColorRect, "a placeholder visual")
	assert_eq(actual, expected, "one body per run, row by row")
	assert_true(expected.has(Rect2i(7, 4, 2, 1)), "the pillar is its own run, per row")
	assert_true(expected.has(Rect2i(7, 5, 2, 1)))


func test_ac16_the_walls_cover_exactly_the_wall_tiles() -> void:
	var data: RoomData = FloorFixtures.arena_room()
	var built: Room = await _build(data)
	var covered: Dictionary = {}
	for wall: StaticBody2D in built.get_wall_bodies():
		var tiles: Rect2i = _tiles_of(wall)
		for tile_x: int in range(tiles.position.x, tiles.end.x):
			for tile_y: int in range(tiles.position.y, tiles.end.y):
				assert_false(covered.has(Vector2i(tile_x, tile_y)), "no tile twice")
				covered[Vector2i(tile_x, tile_y)] = true
	var wall_tiles: int = 0
	for y: int in data.rows.size():
		for x: int in data.rows[y].length():
			var is_wall: bool = data.rows[y][x] == RoomData.WALL
			assert_eq(covered.has(Vector2i(x, y)), is_wall, "tile (%d, %d)" % [x, y])
			wall_tiles += 1 if is_wall else 0
	assert_eq(covered.size(), wall_tiles)


func test_ac16_the_door_covers_the_exit_tiles_and_is_locked() -> void:
	var built: Room = await _build(FloorFixtures.arena_room())
	var door: StaticBody2D = built.get_door()
	assert_not_null(door)
	assert_eq(_tiles_of(door), Rect2i(13, 4, 1, 2), "the E run")
	assert_eq(door.collision_layer, 1, "a wall body")
	assert_false(built.is_door_open())
	assert_false((door.get_node("CollisionShape2D") as CollisionShape2D).disabled)
	var wall: ColorRect = built.get_wall_bodies()[0].get_node("Visual")
	assert_ne((door.get_node("Visual") as ColorRect).color, wall.color, "its own look")
	var shape: RectangleShape2D = (door.get_node("CollisionShape2D") as CollisionShape2D).shape
	assert_eq(shape.size, Units.vector_tiles_to_px(Vector2(1, 2)))
	assert_eq(door.position, Units.vector_tiles_to_px(Vector2(13.5, 5.0)))


func test_ac16_the_player_stands_on_p_and_the_enemies_on_their_spawns() -> void:
	var data: RoomData = FloorFixtures.arena_room()
	var built: Room = await _build(data)
	var player: Player = built.get_player()
	assert_eq(player.position, Units.vector_tiles_to_px(data.get_player_start_tiles()))
	assert_eq(player.motor.get_position_tiles(), data.get_player_start_tiles())
	var spawns: Array[RoomSpawn] = data.get_spawns()
	assert_eq(spawns.size(), 2)
	assert_eq(built.get_enemies().size(), spawns.size(), "one Enemy per spawn")
	for index: int in spawns.size():
		var enemy: Enemy = built.get_enemies()[index]
		assert_eq(enemy.combat_id, spawns[index].combat_id)
		assert_eq(enemy.logic.get_combat_id(), spawns[index].combat_id)
		assert_eq(enemy.logic.get_data(), spawns[index].enemy)
		assert_eq(enemy.position, Units.vector_tiles_to_px(spawns[index].position_tiles))
		assert_eq(enemy.logic.get_position_tiles(), spawns[index].position_tiles)
	assert_eq(built.get_enemies()[0].combat_id, &"grunt_1")
	assert_eq(built.get_enemies()[1].combat_id, &"chaser_2")


func test_ac16_a_runner_is_the_last_child_with_the_player_then_the_spawns() -> void:
	var built: Room = await _build(FloorFixtures.arena_room())
	var runner: CombatRunner = built.get_runner()
	assert_eq(built.get_child(built.get_child_count() - 1), runner, "last child")
	assert_eq(runner.get_setup_errors(), PackedStringArray(), "no setup errors")
	assert_true(runner.is_physics_processing())
	var ids: Array[StringName] = []
	for combatant: Combatant in runner.get_sim().get_combatants():
		ids.append(combatant.get_combat_id())
	assert_eq(ids, [&"player_1", &"grunt_1", &"chaser_2"] as Array[StringName])
	assert_false(runner.refill_player_on_died, "the floor scene decides what a death means")
	assert_not_null(runner.get_sim().get_nav(), "F-011/C2: the nav grid from the same rows")
	assert_eq(runner.get_sim().get_nav().get_size(), Vector2i(14, 10))


func test_ac16_a_new_room_gets_a_new_runner_and_a_new_sim() -> void:
	var first: Room = await _build(FloorFixtures.arena_room())
	var second: Room = await _build(FloorFixtures.arena_room())
	assert_ne(first.get_runner(), second.get_runner())
	assert_ne(first.get_runner().get_sim(), second.get_runner().get_sim())


func test_ac16_entry_hp_and_class_are_applied() -> void:
	var data: RoomData = FloorFixtures.arena_room()
	var warrior: ClassData = load(Tunables.WARRIOR_PATH)
	var built: Room = await _build(data, 37, warrior)
	var state: CombatState = built.get_player().motor.get_combat_state()
	assert_eq(state.get_hp(), 37, "the carried HP")
	assert_eq(state.get_max_hp(), warrior.max_hp)
	assert_eq(built.get_player().class_data, warrior)
	var full: Room = await _build(data, 1000)
	assert_eq(full.get_player().motor.get_combat_state().get_hp(), warrior.max_hp, "clamped")


func test_ac16_a_boss_room_has_a_boss_bar_on_its_boss_and_a_combat_room_has_none() -> void:
	var boss: Room = await _build(FloorFixtures.boss_room())
	var bar: BossBar = _find_boss_bar(boss)
	assert_not_null(bar, "a boss room has a bar")
	assert_eq(bar.boss, boss.get_enemies()[0])
	await wait_process_frames(1)
	assert_string_contains(bar.get_label_text(), "warden_test  40 / 40")
	var combat: Room = await _build(FloorFixtures.arena_room())
	assert_null(_find_boss_bar(combat), "no bar in a combat room")


func test_ac16_the_player_has_a_shake_camera_and_the_room_draws_the_combat() -> void:
	var built: Room = await _build(FloorFixtures.arena_room())
	var cameras: int = 0
	for child: Node in built.get_player().get_children():
		cameras += 1 if child is PlaceholderShake else 0
	assert_eq(cameras, 1)
	var draws: int = 0
	for child: Node in built.get_children():
		if child is CombatDebugDraw:
			draws += 1
			assert_eq((child as CombatDebugDraw).runner, built.get_runner())
	assert_eq(draws, 1)


func test_ac16_the_door_opens_once_and_stays_open() -> void:
	var built: Room = await _build(FloorFixtures.arena_room())
	var door: StaticBody2D = built.get_door()
	var closed_color: Color = (door.get_node("Visual") as ColorRect).color
	built.open_door()
	assert_true(built.is_door_open())
	assert_eq(door.collision_layer, 0, "collision off at once")
	assert_true((door.get_node("CollisionShape2D") as CollisionShape2D).disabled)
	assert_ne((door.get_node("Visual") as ColorRect).color, closed_color, "the look changes")
	built.open_door()
	assert_true(built.is_door_open(), "idempotent")


func test_ac16_cleared_is_read_from_logic_each_time() -> void:
	var built: Room = await _build(FloorFixtures.arena_room())
	assert_false(built.is_cleared())
	assert_eq(built.count_living_enemies(), 2)
	_kill(built.get_enemies()[0])
	assert_false(built.is_cleared())
	assert_eq(built.count_living_enemies(), 1)
	_kill(built.get_enemies()[1])
	assert_true(built.is_cleared())
	assert_eq(built.count_living_enemies(), 0)
	var second: Enemy = built.get_enemies()[1]
	second.logic.setup(second.data, Tunables.enemy_combat, 120, Vector2(9.5, 7.5), &"chaser_2")
	assert_false(built.is_cleared(), "an enemy that is reset lives again: nothing was stored")


func _build(data: RoomData, entry_hp: int = 100, class_data: ClassData = null) -> Room:
	assert_eq(data.validate(_rules), PackedStringArray(), "the fixture is a valid room")
	var built: Room = Room.new()
	built.setup(data, entry_hp, class_data)
	add_child_autofree(built)
	await get_tree().physics_frame
	return built


func _kill(target: Enemy) -> void:
	var event: HitEvent = HitEvent.new()
	event.target_id = target.combat_id
	event.damage = target.logic.get_combat_state().get_hp()
	event.direction = Vector2.RIGHT
	target.logic.get_combat_state().apply_hit(event, Tunables.player_combat)


func _find_boss_bar(built: Room) -> BossBar:
	for child: Node in built.get_children():
		if child is CanvasLayer and child.get_child_count() > 0:
			return child.get_child(0) as BossBar
	return null


## The tiles a body covers, from its px position and shape.
func _tiles_of(body: StaticBody2D) -> Rect2i:
	var shape: RectangleShape2D = (body.get_node("CollisionShape2D") as CollisionShape2D).shape
	var top_left: Vector2 = Units.vector_px_to_tiles(body.position - shape.size / 2.0)
	var size: Vector2 = Units.vector_px_to_tiles(shape.size)
	return Rect2i(Vector2i(top_left.round()), Vector2i(size.round()))
