extends F007SceneTest
## F-007 T7: f007_warden.tscn (AC17), the gap and punish cues (AC21, C20), the stage shift cue
## and the boss bar (C17), and the debug reset in the scene (AC16).

const ROOM_TILES: Vector2 = Vector2(20, 12)


func test_ac17_the_scene_runs_on_its_own() -> void:
	await spawn_debug_scene()
	assert_eq(_runner.get_setup_errors(), PackedStringArray())
	assert_true(_runner.is_physics_processing())
	assert_eq(_runner.combatant_paths.size(), 2, "one Warrior, one Warden")
	assert_eq(_player.class_data.id, &"warrior")
	assert_eq(_boss.get_data_path(), Tunables.WARDEN_PATH)
	assert_true(_runner.refill_player_on_died, "Q2: the debug reset is the death")
	await run_ticks(30)
	assert_gt(run_time(), 0.0, "it steps")


func test_ac17_a_walled_room_of_20_by_12_tiles_and_nothing_else() -> void:
	await spawn_debug_scene()
	var inner: Rect2 = _room_inside()
	assert_eq(inner.position, Vector2.ZERO)
	assert_eq(inner.size, ROOM_TILES)
	var names: Array[String] = []
	for child: Node in _scene.get_children():
		names.append(child.name)
	assert_eq(
		names,
		(
			[
				"World",
				"Player",
				"Warden",
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
	assert_string_contains(_bar.get_label_text(), "400 / 400  stage 1")
	BossValues.set_hp(_boss.logic, 300)
	assert_eq(_bar.get_fill_fraction(), 0.75)
	assert_false(_bar.is_shift_cue_on())


func test_ac17_a_visible_cue_during_the_stage_shift() -> void:
	await spawn_debug_scene()
	BossValues.set_hp(_boss.logic, 200)
	await run_ticks(1)
	assert_eq(boss_state(), EnemyLogic.State.STAGE_SHIFT)
	await wait_process_frames(1)
	assert_true(_bar.is_shift_cue_on())
	assert_string_contains(_bar.get_label_text(), "stage 2  STAGE SHIFT")
	assert_eq(_boss.get_body_color(), _boss.shift_color)
	assert_string_contains(_boss.get_debug_text(), "STAGE_SHIFT")
	await run_until(func() -> bool: return boss_state() != EnemyLogic.State.STAGE_SHIFT)
	assert_false(_bar.is_shift_cue_on())
	assert_ne(_boss.get_body_color(), _boss.shift_color)


func test_ac21_swipe_a_s_recovery_is_a_gap_and_swipe_b_s_is_the_opening() -> void:
	await spawn_debug_scene()
	put_player_at(boss_tiles() - Vector2(1.5, 0))
	assert_true(await _run_to_recovery_of(&"warden_swipe_a"))
	assert_true(_boss.logic.has_pending_follow_up())
	assert_eq(_boss.get_body_color(), _boss.gap_color)
	assert_string_contains(_boss.get_debug_text(), "RECOVERY (gap)")
	assert_true(await _run_to_recovery_of(&"warden_swipe_b"))
	assert_false(_boss.logic.has_pending_follow_up())
	assert_eq(_boss.get_body_color(), _boss.open_color)
	assert_false(_boss.get_debug_text().contains("(gap)"))


func test_ac21_the_cue_follows_a_reset_and_a_restore_mid_gap() -> void:
	await spawn_debug_scene()
	put_player_at(boss_tiles() - Vector2(1.5, 0))
	assert_true(await _run_to_recovery_of(&"warden_swipe_a"))
	var mid_gap: Dictionary = _runner.take_snapshot()
	assert_true(await _run_to_recovery_of(&"warden_swipe_b"))
	assert_eq(_boss.get_body_color(), _boss.open_color)
	assert_true(_runner.restore_snapshot(mid_gap))
	assert_true(_boss.logic.has_pending_follow_up(), "restored mid-gap")
	assert_eq(_boss.get_body_color(), _boss.gap_color)
	assert_string_contains(_boss.get_debug_text(), "(gap)")
	_runner.reset()
	assert_false(_boss.logic.has_pending_follow_up(), "reset")
	assert_eq(_boss.get_body_color(), _boss.body_color)
	assert_false(_boss.get_debug_text().contains("(gap)"))


func test_ac21_a_chaser_s_recovery_still_shows_the_opening() -> void:
	await build(EnemyArena.chaser_values())
	var seen: Array[Color] = []
	for _i: int in 120:
		await run_ticks(1)
		if boss_state() == EnemyLogic.State.RECOVERY:
			seen.append(_boss.get_body_color())
			assert_false(_boss.get_debug_text().contains("(gap)"))
	assert_false(seen.is_empty(), "it attacked")
	for color: Color in seen:
		assert_eq(color, _boss.open_color)


func test_ac16_the_debug_reset_returns_the_warden_to_its_start() -> void:
	await spawn_debug_scene()
	put_player_at(boss_tiles() - Vector2(1.5, 0))
	BossValues.set_hp(_boss.logic, 150)
	await run_ticks(30)
	assert_eq(_boss.logic.get_stage_index(), 1)
	assert_eq(boss_state(), EnemyLogic.State.STAGE_SHIFT)
	_runner.reset()
	assert_eq(_boss.logic.get_combat_state().get_hp(), 400)
	assert_eq(_boss.logic.get_stage_index(), 0)
	assert_eq(_boss.logic.get_stage_shift_left(), 0.0)
	assert_eq(boss_state(), EnemyLogic.State.IDLE)
	assert_null(_boss.logic.get_running_attack())
	assert_eq(_boss.logic.get_current_attacks()[0].id, &"warden_swipe_a")


## Runs until the Warden is in the recovery of `attack_id`. Returns whether it got there.
func _run_to_recovery_of(attack_id: StringName) -> bool:
	return await run_until(
		func() -> bool:
			var attack: EnemyAttackData = _boss.logic.get_running_attack()
			return (
				boss_state() == EnemyLogic.State.RECOVERY
				and attack != null
				and attack.id == attack_id
			)
	)


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
