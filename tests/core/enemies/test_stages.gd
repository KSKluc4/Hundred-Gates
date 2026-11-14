extends GutTest
## F-007 T3: stages, the entry rule and the stage shift (C3, C5-C8): AC2-AC6, AC16, AC18,
## AC19, on a real sim at 120 steps/s. Step indices are sim time x 120.
##
## The fixture is a 400 HP chaser, never pushed (PR-7), with one stage at 50 %. Stage 0's
## swipe never triggers (band 5-6), so it chases; stage 1's swipe triggers within 2 tiles.
## The player stands at the origin and its sword hit 1 lands at step 10 (F-004 AC12).

const TIME: float = EnemyArena.TIME
const NOT_A_RANGE: float = 0.01
const CHASING_START: Vector2 = Vector2(0, 1.95)
const PLANTED_START: Vector2 = Vector2(0, 1.6)
## Step whose start first finds the enemy out of the hit's 0.05 s of hitstop (6 steps).
const AFTER_HITSTOP: int = 16


func test_ac2_the_stage_is_entered_at_the_first_step_start_after_the_hitstop() -> void:
	var arena: CasterArena = _stage_arena(1.2)
	var run: Dictionary = _hit_once(arena, 201)
	var enemy: EnemyLogic = run["enemy"]
	var watch: StageWatch = run["watch"]
	assert_eq(enemy.get_combat_state().get_hp(), 191)
	for step: int in range(0, AFTER_HITSTOP):
		assert_eq(watch.at_start[step]["stage"], 0, "step %d" % step)
		assert_eq(watch.at_start[step]["changes"], 0, "step %d" % step)
	for step: int in range(10, AFTER_HITSTOP):
		assert_true(watch.at_start[step]["in_hitstop"], "step %d is in the hitstop" % step)
	var entry: Dictionary = watch.at_start[AFTER_HITSTOP]
	assert_eq(entry["stage"], 1)
	assert_eq(entry["state"], EnemyLogic.State.STAGE_SHIFT)
	assert_eq(entry["attack"], &"", "no attack in the entry step")
	assert_almost_eq(float(entry["shift_left"]), 1.2, TIME)
	assert_eq(watch.changes.size(), 1)
	assert_eq(watch.changes[0][0], 1, "stage_changed(1)")
	assert_eq(enemy.get_stage_index(), 1)


func test_ac2_with_no_hitstop_the_stage_is_entered_at_the_next_step_start() -> void:
	var arena: CasterArena = _stage_arena(1.2)
	arena.rules.hitstop_normal = 0.0
	var run: Dictionary = _hit_once(arena, 201)
	var watch: StageWatch = run["watch"]
	assert_eq(watch.at_start[9]["stage"], 0)
	assert_eq(watch.at_start[10]["stage"], 1)
	assert_eq(watch.at_start[10]["state"], EnemyLogic.State.STAGE_SHIFT)
	assert_eq(watch.changes.size(), 1)


func test_ac2_hp_above_the_line_enters_nothing() -> void:
	var arena: CasterArena = _stage_arena(1.2)
	var run: Dictionary = _hit_once(arena, 211)  # 201 after the hit: 201 * 100 > 400 * 50.
	assert_eq(run["enemy"].get_stage_index(), 0)
	assert_eq(run["watch"].changes.size(), 0)


func test_ac3_a_running_pattern_finishes_before_the_stage_is_entered() -> void:
	var arena: CasterArena = _stage_arena(1.2)
	var root: EnemyAttackData = arena.chaser_data.attacks[0]
	root.id = &"root"
	root.trigger_min_tiles = 0.0
	root.trigger_max_tiles = 2.0
	root.lunge_tiles = 0.0
	root.range_tiles = NOT_A_RANGE
	var next: EnemyAttackData = root.duplicate()
	next.id = &"next"
	root.follow_up = next
	var run: Dictionary = _hit_once(arena, 201, PLANTED_START, 400)
	var watch: StageWatch = run["watch"]
	# Root: windup 0.5 + 0.05 hitstop, active 0.1, recovery 0.6; then next: 0.5, 0.1, 0.6.
	assert_eq(watch.at_start[1]["attack"], &"root")
	assert_eq(watch.at_start[150]["attack"], &"next", "the follow-up ran in stage 0")
	assert_eq(watch.at_start[293]["state"], EnemyLogic.State.RECOVERY)
	for step: int in range(0, 294):
		assert_eq(watch.at_start[step]["stage"], 0, "step %d" % step)
	assert_eq(watch.at_start[294]["stage"], 1, "the first step start after the last recovery")
	assert_eq(watch.at_start[294]["state"], EnemyLogic.State.STAGE_SHIFT)
	assert_eq(watch.changes.size(), 1)


