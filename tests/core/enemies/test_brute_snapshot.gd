extends GutTest
## F-006 AC13 (C10) and the C11 rate refusal (AC15): snapshots and latching of the brute.

const RESUMED_TICKS: int = 240
const CHARGE: int = BruteArena.CHARGE
const WALL: float = 2.97


func test_ac13_mid_charge_windup() -> void:
	var brute: Dictionary = _assert_resumes(_walled.bind(60), _walled.bind(0))
	assert_eq(brute["state"], EnemyLogic.State.WINDUP)
	assert_eq(brute["attack"]["wall_stun_duration"], 1.5)
	assert_eq(brute["attack"]["trigger_min_tiles"], 3.0)
	assert_eq(brute["attack"]["trigger_max_tiles"], 7.0)


func test_ac13_mid_charge_lunge() -> void:
	var brute: Dictionary = _assert_resumes(_walled.bind(110), _walled.bind(0))
	assert_eq(brute["state"], EnemyLogic.State.ACTIVE)
	assert_false(brute["wall_stopped"])


func test_ac13_mid_stun() -> void:
	var brute: Dictionary = _assert_resumes(_walled.bind(200), _walled.bind(0))
	assert_eq(brute["state"], EnemyLogic.State.RECOVERY)
	assert_true(brute["wall_stopped"])


func test_ac13_mid_stomp() -> void:
	var brute: Dictionary = _assert_resumes(_hugged.bind(40), _hugged.bind(0))
	assert_eq(brute["state"], EnemyLogic.State.WINDUP)
	assert_eq(brute["attack"]["id"], &"brute_stomp")
	assert_eq(brute["attack"]["wall_stun_duration"], 0.0)


func test_c10_a_restore_with_another_wall_stopped_value_takes_it() -> void:
	var arena: BruteArena = _walled(110)
	var brute: EnemyLogic = arena.enemies[0]
	var snapshot: Dictionary = brute.to_dict()
	snapshot["state"] = EnemyLogic.State.RECOVERY
	snapshot["phase_elapsed"] = 0.0
	snapshot["wall_stopped"] = true
	brute.from_dict(snapshot)
	assert_true(brute.is_wall_stopped())
	assert_true(brute.get_charge_segment().is_empty(), "from_dict() clears the segment")
	arena.ticks(179)
	assert_eq(brute.get_state(), EnemyLogic.State.RECOVERY, "1.5 s of stun, not 0.9")
	arena.ticks(1)
	assert_ne(brute.get_state(), EnemyLogic.State.RECOVERY)


func test_c10_a_snapshot_without_wall_stopped_is_rejected() -> void:
	var brute: EnemyLogic = _walled(110).enemies[0]
	var before: Dictionary = brute.to_dict()
	var broken: Dictionary = before.duplicate()
	broken.erase("wall_stopped")
	broken["position"] = Vector2(9, 9)
	brute.from_dict(broken)
	assert_push_error("snapshot rejected")
	assert_eq_deep(brute.to_dict(), before)


func test_c10_setup_clears_the_stun() -> void:
	var arena: BruteArena = _walled(200)
	var brute: EnemyLogic = arena.enemies[0]
	assert_true(brute.is_wall_stopped())
	assert_true(brute.setup(arena.brute_data, arena.enemy_rules, 120, Vector2.ZERO, &"brute_1"))
	assert_false(brute.is_wall_stopped())
	assert_eq(brute.get_state(), EnemyLogic.State.IDLE)


func test_c11_a_running_charge_keeps_its_latched_stun_through_a_reload() -> void:
	var arena: BruteArena = _walled(60)
	var brute: EnemyLogic = arena.enemies[0]
	var edited: EnemyData = BruteArena.brute_values()
	edited.attacks[CHARGE].wall_stun_duration = 3.0
	edited.attacks[CHARGE].recovery = 0.5
	assert_true(brute.apply_data(edited, arena.enemy_rules, 120))
	arena.ticks(140)  # The stop is at 1.05 s, so 1.5 s of stun ends at 2.55 s (306 ticks).
	assert_true(brute.is_wall_stopped())
	arena.ticks(105)
	assert_eq(brute.get_state(), EnemyLogic.State.RECOVERY, "2.54 s: latched 1.5 s, not 3.0")
	assert_true(brute.is_wall_stopped(), "the flag survives the reload too")
	arena.ticks(2)
	assert_ne(brute.get_state(), EnemyLogic.State.RECOVERY)
	assert_eq(brute.get_cooldown_remaining() > 0.0, true)


