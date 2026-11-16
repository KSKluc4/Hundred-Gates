extends GutTest
## F-009 T2: the Juggernaut's data (C4, C5, §4 tables) and its fight on the brute brain, at 120
## steps/s: AC2 (it validates), AC3 (band picks), AC4 and AC7 (double and triple charge), AC5
## (a wall stop on any charge ends the pattern), AC6 (stomp, then Debris), AC8 (50 % crossed in
## a gap), AC8b (Debris through its owner's hitstop), AC9 (two bolts, one hit) and C10 (co-op).
## Walls come from BruteWallStub (F-006): +x charges only, so the charge tests line the player
## up along +x and move it between charges.

const TIME: float = EnemyArena.TIME
const STEP: float = EnemyArena.STEP
## Positions are float32 vectors.
const TILES: float = 1e-4
## AC6: bolt directions against the locked aim.
const DIRECTION: float = 1e-6
const DEBRIS: Array = [0.0, 45.0, 90.0, 135.0, 180.0, -135.0, -90.0, -45.0]
## The Juggernaut's HP right under the 50 % line: in stage 2 at its first step start.
const STAGE_2_HP: int = 250
## §4: windup, aim_track_time, active, recovery, damage, arc, range, knockback, lunge, wall stun,
## speed, max distance, trigger min, trigger max, volley, follow-up path ("" = none).
const ATTACKS: Dictionary = {
	Tunables.JUGGERNAUT_STOMP_PATH:
	[0.60, 0.0, 0.10, 0.70, 22, 360.0, 2.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 1.8, [], ""],
	Tunables.JUGGERNAUT_P2_STOMP_PATH:
	[
		0.60,
		0.0,
		0.10,
		0.30,
		22,
		360.0,
		2.0,
		1.5,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		1.8,
		[],
		Tunables.JUGGERNAUT_DEBRIS_PATH
	],
	Tunables.JUGGERNAUT_CHARGE_A_PATH:
	[
		0.80,
		0.50,
		0.50,
		0.35,
		25,
		120.0,
		1.0,
		1.5,
		7.0,
		1.5,
		0.0,
		0.0,
		3.0,
		9.0,
		[],
		Tunables.JUGGERNAUT_CHARGE_B_PATH
	],
	Tunables.JUGGERNAUT_CHARGE_B_PATH:
	[0.60, 0.35, 0.50, 0.60, 25, 120.0, 1.0, 1.5, 7.0, 1.5, 0.0, 0.0, 3.0, 9.0, [], ""],
	Tunables.JUGGERNAUT_P2_CHARGE_A_PATH:
	[
		0.80,
		0.50,
		0.50,
		0.35,
		25,
		120.0,
		1.0,
		1.5,
		7.0,
		1.5,
		0.0,
		0.0,
		3.0,
		9.0,
		[],
		Tunables.JUGGERNAUT_P2_CHARGE_B_PATH
	],
	Tunables.JUGGERNAUT_P2_CHARGE_B_PATH:
	[
		0.60,
		0.35,
		0.50,
		0.35,
		25,
		120.0,
		1.0,
		1.5,
		7.0,
		1.5,
		0.0,
		0.0,
		3.0,
		9.0,
		[],
		Tunables.JUGGERNAUT_CHARGE_C_PATH
	],
	Tunables.JUGGERNAUT_CHARGE_C_PATH:
	[0.50, 0.30, 0.50, 0.60, 25, 120.0, 1.0, 1.5, 7.0, 1.5, 0.0, 0.0, 3.0, 9.0, [], ""],
	Tunables.JUGGERNAUT_DEBRIS_PATH:
	[0.50, 0.30, 0.10, 0.80, 18, 360.0, 0.25, 0.5, 0.0, 0.0, 5.0, 8.0, 0.0, 1.8, DEBRIS, ""],
}
const FIELDS: Array[String] = [
	"windup",
	"aim_track_time",
	"active",
	"recovery",
	"damage",
	"arc_angle_deg",
	"range_tiles",
	"knockback_tiles",
	"lunge_tiles",
	"wall_stun_duration",
	"projectile_speed_tiles",
	"projectile_max_distance_tiles",
	"trigger_min_tiles",
	"trigger_max_tiles",
]
const CHARGES: Array[StringName] = [
	&"juggernaut_charge_a",
	&"juggernaut_charge_b",
	&"juggernaut_p2_charge_a",
	&"juggernaut_p2_charge_b",
	&"juggernaut_charge_c",
]


