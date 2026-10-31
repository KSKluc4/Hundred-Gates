extends GutTest
## AC8, in the debug scene over real physics frames, with scripted commands.

const SCENE: PackedScene = preload("res://scenes/debug/f001_movement.tscn")
const WORLD_LAYER: int = 1
const EAST_FACE_X: float = 480.0
const DIAGONAL_WALL_CENTER: Vector2 = Vector2(368, 96)
const DIAGONAL_WALL_HALF_THICKNESS: float = 8.0
const SETTLE_TICKS: int = 12

var _player: Player
var _body_radius: float
var _overlaps: int
var _ticks_per_second_before: int


func before_each() -> void:
	_ticks_per_second_before = Engine.physics_ticks_per_second


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks_per_second_before


func test_open_space_dash_keeps_motor_travel_through_physics() -> void:
	await _spawn_at(Vector2(240, 160))
	var distance_px: float = Units.tiles_to_px(_player.class_data.dash_distance)
	await _run_ticks(1, Vector2.DOWN, true)
	await _run_ticks(_dash_ticks() + SETTLE_TICKS)
	assert_almost_eq(_player.global_position.y, 160.0 + distance_px, Units.tiles_to_px(0.01))
	assert_almost_eq(_player.global_position.x, 240.0, 0.001)
	assert_eq(_player.motor.get_position_px(), _player.global_position)


func test_c1_glue_keeps_dash_distance_at_every_tick_rate() -> void:
	for rate: int in [30, 60, 120]:
		Engine.physics_ticks_per_second = rate
		await _spawn_at(Vector2(240, 160))
		var distance_px: float = Units.tiles_to_px(_player.class_data.dash_distance)
		await _run_ticks(1, Vector2.DOWN, true)
		await _run_ticks(_dash_ticks() + SETTLE_TICKS)
		var label: String = "%d ticks/s" % rate
		var tolerance: float = Units.tiles_to_px(0.01)
		assert_almost_eq(_player.global_position.y, 160.0 + distance_px, tolerance, label)


func test_ac8_straight_dash_stops_at_the_wall_without_overlap() -> void:
	await _spawn_at(Vector2(EAST_FACE_X - 24.0, 160))
	await _run_ticks(1, Vector2.RIGHT, true)
	await _run_ticks(_dash_ticks() + SETTLE_TICKS)
	assert_almost_eq(_player.global_position.x, EAST_FACE_X - _body_radius, 0.2)
	assert_lte(_player.global_position.x, EAST_FACE_X - _body_radius)
	assert_eq(_overlaps, 0)
	assert_eq(_player.motor.get_position_px(), _player.global_position, "C18: physics wins")


func test_ac8_no_jitter_while_walking_into_a_wall() -> void:
	await _spawn_at(Vector2(EAST_FACE_X - 12.0, 160))
	await _run_ticks(30, Vector2.RIGHT)
	var resting_x: float = _player.global_position.x
	for _i: int in 20:
		await _run_ticks(1, Vector2.RIGHT)
		assert_almost_eq(_player.global_position.x, resting_x, 0.001)
	assert_eq(_overlaps, 0)


func test_ac8_diagonal_dash_into_a_flat_wall_slides_along_it() -> void:
	var start: Vector2 = Vector2(EAST_FACE_X - _radius_of_scene() - 1.0, 100)
	await _spawn_at(start)
	await _run_ticks(1, Vector2(1, 1).normalized(), true)
	await _run_ticks(_dash_ticks() + SETTLE_TICKS)
	# MOTION_MODE_FLOATING keeps speed on a slide: the full distance, not distance·cos45.
	var distance_px: float = Units.tiles_to_px(_player.class_data.dash_distance)
	var slide_px: float = _player.global_position.y - start.y
	assert_almost_eq(slide_px, distance_px, 2.0)
	assert_lte(_player.global_position.x, EAST_FACE_X - _body_radius)
	assert_eq(_overlaps, 0)


func test_ac8_straight_dash_into_a_45_degree_wall_slides_along_it() -> void:
	var normal: Vector2 = Vector2(-1, 1).normalized()
	var tangent: Vector2 = Vector2(1, 1).normalized()
	var offset: float = DIAGONAL_WALL_HALF_THICKNESS + _radius_of_scene()
	var start: Vector2 = DIAGONAL_WALL_CENTER + normal * (offset + 2.0)
	await _spawn_at(start)
	await _run_ticks(1, Vector2.RIGHT, true)
	await _run_ticks(_dash_ticks() + SETTLE_TICKS)
	var moved: Vector2 = _player.global_position - start
	assert_gt(moved.dot(tangent), 25.0, "slid along the wall")
	var from_center: Vector2 = _player.global_position - DIAGONAL_WALL_CENTER
	assert_gte(from_center.dot(normal), offset, "stayed outside the wall")
	assert_eq(_overlaps, 0)


func test_restored_snapshot_moves_the_body_before_the_next_tick() -> void:
	await _spawn_at(Vector2(240, 160))
	await _run_ticks(10, Vector2.RIGHT)
	var snapshot: Dictionary = _player.motor.to_dict()
	var saved_position: Vector2 = _player.global_position
	await _run_ticks(10, Vector2.LEFT)
	assert_ne(_player.global_position, saved_position)
	_player.restore_snapshot(snapshot)
	assert_eq(_player.global_position, saved_position)


func _radius_of_scene() -> float:
	var player_scene: Node = SCENE.instantiate()
	var shape: CircleShape2D = player_scene.get_node("Player/CollisionShape2D").shape
	player_scene.free()
	return shape.radius


func _spawn_at(start: Vector2) -> void:
	var scene: Node = SCENE.instantiate()
	_player = scene.get_node("Player")
	_player.position = start
	_player.input_enabled = false
	_body_radius = (_player.get_node("CollisionShape2D").shape as CircleShape2D).radius
	_overlaps = 0
	add_child_autofree(scene)
	await get_tree().physics_frame  # _run_ticks must start just before a Player tick.


func _dash_ticks() -> int:
	return ceili(_player.class_data.dash_duration * Engine.physics_ticks_per_second)


## One Player tick per iteration. GUT's wait_physics_frames(1) would span two ticks.
func _run_ticks(ticks: int, move: Vector2 = Vector2.ZERO, dash: bool = false) -> void:
	for _i: int in ticks:
		_player.motor.submit(MoveCommand.new(move))
		_player.motor.submit(AimCommand.new(Vector2.ZERO))
		if dash:
			_player.motor.submit(DashCommand.new())
		await get_tree().physics_frame
		if _overlaps_world():
			_overlaps += 1


func _overlaps_world() -> bool:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = _body_radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, _player.global_position)
	query.collision_mask = WORLD_LAYER
	var space: PhysicsDirectSpaceState2D = _player.get_world_2d().direct_space_state
	return not space.intersect_shape(query, 1).is_empty()
