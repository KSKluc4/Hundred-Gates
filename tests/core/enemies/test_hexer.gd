extends GutTest
## F-008 T4: the Hexer's data (C12, §4 tables), AC14 (it validates, and distance picks its
## patterns in both stages), AC15 (the caster brain moves it) and AC13 (one scripted fight, the
## same at 30, 60 and 120 ticks/s, down to every bolt's position at every contact).

const TIME: float = EnemyArena.TIME
const RATES: Array[int] = EnemyArena.RATES
## C10: bolt positions across tick rates.
const POSITION: float = 1e-6
const FAN_3: Array = [-20.0, 0.0, 20.0]
const FAN_2: Array = [-10.0, 10.0]
const RING: Array = [
	0.0, 30.0, 60.0, 90.0, 120.0, 150.0, 180.0, -150.0, -120.0, -90.0, -60.0, -30.0
]
## §4: windup, aim_track_time, active, recovery, damage, arc, range, knockback, speed, max
## distance, trigger min, trigger max, volley, follow-up path ("" = none).
const ATTACKS: Dictionary = {
	Tunables.HEXER_NOVA_PATH:
	[0.60, 0.0, 0.10, 1.00, 18, 360.0, 2.5, 3.0, 0.0, 0.0, 0.0, 2.5, [], ""],
	Tunables.HEXER_P2_NOVA_PATH:
	[0.60, 0.0, 0.10, 0.30, 18, 360.0, 2.5, 3.0, 0.0, 0.0, 0.0, 2.5, [], Tunables.HEXER_RING_PATH],
	Tunables.HEXER_FAN_A_PATH:
	[
		0.70,
		0.45,
		0.10,
		0.30,
		18,
		360.0,
		0.25,
		0.5,
		6.0,
		10.0,
		2.5,
		9.0,
		FAN_3,
		Tunables.HEXER_FAN_B_PATH
	],
	Tunables.HEXER_FAN_B_PATH:
	[0.45, 0.25, 0.10, 0.90, 18, 360.0, 0.25, 0.5, 6.0, 10.0, 2.5, 9.0, FAN_2, ""],
	Tunables.HEXER_P2_FAN_A_PATH:
	[
		0.70,
		0.45,
		0.10,
		0.30,
		18,
		360.0,
		0.25,
		0.5,
		6.0,
		10.0,
		2.5,
		9.0,
		FAN_3,
		Tunables.HEXER_P2_FAN_B_PATH
	],
	Tunables.HEXER_P2_FAN_B_PATH:
	[
		0.45,
		0.25,
		0.10,
		0.30,
		18,
		360.0,
		0.25,
		0.5,
		6.0,
		10.0,
		2.5,
		9.0,
		FAN_2,
		Tunables.HEXER_FAN_C_PATH
	],
	Tunables.HEXER_FAN_C_PATH:
	[0.45, 0.25, 0.10, 0.90, 18, 360.0, 0.25, 0.5, 6.0, 10.0, 2.5, 9.0, FAN_3, ""],
	Tunables.HEXER_RING_PATH:
	[0.60, 0.35, 0.10, 1.00, 18, 360.0, 0.25, 0.5, 4.0, 8.0, 0.0, 2.5, RING, ""],
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
	"projectile_speed_tiles",
	"projectile_max_distance_tiles",
	"trigger_min_tiles",
	"trigger_max_tiles",
]


