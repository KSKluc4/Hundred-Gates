# gdlint:disable=max-public-methods
extends GutTest
## F-014 T3 (AC13, AC14, C6, C10, C15): the director's slot in CombatSim.tick(), the snapshot rule,
## the same scripted run at three tick rates, and a room restored in the middle of a warning.
## Without a director the sim is what it was.

const RATES: Array[int] = [30, 60, 120]
const WARNING_STEPS: int = 96
const STEP: float = 1.0 / 120.0

var _rules: FloorTunables


## Logs each moment of a step it takes part in, in the order the sim calls them.
class Tracer:
	extends SimProbe

	var log: Array[String] = []
	var times: Array[float] = []
	var seen_view: CombatView = null
	var _sim_ref: WeakRef

	func _init(sim: CombatSim) -> void:
		super(&"tracer")
		_team = Team.ENEMY
		_position = Vector2(10000, 10000)
		_sim_ref = weakref(sim)

	func note(event: String) -> void:
		log.append(event)
		times.append((_sim_ref.get_ref() as CombatSim).get_time())

	func sense(view: CombatView) -> void:
		seen_view = view
		note("sense")

	func step(duration: float) -> void:
		super(duration)
		note("step")

	func fire_due_actions() -> void:
		note("fire")

	func get_live_hitbox() -> Hitbox:
		note("contact")
		return null

	func end_step() -> void:
		note("end")


## Writes its calls into the tracer's log.
class SpyWaves:
	extends RoomWaves

	var tracer: Tracer
	var views: Array[CombatView] = []
	var durations: Array[float] = []

	func step(duration: float, view: CombatView) -> void:
		views.append(view)
		durations.append(duration)
		tracer.note("director")


## Does nothing at all in a step.
class IdleWaves:
	extends RoomWaves

	func step(_duration: float, _view: CombatView) -> void:
		pass


func before_each() -> void:
	_rules = WaveFixtures.rules()


func _sim() -> CombatSim:
	var sim: CombatSim = CombatSim.new()
	sim.setup(120, Tunables.player_combat.duplicate())
	return sim


func _rig(placed_count: int = 2, reserve_count: int = 4, max_engaged: int = 3) -> WaveFixtures.Rig:
	var placed_at: Array[Vector2] = []
	for index: int in placed_count:
		placed_at.append(WaveFixtures.PLACED_AT[index])
	return WaveFixtures.rig(placed_at, reserve_count, max_engaged, _rules.duplicate())


## A rig a warning has been running in for a while: the first placed enemy awake, the second woken
## and killed, the first reserve enemy on its way (started in step 1).
func _mid_warning_rig() -> WaveFixtures.Rig:
	var rig: WaveFixtures.Rig = _rig()
	rig.wake(rig.placed[0])
	rig.wake(rig.placed[1])
	rig.ticks(20)
	rig.kill(rig.placed[1])
	rig.ticks(40)
	return rig


# --- C6: the slot in tick() ---------------------------------------------------------------------


func test_c6_a_sim_has_no_director_until_one_is_set() -> void:
	var sim: CombatSim = _sim()
	assert_null(sim.get_waves())
	var waves: RoomWaves = RoomWaves.new()
	sim.set_waves(waves)
	assert_same(sim.get_waves(), waves)
	sim.set_waves(null)
	assert_null(sim.get_waves(), "null detaches it")


func test_c6_the_director_steps_after_every_step_and_the_clock_before_the_contact() -> void:
	var sim: CombatSim = _sim()
	var tracer: Tracer = Tracer.new(sim)
	sim.register(tracer)
	var waves: SpyWaves = SpyWaves.new()
	waves.tracer = tracer
	sim.set_waves(waves)
	sim.tick(STEP)
	assert_eq(tracer.log.slice(0, 3), ["sense", "step", "director"] as Array[String])
	var order: Array[String] = []
	for event: String in tracer.log:
		if order.is_empty() or order[-1] != event:
			order.append(event)
	assert_eq(order, ["sense", "step", "director", "fire", "contact", "end"] as Array[String])
	assert_almost_eq(tracer.times[1], 0.0, 1e-12, "the combatants stepped before the clock moved")
	assert_almost_eq(tracer.times[2], STEP, 1e-12, "the director sees the clock already advanced")
	assert_almost_eq(tracer.times[tracer.log.find("fire")], STEP, 1e-12)


