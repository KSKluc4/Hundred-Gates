extends GutTest
## F-006 C7 in core, with stub reports from the move_bodies callable: AC6, AC7c, AC8, AC9, AC20.

const TIME: float = EnemyArena.TIME
const TILES: float = EnemyArena.TILES
const STEP: float = EnemyArena.STEP
const CHARGE: int = BruteArena.CHARGE
## The brute's centre stops here, 2.97 tiles into a +x charge: inside the step ending at 1.05 s.
const WALL: float = 2.97
const STOP_STEP: int = 126
const RATES: Array[int] = EnemyArena.RATES


func test_c7_a_segment_only_while_a_wall_stun_lunge_moves() -> void:
	var arena: BruteArena = _charge_arena(Vector2(6.5, 0))
	var brute: EnemyLogic = arena.enemies[0]
	var probe: StepEndProbe = _probe(arena, brute)
	var segments: Dictionary = {}
	var sim: CombatSim = arena.sim  # Not the arena: it holds this callable.
	arena.move_bodies = func() -> void:
		segments[roundi(sim.get_time() * 120.0)] = brute.get_charge_segment()
	arena.ticks(130)
	for step: int in range(1, 97):
		assert_true(segments[step].is_empty(), "windup: no segment at %d" % step)
	for step: int in range(97, 130):
		assert_eq(segments[step].size(), 2, "lunge: segment at %d" % step)
		assert_almost_eq(
			segments[step][0].distance_to(segments[step][1]), 0.1, TIME, "12 tiles/s for a step"
		)
		assert_true(probe.after_step[step]["segment"].is_empty(), "end_step clears it")
	assert_almost_eq(segments[97][0].x, 0.0, TIME, "starts where the step started")
	assert_almost_eq(segments[97][1].x, 0.1, TIME)


func test_c7_no_segment_for_an_attack_without_a_wall_stun() -> void:
	var arena: BruteArena = _charge_arena(Vector2(6.5, 0))
	arena.brute_data.attacks[CHARGE].wall_stun_duration = 0.0
	var brute: EnemyLogic = arena.enemies[0]
	var seen: Array[int] = [0]
	arena.move_bodies = func() -> void: seen[0] += brute.get_charge_segment().size()
	arena.ticks(130)
	assert_eq(seen[0], 0)
	assert_almost_eq(brute.get_position_tiles().x, 3.4, TILES, "it still lunges")


func test_ac7c_a_full_charge_with_no_wall_recovers_normally_at_every_rate() -> void:
	for rate: int in RATES:
		var label: String = "%d ticks/s" % rate
		# Beyond the charge's reach (6 + 0.9 + 0.35), so no hitstop shifts the timing.
		var arena: BruteArena = _charge_arena(Vector2(0, 7.5))
		var brute: EnemyLogic = arena.enemies[0]
		arena.brute_data.attacks[CHARGE].trigger_max_tiles = 8.0
		arena.restore_value(brute, "aggroed", true)
		var stub: BruteWallStub = BruteWallStub.new(brute, arena.sim).install(arena)
		var watch: EnemyWatch = arena.watch(brute)
		arena.play(rate, 0, 120)
		assert_eq(stub.stop_step(), -1, label)
		assert_eq(stub.reports.size(), 60, "%s: one report per lunge step" % label)
		for entry: Dictionary in stub.reports:
			assert_true(entry["accepted"], label)
		var recovery: float = watch.times_entered(EnemyLogic.State.RECOVERY)[0]
		var idle: float = _idle_after_attack(watch)
		assert_almost_eq(recovery, 1.3, TIME, label)
		assert_almost_eq(idle - recovery, 0.9, TIME, "%s: the normal recovery" % label)
		assert_false(brute.is_wall_stopped(), label)
		assert_almost_eq(brute.get_position_tiles().y, 6.0, TIME, "%s: the full 6 tiles" % label)


