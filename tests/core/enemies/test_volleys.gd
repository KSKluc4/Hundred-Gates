extends GutTest
## F-008 T3: volley launch and life on a real CombatSim (C4, C5, C8, C9): AC2–AC8 (with AC5b)
## and AC12. Walls go through a test move_bodies, as the glue reports them (F-005/C5).

const RecorderScript: GDScript = preload("res://tests/core/enemies/caster_bolt_recorder.gd")
const TIME: float = EnemyArena.TIME
const DIRECTION: float = 1e-6
const START: Vector2 = Vector2(0, 6.52)
const FAN: Array = [-20.0, 0.0, 20.0]
## Long enough that the fan's middle bolt lands (step 191) after either snapshot.
const RESUMED_TICKS: int = 160
## The caster's bolt: windup 0.6 ends exactly at step 72.
const LAUNCH: int = 72


func test_ac2_a_fan_launches_three_bolts_at_the_windup_end() -> void:
	var arena: CasterArena = _arena(FAN)
	arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	arena.ticks(LAUNCH - 1)
	assert_eq(caster.get_projectiles().get_projectiles().size(), 0, "not before")
	var aim: Vector2 = caster.get_aim()
	arena.ticks(1)
	var bolts: Array[ProjectileSet.Projectile] = caster.get_projectiles().get_projectiles()
	assert_eq(bolts.size(), 3)
	for index: int in bolts.size():
		var bolt: ProjectileSet.Projectile = bolts[index]
		var label: String = "entry %d" % index
		assert_eq(bolt.serial, index, label)
		assert_eq(bolt.origin, START, label)
		assert_eq(bolt.speed, 6.0, label)
		assert_eq(bolt.radius, 0.25, label)
		assert_eq(bolt.damage, 18, label)
		assert_eq(bolt.knockback_tiles, 0.5, label)
		assert_eq(bolt.max_distance, 10.0, label)
		var expected: Vector2 = aim.rotated(deg_to_rad(FAN[index]))
		assert_almost_eq(bolt.direction, expected, Vector2.ONE * DIRECTION, label)
	assert_eq(caster.get_projectiles().get_next_serial(), 3)


func test_ac3_an_empty_list_launches_one_bolt_along_the_aim() -> void:
	var arena: CasterArena = _arena([])
	arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	arena.ticks(LAUNCH)
	var bolts: Array[ProjectileSet.Projectile] = caster.get_projectiles().get_projectiles()
	assert_eq(bolts.size(), 1)
	assert_eq(bolts[0].direction, caster.get_aim())


func test_ac3_the_recorded_caster_bolt_run_matches_the_run_before_this_feature() -> void:
	var golden: String = FileAccess.get_file_as_string(RecorderScript.GOLDEN_PATH)
	assert_ne(golden, "", "the golden file exists")
	var recorded: String = RecorderScript.record()
	var expected: PackedStringArray = golden.split("\n")
	var actual: PackedStringArray = recorded.split("\n")
	assert_eq(actual.size(), expected.size(), "line count")
	for index: int in mini(actual.size(), expected.size()):
		if actual[index] != expected[index]:
			fail_test("line %d: %s != %s" % [index, actual[index], expected[index]])
			return
	pass_test("identical, %d lines" % actual.size())


func test_ac4_a_launch_inside_a_step_flies_every_bolt_the_rest_of_it() -> void:
	var arena: CasterArena = _arena(FAN)
	arena.caster_data.attacks[0].windup = 0.605
	arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	arena.ticks(73)
	var bolts: Array[ProjectileSet.Projectile] = caster.get_projectiles().get_projectiles()
	assert_eq(bolts.size(), 3)
	var expected: float = 6.0 * (73.0 / 120.0 - 0.605)
	for bolt: ProjectileSet.Projectile in bolts:
		assert_almost_eq(bolt.travelled, expected, TIME, "serial %d" % bolt.serial)
		var flown: Vector2 = bolt.origin + bolt.direction * expected
		assert_almost_eq(bolt.position, flown, Vector2.ONE * TIME, "serial %d" % bolt.serial)


