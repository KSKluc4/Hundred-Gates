extends GutTest
## F-005 AC7–AC15 and AC27: the caster's attack and its projectiles on a real CombatSim.

const TIME: float = EnemyArena.TIME
const TILES: float = EnemyArena.TILES
const START: Vector2 = Vector2(0, 6.52)
## AC8, AC14: walks straight up from below the caster during its windup.
const SWORD_START: Vector2 = Vector2(0, 5.1)


func test_ac7_one_projectile_per_attack_at_the_windup_end_with_serials_in_order() -> void:
	var arena: CasterArena = CasterArena.new()
	arena.caster_data.attack_cooldown = 0.0
	arena.add_player()
	# 6 tiles: each hit pushes the player 0.5 away, and it stays within the 7-tile range.
	var start: Vector2 = Vector2(0, 6.0)
	var caster: EnemyLogic = arena.add_caster(start)
	var watch: CasterWatch = arena.watch_caster(caster)
	arena.ticks(450)
	_assert_steps(watch.times_entered(EnemyLogic.State.ACTIVE), [72, 252, 432], "")
	assert_eq(watch.seen_at.keys(), [0, 1, 2])
	for serial: int in 3:
		var launch_step: int = 72 + 180 * serial
		assert_eq(watch.seen_at[serial][0], launch_step, "serial %d" % serial)
		var launched: Dictionary = watch.projectile_at(launch_step, serial)
		_assert_tiles(launched["position"], start, "at the caster")
	for step: int in watch.contacts:
		assert_false(watch.at(step)["own_hitbox"], "its body never has a hitbox (%d)" % step)


func test_ac7_it_flies_along_the_locked_aim() -> void:
	var arena: CasterArena = CasterArena.new()
	var player: PlayerMotor = arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	var watch: CasterWatch = arena.watch_caster(caster)
	arena.play(120, 0, 22, {12: Vector2.RIGHT, 13: Vector2.RIGHT, 14: Vector2.RIGHT})
	assert_gt(player.get_position_tiles().x, 0.3, "the player stepped aside after the lock")
	assert_eq(watch.projectile_at(72)["direction"], Vector2.UP, "aim locked at 0.35")
	assert_eq(caster.get_aim(), Vector2.UP)


func test_ac7_a_launch_inside_a_step_flies_the_rest_of_it() -> void:
	var arena: CasterArena = CasterArena.new()
	arena.caster_data.attack.windup = 0.605
	arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	var watch: CasterWatch = arena.watch_caster(caster)
	arena.ticks(73)
	var launched: Dictionary = watch.projectile_at(73)
	assert_almost_eq(launched["position"].y, START.y - 6.0 * (73.0 / 120.0 - 0.605), TIME)


func test_ac8_it_flies_max_distance_over_speed_and_its_casters_hitstop_changes_nothing() -> void:
	var calm: Array = _sword_run(false)
	var hit: Array = _sword_run(true)
	var calm_watch: CasterWatch = calm[1]
	var hit_watch: CasterWatch = hit[1]
	var caster: EnemyLogic = hit[2]
	assert_gt(caster.get_combat_state().get_hp(), 0, "alive")
	var paused: int = 0
	for step: int in range(72, 161):
		assert_eq_deep(hit_watch.at(step)["projectiles"], calm_watch.at(step)["projectiles"])
		if hit_watch.at(step)["hitstop"] > 0.0:
			paused += 1
	assert_gt(paused, 0, "the caster was in hitstop while it flew")


func test_ac8_max_distance_is_exact() -> void:
	var arena: CasterArena = CasterArena.new()
	arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	var watch: CasterWatch = arena.watch_caster(caster)
	arena.play(120, 0, 70, {47: Vector2.DOWN}, [47])  # Run B: the dash goes through it.
	assert_eq(watch.seen_at[0][-1], 72 + 200, "10 / 6 s after launch")
	assert_almost_eq(watch.projectile_at(272)["position"].distance_to(START), 10.0, TIME)