func test_ac6_the_stop_applies_after_its_contact_and_lasts_the_stun() -> void:
	var arena: BruteArena = _charge_arena(Vector2(6.5, 0))
	var brute: EnemyLogic = arena.enemies[0]
	var stub: BruteWallStub = BruteWallStub.new(brute, arena.sim, WALL).install(arena)
	var watch: EnemyWatch = arena.watch(brute)
	var probe: StepEndProbe = _probe(arena, brute)
	arena.ticks(STOP_STEP)
	assert_eq(stub.stop_step(), STOP_STEP)
	var report: Dictionary = stub.reports[-1]
	assert_eq(report["state"], EnemyLogic.State.ACTIVE, "between report and contact")
	assert_false(report["wall_stopped"], "between report and contact")
	assert_true(report["has_hitbox"], "the stop contact still has its sector")
	assert_true(report["segment_after"].is_empty(), "the report takes the segment")
	var stop_contact: Dictionary = watch.at(STOP_STEP)
	assert_eq(stop_contact["state"], EnemyLogic.State.ACTIVE)
	assert_true(stop_contact["has_hitbox"])
	assert_almost_eq(stop_contact["position"].x, WALL, TIME, "at its physics position")
	var after: Dictionary = probe.after_step[STOP_STEP]
	assert_eq(after["state"], EnemyLogic.State.RECOVERY, "right after that step")
	assert_true(after["wall_stopped"])
	assert_eq(after["phase_elapsed"], 0.0)
	assert_eq(brute.get_state(), EnemyLogic.State.RECOVERY, "at the tick end")
	assert_true(brute.is_wall_stopped())
	arena.ticks(240)
	var idle: float = _idle_after_attack(watch)
	assert_almost_eq(idle, 1.05 + 1.5, TIME, "the stun lasts 1.5 s from the stop contact")
	assert_eq(watch.times_entered(EnemyLogic.State.RECOVERY).size(), 1)
	assert_almost_eq(watch.at(307)["cooldown"], 1.0 - STEP, TIME, "then the cooldown")
	assert_false(brute.is_wall_stopped(), "cleared when the attack ends")
	assert_almost_eq(watch.at(306)["position"].x, WALL, TIME, "it never moved in the stun")
	assert_eq(stub.reports.size(), STOP_STEP - 96, "no report after the stop")


func test_ac6_the_stop_contact_can_still_hit() -> void:
	var player_at: Vector2 = Vector2(WALL + 1.24, 0)  # Out of reach one step before the stop.
	var arena: BruteArena = _charge_arena(player_at)
	var brute: EnemyLogic = arena.enemies[0]
	BruteWallStub.new(brute, arena.sim, WALL).install(arena)
	arena.ticks(STOP_STEP)
	assert_eq(arena.hurt_times.size(), 1)
	assert_almost_eq(arena.hurt_times[0], STOP_STEP * STEP, TIME, "at the stop contact")
	assert_eq(arena.hurt_events[0].damage, 25)
	assert_true(brute.is_wall_stopped())


func test_ac6_hits_during_the_stun_pause_it_and_never_push() -> void:
	var arena: BruteArena = _charge_arena(Vector2(6.5, 0))
	var brute: EnemyLogic = arena.enemies[0]
	BruteWallStub.new(brute, arena.sim, WALL).install(arena)
	var watch: EnemyWatch = arena.watch(brute)
	arena.ticks(STOP_STEP)
	for _i: int in 42:
		arena.tick(120, Vector2.LEFT, false, false, Vector2.LEFT)
	arena.tick(120, Vector2.ZERO, false, true, Vector2.LEFT)
	arena.ticks(30)
	var hp: int = brute.get_combat_state().get_hp()
	assert_eq(hp, 110, "sword hit 1 landed during the stun")
	assert_eq(brute.get_state(), EnemyLogic.State.RECOVERY)
	assert_almost_eq(brute.get_position_tiles().x, WALL, TIME, "never pushed")
	arena.ticks(200)
	var idle: float = _idle_after_attack(watch)
	var hitstop: float = arena.rules.hitstop_normal
	assert_almost_eq(idle, 1.05 + 1.5 + hitstop, TIME, "paused by its hitstop")
	var last_stun_step: int = roundi(idle * 120.0) - 1
	assert_almost_eq(watch.at(last_stun_step)["position"].x, WALL, TIME, "never pushed")


func test_ac6_death_wins_at_the_stop_contact() -> void:
	var arena: BruteArena = _charge_arena(Vector2(WALL + 1.24, 0))
	arena.brute_data.max_hp = 10
	arena.brute_data.attacks[CHARGE].knockback_tiles = 0.0
	var brute: EnemyLogic = _reset_brute(arena)
	var stub: BruteWallStub = BruteWallStub.new(brute, arena.sim, WALL).install(arena)
	var probe: StepEndProbe = _probe(arena, brute)
	var swords: Array[float] = arena.sword_times
	# Sword hit 1's active (0.08 s windup) opens inside the stop step, ending at 1.05 s.
	arena.ticks(STOP_STEP - 10)
	arena.tick(120, Vector2.ZERO, false, true, Vector2.LEFT)
	arena.ticks(9)
	assert_eq(stub.stop_step(), STOP_STEP)
	assert_eq(swords.size(), 1)
	assert_almost_eq(swords[0], STOP_STEP * STEP, TIME, "the sword lands at the stop contact")
	assert_eq(arena.hurt_times.size(), 1, "the charge's own hit at that contact still lands")
	assert_almost_eq(arena.hurt_times[0], STOP_STEP * STEP, TIME)
	var after: Dictionary = probe.after_step[STOP_STEP]
	assert_eq(after["state"], EnemyLogic.State.DEAD)
	assert_false(after["wall_stopped"])
	assert_eq(brute.get_state(), EnemyLogic.State.DEAD)
	assert_false(brute.is_wall_stopped())