func test_c6_the_director_gets_the_view_the_combatants_sensed_and_the_step_length() -> void:
	var sim: CombatSim = _sim()
	var tracer: Tracer = Tracer.new(sim)
	sim.register(tracer)
	var waves: SpyWaves = SpyWaves.new()
	waves.tracer = tracer
	sim.set_waves(waves)
	sim.tick(STEP)
	assert_eq(waves.views.size(), 1)
	assert_same(waves.views[0], tracer.seen_view)
	assert_almost_eq(waves.durations[0], STEP, 1e-12)


func test_c6_the_director_steps_once_per_step_at_every_tick_rate() -> void:
	for rate: int in RATES:
		var sim: CombatSim = _sim()
		var tracer: Tracer = Tracer.new(sim)
		sim.register(tracer)
		var waves: SpyWaves = SpyWaves.new()
		waves.tracer = tracer
		sim.set_waves(waves)
		for _i: int in rate:
			sim.tick(1.0 / rate)
		assert_eq(waves.views.size(), 120, "%d Hz: one per step" % rate)
		for duration: float in waves.durations:
			assert_almost_eq(duration, STEP, 1e-12)
		assert_eq(tracer.log.count("director"), tracer.log.count("step"))


# --- C15: without a director --------------------------------------------------------------------


func _plain_arena() -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2(10, 6))
	arena.add_chaser(Vector2(10, 9), &"chaser_1")
	arena.add_chaser(Vector2(14, 6), &"chaser_2")
	return arena


func test_c15_without_a_director_the_snapshot_has_exactly_todays_keys() -> void:
	var arena: EnemyArena = _plain_arena()
	arena.ticks(30)
	var snapshot: Dictionary = arena.sim.to_dict()
	assert_eq(snapshot.keys(), ["step_rate", "time", "order", "combatants"])
	assert_eq(snapshot.keys(), CombatSim.SNAPSHOT_KEYS)


func test_c15_a_snapshot_with_a_waves_entry_restores_into_a_sim_without_a_director() -> void:
	var arena: EnemyArena = _plain_arena()
	arena.ticks(30)
	var snapshot: Dictionary = arena.sim.to_dict()
	snapshot["waves"] = {"anything": 1}
	arena.ticks(30)
	assert_true(arena.sim.from_dict(snapshot), "as before: extra keys are not read")
	assert_false(arena.sim.to_dict().has("waves"))


func test_c15_an_idle_director_changes_nothing_about_a_run() -> void:
	var plain: EnemyArena = _plain_arena()
	var with_idle: EnemyArena = _plain_arena()
	with_idle.sim.set_waves(IdleWaves.new())
	for arena: EnemyArena in [plain, with_idle]:
		arena.tick(120, Vector2.RIGHT)
		for index: int in 400:
			arena.tick(
				120, Vector2.LEFT if index % 100 < 50 else Vector2.RIGHT, false, index % 70 == 0
			)
	var snapshot: Dictionary = with_idle.sim.to_dict()
	assert_true(snapshot.has("waves"))
	snapshot.erase("waves")
	assert_eq(snapshot, plain.sim.to_dict(), "the hook is the only difference")


# --- C10: the snapshot entry --------------------------------------------------------------------