func test_c4_the_juggernaut_matches_the_spec() -> void:
	var juggernaut: EnemyData = load(Tunables.JUGGERNAUT_PATH)
	assert_eq(juggernaut.id, &"juggernaut")
	assert_eq(juggernaut.brain, EnemyData.Brain.BRUTE, "C2: the brute's brain")
	assert_eq(juggernaut.max_hp, 500)
	assert_eq(juggernaut.hurtbox_radius_tiles, 0.8)
	assert_eq(juggernaut.knockback_scale, 0.0)
	assert_eq(juggernaut.move_speed, 2.0)
	assert_eq(juggernaut.aggro_radius_tiles, 10.0)
	assert_eq(juggernaut.stop_distance_tiles, 1.5)
	assert_eq(juggernaut.retreat_distance_tiles, 0.0)
	assert_eq(juggernaut.attack_cooldown, 1.0)
	assert_eq(
		_paths(juggernaut.attacks),
		[Tunables.JUGGERNAUT_STOMP_PATH, Tunables.JUGGERNAUT_CHARGE_A_PATH]
	)
	assert_eq(juggernaut.stages.size(), 1)
	var stage: EnemyStageData = juggernaut.stages[0]
	assert_eq(stage.resource_path, Tunables.JUGGERNAUT_STAGE_2_PATH)
	assert_eq(stage.enter_at_hp_percent, 50)
	assert_eq(stage.shift_duration, 1.2)
	assert_eq(stage.move_speed, 2.5)
	assert_eq(stage.attack_cooldown, 0.8)
	assert_eq(
		_paths(stage.attacks),
		[Tunables.JUGGERNAUT_P2_STOMP_PATH, Tunables.JUGGERNAUT_P2_CHARGE_A_PATH]
	)


func test_c4_every_juggernaut_attack_matches_the_table() -> void:
	for path: String in ATTACKS:
		var attack: EnemyAttackData = load(path)
		var row: Array = ATTACKS[path]
		assert_eq(attack.id, StringName(path.get_file().get_basename()), path)
		for index: int in FIELDS.size():
			assert_almost_eq(float(attack.get(FIELDS[index])), float(row[index]), TIME, path)
		assert_eq(attack.volley_angles_deg, PackedFloat64Array(row[14]), "%s volley" % path)
		var follow_up: String = attack.follow_up.resource_path if attack.follow_up != null else ""
		assert_eq(follow_up, row[15], "%s follow_up" % path)
		assert_false(attack.is_finisher, path)
		assert_eq(attack.is_projectile(), row[10] > 0.0, path)


func test_c5_every_charge_is_a_wall_stun_attack_and_nothing_else_is() -> void:
	for path: String in ATTACKS:
		var attack: EnemyAttackData = load(path)
		var is_charge: bool = CHARGES.has(attack.id)
		assert_eq(attack.is_wall_stun(), is_charge, path)
		if is_charge:
			assert_eq(attack.wall_stun_duration, 1.5, path)
			assert_gt(attack.lunge_tiles, 0.0, path)
			assert_false(attack.is_projectile(), "%s is melee" % path)


func test_ac2_the_juggernaut_validates_with_the_real_tunables_in_both_stages() -> void:
	var juggernaut: EnemyData = load(Tunables.JUGGERNAUT_PATH)
	var rate: int = Tunables.player_combat.combat_step_rate
	assert_eq(rate, 120)
	assert_eq(juggernaut.validate(rate, Tunables.enemy_combat), PackedStringArray())
	assert_eq(juggernaut.validate_against_class(load(Tunables.WARRIOR_PATH)), PackedStringArray())
	var stage: EnemyStageData = juggernaut.stages[0]
	assert_eq(stage.validate(), PackedStringArray(), "stage 2")
	for path: String in ATTACKS:
		var attack: EnemyAttackData = load(path)
		assert_eq(attack.validate_enemy(rate, Tunables.enemy_combat), PackedStringArray(), path)
	var warrior: ClassData = load(Tunables.WARRIOR_PATH)
	assert_lt(juggernaut.move_speed, warrior.move_speed, "C7: stage 1 is slower")
	assert_lt(stage.move_speed, warrior.move_speed, "C7: stage 2 is slower")


func test_ac3_stage_1_distance_picks_the_attack() -> void:
	assert_eq(_first_pick(1.5), &"juggernaut_stomp")
	assert_eq(_first_pick(1.8), &"juggernaut_stomp", "at exactly 1.8 the stomp's band holds")
	assert_eq(_first_pick(2.5), &"", "walks in")
	assert_eq(_first_pick(3.0), &"juggernaut_charge_a")
	assert_eq(_first_pick(9.0), &"juggernaut_charge_a")
	assert_eq(_first_pick(9.5), &"", "aggroed, walks in")


