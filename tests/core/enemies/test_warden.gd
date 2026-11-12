extends GutTest
## F-007 T6: the Warden's data (C16, §4 table), AC15 (it validates, and distance picks its
## patterns in both stages) and AC14 (one scripted fight, the same at 30, 60 and 120 ticks/s).

const TIME: float = EnemyArena.TIME
const RATES: Array[int] = EnemyArena.RATES
## §4: windup, aim_track_time, active, recovery, damage, arc, range, knockback, lunge,
## trigger min, trigger max, follow-up path ("" = none).
const ATTACKS: Dictionary = {
	Tunables.WARDEN_SWIPE_A_PATH:
	[0.50, 0.30, 0.10, 0.25, 20, 110.0, 1.6, 0.8, 0.6, 0.0, 2.0, Tunables.WARDEN_SWIPE_B_PATH],
	Tunables.WARDEN_SWIPE_B_PATH: [0.45, 0.25, 0.10, 0.80, 20, 110.0, 1.6, 0.8, 0.8, 0.0, 2.0, ""],
	Tunables.WARDEN_DASHING_CUT_PATH:
	[0.70, 0.45, 0.30, 0.90, 22, 120.0, 1.2, 1.2, 5.0, 3.0, 6.0, ""],
	Tunables.WARDEN_P2_SWIPE_A_PATH:
	[0.50, 0.30, 0.10, 0.25, 20, 110.0, 1.6, 0.8, 0.6, 0.0, 2.0, Tunables.WARDEN_P2_SWIPE_B_PATH],
	Tunables.WARDEN_P2_SWIPE_B_PATH:
	[0.45, 0.25, 0.10, 0.25, 20, 110.0, 1.6, 0.8, 0.8, 0.0, 2.0, Tunables.WARDEN_OVERHEAD_PATH],
	Tunables.WARDEN_OVERHEAD_PATH: [0.75, 0.50, 0.10, 1.00, 25, 150.0, 2.0, 1.5, 1.0, 0.0, 2.0, ""],
	Tunables.WARDEN_P2_DASHING_CUT_PATH:
	[0.70, 0.45, 0.30, 0.30, 22, 120.0, 1.2, 1.2, 5.0, 3.0, 6.0, Tunables.WARDEN_SPIN_PATH],
	Tunables.WARDEN_SPIN_PATH: [0.45, 0.0, 0.10, 0.90, 20, 360.0, 1.8, 1.2, 0.0, 0.0, 2.0, ""],
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
	"trigger_min_tiles",
	"trigger_max_tiles",
]


func test_c16_the_warden_matches_the_spec() -> void:
	var warden: EnemyData = load(Tunables.WARDEN_PATH)
	assert_eq(warden.id, &"warden")
	assert_eq(warden.brain, EnemyData.Brain.CHASER, "the chaser's brain")
	assert_eq(warden.max_hp, 400)
	assert_eq(warden.hurtbox_radius_tiles, 0.7)
	assert_eq(warden.knockback_scale, 0.0)
	assert_eq(warden.move_speed, 3.0)
	assert_eq(warden.aggro_radius_tiles, 10.0)
	assert_eq(warden.stop_distance_tiles, 1.2)
	assert_eq(warden.retreat_distance_tiles, 0.0)
	assert_eq(warden.attack_cooldown, 1.0)
	assert_eq(
		_paths(warden.attacks), [Tunables.WARDEN_SWIPE_A_PATH, Tunables.WARDEN_DASHING_CUT_PATH]
	)
	assert_eq(warden.stages.size(), 1)
	var stage: EnemyStageData = warden.stages[0]
	assert_eq(stage.resource_path, Tunables.WARDEN_STAGE_2_PATH)
	assert_eq(stage.enter_at_hp_percent, 50)
	assert_eq(stage.shift_duration, 1.2)
	assert_eq(stage.move_speed, 3.5)
	assert_eq(stage.attack_cooldown, 0.7)
	assert_eq(
		_paths(stage.attacks),
		[Tunables.WARDEN_P2_SWIPE_A_PATH, Tunables.WARDEN_P2_DASHING_CUT_PATH]
	)


