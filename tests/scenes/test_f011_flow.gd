extends F011SceneTest
## F-011 T5 (AC17-AC20): the door, the heal, the room swap, the boss room and the death rule, in
## the real floor scene.

## The arena's door: E at x = 13, so a body stops at its west face, minus its radius.
const DOOR_FACE_TILES: float = 13.0
const WALK_TICKS: int = 60


func test_ac17_the_door_holds_while_an_enemy_lives() -> void:
	await spawn_floor(_floor_of_solo_rooms(1))
	enemy().logic.set_ai_enabled(false)
	var body_radius: float = Units.px_to_tiles(
		(player().get_node("CollisionShape2D") as CollisionShape2D).shape.radius
	)
	put_player_at_door()
	await run_ticks(WALK_TICKS, Vector2.RIGHT)
	assert_lte(player().motor.get_position_tiles().x, DOOR_FACE_TILES - body_radius + 0.01)
	assert_gt(player().motor.get_position_tiles().x, DOOR_FACE_TILES - body_radius - 0.05, "at it")
	assert_eq(_floor.get_run().get_room_index(), 0, "still in room 1")
	assert_false(room().is_door_open())
	assert_false(_floor.get_run().is_room_cleared())


func test_ac17_a_real_kill_opens_the_door_within_one_tick_and_heals_once() -> void:
	await spawn_floor(_floor_of_solo_rooms(1))
	enemy().logic.set_ai_enabled(false)
	set_hp(50)
	put_player_at(enemy().logic.get_position_tiles() - Vector2(1.0, 0.0))
	var dead: Callable = func() -> bool: return not enemy().logic.is_alive()
	assert_true(await run_until(dead, 600, Vector2.ZERO, Vector2.RIGHT, SWING_PERIOD_TICKS))
	assert_eq(enemy().logic.get_combat_state().get_hp(), 0, "the sword killed it")
	await run_ticks(1)
	assert_true(room().is_door_open(), "collision off within one tick of the kill")
	assert_eq(room().get_door().collision_layer, 0)
	assert_eq(hp(), 80, "50 + roundi(100 x 0.30)")
	await run_ticks(WALK_TICKS)
	assert_eq(hp(), 80, "once")
	assert_true(_floor.get_run().is_room_cleared())


func test_ac17_the_heal_is_capped_at_max_hp() -> void:
	await spawn_floor(_floor_of_solo_rooms(1))
	set_hp(90)
	kill_all()
	await run_ticks(2)
	assert_eq(hp(), 100)


func test_ac17_a_cleared_room_lets_the_player_through_the_door() -> void:
	await spawn_floor(_floor_of_solo_rooms(2))
	var first_id: int = room().get_instance_id()
	kill_all()
	await run_ticks(2)
	put_player_at_door()
	var left: Callable = func() -> bool: return room().get_instance_id() != first_id
	assert_true(await run_until(left, WALK_TICKS * 2, Vector2.RIGHT), "walked out of room 1")


func test_ac18_the_exit_replaces_the_room_and_carries_the_hp() -> void:
	await spawn_floor(_floor_of_solo_rooms(2))
	var old_room: Room = room()
	var old_ids: Array[StringName] = _ids(old_room)
	set_hp(50)
	kill_all()
	await run_ticks(2)
	assert_eq(hp(), 80)
	var entered: Array[int] = []
	_floor.room_entered.connect(func(index: int) -> void: entered.append(index))
	var old_id: int = old_room.get_instance_id()
	var swap: Dictionary = _watch_swap_of(old_room)
	put_player_at_door()
	var left: Callable = func() -> bool: return room().get_instance_id() != old_id
	assert_true(await run_until(left, WALK_TICKS * 2, Vector2.RIGHT))
	assert_eq(entered, [1] as Array[int])
	assert_eq(_floor.get_run().get_room_index(), 1)
	_assert_old_room_left_this_tick(swap)
	await get_tree().process_frame
	assert_false(is_instance_valid(old_room), "the old room is freed by the end of the frame")
	assert_eq(hp(), 80, "the carried HP")
	assert_eq(room().get_room_data().id, &"solo_2")
	assert_eq(_ids(room()), [&"player_1", &"grunt2_1"] as Array[StringName])
	assert_eq(old_ids, [&"player_1", &"grunt1_1"] as Array[StringName], "the old sim's ids")
	assert_eq(room().count_living_enemies(), 1, "fresh enemies")
	assert_false(room().is_door_open(), "a locked door again")


