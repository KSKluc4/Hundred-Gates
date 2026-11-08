extends GutTest
## F-005 AC21 (C10) and AC22's core half (C11): snapshots, latching, and the rate checks.

const RESUMED_TICKS: int = 60
const TIME: float = EnemyArena.TIME
const START: Vector2 = Vector2(0, 6.52)


func test_ac21_mid_windup_before_the_lock() -> void:
	var caster: Dictionary = _assert_resumes(_run_a.bind(30))
	assert_eq(caster["state"], EnemyLogic.State.WINDUP)
	assert_false(caster["aim_locked"])


func test_ac21_mid_windup_after_the_lock() -> void:
	var caster: Dictionary = _assert_resumes(_run_a.bind(60))
	assert_eq(caster["state"], EnemyLogic.State.WINDUP)
	assert_true(caster["aim_locked"])


func test_ac21_in_recovery_with_one_projectile_in_flight() -> void:
	var caster: Dictionary = _assert_resumes(_run_a.bind(100))
	assert_eq(caster["state"], EnemyLogic.State.RECOVERY)
	assert_eq(caster["projectiles"].size(), 1)
	assert_false(caster["projectiles"][0]["spent"])
	assert_eq(caster["next_projectile_serial"], 1)


func test_ac21_with_a_spent_projectile_not_yet_removed() -> void:
	var caster: Dictionary = _assert_resumes(_walled.bind(143), _walled.bind(0))
	assert_eq(caster["projectiles"].size(), 1)
	assert_true(caster["projectiles"][0]["spent"])


func test_ac21_with_two_projectiles_in_flight() -> void:
	var caster: Dictionary = _assert_resumes(_quick.bind(196), _quick.bind(0))
	assert_eq(caster["projectiles"].size(), 2)
	assert_eq(caster["projectiles"][0]["serial"], 0)
	assert_eq(caster["projectiles"][1]["serial"], 1)
	assert_eq(caster["next_projectile_serial"], 2)


func test_ac21_after_a_projectile_landed() -> void:
	var caster: Dictionary = _assert_resumes(_run_a.bind(191))
	assert_eq(caster["projectiles"].size(), 1, "landed, not yet removed")
	assert_eq_deep(caster["projectiles"][0]["hit_ids"], [&"player_1"])


func test_ac21_dead() -> void:
	var caster: Dictionary = _assert_resumes(_killed, _fragile)
	assert_eq(caster["state"], EnemyLogic.State.DEAD)
	assert_eq(caster["projectiles"].size(), 0)


func test_c10_a_chaser_carries_an_empty_list_and_zero() -> void:
	var arena: CasterArena = CasterArena.new()
	arena.add_player()
	var chaser: EnemyLogic = arena.add_chaser(Vector2(0, 3))
	arena.ticks(130)
	assert_eq(chaser.to_dict()["projectiles"].size(), 0)
	assert_eq(chaser.to_dict()["next_projectile_serial"], 0)


func test_c10_a_snapshot_without_the_projectile_keys_is_rejected() -> void:
	var caster: EnemyLogic = _run_a(100).enemies[0]
	var before: Dictionary = caster.to_dict()
	var broken: Dictionary = before.duplicate()
	broken.erase("projectiles")
	broken["position"] = Vector2(9, 9)
	caster.from_dict(broken)
	assert_push_error("snapshot rejected")
	assert_eq_deep(caster.to_dict(), before)


func test_c4_setup_resets_projectiles_and_serials() -> void:
	var arena: CasterArena = _run_a(100)
	var caster: EnemyLogic = arena.enemies[0]
	assert_true(caster.setup(arena.caster_data, arena.enemy_rules, 120, START, &"caster_1"))
	assert_eq(caster.get_projectiles().get_projectiles().size(), 0)
	assert_eq(caster.get_projectiles().get_next_serial(), 0)


