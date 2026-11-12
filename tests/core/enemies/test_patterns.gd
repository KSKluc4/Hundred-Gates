extends GutTest
## F-007 T2: follow-ups and patterns (C9-C12) and the gap getter (C20): AC7-AC11, on a real
## sim. The pattern is the chaser's swipe (windup 0.5, track 0.3, active 0.1, recovery 0.6)
## followed by a copy whose trigger band (5-6 tiles) never holds.

const TIME: float = EnemyArena.TIME
const NOT_A_RANGE: float = 0.01
const CHARGE: int = BruteArena.CHARGE
const STOMP: int = BruteArena.STOMP
## F-006's wall in front of a +x charge: the brute's centre stops at x = 2.97.
const WALL: float = 2.97


func test_ac7_the_follow_up_starts_the_instant_the_recovery_ends() -> void:
	var arena: EnemyArena = _pattern_arena()
	arena.add_player(Vector2(0, 1.0))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO)
	var watch: EnemyWatch = arena.watch(enemy)
	var cooldowns: Dictionary = {}
	arena.ticks(1)
	assert_eq(enemy.get_running_attack().id, &"root")
	assert_eq(enemy.get_pattern_root_index(), 0)
	assert_eq(enemy.get_pattern_depth(), 0)
	for _i: int in 300:
		arena.ticks(1)
		cooldowns[roundi(arena.sim.get_time() * 120.0)] = enemy.get_cooldown_remaining()
	_assert_times(watch.times_entered(EnemyLogic.State.WINDUP), [0.0, 1.2])
	_assert_times(watch.times_entered(EnemyLogic.State.ACTIVE), [0.5, 1.7])
	_assert_times(watch.times_entered(EnemyLogic.State.RECOVERY), [0.6, 1.8])
	_assert_times(watch.times_entered(EnemyLogic.State.IDLE), [0.0, 2.4])
	for chase: float in watch.times_entered(EnemyLogic.State.CHASE):
		assert_true(chase >= 2.4 - TIME, "never free in between")
	for step: int in range(2, 288):
		assert_eq(cooldowns[step], 0.0, "no cooldown inside the pattern (step %d)" % step)
	assert_almost_eq(float(cooldowns[288]), 0.8, TIME, "the cooldown starts at the pattern end")


func test_ac7_the_follow_up_ignores_its_trigger_band_and_is_read_from_the_data() -> void:
	var arena: EnemyArena = _pattern_arena()
	arena.add_player(Vector2(0, 1.0))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO)
	arena.ticks(145)
	assert_eq(enemy.get_state(), EnemyLogic.State.WINDUP)
	assert_eq(enemy.get_running_attack().id, &"next", "1 tile is outside its 5-6 band")
	assert_eq(enemy.get_pattern_root_index(), 0)
	assert_eq(enemy.get_pattern_depth(), 1)
	assert_null(enemy.get_running_attack().follow_up, "the latched copy holds no chain")


func test_ac8_the_follow_up_re_picks_the_nearest_living_player_then_tracks_and_locks() -> void:
	var arena: EnemyArena = _pattern_arena()
	var player_a: PlayerMotor = arena.add_player(Vector2(1.0, 0))
	var player_b: PlayerMotor = arena.add_player(Vector2(0, 8.0), &"player_2")
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO)
	arena.ticks(120)
	assert_eq(enemy.get_target_id(), &"player_1")
	assert_eq(enemy.get_aim(), Vector2.RIGHT)
	_put(player_a, Vector2(9.0, 0))
	_put(player_b, Vector2(0, -1.0))
	arena.ticks(24)  # To 1.2 s: the follow-up starts at the end of this step.
	assert_eq(enemy.get_running_attack().id, &"next")
	assert_eq(enemy.get_target_id(), &"player_2")
	assert_eq(enemy.get_aim(), Vector2.UP, "aimed at B from the step's view")
	_put(player_b, Vector2(1.0, -1.0))
	arena.ticks(12)  # 1.3 s: still tracking (0.3 s from 1.2).
	assert_false(enemy.is_aim_locked())
	assert_almost_eq(enemy.get_aim().angle(), Vector2(1.0, -1.0).angle(), TIME, "tracks B")
	arena.ticks(36)  # 1.6 s: locked at 1.5.
	assert_true(enemy.is_aim_locked())
	var locked: Vector2 = enemy.get_aim()
	_put(player_b, Vector2(-1.0, 0))
	arena.ticks(6)
	assert_eq(enemy.get_aim(), locked, "stays locked")
	assert_eq(enemy.get_target_id(), &"player_2")