func test_c12_the_hexer_matches_the_spec() -> void:
	var hexer: EnemyData = load(Tunables.HEXER_PATH)
	assert_eq(hexer.id, &"hexer")
	assert_eq(hexer.brain, EnemyData.Brain.CASTER, "the caster's brain")
	assert_eq(hexer.max_hp, 320)
	assert_eq(hexer.hurtbox_radius_tiles, 0.5)
	assert_eq(hexer.knockback_scale, 0.0)
	assert_eq(hexer.move_speed, 2.5)
	assert_eq(hexer.aggro_radius_tiles, 10.0)
	assert_eq(hexer.stop_distance_tiles, 7.0)
	assert_eq(hexer.retreat_distance_tiles, 4.0)
	assert_eq(hexer.attack_cooldown, 1.2)
	assert_eq(_paths(hexer.attacks), [Tunables.HEXER_NOVA_PATH, Tunables.HEXER_FAN_A_PATH])
	assert_eq(hexer.stages.size(), 1)
	var stage: EnemyStageData = hexer.stages[0]
	assert_eq(stage.resource_path, Tunables.HEXER_STAGE_2_PATH)
	assert_eq(stage.enter_at_hp_percent, 50)
	assert_eq(stage.shift_duration, 1.2)
	assert_eq(stage.move_speed, 3.0)
	assert_eq(stage.attack_cooldown, 0.9)
	assert_eq(_paths(stage.attacks), [Tunables.HEXER_P2_NOVA_PATH, Tunables.HEXER_P2_FAN_A_PATH])


func test_c12_every_hexer_attack_matches_the_table() -> void:
	for path: String in ATTACKS:
		var attack: EnemyAttackData = load(path)
		var row: Array = ATTACKS[path]
		assert_eq(attack.id, StringName(path.get_file().get_basename()), path)
		for index: int in FIELDS.size():
			assert_almost_eq(float(attack.get(FIELDS[index])), float(row[index]), TIME, path)
		assert_eq(attack.volley_angles_deg, PackedFloat64Array(row[12]), "%s volley" % path)
		var follow_up: String = attack.follow_up.resource_path if attack.follow_up != null else ""
		assert_eq(follow_up, row[13], "%s follow_up" % path)
		assert_eq(attack.lunge_tiles, 0.0, path)
		assert_eq(attack.wall_stun_duration, 0.0, path)
		assert_false(attack.is_finisher, path)
		assert_eq(attack.is_projectile(), row[8] > 0.0, path)


func test_ac14_the_hexer_validates_with_the_real_tunables() -> void:
	var hexer: EnemyData = load(Tunables.HEXER_PATH)
	var rate: int = Tunables.player_combat.combat_step_rate
	assert_eq(hexer.validate(rate, Tunables.enemy_combat), PackedStringArray())
	assert_eq(hexer.validate_against_class(load(Tunables.WARRIOR_PATH)), PackedStringArray())


func test_ac14_stage_1_close_is_the_nova_even_at_exactly_2_5() -> void:
	assert_eq(_pattern_at(2.0, false)["ids"], [&"hexer_nova"] as Array[StringName])
	assert_eq(_pattern_at(2.5, false)["ids"], [&"hexer_nova"] as Array[StringName])


func test_ac14_stage_1_mid_range_is_fan_a_then_fan_b_then_the_cooldown() -> void:
	var pattern: Dictionary = _pattern_at(5.0, false)
	assert_eq(pattern["ids"], [&"hexer_fan_a", &"hexer_fan_b"] as Array[StringName])
	assert_eq(pattern["bolts"], [3, 2])
	assert_almost_eq(pattern["cooldown_after"], 1.2, 1.0 / 120.0 + TIME, "the cooldown runs")


func test_ac14_stage_1_beyond_9_starts_nothing() -> void:
	var arena: CasterArena = _hexer_arena(9.5, false)
	var hexer: EnemyLogic = arena.enemies[0]
	arena.ticks(1)
	assert_null(hexer.get_running_attack())
	assert_eq(hexer.get_state(), EnemyLogic.State.CHASE, "it walks in")


func test_ac14_stage_2_close_is_nova_then_a_ring_with_one_bolt_on_the_aim() -> void:
	var pattern: Dictionary = _pattern_at(2.0, true)
	assert_eq(pattern["ids"], [&"hexer_p2_nova", &"hexer_ring"] as Array[StringName])
	assert_eq(pattern["bolts"], [0, 12])
	var on_aim: int = 0
	for direction: Vector2 in pattern["ring_directions"]:
		if direction.distance_to(pattern["ring_aim"]) < 1e-6:
			on_aim += 1
	assert_eq(on_aim, 1, "one bolt along the locked aim")