func test_ac4_stage_1_double_charge_with_no_wall() -> void:
	var arena: BruteArena = _arena(Vector2(0, 5.0))
	var juggernaut: EnemyLogic = arena.enemies[0]
	var stub: BruteWallStub = BruteWallStub.new(juggernaut, arena.sim).install(arena)
	var watch: EnemyWatch = arena.watch(juggernaut)
	var run: Dictionary = _record(arena, juggernaut, 480)
	assert_eq(stub.stop_step(), -1, "no wall in reach")
	assert_eq(run["ids"], [&"juggernaut_charge_a", &"juggernaut_charge_b"] as Array[StringName])
	var windups: Array = watch.times_entered(EnemyLogic.State.WINDUP)
	var actives: Array = watch.times_entered(EnemyLogic.State.ACTIVE)
	var recoveries: Array = watch.times_entered(EnemyLogic.State.RECOVERY)
	assert_eq(windups.size(), 2)
	assert_eq(actives.size(), 2)
	assert_eq(recoveries.size(), 2)
	if windups.size() != 2 or actives.size() != 2 or recoveries.size() != 2:
		return
	assert_almost_eq(float(windups[0]), 0.0, TIME)
	assert_almost_eq(actives[0] - windups[0], 0.80, TIME, "Charge A's windup")
	assert_almost_eq(watch.aim_lock_times[0] - windups[0], 0.50, TIME, "A tracks 0.50 s")
	var hitstop_a: float = _hitstop_in(arena, actives[0], recoveries[0])
	assert_almost_eq(recoveries[0] - actives[0], 0.50 + hitstop_a, TIME, "A's active")
	assert_almost_eq(run["at"][_step(recoveries[0])]["position"].y, 7.0, TILES, "lunged 7 tiles")
	assert_almost_eq(windups[1] - recoveries[0], 0.35, TIME, "B starts at the gap's end")
	assert_true(_all(run, &"juggernaut_charge_a", EnemyLogic.State.RECOVERY, "gap", true))
	assert_eq(watch.aim_lock_times.size(), 2)
	if watch.aim_lock_times.size() == 2:
		assert_almost_eq(watch.aim_lock_times[1] - windups[1], 0.35, TIME, "B re-tracks 0.35 s")
	assert_false(run["at"][_step(windups[1])]["locked"], "B starts unlocked: it re-tracks")
	assert_almost_eq(actives[1] - windups[1], 0.60, TIME, "Charge B's windup")
	var idle: float = _idle_after(watch, recoveries[1])
	assert_almost_eq(idle - recoveries[1], 0.60, TIME, "B's recovery")
	assert_true(_all(run, &"juggernaut_charge_b", EnemyLogic.State.RECOVERY, "gap", false))
	assert_almost_eq(run["at"][_step(idle)]["cooldown"], 1.0, TIME, "then the 1.0 s cooldown")


func test_ac4_c10_charge_b_re_picks_the_nearest_living_player() -> void:
	var arena: BruteArena = BruteArena.new()
	arena.brute_data = load(Tunables.JUGGERNAUT_PATH)
	arena.add_player(Vector2(9.0, 0))
	var second: PlayerMotor = arena.add_player(Vector2(-12.0, 0), &"player_2")
	var juggernaut: EnemyLogic = arena.add_brute(Vector2.ZERO, &"juggernaut")
	arena.ticks(1)
	assert_eq(juggernaut.get_target_id(), &"player_1")
	arena.ticks(_step(0.80 + 0.50) + 1)  # Into A's gap: A went 7 tiles +x, to (7, 0).
	assert_true(juggernaut.has_pending_follow_up(), "in A's gap")
	_put(second, Vector2(7.0, -1.5))  # Now nearer than player_1, 2 tiles away.
	arena.ticks(_step(0.35))
	assert_eq(juggernaut.get_running_attack().id, &"juggernaut_charge_b")
	assert_eq(juggernaut.get_target_id(), &"player_2", "B aims at the nearest living player")
	assert_almost_eq(juggernaut.get_aim().angle(), Vector2.UP.angle(), TILES)


func test_ac5_a_wall_stop_on_stage_1_charge_a_ends_the_pattern() -> void:
	_assert_wall_stop(false, 0)


func test_ac5_a_wall_stop_on_stage_1_charge_b_ends_the_pattern() -> void:
	_assert_wall_stop(false, 1)


func test_ac5_a_wall_stop_on_stage_2_charge_a_ends_the_pattern() -> void:
	_assert_wall_stop(true, 0)


func test_ac5_a_wall_stop_on_stage_2_charge_b_ends_the_pattern() -> void:
	_assert_wall_stop(true, 1)


func test_ac5_a_wall_stop_on_stage_2_charge_c_ends_the_pattern() -> void:
	_assert_wall_stop(true, 2)