func test_c10_with_a_director_the_snapshot_carries_its_state() -> void:
	var rig: WaveFixtures.Rig = _mid_warning_rig()
	var snapshot: Dictionary = rig.arena.sim.to_dict()
	assert_true(snapshot.has("waves"))
	var waves: Dictionary = snapshot["waves"]
	assert_eq(waves.keys(), ["started", "next_index", "since_last", "pending"])
	assert_true(waves["started"])
	assert_eq(waves["next_index"], 1)
	assert_eq(waves["pending"].size(), 1)
	assert_eq(waves["pending"][0]["index"], 0)
	assert_eq(waves["pending"][0]["point"], Vector2(16.5, 3.5))
	assert_almost_eq(waves["pending"][0]["left"], 0.8 - 59.0 / 120.0, 1e-9)
	assert_almost_eq(waves["pending"][0]["total"], 0.8, 1e-9)
	assert_almost_eq(waves["since_last"], 59.0 / 120.0, 1e-9)
	assert_eq(snapshot.keys().size(), 5, "the four of before and the waves")


func test_c10_a_fresh_director_starts_at_the_interval_with_nothing_sent() -> void:
	var rig: WaveFixtures.Rig = _rig()
	var waves: Dictionary = rig.arena.sim.to_dict()["waves"]
	assert_false(waves["started"])
	assert_eq(waves["next_index"], 0)
	assert_almost_eq(waves["since_last"], 1.5, 1e-12)
	assert_eq(waves["pending"].size(), 0)


func _assert_refused(rig: WaveFixtures.Rig, bad: Dictionary, label: String) -> void:
	var before: Dictionary = rig.arena.sim.to_dict()
	var enemy_before: Dictionary = rig.placed[0].to_dict()
	assert_false(rig.arena.sim.from_dict(bad), label)
	assert_push_error("snapshot rejected")
	assert_eq(rig.arena.sim.to_dict(), before, "%s: nothing changed" % label)
	assert_eq(rig.placed[0].to_dict(), enemy_before, "%s: not even the enemies" % label)


## A snapshot of a rig as it was at its start, and the rig a good while later, so that a
## restore that went through half-way would show.
func test_c10_a_snapshot_the_director_refuses_changes_nothing_at_all() -> void:
	var source: WaveFixtures.Rig = _mid_warning_rig()
	var good: Dictionary = source.arena.sim.to_dict()
	var rig: WaveFixtures.Rig = _rig()
	rig.wake(rig.placed[0])
	rig.ticks(200)  # Not where the snapshot is.
	var cases: Dictionary = {}
	var missing: Dictionary = good.duplicate(true)
	missing.erase("waves")
	cases["no waves entry"] = missing
	var not_a_dictionary: Dictionary = good.duplicate(true)
	not_a_dictionary["waves"] = 5
	cases["waves is not a dictionary"] = not_a_dictionary
	var broken: Dictionary = good.duplicate(true)
	broken["waves"].erase("pending")
	cases["a key is missing"] = broken
	var negative_index: Dictionary = good.duplicate(true)
	negative_index["waves"]["next_index"] = -1
	cases["next_index below 0"] = negative_index
	var big_index: Dictionary = good.duplicate(true)
	big_index["waves"]["next_index"] = 5
	cases["next_index above the reserve"] = big_index
	var float_index: Dictionary = good.duplicate(true)
	float_index["waves"]["next_index"] = 1.0
	cases["next_index not an int"] = float_index
	var negative_time: Dictionary = good.duplicate(true)
	negative_time["waves"]["since_last"] = -0.5
	cases["since_last below 0"] = negative_time
	var nan_time: Dictionary = good.duplicate(true)
	nan_time["waves"]["since_last"] = NAN
	cases["since_last NaN"] = nan_time
	var unstarted: Dictionary = good.duplicate(true)
	unstarted["waves"]["started"] = false
	cases["arrivals sent in a fight that has not started"] = unstarted
	var ahead: Dictionary = good.duplicate(true)
	ahead["waves"]["pending"][0]["index"] = 1
	cases["a pending enemy that was not started"] = ahead
	var outside: Dictionary = good.duplicate(true)
	outside["waves"]["pending"][0]["index"] = 9
	cases["a pending enemy outside the reserve"] = outside
	var twice: Dictionary = good.duplicate(true)
	twice["waves"]["pending"].append(twice["waves"]["pending"][0].duplicate())
	cases["the same enemy pending twice"] = twice
	var off_point: Dictionary = good.duplicate(true)
	off_point["waves"]["pending"][0]["point"] = Vector2(3.3, 3.3)
	cases["a pending arrival off the arrival points"] = off_point
	var too_long: Dictionary = good.duplicate(true)
	too_long["waves"]["pending"][0]["left"] = 5.0
	cases["time left above the warning"] = too_long
	var negative_left: Dictionary = good.duplicate(true)
	negative_left["waves"]["pending"][0]["left"] = -0.1
	cases["time left below 0"] = negative_left
	var no_total: Dictionary = good.duplicate(true)
	no_total["waves"]["pending"][0]["total"] = -1.0
	cases["a negative warning"] = no_total
	var short_entry: Dictionary = good.duplicate(true)
	short_entry["waves"]["pending"][0].erase("point")
	cases["a pending entry without its point"] = short_entry
	var not_a_list: Dictionary = good.duplicate(true)
	not_a_list["waves"]["pending"] = {}
	cases["pending is not a list"] = not_a_list
	var fresh: Dictionary = _rig().arena.sim.to_dict()  # Nothing sent, nothing pending.
	var fresh_low: Dictionary = fresh.duplicate(true)
	fresh_low["waves"]["next_index"] = -1
	cases["next_index below 0, nothing pending"] = fresh_low
	var fresh_high: Dictionary = fresh.duplicate(true)
	fresh_high["waves"]["next_index"] = 5
	cases["next_index above the reserve, nothing pending"] = fresh_high
	var below: Dictionary = good.duplicate(true)
	below["waves"]["pending"][0]["index"] = -1
	cases["a pending enemy below 0"] = below
	for label: String in cases:
		_assert_refused(rig, cases[label], label)
	assert_true(rig.arena.sim.from_dict(good), "the control: the unbroken one is taken")


