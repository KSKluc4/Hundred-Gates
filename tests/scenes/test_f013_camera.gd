# gdlint:disable=max-public-methods
extends F011SceneTest
## F-013 T1 (AC1-AC8): the room's follow camera. Rooms are built by the tests, with their own
## sizes (48 x 28, 64 x 36, the 12 x 8 fixture): a `Room` on a `RoomData` directly, or the real
## floor scene for the ways of reaching a room. The `Game` cases (a death, the town and a floor,
## the HUD) are in test_f013_camera_game.gd.
## The engine facts these rely on are tests too (PR-11, PR-13): a smoothed, limited camera is on
## its limited target in the first physics frame; `offset` is applied after the limits and is part
## of get_screen_center_position(); reset_smoothing() + force_update_scroll() settle a camera.

const VIEW: Vector2i = Vector2i(640, 360)
const NO_TILE: Vector2i = Vector2i(-1, -1)
const SMALL: Vector2i = Vector2i(12, 8)
const MEDIUM: Vector2i = Vector2i(48, 28)
const LARGE: Vector2i = Vector2i(64, 36)
## Raised for each test: the shipped file still says 40 x 22 while T2 is not in.
const MAX_ROOM_FOR_TESTS: Vector2i = Vector2i(80, 46)
## Pixels: a camera that is "at" a place is within this of it.
const NEAR_PX: float = 0.01
const WALK_TICKS: int = 300

var _built: Room
var _smoothing_enabled_before: bool
var _smoothing_speed_before: float
var _margin_before: int
var _max_room_before: Vector2i


func before_each() -> void:
	super.before_each()
	_built = null
	_smoothing_enabled_before = Tunables.camera.follow_smoothing_enabled
	_smoothing_speed_before = Tunables.camera.follow_smoothing_speed
	_margin_before = Tunables.camera.outside_margin_tiles
	_max_room_before = Tunables.floors.max_room_size
	Tunables.floors.max_room_size = MAX_ROOM_FOR_TESTS


func after_each() -> void:
	Tunables.camera.follow_smoothing_enabled = _smoothing_enabled_before
	Tunables.camera.follow_smoothing_speed = _smoothing_speed_before
	Tunables.camera.outside_margin_tiles = _margin_before
	Tunables.floors.max_room_size = _max_room_before
	await super.after_each()


# --- shared builders (the Game cases use them too) ---


## A walled room of `size` tiles: floor inside, `P` at `start`, a 2-tile exit on the east border at
## mid height and, unless `spawn` is NO_TILE, a `1` there.
static func open_rows(
	size: Vector2i, start: Vector2i, spawn: Vector2i = NO_TILE
) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for y: int in size.y:
		if y == 0 or y == size.y - 1:
			rows.append("#".repeat(size.x))
		else:
			rows.append("#" + ".".repeat(size.x - 2) + "#")
	var exit_y: int = size.y / 2
	rows = RoomFixtures.with_tile(rows, size.x - 1, exit_y, "E")
	rows = RoomFixtures.with_tile(rows, size.x - 1, exit_y + 1, "E")
	rows = RoomFixtures.with_tile(rows, start.x, start.y, "P")
	if spawn != NO_TILE:
		rows = RoomFixtures.with_tile(rows, spawn.x, spawn.y, "1")
	return rows


## No enemies, so nothing moves the player but the test.
static func empty_room(size: Vector2i, room_id: StringName = &"empty") -> RoomData:
	var rows: PackedStringArray = open_rows(size, Vector2i(2, size.y / 2))
	return TowerFixtures.safe_room_with(room_id, rows)


## One weak enemy far to the east: a combat room (or, with `is_boss`, a boss room).
static func enemy_room(size: Vector2i, room_id: StringName, is_boss: bool = false) -> RoomData:
	var rows: PackedStringArray = open_rows(
		size, Vector2i(2, size.y / 2), Vector2i(size.x - 8, size.y / 2)
	)
	var enemy_id: StringName = StringName("%s_enemy" % room_id)
	var enemies: Array[EnemyData] = [FloorFixtures.weak_enemy(enemy_id)]
	return RoomFixtures.room(room_id, rows, enemies, is_boss)