func test_ac6_stage_2_stomp_then_debris() -> void:
	var arena: BruteArena = _arena(Vector2(0, 1.5), STAGE_2_HP)
	var juggernaut: EnemyLogic = arena.enemies[0]
	var watch: CasterWatch = arena.watch_caster(juggernaut)
	var launch: Dictionary = {}
	var on_tick: Callable = func(_index: int) -> void:
		if launch.is_empty() and juggernaut.get_projectiles().get_next_serial() > 0:
			launch["time"] = arena.sim.get_time()
			launch["aim"] = juggernaut.get_aim()
			launch["bolts"] = juggernaut.get_projectiles().get_projectiles().duplicate()
	var run: Dictionary = _record(arena, juggernaut, 480, on_tick)
	assert_eq(juggernaut.get_stage_index(), 1, "stage 2 is stages[0]")
	assert_eq(
		run["ids"].slice(0, 2), [&"juggernaut_p2_stomp", &"juggernaut_debris"] as Array[StringName]
	)
	var windups: Array = watch.times_entered(EnemyLogic.State.WINDUP)
	var actives: Array = watch.times_entered(EnemyLogic.State.ACTIVE)
	var recoveries: Array = watch.times_entered(EnemyLogic.State.RECOVERY)
	assert_almost_eq(float(windups[0]), 1.2, TIME, "after the 1.2 s shift")
	assert_almost_eq(actives[0] - windups[0], 0.60, TIME, "the stomp's windup")
	var hitstop: float = _hitstop_in(arena, actives[0], recoveries[0])
	assert_eq(arena.hurt_events[0].damage, 22, "the stomp landed")
	assert_almost_eq(recoveries[0] - actives[0], 0.10 + hitstop, TIME)
	assert_almost_eq(windups[1] - recoveries[0], 0.30, TIME, "a 0.30 s gap")
	assert_true(_all(run, &"juggernaut_p2_stomp", EnemyLogic.State.RECOVERY, "gap", true))
	assert_almost_eq(watch.aim_lock_times[1] - windups[1], 0.30, TIME, "Debris tracks 0.30 s")
	assert_almost_eq(actives[1] - windups[1], 0.50, TIME, "Debris's windup")
	assert_almost_eq(float(launch["time"]), float(actives[1]), TIME, "launch at its end")
	var bolts: Array = launch["bolts"]
	assert_eq(bolts.size(), 8, "8 bolts at one instant")
	for index: int in bolts.size():
		var bolt: ProjectileSet.Projectile = bolts[index]
		var expected: Vector2 = (launch["aim"] as Vector2).rotated(deg_to_rad(DEBRIS[index]))
		assert_eq(bolt.serial, index, "consecutive serials")
		assert_lt(bolt.direction.distance_to(expected), DIRECTION, "bolt %d's angle" % index)
		assert_eq(bolt.speed, 5.0)
		assert_eq(bolt.radius, 0.25)
		assert_eq(bolt.max_distance, 8.0)
		assert_eq(bolt.damage, 18)
		assert_eq(bolt.origin, bolts[0].origin, "from one point")
	assert_lt((bolts[0] as ProjectileSet.Projectile).direction.distance_to(launch["aim"]), TIME)
	var idle: float = _idle_after(watch, recoveries[1])
	assert_almost_eq(idle - recoveries[1], 0.80, TIME, "Debris's recovery")
	assert_true(_all(run, &"juggernaut_debris", EnemyLogic.State.RECOVERY, "gap", false))
	assert_almost_eq(run["at"][_step(idle)]["cooldown"], 0.8, TIME, "then the 0.8 s cooldown")


