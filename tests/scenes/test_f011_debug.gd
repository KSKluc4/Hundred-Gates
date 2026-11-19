extends F011SceneTest
## F-011 T5 (AC21, AC23): a floor that fails validation builds nothing and says why, and the
## debug label and keys (R restarts the room, N jumps to the next one).

var _label: FloorDebugLabel


func test_ac21_a_floor_with_a_broken_room_builds_nothing_and_logs_each_error() -> void:
	var data: FloorData = FloorFixtures.floor_of(
		[FloorFixtures.one_enemy_room()] as Array[RoomData]
	)
	var rows: PackedStringArray = RoomFixtures.with_tile(FloorFixtures.one_enemy_rows(), 1, 4, ".")
	rows = RoomFixtures.with_tile(rows, 5, 2, "#")  # A thin wall as well: two errors, two rules.
	data.rooms[0] = RoomFixtures.room(&"broken", rows)
	await spawn_floor(data)
	var errors: PackedStringArray = _floor.get_setup_errors()
	assert_gt(errors.size(), 1, str(errors))
	assert_true(_any(errors, "room broken: player_start:"), str(errors))
	assert_true(_any(errors, "room broken: thin_wall:"), str(errors))
	for error: String in errors:
		assert_push_error(error)
	assert_null(_floor.get_room(), "no room")
	assert_null(_floor.get_run())
	assert_false(_floor.is_physics_processing(), "nothing steps")
	assert_eq(_count_rooms(), 0, "and nothing was added to the tree")


func test_ac21_a_missing_floor_data_is_refused() -> void:
	await spawn_floor(null)
	assert_eq(_floor.get_setup_errors(), PackedStringArray(["floor_data: not set"]))
	assert_push_error("floor_data: not set")
	assert_null(_floor.get_room())
	assert_eq(_count_rooms(), 0)


func test_ac21_a_floor_number_below_1_is_refused() -> void:
	var data: FloorData = FloorFixtures.floor_of(
		[FloorFixtures.one_enemy_room()] as Array[RoomData]
	)
	data.floor_number = 0
	await spawn_floor(data)
	assert_eq(_floor.get_setup_errors().size(), 1, str(_floor.get_setup_errors()))
	assert_push_error("floor_number")
	assert_null(_floor.get_room())


func test_ac21_a_floor_scene_moved_off_the_world_origin_is_refused() -> void:
	await spawn_floor(
		_three_room_floor(1), 0, func(scene: FloorScene) -> void: scene.position = Vector2(160, 64)
	)
	_expect_origin_refused()
	assert_string_contains(_floor.get_setup_errors()[0], "(160.0, 64.0)", "says where it is")


func test_ac21_a_floor_scene_under_a_moved_parent_is_refused() -> void:
	var parent: Node2D = Node2D.new()
	parent.position = Vector2(32, 0)
	await _spawn_under(parent)
	_expect_origin_refused()


func test_ac21_a_floor_scene_under_a_scaled_parent_is_refused() -> void:
	var parent: Node2D = Node2D.new()
	parent.scale = Vector2(2, 2)
	await _spawn_under(parent)
	_expect_origin_refused()


func test_ac21_a_scaled_floor_scene_is_refused() -> void:
	await spawn_floor(
		_three_room_floor(1), 0, func(scene: FloorScene) -> void: scene.scale = Vector2(2, 2)
	)
	_expect_origin_refused()


func test_ac21_a_rotated_floor_scene_is_refused() -> void:
	await spawn_floor(
		_three_room_floor(1), 0, func(scene: FloorScene) -> void: scene.rotation = 0.5
	)
	_expect_origin_refused()


func test_ac21_a_floor_scene_at_the_origin_builds_with_or_without_a_parent() -> void:
	await spawn_floor(_three_room_floor(1))
	assert_eq(_floor.get_setup_errors(), PackedStringArray())
	assert_not_null(room())
	var parent: Node2D = Node2D.new()
	await _spawn_under(parent)
	assert_eq(_floor.get_setup_errors(), PackedStringArray())
	assert_not_null(room(), "built under a parent at the origin")
	assert_eq(_floor.get_run().get_room_index(), 0)


func test_ac21_the_keys_do_nothing_without_a_room() -> void:
	await spawn_floor(null)
	assert_push_error("floor_data: not set")
	press_key(KEY_N)
	press_key(KEY_R)
	assert_null(_floor.get_room())
	assert_null(_floor.get_run())


func test_ac23_the_label_shows_the_setup_errors() -> void:
	await spawn_floor(null)
	assert_push_error("floor_data: not set")
	_find_label()
	assert_string_contains(_label.get_text_now(), "floor_data: not set")
	await wait_process_frames(1)
	assert_eq(_label.text, _label.get_text_now())