func test_ac18_standing_on_an_exit_tile_before_the_clear_does_nothing() -> void:
	await spawn_floor(_floor_of_solo_rooms(2))
	var first: Room = room()
	var tiles: Array[Vector2i] = first.get_room_data().get_exit_tiles()
	put_player_at(Vector2(tiles[0]) + Vector2(0.5, 0.5))
	await run_ticks(10)
	assert_eq(room(), first)
	assert_eq(_floor.get_run().get_room_index(), 0)


func test_ac19_the_boss_room_starts_at_full_hp_and_its_kill_clears_the_floor() -> void:
	await spawn_floor(_floor_of_solo_rooms(1, 3))
	var cleared: Array[int] = []
	_floor.floor_cleared.connect(func(number: int) -> void: cleared.append(number))
	set_hp(40)
	kill_all()
	await run_ticks(2)
	assert_eq(hp(), 70)
	put_player_at_door()
	var boss_room: Callable = func() -> bool: return room().get_room_data().is_boss_room
	assert_true(await run_until(boss_room, WALK_TICKS * 2, Vector2.RIGHT))
	assert_eq(hp(), 100, "full HP in the boss room")
	assert_true(_floor.get_run().get_room().is_boss_room)
	assert_eq(cleared, [] as Array[int])
	set_hp(60)
	kill(enemy())
	await run_ticks(2)
	assert_true(_floor.get_run().is_floor_cleared())
	assert_eq(cleared, [3] as Array[int], "floor_cleared(3), once")
	assert_eq(hp(), 60, "a boss clear heals nothing")
	var label: FloorDebugLabel = _floor.get_node("DebugLayer/FloorDebugLabel")
	assert_string_contains(label.get_text_now(), "FLOOR CLEARED")
	assert_true(room().is_door_open())
	await run_ticks(WALK_TICKS)
	assert_eq(cleared, [3] as Array[int], "still once")


func test_ac19_the_last_room_has_no_next_room() -> void:
	await spawn_floor(_floor_of_solo_rooms(1), 1)
	var boss_room: Room = room()
	kill_all()
	await run_ticks(2)
	put_player_at_door()
	await run_ticks(WALK_TICKS, Vector2.RIGHT)
	assert_eq(room(), boss_room, "advance() is refused on the last room")
	assert_eq(_floor.get_run().get_room_index(), 1)


func test_ac20_a_dead_player_restarts_the_room_at_full_hp_with_a_fresh_sim() -> void:
	await spawn_floor(_floor_of_solo_rooms(2), 1)
	var old_room: Room = room()
	var old_sim: CombatSim = old_room.get_runner().get_sim()
	var old_enemy: Enemy = enemy()
	var swap: Dictionary = _watch_swap_of(old_room)
	hit(old_enemy.logic, 5)
	assert_lt(old_enemy.logic.get_combat_state().get_hp(), FloorFixtures.WEAK_HP)
	hit(player().motor, 1000)
	assert_eq(hp(), 0)
	await run_ticks(2)
	assert_ne(room(), old_room, "a new room")
	assert_ne(room().get_runner().get_sim(), old_sim, "a fresh sim")
	assert_eq(hp(), 100, "full HP")
	assert_eq(_floor.get_run().get_room_index(), 1, "the same room again")
	assert_eq(room().get_room_data().id, &"solo_2")
	assert_eq(
		enemy().logic.get_combat_state().get_hp(), FloorFixtures.WEAK_HP, "the enemy is whole again"
	)
	assert_eq(room().count_living_enemies(), 1)
	assert_false(_floor.get_run().is_room_cleared())
	assert_false(room().is_door_open())
	_assert_old_room_left_this_tick(swap)
	await get_tree().process_frame
	assert_false(is_instance_valid(old_room), "the old room is freed by the end of the frame")