## Two rooms larger than the view, then a boss room.
static func big_floor(floor_number: int = 1) -> FloorData:
	var data: FloorData = FloorData.new()
	data.floor_number = floor_number
	var prefix: String = "f%d" % floor_number
	var list: Array[RoomData] = [
		enemy_room(MEDIUM, StringName(prefix + "_a")),
		enemy_room(Vector2i(52, 28), StringName(prefix + "_b")),
		enemy_room(Vector2i(56, 32), StringName(prefix + "_boss"), true),
	]
	data.rooms = list
	return data


## Where a camera with the room's limits looks for a body at `player_px`, worked out here from
## the room's size and the view and not from Room.camera_limits_px(): a body held so the view
## stays inside the room; on an axis where the room is smaller than the view, the room's middle.
static func expected_center_px(
	player_px: Vector2, room_size: Vector2i, view_px: Vector2
) -> Vector2:
	var room_px: Vector2 = Vector2(room_size * Units.TILE_SIZE_PX)
	var center: Vector2 = player_px
	for axis: int in 2:
		if room_px[axis] <= view_px[axis]:
			center[axis] = room_px[axis] / 2.0
		else:
			center[axis] = clampf(
				player_px[axis], view_px[axis] / 2.0, room_px[axis] - view_px[axis] / 2.0
			)
	return center


# --- helpers ---


func room() -> Room:
	if _built != null:
		return _built
	return _floor.get_room()


func player() -> Player:
	return room().get_player()


func camera() -> PlaceholderShake:
	return room().get_camera()


## A `Room` on `data` with no floor scene, its player's input off. One physics frame passes.
func build_room(data: RoomData) -> void:
	_built = Room.new()
	_built.player_input_enabled = false
	_built.setup(data, 100)
	add_child_autofree(_built)
	await get_tree().physics_frame


func view_px() -> Vector2:
	return get_viewport().get_visible_rect().size


## The shake off and the smoothing run to its end: what "settled" means in the spec (§5).
func settle() -> void:
	var cam: PlaceholderShake = camera()
	cam.shake_enabled = false
	cam.clear()
	cam.reset_smoothing()
	cam.force_update_scroll()


func center_px() -> Vector2:
	return camera().get_screen_center_position()


func player_px() -> Vector2:
	return player().global_position


func room_size() -> Vector2i:
	return room().get_room_data().get_size()


func room_rect_px() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(room_size() * Units.TILE_SIZE_PX))


## The rectangle the camera shows, from its settled centre.
func visible_rect_px() -> Rect2:
	return Rect2(center_px() - view_px() / 2.0, view_px())


## Where the player stands in the room, `x` and `y` in tiles, and the camera is settled there.
func stand_and_settle(tiles: Vector2) -> void:
	put_player_at(tiles)
	settle()


## The camera is the viewport's current one and looks at the limited place for the player's start.
func assert_on_start_target(label: String) -> void:
	var cam: PlaceholderShake = camera()
	assert_eq(cam.get_viewport().get_camera_2d(), cam, "%s: the viewport's camera" % label)
	assert_true(cam.is_current(), "%s: current" % label)
	var start_px: Vector2 = Units.vector_tiles_to_px(
		room().get_room_data().get_player_start_tiles()
	)
	var expected: Vector2 = expected_center_px(start_px, room_size(), view_px())
	assert_eq(cam.offset, Vector2.ZERO, "%s: no shake yet" % label)
	_assert_near(cam.get_screen_center_position(), expected, "%s: the limited start" % label)


func _assert_near(
	actual: Vector2, expected: Vector2, label: String, tolerance: float = NEAR_PX
) -> void:
	assert_true(
		actual.distance_to(expected) <= tolerance,
		"%s: %s is not within %s of %s" % [label, actual, tolerance, expected]
	)


# --- engine facts ---