func test_ac8_a_stop_after_active_ended_inside_the_step_at_every_rate() -> void:
	for rate: int in RATES:
		var label: String = "%d ticks/s" % rate
		var arena: BruteArena = _ac8_arena()
		var brute: EnemyLogic = arena.enemies[0]
		var stub: BruteWallStub = BruteWallStub.new(brute, arena.sim, 5.99).install(arena)
		var probe: StepEndProbe = _probe(arena, brute)
		var watch: EnemyWatch = arena.watch(brute)
		var ticks_to_stop: int = ceili(157.0 * rate / 120.0)
		for _i: int in ticks_to_stop:
			arena.tick(rate)
		assert_eq(stub.stop_step(), 157, label)
		var report: Dictionary = stub.reports[-1]
		assert_eq(report["state"], EnemyLogic.State.RECOVERY, "%s: active ended mid-step" % label)
		assert_false(report["wall_stopped"], label)
		var after: Dictionary = probe.after_step[157]
		assert_eq(after["state"], EnemyLogic.State.RECOVERY, label)
		assert_true(after["wall_stopped"], label)
		assert_almost_eq(after["phase_elapsed"], 157.0 / 120.0 - 1.305, TIME, label)
		assert_false(after["attack"].is_empty(), "%s: still latched" % label)
		assert_eq(after["cooldown_remaining"], 0.0, label)
		var tick_end: float = ticks_to_stop / float(rate)
		assert_almost_eq(arena.sim.get_time(), tick_end, TIME, label)
		assert_almost_eq(tick_end, [1.333333, 1.316667, 1.308333][RATES.find(rate)], 0.000001)
		var snapshot: Dictionary = arena.sim.to_dict()
		var saved: Dictionary = snapshot["combatants"][&"brute_1"]
		assert_eq(saved["state"], EnemyLogic.State.RECOVERY, label)
		assert_true(saved["wall_stopped"], label)
		assert_eq(saved.size(), EnemyLogic.SNAPSHOT_KEYS.size(), "%s: no per-step key" % label)
		for key: String in saved:
			assert_true(EnemyLogic.SNAPSHOT_KEYS.has(key), "%s: %s" % [label, key])
		_play_to(arena, rate, 2.9)
		assert_almost_eq(_idle_after_attack(watch), 2.808333, 0.000001, label)
		assert_eq(watch.at(336)["state"], EnemyLogic.State.RECOVERY, "%s: 2.8 s" % label)
		assert_almost_eq(watch.at(337)["cooldown"], 1.0 - (337.0 / 120.0 - 2.805), TIME, label)
		var fresh: BruteArena = _ac8_arena()
		var fresh_brute: EnemyLogic = fresh.enemies[0]
		BruteWallStub.new(fresh_brute, fresh.sim, 5.99).install(fresh)
		_probe(fresh, fresh_brute)
		var fresh_watch: EnemyWatch = fresh.watch(fresh_brute)
		assert_true(fresh.sim.from_dict(snapshot), label)
		_play_to(fresh, rate, 2.9)
		assert_almost_eq(
			fresh_watch.at(337)["cooldown"],
			1.0 - (337.0 / 120.0 - 2.805),
			TIME,
			"%s: restored" % label
		)
		assert_eq(fresh_watch.at(336)["state"], EnemyLogic.State.RECOVERY, label)
		assert_eq_deep(fresh_brute.to_dict(), brute.to_dict())


func test_ac15_the_ac8_charge_with_no_recovery_is_rejected() -> void:
	var data: EnemyData = _ac8_arena().brute_data
	data.attacks[CHARGE].recovery = 0.0
	var errors: PackedStringArray = data.validate(120, Tunables.enemy_combat)
	assert_eq(errors.size(), 1, str(errors))
	assert_string_contains(errors[0], "brute_charge: recovery must be >= 2 combat steps")