func test_ac22_a_projectile_in_flight_keeps_its_latched_values() -> void:
	var arena: CasterArena = CasterArena.new()
	arena.caster_data.attack_cooldown = 0.0
	var player: PlayerMotor = arena.add_player()
	var caster: EnemyLogic = arena.add_caster(Vector2(0, 6.0))
	var watch: CasterWatch = arena.watch_caster(caster)
	var damage: Array[int] = []
	player.get_combat_state().damaged.connect(func(e: HitEvent) -> void: damage.append(e.damage))
	arena.ticks(100)  # Projectile 0 in flight, the caster in recovery.
	var faster: EnemyData = CasterArena.caster_values()
	faster.attack_cooldown = 0.0
	faster.attack.projectile_speed_tiles = 12.0
	faster.attack.damage = 25
	assert_true(caster.apply_data(faster, arena.enemy_rules, 120))
	arena.ticks(300)
	assert_eq(damage, [18, 25] as Array[int], "latched 18, then the new 25")
	var first: Vector2 = watch.projectile_at(100)["position"]
	var later: Vector2 = watch.projectile_at(101)["position"]
	assert_almost_eq(first.y - later.y, 6.0 / 120.0, TIME, "still at its latched 6 tiles/s")
	var launch: int = watch.seen_at[1][0]
	var second_step: float = (
		watch.projectile_at(launch, 1)["position"].y
		- watch.projectile_at(launch + 1, 1)["position"].y
	)
	assert_almost_eq(second_step, 12.0 / 120.0, TIME, "the next uses 12")


func test_ac22_a_latched_windup_launches_with_its_latched_values() -> void:
	var arena: CasterArena = CasterArena.new()
	var player: PlayerMotor = arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	arena.ticks(30)
	var other: EnemyData = CasterArena.caster_values()
	other.attack.damage = 25
	other.attack.projectile_speed_tiles = 12.0
	assert_true(caster.apply_data(other, arena.enemy_rules, 120))
	arena.ticks(50)
	assert_eq(caster.get_projectiles().get_projectiles()[0].speed, 6.0)
	assert_eq(caster.get_projectiles().get_projectiles()[0].damage, 18)
	arena.ticks(120)
	assert_eq(player.get_combat_state().get_hp(), 82)


func test_ac22_invalid_caster_or_bolt_values_change_nothing() -> void:
	var edits: Array[Callable] = [
		func(d: EnemyData) -> void: d.retreat_distance_tiles = 6.5,
		func(d: EnemyData) -> void: d.attack.projectile_max_distance_tiles = 0.0,
		func(d: EnemyData) -> void: d.attack.projectile_speed_tiles = 31.0,
		func(d: EnemyData) -> void: d.attack.arc_angle_deg = 90.0,
	]
	for edit: Callable in edits:
		var arena: CasterArena = _run_a(100)
		var caster: EnemyLogic = arena.enemies[0]
		var bad: EnemyData = CasterArena.caster_values()
		edit.call(bad)
		assert_false(caster.apply_data(bad, arena.enemy_rules, 120))
		assert_push_error("data rejected")
		assert_eq(caster.get_data(), arena.caster_data)


func test_ac22_a_rate_a_projectile_in_flight_cant_take_is_refused_and_names_it() -> void:
	var arena: CasterArena = _at_240()
	var caster: EnemyLogic = arena.enemies[0]
	assert_eq(arena.sim.rate_change_errors(120).size(), 0, "nothing latched yet")
	arena.ticks(40)  # Launched at 0.3 s: in flight at 1/3 s.
	assert_eq(caster.get_state(), EnemyLogic.State.ACTIVE, "no pending projectile, then")
	var window: PackedFloat64Array = PackedFloat64Array([0.3, 0.1])
	assert_eq(CombatTiming.window_errors(window[0], window[1], 120).size(), 0, "nor a window")
	assert_false(caster.get_projectiles().get_projectiles()[0].spent)
	var errors: PackedStringArray = arena.sim.rate_change_errors(120)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "caster_7")
	assert_string_contains(errors[0], "projectile 0")
	assert_eq(arena.sim.rate_change_errors(240).size(), 0)
	assert_eq(arena.sim.rate_change_errors(480).size(), 0, "raising the rate always passes")


