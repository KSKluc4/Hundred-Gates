extends F011SceneTest
## F-014 T5 (C12, AC17): the warning rings of a room with reinforcements, in the real floor scene
## on fixture floors. WaveMarkers draws what the director says, from get_pending(), every frame.
##
## WaveFixtures.wave_room(): placed `chaser_1` and `caster_2` (asleep), reserve `chaser_3`,
## `caster_4`, `chaser_5`. The warning lasts 0.8 s: 96 steps, one step per tick at 120 ticks/s.

const WARNING_TICKS: int = 96
const FILL_TOLERANCE: float = 0.02

var _tunables_before: Dictionary = {}


func before_each() -> void:
	super()
	_tunables_before = {
		"warning": Tunables.floors.wave_spawn_warning_duration,
		"interval": Tunables.floors.wave_spawn_interval,
	}


func after_each() -> void:
	Tunables.floors.wave_spawn_warning_duration = _tunables_before["warning"]
	Tunables.floors.wave_spawn_interval = _tunables_before["interval"]
	await super()


func _wave_floor(room: RoomData = null, wave_rooms: int = 1) -> FloorData:
	var rooms: Array[RoomData] = []
	for index: int in wave_rooms:
		rooms.append(WaveFixtures.wave_room(StringName("wave_%d" % (index + 1))))
	if room != null:
		rooms[0] = room
	return FloorFixtures.floor_of(rooms)


func _markers() -> WaveMarkers:
	return room().get_wave_markers()


func _pending_now() -> bool:
	return not room().get_waves().get_pending().is_empty()


func _enemy_named(id: StringName) -> Enemy:
	for node: Enemy in room().get_enemies():
		if node.combat_id == id:
			return node
	return null


## The fight starts: the first placed enemy dies, and a warning starts in the next step.
func _start_a_warning() -> RoomWaves.Pending:
	kill(enemy(0))
	assert_true(await run_until(_pending_now, 20), "a warning starts")
	return room().get_waves().get_pending()[0]


func test_ac17_there_is_no_marker_before_any_warning() -> void:
	await spawn_floor(_wave_floor())
	assert_not_null(_markers())
	assert_eq(_markers().get_markers().size(), 0)
	await run_ticks(2 * WARNING_TICKS)
	assert_false(room().get_waves().has_started(), "nobody has noticed the player")
	assert_eq(_markers().get_markers().size(), 0)
	assert_eq(_markers().get_last_drawn().size(), 0, "and the draw pass drew none")


func test_ac17_one_marker_at_the_pending_point_with_the_arriving_enemys_radius() -> void:
	await spawn_floor(_wave_floor())
	var warning: RoomWaves.Pending = await _start_a_warning()
	var markers: Array[Dictionary] = _markers().get_markers()
	assert_eq(markers.size(), 1)
	assert_eq(markers[0]["enemy_id"], warning.enemy_id)
	assert_eq(markers[0]["position_px"], Units.vector_tiles_to_px(warning.point))
	var expected_radius: float = Units.tiles_to_px(
		_enemy_named(warning.enemy_id).data.hurtbox_radius_tiles
	)
	assert_eq(markers[0]["radius_px"], expected_radius, "the arriving enemy's body")
	assert_gt(expected_radius, 0.0)
	await wait_process_frames(2)
	var drawn: Array[Dictionary] = _markers().get_last_drawn()
	assert_eq(drawn.size(), 1, "that is what it draws")
	for key: String in ["enemy_id", "position_px", "radius_px"]:
		assert_eq(drawn[0][key], markers[0][key], key)
	assert_gt(float(drawn[0]["fill"]), 0.0, "a little further on, as the frames went by")