func test_ac14_stage_2_mid_range_is_the_triple_fan() -> void:
	var pattern: Dictionary = _pattern_at(5.0, true)
	assert_eq(
		pattern["ids"], [&"hexer_p2_fan_a", &"hexer_p2_fan_b", &"hexer_fan_c"] as Array[StringName]
	)
	assert_eq(pattern["bolts"], [3, 2, 3])


func test_ac15_with_the_cooldown_running_it_backs_walks_in_or_holds() -> void:
	assert_almost_eq(_moved_with_cooldown(3.0), -2.5 * 12.0 / 120.0, TIME, "backs straight away")
	assert_almost_eq(_moved_with_cooldown(8.0), 2.5 * 12.0 / 120.0, TIME, "walks in")
	assert_almost_eq(_moved_with_cooldown(5.0), 0.0, TIME, "holds")


func test_ac13_one_scripted_fight_is_the_same_at_every_tick_rate() -> void:
	var runs: Array[Dictionary] = []
	for rate: int in RATES:
		runs.append(_scripted_fight(rate))
	var first: Dictionary = runs[0]
	assert_true(first["crossed_mid_pattern"], "50 % was crossed inside a pattern")
	assert_eq(first["stage_entries"].size(), 1, "it entered stage 2")
	for id: StringName in [&"hexer_nova", &"hexer_p2_fan_a", &"hexer_fan_c", &"hexer_ring"]:
		assert_true(first["attacks"].has(id), "%s ran: %s" % [id, first["attacks"]])
	assert_gt(first["launches"].size(), 12, "bolts launched")
	assert_gt(first["hurt"].size(), 0, "the Hexer landed hits")
	assert_gt(first["sword"].size(), 0, "the sword landed hits")
	for index: int in range(1, runs.size()):
		var run: Dictionary = runs[index]
		var label: String = "%d vs %d ticks/s" % [RATES[index], RATES[0]]
		assert_eq(run["attacks"], first["attacks"], "%s: attacks" % label)
		assert_eq(run["launches"], first["launches"], "%s: launch steps by serial" % label)
		for key: String in ["stage_entries", "windups", "hurt", "sword"]:
			_assert_same_times(run[key], first[key], "%s: %s" % [label, key])
		assert_eq(run["final_hp"], first["final_hp"], label)
		_assert_same_bolts(run["bolts"], first["bolts"], label)


## The Hexer at the origin, the player `distance` below it. In stage 2 at once (its shift runs
## first) when `stage_2`.
func _hexer_arena(distance: float, stage_2: bool) -> CasterArena:
	var arena: CasterArena = CasterArena.new()
	arena.caster_data = load(Tunables.HEXER_PATH)
	arena.add_player(Vector2(0, distance))
	var hexer: EnemyLogic = arena.add_caster(Vector2.ZERO, &"hexer")
	if stage_2:
		BossValues.set_hp(hexer, 160)
	return arena


## The first pattern the Hexer runs: ids in order, bolts each launched, the cooldown when it
## ended and, for a ring, its aim at the launch and its bolts' directions.
func _pattern_at(distance: float, stage_2: bool) -> Dictionary:
	var arena: CasterArena = _hexer_arena(distance, stage_2)
	var hexer: EnemyLogic = arena.enemies[0]
	var result: Dictionary = {"ids": [] as Array[StringName], "bolts": [], "cooldown_after": -1.0}
	var started: bool = false
	var serial: int = 0
	for _i: int in 900:
		arena.ticks(1)
		var attack: EnemyAttackData = hexer.get_running_attack()
		var launched: int = hexer.get_projectiles().get_next_serial() - serial
		if launched > 0:
			result["bolts"][-1] += launched
			if result["ids"][-1] == &"hexer_ring":
				result["ring_aim"] = hexer.get_aim()
				result["ring_directions"] = _directions_from(hexer, serial)
			serial += launched
		if attack == null:
			if started:
				result["cooldown_after"] = hexer.get_cooldown_remaining()
				break
			continue
		started = true
		if result["ids"].is_empty() or result["ids"][-1] != attack.id:
			result["ids"].append(attack.id)
			result["bolts"].append(0)
	if stage_2:
		assert_eq(hexer.get_stage_index(), 1, "stage 2 is stages[0]")
	return result