func test_engine_the_headless_view_is_the_project_viewport() -> void:
	await build_room(empty_room(SMALL))
	assert_eq(Vector2i(view_px()), VIEW)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), VIEW.x)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), VIEW.y)


func test_engine_the_offset_comes_after_the_limits_and_is_in_the_screen_centre() -> void:
	await build_room(empty_room(MEDIUM))
	stand_and_settle(Vector2(1.5, 1.5))
	var limited: Vector2 = center_px()
	_assert_near(limited, Vector2(320.0, 180.0), "the corner, limited")
	camera().offset = Vector2(-6.0, -6.0)
	camera().force_update_scroll()
	_assert_near(
		center_px(), limited + Vector2(-6.0, -6.0), "the offset is added to the limited place"
	)
	assert_lt(visible_rect_px().position.x, 0.0, "so the view leaves the room by the offset")


func test_engine_settling_jumps_a_camera_that_is_gliding() -> void:
	await build_room(empty_room(LARGE))
	stand_and_settle(Vector2(20.5, 18.5))
	var before: Vector2 = center_px()
	put_player_at(Vector2(44.5, 18.5))
	await get_tree().physics_frame
	var expected: Vector2 = expected_center_px(player_px(), room_size(), view_px())
	assert_lt(center_px().x, expected.x - 100.0, "a teleport inside the room glides (§3, costs)")
	assert_gt(center_px().x, before.x, "and the camera did start to move")
	settle()
	_assert_near(center_px(), expected, "settled: on the new place")


# --- AC1: Room.camera_limits_px() ---


func test_ac1_a_room_a_view_large_or_more_gets_its_own_rectangle() -> void:
	assert_eq(Room.camera_limits_px(LARGE, VIEW), Rect2i(0, 0, 1024, 576), "64 x 36")
	assert_eq(Room.camera_limits_px(Vector2i(40, 23), VIEW), Rect2i(0, 0, 640, 368), "40 x 23")


func test_ac1_a_small_room_gets_a_view_long_range_centred_on_it() -> void:
	assert_eq(Room.camera_limits_px(SMALL, VIEW), Rect2i(-224, -116, 640, 360), "12 x 8")


func test_ac1_each_axis_is_decided_on_its_own() -> void:
	assert_eq(Room.camera_limits_px(Vector2i(64, 12), VIEW), Rect2i(0, -84, 1024, 360), "64 x 12")
	assert_eq(Room.camera_limits_px(Vector2i(12, 36), VIEW), Rect2i(-224, 0, 640, 576), "12 x 36")


func test_ac1_the_rounding_is_a_floor() -> void:
	var limits: Rect2i = Room.camera_limits_px(SMALL, Vector2i(641, 361))
	assert_eq(limits, Rect2i(-225, -117, 641, 361), "12 x 8 against 641 x 361")


func test_ac1_the_range_is_centred_on_the_room_within_a_pixel() -> void:
	for view: Vector2i in [VIEW, Vector2i(641, 361), Vector2i(320, 181)]:
		var limits: Rect2i = Room.camera_limits_px(SMALL, view)
		var room_centre: Vector2 = Vector2(SMALL * Units.TILE_SIZE_PX) / 2.0
		var range_centre: Vector2 = Vector2(limits.position) + Vector2(limits.size) / 2.0
		assert_lte(range_centre.distance_to(room_centre), 1.0, "view %s" % view)
		assert_eq(
			limits.size, view.max(SMALL * Units.TILE_SIZE_PX), "at least a view, view %s" % view
		)


# --- AC2, AC3, AC4 ---


func test_ac2_in_a_48_by_28_room_the_view_stays_inside_at_every_corner_and_the_centre() -> void:
	await build_room(empty_room(MEDIUM))
	_assert_view_inside_at_corners_and_centre()


func test_ac2_in_a_64_by_36_room_the_view_stays_inside_at_every_corner_and_the_centre() -> void:
	await build_room(empty_room(LARGE))
	_assert_view_inside_at_corners_and_centre()


