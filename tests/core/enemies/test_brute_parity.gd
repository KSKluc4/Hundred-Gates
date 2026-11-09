extends GutTest
## F-006 AC12 in core (stub reports): BruteScript's fight gives the same wall-stop step, stun
## end, hits and positions at 30, 60 and 120 ticks/s.

const TIME: float = EnemyArena.TIME
const POSITION: float = 0.00001
const SAMPLE_STEPS: Array[int] = [100, 126, 200, 306, 400, 480, 560, 640, 720, 800, 900, 1000]


func test_ac12_the_scripted_fight_is_the_same_at_every_rate() -> void:
	var runs: Array[Dictionary] = []
	for rate: int in EnemyArena.RATES:
		runs.append(_run(rate))
	var reference: Dictionary = runs[2]
	assert_eq(reference["stop_step"], BruteScript.STOP_STEP, "the pillar stops the first charge")
	assert_almost_eq(reference["stun_end"], 2.55, TIME)
	assert_eq(reference["charges"], 2, "a second charge")
	assert_eq(reference["stops"], 1, "the second charge runs its full length")
	assert_eq(reference["stomps"], 1)
	assert_eq(reference["hurt"].size(), 2, "the stomp and the second charge hit")
	for index: int in 2:
		var label: String = "%d ticks/s" % EnemyArena.RATES[index]
		var run: Dictionary = runs[index]
		for key: String in ["stop_step", "charges", "stops", "stomps"]:
			assert_eq(run[key], reference[key], "%s: %s" % [label, key])
		assert_almost_eq(run["stun_end"], reference["stun_end"], TIME, label)
		assert_eq(run["hurt"].size(), reference["hurt"].size(), label)
		for hit: int in mini(run["hurt"].size(), reference["hurt"].size()):
			assert_almost_eq(run["hurt"][hit], reference["hurt"][hit], TIME, label)
		for step: int in SAMPLE_STEPS:
			var position: Vector2 = run["positions"][step]
			var expected: Vector2 = reference["positions"][step]
			assert_almost_eq(position.x, expected.x, POSITION, "%s: step %d" % [label, step])
			assert_almost_eq(position.y, expected.y, POSITION, "%s: step %d" % [label, step])
		assert_almost_eq(run["player"].x, reference["player"].x, POSITION, label)
		assert_almost_eq(run["player"].y, reference["player"].y, POSITION, label)


func _run(rate: int) -> Dictionary:
	var arena: BruteArena = BruteArena.new()
	var player: PlayerMotor = arena.add_player(BruteScript.PLAYER_START)
	var brute: EnemyLogic = arena.add_brute(Vector2.ZERO)
	var pillar: Rect2 = BruteScript.PILLAR
	var stub: BruteWallStub = BruteWallStub.new(brute, arena.sim, pillar.position.x - 0.6)
	stub.span = Vector2(pillar.position.y - 0.6, pillar.end.y + 0.6)
	stub.install(arena)
	var probe: StepEndProbe = StepEndProbe.new(brute, arena.sim)
	arena.sim.register(probe)
	var watch: EnemyWatch = arena.watch(brute)
	arena.play(rate, 0, BruteScript.END_30THS, BruteScript.moves())
	var result: Dictionary = {
		"stop_step": stub.stop_step(),
		"stun_end": -1.0,
		"charges": 0,
		"stomps": 0,
		"stops": 0,
		"hurt": arena.hurt_times.duplicate(),
		"positions": {},
		"player": player.get_position_tiles(),
	}
	for step: int in SAMPLE_STEPS:
		result["positions"][step] = watch.at(step)["position"]
	var was_stopped: bool = false
	var last_attack: String = ""
	for step: int in range(1, BruteScript.END_30THS * 4 + 1):
		var after: Dictionary = probe.after_step[step]
		if after["wall_stopped"] and not was_stopped:
			result["stops"] += 1
		if was_stopped and not after["wall_stopped"] and result["stun_end"] < 0.0:
			result["stun_end"] = step / 120.0
		was_stopped = after["wall_stopped"]
		var attack: String = String(after["attack"].get("id", ""))
		if attack != last_attack and attack == "brute_charge":
			result["charges"] += 1
		if attack != last_attack and attack == "brute_stomp":
			result["stomps"] += 1
		last_attack = attack
	return result
