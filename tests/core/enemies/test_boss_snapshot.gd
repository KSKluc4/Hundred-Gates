extends GutTest
## F-007 T5: snapshots of stages and patterns (C14). AC13 (mid-gap, mid-shift) on a real sim,
## and the refusal of a stage the data doesn't list, before anything is restored.

const TIME: float = EnemyArena.TIME
## Steps replayed after a restore.
const REPLAY: int = 240


func test_ac13a_a_restore_mid_gap_replays_identically() -> void:
	var arena: EnemyArena = _boss_arena()
	var enemy: EnemyLogic = arena.enemies[0]
	arena.ticks(96)  # 0.8 s: in root's recovery, a gap before next.
	assert_eq(enemy.get_state(), EnemyLogic.State.RECOVERY)
	assert_true(enemy.has_pending_follow_up())
	_assert_replays(arena, enemy)


func test_ac13b_a_restore_mid_shift_replays_identically() -> void:
	var arena: EnemyArena = _boss_arena()
	var enemy: EnemyLogic = arena.enemies[0]
	BossValues.set_hp(enemy, 200)
	arena.ticks(60)
	assert_eq(enemy.get_state(), EnemyLogic.State.STAGE_SHIFT)
	assert_almost_eq(enemy.get_stage_shift_left(), 0.7, TIME)
	_assert_replays(arena, enemy)


func test_c14_the_snapshot_holds_stage_shift_and_pattern_position() -> void:
	var arena: EnemyArena = _boss_arena()
	var enemy: EnemyLogic = arena.enemies[0]
	arena.ticks(160)  # In next: depth 1.
	var snapshot: Dictionary = enemy.to_dict()
	assert_eq(snapshot["pattern_root_index"], 0)
	assert_eq(snapshot["pattern_depth"], 1)
	assert_eq(snapshot["stage_index"], 0)
	assert_eq(snapshot["stage_shift_left"], 0.0)
	assert_false(snapshot["attack"].has("follow_up"), "the running attack stays by value")


func test_c14_a_pattern_position_that_no_longer_resolves_just_ends_the_pattern() -> void:
	var arena: EnemyArena = _boss_arena()
	var enemy: EnemyLogic = arena.enemies[0]
	arena.ticks(96)
	var snapshot: Dictionary = enemy.to_dict()
	snapshot["pattern_root_index"] = 5
	enemy.from_dict(snapshot)
	assert_eq(enemy.get_pattern_root_index(), 5, "restored, not an error")
	assert_false(enemy.has_pending_follow_up())
	arena.ticks(60)
	assert_ne(enemy.get_running_attack().id if enemy.get_running_attack() else &"", &"next")


func test_c14_a_stage_the_data_does_not_list_is_refused_by_the_enemy() -> void:
	var arena: EnemyArena = _boss_arena()
	var enemy: EnemyLogic = arena.enemies[0]
	arena.ticks(30)
	var before: Dictionary = enemy.to_dict()
	var snapshot: Dictionary = before.duplicate()
	snapshot["stage_index"] = 2
	snapshot["position"] = Vector2(3, 3)
	assert_eq(enemy.restore_errors(snapshot).size(), 1)
	enemy.from_dict(snapshot)
	assert_push_error("snapshot in stage 2, but the data lists only 1 stages")
	assert_eq(enemy.to_dict(), before, "nothing changed")
	snapshot["stage_index"] = 1
	assert_eq(enemy.restore_errors(snapshot), PackedStringArray(), "stage 1 is listed")


func test_c14_the_sim_refuses_it_before_restoring_anyone() -> void:
	var arena: EnemyArena = _boss_arena()
	arena.ticks(30)
	var early: Dictionary = arena.sim.to_dict()
	arena.ticks(30)
	var before: Dictionary = arena.sim.to_dict()
	var bad: Dictionary = early.duplicate(true)
	bad["combatants"][&"boss_1"]["stage_index"] = 3
	assert_false(arena.sim.from_dict(bad))
	assert_push_error("snapshot in stage 3")
	assert_eq(arena.sim.to_dict(), before, "the player, registered first, wasn't restored either")


## The chaser boss: root then next, one stage at 50 %. The player stands in reach.
func _boss_arena() -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	arena.chaser_data = BossValues.chaser_boss()
	arena.add_player(Vector2(0, 1.0))
	arena.add_chaser(Vector2.ZERO, &"boss_1")
	return arena


## Records REPLAY steps, restores the snapshot taken first, replays, and compares.
func _assert_replays(arena: EnemyArena, enemy: EnemyLogic) -> void:
	var snapshot: Dictionary = arena.sim.to_dict()
	var original: Array[Dictionary] = _record(arena, enemy)
	assert_true(arena.sim.from_dict(snapshot))
	assert_eq(enemy.has_pending_follow_up(), original[0]["gap_before"], "the cue, restored")
	var replay: Array[Dictionary] = _record(arena, enemy)
	for index: int in REPLAY:
		assert_eq(replay[index], original[index], "step %d after the restore" % index)
		if replay[index] != original[index]:
			return


func _record(arena: EnemyArena, enemy: EnemyLogic) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	var gap_before: bool = enemy.has_pending_follow_up()
	for _i: int in REPLAY:
		arena.tick()
		var attack: EnemyAttackData = enemy.get_running_attack()
		(
			samples
			. append(
				{
					"gap_before": gap_before,
					"stage": enemy.get_stage_index(),
					"shift_left": snappedf(enemy.get_stage_shift_left(), TIME),
					"state": enemy.get_state(),
					"attack": attack.to_dict() if attack != null else {},
					"depth": enemy.get_pattern_depth(),
					"target": enemy.get_target_id(),
					"aim": enemy.get_aim(),
					"position": enemy.get_position_tiles(),
					"hp": arena.players[0].get_combat_state().get_hp(),
				}
			)
		)
		gap_before = enemy.has_pending_follow_up()
	return samples