func test_ac17_the_radius_is_the_arriving_enemys_own_not_the_first_ones() -> void:
	Tunables.floors.wave_spawn_interval = 0.0
	await spawn_floor(_wave_floor())
	kill(enemy(0))
	kill(enemy(1))
	assert_true(await run_until(_pending_now, 20))
	var seen: Dictionary = {}
	for _i: int in 5 * WARNING_TICKS:
		for marker: Dictionary in _markers().get_markers():
			seen[marker["enemy_id"]] = marker["radius_px"]
		set_hp(100)
		await run_ticks(1)
	assert_true(seen.has(&"chaser_3") and seen.has(&"caster_4"), "both kinds were warned")
	assert_ne(seen[&"chaser_3"], seen[&"caster_4"], "a chaser's body and a caster's differ")
	assert_eq(
		seen[&"caster_4"], Units.tiles_to_px(_enemy_named(&"caster_4").data.hurtbox_radius_tiles)
	)


func test_ac17_the_fill_follows_the_time_left() -> void:
	await spawn_floor(_wave_floor())
	await _start_a_warning()
	assert_almost_eq(float(_markers().get_markers()[0]["fill"]), 0.0, 0.0001, "0 at the start")
	var last_fill: float = 0.0
	for _i: int in WARNING_TICKS / 2:
		await run_ticks(1)
		var fill: float = _markers().get_markers()[0]["fill"]
		assert_gte(fill, last_fill, "it only grows")
		last_fill = fill
	assert_almost_eq(last_fill, 0.5, FILL_TOLERANCE, "about a half midway")
	for _i: int in WARNING_TICKS / 2 - 2:
		await run_ticks(1)
	assert_eq(_markers().get_markers().size(), 1, "still there a step or two before")
	assert_gt(float(_markers().get_markers()[0]["fill"]), 0.97, "close to 1 just before arrival")
	assert_lt(float(_markers().get_markers()[0]["fill"]), 1.0)


func test_ac17_the_fill_is_the_pending_arrivals_own_numbers() -> void:
	await spawn_floor(_wave_floor())
	await _start_a_warning()
	for _i: int in 40:
		await run_ticks(1)
		var entry: RoomWaves.Pending = room().get_waves().get_pending()[0]
		assert_almost_eq(
			float(_markers().get_markers()[0]["fill"]), 1.0 - entry.time_left / entry.total, 0.00001
		)


func test_ac17_a_warning_of_zero_is_drawn_full() -> void:
	Tunables.floors.wave_spawn_warning_duration = 0.0
	await spawn_floor(_wave_floor())
	kill(enemy(0))
	assert_true(await run_until(_pending_now, 20))
	assert_eq(room().get_waves().get_pending()[0].total, 0.0)
	assert_eq(_markers().get_markers().size(), 1)
	assert_eq(float(_markers().get_markers()[0]["fill"]), 1.0, "full")
	await run_ticks(1)
	assert_eq(_markers().get_markers().size(), 0, "and it arrived in the next step")


func test_ac17_the_marker_is_gone_in_the_frame_after_the_arrival() -> void:
	await spawn_floor(_wave_floor())
	var warning: RoomWaves.Pending = await _start_a_warning()
	var node: Enemy = _enemy_named(warning.enemy_id)
	await wait_process_frames(1)
	assert_eq(_markers().get_last_drawn().size(), 1, "drawn while it runs")
	var arrived: Callable = func() -> bool: return not node.logic.is_waiting()
	assert_true(await run_until(arrived, 2 * WARNING_TICKS))
	assert_eq(_markers().get_markers().size(), 0, "none in the tick it arrives")
	await wait_process_frames(2)
	assert_eq(_markers().get_last_drawn().size(), 0, "none drawn in the frame after")


func test_ac17_two_pending_arrivals_have_two_markers_at_two_points() -> void:
	Tunables.floors.wave_spawn_interval = 0.0
	var data: RoomData = WaveFixtures.wave_room()
	data.max_engaged = 2
	await spawn_floor(_wave_floor(data))
	kill(enemy(0))
	kill(enemy(1))
	assert_true(await run_until(_pending_now, 20))
	var markers: Array[Dictionary] = _markers().get_markers()
	assert_eq(markers.size(), 2, "the cap allows two")
	assert_ne(markers[0]["position_px"], markers[1]["position_px"], "at two different points")
	assert_ne(markers[0]["enemy_id"], markers[1]["enemy_id"])
	var pending: Array[RoomWaves.Pending] = room().get_waves().get_pending()
	for index: int in 2:
		assert_eq(markers[index]["position_px"], Units.vector_tiles_to_px(pending[index].point))
	await wait_process_frames(2)
	assert_eq(_markers().get_last_drawn().size(), 2)