func test_ac5_three_bolts_on_one_player_at_one_contact_hit_once() -> void:
	var arena: CasterArena = _arena(FAN)
	var player: PlayerMotor = arena.add_player(Vector2(0, 6.0))
	var caster: EnemyLogic = arena.add_caster(START)
	var watch: CasterWatch = arena.watch_caster(caster)
	arena.ticks(LAUNCH)
	var bolts: Array[ProjectileSet.Projectile] = caster.get_projectiles().get_projectiles()
	for bolt: ProjectileSet.Projectile in bolts:
		var gap: float = bolt.position.distance_to(player.get_position_tiles())
		assert_lt(gap, 0.25 + 0.35, "serial %d overlaps at the contact" % bolt.serial)
	assert_eq(arena.hurt_events.size(), 1, "one hit")
	assert_eq(arena.hurt_events[0].damage, 18)
	assert_almost_eq(arena.hurt_times[0], LAUNCH / 120.0, TIME)
	assert_eq(player.get_combat_state().get_hp(), 82)
	assert_eq_deep(bolts[0].hit_ids, [&"player_1"] as Array[StringName])
	assert_eq(bolts[1].hit_ids.size(), 0, "not marked")
	assert_eq(bolts[2].hit_ids.size(), 0, "not marked")
	arena.ticks(1)
	var left: Array = watch.at(LAUNCH + 1)["projectiles"].map(
		func(p: Dictionary) -> int: return p["serial"]
	)
	assert_eq(left, [1, 2], "the landed bolt is gone, the other two fly on")
	for serial: int in [1, 2]:
		var before: Vector2 = watch.projectile_at(LAUNCH, serial)["position"]
		var after: Vector2 = watch.projectile_at(LAUNCH + 1, serial)["position"]
		assert_almost_eq(before.distance_to(after), 6.0 / 120.0, TIME, "serial %d" % serial)


func test_ac5b_an_unmarked_bolt_still_overlapping_hits_when_the_hurt_iframes_end() -> void:
	var arena: CasterArena = _arena([0.0, 10.0])
	var bolt_data: EnemyAttackData = arena.caster_data.attacks[0]
	bolt_data.projectile_speed_tiles = 0.1  # Slow: the player stands in it.
	bolt_data.knockback_tiles = 0.0
	var player: PlayerMotor = arena.add_player(Vector2(0, 6.2))
	var caster: EnemyLogic = arena.add_caster(START)
	arena.ticks(LAUNCH + 90)
	# The hurt i-frames run on the player's own clock, after its defender hitstop (F-003).
	var protected: float = arena.rules.hitstop_normal + arena.rules.player_hurt_iframes
	assert_eq(arena.hurt_events.size(), 2, "%s" % [arena.hurt_times])
	assert_almost_eq(arena.hurt_times[0], LAUNCH / 120.0, TIME, "serial 0 at the launch")
	var second: float = arena.hurt_times[1]
	var ends: float = arena.hurt_times[0] + protected
	assert_almost_eq(second, ceilf(ends * 120.0 - TIME) / 120.0, TIME, "first contact after")
	assert_eq(player.get_combat_state().get_hp(), 64, "two hits from one volley")
	assert_eq(caster.get_projectiles().get_next_serial(), 2)


func test_ac6_two_players_each_hit_by_their_own_bolt_at_one_contact() -> void:
	var arena: CasterArena = _arena([-90.0, 90.0])
	arena.add_player(Vector2(0, -1.5), &"target")  # Nearest: the aim is straight up.
	var left: PlayerMotor = arena.add_player(Vector2(-2.0, 0), &"left")
	var right: PlayerMotor = arena.add_player(Vector2(2.0, 0), &"right")
	var caster: EnemyLogic = arena.add_caster(Vector2.ZERO)
	arena.ticks(LAUNCH)
	assert_eq(caster.get_aim(), Vector2.UP)
	var bolts: Array[ProjectileSet.Projectile] = caster.get_projectiles().get_projectiles()
	for _i: int in 120:
		if not arena.hurt_events.is_empty():
			break
		arena.ticks(1)
	assert_eq(arena.hurt_events.size(), 2, "both at one contact")
	assert_almost_eq(arena.hurt_times[0], arena.hurt_times[1], TIME, "the same contact")
	assert_eq(left.get_combat_state().get_hp(), 82)
	assert_eq(right.get_combat_state().get_hp(), 82)
	assert_eq_deep(bolts[0].hit_ids, [&"left"] as Array[StringName])
	assert_eq_deep(bolts[1].hit_ids, [&"right"] as Array[StringName])


func test_ac7_only_the_bolt_whose_path_meets_a_wall_is_spent_there() -> void:
	var arena: CasterArena = _arena([-20.0, 20.0])  # Both miss a player standing still.
	arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	var watch: CasterWatch = arena.watch_caster(caster)
	arena.move_bodies = _wall_at_x.bind(caster, 0.5)
	arena.ticks(LAUNCH + 240)
	var walled: Array = watch.seen_at[1]
	var stopped: Dictionary = watch.projectile_at(walled[-1], 1)
	assert_true(stopped["spent"])
	assert_almost_eq(stopped["position"].x, 0.5, TIME, "at the wall")
	# 0.5 / sin(20°) = 1.46 tiles: 30 steps at 6 tiles/s, against 200 to its max distance.
	var at_wall: float = START.distance_to(stopped["position"])
	assert_almost_eq(at_wall, 0.5 / sin(deg_to_rad(20.0)), 1e-5, "where its path meets it")
	var free: Array = watch.seen_at[0]
	var last: Dictionary = watch.projectile_at(free[-1], 0)
	assert_true(last["spent"])
	assert_almost_eq(START.distance_to(last["position"]), 10.0, 1e-5, "flew its max distance")
	assert_gt(free.size(), walled.size())


