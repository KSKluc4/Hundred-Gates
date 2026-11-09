extends GutTest
## AC19 and the core half of AC20: snapshots, latching, and the rate check.

const RESUMED_TICKS: int = 60
const STEP: float = EnemyArena.STEP
const TIME: float = EnemyArena.TIME


func test_ac19_mid_windup_before_the_lock() -> void:
	var enemy_state: Dictionary = _assert_resumes(_run_a.bind(70))
	assert_eq(enemy_state["state"], EnemyLogic.State.WINDUP)
	assert_false(enemy_state["aim_locked"])


func test_ac19_mid_windup_after_the_lock() -> void:
	var enemy_state: Dictionary = _assert_resumes(_run_a.bind(100))
	assert_eq(enemy_state["state"], EnemyLogic.State.WINDUP)
	assert_true(enemy_state["aim_locked"])


func test_ac19_mid_active_with_the_lunge_half_done() -> void:
	var enemy_state: Dictionary = _assert_resumes(_run_b.bind(122))
	assert_eq(enemy_state["state"], EnemyLogic.State.ACTIVE)
	assert_almost_eq(float(enemy_state["phase_elapsed"]), 0.05, TIME)


func test_ac19_mid_active_with_a_hit_already_in_its_set() -> void:
	var enemy_state: Dictionary = _assert_resumes(_run_a.bind(125))
	assert_eq(enemy_state["state"], EnemyLogic.State.ACTIVE)
	assert_eq_deep(enemy_state["hit_ids"], [&"player_1"])


func test_ac19_mid_recovery() -> void:
	var enemy_state: Dictionary = _assert_resumes(_run_b.bind(150))
	assert_eq(enemy_state["state"], EnemyLogic.State.RECOVERY)


func test_ac19_mid_cooldown() -> void:
	var enemy_state: Dictionary = _assert_resumes(_run_b.bind(250))
	assert_eq(enemy_state["state"], EnemyLogic.State.CHASE)
	assert_gt(float(enemy_state["cooldown_remaining"]), 0.0)


func test_ac19_in_hitstop() -> void:
	var enemy_state: Dictionary = _assert_resumes(_run_a.bind(119))
	assert_gt(float(enemy_state["combat"]["hitstop_remaining"]), 0.0)


func test_ac19_in_knockback() -> void:
	var enemy_state: Dictionary = _assert_resumes(_pushed, _untouched_pushed)
	assert_eq(enemy_state["state"], EnemyLogic.State.KNOCKBACK)
	assert_gt(float(enemy_state["combat"]["knockback_remaining"]), 0.0)


func test_ac19_dead() -> void:
	var enemy_state: Dictionary = _assert_resumes(_killed, _fragile)
	assert_eq(enemy_state["state"], EnemyLogic.State.DEAD)
	assert_eq(enemy_state["combat"]["hp"], 0)


func test_c6_ai_off_and_a_target_survive_a_restore() -> void:
	var arena: EnemyArena = _fight()
	arena.ticks(10)
	arena.enemies[0].set_ai_enabled(false)
	var snapshot: Dictionary = arena.sim.to_dict()
	var fresh: EnemyArena = _fight()
	assert_true(fresh.sim.from_dict(snapshot))
	assert_false(fresh.enemies[0].is_ai_enabled())
	assert_eq(fresh.enemies[0].get_target_id(), &"player_1")


func test_c6_a_restore_emits_state_restored() -> void:
	var arena: EnemyArena = _fight()
	var snapshot: Dictionary = arena.sim.to_dict()
	watch_signals(arena.enemies[0])
	arena.sim.from_dict(snapshot)
	assert_signal_emit_count(arena.enemies[0], "state_restored", 1)


func test_c6_a_snapshot_with_a_key_missing_is_rejected() -> void:
	var enemy: EnemyLogic = _fight().enemies[0]
	var before: Dictionary = enemy.to_dict()
	var broken: Dictionary = before.duplicate()
	broken.erase("aim_locked")
	broken["position"] = Vector2(9, 9)
	enemy.from_dict(broken)
	assert_push_error("snapshot rejected")
	assert_eq_deep(enemy.to_dict(), before)


func test_ac20_a_reload_mid_attack_finishes_on_latched_values_and_the_next_uses_the_new() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attack_cooldown = 0.1
	var player: PlayerMotor = arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	var watch: EnemyWatch = arena.watch(enemy)
	arena.ticks(10)
	var harder: EnemyData = EnemyArena.chaser_values()
	harder.attack_cooldown = 0.1
	harder.attacks[0].damage = 33
	harder.attacks[0].windup = 0.6
	harder.attacks[0].recovery = 0.2
	assert_true(enemy.apply_data(harder, arena.enemy_rules, 120))
	arena.ticks(61)
	_assert_steps(watch.times_entered(EnemyLogic.State.ACTIVE), [60])
	assert_eq(player.get_combat_state().get_hp(), 80, "the running swing keeps its 20")
	arena.ticks(200)
	_assert_steps(watch.times_entered(EnemyLogic.State.WINDUP), [0, 162])
	_assert_steps(watch.times_entered(EnemyLogic.State.ACTIVE), [60, 234])
	assert_eq(player.get_combat_state().get_hp(), 47, "the next one uses 33")