func _directions_from(hexer: EnemyLogic, first_serial: int) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	for projectile: ProjectileSet.Projectile in hexer.get_projectiles().get_projectiles():
		if projectile.serial >= first_serial:
			directions.append(projectile.direction)
	return directions


## The Hexer's y after 12 steps with its cooldown running, the player `distance` below.
func _moved_with_cooldown(distance: float) -> float:
	var arena: CasterArena = _hexer_arena(distance, false)
	var hexer: EnemyLogic = arena.enemies[0]
	arena.restore_value(hexer, "cooldown_remaining", 5.0)
	arena.ticks(12)
	assert_null(hexer.get_running_attack(), "at %s" % distance)
	assert_eq(hexer.get_position_tiles().x, 0.0, "straight along the line at %s" % distance)
	return hexer.get_position_tiles().y


## 10 s of one fight. The player (1000 HP, so it lives) starts 1.5 tiles below the Hexer at
## 165 HP and swings into its first nova, taking it under 50 % mid-pattern. The nova throws it
## out and stage 2's triple fan follows, during which it steps in. It walks in again during the
## cooldown, so the Hexer, ready, is within 2.5 tiles: the stage 2 nova, then the ring. It swings
## during the nova's windup.
func _scripted_fight(rate: int) -> Dictionary:
	var arena: CasterArena = CasterArena.new()
	arena.class_data.max_hp = 1000
	arena.caster_data = load(Tunables.HEXER_PATH)
	arena.add_player(Vector2(0, 1.5))
	var hexer: EnemyLogic = arena.add_caster(Vector2.ZERO, &"hexer")
	BossValues.set_hp(hexer, 165)
	var watch: CasterWatch = arena.watch_caster(hexer)
	var result: Dictionary = {
		"stage_entries": [] as Array[float],
		"attacks": [] as Array[StringName],
		"crossed_mid_pattern": false,
	}
	var sim: CombatSim = arena.sim  # Not the arena: the Hexer would keep it alive.
	var on_stage: Callable = func(_index: int) -> void:
		result["stage_entries"].append(sim.get_time())
	hexer.stage_changed.connect(on_stage)
	var moves: Dictionary = {}
	for thirtieth: int in range(150, 158) + range(183, 216):
		moves[thirtieth] = Vector2.UP
	var swings: Array = [2, 218, 232, 246, 260]
	for thirtieth: int in 300:
		arena.play(rate, thirtieth, thirtieth + 1, moves, [], swings, Vector2.UP)
		var attack: EnemyAttackData = hexer.get_running_attack()
		if attack != null and (result["attacks"].is_empty() or result["attacks"][-1] != attack.id):
			result["attacks"].append(attack.id)
		var hp: int = hexer.get_combat_state().get_hp()
		if hp <= 160 and hexer.get_stage_index() == 0 and attack != null:
			result["crossed_mid_pattern"] = true
	hexer.stage_changed.disconnect(on_stage)
	result["windups"] = watch.times_entered(EnemyLogic.State.WINDUP)
	result["hurt"] = arena.hurt_times
	result["sword"] = arena.sword_times
	result["final_hp"] = [
		arena.players[0].get_combat_state().get_hp(), hexer.get_combat_state().get_hp()
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


## C10: at every contact step of both runs, the same live bolts by serial, each where the
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
	assert_gt(compared, 2000, "%s: bolts compared at many contacts" % label)
	pass_test("%s: %d bolt positions match" % [label, compared])


func _paths(attacks: Array[EnemyAttackData]) -> Array[String]:
	var paths: Array[String] = []
	for attack: EnemyAttackData in attacks:
		paths.append(attack.resource_path)
	return paths


func _assert_same_times(actual: Array, expected: Array, label: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s: %s vs %s" % [label, actual, expected])
	for index: int in mini(actual.size(), expected.size()):
		assert_almost_eq(float(actual[index]), float(expected[index]), TIME, label)