func _assert_view_inside_at_corners_and_centre() -> void:
	var size: Vector2i = room_size()
	var outer: Rect2 = room_rect_px().grow(0.001)
	var spots: Dictionary = {
		"north-west": Vector2(1.5, 1.5),
		"north-east": Vector2(size.x - 1.5, 1.5),
		"south-west": Vector2(1.5, size.y - 1.5),
		"south-east": Vector2(size.x - 1.5, size.y - 1.5),
		"centre": Vector2(size) / 2.0,
	}
	for spot: String in spots:
		stand_and_settle(spots[spot])
		assert_true(outer.encloses(visible_rect_px()), "%s: %s" % [spot, visible_rect_px()])
		assert_true(camera().is_current(), "%s: the camera is current" % spot)


## AC2, the shipped pass (T6): the view stays inside the room on the smallest and on the largest
## room of the shipped tower, the town included. Found from the data, by area; every room that
## ties for it is checked.
func test_ac2_on_the_smallest_shipped_room_the_view_stays_inside() -> void:
	for data: RoomData in _shipped_rooms_by_area(true):
		await build_room(data)
		_assert_view_inside_at_walkable_corners_and_centre()
		_built.queue_free()
		await get_tree().physics_frame


func test_ac2_on_the_largest_shipped_room_the_view_stays_inside() -> void:
	for data: RoomData in _shipped_rooms_by_area(false):
		await build_room(data)
		_assert_view_inside_at_walkable_corners_and_centre()
		_built.queue_free()
		await get_tree().physics_frame


## The town and every floor room of the shipped tower whose area is the smallest (or the largest).
func _shipped_rooms_by_area(smallest: bool) -> Array[RoomData]:
	var tower: TowerData = load(Tunables.TOWER_PATH) as TowerData
	var all: Array[RoomData] = [tower.town]
	for floor_data: FloorData in tower.floors:
		all.append_array(floor_data.rooms)
	var best: int = -1
	for data: RoomData in all:
		var area: int = data.get_size().x * data.get_size().y
		if best < 0 or (area < best if smallest else area > best):
			best = area
	var found: Array[RoomData] = []
	for data: RoomData in all:
		if data.get_size().x * data.get_size().y == best:
			found.append(data)
	assert_gt(found.size(), 0, "a shipped room was found")
	return found


## As _assert_view_inside_at_corners_and_centre(), where the player stands on floor: the corners
## are the walkable tiles next to the border corners, the centre is the walkable tile nearest the
## middle (a shipped room may have a block there).
func _assert_view_inside_at_walkable_corners_and_centre() -> void:
	var data: RoomData = room().get_room_data()
	var size: Vector2i = data.get_size()
	var outer: Rect2 = room_rect_px().grow(0.001)
	var middle: Vector2 = Vector2(size) / 2.0
	var centre: Vector2i = Vector2i(1, 1)
	for y: int in range(1, size.y - 1):
		for x: int in range(1, size.x - 1):
			var tile: Vector2i = Vector2i(x, y)
			var better: bool = (
				(Vector2(tile) + Vector2(0.5, 0.5)).distance_to(middle)
				< ((Vector2(centre) + Vector2(0.5, 0.5)).distance_to(middle))
			)
			if data.is_walkable(tile) and (better or not data.is_walkable(centre)):
				centre = tile
	var spots: Dictionary = {
		"north-west": Vector2i(1, 1),
		"north-east": Vector2i(size.x - 2, 1),
		"south-west": Vector2i(1, size.y - 2),
		"south-east": Vector2i(size.x - 2, size.y - 2),
		"centre": centre,
	}
	for spot: String in spots:
		var tile: Vector2i = spots[spot]
		assert_true(data.is_walkable(tile), "%s %s: %s is floor" % [data.id, spot, tile])
		stand_and_settle(Vector2(tile) + Vector2(0.5, 0.5))
		assert_true(
			outer.encloses(visible_rect_px()), "%s %s: %s" % [data.id, spot, visible_rect_px()]
		)
		assert_true(camera().is_current(), "%s %s: the camera is current" % [data.id, spot])


