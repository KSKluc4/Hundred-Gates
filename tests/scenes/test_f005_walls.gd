extends F005SceneTest
## F-005 AC23 (C5): walls stop projectiles over real physics, a stopped projectile never sinks
## into a wall, and a launch born inside a wall is blocked.

const PLAYER_SCENE: PackedScene = preload("res://src/entities/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://src/entities/enemies/enemy.tscn")
## AC23: a stopped projectile's circle may sink at most 0.01 tiles into a wall.
const MAX_OVERLAP_PX: float = 0.01 * 16.0
## The pillar, as the scene places it: 2x2 tiles centred here.
const PILLAR_RECT: Rect2 = Rect2(156, 146, 32, 32)
const NORTH_FACE_PX: float = 0.0
const BOLT_RADIUS_PX: float = 0.25 * 16.0

var _walls: Array[Rect2] = []
var _max_overlap_px: float = -INF
var _contacts: int = 0
var _bolts_drawn: int = 0


func test_ac23_a_bolt_at_the_player_behind_the_pillar_breaks_on_it() -> void:
	await spawn_fresh(_place_behind_the_pillar)
	_watch_walls()
	var watch: CasterWatch = watch_caster(_casters[1])
	var hurt: Array[float] = record_hurt()
	await run_ticks(150)  # 2.5 s: the first bolt flies and breaks, before the next one.
	var spent: Dictionary = _last_sample(watch)
	assert_true(spent["spent"], "stopped")
	var centre: Vector2 = Units.vector_tiles_to_px(spent["position"])
	var gap: float = _distance_to_rect(centre, PILLAR_RECT)
	assert_almost_eq(gap, BOLT_RADIUS_PX, 0.5, "touching the pillar")
	assert_lt(Units.px_to_tiles(centre.distance_to(Vector2(216, 128))), 10.0, "short of max")
	assert_eq(hurt.size(), 0, "it never hit")
	assert_eq(_player.motor.get_combat_state().get_hp(), 100)
	assert_lte(_max_overlap_px, MAX_OVERLAP_PX, "max overlap %.4f px" % _max_overlap_px)
	assert_gt(_contacts, 100)


func test_ac23_a_bolt_into_an_outer_wall_stops_there() -> void:
	await spawn_fresh(_place_under_the_north_wall)
	_watch_walls()
	var watch: CasterWatch = watch_caster(_casters[0])
	var hurt: Array[float] = record_hurt()
	await run_ticks(24)  # To 0.4 s, after the 0.35 lock.
	await run_ticks(12, false, false, Vector2.RIGHT)  # Steps out of the line.
	await run_ticks(114)  # To 2.5 s.
	var spent: Dictionary = _last_sample(watch)
	assert_true(spent["spent"], "stopped")
	var centre: Vector2 = Units.vector_tiles_to_px(spent["position"])
	assert_almost_eq(centre.y, NORTH_FACE_PX + BOLT_RADIUS_PX, 0.5, "at the north wall's face")
	assert_almost_eq(centre.x, 240.0, TILE_PX, "straight up")
	assert_eq(hurt.size(), 0)
	assert_lte(_max_overlap_px, MAX_OVERLAP_PX, "max overlap %.4f px" % _max_overlap_px)


func test_ac23_a_launch_inside_a_wall_is_blocked_on_and_between_contacts() -> void:
	for windup: float in [0.6, 0.605]:
		var label: String = "windup %s" % windup
		var hurt: Array[float] = await _blocked_launch_run(windup, true)
		var caster: Enemy = _scene.get_node("Caster")
		assert_eq(hurt.size(), 0, "%s: not hit" % label)
		assert_eq(caster.logic.get_projectiles().get_next_serial(), 1, "%s: it launched" % label)
		assert_eq(caster.logic.get_projectiles().get_projectiles().size(), 0, label)
		assert_eq(_bolts_drawn, 0, "%s: no bolt drawn, ever" % label)
		_scene.queue_free()