func test_ac4_one_hit_past_two_lines_enters_the_deepest_stage_directly() -> void:
	var arena: CasterArena = _stage_arena(1.2)
	arena.chaser_data.stages[0].enter_at_hp_percent = 60
	var second: EnemyStageData = arena.chaser_data.stages[0].duplicate()
	second.enter_at_hp_percent = 30
	second.shift_duration = 0.9
	arena.chaser_data.stages.append(second)
	arena.class_data.attack_chain[0].damage = 200
	var run: Dictionary = _hit_once(arena, 241, CHASING_START, 150)  # 41 after: below 30 %.
	var watch: StageWatch = run["watch"]
	assert_eq(run["enemy"].get_combat_state().get_hp(), 41)
	assert_eq(watch.changes.size(), 1, "one signal")
	assert_eq(watch.changes[0][0], 2, "stage_changed(2)")
	var entry: Dictionary = watch.at_start[AFTER_HITSTOP]
	assert_eq(entry["stage"], 2)
	assert_almost_eq(float(entry["shift_left"]), 0.9, TIME, "stage 2's shift")
	assert_eq(watch.first_start_not_in(EnemyLogic.State.STAGE_SHIFT, AFTER_HITSTOP), 124)


func test_ac5_a_hit_in_the_shift_lands_but_only_delays_its_end() -> void:
	var arena: CasterArena = _stage_arena(1.2)
	var enemy: EnemyLogic = _setup(arena, 201)
	var watch: StageWatch = _watch(arena, enemy)
	var contacts: EnemyWatch = arena.watch(enemy)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(59)  # To step 60: in the shift since step 16.
	assert_eq(enemy.get_state(), EnemyLogic.State.STAGE_SHIFT)
	var hp: int = enemy.get_combat_state().get_hp()
	var position: Vector2 = enemy.get_position_tiles()
	var hitstop: float = 0.0
	arena.tick(120, Vector2.ZERO, false, true)
	for _i: int in 30:
		arena.tick()
		if hitstop == 0.0 and enemy.get_combat_state().get_hp() < hp:
			hitstop = enemy.get_combat_state().get_hitstop_remaining()
	assert_lt(enemy.get_combat_state().get_hp(), hp, "it takes the damage")
	assert_gt(hitstop, 0.0, "and the hitstop")
	arena.ticks(200)
	assert_eq(contacts.times_entered(EnemyLogic.State.KNOCKBACK), [], "never pushed")
	var end: int = watch.first_start_not_in(EnemyLogic.State.STAGE_SHIFT, AFTER_HITSTOP)
	assert_eq(end, AFTER_HITSTOP + 144 + roundi(hitstop * 120.0), "later by the hitstop")
	for step: int in range(AFTER_HITSTOP + 1, end):
		assert_eq(watch.at_start[step]["state"], EnemyLogic.State.STAGE_SHIFT, "step %d" % step)
		assert_eq(watch.at_start[step]["position"], position, "doesn't move (step %d)" % step)
		assert_false(contacts.at(step)["has_hitbox"], "no hitbox (step %d)" % step)


func test_ac6_the_cooldown_keeps_counting_through_the_shift() -> void:
	var arena: CasterArena = _stage_arena(1.2)
	var enemy: EnemyLogic = _setup(arena, 201)
	arena.restore_value(enemy, "cooldown_remaining", 0.4 + 10.0 / 120.0)
	var watch: StageWatch = _watch(arena, enemy)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(200)
	assert_almost_eq(float(watch.changes[0][2]), 0.4, TIME, "0.4 s left at the entry")
	var shift_end: int = AFTER_HITSTOP + 144
	assert_eq(watch.at_start[shift_end - 1]["state"], EnemyLogic.State.STAGE_SHIFT)
	assert_eq(watch.at_start[shift_end]["state"], EnemyLogic.State.WINDUP, "at once")
	assert_eq(watch.at_start[shift_end]["attack"], &"stage_swipe")