func test_ac3_in_a_48_by_28_room_the_camera_is_on_the_player_when_far_from_every_wall() -> void:
	await build_room(empty_room(MEDIUM))
	# Half a view is 20 x 11.25 tiles: the room allows x in 20..28 and y in 11.25..16.75.
	_assert_camera_on_player([Vector2(24, 14), Vector2(20, 11.25), Vector2(28, 16.75)])


func test_ac3_in_a_64_by_36_room_the_camera_is_on_the_player_when_far_from_every_wall() -> void:
	await build_room(empty_room(LARGE))
	_assert_camera_on_player(
		[Vector2(32, 18), Vector2(20, 11.25), Vector2(44, 24.75), Vector2(25, 15), Vector2(40, 20)]
	)


func _assert_camera_on_player(spots: Array[Vector2]) -> void:
	for spot: Vector2 in spots:
		stand_and_settle(spot)
		_assert_near(center_px(), player_px(), "player at %s" % spot, 1.0)
		assert_almost_eq(player_px(), Units.vector_tiles_to_px(spot), Vector2(0.5, 0.5))


func test_ac3_next_to_a_wall_the_camera_holds_back_and_the_player_leaves_the_centre() -> void:
	await build_room(empty_room(LARGE))
	stand_and_settle(Vector2(3.5, 18.5))
	_assert_near(center_px(), Vector2(320.0, 18.5 * 16.0), "held at the west limit")
	assert_gt(center_px().x, player_px().x + 200.0, "the player is left of the screen's centre")


func test_ac4_a_12_by_8_room_is_centred_wherever_the_player_stands() -> void:
	await build_room(TowerFixtures.safe_room())
	assert_eq(room_size(), SMALL)
	var middle: Vector2 = Vector2(SMALL * Units.TILE_SIZE_PX) / 2.0
	for spot: Vector2 in [
		Vector2(1.5, 1.5), Vector2(10.5, 6.5), Vector2(6.0, 4.0), Vector2(1.5, 6.5)
	]:
		stand_and_settle(spot)
		_assert_near(center_px(), middle, "player at %s" % spot, 0.5)
		assert_true(visible_rect_px().encloses(room_rect_px()), "the whole room is on screen")


func test_ac4_a_room_narrower_than_the_view_on_one_axis_only_is_centred_on_that_axis() -> void:
	await build_room(empty_room(Vector2i(64, 12)))
	stand_and_settle(Vector2(30.5, 6.5))
	assert_almost_eq(center_px().y, 96.0, 0.5, "centred on the short axis")
	assert_almost_eq(center_px().x, 30.5 * 16.0, 1.0, "following on the long one")


# --- AC5: the camera is on its limited target as soon as a room is shown ---


func test_ac5_a_room_built_directly_is_on_its_limited_start_without_settling() -> void:
	await build_room(empty_room(MEDIUM))
	assert_on_start_target("48 x 28")
	_assert_near(center_px(), Vector2(320.0, 14.0 * 16.0 + 8.0), "not the player's own place", 0.01)
	assert_gt(center_px().x, player_px().x + 200.0, "the start is near the west wall: limited")


func test_ac5_the_first_room_of_a_floor() -> void:
	await spawn_floor(big_floor())
	assert_on_start_target("first room")


func test_ac5_through_the_door() -> void:
	await spawn_floor(big_floor())
	await _walk_to_next_room()
	assert_eq(_floor.get_run().get_room_index(), 1)
	assert_eq(room().get_room_data().id, &"f1_b")
	assert_on_start_target("room 2, through the door")
	await get_tree().physics_frame
	assert_on_start_target("room 2, one frame later")


func test_ac5_through_the_door_into_the_boss_room() -> void:
	await spawn_floor(big_floor(), 1)
	await _walk_to_next_room()
	assert_true(room().get_room_data().is_boss_room)
	assert_on_start_target("boss room, through the door")