func test_ac23_control_the_same_launch_with_the_wall_away_hits() -> void:
	for windup: float in [0.6, 0.605]:
		var hurt: Array[float] = await _blocked_launch_run(windup, false)
		assert_eq(hurt.size(), 1, "windup %s" % windup)
		assert_almost_eq(hurt[0], ceilf(windup * 120.0 - TIME) / 120.0, TIME, "at the launch")
		_scene.queue_free()


## AC23's small walled scene, built here: a caster with a 0.5-tile bolt (bigger than its
## 0.35-tile body) touching a wall on its right, aiming left at a player 0.6 tiles away whose
## hurtbox overlaps the launch circle. `with_wall` false moves the wall far away. Runs 1 s.
func _blocked_launch_run(windup: float, with_wall: bool) -> Array[float]:
	_scene = Node2D.new()
	var wall: StaticBody2D = StaticBody2D.new()
	wall.name = "Wall"
	wall.collision_layer = 1
	wall.position = Vector2(200, 100) if with_wall else Vector2(400, 100)
	var wall_shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(16, 160)  # Its left face at x = 192.
	wall_shape.shape = rect
	wall.add_child(wall_shape)
	_scene.add_child(wall)
	_player = PLAYER_SCENE.instantiate()
	_player.name = "Player"
	_player.position = Vector2(192 - 5.6 - 9.6, 100)
	_player.input_enabled = false
	_scene.add_child(_player)
	var caster: Enemy = ENEMY_SCENE.instantiate()
	caster.name = "Caster"
	caster.combat_id = &"caster_1"
	var data: EnemyData = caster_copy()
	data.attack.range_tiles = 0.5
	data.attack.windup = windup
	caster.data = data
	caster.position = Vector2(192 - 5.6, 100)  # Its 0.35-tile body touches the wall.
	_scene.add_child(caster)
	_runner = CombatRunner.new()
	_runner.name = "CombatRunner"
	_runner.combatant_paths = [NodePath("../Player"), NodePath("../Caster")] as Array[NodePath]
	_scene.add_child(_runner)
	add_child_autofree(_scene)
	await get_tree().physics_frame
	_runner.reset()
	_t0 = _runner.get_sim().get_time()
	_bolts_drawn = 0
	var probe: SimProbe = SimProbe.new()
	probe.on_contact = func() -> void: _bolts_drawn += caster.get_bolts_px().size()
	_runner.get_sim().register(probe)
	var hurt: Array[float] = record_hurt()
	for _i: int in 60:
		await get_tree().physics_frame
		_bolts_drawn += caster.get_bolts_px().size()
	return hurt


func _place_behind_the_pillar() -> void:
	_casters[0].position = FAR_EAST
	_chaser.position = Vector2(456, 296)


func _place_under_the_north_wall() -> void:
	_player.position = Vector2(240, 40)
	_casters[0].position = Vector2(240, 140)
	park_others()


## Every wall rectangle in the room, and a probe that measures the worst overlap of any
## projectile with any of them at every contact instant.
func _watch_walls() -> void:
	_walls = []
	for wall: Node in _scene.get_node("World").get_children():
		var shape: RectangleShape2D = (wall.get_node("CollisionShape2D") as CollisionShape2D).shape
		var centre: Vector2 = (wall as Node2D).global_position
		_walls.append(Rect2(centre - shape.size / 2.0, shape.size))
	var probe: SimProbe = SimProbe.new()
	probe.on_contact = _measure_overlap
	_runner.get_sim().register(probe)


func _measure_overlap() -> void:
	_contacts += 1
	for enemy: Enemy in _casters:
		for projectile: ProjectileSet.Projectile in enemy.logic.get_projectiles().get_projectiles():
			var centre: Vector2 = Units.vector_tiles_to_px(projectile.position)
			var radius: float = Units.tiles_to_px(projectile.radius)
			for rect: Rect2 in _walls:
				_max_overlap_px = maxf(_max_overlap_px, radius - _distance_to_rect(centre, rect))


## The last contact sample that still had projectile 0.
func _last_sample(watch: CasterWatch) -> Dictionary:
	var last_step: int = watch.seen_at[0][-1]
	return watch.projectile_at(last_step)


func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var nearest: Vector2 = point.clamp(rect.position, rect.end)
	return point.distance_to(nearest)