func test_ac7_stage_2_triple_charge_with_no_wall() -> void:
	var arena: BruteArena = _arena(Vector2(0, 5.0), STAGE_2_HP)
	var juggernaut: EnemyLogic = arena.enemies[0]
	var stub: BruteWallStub = BruteWallStub.new(juggernaut, arena.sim).install(arena)
	var watch: EnemyWatch = arena.watch(juggernaut)
	var player: PlayerMotor = arena.players[0]
	var aims: Array[Dictionary] = []
	var on_tick: Callable = func(_index: int) -> void:
		var locked: bool = juggernaut.is_aim_locked()
		if aims.size() < watch.aim_lock_times.size() and locked:
			aims.append({"aim": juggernaut.get_aim(), "towards": _towards(juggernaut, player)})
	var run: Dictionary = _record(arena, juggernaut, 900, on_tick)
	assert_eq(stub.stop_step(), -1, "no wall in reach")
	assert_eq(
		run["ids"].slice(0, 3),
		(
			[&"juggernaut_p2_charge_a", &"juggernaut_p2_charge_b", &"juggernaut_charge_c"]
			as Array[StringName]
		)
	)
	var windups: Array = watch.times_entered(EnemyLogic.State.WINDUP)
	var actives: Array = watch.times_entered(EnemyLogic.State.ACTIVE)
	var recoveries: Array = watch.times_entered(EnemyLogic.State.RECOVERY)
	if windups.size() < 3 or recoveries.size() < 3 or watch.aim_lock_times.size() < 3:
		fail_test("3 windups, recoveries and locks: %s" % [run["ids"]])
		return
	var windup_lengths: Array = [0.80, 0.60, 0.50]
	var tracks: Array = [0.50, 0.35, 0.30]
	for index: int in 3:
		assert_almost_eq(actives[index] - windups[index], windup_lengths[index], TIME)
		assert_almost_eq(watch.aim_lock_times[index] - windups[index], tracks[index], TIME)
		assert_false(run["at"][_step(windups[index])]["locked"], "re-aimed: %d tracks" % index)
	assert_almost_eq(windups[1] - recoveries[0], 0.35, TIME, "gap A")
	assert_almost_eq(windups[2] - recoveries[1], 0.35, TIME, "gap B")
	assert_gte(aims.size(), 3)
	for entry: Dictionary in aims:
		assert_lt(entry["aim"].distance_to(entry["towards"]), 1e-4, "each aimed at the player")
	var idle: float = _idle_after(watch, recoveries[2])
	assert_almost_eq(idle - recoveries[2], 0.60, TIME, "C's recovery")
	assert_almost_eq(run["at"][_step(idle)]["cooldown"], 0.8, TIME, "then the cooldown")


func test_ac8_crossing_50_percent_in_charge_a_gap_finishes_the_pattern_then_shifts() -> void:
	var arena: BruteArena = _arena(Vector2(0, 5.0))
	var juggernaut: EnemyLogic = arena.enemies[0]
	var watch: EnemyWatch = arena.watch(juggernaut)
	arena.ticks(_step(0.80 + 0.50) + 12)
	assert_true(juggernaut.has_pending_follow_up(), "in Charge A's gap")
	BossValues.set_hp(juggernaut, STAGE_2_HP)  # F-004/C6's restore path, as if hit.
	var run: Dictionary = _record(arena, juggernaut, 300)
	assert_eq(run["ids"][0], &"juggernaut_charge_a")
	assert_eq(run["ids"][1], &"juggernaut_charge_b", "B still runs")
	var shift: Array = watch.times_entered(EnemyLogic.State.STAGE_SHIFT)
	assert_eq(shift.size(), 1, "the shift came")
	if shift.size() != 1:
		return
	var b_recovery: float = watch.times_entered(EnemyLogic.State.RECOVERY)[1]
	assert_almost_eq(shift[0] - b_recovery, 0.60, TIME, "at the first free step start after B")
	for state: EnemyLogic.State in [EnemyLogic.State.IDLE, EnemyLogic.State.CHASE]:
		for time: float in watch.times_entered(state):
			assert_false(time > TIME and time < shift[0] - TIME, "never free before the shift")
	# In the shift: a sword hit lands and only delays its end.
	var player: PlayerMotor = arena.players[0]
	var planted: Vector2 = juggernaut.get_position_tiles()
	_put(player, planted + Vector2(1.5, 0))
	var hp: int = juggernaut.get_combat_state().get_hp()
	arena.tick(120, Vector2.ZERO, false, true, Vector2.LEFT)
	arena.ticks(20)
	assert_eq(juggernaut.get_state(), EnemyLogic.State.STAGE_SHIFT)
	assert_eq(juggernaut.get_combat_state().get_hp(), hp - 10, "takes damage in the shift")
	assert_eq(juggernaut.get_position_tiles(), planted, "planted")
	# Walk-in range for stage 2, so the speed shows before the stomp's band holds.
	_put(player, planted + Vector2(0, 2.5))
	var end_run: Dictionary = _record(arena, juggernaut, 240)
	var shift_end: float = _first_time_not(end_run, EnemyLogic.State.STAGE_SHIFT)
	var hitstop: float = arena.rules.hitstop_normal
	assert_almost_eq(shift_end - shift[0], 1.2 + hitstop, TIME, "1.2 s, plus the hit's hitstop")
	assert_eq(juggernaut.get_stage_index(), 1)
	assert_eq(juggernaut.get_current_move_speed(), 2.5)
	var step_after: int = _step(shift_end) + 12
	var walked: float = (
		end_run["at"][step_after]["position"].y - end_run["at"][_step(shift_end)]["position"].y
	)
	assert_almost_eq(walked, 2.5 * 12.0 / 120.0, TIME, "chases at 2.5 tiles/s")
	assert_eq(end_run["ids"][0], &"juggernaut_p2_stomp", "the next attack is stage 2's")