func test_c16_every_warden_attack_matches_the_table() -> void:
	var chaser_swipe: EnemyAttackData = load(Tunables.CHASER_SWIPE_PATH)
	for path: String in ATTACKS:
		var attack: EnemyAttackData = load(path)
		var row: Array = ATTACKS[path]
		assert_eq(attack.id, StringName(path.get_file().get_basename()), path)
		for index: int in FIELDS.size():
			assert_almost_eq(float(attack.get(FIELDS[index])), float(row[index]), TIME, path)
		var follow_up: String = attack.follow_up.resource_path if attack.follow_up != null else ""
		assert_eq(follow_up, row[11], "%s follow_up" % path)
		assert_false(attack.is_projectile(), path)
		assert_false(attack.is_wall_stun(), path)
		assert_eq(attack.is_finisher, chaser_swipe.is_finisher, "%s: the chaser's value" % path)


func test_ac15_the_warden_validates_with_the_real_tunables() -> void:
	var warden: EnemyData = load(Tunables.WARDEN_PATH)
	var rate: int = Tunables.player_combat.combat_step_rate
	assert_eq(warden.validate(rate, Tunables.enemy_combat), PackedStringArray())
	assert_eq(warden.validate_against_class(load(Tunables.WARRIOR_PATH)), PackedStringArray())


func test_ac15_stage_1_distance_picks_the_attack() -> void:
	assert_eq(_pattern_at(1.5, false), [&"warden_swipe_a", &"warden_swipe_b"] as Array[StringName])
	assert_eq(_pattern_at(4.5, false), [&"warden_dashing_cut"] as Array[StringName])
	var arena: EnemyArena = _warden_arena(2.5, false)
	var warden: EnemyLogic = arena.enemies[0]
	arena.ticks(1)
	assert_eq(warden.get_state(), EnemyLogic.State.CHASE, "between the bands it walks in")
	assert_null(warden.get_running_attack())
	arena.ticks(12)
	assert_almost_eq(warden.get_position_tiles().y, 3.0 * 13.0 / 120.0, TIME, "3 tiles/s")


func test_ac15_stage_2_distance_picks_the_pattern() -> void:
	assert_eq(
		_pattern_at(1.5, true),
		[&"warden_p2_swipe_a", &"warden_p2_swipe_b", &"warden_overhead"] as Array[StringName]
	)
	assert_eq(
		_pattern_at(4.5, true), [&"warden_p2_dashing_cut", &"warden_spin"] as Array[StringName]
	)


func test_ac14_one_scripted_fight_is_the_same_at_every_tick_rate() -> void:
	var runs: Array[Dictionary] = []
	for rate: int in RATES:
		runs.append(_scripted_fight(rate))
	var first: Dictionary = runs[0]
	assert_eq(first["stage_entries"].size(), 1, "it entered stage 2: %s" % [first])
	assert_true(first["crossed_mid_pattern"], "the line was crossed inside a pattern")
	assert_gte(first["follow_ups"].size(), 2, "follow-ups ran in both stages: %s" % [first])
	if first["follow_ups"].size() >= 2 and first["stage_entries"].size() == 1:
		assert_lt(first["follow_ups"][0], first["stage_entries"][0], "a follow-up in stage 1")
		assert_gt(first["follow_ups"][-1], first["stage_entries"][0], "and one in stage 2")
	assert_gt(first["hurt"].size(), 0, "the Warden landed hits")
	assert_gt(first["sword"].size(), 1, "the sword landed hits")
	for index: int in range(1, runs.size()):
		var label: String = "%d vs %d ticks/s" % [RATES[index], RATES[0]]
		for key: String in ["stage_entries", "windups", "hurt", "sword"]:
			_assert_same_times(runs[index][key], first[key], "%s: %s" % [label, key])
		assert_eq(runs[index]["final_hp"], first["final_hp"], label)


