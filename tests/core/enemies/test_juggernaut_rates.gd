extends GutTest
## F-009 T3: one scripted Juggernaut fight on the real data, in a 20 x 12 tile room whose four
## walls RoomWallStub reports. AC10 (C8): the same at 30, 60 and 120 ticks/s. AC11 (C9):
## snapshots taken in Charge A's gap, in a wall stun, mid Debris windup and with Debris in
## flight restore and replay identically.
##
## The fight (fixed commands, by thirtieth): the Juggernaut (300 HP) charges the player into
## the right wall and is stunned; the player lands a chain in the stun, walks left and eats an
## unstopped double charge; it stomps, the player walks back in and lands hits 1 and 2 in the
## stomp's recovery, crossing 50 % mid-attack; after the shift, stage 2 stomps, then Debris;
## the player backs off and eats the triple charge.

const TIME: float = EnemyArena.TIME
const RATES: Array[int] = EnemyArena.RATES
## C8: bolt positions across tick rates.
const POSITION: float = 1e-6
const ROOM: Vector2 = Vector2(20, 12)
const THIRTIETHS: int = 600
## Thirtieths after a restore that both runs play.
const REPLAY_30THS: int = 120


func test_ac10_one_scripted_fight_is_the_same_at_every_tick_rate() -> void:
	var runs: Array[Dictionary] = []
	for rate: int in RATES:
		runs.append(_recorded_fight(rate))
	var first: Dictionary = runs[0]
	assert_eq(
		first["attacks"],
		(
			[
				&"juggernaut_charge_a",
				&"juggernaut_charge_a",
				&"juggernaut_charge_b",
				&"juggernaut_stomp",
				&"juggernaut_p2_stomp",
				&"juggernaut_debris",
				&"juggernaut_p2_charge_a",
				&"juggernaut_p2_charge_b",
				&"juggernaut_charge_c",
			]
			as Array[StringName]
		),
		"wall-stopped A, double charge, stomp, stomp -> Debris, triple charge"
	)
	assert_eq(first["stops"].size(), 1, "one wall stop, on the first Charge A")
	assert_true(first["crossed_mid_attack"], "50 % was crossed inside an attack")
	assert_eq(first["stage_entries"].size(), 1, "it entered stage 2")
	assert_eq(first["launches"].size(), 8, "one Debris volley")
	assert_gt(first["hurt"].size(), 5, "the Juggernaut landed hits")
	assert_gt(first["sword"].size(), 3, "the sword landed hits")
	for index: int in range(1, runs.size()):
		var run: Dictionary = runs[index]
		var label: String = "%d vs %d ticks/s" % [RATES[index], RATES[0]]
		assert_eq(run["attacks"], first["attacks"], "%s: attacks" % label)
		assert_eq(run["stops"], first["stops"], "%s: wall stops" % label)
		assert_eq(run["launches"], first["launches"], "%s: launch steps by serial" % label)
		assert_eq(run["damage"], first["damage"], "%s: every hit's damage" % label)
		for key: String in ["stage_entries", "windups", "hurt", "sword"]:
			_assert_same_times(run[key], first[key], "%s: %s" % [label, key])
		assert_eq(run["final_hp"], first["final_hp"], label)
		_assert_same_bolts(run["bolts"], first["bolts"], label)


func test_ac11a_a_restore_in_charge_a_gap_replays_identically() -> void:
	var juggernaut: Dictionary = _assert_resumes(165)
	assert_eq(juggernaut["attack"]["id"], &"juggernaut_charge_a")
	assert_eq(juggernaut["state"], EnemyLogic.State.RECOVERY)
	assert_false(juggernaut["wall_stopped"], "a gap, not a stun")


func test_ac11b_a_restore_in_a_wall_stun_replays_identically() -> void:
	var juggernaut: Dictionary = _assert_resumes(50)
	assert_eq(juggernaut["state"], EnemyLogic.State.RECOVERY)
	assert_true(juggernaut["wall_stopped"])


func test_ac11c_a_restore_mid_debris_windup_replays_identically() -> void:
	var juggernaut: Dictionary = _assert_resumes(378)
	assert_eq(juggernaut["attack"]["id"], &"juggernaut_debris")
	assert_eq(juggernaut["state"], EnemyLogic.State.WINDUP)
	assert_eq(juggernaut["projectiles"].size(), 0)


func test_ac11d_a_restore_with_debris_in_flight_replays_identically() -> void:
	var juggernaut: Dictionary = _assert_resumes(395)
	assert_gt(juggernaut["projectiles"].size(), 5, "Debris in flight")
	assert_eq(juggernaut["next_projectile_serial"], 8)


## The fight at its start: the player (1000 HP, so it lives) and the Juggernaut, walls on.
func _new_fight() -> BruteArena:
	var arena: BruteArena = BruteArena.new()
	arena.class_data.max_hp = 1000
	arena.brute_data = load(Tunables.JUGGERNAUT_PATH)
	arena.add_player(Vector2(18, 6))
	var juggernaut: EnemyLogic = arena.add_brute(Vector2(13, 6), &"juggernaut")
	BossValues.set_hp(juggernaut, 300)
	RoomWallStub.new(juggernaut, arena.sim, ROOM).install(arena)
	return arena