func test_ac5_with_the_n_key() -> void:
	await spawn_floor(big_floor())
	press_key(KEY_N)
	assert_eq(_floor.get_run().get_room_index(), 1)
	await get_tree().physics_frame
	assert_on_start_target("room 2, N key")
	await get_tree().physics_frame
	assert_on_start_target("room 2, N key, one frame later")


func test_ac5_with_the_r_key() -> void:
	await spawn_floor(big_floor(), 1)
	put_player_at(Vector2(30.5, 14.5))
	await run_ticks(60)
	press_key(KEY_R)
	await get_tree().physics_frame
	assert_on_start_target("room 2, R key")
	await get_tree().physics_frame
	assert_on_start_target("room 2, R key, one frame later")


func test_ac5_after_a_death_the_restarted_room() -> void:
	await spawn_floor(big_floor(), 1)
	put_player_at(Vector2(30.5, 14.5))
	await run_ticks(60)
	hit(player().motor, 1000)
	var old_id: int = room().get_instance_id()
	await run_until(func() -> bool: return room().get_instance_id() != old_id, 10)
	assert_ne(room().get_instance_id(), old_id, "the room was rebuilt")
	assert_on_start_target("after a death")
	await get_tree().physics_frame
	assert_on_start_target("after a death, one frame later")


func test_ac5_a_room_swap_never_glides_in_from_the_old_rooms_place() -> void:
	await spawn_floor(big_floor())
	put_player_at(Vector2(40.5, 20.5))
	await run_ticks(30)
	await _walk_to_next_room()
	var start_px: Vector2 = Units.vector_tiles_to_px(
		room().get_room_data().get_player_start_tiles()
	)
	assert_lt(center_px().x, start_px.x + 300.0, "not near where the old room's player stood")
	assert_on_start_target("the new room")


# --- AC6: smoothing and the callback come from camera.tres ---


func test_ac6_the_camera_takes_smoothing_and_callback_from_the_tunables_file() -> void:
	await build_room(empty_room(MEDIUM))
	var cam: PlaceholderShake = camera()
	assert_eq(cam.position_smoothing_enabled, Tunables.camera.follow_smoothing_enabled)
	assert_true(cam.position_smoothing_enabled, "the shipped file smooths")
	assert_almost_eq(cam.position_smoothing_speed, Tunables.camera.follow_smoothing_speed, 0.0001)
	assert_almost_eq(cam.position_smoothing_speed, 8.0, 0.0001)
	assert_eq(cam.process_callback, Camera2D.CAMERA2D_PROCESS_PHYSICS)
	assert_false(cam.limit_smoothed, "C2: limit smoothing stays off")


func test_ac6_the_values_are_read_from_the_tunables_not_written_in_the_room() -> void:
	Tunables.camera.follow_smoothing_enabled = false
	Tunables.camera.follow_smoothing_speed = 3.5
	await build_room(empty_room(MEDIUM))
	assert_false(camera().position_smoothing_enabled)
	assert_almost_eq(camera().position_smoothing_speed, 3.5, 0.0001)
	assert_eq(camera().process_callback, Camera2D.CAMERA2D_PROCESS_PHYSICS)


func test_ac6_with_smoothing_off_the_camera_is_on_the_limited_player_every_physics_frame() -> void:
	Tunables.camera.follow_smoothing_enabled = false
	await build_room(empty_room(MEDIUM))
	camera().shake_enabled = false
	put_player_at(Vector2(18.5, 14.5))
	var checked: int = 0
	for tick: int in WALK_TICKS:
		await run_ticks(1, Vector2.RIGHT)
		var expected: Vector2 = expected_center_px(player_px(), room_size(), view_px())
		_assert_near(center_px(), expected, "tick %d" % tick)
		checked += 1
	assert_eq(checked, WALK_TICKS)
	assert_gt(player_px().x, 28.0 * 16.0, "the walk went past the east limit of the follow")