func test_ac20_restarting_keeps_a_finished_floor_finished() -> void:
	await spawn_floor(_floor_of_solo_rooms(1), 1)
	var cleared: Array[int] = []
	_floor.floor_cleared.connect(func(number: int) -> void: cleared.append(number))
	kill_all()
	await run_ticks(2)
	hit(player().motor, 1000)
	await run_ticks(2)
	kill_all()
	await run_ticks(2)
	assert_eq(cleared, [1] as Array[int], "never announced twice")


## F-011 DEV-13 (Gate B playtest): every built room has the viewport's current 2D camera, its own
## player's, and the view follows it. A room built inside _physics_process (the walk through the
## exit, the death restart) once ended with no current camera and was drawn in the top-left corner.
func test_dev13_the_first_room_has_the_current_camera() -> void:
	await spawn_floor(_floor_of_solo_rooms(1))
	await _assert_current_camera("first room")


func test_dev13_a_walked_in_room_has_the_current_camera() -> void:
	await spawn_floor(_floor_of_solo_rooms(2))
	await _walk_to_next_room()
	assert_eq(_floor.get_run().get_room_index(), 1)
	await _assert_current_camera("room 2, walked in")


func test_dev13_two_walk_throughs_in_a_row_keep_the_camera() -> void:
	await spawn_floor(_floor_of_solo_rooms(2))
	await _walk_to_next_room()
	await _assert_current_camera("room 2, walked in")
	await _walk_to_next_room()
	assert_eq(_floor.get_run().get_room_index(), 2)
	await _assert_current_camera("room 3, walked in")


func test_dev13_the_boss_room_entered_by_walking_has_the_current_camera() -> void:
	await spawn_floor(_floor_of_solo_rooms(1))
	await _walk_to_next_room()
	assert_true(room().get_room_data().is_boss_room)
	await _assert_current_camera("boss room, walked in")


func test_dev13_a_room_rebuilt_after_death_has_the_current_camera() -> void:
	await spawn_floor(_floor_of_solo_rooms(2), 1)
	hit(player().motor, 1000)
	await run_ticks(2)
	assert_eq(hp(), 100, "the room was rebuilt")
	await _assert_current_camera("rebuilt after death")


func test_dev13_a_skipped_room_has_the_current_camera() -> void:
	await spawn_floor(_floor_of_solo_rooms(2))
	_floor.skip_room()
	await _assert_current_camera("room 2, skipped")


func test_dev13_a_restarted_room_has_the_current_camera() -> void:
	await spawn_floor(_floor_of_solo_rooms(2))
	_floor.restart_room()
	await _assert_current_camera("room 1, restarted")


## F-011 DEV-13: records, in the tick the room is swapped (room_entered fires inside it), what
## became of the old room: out of the tree for good, queued for deletion, not yet freed.
func _watch_swap_of(old_room: Room) -> Dictionary:
	var seen: Dictionary = {}
	_floor.room_entered.connect(
		func(_index: int) -> void:
			seen["valid"] = is_instance_valid(old_room)
			if is_instance_valid(old_room):
				seen["in_tree"] = old_room.is_inside_tree()
				seen["parent"] = old_room.get_parent()
				seen["queued"] = old_room.is_queued_for_deletion(),
		CONNECT_ONE_SHOT
	)
	return seen


func _assert_old_room_left_this_tick(seen: Dictionary) -> void:
	assert_true(seen.get("valid", false), "the swap happened, the old room still allocated")
	assert_false(seen.get("in_tree", true), "the old room is out of the tree in the same tick")
	assert_null(seen.get("parent", "unset"), "and not a child of the floor scene")
	assert_true(seen.get("queued", false), "queued for deletion")


