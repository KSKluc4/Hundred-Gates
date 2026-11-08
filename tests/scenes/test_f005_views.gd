extends F005SceneTest
## F-005 AC24 (views derived from logic, C12) and AC25 (I, R and F5 on casters).

const ORACLE_STEPS_PER_TICK: int = 2  # 120 steps/s at the default 60 ticks/s.


func test_ac24_the_aim_line_tracks_then_locks() -> void:
	await spawn_fresh(place_oracle)
	var caster: Enemy = _casters[0]
	await run_ticks(10)  # 0.17 s: tracking.
	assert_eq(caster.get_telegraph(), Enemy.Telegraph.TRACKING)
	_assert_aim_line(caster)
	await run_ticks(15)  # 0.42 s: past the 0.35 lock.
	assert_eq(caster.get_telegraph(), Enemy.Telegraph.LOCKED)
	_assert_aim_line(caster)
	await run_ticks(12)  # 0.62 s: launched, the line is gone.
	assert_eq(caster.get_aim_line().size(), 0)


func test_ac24_each_bolt_is_a_circle_of_its_radius_at_its_logic_position() -> void:
	await spawn_fresh(place_oracle)
	var caster: Enemy = _casters[0]
	assert_eq(caster.get_bolts_px().size(), 0)
	for ticks: int in [40, 10, 20]:
		await run_ticks(ticks)
		var projectile: ProjectileSet.Projectile = (
			caster.logic.get_projectiles().get_projectiles()[0]
		)
		var bolts: PackedVector3Array = caster.get_bolts_px()
		assert_eq(bolts.size(), 1)
		var centre: Vector2 = Units.vector_tiles_to_px(projectile.position)
		assert_eq(Vector2(bolts[0].x, bolts[0].y), centre)
		assert_eq(bolts[0].z, Units.tiles_to_px(0.25))


func test_ac24_recovery_is_tinted_open() -> void:
	await spawn_fresh(place_oracle)
	var caster: Enemy = _casters[0]
	assert_eq(caster.get_body_color(), caster.body_color)
	await run_ticks(50)  # 0.83 s: recovery.
	assert_eq(caster.logic.get_state(), EnemyLogic.State.RECOVERY)
	assert_eq(caster.get_body_color(), caster.open_color)
	assert_eq(caster.get_telegraph(), Enemy.Telegraph.NONE)


func test_ac24_the_f3_overlay_draws_projectile_hitboxes() -> void:
	await spawn_fresh(place_oracle)
	var caster: Enemy = _casters[0]
	await run_ticks(20)
	assert_eq(_debug_draw.get_live_hitboxes().size(), 0, "no sector on the caster's body")
	await run_ticks(30)
	var hitboxes: Array[Hitbox] = _debug_draw.get_live_hitboxes()
	assert_eq(hitboxes.size(), 1, "the bolt's")
	var projectile: ProjectileSet.Projectile = caster.logic.get_projectiles().get_projectiles()[0]
	assert_eq(hitboxes[0].origin, projectile.position)
	assert_eq(hitboxes[0].arc_angle_deg, 360.0)
	assert_eq(hitboxes[0].range_tiles, 0.25)


func test_ac24_a_melee_attack_draws_no_aim_line() -> void:
	await spawn_fresh(_place_chaser_in_range)
	await run_ticks(10)
	assert_eq(_chaser.logic.get_state(), EnemyLogic.State.WINDUP)
	assert_eq(_chaser.get_aim_line().size(), 0)


func test_ac24_after_a_restore_no_stale_line_or_bolt() -> void:
	await spawn_fresh(place_oracle)
	var caster: Enemy = _casters[0]
	var before_any: Dictionary = _runner.take_snapshot()
	await run_ticks(10)
	var tracking: Dictionary = _runner.take_snapshot()
	await run_ticks(40)  # A bolt in flight.
	var in_flight: Dictionary = _runner.take_snapshot()
	var flying_at: Vector2 = Vector2(caster.get_bolts_px()[0].x, caster.get_bolts_px()[0].y)
	assert_true(_runner.restore_snapshot(tracking))
	assert_eq(caster.get_bolts_px().size(), 0, "no stale bolt")
	assert_eq(caster.get_telegraph(), Enemy.Telegraph.TRACKING)
	_assert_aim_line(caster)
	assert_true(_runner.restore_snapshot(in_flight))
	assert_eq(caster.get_aim_line().size(), 0, "no stale line")
	assert_eq(Vector2(caster.get_bolts_px()[0].x, caster.get_bolts_px()[0].y), flying_at)
	assert_true(_runner.restore_snapshot(before_any))
	assert_eq(caster.get_bolts_px().size(), 0)
	assert_eq(caster.get_aim_line().size(), 0)