func test_ac8b_debris_bolts_fly_through_the_juggernaut_hitstop() -> void:
	var calm: Dictionary = _debris_sword_run(false)
	var hit: Dictionary = _debris_sword_run(true)
	var calm_watch: CasterWatch = calm["watch"]
	var hit_watch: CasterWatch = hit["watch"]
	assert_lt(hit["hp"], calm["hp"], "the sword landed")
	var launch: int = hit["launch"]
	assert_eq(launch, calm["launch"])
	var paused: int = 0
	var compared: int = 0
	var step: int = launch
	while hit_watch.contacts.has(step) and not hit_watch.at(step)["projectiles"].is_empty():
		assert_eq_deep(hit_watch.at(step)["projectiles"], calm_watch.at(step)["projectiles"])
		compared += hit_watch.at(step)["projectiles"].size()
		if hit_watch.at(step)["hitstop"] > 0.0:
			paused += 1
		step += 1
	assert_true(calm_watch.at(step)["projectiles"].is_empty(), "both end together")
	assert_gt(paused, 0, "the Juggernaut was in hitstop while they flew")
	assert_gt(compared, 8 * 100, "bolts compared through their whole flight")


func test_ac9_two_debris_bolts_on_one_player_at_one_contact_hit_once() -> void:
	var arena: BruteArena = _arena(Vector2(0, 1.5), STAGE_2_HP)
	var juggernaut: EnemyLogic = arena.enemies[0]
	var player: PlayerMotor = arena.players[0]
	_run_to_debris_lock(arena, juggernaut)
	_put(player, Vector2(-30.0, 0))  # Out of the way while the bolts fly out.
	var bolts: ProjectileSet = juggernaut.get_projectiles()
	while bolts.get_projectiles().is_empty() or bolts.get_projectiles()[0].travelled < 0.95:
		arena.ticks(1)
	# Where bolts 0 and 1 are at the next contact, 1 tile out: 0.38 tiles from their midpoint,
	# and every other bolt is over 1 tile from it.
	var step_flight: float = 5.0 * STEP
	var next: Array[Vector2] = []
	for bolt: ProjectileSet.Projectile in bolts.get_projectiles():
		next.append(bolt.position + bolt.direction * step_flight)
	var standing: Vector2 = (next[0] + next[1]) / 2.0
	_put(player, standing)
	var hurt_before: int = arena.hurt_events.size()
	arena.ticks(1)
	var near: Array[int] = []
	var marked: Array[int] = []
	for bolt: ProjectileSet.Projectile in bolts.get_projectiles():
		if bolt.position.distance_to(standing) < 0.25 + 0.35:
			near.append(bolt.serial)
		if bolt.has_landed():
			marked.append(bolt.serial)
	assert_eq(near, [0, 1] as Array[int], "both overlap it at this contact")
	assert_eq(arena.hurt_events.size() - hurt_before, 1, "one hit")
	assert_eq(arena.hurt_events[-1].damage, 18)
	assert_eq(marked.size(), 1, "one bolt is marked")
	arena.ticks(1)
	var left: Array = bolts.get_projectiles().map(
		func(p: ProjectileSet.Projectile) -> int: return p.serial
	)
	assert_eq(left.size(), 7, "the landed bolt is gone")
	assert_false(left.has(marked[0]) if not marked.is_empty() else true)
	assert_true(left.has(1 - marked[0]) if not marked.is_empty() else false, "the other flies on")
	arena.ticks(60)
	assert_eq(arena.hurt_events.size() - hurt_before, 1, "it never hits in the hurt i-frames")


func test_c10_two_players_each_hit_by_their_own_debris_bolt() -> void:
	var arena: BruteArena = _arena(Vector2(0, 1.5), STAGE_2_HP)
	var other: PlayerMotor = arena.add_player(Vector2(-30.0, 0), &"player_2")
	var juggernaut: EnemyLogic = arena.enemies[0]
	_run_to_debris_lock(arena, juggernaut)
	var at: Vector2 = juggernaut.get_position_tiles()
	var aim: Vector2 = juggernaut.get_aim()
	_put(arena.players[0], at + aim * 3.0)
	_put(other, at + aim.rotated(deg_to_rad(-90.0)) * 3.0)
	var hurt_before: int = arena.hurt_events.size()
	arena.ticks(120)
	var hit: Array[StringName] = []
	for index: int in range(hurt_before, arena.hurt_events.size()):
		hit.append(arena.hurt_events[index].target_id)
	assert_eq(hit.size(), 2, "two hits")
	assert_true(hit.has(&"player_1") and hit.has(&"player_2"), "each by its own bolt: %s" % [hit])


