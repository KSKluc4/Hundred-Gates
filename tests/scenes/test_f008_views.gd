extends F008SceneTest
## F-008 T5: Enemy.get_aim_lines() (C11, AC16): one line per bolt during a projectile
## attack's windup, get_aim_line() the first, nothing outside a windup.


func test_ac16_a_fan_shows_three_lines_in_list_order_while_tracking_and_locked() -> void:
	await build(volley_caster(FAN), Vector2(0, 5.0))
	assert_true(await run_until(func() -> bool: return enemy_state() == EnemyLogic.State.WINDUP))
	assert_false(_enemy.logic.is_aim_locked())
	assert_volley_lines(_enemy, "tracking")
	assert_true(await run_until(func() -> bool: return _enemy.logic.is_aim_locked()))
	assert_eq(enemy_state(), EnemyLogic.State.WINDUP)
	assert_volley_lines(_enemy, "locked")
	var lines: Array[PackedVector2Array] = _enemy.get_aim_lines()
	var aim: Vector2 = _enemy.logic.get_aim()
	var middle: Vector2 = (lines[1][1] - lines[1][0]).normalized()
	assert_almost_eq(middle, aim, Vector2.ONE * 1e-6, "entry 0 is the middle line, on the aim")
	var first: Vector2 = (lines[0][1] - lines[0][0]).normalized()
	assert_almost_eq(first, aim.rotated(deg_to_rad(-20.0)), Vector2.ONE * 1e-6, "-20 first")


func test_ac16_outside_a_windup_both_are_empty() -> void:
	await build(volley_caster(FAN), Vector2(0, 5.0))
	assert_eq(_enemy.get_aim_lines().size(), 0, "idle")
	assert_eq(_enemy.get_aim_line().size(), 0, "idle")
	assert_true(await run_until(func() -> bool: return enemy_state() == EnemyLogic.State.ACTIVE))
	assert_eq(_enemy.get_aim_lines().size(), 0, "active")
	assert_eq(_enemy.get_aim_line().size(), 0, "active")
	assert_eq(_enemy.get_bolts_px().size(), 3, "three bolts drawn instead")
	assert_true(await run_until(func() -> bool: return enemy_state() == EnemyLogic.State.RECOVERY))
	assert_eq(_enemy.get_aim_lines().size(), 0, "recovery")


func test_ac16_a_single_bolt_shows_one_line_as_before() -> void:
	await build(volley_caster([]), Vector2(0, 5.0))
	assert_true(await run_until(func() -> bool: return enemy_state() == EnemyLogic.State.WINDUP))
	assert_volley_lines(_enemy, "one bolt")
	assert_eq(_enemy.get_aim_lines().size(), 1)


func test_ac16_the_hexer_ring_shows_twelve_lines() -> void:
	await build(load(Tunables.HEXER_PATH), Vector2(0, 2.0))
	BossValues.set_hp(_enemy.logic, 160)  # Stage 2: nova, then the ring.
	var in_ring: Callable = func() -> bool:
		var attack: EnemyAttackData = _enemy.logic.get_running_attack()
		return attack != null and attack.id == &"hexer_ring"
	assert_true(await run_until(in_ring, 900))
	assert_eq(enemy_state(), EnemyLogic.State.WINDUP)
	assert_volley_lines(_enemy, "ring")
	assert_eq(_enemy.get_aim_lines().size(), 12)


func test_ac16_a_melee_attack_without_a_lane_has_no_lines() -> void:
	await build(load(Tunables.HEXER_PATH), Vector2(0, 2.0))
	assert_true(await run_until(func() -> bool: return enemy_state() == EnemyLogic.State.WINDUP))
	assert_eq(_enemy.logic.get_running_attack().id, &"hexer_nova")
	assert_eq(_enemy.get_aim_lines().size(), 0)
	assert_eq(_enemy.get_aim_line().size(), 0)