func test_ac9_a_report_with_no_segment_is_refused_and_changes_nothing() -> void:
	var arena: BruteArena = _charge_arena(Vector2(6.5, 0))
	var brute: EnemyLogic = arena.enemies[0]
	var results: Array[bool] = []
	var before: Array[Dictionary] = []
	var after: Array[Dictionary] = []
	var sim: CombatSim = arena.sim  # Not the arena: it holds this callable.
	arena.move_bodies = func() -> void:
		var step: int = roundi(sim.get_time() * 120.0)
		if step == 50:  # Windup: no lunge this step.
			before.append(brute.to_dict())
			results.append(brute.report_charge_reach(Vector2.ZERO))
			after.append(brute.to_dict())
		if step == 100:  # A lunge step: the first report counts, a second one doesn't.
			results.append(brute.report_charge_reach(brute.get_charge_segment()[0]))
			before.append(brute.to_dict())
			results.append(brute.report_charge_reach(Vector2.ZERO))
			after.append(brute.to_dict())
	arena.ticks(100)
	assert_push_error("no charge segment")
	assert_push_error("no charge segment")
	assert_eq(results, [false, true, false] as Array[bool])
	assert_eq_deep(after[0], before[0])
	assert_eq_deep(after[1], before[1])
	assert_true(brute.is_wall_stopped(), "the first report at 100 was a stop")


func test_ac20_other_combatants_inherit_the_no_op() -> void:
	var motor: PlayerMotor = PlayerMotor.new()
	motor.setup(CombatArena.warrior(), Tunables.player_combat, Vector2(1, 2), Vector2.DOWN, &"p")
	var before: Dictionary = motor.to_dict()
	motor.end_step()
	assert_eq_deep(motor.to_dict(), before)
	var dummy: DummyLogic = DummyLogic.new()
	var dummy_data: DummyData = load(Tunables.TRAINING_DUMMY_PATH)
	dummy.setup(dummy_data, 120, Vector2.ZERO, 0.0, &"d")
	before = dummy.to_dict()
	dummy.end_step()
	assert_eq_deep(dummy.to_dict(), before)


func test_ac20_the_sim_calls_end_step_once_per_step_in_registration_order() -> void:
	for rate: int in RATES:
		var sim: CombatSim = CombatSim.new()
		sim.setup(120, Tunables.player_combat)
		var order: Array[StringName] = []
		for id: StringName in [&"a", &"b"]:
			var probe: SimProbe = OrderProbe.new(id, order)
			sim.register(probe)
		sim.tick(1.0 / rate)
		var steps: int = 120 / rate
		assert_eq(order.size(), steps * 2, str(rate))
		for index: int in steps:
			assert_eq(order[index * 2], &"a")
			assert_eq(order[index * 2 + 1], &"b")


class OrderProbe:
	extends SimProbe
	var _order: Array[StringName]

	func _init(id: StringName, order: Array[StringName]) -> void:
		super(id)
		_order = order

	func end_step() -> void:
		_order.append(_combat_id)


## A brute at the origin charging a still player at `player_at`, at 120 steps/s.
func _charge_arena(player_at: Vector2) -> BruteArena:
	var arena: BruteArena = BruteArena.new()
	arena.add_player(player_at)
	arena.add_brute(Vector2.ZERO)
	return arena


## setup() again after a test changed the data.
func _reset_brute(arena: BruteArena) -> EnemyLogic:
	var brute: EnemyLogic = arena.enemies[0]
	assert_true(brute.setup(arena.brute_data, arena.enemy_rules, 120, Vector2.ZERO, &"brute_1"))
	return brute


## AC8's charge: windup 0.80, track 0.50, active 0.505, lunge 6.0, recovery 2 steps, stun 1.50.
## The target is 9 tiles out, beyond the wall, so nothing hits and no hitstop shifts the timing.
func _ac8_arena() -> BruteArena:
	var arena: BruteArena = BruteArena.new()
	var charge: EnemyAttackData = arena.brute_data.attacks[CHARGE]
	charge.active = 0.505
	charge.recovery = 2.0 / 120.0
	charge.trigger_max_tiles = 10.0
	arena.add_player(Vector2(9.0, 0))
	var brute: EnemyLogic = arena.add_brute(Vector2.ZERO)
	arena.restore_value(brute, "aggroed", true)
	return arena


func _probe(arena: BruteArena, brute: EnemyLogic) -> StepEndProbe:
	var probe: StepEndProbe = StepEndProbe.new(brute, arena.sim)
	arena.sim.register(probe)
	return probe


func _play_to(arena: BruteArena, rate: int, time: float) -> void:
	while arena.sim.get_time() < time - TIME:
		arena.tick(rate)


## The first time the brute was idle again after its first attack started.
func _idle_after_attack(watch: EnemyWatch) -> float:
	var started: float = watch.times_entered(EnemyLogic.State.WINDUP)[0]
	for time: float in watch.times_entered(EnemyLogic.State.IDLE):
		if time > started:
			return time
	return -1.0