## Brings a stage-2 Juggernaut with its player at 1.5 tiles to Debris's locked aim.
func _run_to_debris_lock(arena: BruteArena, juggernaut: EnemyLogic) -> void:
	for _i: int in 600:
		arena.ticks(1)
		var attack: EnemyAttackData = juggernaut.get_running_attack()
		if attack != null and attack.id == &"juggernaut_debris" and juggernaut.is_aim_locked():
			return
	fail_test("Debris never locked its aim")


## AC5: the Juggernaut at the origin charges +x at a player 9 tiles ahead. Before each charge
## (in the gap before it) the player moves 7 tiles further, so no charge ever reaches it, and
## a wall 4 tiles ahead of charge `stopped` stops that one.
func _assert_wall_stop(stage_2: bool, stopped: int) -> void:
	var label: String = "stage %d, charge %d" % [2 if stage_2 else 1, stopped]
	var arena: BruteArena = _arena(Vector2(9.0, 0), STAGE_2_HP if stage_2 else 500)
	var juggernaut: EnemyLogic = arena.enemies[0]
	var player: PlayerMotor = arena.players[0]
	var stub: BruteWallStub = BruteWallStub.new(juggernaut, arena.sim).install(arena)
	if stopped == 0:
		stub.limit = 4.0
	var watch: EnemyWatch = arena.watch(juggernaut)
	var gaps_seen: Array[int] = [0]
	var on_tick: Callable = func(_index: int) -> void:
		if juggernaut.has_pending_follow_up() and juggernaut.get_pattern_depth() == gaps_seen[0]:
			gaps_seen[0] += 1
			var next: int = gaps_seen[0]
			_put(player, Vector2(9.0 + 7.0 * next, 0))
			if next == stopped:
				stub.limit = 7.0 * next + 4.0
	var run: Dictionary = _record(arena, juggernaut, 960, on_tick)
	var windups: Array = watch.times_entered(EnemyLogic.State.WINDUP)
	var recoveries: Array = watch.times_entered(EnemyLogic.State.RECOVERY)
	if recoveries.size() <= stopped:
		fail_test("%s: only %d recoveries" % [label, recoveries.size()])
		return
	var stun_start: float = recoveries[stopped]
	var idle: float = _idle_after(watch, stun_start)
	assert_ne(stub.stop_step(), -1, "%s: the wall stopped it" % label)
	assert_almost_eq(stub.stop_step() * STEP, stun_start, TIME, "%s: stunned at the stop" % label)
	for time: float in arena.hurt_times:
		assert_gt(time, idle, "%s: nothing hit in the pattern, so no hitstop" % label)
	var in_pattern: Array = windups.filter(func(t: float) -> bool: return t < idle)
	assert_eq(in_pattern.size(), stopped + 1, "%s: no charge after the stopped one" % label)
	assert_almost_eq(idle - stun_start, 1.5, TIME, "%s: the stun is the recovery" % label)
	var stop_x: float = 7.0 * stopped + 4.0
	assert_almost_eq(run["at"][_step(idle) - 1]["position"].x, stop_x, TILES, "%s: wall" % label)
	for step: int in range(_step(stun_start) + 1, _step(idle)):
		assert_false(run["at"][step]["gap"], "%s: the stun shows as open (%d)" % [label, step])
		assert_true(run["at"][step]["stopped"], "%s: wall-stopped (%d)" % [label, step])
	for index: int in stopped:
		var gap_step: int = _step(recoveries[index]) + 1
		assert_true(
			run["at"][gap_step]["gap"], "%s: charge %d's recovery is a gap" % [label, index]
		)
	var cooldown: float = 0.8 if stage_2 else 1.0
	assert_almost_eq(run["at"][_step(idle)]["cooldown"], cooldown, TIME, "%s: cooldown" % label)


## Two runs of a stage-2 Debris whose on-aim bolt meets the player near 3 tiles (knocked there
## by the stomp). In its hurt i-frames the player walks back in and, if `swing`, lands hit 1
## while the other 7 bolts fly. Returns the watch, the launch step and the Juggernaut's HP.
func _debris_sword_run(swing: bool) -> Dictionary:
	var arena: BruteArena = _arena(Vector2(0, 1.5), STAGE_2_HP)
	var juggernaut: EnemyLogic = arena.enemies[0]
	var watch: CasterWatch = arena.watch_caster(juggernaut)
	var launch: int = -1
	var swung: bool = false
	for _i: int in 600:
		var move: Vector2 = Vector2.ZERO
		var press: bool = false
		if launch >= 0 and not swung and roundi(arena.sim.get_time() * 120.0) - launch >= 60:
			# Walks back in to 1.6 tiles (in hit 1's reach), then swings, or not.
			var gap: float = arena.players[0].get_position_tiles().distance_to(
				juggernaut.get_position_tiles()
			)
			if gap > 1.6:
				move = Vector2.UP
			else:
				swung = true
				press = swing
		arena.tick(120, move, false, press, Vector2.UP)
		if launch < 0 and juggernaut.get_projectiles().get_next_serial() > 0:
			launch = roundi(arena.sim.get_time() * 120.0)
	return {"watch": watch, "launch": launch, "hp": juggernaut.get_combat_state().get_hp()}