func test_ac9_two_players_on_one_projectile_only_the_first_registered_is_hit() -> void:
	for swap: bool in [false, true]:
		var arena: CasterArena = CasterArena.new()
		var ids: Array[StringName] = [&"player_a", &"player_b"]
		var spots: Array[Vector2] = [Vector2.ZERO, Vector2(0.1, 0)]
		if swap:
			ids.reverse()
			spots.reverse()
		for index: int in 2:
			arena.add_player(spots[index], ids[index])
		var caster: EnemyLogic = arena.add_caster(START)
		var watch: CasterWatch = arena.watch_caster(caster)
		arena.ticks(192)
		var bolt: Vector2 = watch.projectile_at(191)["position"]
		for player: PlayerMotor in arena.players:
			assert_lt(bolt.distance_to(player.get_position_tiles()), 0.6, "both overlap at 191")
		_assert_steps(arena.hurt_times, [191], "one hit")
		assert_eq(arena.hurt_events[0].target_id, ids[0], "the first registered")
		assert_eq(arena.players[1].get_combat_state().get_hp(), 100, "the other untouched")
		assert_eq(watch.at(192)["projectiles"].size(), 0, "gone at the next step")


func test_ac10_the_caster_gets_no_hitstop_and_hit_landed_fires_once() -> void:
	var arena: CasterArena = CasterArena.new()
	var player: PlayerMotor = arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	arena.ticks(190)
	watch_signals(caster.get_combat_state())
	var before: float = caster.get_combat_state().get_hitstop_remaining()
	arena.ticks(1)
	assert_eq(player.get_combat_state().get_hp(), 82)
	assert_almost_eq(player.get_combat_state().get_hitstop_remaining(), 0.05, TIME)
	assert_eq(caster.get_combat_state().get_hitstop_remaining(), before)
	assert_signal_emit_count(caster.get_combat_state(), "hit_landed", 1)


func test_ac11_an_off_centre_hit_pushes_along_the_flight() -> void:
	var arena: CasterArena = CasterArena.new()
	var player: PlayerMotor = arena.add_player()
	arena.add_caster(START)
	arena.play(120, 0, 14, {12: Vector2.RIGHT, 13: Vector2.RIGHT})  # After the 0.35 lock.
	arena.ticks(10)  # Its 0.04 s of decel.
	var offset: float = player.get_position_tiles().x
	assert_gt(offset, 0.1, "off the line")
	arena.ticks(190)
	assert_eq(arena.hurt_events.size(), 1)
	assert_eq(arena.hurt_events[0].direction, Vector2.UP, "not from the bolt's centre")
	assert_almost_eq(player.get_position_tiles().x, offset, TIME, "no sideways push")


func test_ac12_dash_iframes_skip_unmarked_and_the_first_contact_after_hits() -> void:
	var arena: CasterArena = CasterArena.new()
	arena.class_data.dash_distance = 0.01  # It stays in the bolt's way.
	var player: PlayerMotor = arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	var watch: CasterWatch = arena.watch_caster(caster)
	arena.play(120, 0, 48, {}, [47])  # Dash at 188/120: i-frames to 201.2/120.
	arena.ticks(202 - 192)
	for step: int in range(191, 202):
		var bolt: Vector2 = watch.projectile_at(step)["position"]
		assert_lt(bolt.distance_to(player.get_position_tiles()), 0.6, "overlaps at %d" % step)
	_assert_steps(arena.hurt_times, [202], "the first contact after the i-frames")
	assert_eq(player.get_combat_state().get_hp(), 82)


func test_ac13_no_candidate_over_another_enemy_a_dummy_or_its_own_caster() -> void:
	var arena: CasterArena = CasterArena.new()
	arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	var chaser: EnemyLogic = arena.add_chaser(Vector2(0, 4.0), &"chaser_1")
	chaser.set_ai_enabled(false)
	var dummy: DummyLogic = DummyLogic.new()
	dummy.setup(CombatArena.dummy_values(), 120, Vector2(0, 2.0), 0.0, &"dummy")
	arena.sim.register(dummy)
	var watch: CasterWatch = arena.watch_caster(caster)
	arena.ticks(189)
	assert_eq(watch.candidates_seen, 0, "it flew over the caster, the chaser and the dummy")
	_assert_tiles(
		watch.projectile_at(189)["position"], Vector2(0, START.y - 6.0 * (189 - 72) / 120.0), ""
	)
	assert_eq(chaser.get_combat_state().get_hp(), 50)
	assert_eq(dummy.get_combat_state().get_hp(), 200)
	assert_eq(caster.get_combat_state().get_hp(), 30)


func test_ac14_killing_a_caster_removes_its_projectiles_at_that_contact() -> void:
	var run: Array = _sword_run(true, 1)
	var arena: CasterArena = run[0]
	var watch: CasterWatch = run[1]
	var caster: EnemyLogic = run[2]
	var died_at: float = run[3]
	assert_eq(caster.get_state(), EnemyLogic.State.DEAD)
	var step: int = roundi(died_at * 120.0)
	assert_eq(watch.at(step)["projectiles"].size(), 1, "in flight at the killing contact")
	assert_eq(watch.at(step + 1)["projectiles"].size(), 0)
	assert_eq(caster.get_projectiles().get_projectiles().size(), 0)
	assert_eq(caster.get_live_hitboxes().size(), 0)
	assert_eq(arena.players[1].get_combat_state().get_hp(), 100, "it never reached its target")