func test_ac9_no_living_player_ends_the_pattern_and_starts_the_cooldown() -> void:
	var arena: EnemyArena = _pattern_arena()
	var root: EnemyAttackData = arena.chaser_data.attacks[0]
	root.range_tiles = 1.2
	root.damage = 1000
	var player: PlayerMotor = arena.add_player(Vector2(0, 1.0))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO)
	var watch: EnemyWatch = arena.watch(enemy)
	arena.ticks(300)
	assert_false(player.is_alive(), "the root's hit killed the only player")
	assert_eq(watch.times_entered(EnemyLogic.State.WINDUP).size(), 1, "no follow-up windup")
	var recovery: float = watch.times_entered(EnemyLogic.State.RECOVERY)[0]
	var idle: float = watch.times_entered(EnemyLogic.State.IDLE)[1]
	assert_almost_eq(idle - recovery, 0.6, TIME, "ends with the root's own recovery")
	assert_eq(enemy.get_pattern_root_index(), -1)


func test_ac10_each_attack_of_a_pattern_is_its_own_attack_instance() -> void:
	var arena: EnemyArena = _hitting_pattern_arena()
	arena.add_player(Vector2(0, 1.0))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO)
	var watch: EnemyWatch = arena.watch(enemy)
	arena.ticks(300)
	assert_eq(arena.hurt_times.size(), 2, "hit by both: %s" % [arena.hurt_times])
	var actives: Array = watch.times_entered(EnemyLogic.State.ACTIVE)
	assert_eq(actives.size(), 2)
	if arena.hurt_times.size() == 2 and actives.size() == 2:
		assert_true(arena.hurt_times[1] >= actives[1] - TIME, "the second by the follow-up")
		assert_true(arena.hurt_times[1] - arena.hurt_times[0] >= 0.6 - TIME, "after i-frames")


func test_ac10_hurt_iframes_are_the_only_protection_between_the_two() -> void:
	var arena: EnemyArena = _hitting_pattern_arena()
	arena.chaser_data.attacks[0].recovery = 0.0  # The follow-up's active falls in i-frames.
	arena.chaser_data.attacks[0].follow_up.windup = 0.3
	arena.chaser_data.attacks[0].follow_up.aim_track_time = 0.1
	arena.add_player(Vector2(0, 1.0))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO)
	var watch: EnemyWatch = arena.watch(enemy)
	arena.ticks(300)
	assert_eq(watch.times_entered(EnemyLogic.State.ACTIVE).size(), 2)
	assert_eq(arena.hurt_times.size(), 1, "the second swing met the player's hurt i-frames")


func test_ac11_a_wall_stopped_attack_drops_its_follow_up() -> void:
	var arena: BruteArena = _brute_pattern_arena(Vector2(6.5, 0))
	var brute: EnemyLogic = arena.enemies[0]
	BruteWallStub.new(brute, arena.sim, WALL).install(arena)
	var watch: EnemyWatch = arena.watch(brute)
	var gap_seen: bool = false
	var cooldown_after_stun: float = -1.0
	for _i: int in 400:
		var was_recovering: bool = brute.get_state() == EnemyLogic.State.RECOVERY
		arena.tick()
		if brute.get_state() == EnemyLogic.State.RECOVERY:
			gap_seen = gap_seen or brute.has_pending_follow_up()
		elif was_recovering:
			cooldown_after_stun = brute.get_cooldown_remaining()
	assert_eq(watch.times_entered(EnemyLogic.State.WINDUP).size(), 1, "no follow-up")
	var recovery: float = watch.times_entered(EnemyLogic.State.RECOVERY)[0]
	var idle: float = _idle_after(watch, recovery)
	assert_almost_eq(idle - recovery, 1.5, TIME, "the stun ran, and the pattern ended there")
	assert_false(gap_seen, "a stun is never a gap")
	assert_almost_eq(cooldown_after_stun, 1.0, 1.0 / 120.0, "the cooldown starts at the stun end")


func test_ac11_a_charge_that_is_not_wall_stopped_goes_on_to_its_follow_up() -> void:
	var arena: BruteArena = _brute_pattern_arena(Vector2(0, 7.5))
	var brute: EnemyLogic = arena.enemies[0]
	BruteWallStub.new(brute, arena.sim).install(arena)
	var watch: EnemyWatch = arena.watch(brute)
	arena.ticks(400)
	var windups: Array = watch.times_entered(EnemyLogic.State.WINDUP)
	assert_eq(windups.size(), 2, "charge, then its follow-up")
	if windups.size() == 2:
		assert_almost_eq(float(windups[1]), 2.2, TIME, "at the charge's recovery end")