## Plays thirtieths [from, to) of the script at `rate`.
func _play(arena: BruteArena, rate: int, from: int, to: int) -> void:
	var moves: Dictionary = {}
	for thirtieth: int in range(75, 120):  # Out of the stun, to the room's middle.
		moves[thirtieth] = Vector2.LEFT
	for thirtieth: int in range(279, 288):  # Back in after the stomp.
		moves[thirtieth] = Vector2.RIGHT
	for thirtieth: int in range(395, 405):  # Off after Debris, into charge range.
		moves[thirtieth] = Vector2.LEFT
	var swings: Array = [45, 55, 65, 288, 294]
	for thirtieth: int in range(from, to):
		var aim: Vector2 = Vector2.RIGHT if thirtieth >= 288 and thirtieth < 300 else Vector2.LEFT
		arena.play(rate, thirtieth, thirtieth + 1, moves, [], swings, aim)


func _recorded_fight(rate: int) -> Dictionary:
	var arena: BruteArena = _new_fight()
	var juggernaut: EnemyLogic = arena.enemies[0]
	var stub: RoomWallStub = arena.wall_stub
	var watch: CasterWatch = arena.watch_caster(juggernaut)
	var result: Dictionary = {
		"stage_entries": [] as Array[float],
		"attacks": [] as Array[StringName],
		"crossed_mid_attack": false,
	}
	var sim: CombatSim = arena.sim  # Not the arena: the Juggernaut would keep it alive.
	var on_stage: Callable = func(_index: int) -> void:
		result["stage_entries"].append(sim.get_time())
	juggernaut.stage_changed.connect(on_stage)
	var previous: StringName = &""
	for thirtieth: int in THIRTIETHS:
		_play(arena, rate, thirtieth, thirtieth + 1)
		var attack: EnemyAttackData = juggernaut.get_running_attack()
		var id: StringName = attack.id if attack != null else &""
		if id != &"" and id != previous:
			result["attacks"].append(id)
		previous = id
		var hp: int = juggernaut.get_combat_state().get_hp()
		if hp <= 250 and juggernaut.get_stage_index() == 0 and attack != null:
			result["crossed_mid_attack"] = true
	juggernaut.stage_changed.disconnect(on_stage)
	result["stops"] = stub.stops
	result["windups"] = watch.times_entered(EnemyLogic.State.WINDUP)
	result["hurt"] = arena.hurt_times
	result["sword"] = arena.sword_times
	result["damage"] = arena.hurt_events.map(func(event: HitEvent) -> int: return event.damage)
	result["final_hp"] = [
		arena.players[0].get_combat_state().get_hp(), juggernaut.get_combat_state().get_hp()
	]
	var launches: Dictionary = {}
	for serial: int in watch.seen_at:
		launches[serial] = watch.seen_at[serial][0]
	result["launches"] = launches
	var bolts: Dictionary = {}
	for step: int in watch.contacts:
		bolts[step] = watch.at(step)["projectiles"]
	result["bolts"] = bolts
	return result


## C9: plays the script at 120 ticks/s to `at`, restores that snapshot into a fresh fight, then
## replays the same commands in both and compares every snapshot, the hits and the wall stops.
## Returns the Juggernaut's snapshot.
func _assert_resumes(at: int) -> Dictionary:
	var unbroken: BruteArena = _new_fight()
	_play(unbroken, 120, 0, at)
	var snapshot: Dictionary = unbroken.sim.to_dict()
	var hurt_before: int = unbroken.hurt_times.size()
	var sword_before: int = unbroken.sword_times.size()
	var stops_before: int = (unbroken.wall_stub as RoomWallStub).stops.size()
	var fresh: BruteArena = _new_fight()
	assert_true(fresh.sim.from_dict(snapshot))
	assert_eq_deep(fresh.sim.to_dict(), snapshot)
	for thirtieth: int in range(at, at + REPLAY_30THS):
		_play(unbroken, 120, thirtieth, thirtieth + 1)
		_play(fresh, 120, thirtieth, thirtieth + 1)
		assert_eq_deep(fresh.sim.to_dict(), unbroken.sim.to_dict())
	assert_eq(fresh.hurt_times, unbroken.hurt_times.slice(hurt_before), "hits after the restore")
	assert_eq(fresh.sword_times, unbroken.sword_times.slice(sword_before))
	assert_eq(
		(fresh.wall_stub as RoomWallStub).stops,
		(unbroken.wall_stub as RoomWallStub).stops.slice(stops_before)
	)
	assert_gt(fresh.hurt_times.size() + fresh.sword_times.size(), 0, "something landed after")
	return snapshot["combatants"][&"juggernaut"]


## C8: at every contact step of both runs, the same live bolts by serial, each where the
## other run has it within POSITION tiles.
func _assert_same_bolts(actual: Dictionary, expected: Dictionary, label: String) -> void:
	assert_eq(actual.keys(), expected.keys(), "%s: the same contact steps" % label)
	var compared: int = 0
	for step: int in expected:
		if not actual.has(step):
			continue
		var mine: Array = actual[step]
		var theirs: Array = expected[step]
		var serials: Array = mine.map(func(p: Dictionary) -> int: return p["serial"])
		var expected_serials: Array = theirs.map(func(p: Dictionary) -> int: return p["serial"])
		if serials != expected_serials:
			fail_test("%s: step %d live bolts %s vs %s" % [label, step, serials, expected_serials])
			return
		for index: int in mine.size():
			var gap: float = mine[index]["position"].distance_to(theirs[index]["position"])
			if gap > POSITION:
				fail_test("%s: step %d bolt %d off by %s" % [label, step, serials[index], gap])
				return
			compared += 1
	assert_gt(compared, 1000, "%s: bolts compared at many contacts" % label)
	pass_test("%s: %d bolt positions match" % [label, compared])


func _assert_same_times(actual: Array, expected: Array, label: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s: %s vs %s" % [label, actual, expected])
	for index: int in mini(actual.size(), expected.size()):
		assert_almost_eq(float(actual[index]), float(expected[index]), TIME, label)
