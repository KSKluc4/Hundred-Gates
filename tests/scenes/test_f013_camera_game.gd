extends F012GameTest
## F-013 T1 (AC5, AC8): the follow camera inside the real `Game`, on a tower built by the test
## whose town and rooms are larger than the view: the town into a floor, a floor back to the
## town, a death, and the HUD, which keeps its screen position while the player crosses a room
## larger than the view.
## The rooms and builders are test_f013_camera.gd's.

const CameraTest: GDScript = preload("res://tests/scenes/test_f013_camera.gd")
const TOWN_SIZE: Vector2i = Vector2i(64, 36)
const GATE_FIRST_X: int = 30
const GATE_WIDTH: int = 4
const TOWN_START: Vector2i = Vector2i(32, 9)
const NEAR_PX: float = 0.01
const DEATH_DELAY: float = 0.2

var _smoothing_speed_before: float


func before_each() -> void:
	super.before_each()
	_smoothing_speed_before = Tunables.camera.follow_smoothing_speed


func after_each() -> void:
	Tunables.camera.follow_smoothing_speed = _smoothing_speed_before
	await super.after_each()


## The town: 64 x 36, a 4-tile gate on the north border, P near it. Then one floor of two rooms and
## a boss room, all larger than the view.
func big_tower() -> TowerData:
	var rows: PackedStringArray = CameraTest.open_rows(TOWN_SIZE, TOWN_START)
	rows = RoomFixtures.with_tile(rows, TOWN_SIZE.x - 1, TOWN_SIZE.y / 2, "#")
	rows = RoomFixtures.with_tile(rows, TOWN_SIZE.x - 1, TOWN_SIZE.y / 2 + 1, "#")
	for step: int in GATE_WIDTH:
		rows = RoomFixtures.with_tile(rows, GATE_FIRST_X + step, 0, "E")
	var data: TowerData = TowerData.new()
	data.town = TowerFixtures.safe_room_with(&"town", rows)
	var floors: Array[FloorData] = [CameraTest.big_floor()]
	data.floors = floors
	return data


## The room the game shows: the town's, or the floor's.
func shown_room() -> Room:
	return town().get_room() if town() != null else room()


func assert_on_start_target(label: String) -> void:
	var shown: Room = shown_room()
	var cam: PlaceholderShake = shown.get_camera()
	assert_eq(cam.get_viewport().get_camera_2d(), cam, "%s: the viewport's camera" % label)
	assert_true(cam.is_current(), "%s: current" % label)
	var data: RoomData = shown.get_room_data()
	var start_px: Vector2 = Units.vector_tiles_to_px(data.get_player_start_tiles())
	var view: Vector2 = get_viewport().get_visible_rect().size
	var expected: Vector2 = CameraTest.expected_center_px(start_px, data.get_size(), view)
	assert_eq(cam.offset, Vector2.ZERO, "%s: no shake" % label)
	var actual: Vector2 = cam.get_screen_center_position()
	assert_true(
		actual.distance_to(expected) <= NEAR_PX, "%s: %s is not %s" % [label, actual, expected]
	)


## The check one physics frame after, and once more a frame later.
func assert_on_start_target_and_after_a_frame(label: String) -> void:
	assert_on_start_target(label)
	await get_tree().physics_frame
	assert_on_start_target("%s, a frame later" % label)


# --- AC5 ---


func test_ac5_the_town_at_the_start_of_the_game() -> void:
	await spawn_game(big_tower())
	assert_eq(game().get_setup_errors(), PackedStringArray(), "the tower is valid")
	assert_eq(town().get_room().get_room_data().get_size(), TOWN_SIZE)
	await assert_on_start_target_and_after_a_frame("the town")


func test_ac5_from_the_town_into_a_floor() -> void:
	await spawn_game(big_tower())
	await enter_floor_through_gate(1)
	assert_not_null(floor_scene(), "a floor is shown")
	assert_null(town())
	await assert_on_start_target_and_after_a_frame("the floor, from the town")


func test_ac5_from_a_floor_back_to_the_town() -> void:
	await spawn_game(big_tower())
	await enter_floor_through_gate(1, false)
	skip_to_boss()
	await run_ticks(1)
	await clear_boss_and_leave()
	assert_not_null(town(), "the town is shown")
	await assert_on_start_target_and_after_a_frame("the town, from the floor")


func test_ac5_the_town_after_a_death_in_a_floor() -> void:
	set_death_delay(DEATH_DELAY)
	await spawn_game(big_tower())
	await enter_floor_through_gate(1)
	put_player_at(Vector2(30.5, 14.5))
	await run_ticks(30)
	kill_player()
	var back: Callable = func() -> bool: return town() != null
	assert_true(await run_until(back, WALK_LIMIT_TICKS), "the death returned to the town")
	await assert_on_start_target_and_after_a_frame("the town, after a death")


func test_ac5_a_floor_entered_at_the_boss_from_the_town() -> void:
	await spawn_game(big_tower())
	session().get_progress().mark_boss_reached(1)
	await enter_floor_through_gate(1, true)
	assert_true(room().get_room_data().is_boss_room)
	await assert_on_start_target_and_after_a_frame("the boss room, from the town")


# --- AC8: the HUD does not scroll ---


func test_ac8_the_hud_keeps_its_screen_position_while_the_player_crosses_the_town() -> void:
	Tunables.camera.follow_smoothing_speed = 30.0  # the walk below covers the whole town quickly
	await spawn_game(big_tower())
	var elements: Array[Control] = [
		hud().get_health_bar(),
		hud().get_node("LocationLabel"),
		hud().get_node("BannerLabel"),
	]
	var before: Array[Vector2] = _screen_origins(elements)
	var world_before: Vector2 = get_viewport().get_canvas_transform().origin
	var moved: bool = false
	for spot: Vector2 in [Vector2(32.5, 20.5), Vector2(10.5, 30.5), Vector2(55.5, 30.5)]:
		put_player_at(spot)
		await run_ticks(120)
		assert_eq(_screen_origins(elements), before, "the HUD with the player at %s" % spot)
		moved = moved or get_viewport().get_canvas_transform().origin != world_before
	assert_true(moved, "the world did scroll under the HUD")
	assert_ne(
		get_viewport().get_canvas_transform().origin,
		world_before,
		"and it is not back at the start"
	)


func test_ac8_the_hud_keeps_its_screen_position_in_a_floor_room_larger_than_the_view() -> void:
	Tunables.camera.follow_smoothing_speed = 30.0
	await spawn_game(big_tower())
	await enter_floor_through_gate(1)
	var elements: Array[Control] = [hud().get_health_bar(), hud().get_node("LocationLabel")]
	var before: Array[Vector2] = _screen_origins(elements)
	var world_before: Vector2 = get_viewport().get_canvas_transform().origin
	for spot: Vector2 in [Vector2(30.5, 14.5), Vector2(44.5, 24.5)]:
		put_player_at(spot)
		await run_ticks(120)
		assert_eq(_screen_origins(elements), before, "the HUD with the player at %s" % spot)
	assert_ne(get_viewport().get_canvas_transform().origin, world_before, "the world scrolled")


func _screen_origins(elements: Array[Control]) -> Array[Vector2]:
	var origins: Array[Vector2] = []
	for element: Control in elements:
		origins.append(element.get_global_transform_with_canvas().origin)
	return origins