func test_c20_the_gap_getter_is_true_only_in_a_recovery_with_a_follow_up_due() -> void:
	var arena: EnemyArena = _pattern_arena()
	arena.add_player(Vector2(0, 1.0))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO)
	var by_attack: Dictionary = {}
	for _i: int in 300:
		arena.ticks(1)
		var attack: EnemyAttackData = enemy.get_running_attack()
		var key: String = "%s/%s" % [attack.id if attack != null else &"-", enemy.get_state()]
		if not by_attack.has(key):
			by_attack[key] = []
		by_attack[key].append(enemy.has_pending_follow_up())
	var root_recovery: String = "root/%d" % EnemyLogic.State.RECOVERY
	var next_recovery: String = "next/%d" % EnemyLogic.State.RECOVERY
	assert_false(by_attack[root_recovery].has(false), "the root's recovery is a gap")
	assert_false(by_attack[next_recovery].has(true), "the last recovery is the punish window")
	for key: String in by_attack:
		if key != root_recovery:
			assert_false(by_attack[key].has(true), "%s is never a gap" % key)


func test_c20_a_chaser_without_follow_ups_never_shows_a_gap() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2(0, 1.0))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO)
	var recoveries: int = 0
	for _i: int in 300:
		arena.ticks(1)
		assert_false(enemy.has_pending_follow_up())
		if enemy.get_state() == EnemyLogic.State.RECOVERY:
			recoveries += 1
	assert_gt(recoveries, 0)


func test_c9_a_three_attack_chain_runs_in_order() -> void:
	var arena: EnemyArena = _pattern_arena()
	var third: EnemyAttackData = arena.chaser_data.attacks[0].follow_up.duplicate()
	third.id = &"third"
	third.follow_up = null
	arena.chaser_data.attacks[0].follow_up.follow_up = third
	arena.add_player(Vector2(0, 1.0))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO)
	var ids: Array[StringName] = []
	for _i: int in 400:
		arena.ticks(1)
		var attack: EnemyAttackData = enemy.get_running_attack()
		if attack != null and (ids.is_empty() or ids[-1] != attack.id):
			ids.append(attack.id)
	assert_eq(ids.slice(0, 3), [&"root", &"next", &"third"] as Array[StringName])


## The chaser's swipe as a pattern root with a follow-up. Neither hits (range 0.01) nor moves,
## so no hitstop or distance shifts the timing.
func _pattern_arena() -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	var root: EnemyAttackData = arena.chaser_data.attacks[0]
	root.id = &"root"
	root.lunge_tiles = 0.0
	root.range_tiles = NOT_A_RANGE
	var next: EnemyAttackData = root.duplicate()
	next.id = &"next"
	next.trigger_min_tiles = 5.0
	next.trigger_max_tiles = 6.0
	root.follow_up = next
	return arena


## The real swipe, twice: both reach a player standing 1 tile away.
func _hitting_pattern_arena() -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	var root: EnemyAttackData = arena.chaser_data.attacks[0]
	root.id = &"root"
	var next: EnemyAttackData = root.duplicate()
	next.id = &"next"
	root.follow_up = next
	return arena


## A brute at the origin whose charge is followed by a stomp, charging a still player.
func _brute_pattern_arena(player_at: Vector2) -> BruteArena:
	var arena: BruteArena = BruteArena.new()
	var charge: EnemyAttackData = arena.brute_data.attacks[CHARGE]
	charge.trigger_max_tiles = 8.0
	charge.range_tiles = NOT_A_RANGE  # Never hits, so no hitstop shifts the timing.
	var stomp: EnemyAttackData = arena.brute_data.attacks[STOMP].duplicate()
	stomp.id = &"follow_stomp"
	charge.follow_up = stomp
	arena.add_player(player_at)
	var brute: EnemyLogic = arena.add_brute(Vector2.ZERO)
	arena.restore_value(brute, "aggroed", true)
	return arena


func _put(motor: PlayerMotor, tiles: Vector2) -> void:
	motor.sync_position(Units.vector_tiles_to_px(tiles))


func _idle_after(watch: EnemyWatch, time: float) -> float:
	for idle: float in watch.times_entered(EnemyLogic.State.IDLE):
		if idle > time:
			return idle
	return -1.0


func _assert_times(actual: Array, expected: Array) -> void:
	assert_eq(actual.size(), expected.size(), "%s vs %s" % [actual, expected])
	for index: int in mini(actual.size(), expected.size()):
		assert_almost_eq(float(actual[index]), float(expected[index]), TIME, str(actual))