func test_ac6_with_smoothing_on_the_camera_trails_a_moving_player() -> void:
	await build_room(empty_room(MEDIUM))
	camera().shake_enabled = false
	put_player_at(Vector2(21.5, 14.5))
	settle()
	await run_ticks(30, Vector2.RIGHT)
	var expected: Vector2 = expected_center_px(player_px(), room_size(), view_px())
	assert_gt(player_px().x, 22.0 * 16.0)
	assert_lt(center_px().x, expected.x - 0.5, "behind the limited player")
	assert_gt(center_px().x, 21.5 * 16.0, "but on its way")


# --- AC7: the outside strips ---


func test_ac7_four_strips_with_the_wall_colour_and_no_collision() -> void:
	await build_room(empty_room(MEDIUM))
	var strips: Array[ColorRect] = room().get_outside_strips()
	assert_eq(strips.size(), 4)
	for strip: ColorRect in strips:
		assert_eq(strip.color, room().wall_color, "%s: the wall colour" % strip.name)
		assert_true(room().is_ancestor_of(strip))
		assert_eq(strip.get_child_count(), 0, "%s: nothing under it" % strip.name)
		var node: Node = strip
		while node != room():
			assert_false(node is CollisionObject2D, "%s: no body above it" % strip.name)
			assert_false(node is CollisionShape2D)
			node = node.get_parent()


func test_ac7_the_strips_cover_the_margin_on_every_side_including_the_corners() -> void:
	await build_room(empty_room(MEDIUM))
	_assert_ring_covered(Tunables.camera.outside_margin_tiles)


func test_ac7_the_margin_is_the_tunables_not_a_constant() -> void:
	Tunables.camera.outside_margin_tiles = 5
	await build_room(empty_room(LARGE))
	_assert_ring_covered(5)


func test_ac7_a_margin_of_zero_builds_no_strip() -> void:
	Tunables.camera.outside_margin_tiles = 0
	await build_room(empty_room(MEDIUM))
	assert_eq(room().get_outside_strips().size(), 0)


func _assert_ring_covered(margin_tiles: int) -> void:
	var margin: float = margin_tiles * float(Units.TILE_SIZE_PX)
	var inner: Rect2 = room_rect_px()
	var outer: Rect2 = inner.grow(margin)
	var area: float = 0.0
	var rects: Array[Rect2] = []
	for strip: ColorRect in room().get_outside_strips():
		var rect: Rect2 = Rect2(strip.global_position, strip.size)
		assert_true(outer.encloses(rect), "%s: inside the outer rectangle" % strip.name)
		assert_false(rect.intersects(inner), "%s: outside the room" % strip.name)
		for other: Rect2 in rects:
			assert_false(rect.intersects(other), "%s: no overlap" % strip.name)
		rects.append(rect)
		area += rect.get_area()
	var ring_area: float = outer.get_area() - inner.get_area()
	assert_almost_eq(area, ring_area, 0.001, "the strips add up to the whole ring")
	var probes: Array[Vector2] = [
		outer.position + Vector2(1.0, 1.0),
		Vector2(outer.end.x - 1.0, outer.position.y + 1.0),
		Vector2(outer.position.x + 1.0, outer.end.y - 1.0),
		outer.end - Vector2(1.0, 1.0),
		Vector2(inner.position.x - 1.0, inner.get_center().y),
		Vector2(inner.end.x + 1.0, inner.get_center().y),
		Vector2(inner.get_center().x, inner.position.y - 1.0),
		Vector2(inner.get_center().x, inner.end.y + 1.0),
	]
	for probe: Vector2 in probes:
		var covered: bool = rects.any(func(rect: Rect2) -> bool: return rect.has_point(probe))
		assert_true(covered, "%s is covered" % probe)