func test_ac14_a_hit_found_at_the_killing_contact_still_lands_in_both_orders() -> void:
	for caster_first: bool in [false, true]:
		var label: String = "caster first" if caster_first else "player first"
		var arena: CasterArena = CasterArena.new()
		arena.caster_data.max_hp = 1
		var caster: EnemyLogic
		var player: PlayerMotor
		if caster_first:
			caster = arena.add_caster(Vector2(0, 0.98))
			player = arena.add_player()
		else:
			player = arena.add_player()
			caster = arena.add_caster(Vector2(0, 0.98))
		var died: Array[float] = []
		_record_death(caster, arena.sim, died)
		arena.ticks(70)
		arena.tick(120, Vector2.ZERO, false, true)  # Hit 1 is active from 79.6/120.
		arena.ticks(10)
		_assert_steps(died, [80], label)
		_assert_steps(arena.hurt_times, [80], "%s: the bolt lands at the same contact" % label)
		assert_eq(player.get_combat_state().get_hp(), 82, label)
		assert_eq(caster.get_projectiles().get_projectiles().size(), 0, label)


func test_ac15_a_report_short_of_the_plan_is_a_wall_stop() -> void:
	var arena: CasterArena = CasterArena.new()
	var player: PlayerMotor = arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	var watch: CasterWatch = arena.watch_caster(caster)
	var reached: Array[Vector2] = []
	arena.move_bodies = _report_once.bind(arena.sim, caster, 100, 0.03, reached)
	arena.ticks(150)
	var stopped: Dictionary = watch.projectile_at(100)
	assert_true(stopped["spent"])
	assert_eq(stopped["position"], reached[0], "at the reported position")
	assert_eq(watch.at(100)["hitboxes"], 1, "it gets that contact")
	assert_null(watch.projectile_at(101), "gone at the next step")
	assert_eq(player.get_combat_state().get_hp(), 100)


func test_ac15_a_report_equal_to_the_plan_or_within_epsilon_changes_nothing() -> void:
	for shortfall: float in [0.0, 0.000001]:
		var arena: CasterArena = CasterArena.new()
		var player: PlayerMotor = arena.add_player()
		var caster: EnemyLogic = arena.add_caster(START)
		var watch: CasterWatch = arena.watch_caster(caster)
		arena.move_bodies = _report_once.bind(
			arena.sim, caster, 100, shortfall, [] as Array[Vector2]
		)
		arena.ticks(192)
		assert_false(watch.projectile_at(100)["spent"], str(shortfall))
		_assert_steps(arena.hurt_times, [191], "the run is unchanged (%s)" % shortfall)
		assert_eq(player.get_combat_state().get_hp(), 82)


func test_ac27_a_blocked_launch_never_hits_and_its_serial_stays_used() -> void:
	for windup: float in [0.6, 0.605]:
		var label: String = "windup %s" % windup
		var arena: CasterArena = _ac27(windup)
		var player: PlayerMotor = arena.players[0]
		var caster: EnemyLogic = arena.enemies[0]
		var watch: CasterWatch = arena.watch_caster(caster)
		var blocked: Array[int] = []
		arena.move_bodies = _block_serial_zero.bind(arena.sim, caster, blocked)
		var launch_step: int = ceili(windup * 120.0 - TIME)
		arena.ticks(launch_step)
		assert_eq(blocked, [launch_step], "%s: reported in its own step" % label)
		assert_eq(watch.at(launch_step)["projectiles"].size(), 0, "%s: gone before contact" % label)
		assert_eq(watch.at(launch_step)["hitboxes"], 0, "%s: never a live hitbox" % label)
		arena.ticks(1)
		assert_eq(caster.get_projectiles().get_projectiles().size(), 0, label)
		assert_eq(player.get_combat_state().get_hp(), 100, "%s: not hit" % label)
		arena.ticks(400)  # It backs off to 3 tiles during the cooldown, then shoots again.
		assert_eq(watch.seen_at.keys(), [1], "%s: the next launch is serial 1" % label)
		assert_eq(player.get_combat_state().get_hp(), 82, "%s: and that one hits" % label)