func test_c10_the_director_alone_refuses_what_restore_errors_lists() -> void:
	var rig: WaveFixtures.Rig = _mid_warning_rig()
	var good: Dictionary = rig.waves.to_dict()
	assert_eq(rig.waves.restore_errors(good), PackedStringArray())
	var bad: Dictionary = good.duplicate(true)
	bad["next_index"] = 17
	assert_eq(rig.waves.restore_errors(bad).size(), 1)
	assert_false(rig.waves.from_dict(bad))
	assert_push_error("snapshot rejected")
	assert_eq(rig.waves.to_dict(), good)
	assert_eq(rig.waves.restore_errors({}).size(), 1, "an empty one is one error, not a crash")


# --- AC13: the same run at three tick rates -----------------------------------------------------


## What a scripted run gave: the step each reinforcement was started in, the step and the place
## each arrived in, and the count of kills. Actions fall on thirtieths of a second.
func _scripted_run(rate: int) -> Dictionary:
	var rig: WaveFixtures.Rig = _rig(2, 5, 2)
	var script: Dictionary = {
		15: func() -> void: rig.wake(rig.placed[0]),
		90: func() -> void: rig.kill(rig.placed[0]),
		105: func() -> void: rig.wake(rig.placed[1]),
		180: func() -> void: rig.kill(rig.placed[1]),
		240: func() -> void: rig.kill_everyone(),
	}
	var per_30th: int = rate / 30
	for index: int in rate * 10:
		if index % per_30th == 0 and script.has(index / per_30th):
			script[index / per_30th].call()
		rig.tick(rate)
	var starts: Array[Array] = []
	for entry: Dictionary in rig.recorder.starts:
		starts.append([entry["step"], entry["id"], entry["point"]])
	var arrivals: Array[Array] = []
	for entry: Dictionary in rig.recorder.arrivals:
		arrivals.append([entry["step"], entry["id"], entry["position"]])
	return {
		"starts": starts,
		"arrivals": arrivals,
		"kills": rig.waves.get_kill_count(),
		"steps": rig.step_count(),
	}