## The Warden at the origin, the player `distance` below it, already aggroed. In stage 2 at once
## (its shift runs first) when `stage_2`.
func _warden_arena(distance: float, stage_2: bool) -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data = load(Tunables.WARDEN_PATH)
	arena.add_player(Vector2(0, distance))
	var warden: EnemyLogic = arena.add_chaser(Vector2.ZERO, &"warden")
	if stage_2:
		BossValues.set_hp(warden, 200)
	return arena


## Ids of the attacks of the first pattern the Warden runs, in order.
func _pattern_at(distance: float, stage_2: bool) -> Array[StringName]:
	var arena: EnemyArena = _warden_arena(distance, stage_2)
	var warden: EnemyLogic = arena.enemies[0]
	var ids: Array[StringName] = []
	var started: bool = false
	for _i: int in 600:
		arena.ticks(1)
		var attack: EnemyAttackData = warden.get_running_attack()
		if attack == null:
			if started:
				break
			continue
		started = true
		if ids.is_empty() or ids[-1] != attack.id:
			ids.append(attack.id)
	if stage_2:
		assert_eq(warden.get_stage_index(), 1, "stage 2 is stages[0]")
	return ids


## 6 s of one fight: the player stands below the Warden, swings into its first pattern (which
## takes it under 50 %), steps aside, dashes and swings again. The Warden starts at 205 HP.
func _scripted_fight(rate: int) -> Dictionary:
	var arena: EnemyArena = _warden_arena(1.5, false)
	var warden: EnemyLogic = arena.enemies[0]
	BossValues.set_hp(warden, 205)
	var watch: EnemyWatch = arena.watch(warden)
	var result: Dictionary = {
		"stage_entries": [] as Array[float],
		"follow_ups": [] as Array[float],
		"crossed_mid_pattern": false,
	}
	var sim: CombatSim = arena.sim  # Not the arena: the Warden would keep it alive.
	var on_stage: Callable = func(_index: int) -> void:
		result["stage_entries"].append(sim.get_time())
	warden.stage_changed.connect(on_stage)
	var moves: Dictionary = {}
	for thirtieth: int in range(40, 52):
		moves[thirtieth] = Vector2.RIGHT
	var depth: int = 0
	var ticks_per_30th: int = rate / 30
	for thirtieth: int in 180:
		arena.play(
			rate, thirtieth, thirtieth + 1, moves, [60, 90], [3, 30, 70, 100, 130, 160], Vector2.UP
		)
		if warden.get_pattern_depth() > depth:
			result["follow_ups"].append(arena.sim.get_time())
		depth = warden.get_pattern_depth()
		var hp: int = warden.get_combat_state().get_hp()
		if hp <= 200 and warden.get_stage_index() == 0 and warden.get_running_attack() != null:
			result["crossed_mid_pattern"] = true
	assert_eq(ticks_per_30th * 30, rate)
	warden.stage_changed.disconnect(on_stage)
	result["windups"] = watch.times_entered(EnemyLogic.State.WINDUP)
	result["hurt"] = arena.hurt_times
	result["sword"] = arena.sword_times
	result["final_hp"] = [
		arena.players[0].get_combat_state().get_hp(), warden.get_combat_state().get_hp()
	]
	return result


func _paths(attacks: Array[EnemyAttackData]) -> Array[String]:
	var paths: Array[String] = []
	for attack: EnemyAttackData in attacks:
		paths.append(attack.resource_path)
	return paths


func _assert_same_times(actual: Array, expected: Array, label: String) -> void:
	assert_eq(actual.size(), expected.size(), "%s: %s vs %s" % [label, actual, expected])
	for index: int in mini(actual.size(), expected.size()):
		assert_almost_eq(float(actual[index]), float(expected[index]), TIME, label)
