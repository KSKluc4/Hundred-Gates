extends F007SceneTest
## F-007 T5: AC20 (f) and (g), through CombatRunner's snapshots, with the boss registered after
## the player and the dummy (PR-6).

const REPLAY: int = 200


func test_ac20f_after_shortening_the_chain_a_snapshot_replays_identically() -> void:
	await build()
	await run_ticks(30)
	write(ROOT_PATH, "follow_up", null)
	assert_eq(_runner.reload_data(), PackedStringArray())
	await _assert_replays()


func test_ac20f_after_a_follow_up_edit_a_snapshot_replays_identically() -> void:
	await build()
	await run_ticks(30)
	write(NEXT_PATH, "windup", 0.6)
	assert_eq(_runner.reload_data(), PackedStringArray())
	var replay: Array[Dictionary] = await _assert_replays()
	var windups: Array = replay.filter(func(s: Dictionary) -> bool: return s["attack"] == &"next")
	assert_false(windups.is_empty(), "the follow-up ran in the replay")
	if not windups.is_empty():
		assert_eq(windups[0]["windup"], 0.6)


func test_ac20g_a_snapshot_in_a_stage_the_data_no_longer_lists_is_refused() -> void:
	await build()
	await enter_stage_1()
	await run_ticks(30)
	var in_stage: Dictionary = _runner.take_snapshot()
	_runner.reset()  # Stage 0: now a reload may drop the stage.
	write(BOSS_PATH, "stages", [] as Array[EnemyStageData])
	assert_eq(_runner.reload_data(), PackedStringArray())
	await run_ticks(20)
	var before: Dictionary = _runner.take_snapshot()
	var positions: Array[Vector2] = _positions()
	assert_false(_runner.restore_snapshot(in_stage))
	assert_push_error("snapshot in stage 1, but the data lists only 0 stages")
	assert_eq(_runner.take_snapshot(), before, "nothing changed, the player and dummy included")
	assert_eq(_positions(), positions, "no body moved")


func _positions() -> Array[Vector2]:
	return [_player.global_position, _dummy.global_position, _boss.global_position]


## Takes a snapshot now, records REPLAY ticks, restores it, replays, and compares.
func _assert_replays() -> Array[Dictionary]:
	var snapshot: Dictionary = _runner.take_snapshot()
	var original: Array[Dictionary] = await _record()
	assert_true(_runner.restore_snapshot(snapshot))
	var replay: Array[Dictionary] = await _record()
	for index: int in REPLAY:
		assert_eq(replay[index], original[index], "tick %d after the restore" % index)
		if replay[index] != original[index]:
			break
	return replay


func _record() -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	for _i: int in REPLAY:
		await run_ticks(1)
		var logic: EnemyLogic = _boss.logic
		var attack: EnemyAttackData = logic.get_running_attack()
		(
			samples
			. append(
				{
					"state": logic.get_state(),
					"attack": attack.id if attack != null else &"",
					"windup": attack.windup if attack != null else 0.0,
					"depth": logic.get_pattern_depth(),
					"gap": logic.has_pending_follow_up(),
					"stage": logic.get_stage_index(),
					"cooldown": snappedf(logic.get_cooldown_remaining(), TIME),
					"aim": logic.get_aim(),
					"target": logic.get_target_id(),
				}
			)
		)
	return samples