func test_ac13_warning_starts_arrivals_and_points_match_at_30_60_and_120_ticks() -> void:
	var reference: Dictionary = _scripted_run(120)
	assert_eq(reference["steps"], 1200)
	assert_gte(reference["starts"].size(), 3, "the run does something")
	assert_gte(reference["arrivals"].size(), 2)
	for rate: int in [30, 60]:
		var run: Dictionary = _scripted_run(rate)
		assert_eq(run["steps"], 1200, "%d Hz" % rate)
		assert_eq(run["starts"], reference["starts"], "%d Hz: when and where warnings start" % rate)
		assert_eq(run["arrivals"], reference["arrivals"], "%d Hz: when and where they land" % rate)
		assert_eq(run["kills"], reference["kills"], "%d Hz" % rate)


func test_ac13_the_scripted_run_uses_more_than_one_arrival_point() -> void:
	var points: Array[Vector2] = []
	for entry: Array in _scripted_run(120)["starts"]:
		if not points.has(entry[2]):
			points.append(entry[2])
	assert_gt(points.size(), 1, "so the points are compared for something")


# --- AC14: a snapshot in the middle of a warning ------------------------------------------------


func test_ac14_a_room_restored_mid_warning_continues_to_the_same_instant_point_and_kills() -> void:
	var original: WaveFixtures.Rig = _mid_warning_rig()
	var snapshot: Dictionary = original.arena.sim.to_dict()
	var restored: WaveFixtures.Rig = _rig()
	assert_true(restored.arena.sim.from_dict(snapshot))
	assert_eq(restored.waves.get_kill_count(), original.waves.get_kill_count(), "the kills")
	assert_eq(restored.waves.get_kill_count(), 1)
	assert_eq(restored.waves.has_started(), true)
	assert_eq(restored.waves.get_next_index(), original.waves.get_next_index())
	var was: Array[RoomWaves.Pending] = original.waves.get_pending()
	var is_now: Array[RoomWaves.Pending] = restored.waves.get_pending()
	assert_eq(is_now.size(), 1)
	assert_eq(is_now[0].enemy_id, was[0].enemy_id)
	assert_eq(is_now[0].point, was[0].point)
	assert_almost_eq(is_now[0].time_left, was[0].time_left, 1e-12)
	assert_almost_eq(is_now[0].total, was[0].total, 1e-12)
	assert_true(restored.reserve[0].is_waiting())
	# Then both run on, with the same things done to them.
	for rig: WaveFixtures.Rig in [original, restored]:
		rig.run(6.0)
	assert_gte(original.recorder.arrivals.size(), 1)
	assert_eq(restored.recorder.arrivals.size(), original.recorder.arrivals.size())
	assert_eq(restored.recorder.arrivals[0]["step"], 1 + WARNING_STEPS, "the same instant")
	for index: int in original.recorder.arrivals.size():
		var was_arrival: Dictionary = original.recorder.arrivals[index]
		var now_arrival: Dictionary = restored.recorder.arrivals[index]
		assert_eq(now_arrival["step"], was_arrival["step"])
		assert_eq(now_arrival["position"], was_arrival["position"])
		assert_eq(now_arrival["id"], was_arrival["id"])
	assert_eq(restored.waves.get_kill_count(), original.waves.get_kill_count())
	assert_eq(restored.arena.sim.to_dict(), original.arena.sim.to_dict(), "and everything else")