func test_ac27_control_the_same_launch_unblocked_hits_at_that_contact() -> void:
	for windup: float in [0.6, 0.605]:
		var arena: CasterArena = _ac27(windup)
		arena.ticks(80)
		_assert_steps(arena.hurt_times, [ceili(windup * 120.0 - TIME)], "windup %s" % windup)


func test_ac27_a_blocked_report_for_one_launched_earlier_changes_nothing() -> void:
	var arena: CasterArena = CasterArena.new()
	var player: PlayerMotor = arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	arena.ticks(100)
	var before: Dictionary = caster.to_dict()
	assert_false(caster.get_projectiles().report_blocked_launch(0))
	assert_push_error("not launched this step")
	assert_eq_deep(caster.to_dict(), before)
	arena.ticks(92)
	_assert_steps(arena.hurt_times, [191], "it still lands")
	assert_eq(player.get_combat_state().get_hp(), 82)


## Player at (0, 6.0), caster at (0, 6.52): it shoots at 0.52, and the launch circle overlaps
## the player.
func _ac27(windup: float) -> CasterArena:
	var arena: CasterArena = CasterArena.new()
	arena.caster_data.attack.windup = windup
	arena.add_player(Vector2(0, 6.0))
	arena.add_caster(START)
	return arena


## move_bodies for AC27: serial 0's launch is blocked, every other report is the plan.
func _block_serial_zero(sim: CombatSim, caster: EnemyLogic, blocked: Array[int]) -> void:
	var projectiles: ProjectileSet = caster.get_projectiles()
	for projectile: ProjectileSet.Projectile in projectiles.get_projectiles().duplicate():
		if projectile.serial == 0 and projectile.launched_in_step:
			blocked.append(roundi(sim.get_time() * 120.0))
			projectiles.report_blocked_launch(0)
		else:
			projectiles.report_position(projectile.serial, projectile.position)


## move_bodies for AC15: at `step`, projectile 0 is reported `shortfall` short of its plan.
func _report_once(
	sim: CombatSim, caster: EnemyLogic, step: int, shortfall: float, reached: Array[Vector2]
) -> void:
	if roundi(sim.get_time() * 120.0) != step:
		return
	var projectile: ProjectileSet.Projectile = caster.get_projectiles().get_projectiles()[0]
	var at: Vector2 = projectile.position - projectile.direction * shortfall
	reached.append(at)
	caster.get_projectiles().report_position(0, at)


## AC8, AC14: a second Warrior walks up to the caster during its windup and, if `swing`,
## presses attack at 0.8 s. The caster's target is the other Warrior, 5 tiles above it.
## Returns [arena, watch, caster, the time it died or -1].
func _sword_run(swing: bool, caster_hp: int = 30) -> Array:
	var arena: CasterArena = CasterArena.new()
	arena.caster_data.max_hp = caster_hp
	arena.add_player(SWORD_START, &"sword")  # First: the arena's commands go to it.
	arena.add_player(Vector2(0, -5), &"target")
	var caster: EnemyLogic = arena.add_caster(Vector2.ZERO)
	var watch: CasterWatch = arena.watch_caster(caster)
	var died: Array[float] = []
	_record_death(caster, arena.sim, died)
	var moves: Dictionary = {}
	for thirtieth: int in 23:
		moves[thirtieth] = Vector2.UP
	arena.play(120, 0, 50, moves, [], [24] if swing else [], Vector2.UP)
	assert_eq(watch.projectile_at(72)["direction"], Vector2.UP, "aimed at the target")
	return [arena, watch, caster, died[0] if not died.is_empty() else -1.0]


## Weakly: the caster's signal holding the sim would keep both alive forever.
func _record_death(caster: EnemyLogic, sim: CombatSim, died: Array[float]) -> void:
	var sim_ref: WeakRef = weakref(sim)
	caster.get_combat_state().died.connect(
		func() -> void: died.append((sim_ref.get_ref() as CombatSim).get_time())
	)


func _assert_steps(actual: Array, expected_steps: Array, label: String) -> void:
	assert_eq(actual.size(), expected_steps.size(), "%s: %s" % [label, actual])
	for index: int in mini(actual.size(), expected_steps.size()):
		assert_almost_eq(float(actual[index]), expected_steps[index] / 120.0, TIME, label)


func _assert_tiles(actual: Vector2, expected: Vector2, label: String) -> void:
	assert_almost_eq(actual.x, expected.x, TILES, label)
	assert_almost_eq(actual.y, expected.y, TILES, label)