func test_ac7_the_strips_are_not_walls_and_the_nav_grid_is_the_rooms_own() -> void:
	var data: RoomData = empty_room(MEDIUM)
	await build_room(data)
	var wall_tiles: int = 0
	for row: String in data.rows:
		wall_tiles += row.count("#")
	var covered: int = 0
	for wall: StaticBody2D in room().get_wall_bodies():
		var shape: RectangleShape2D = (wall.get_node("CollisionShape2D") as CollisionShape2D).shape
		covered += (
			roundi(shape.size.x / Units.TILE_SIZE_PX) * roundi(shape.size.y / Units.TILE_SIZE_PX)
		)
	assert_eq(covered, wall_tiles, "the bodies are the grid's walls and nothing else")
	var bodies: int = 0
	for child: Node in room().get_children():
		bodies += 1 if child is CollisionObject2D and child != player() else 0
	assert_eq(bodies, room().get_wall_bodies().size() + 1, "walls and the door, no strip")


func test_ac7_the_shipped_margin_covers_the_shipped_shake() -> void:
	var shake: ScreenShakeSettings = load(Tunables.SCREEN_SHAKE_PATH)
	var shipped: CameraTunables = load(Tunables.CAMERA_TUNABLES_PATH)
	var margin_px: float = shipped.outside_margin_tiles * float(Units.TILE_SIZE_PX)
	assert_gte(margin_px, shake.max_offset_px)


# --- AC8: the shake, the boss bar ---


func test_ac8_a_hit_shakes_the_rooms_camera() -> void:
	await build_room(empty_room(MEDIUM))
	assert_is(camera(), PlaceholderShake)
	assert_eq(camera().get_offset_limit_px(), 0.0, "still before the hit")
	hit(player().motor, 5)
	assert_gt(camera().get_current_intensity(), 0.0)
	assert_gt(camera().get_offset_limit_px(), 0.0, "a non-zero offset limit after a hit")
	assert_eq(room().get_runner().get_node(room().get_runner().shake_path), camera(), "C6")


func test_ac8_a_shake_at_a_corner_stays_inside_the_strips() -> void:
	await build_room(empty_room(MEDIUM))
	put_player_at(Vector2(1.5, 1.5))
	hit(player().motor, 5)
	var strip_limit: Rect2 = room_rect_px().grow(
		Tunables.camera.outside_margin_tiles * float(Units.TILE_SIZE_PX) + 0.001
	)
	var shook: bool = false
	for _frame: int in 12:
		await get_tree().process_frame
		camera().force_update_scroll()
		shook = shook or camera().offset != Vector2.ZERO
		assert_true(strip_limit.encloses(visible_rect_px()), "frame %s" % visible_rect_px())
	assert_true(shook, "the camera did move")


func test_ac8_the_boss_bar_keeps_its_screen_position_while_the_player_crosses_the_room() -> void:
	await build_room(enemy_room(LARGE, &"boss_big", true))
	var bar: BossBar = _find_bar()
	assert_not_null(bar)
	var screen_before: Vector2 = bar.get_global_transform_with_canvas().origin
	assert_eq(screen_before, room().boss_bar_position_px)
	var canvas_origin_before: Vector2 = get_viewport().get_canvas_transform().origin
	for spot: Vector2 in [Vector2(30.5, 18.5), Vector2(50.5, 30.5), Vector2(60.5, 4.5)]:
		put_player_at(spot)
		await run_ticks(90)
		assert_eq(bar.get_global_transform_with_canvas().origin, screen_before, "at %s" % spot)
	assert_ne(
		get_viewport().get_canvas_transform().origin, canvas_origin_before, "the world did scroll"
	)


func _find_bar() -> BossBar:
	var layer: CanvasLayer = room().get_node(NodePath(Room.BOSS_LAYER_NAME))
	for child: Node in layer.get_children():
		if child is BossBar:
			return child
	return null


## Clears the room and walks out through its door, until the floor builds the next one.
func _walk_to_next_room() -> void:
	var old_id: int = room().get_instance_id()
	kill_all()
	await run_ticks(2)
	put_player_at_door()
	var left: Callable = func() -> bool: return room().get_instance_id() != old_id
	assert_true(await run_until(left, WALK_TICKS * 2, Vector2.RIGHT), "walked out of the room")