func test_ac14_the_next_warnings_after_a_restore_start_when_and_where_they_would_have() -> void:
	var original: WaveFixtures.Rig = _mid_warning_rig()
	var snapshot: Dictionary = original.arena.sim.to_dict()
	var restored: WaveFixtures.Rig = _rig()
	assert_true(restored.arena.sim.from_dict(snapshot))
	for rig: WaveFixtures.Rig in [original, restored]:
		rig.kill(rig.placed[0])
		rig.run(8.0)
	var later_original: Array[Array] = []
	var later_restored: Array[Array] = []
	for entry: Dictionary in original.recorder.starts:
		if entry["index"] >= 1:
			later_original.append([entry["step"], entry["id"], entry["point"]])
	for entry: Dictionary in restored.recorder.starts:
		if entry["index"] >= 1:
			later_restored.append([entry["step"], entry["id"], entry["point"]])
	assert_gte(later_original.size(), 1, "a second one was sent after the restore point")
	assert_eq(later_restored, later_original)


func test_ac14_restoring_an_earlier_snapshot_clears_the_warning_that_began_after_it() -> void:
	var rig: WaveFixtures.Rig = _rig()
	rig.ticks(5)
	var early: Dictionary = rig.arena.sim.to_dict()
	rig.wake(rig.placed[0])
	rig.ticks(30)
	assert_eq(rig.waves.get_pending().size(), 1)
	assert_true(rig.arena.sim.from_dict(early))
	assert_eq(rig.waves.get_pending().size(), 0)
	assert_eq(rig.waves.get_next_index(), 0)
	assert_false(rig.waves.has_started())
	assert_true(rig.reserve[0].is_waiting())
	rig.run(3.0)
	assert_eq(rig.waves.get_pending().size(), 0, "and nothing is sent: nobody has woken")


func test_ac14_a_snapshot_without_the_waves_entry_is_refused_with_nothing_changed() -> void:
	var rig: WaveFixtures.Rig = _mid_warning_rig()
	var snapshot: Dictionary = rig.arena.sim.to_dict()
	snapshot.erase("waves")
	rig.ticks(10)
	var before: Dictionary = rig.arena.sim.to_dict()
	var pending_before: float = rig.waves.get_pending()[0].time_left
	assert_false(rig.arena.sim.from_dict(snapshot))
	assert_push_error("snapshot rejected")
	assert_eq(rig.arena.sim.to_dict(), before)
	assert_almost_eq(rig.waves.get_pending()[0].time_left, pending_before, 1e-12)


func test_ac14_a_snapshot_shaped_like_a_room_without_a_director_is_refused_by_one_with() -> void:
	var rig: WaveFixtures.Rig = _rig()
	var plain_snapshot: Dictionary = _plain_arena().sim.to_dict()
	assert_false(plain_snapshot.has("waves"))
	var snapshot: Dictionary = rig.arena.sim.to_dict()
	snapshot.erase("waves")
	assert_false(rig.arena.sim.from_dict(snapshot))
	assert_push_error("snapshot rejected")


func test_ac14_a_restored_pending_arrival_still_holds_its_own_point() -> void:
	# The player is at (20, 8): the best point is the third, (6.5, 9.5), then the second.
	_rules.wave_spawn_interval = 0.5
	var placed_at: Array[Vector2] = [WaveFixtures.PLACED_AT[0]]
	var original: WaveFixtures.Rig = WaveFixtures.rig(
		placed_at, 3, 3, _rules.duplicate(), [], 0.01, Vector2(20, 8)
	)
	original.wake(original.placed[0])
	original.ticks(20)
	var snapshot: Dictionary = original.arena.sim.to_dict()
	assert_eq(snapshot["waves"]["pending"][0]["point"], Vector2(6.5, 9.5))
	var restored: WaveFixtures.Rig = WaveFixtures.rig(
		placed_at, 3, 3, _rules.duplicate(), [], 0.01, Vector2(20, 8)
	)
	assert_true(restored.arena.sim.from_dict(snapshot))
	for rig: WaveFixtures.Rig in [original, restored]:
		rig.run(1.0)
	assert_eq(original.recorder.starts[1]["point"], Vector2(6.5, 4.5), "the point left")
	assert_eq(restored.recorder.starts[-1]["point"], original.recorder.starts[1]["point"])
	assert_eq(restored.recorder.starts[-1]["step"], original.recorder.starts[1]["step"])