func test_ac7_a_volley_born_in_a_wall_is_blocked_whole_and_its_serials_stay_used() -> void:
	var arena: CasterArena = _arena(FAN)
	var player: PlayerMotor = arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	var watch: CasterWatch = arena.watch_caster(caster)
	var blocked: Array[int] = []
	arena.move_bodies = _block_first_volley.bind(caster, blocked)
	arena.ticks(LAUNCH)
	assert_eq(blocked, [0, 1, 2] as Array[int], "every bolt reported as a blocked launch")
	assert_eq(watch.at(LAUNCH)["projectiles"].size(), 0, "gone before the contact")
	assert_eq(watch.at(LAUNCH)["hitboxes"], 0)
	assert_eq(caster.get_projectiles().get_next_serial(), 3, "serials stay used")
	arena.ticks(500)
	assert_eq(player.get_combat_state().get_hp(), 82, "only the next volley's middle bolt hits")
	assert_false(watch.seen_at.has(0) or watch.seen_at.has(1) or watch.seen_at.has(2))
	assert_true(watch.seen_at.has(3), "the next volley starts at serial 3")


func test_ac8_owner_death_removes_every_bolt_at_that_contact() -> void:
	var run: Array = _sword_run(true, 1)
	var watch: CasterWatch = run[1]
	var caster: EnemyLogic = run[2]
	var died_at: float = run[3]
	assert_gt(died_at, 0.0, "it died")
	var step: int = roundi(died_at * 120.0)
	assert_eq(watch.at(step)["projectiles"].size(), 3, "all in flight at the killing contact")
	assert_eq(watch.at(step + 1)["projectiles"].size(), 0, "all gone at the next")
	assert_eq(caster.get_live_hitboxes().size(), 0)


func test_ac8_owner_hitstop_changes_no_bolt() -> void:
	var calm: Array = _sword_run(false)
	var hit: Array = _sword_run(true)
	var calm_watch: CasterWatch = calm[1]
	var hit_watch: CasterWatch = hit[1]
	var paused: int = 0
	for step: int in range(LAUNCH, 160):
		assert_eq(hit_watch.at(step)["projectiles"].size(), 3, "step %d" % step)
		assert_eq_deep(hit_watch.at(step)["projectiles"], calm_watch.at(step)["projectiles"])
		if hit_watch.at(step)["hitstop"] > 0.0:
			paused += 1
	assert_gt(paused, 0, "the caster was in hitstop while they flew")


func test_ac8_a_stage_shift_changes_no_bolt() -> void:
	var calm: Array = _stage_run(false)
	var shifted: Array = _stage_run(true)
	var calm_watch: CasterWatch = calm[1]
	var shift_watch: CasterWatch = shifted[1]
	var boss: EnemyLogic = shifted[0].enemies[0]
	assert_eq(boss.get_stage_index(), 1, "it shifted")
	assert_true(
		shift_watch.times_entered(EnemyLogic.State.STAGE_SHIFT).size() == 1, "entered the shift"
	)
	var shift_step: int = roundi(shift_watch.times_entered(EnemyLogic.State.STAGE_SHIFT)[0] * 120)
	# The middle bolt landed on the player before the shift: the other two still fly.
	assert_eq(shift_watch.at(shift_step)["projectiles"].size(), 2, "in flight during the shift")
	for step: int in range(LAUNCH, shift_step + 30):
		assert_eq_deep(shift_watch.at(step)["projectiles"], calm_watch.at(step)["projectiles"])


func test_ac12_snapshot_mid_windup_of_a_volley() -> void:
	var caster: Dictionary = _assert_resumes(_fight.bind(40))
	assert_eq(caster["state"], EnemyLogic.State.WINDUP)
	assert_eq(caster["attack"]["volley_angles_deg"], PackedFloat64Array(FAN))
	assert_eq(caster["projectiles"].size(), 0)


func test_ac12_snapshot_with_a_volley_in_flight() -> void:
	var caster: Dictionary = _assert_resumes(_fight.bind(100))
	assert_eq(caster["projectiles"].size(), 3)
	assert_eq(caster["next_projectile_serial"], 3)


## The caster, its bolt turned into a volley of `angles`.
func _arena(angles: Array) -> CasterArena:
	var arena: CasterArena = CasterArena.new()
	arena.caster_data.attacks[0].volley_angles_deg = PackedFloat64Array(angles)
	return arena


