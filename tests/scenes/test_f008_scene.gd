extends F008SceneTest
## F-008 T6: f008_hexer.tscn (AC17), its debug keys and reset, and AC16's views after a reset,
## a reload and a restore.

const ROOM_TILES: Vector2 = Vector2(20, 12)


func test_ac17_the_scene_runs_on_its_own() -> void:
	await spawn_debug_scene()
	assert_eq(_runner.get_setup_errors(), PackedStringArray())
	assert_true(_runner.is_physics_processing())
	assert_eq(_runner.combatant_paths.size(), 2, "one Warrior, one Hexer")
	assert_eq(_player.class_data.id, &"warrior")
	assert_eq(_enemy.get_data_path(), Tunables.HEXER_PATH)
	assert_eq(_enemy.logic.get_data().brain, EnemyData.Brain.CASTER)
	assert_true(_runner.refill_player_on_died)
	await run_ticks(30)
	assert_gt(_runner.get_sim().get_time() - _t0, 0.0, "it steps")


func test_ac17_the_f007_room_with_no_pillar_or_door() -> void:
	await spawn_debug_scene()
	var inner: Rect2 = _room_inside()
	assert_eq(inner.position, Vector2.ZERO)
	assert_eq(inner.size, ROOM_TILES)
	var walls: Array[String] = []
	for wall: Node in _scene.get_node("World").get_children():
		walls.append(wall.name)
	assert_eq(walls, ["NorthWall", "SouthWall", "WestWall", "EastWall"] as Array[String])
	var names: Array[String] = []
	for child: Node in _scene.get_children():
		names.append(child.name)
	assert_eq(
		names,
		(
			[
				"World",
				"Player",
				"Hexer",
				"CombatDebugDraw",
				"MotorDebugOverlay",
				"BossBarLayer",
				"CombatRunner",
			]
			as Array[String]
		),
		"no door, gate or floor logic"
	)


func test_ac17_the_boss_bar_shows_hp_and_a_mark_at_50() -> void:
	await spawn_debug_scene()
	await wait_process_frames(1)
	assert_eq(_bar.get_marks(), [0.5] as Array[float])
	assert_eq(_bar.get_fill_fraction(), 1.0)
	assert_string_contains(_bar.get_label_text(), "320 / 320  stage 1")


func test_ac17_the_debug_keys_work_here() -> void:
	await spawn_debug_scene()
	press_key(KEY_I)
	assert_false(_enemy.logic.is_ai_enabled())
	assert_string_contains(await overlay_text(), "ai: off")
	press_key(KEY_I)
	assert_true(_enemy.logic.is_ai_enabled())
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_eq(_enemy.logic.get_data().id, &"hexer")


func test_ac17_the_debug_reset_returns_the_hexer_to_its_start() -> void:
	await spawn_debug_scene(place.bind(Vector2(10, 6), Vector2(15, 6)))
	var start: Vector2 = _enemy.global_position
	BossValues.set_hp(_enemy.logic, 150)
	assert_true(await run_until(func() -> bool: return _enemy.get_bolts_px().size() > 0, 900))
	assert_eq(_enemy.logic.get_stage_index(), 1)
	press_key(KEY_R)
	assert_eq(_enemy.logic.get_combat_state().get_hp(), 320, "full HP")
	assert_eq(_enemy.logic.get_stage_index(), 0, "stage 0")
	assert_null(_enemy.logic.get_running_attack(), "no attack")
	assert_eq(enemy_state(), EnemyLogic.State.IDLE)
	assert_eq(_enemy.logic.get_projectiles().get_projectiles().size(), 0, "no bolts")
	assert_eq(_enemy.logic.get_projectiles().get_next_serial(), 0)
	assert_eq(_enemy.global_position, start)
	assert_views_match_logic("after the reset")
	assert_eq(_enemy.get_bolts_px().size(), 0)


func test_ac16_no_stale_line_or_bolt_after_a_restore() -> void:
	await spawn_debug_scene(place.bind(Vector2(10, 6), Vector2(15, 6)))
	assert_true(await run_until(func() -> bool: return enemy_state() == EnemyLogic.State.WINDUP))
	var in_windup: Dictionary = _runner.take_snapshot()
	assert_true(await run_until(func() -> bool: return _enemy.get_bolts_px().size() == 3))
	await run_ticks(10)
	var in_flight: Dictionary = _runner.take_snapshot()
	var flying: PackedVector3Array = _enemy.get_bolts_px()
	await run_ticks(30)
	assert_true(_runner.restore_snapshot(in_windup))
	assert_eq(_enemy.get_bolts_px().size(), 0, "no stale bolt")
	assert_eq(_enemy.get_aim_lines().size(), 3, "the fan's lines")
	assert_views_match_logic("restored in windup")
	assert_true(_runner.restore_snapshot(in_flight))
	assert_eq(_enemy.get_bolts_px(), flying, "the bolts where they were")
	assert_views_match_logic("restored in flight")


func test_ac16_after_a_reload_the_views_still_follow_logic() -> void:
	await spawn_debug_scene(place.bind(Vector2(10, 6), Vector2(15, 6)))
	var fan_b_windup: Callable = func() -> bool:
		var attack: EnemyAttackData = _enemy.logic.get_running_attack()
		return (
			attack != null
			and attack.id == &"hexer_fan_b"
			and enemy_state() == EnemyLogic.State.WINDUP
		)
	assert_true(await run_until(fan_b_windup))
	assert_gt(_enemy.get_bolts_px().size(), 0, "fan A's bolts in flight")
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_views_match_logic("after the reload")
	assert_eq(_enemy.get_aim_lines().size(), 2, "fan B's two lines, latched")


## The walls' inner faces, in tiles.
func _room_inside() -> Rect2:
	var left: float = -INF
	var right: float = INF
	var top: float = -INF
	var bottom: float = INF
	for wall: Node in _scene.get_node("World").get_children():
		var body: StaticBody2D = wall as StaticBody2D
		var shape: RectangleShape2D = body.get_node("CollisionShape2D").shape
		var rect: Rect2 = Rect2(body.position - shape.size / 2.0, shape.size)
		if shape.size.x > shape.size.y:
			if rect.position.y < 0:
				top = maxf(top, rect.end.y)
			else:
				bottom = minf(bottom, rect.position.y)
		elif rect.position.x < 0:
			left = maxf(left, rect.end.x)
		else:
			right = minf(right, rect.position.x)
	var inner_px: Rect2 = Rect2(left, top, right - left, bottom - top)
	return Rect2(
		Units.vector_px_to_tiles(inner_px.position), Units.vector_px_to_tiles(inner_px.size)
	)