func test_ac23_the_label_shows_floor_room_hp_and_enemies() -> void:
	await spawn_floor(_three_room_floor(7))
	_find_label()
	var text: String = _label.get_text_now()
	assert_string_contains(text, "Floor 7")
	assert_string_contains(text, "room 1 / 3")
	assert_string_contains(text, "HP 100 / 100")
	assert_string_contains(text, "Enemies 1")
	assert_false(text.contains("EXIT OPEN"))
	assert_false(text.contains("FLOOR CLEARED"))
	set_hp(55)
	assert_string_contains(_label.get_text_now(), "HP 55 / 100")
	await wait_process_frames(1)
	assert_eq(_label.text, _label.get_text_now(), "the node's text follows it")


func test_ac23_the_label_shows_exit_open_and_floor_cleared() -> void:
	await spawn_floor(_three_room_floor(1), 2)
	_find_label()
	assert_string_contains(_label.get_text_now(), "room 3 / 3")
	kill_all()
	await run_ticks(2)
	var text: String = _label.get_text_now()
	assert_string_contains(text, "Enemies 0")
	assert_string_contains(text, "EXIT OPEN")
	assert_string_contains(text, "FLOOR CLEARED")


func test_ac23_n_jumps_to_the_next_room_with_no_heal_and_r_restarts_it() -> void:
	await spawn_floor(_three_room_floor(1))
	_find_label()
	set_hp(40)
	var first: int = room().get_instance_id()
	press_key(KEY_N)
	assert_eq(_floor.get_run().get_room_index(), 1)
	assert_ne(room().get_instance_id(), first, "a new room")
	assert_eq(hp(), 40, "carried as it is: the skip heals nothing")
	assert_string_contains(_label.get_text_now(), "room 2 / 3")
	assert_eq(room().get_room_data().id, &"solo_2")
	set_hp(10)
	var second: int = room().get_instance_id()
	press_key(KEY_R)
	assert_ne(room().get_instance_id(), second, "a new room again")
	assert_eq(_floor.get_run().get_room_index(), 1, "the same room")
	assert_eq(hp(), 100, "at full HP")
	assert_string_contains(_label.get_text_now(), "room 2 / 3")


func test_ac23_n_enters_the_boss_room_at_full_hp_and_does_nothing_in_the_last_room() -> void:
	await spawn_floor(_three_room_floor(1), 1)
	_find_label()
	set_hp(30)
	press_key(KEY_N)
	assert_true(room().get_room_data().is_boss_room)
	assert_eq(hp(), 100, "the boss room's full heal")
	var boss_room: int = room().get_instance_id()
	press_key(KEY_N)
	assert_eq(room().get_instance_id(), boss_room, "no next room")
	assert_eq(_floor.get_run().get_room_index(), 2)
	assert_false(_floor.get_run().is_floor_cleared(), "skipping isn't clearing the boss")


func test_ac23_the_floor_scene_declares_its_signal_for_a_room_entered() -> void:
	await spawn_floor(_three_room_floor(1))
	var entered: Array[int] = []
	_floor.room_entered.connect(func(index: int) -> void: entered.append(index))
	press_key(KEY_N)
	press_key(KEY_N)
	assert_eq(entered, [1, 2] as Array[int])


func _three_room_floor(floor_number: int) -> FloorData:
	var rooms: Array[RoomData] = [
		FloorFixtures.one_enemy_room(&"solo_1", &"grunt1"),
		FloorFixtures.one_enemy_room(&"solo_2", &"grunt2"),
	]
	return FloorFixtures.floor_of(rooms, floor_number)


## A fresh floor scene as the child of `parent`, which joins the tree with it.
func _spawn_under(parent: Node2D) -> void:
	_floor = (load(FLOOR_SCENE_PATH) as PackedScene).instantiate()
	_floor.floor_data = _three_room_floor(1)
	_floor.player_input_enabled = false
	parent.add_child(_floor)
	add_child_autofree(parent)
	await get_tree().physics_frame


## F-011/C6: the one setup error is about the origin, and nothing was built or runs.
func _expect_origin_refused() -> void:
	var errors: PackedStringArray = _floor.get_setup_errors()
	assert_eq(errors.size(), 1, str(errors))
	assert_string_contains(errors[0], "origin: the floor scene must sit at the world origin")
	assert_push_error("origin: the floor scene must sit at the world origin")
	assert_null(_floor.get_room(), "no room")
	assert_null(_floor.get_run())
	assert_false(_floor.is_physics_processing(), "nothing steps")
	assert_eq(_count_rooms(), 0, "and nothing was added to the tree")


func _find_label() -> void:
	_label = _floor.get_node("DebugLayer/FloorDebugLabel")


func _count_rooms() -> int:
	var rooms: int = 0
	for child: Node in _floor.get_children():
		rooms += 1 if child is Room else 0
	return rooms


func _any(errors: PackedStringArray, needle: String) -> bool:
	for error: String in errors:
		if error.contains(needle):
			return true
	return false