func test_ac20_invalid_data_changes_nothing() -> void:
	var arena: EnemyArena = _fight()
	var enemy: EnemyLogic = arena.enemies[0]
	var bad: EnemyData = EnemyArena.chaser_values()
	bad.attacks[0].windup = 0.1
	assert_false(enemy.apply_data(bad, arena.enemy_rules, 120))
	assert_push_error("data rejected")
	assert_eq(enemy.get_data(), arena.chaser_data)


func test_ac20_lowering_max_hp_clamps_it_and_raising_it_doesnt_heal() -> void:
	var arena: EnemyArena = _fight()
	var enemy: EnemyLogic = arena.enemies[0]
	var other: EnemyData = EnemyArena.chaser_values()
	other.max_hp = 30
	enemy.apply_data(other, arena.enemy_rules, 120)
	assert_eq(enemy.get_combat_state().get_hp(), 30)
	other = EnemyArena.chaser_values()
	other.max_hp = 90
	enemy.apply_data(other, arena.enemy_rules, 120)
	assert_eq(enemy.get_combat_state().get_hp(), 30)
	assert_eq(enemy.get_combat_state().get_max_hp(), 90)


func test_c12_a_reload_keeps_a_running_cooldown_and_moves_from_the_next_step_start() -> void:
	var arena: EnemyArena = _fight()
	var enemy: EnemyLogic = arena.enemies[0]
	arena.ticks(5)
	enemy._cooldown_remaining = 0.5
	var before: Vector2 = enemy.get_position_tiles()
	var faster: EnemyData = EnemyArena.chaser_values()
	faster.move_speed = 4.8
	faster.attack_cooldown = 5.0
	enemy.apply_data(faster, arena.enemy_rules, 120)
	assert_eq(enemy.get_cooldown_remaining(), 0.5, "kept")
	arena.ticks(1)
	assert_almost_eq(before.y - enemy.get_position_tiles().y, 0.04, 0.000001)
	assert_almost_eq(enemy.get_cooldown_remaining(), 0.5 - STEP, TIME)


func test_c12_new_telegraph_rules_never_recheck_a_running_attack() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	arena.ticks(10)
	var stricter: EnemyCombatTunables = arena.enemy_rules.duplicate()
	stricter.min_telegraph = 0.55
	var fitting: EnemyData = EnemyArena.chaser_values()
	fitting.attacks[0].windup = 0.6
	assert_true(enemy.apply_data(fitting, stricter, 120))
	arena.ticks(51)
	assert_eq(enemy.get_state(), EnemyLogic.State.ACTIVE, "0.5 s of windup still runs")


func test_ac20_a_rate_that_would_break_a_running_window_is_refused_and_names_it() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.rules.combat_step_rate = 240
	arena.chaser_data.attacks[0].active = 1.0 / 240.0
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 3), &"chaser_7")
	assert_eq(enemy.get_running_window_errors(120).size(), 0, "nothing running yet")
	arena.ticks(60)
	assert_eq(enemy.get_state(), EnemyLogic.State.WINDUP)
	var errors: PackedStringArray = arena.sim.rate_change_errors(120)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "chaser_7")


func test_ac20_the_same_rate_passes_once_the_attack_is_in_recovery() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.rules.combat_step_rate = 240
	arena.chaser_data.attacks[0].active = 1.0 / 240.0
	arena.chaser_data.attacks[0].range_tiles = 0.01
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.6))
	arena.ticks(62)
	assert_eq(enemy.get_state(), EnemyLogic.State.RECOVERY)
	assert_eq(arena.sim.rate_change_errors(120).size(), 0)


## Returns the enemy's snapshot, so each test can prove it caught the moment it names.
func _assert_resumes(prepare: Callable, build: Callable = _fight) -> Dictionary:
	var unbroken: EnemyArena = prepare.call()
	var snapshot: Dictionary = unbroken.sim.to_dict()
	var fresh: EnemyArena = build.call()
	assert_true(fresh.sim.from_dict(snapshot))
	assert_eq_deep(fresh.sim.to_dict(), snapshot)
	for index: int in RESUMED_TICKS:
		unbroken.ticks(1)
		fresh.ticks(1)
		assert_eq_deep(fresh.sim.to_dict(), unbroken.sim.to_dict())
	return snapshot["combatants"][&"chaser_1"]


func _fight() -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player()
	arena.add_chaser(Vector2(0, 3))
	return arena


func _fragile() -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.max_hp = 1
	arena.add_player()
	arena.add_chaser(Vector2(0, 1.95))
	return arena


func _run_a(ticks: int) -> EnemyArena:
	var arena: EnemyArena = _fight()
	arena.ticks(ticks)
	return arena


## AC17's dash, so the swing misses.
func _run_b(ticks: int) -> EnemyArena:
	var arena: EnemyArena = _fight()
	arena.ticks(96)
	arena.tick(120, Vector2.RIGHT, true)
	arena.ticks(ticks - 97)
	return arena


func _untouched_pushed() -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data.attacks[0].trigger_max_tiles = 0.01
	arena.add_player()
	arena.add_chaser(Vector2(0, 1.95))
	return arena


func _pushed() -> EnemyArena:
	var arena: EnemyArena = _untouched_pushed()
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(19)
	return arena


func _killed() -> EnemyArena:
	var arena: EnemyArena = _fragile()
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(11)
	return arena


func _assert_steps(actual: Array, expected_steps: Array) -> void:
	assert_eq(actual.size(), expected_steps.size(), str(actual))
	for index: int in mini(actual.size(), expected_steps.size()):
		assert_almost_eq(float(actual[index]), expected_steps[index] / 120.0, TIME)