func test_ac22_a_pending_launch_refuses_the_rate_and_launches_at_its_latched_speed() -> void:
	var arena: CasterArena = _at_240()
	var caster: EnemyLogic = arena.enemies[0]
	arena.ticks(10)
	assert_eq(caster.get_state(), EnemyLogic.State.WINDUP)
	assert_eq(caster.get_projectiles().get_projectiles().size(), 0, "not launched yet")
	var candidate: EnemyData = arena.caster_data.duplicate()
	candidate.attack = candidate.attack.duplicate()
	candidate.attack.projectile_speed_tiles = 30.0
	assert_eq(candidate.validate(120, arena.enemy_rules).size(), 0, "valid on its own at 120")
	var errors: PackedStringArray = arena.sim.rate_change_errors(120)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "caster_7")
	assert_string_contains(errors[0], "pending projectile of caster_bolt")
	assert_eq(arena.sim.get_step_rate(), 240, "a refused reload changes nothing")
	arena.ticks(30)
	assert_eq(caster.get_projectiles().get_projectiles()[0].speed, 60.0)


## 240 steps/s, bolt speed 60 and radius 0.25: exactly at the limit. A short windup, so the
## projectile launches at 0.3 s. It reaches the player at about 0.415 s.
func _at_240() -> CasterArena:
	var arena: CasterArena = CasterArena.new()
	arena.rules.combat_step_rate = 240
	arena.caster_data.attack.projectile_speed_tiles = 60.0
	arena.caster_data.attack.windup = 0.3
	arena.caster_data.attack.aim_track_time = 0.1
	arena.caster_data.attack_range_tiles = 7.9
	arena.add_player()
	arena.add_caster(Vector2(0, 7.5), &"caster_7")
	return arena


## Returns the caster's snapshot, so each test can prove it caught the moment it names.
func _assert_resumes(prepare: Callable, build: Callable = _fight) -> Dictionary:
	var unbroken: CasterArena = prepare.call()
	var snapshot: Dictionary = unbroken.sim.to_dict()
	var fresh: CasterArena = build.call()
	assert_true(fresh.sim.from_dict(snapshot))
	assert_eq_deep(fresh.sim.to_dict(), snapshot)
	for index: int in RESUMED_TICKS:
		unbroken.ticks(1)
		fresh.ticks(1)
		assert_eq_deep(fresh.sim.to_dict(), unbroken.sim.to_dict())
	return snapshot["combatants"][&"caster_1"]


func _fight() -> CasterArena:
	var arena: CasterArena = CasterArena.new()
	arena.add_player()
	arena.add_caster(START)
	return arena


func _run_a(ticks: int) -> CasterArena:
	var arena: CasterArena = _fight()
	arena.ticks(ticks)
	return arena


## AC19's fake wall at y = 3, as a move_bodies callable on both runs.
func _walled(ticks: int) -> CasterArena:
	var arena: CasterArena = _fight()
	var caster: EnemyLogic = arena.enemies[0]
	arena.move_bodies = func() -> void:
		var projectiles: ProjectileSet = caster.get_projectiles()
		for projectile: ProjectileSet.Projectile in projectiles.get_projectiles():
			projectiles.report_position(
				projectile.serial, Vector2(projectile.position.x, maxf(projectile.position.y, 3.0))
			)
	arena.ticks(ticks)
	return arena


## A short recovery and no cooldown: the second launch (1.6 s) comes before the first lands.
func _quick(ticks: int) -> CasterArena:
	var arena: CasterArena = CasterArena.new()
	arena.caster_data.attack_cooldown = 0.0
	arena.caster_data.attack.recovery = 0.3
	arena.add_player()
	arena.add_caster(Vector2(0, 6.9))
	arena.ticks(ticks)
	return arena


func _fragile() -> CasterArena:
	var arena: CasterArena = CasterArena.new()
	arena.caster_data.max_hp = 1
	arena.add_player()
	arena.add_caster(Vector2(0, 1.2))
	return arena


func _killed() -> CasterArena:
	var arena: CasterArena = _fragile()
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(20)
	return arena