func test_ac6_a_zero_shift_still_waits_for_the_cooldown() -> void:
	var arena: CasterArena = _stage_arena(0.0)
	var enemy: EnemyLogic = _setup(arena, 201)
	arena.restore_value(enemy, "cooldown_remaining", 0.4 + 10.0 / 120.0)
	var watch: StageWatch = _watch(arena, enemy)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(100)
	assert_eq(watch.at_start[AFTER_HITSTOP]["stage"], 1)
	assert_eq(watch.first_start_in(EnemyLogic.State.STAGE_SHIFT), -1, "no shift state")
	assert_eq(watch.first_start_in(EnemyLogic.State.WINDUP), AFTER_HITSTOP + 48, "after 0.4 s")


func test_ac19_a_zero_shift_decides_with_the_new_stage_in_the_same_step() -> void:
	var arena: CasterArena = _stage_arena(0.0)
	var run: Dictionary = _hit_once(arena, 201)
	var watch: StageWatch = run["watch"]
	var entry: Dictionary = watch.at_start[AFTER_HITSTOP]
	assert_eq(entry["stage"], 1)
	assert_eq(entry["state"], EnemyLogic.State.WINDUP)
	assert_eq(entry["attack"], &"stage_swipe", "the stage 1 attack, not the stage 0 one")
	assert_eq(watch.changes.size(), 1)
	assert_eq(watch.changes[0][0], 1)


func test_c4_a_stage_swaps_move_speed_and_cooldown() -> void:
	var arena: CasterArena = _stage_arena(0.0)
	arena.chaser_data.stages[0].move_speed = 1.5
	arena.chaser_data.stages[0].attack_cooldown = 0.3
	var run: Dictionary = _hit_once(arena, 201)
	var enemy: EnemyLogic = run["enemy"]
	assert_eq(enemy.get_current_move_speed(), 1.5)
	assert_eq(enemy.get_current_attack_cooldown(), 0.3)
	assert_eq(enemy.get_current_attacks()[0].id, &"stage_swipe")


func test_c5_the_stage_index_never_goes_back_when_hp_comes_back() -> void:
	var arena: CasterArena = _stage_arena(0.0)
	var run: Dictionary = _hit_once(arena, 201)
	var enemy: EnemyLogic = run["enemy"]
	enemy.get_combat_state().refill()
	arena.ticks(30)
	assert_eq(enemy.get_stage_index(), 1)
	assert_eq(run["watch"].changes.size(), 1)


func test_ac16_the_debug_reset_goes_back_to_stage_0() -> void:
	var arena: CasterArena = _stage_arena(1.2)
	var run: Dictionary = _hit_once(arena, 201)
	var enemy: EnemyLogic = run["enemy"]
	assert_eq(enemy.get_state(), EnemyLogic.State.STAGE_SHIFT)
	assert_true(enemy.setup(arena.chaser_data, arena.enemy_rules, 120, Vector2.ZERO, &"chaser_1"))
	assert_eq(enemy.get_stage_index(), 0)
	assert_eq(enemy.get_stage_shift_left(), 0.0)
	assert_eq(enemy.get_state(), EnemyLogic.State.IDLE)
	assert_null(enemy.get_running_attack())
	assert_eq(enemy.get_combat_state().get_hp(), 400)
	assert_eq(enemy.get_current_attacks()[0].id, &"chaser_swipe")