## The Juggernaut at the origin, its player at `player_at`. In stage 2 at once (its shift runs
## first) when `hp` is under the line.
func _arena(player_at: Vector2, hp: int = 500) -> BruteArena:
	var arena: BruteArena = BruteArena.new()
	arena.brute_data = load(Tunables.JUGGERNAUT_PATH)
	arena.add_player(player_at)
	var juggernaut: EnemyLogic = arena.add_brute(Vector2.ZERO, &"juggernaut")
	if hp != 500:
		BossValues.set_hp(juggernaut, hp)
	return arena


## The attack the Juggernaut starts in its first step with the player `distance` below, or
## &"" if it starts none (then it must be chasing).
func _first_pick(distance: float) -> StringName:
	var arena: BruteArena = _arena(Vector2(0, distance))
	var juggernaut: EnemyLogic = arena.enemies[0]
	arena.ticks(1)
	var attack: EnemyAttackData = juggernaut.get_running_attack()
	if attack == null:
		assert_eq(juggernaut.get_state(), EnemyLogic.State.CHASE, "at %s it walks in" % distance)
		return &""
	return attack.id


## One sample per tick (step index -> what the Juggernaut is right after that step), and the
## ids of the attacks it ran, in order. `on_tick` runs before each tick, with its index.
func _record(
	arena: BruteArena, juggernaut: EnemyLogic, ticks: int, on_tick: Callable = Callable()
) -> Dictionary:
	var result: Dictionary = {"at": {}, "ids": [] as Array[StringName]}
	for index: int in ticks:
		if on_tick.is_valid():
			on_tick.call(index)
		arena.ticks(1)
		var attack: EnemyAttackData = juggernaut.get_running_attack()
		if attack != null and (result["ids"].is_empty() or result["ids"][-1] != attack.id):
			result["ids"].append(attack.id)
		result["at"][roundi(arena.sim.get_time() * 120.0)] = {
			"id": attack.id if attack != null else &"",
			"state": juggernaut.get_state(),
			"gap": juggernaut.has_pending_follow_up(),
			"stopped": juggernaut.is_wall_stopped(),
			"locked": juggernaut.is_aim_locked(),
			"cooldown": juggernaut.get_cooldown_remaining(),
			"position": juggernaut.get_position_tiles(),
		}
	return result


## True if every sample of that attack in that state has `key` equal to `value` (and one does).
func _all(
	run: Dictionary, id: StringName, state: EnemyLogic.State, key: String, value: bool
) -> bool:
	var seen: int = 0
	for step: int in run["at"]:
		var sample: Dictionary = run["at"][step]
		if sample["id"] == id and sample["state"] == state:
			seen += 1
			if sample[key] != value:
				return false
	return seen > 0


## The attacker hitstop the Juggernaut took from hits it landed in [from, to).
func _hitstop_in(arena: EnemyArena, from: float, to: float) -> float:
	var hits: int = 0
	for time: float in arena.hurt_times:
		if time > from - TIME and time < to - TIME:
			hits += 1
	return hits * arena.rules.hitstop_normal


func _first_time_not(run: Dictionary, state: EnemyLogic.State) -> float:
	var steps: Array = run["at"].keys()
	steps.sort()
	for step: int in steps:
		if run["at"][step]["state"] != state:
			return step * STEP
	return -1.0


func _idle_after(watch: EnemyWatch, time: float) -> float:
	for idle: float in watch.times_entered(EnemyLogic.State.IDLE):
		if idle > time + TIME:
			return idle
	return -1.0


func _towards(juggernaut: EnemyLogic, player: PlayerMotor) -> Vector2:
	return (player.get_position_tiles() - juggernaut.get_position_tiles()).normalized()


func _put(motor: PlayerMotor, tiles: Vector2) -> void:
	motor.sync_position(Units.vector_tiles_to_px(tiles))


func _step(time: float) -> int:
	return roundi(time * 120.0)


func _paths(attacks: Array[EnemyAttackData]) -> Array[String]:
	var paths: Array[String] = []
	for attack: EnemyAttackData in attacks:
		paths.append(attack.resource_path)
	return paths