func test_ac25_i_toggles_ai_for_casters_too_and_an_aggroed_caster_holds_fire() -> void:
	await spawn_fresh(place_oracle)
	assert_true(_runner.is_ai_on())
	press_key(KEY_I)  # Before its first step: a windup it had started would still finish (C4).
	for enemy: Enemy in [_casters[0], _casters[1], _chaser]:
		assert_false(enemy.logic.is_ai_enabled(), String(enemy.combat_id))
	assert_string_contains(await overlay_text(), "ai: off")
	var start: Vector2 = _casters[0].global_position
	await run_ticks(120)
	assert_eq(_casters[0].global_position, start)
	assert_eq(_casters[0].logic.get_state(), EnemyLogic.State.IDLE)
	assert_eq(_casters[0].logic.get_projectiles().get_next_serial(), 0, "never shot")
	press_key(KEY_I)
	for enemy: Enemy in [_casters[0], _casters[1], _chaser]:
		assert_true(enemy.logic.is_ai_enabled(), String(enemy.combat_id))


func test_ac25_r_removes_every_projectile_and_gives_a_fresh_setup() -> void:
	await spawn_fresh(place_oracle)
	var fresh: Dictionary = _runner.take_snapshot()
	await run_ticks(50)
	assert_eq(_casters[0].logic.get_projectiles().get_projectiles().size(), 1, "one flying")
	press_key(KEY_I)
	press_key(KEY_R)
	var after: Dictionary = _runner.take_snapshot()
	for enemy: Enemy in _casters:
		assert_false(enemy.logic.is_ai_enabled(), "the AI setting survives")
		assert_eq(enemy.logic.get_projectiles().get_projectiles().size(), 0)
		assert_eq(enemy.get_bolts_px().size(), 0)
		assert_eq(enemy.get_aim_line().size(), 0)
		assert_eq(enemy.global_position, enemy.logic.get_position_px())
	_forget_ai(fresh)
	_forget_ai(after)
	fresh["time"] = 0.0
	after["time"] = 0.0
	assert_eq_deep(after, fresh)


func test_ac25_f5_reloads_in_this_scene() -> void:
	await spawn_fresh()
	press_key(KEY_F5)
	assert_string_contains(await overlay_text(), "reload: ok")
	assert_eq(_casters[0].logic.get_data().id, &"caster")


func test_ac25_the_scene_matches_t9() -> void:
	await spawn()
	assert_eq(_runner.get_setup_errors().size(), 0)
	var ids: Array[StringName] = []
	for combatant: Combatant in _runner.get_sim().get_combatants():
		ids.append(combatant.get_combat_id())
	assert_eq(ids, [&"player_1", &"caster_1", &"caster_2", &"chaser_1"] as Array[StringName])
	assert_true(_runner.refill_player_on_died)
	var distance: float = _player.global_position.distance_to(_casters[0].global_position)
	assert_almost_eq(Units.px_to_tiles(distance), 6.0, 0.5, "caster_1 about 6 tiles away")
	var pillar: Node2D = _scene.get_node("World/Pillar")
	var shape: RectangleShape2D = (pillar.get_node("CollisionShape2D") as CollisionShape2D).shape
	assert_eq(shape.size, Vector2(32, 32), "a 2x2-tile pillar")
	var space: PhysicsDirectSpaceState2D = _player.get_world_2d().direct_space_state
	var to_caster_2: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		_player.global_position, _casters[1].global_position, 1
	)
	assert_eq(space.intersect_ray(to_caster_2).get("collider"), pillar, "caster_2 is behind it")
	var to_caster_1: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		_player.global_position, _casters[0].global_position, 1
	)
	assert_true(space.intersect_ray(to_caster_1).is_empty(), "caster_1 has a clear line")


func _assert_aim_line(caster: Enemy) -> void:
	var line: PackedVector2Array = caster.get_aim_line()
	assert_eq(line.size(), 2)
	assert_eq(line[0], caster.logic.get_position_px(), "from the caster")
	var length: float = Units.px_to_tiles(line[0].distance_to(line[1]))
	assert_almost_eq(length, 10.0, TIME, "projectile_max_distance_tiles long")
	assert_almost_eq((line[1] - line[0]).normalized().dot(caster.logic.get_aim()), 1.0, TIME)


func _place_chaser_in_range() -> void:
	_player.position = CENTRE
	_chaser.position = CENTRE + Vector2(0, 20)
	_casters[0].position = FAR_WEST
	_casters[1].position = FAR_EAST


func _forget_ai(snapshot: Dictionary) -> void:
	var entries: Dictionary = snapshot["combatants"]
	for id: StringName in [&"caster_1", &"caster_2", &"chaser_1"]:
		(entries[id] as Dictionary).erase("ai_enabled")
