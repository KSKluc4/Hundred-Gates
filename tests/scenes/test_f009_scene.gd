extends F009SceneTest
## F-009 T4: f009_juggernaut.tscn (AC12, C11): it runs on its own in the f007 room, the boss
## bar, the debug keys, a charge stopped by a real outer wall (physics, not the stub), the
## debug reset and an F5 reload mid-fight.

const ROOM_TILES: Vector2 = Vector2(20, 12)
const F007_SCENE_PATH: String = "res://scenes/debug/f007_warden.tscn"


func test_ac12_the_scene_runs_on_its_own() -> void:
	await spawn_debug_scene()
	assert_eq(_runner.get_setup_errors(), PackedStringArray())
	assert_true(_runner.is_physics_processing())
	assert_eq(_runner.combatant_paths.size(), 2, "one Warrior, one Juggernaut")
	assert_eq(_player.class_data.id, &"warrior")
	assert_eq(_enemy.get_data_path(), Tunables.JUGGERNAUT_PATH)
	assert_eq(_enemy.logic.get_data().brain, EnemyData.Brain.BRUTE)
	assert_true(_runner.refill_player_on_died)
	await run_ticks(30)
	assert_gt(_runner.get_sim().get_time() - _t0, 0.0, "it steps")


func test_c11_the_f007_room_with_outer_walls_only() -> void:
	await spawn_debug_scene()
	assert_eq(_room_inside(_scene), Rect2(Vector2.ZERO, ROOM_TILES))
	var warden_room: Node2D = (load(F007_SCENE_PATH) as PackedScene).instantiate()
	assert_eq(_room_inside(_scene), _room_inside(warden_room), "the same room as f007")
	warden_room.free()
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
				"Juggernaut",
				"CombatDebugDraw",
				"MotorDebugOverlay",
				"BossBarLayer",
				"CombatRunner",
			]
			as Array[String]
		),
		"no pillar, door, gate or floor logic"
	)


func test_ac12_the_boss_bar_shows_hp_and_a_mark_at_50() -> void:
	await spawn_debug_scene()
	await wait_process_frames(1)
	assert_eq(_bar.get_marks(), [0.5] as Array[float])
	assert_eq(_bar.get_fill_fraction(), 1.0)
	assert_string_contains(_bar.get_label_text(), "500 / 500  stage 1")


func test_ac12_the_debug_keys_work_here() -> void:
	await spawn_debug_scene()
	press_key(KEY_I)
	assert_false(_enemy.logic.is_ai_enabled())
	assert_string_contains(await overlay_text(), "ai: off")
	press_key(KEY_I)
	assert_true(_enemy.logic.is_ai_enabled())
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_eq(_enemy.logic.get_data().id, &"juggernaut")


## The Juggernaut 5 tiles left of the player, who stands 2 tiles from the east wall: Charge A
## carries it into that wall.
func test_ac12_a_charge_into_a_real_outer_wall_stuns_it_and_ends_the_pattern() -> void:
	await spawn_debug_scene(place.bind(Vector2(18, 6), Vector2(13, 6)))
	var watch: CasterWatch = watch_enemy()
	assert_true(await run_until(func() -> bool: return _enemy.logic.is_wall_stopped(), 240))
	assert_eq(running_id(), &"juggernaut_charge_a")
	assert_eq(enemy_state(), EnemyLogic.State.RECOVERY)
	assert_false(_enemy.logic.has_pending_follow_up(), "a stun, not a gap")
	assert_eq(_enemy.get_body_color(), _enemy.open_color, "shown as open")
	assert_almost_eq(enemy_tiles().x, ROOM_TILES.x - 0.8, 0.01, "at the east wall's face")
	var stun_start: float = watch.times_entered(EnemyLogic.State.RECOVERY)[-1]
	assert_true(await run_until(func() -> bool: return running_id() == &"", 240))
	var idle: Array = watch.times_entered(EnemyLogic.State.IDLE)
	assert_almost_eq(idle[-1] - stun_start, 1.5, TIME, "stunned 1.5 s")
	assert_eq(watch.times_entered(EnemyLogic.State.WINDUP).size(), 1, "Charge B never came")
	assert_almost_eq(_enemy.logic.get_cooldown_remaining(), 1.0, STEP + TIME, "the cooldown")


func test_ac12_the_debug_reset_returns_full_hp_stage_0_no_attack_no_bolts() -> void:
	await spawn_debug_scene(place.bind(Vector2(10, 6), Vector2(11.5, 6)))
	var start: Vector2 = _enemy.global_position
	BossValues.set_hp(_enemy.logic, 240)
	var bolts_out: Callable = func() -> bool: return _enemy.get_bolts_px().size() > 0
	assert_true(await run_until(bolts_out, 900), "Debris in flight")
	assert_eq(_enemy.logic.get_stage_index(), 1)
	press_key(KEY_R)
	assert_eq(_enemy.logic.get_combat_state().get_hp(), 500, "full HP")
	assert_eq(_enemy.logic.get_stage_index(), 0, "stage 0")
	assert_null(_enemy.logic.get_running_attack(), "no attack")
	assert_eq(enemy_state(), EnemyLogic.State.IDLE)
	assert_eq(_enemy.logic.get_projectiles().get_projectiles().size(), 0, "no bolts")
	assert_eq(_enemy.logic.get_projectiles().get_next_serial(), 0)
	assert_eq(_enemy.get_bolts_px().size(), 0, "none drawn")
	assert_eq(_enemy.global_position, start)


func test_ac12_an_f5_reload_with_unchanged_data_keeps_the_fight_running() -> void:
	await spawn_debug_scene(place.bind(Vector2(5, 6), Vector2(10, 6)))
	var in_windup: Callable = func() -> bool:
		return running_id() == &"juggernaut_charge_a" and enemy_state() == EnemyLogic.State.WINDUP
	assert_true(await run_until(in_windup, 240))
	await run_ticks(10)
	var before: Dictionary = _enemy.logic.to_dict()
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_eq(running_id(), &"juggernaut_charge_a", "the charge goes on")
	assert_eq(_enemy.logic.get_combat_state().get_hp(), before["combat"]["hp"])
	assert_eq(_enemy.logic.get_pattern_root_index(), before["pattern_root_index"])
	var charge_b: Callable = func() -> bool: return running_id() == &"juggernaut_charge_b"
	assert_true(await run_until(charge_b, 240), "and its follow-up after it")


## The walls' inner faces, in tiles.
func _room_inside(scene: Node2D) -> Rect2:
	var left: float = -INF
	var right: float = INF
	var top: float = -INF
	var bottom: float = INF
	for wall: Node in scene.get_node("World").get_children():
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