func test_ac17_a_pending_arrival_whose_enemy_was_killed_has_no_marker_at_once() -> void:
	await spawn_floor(_wave_floor())
	var warning: RoomWaves.Pending = await _start_a_warning()
	assert_eq(_markers().get_markers().size(), 1)
	kill(_enemy_named(warning.enemy_id))
	assert_eq(_markers().get_markers().size(), 0, "before any tick or frame")
	await wait_process_frames(2)
	assert_eq(_markers().get_last_drawn().size(), 0)


func test_ac17_a_restore_to_before_the_warning_shows_no_marker_and_to_during_it_shows_it() -> void:
	await spawn_floor(_wave_floor())
	var before: Dictionary = room().get_runner().take_snapshot()
	var warning: RoomWaves.Pending = await _start_a_warning()
	var during: Dictionary = room().get_runner().take_snapshot()
	await run_ticks(30)
	assert_eq(_markers().get_markers().size(), 1)
	assert_true(room().get_runner().restore_snapshot(before))
	assert_eq(_markers().get_markers().size(), 0, "no marker left behind")
	await wait_process_frames(2)
	assert_eq(_markers().get_last_drawn().size(), 0)
	assert_true(room().get_runner().restore_snapshot(during))
	var markers: Array[Dictionary] = _markers().get_markers()
	assert_eq(markers.size(), 1, "the warning is back")
	assert_eq(markers[0]["position_px"], Units.vector_tiles_to_px(warning.point))
	assert_almost_eq(float(markers[0]["fill"]), 0.0, 0.0001, "from where the snapshot was taken")


func test_ac17_a_rebuilt_room_shows_no_marker() -> void:
	await spawn_floor(_wave_floor())
	await _start_a_warning()
	var old_markers: WaveMarkers = _markers()
	var old_room: Room = room()
	press_key(KEY_R)
	assert_ne(room(), old_room)
	assert_ne(_markers(), old_markers, "a new node")
	assert_eq(_markers().get_markers().size(), 0)
	await wait_process_frames(2)
	assert_eq(_markers().get_last_drawn().size(), 0)
	assert_false(
		is_instance_valid(old_markers) and old_markers.is_inside_tree(), "the old one left"
	)


func test_c12_a_room_without_reinforcements_has_no_marker_node() -> void:
	await spawn_floor(FloorFixtures.floor_of([FloorFixtures.arena_room()]))
	assert_null(room().get_wave_markers())
	for child: Node in room().get_children():
		assert_false(child is WaveMarkers, "no WaveMarkers anywhere under the room")


func test_c12_the_marker_node_has_no_collision_and_draws_under_the_bodies() -> void:
	await spawn_floor(_wave_floor())
	var markers: WaveMarkers = _markers()
	var as_variant: Variant = markers
	assert_false(as_variant is CollisionObject2D)
	assert_eq(markers.find_children("*", "CollisionObject2D", true, false).size(), 0)
	assert_eq(markers.find_children("*", "CollisionShape2D", true, false).size(), 0)
	assert_eq(markers.get_child_count(), 0, "nothing beneath it")
	assert_lt(markers.z_index, enemy(0).z_index, "under the enemies")
	assert_lt(markers.z_index, player().z_index, "and the player")
	assert_eq(room().get_child(room().get_child_count() - 1), room().get_runner(), "runner last")


func test_c12_the_look_differs_from_the_enemy_telegraphs() -> void:
	await spawn_floor(_wave_floor())
	var markers: WaveMarkers = _markers()
	var node: Enemy = enemy(0)
	var telegraphs: Array[Color] = [
		node.tracking_color,
		node.locked_color,
		node.locked_fill_color,
		node.active_color,
		node.bolt_color,
		node.open_color,
		node.shift_color,
	]
	for color: Color in telegraphs:
		assert_ne(markers.ring_color, color)
		assert_ne(markers.fill_color, color)
	assert_gt(markers.line_width_px, 0.0)
