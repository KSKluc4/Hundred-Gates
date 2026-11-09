extends F006SceneTest
## F-006 AC12 over real physics: BruteScript's fight (charge into a pillar, stomp, full-length
## charge) gives the same wall-stop step, stun end, hits and positions at 30, 60 and 120
## ticks/s.

const RATES: Array[int] = [30, 60, 120]
const SAMPLE_STEPS: Array[int] = [100, 126, 200, 306, 400, 480, 560, 640, 720, 800, 900, 1000]

var _positions_agree: bool = true


func test_ac12_the_scripted_fight_over_real_physics_at_every_rate() -> void:
	var runs: Array[Dictionary] = []
	for rate: int in RATES:
		Engine.physics_ticks_per_second = rate
		runs.append(await _run(rate))
		_scene.queue_free()
	var reference: Dictionary = runs[2]
	assert_eq(reference["stop_step"], BruteScript.STOP_STEP, "the pillar stops the first charge")
	assert_almost_eq(reference["stun_end"], 2.55, TIME)
	assert_eq(reference["stops"], 1, "the second charge runs its full length")
	assert_eq(reference["charges"], 2)
	assert_eq(reference["stomps"], 1)
	assert_eq(reference["hurt"].size(), 2, "the stomp and the second charge hit")
	for index: int in 2:
		var label: String = "%d ticks/s" % RATES[index]
		var run: Dictionary = runs[index]
		for key: String in ["stop_step", "charges", "stops", "stomps"]:
			assert_eq(run[key], reference[key], "%s: %s" % [label, key])
		assert_almost_eq(run["stun_end"], reference["stun_end"], TIME, label)
		assert_eq(run["hurt"].size(), reference["hurt"].size(), label)
		for hit: int in mini(run["hurt"].size(), reference["hurt"].size()):
			assert_almost_eq(run["hurt"][hit], reference["hurt"][hit], TIME, label)
		for step: int in SAMPLE_STEPS:
			assert_tiles(
				run["positions"][step], reference["positions"][step], "%s: %d" % [label, step]
			)
		assert_tiles(run["player"], reference["player"], label)
	assert_true(_positions_agree, "logic and body agree at every contact")


func _run(rate: int) -> Dictionary:
	await build([BruteScript.PILLAR] as Array[Rect2], BruteScript.PLAYER_START, Vector2.ZERO)
	var probe: StepEndProbe = probe_brute()
	var watch: EnemyWatch = watch_brute()
	var agree: SimProbe = QuietProbe.new()
	agree.on_contact = _check_positions
	_runner.get_sim().register(agree)
	var hurt: Array[float] = record_hurt()
	var moves: Dictionary = BruteScript.moves()
	var per_30th: int = rate / 30
	for thirtieth: int in BruteScript.END_30THS:
		await run_ticks(per_30th, false, false, moves.get(thirtieth, Vector2.ZERO))
	var base: int = roundi(_t0 * 120.0)
	var result: Dictionary = {
		"stop_step": stop_step(probe),
		"stun_end": -1.0,
		"charges": 0,
		"stomps": 0,
		"stops": 0,
		"hurt": hurt.duplicate(),
		"positions": {},
		"player": Units.vector_px_to_tiles(_player.global_position),
	}
	for step: int in SAMPLE_STEPS:
		result["positions"][step] = watch.at(step + base)["position"]
	var was_stopped: bool = false
	var last_attack: String = ""
	for step: int in range(1, BruteScript.END_30THS * 4 + 1):
		var after: Dictionary = probe.after_step[step + base]
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


## On the enemy team and far away, so it is never a target or a hit: a player-team probe at
## the origin would take the charge's first contact, and give the brute hitstop.
class QuietProbe:
	extends SimProbe

	func _init() -> void:
		super(&"agree")
		_team = Team.ENEMY
		_position = EnemyWatch.FAR_AWAY


func _check_positions() -> void:
	if _brute.logic.get_position_px() != _brute.global_position:
		_positions_agree = false