## move_bodies: a wall on the line x = `wall_x`. A bolt whose segment crosses it is reported
## where its path meets it, every other is reported at its plan.
func _wall_at_x(caster: EnemyLogic, wall_x: float) -> void:
	var projectiles: ProjectileSet = caster.get_projectiles()
	for projectile: ProjectileSet.Projectile in projectiles.get_projectiles():
		var reached: Vector2 = projectile.position
		if reached.x > wall_x and projectile.direction.x > 0.0:
			var along: float = (wall_x - projectile.step_start.x) / projectile.direction.x
			reached = projectile.step_start + projectile.direction * maxf(along, 0.0)
		projectiles.report_position(projectile.serial, reached)


## move_bodies: every bolt of the first volley (serials 0–2) is born in a wall.
func _block_first_volley(caster: EnemyLogic, blocked: Array[int]) -> void:
	var projectiles: ProjectileSet = caster.get_projectiles()
	for projectile: ProjectileSet.Projectile in projectiles.get_projectiles().duplicate():
		if projectile.launched_in_step and projectile.serial < 3:
			blocked.append(projectile.serial)
			projectiles.report_blocked_launch(projectile.serial)
		else:
			projectiles.report_position(projectile.serial, projectile.position)


## As test_caster_attack.gd's: a second Warrior walks up to the caster during its windup and,
## if `swing`, presses attack at 0.8 s. The target is the other Warrior, 5 tiles above it, and
## the fan flies at it. Returns [arena, watch, caster, the time it died or -1].
func _sword_run(swing: bool, caster_hp: int = 30) -> Array:
	var arena: CasterArena = _arena(FAN)
	arena.caster_data.max_hp = caster_hp
	arena.add_player(Vector2(0, 5.1), &"sword")  # First: the arena's commands go to it.
	arena.add_player(Vector2(0, -5), &"target")
	var caster: EnemyLogic = arena.add_caster(Vector2.ZERO)
	var watch: CasterWatch = arena.watch_caster(caster)
	var died: Array[float] = []
	var sim_ref: WeakRef = weakref(arena.sim)
	caster.get_combat_state().died.connect(
		func() -> void: died.append((sim_ref.get_ref() as CombatSim).get_time())
	)
	var moves: Dictionary = {}
	for thirtieth: int in 23:
		moves[thirtieth] = Vector2.UP
	arena.play(120, 0, 50, moves, [], [24] if swing else [], Vector2.UP)
	return [arena, watch, caster, died[0] if not died.is_empty() else -1.0]


## A caster boss with one stage at 50 %, whose fan is in flight when, if `shift`, its HP is
## set below 50 % during the recovery. Returns [arena, watch].
func _stage_run(shift: bool) -> Array:
	var arena: CasterArena = _arena(FAN)
	var data: EnemyData = arena.caster_data
	data.max_hp = 100
	data.attack_cooldown = 5.0  # Nothing else starts while the bolts fly.
	var stage_attack: EnemyAttackData = data.attacks[0].duplicate()
	stage_attack.id = &"stage_fan"
	var stages: Array[EnemyStageData] = [BossValues.stage(50, 1.0, stage_attack, 2.0, 5.0)]
	data.stages = stages
	arena.add_player(Vector2(0, -3.0))
	var boss: EnemyLogic = arena.add_caster(Vector2.ZERO)
	var watch: CasterWatch = arena.watch_caster(boss)
	arena.ticks(LAUNCH + 2)
	if shift:
		BossValues.set_hp(boss, 40)
	arena.ticks(150)
	return [arena, watch]


func _fight(ticks: int) -> CasterArena:
	var arena: CasterArena = _arena(FAN)
	arena.add_player()
	arena.add_caster(START)
	arena.ticks(ticks)
	return arena


## As test_caster_snapshot.gd's: restore into a fresh arena, then tick both and compare every
## snapshot (serials, bolt positions, hits, HP). Returns the caster's snapshot.
func _assert_resumes(prepare: Callable) -> Dictionary:
	var unbroken: CasterArena = prepare.call()
	var snapshot: Dictionary = unbroken.sim.to_dict()
	var fresh: CasterArena = _fight(0)
	assert_true(fresh.sim.from_dict(snapshot))
	assert_eq_deep(fresh.sim.to_dict(), snapshot)
	for _i: int in RESUMED_TICKS:
		unbroken.ticks(1)
		fresh.ticks(1)
		assert_eq_deep(fresh.sim.to_dict(), unbroken.sim.to_dict())
	assert_eq(unbroken.hurt_times.size(), 1, "the fan's middle bolt landed")
	assert_eq(fresh.hurt_times, unbroken.hurt_times, "at the same instant after the restore")
	return snapshot["combatants"][&"caster_1"]