func test_ac18_a_bolt_in_flight_keeps_flying_and_hits_during_the_shift() -> void:
	var arena: CasterArena = CasterArena.new()
	var data: EnemyData = arena.caster_data
	data.attacks[0].trigger_max_tiles = 10.0
	data.stages.append(BossValues.stage(50, 5.0, data.attacks[0].duplicate(), 2.5, 1.2))
	arena.add_player(Vector2(0, 9.5))
	var caster: EnemyLogic = arena.add_caster(Vector2.ZERO)
	arena.restore_value(caster, "aggroed", true)
	var watch: StageWatch = _watch(arena, caster)
	var bolts: Dictionary = {}
	var sector: Array[bool] = [false]
	for step: int in 400:
		if step == 100:  # In the bolt's recovery: the line is crossed while committed.
			BossValues.set_hp(caster, 15)
		arena.tick()
		var flying: Array[ProjectileSet.Projectile] = caster.get_projectiles().get_projectiles()
		if caster.get_state() == EnemyLogic.State.STAGE_SHIFT:
			bolts[step + 1] = flying.map(_bolt_position)
			sector[0] = sector[0] or caster.get_live_hitbox() != null
	var entry: int = watch.first_start_in(EnemyLogic.State.STAGE_SHIFT)
	assert_eq(entry, 180, "free after the bolt's recovery (0.6 + 0.1 + 0.8 s)")
	assert_eq(bolts[entry + 1].size(), 1, "the bolt is still in flight")
	assert_almost_eq(bolts[entry + 13][0].y - bolts[entry + 1][0].y, 6.0 * 0.1, TIME, "6 tiles/s")
	assert_eq(arena.hurt_times.size(), 1, "it hit the player")
	if arena.hurt_times.size() == 1:
		var hit_step: int = roundi(arena.hurt_times[0] * 120.0)
		assert_eq(
			watch.at_start[hit_step - 1]["state"], EnemyLogic.State.STAGE_SHIFT, "in the shift"
		)
		assert_eq(arena.hurt_events[0].damage, 18)
		assert_almost_eq(arena.hurt_events[0].direction.angle(), Vector2.DOWN.angle(), TIME)
		assert_gt(arena.hurt_events[0].knockback_tiles, 0.0, "along its flight")
	for step: int in bolts:
		assert_lte(bolts[step].size(), 1, "no new bolt in the shift (step %d)" % step)
	assert_false(sector[0], "no sector hitbox in the shift")


## A CasterArena only for its restore_value().
func _stage_arena(shift: float) -> CasterArena:
	var arena: CasterArena = CasterArena.new()
	var data: EnemyData = arena.chaser_data
	data.max_hp = 400
	data.knockback_scale = 0.0
	var swipe: EnemyAttackData = data.attacks[0]
	swipe.trigger_min_tiles = 5.0
	swipe.trigger_max_tiles = 6.0
	var stage_swipe: EnemyAttackData = swipe.duplicate()
	stage_swipe.id = &"stage_swipe"
	stage_swipe.trigger_min_tiles = 0.0
	stage_swipe.trigger_max_tiles = 2.0
	stage_swipe.lunge_tiles = 0.0
	stage_swipe.range_tiles = NOT_A_RANGE
	var stages: Array[EnemyStageData] = [BossValues.stage(50, shift, stage_swipe, 3.0, 0.8)]
	data.stages = stages
	return arena


func _setup(arena: EnemyArena, hp: int, at: Vector2 = CHASING_START) -> EnemyLogic:
	arena.add_player(Vector2.ZERO)
	var enemy: EnemyLogic = arena.add_chaser(at)
	BossValues.set_hp(enemy, hp)
	return enemy


func _watch(arena: EnemyArena, enemy: EnemyLogic) -> StageWatch:
	var watch: StageWatch = StageWatch.new(enemy, arena.sim)
	arena.sim.register(watch)
	return watch


## One sword hit 1 at step 10, then `ticks` more.
func _hit_once(
	arena: EnemyArena, hp: int, at: Vector2 = CHASING_START, ticks: int = 40
) -> Dictionary:
	var enemy: EnemyLogic = _setup(arena, hp, at)
	var watch: StageWatch = _watch(arena, enemy)
	arena.tick(120, Vector2.ZERO, false, true)
	arena.ticks(ticks)
	return {"enemy": enemy, "watch": watch}


func _bolt_position(projectile: ProjectileSet.Projectile) -> Vector2:
	return projectile.position