func test_ac15_lowering_the_rate_is_refused_while_a_short_recovery_charge_runs() -> void:
	var arena: BruteArena = _at_240()
	var brute: EnemyLogic = arena.enemies[0]
	arena.ticks(10)
	assert_eq(brute.get_state(), EnemyLogic.State.WINDUP)
	var errors: PackedStringArray = arena.sim.rate_change_errors(120)
	assert_eq(errors.size(), 1, str(errors))
	assert_string_contains(errors[0], "brute_1")
	assert_string_contains(errors[0], "brute_charge recovery must be >= 2 combat steps")
	assert_eq(arena.sim.rate_change_errors(240), PackedStringArray(), "the same rate passes")
	assert_eq(arena.sim.rate_change_errors(480), PackedStringArray(), "raising passes")
	while brute.get_state() != EnemyLogic.State.ACTIVE:
		arena.ticks(1)
	assert_eq(arena.sim.rate_change_errors(120).size(), 1, "refused in ACTIVE too")
	while brute.get_state() == EnemyLogic.State.ACTIVE:
		arena.ticks(1)
	assert_eq(brute.get_state(), EnemyLogic.State.RECOVERY)
	assert_eq(arena.sim.rate_change_errors(120), PackedStringArray(), "recovery already runs")


func test_ac15_a_stomp_never_refuses_the_rate() -> void:
	var arena: BruteArena = BruteArena.new()
	arena.rules.combat_step_rate = 240
	arena.brute_data.attacks[BruteArena.STOMP].recovery = 1.0 / 240.0
	arena.add_player()
	var brute: EnemyLogic = arena.add_brute(Vector2(0, 1.0))
	arena.ticks(10)
	assert_eq(brute.get_running_attack().id, &"brute_stomp")
	assert_eq(arena.sim.rate_change_errors(120), PackedStringArray())


## Returns the brute's snapshot, so each test can prove it caught the moment it names.
func _assert_resumes(prepare: Callable, build: Callable) -> Dictionary:
	var unbroken: BruteArena = prepare.call()
	var snapshot: Dictionary = unbroken.sim.to_dict()
	var fresh: BruteArena = build.call()
	assert_true(fresh.sim.from_dict(snapshot))
	assert_eq_deep(fresh.sim.to_dict(), snapshot)
	for index: int in RESUMED_TICKS:
		unbroken.ticks(1)
		fresh.ticks(1)
		assert_eq_deep(fresh.sim.to_dict(), unbroken.sim.to_dict())
	assert_eq(
		fresh.hurt_times.size(), unbroken.hurt_times.size() - _hurt_before(unbroken, snapshot)
	)
	return snapshot["combatants"][&"brute_1"]


func _hurt_before(arena: BruteArena, snapshot: Dictionary) -> int:
	var count: int = 0
	for time: float in arena.hurt_times:
		if time <= snapshot["time"] + EnemyArena.TIME:
			count += 1
	return count


## A charge into a stub wall at x = 2.97, with the target out of reach beyond it.
func _walled(ticks: int) -> BruteArena:
	var arena: BruteArena = BruteArena.new()
	arena.add_player(Vector2(6.5, 0))
	var brute: EnemyLogic = arena.add_brute(Vector2.ZERO)
	BruteWallStub.new(brute, arena.sim, WALL).install(arena)
	arena.ticks(ticks)
	return arena


## A player 1 tile away: the stomp, which hits.
func _hugged(ticks: int) -> BruteArena:
	var arena: BruteArena = BruteArena.new()
	arena.add_player(Vector2(1.0, 0))
	var brute: EnemyLogic = arena.add_brute(Vector2.ZERO)
	BruteWallStub.new(brute, arena.sim).install(arena)
	arena.ticks(ticks)
	return arena


## A charge whose recovery is 2 steps at 240 steps/s, so 1 step at 120.
func _at_240() -> BruteArena:
	var arena: BruteArena = BruteArena.new()
	arena.rules.combat_step_rate = 240
	arena.brute_data.attacks[CHARGE].recovery = 2.0 / 240.0
	arena.add_player(Vector2(5.0, 0))
	arena.add_brute(Vector2.ZERO)
	return arena