## Clears the room and walks out through its door, until the floor builds the next one.
func _walk_to_next_room() -> void:
	var old_id: int = room().get_instance_id()
	kill_all()
	await run_ticks(2)
	put_player_at_door()
	var left: Callable = func() -> bool: return room().get_instance_id() != old_id
	assert_true(await run_until(left, WALK_TICKS * 2, Vector2.RIGHT), "walked out of the room")


## After a frame has passed: the viewport's current camera is the new player's PlaceholderShake,
## and the canvas transform is not the identity. The Camera2D writes the canvas transform of its
## viewport (also headless: the viewport exists, only the renderer is a dummy), and with no
## current camera it stays at the origin (0, 0), which is the room drawn in the corner. The
## player never stands where the view would centre on the origin by chance.
func _assert_current_camera(label: String) -> void:
	await get_tree().process_frame
	var camera: Camera2D = player().get_node(NodePath(Room.SHAKE_NAME))
	var viewport: Viewport = _floor.get_viewport()
	assert_eq(viewport.get_camera_2d(), camera, "%s: the viewport's camera is the player's" % label)
	assert_true(camera.is_current(), "%s: the camera is current" % label)
	assert_ne(viewport.get_canvas_transform().origin, Vector2.ZERO, "%s: the view follows" % label)


## `solo_rooms` combat rooms of one weak enemy, then the fixture boss room.
func _floor_of_solo_rooms(solo_rooms: int, floor_number: int = 1) -> FloorData:
	var rooms: Array[RoomData] = []
	for index: int in solo_rooms:
		rooms.append(
			FloorFixtures.one_enemy_room(
				StringName("solo_%d" % (index + 1)), StringName("grunt%d" % (index + 1))
			)
		)
	return FloorFixtures.floor_of(rooms, floor_number)


func _ids(built: Room) -> Array[StringName]:
	var ids: Array[StringName] = []
	for combatant: Combatant in built.get_runner().get_sim().get_combatants():
		ids.append(combatant.get_combat_id())
	return ids


## F-011/AC17, AC18 with the exit on the north and on the west border, not only the east.
func test_ac17_a_north_door_is_locked_then_passable_and_the_room_swaps() -> void:
	await _door_on_another_side(FloorFixtures.north_exit_room(), Vector2.UP)


func test_ac17_a_west_door_is_locked_then_passable_and_the_room_swaps() -> void:
	await _door_on_another_side(FloorFixtures.west_exit_room(), Vector2.LEFT)


func _door_on_another_side(data: RoomData, outward: Vector2) -> void:
	await spawn_floor(FloorFixtures.floor_of([data] as Array[RoomData]))
	var first_id: int = room().get_instance_id()
	assert_eq(door_outward(), outward)
	enemy().logic.set_ai_enabled(false)
	var inside: Callable = func() -> bool:
		var tile: Vector2 = player().motor.get_position_tiles()
		return room().get_room_data().is_walkable(Vector2i(floori(tile.x), floori(tile.y)))
	put_player_at_door()
	assert_true(inside.call(), "starts inside the room")
	await run_ticks(WALK_TICKS, outward)
	assert_true(inside.call(), "the locked door holds the player in")
	assert_eq(room().get_instance_id(), first_id)
	assert_eq(_floor.get_run().get_room_index(), 0)
	set_hp(50)
	kill_all()
	await run_ticks(2)
	assert_true(room().is_door_open())
	assert_eq(hp(), 80, "the heal, once")
	put_player_at_door()
	var left: Callable = func() -> bool: return room().get_instance_id() != first_id
	assert_true(await run_until(left, WALK_TICKS * 2, outward), "walked out through the door")
	assert_eq(_floor.get_run().get_room_index(), 1)
	assert_eq(hp(), 100, "the next room is the boss room: full HP")
	assert_true(room().get_room_data().is_boss_room)
