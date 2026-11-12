extends F007SceneTest
## F-007 T4: AC12 on reload and at scene setup, and AC20 (a)-(e): CombatRunner.reload_data()
## against the live stage (C19) and mid-pattern (C9), in a scene with a player, a dummy and
## the boss registered last.


func test_ac12_every_bad_stage_or_follow_up_is_rejected_on_reload_naming_file_and_rule() -> void:
	var cases: Array[Array] = [
		[_edit.bind(NEXT_PATH, "windup", 0.4), BOSS_PATH, "next: windup - aim_track_time"],
		[_edit.bind(STAGE_PATH, "enter_at_hp_percent", 0), STAGE_PATH, "1-99"],
		[_edit.bind(STAGE_PATH, "enter_at_hp_percent", 100), STAGE_PATH, "1-99"],
		[_edit.bind(STAGE_PATH, "shift_duration", -0.1), STAGE_PATH, "shift_duration must be"],
		[_edit.bind(STAGE_PATH, "move_speed", 5.0), STAGE_PATH, "must be below class warrior"],
		[_edit.bind(STAGE_PATH, "move_speed", -1.0), STAGE_PATH, "move_speed must be >= 0"],
		[_edit.bind(STAGE_PATH, "attack_cooldown", -0.1), STAGE_PATH, "attack_cooldown must be"],
		[_two_stages.bind(50), STAGE_2_PATH, "must be below the previous stage's (50)"],
		[_null_stage, BOSS_PATH, "stages[1] must not be null"],
	]
	for entry: Array in cases:
		write_copies()
		await build()
		var before: Dictionary = reload_touches()
		(entry[0] as Callable).call()
		var errors: PackedStringArray = _runner.reload_data()
		var text: String = "\n".join(errors)
		assert_false(errors.is_empty(), "rejected: %s" % entry[2])
		assert_string_contains(text, entry[1])
		assert_string_contains(text, entry[2])
		assert_eq(reload_touches(), before, "nothing changed: %s" % entry[2])
		_scene.free()


func test_ac12_a_follow_up_cycle_across_files_is_rejected_before_loading() -> void:
	await build()
	var before: Dictionary = reload_touches()
	# root -> next -> root. Godot's loader would never return from it.
	write(NEXT_PATH, "follow_up", fresh(ROOT_PATH))
	var errors: PackedStringArray = _runner.reload_data()
	assert_eq(errors.size(), 1, str(errors))
	if errors.size() == 1:
		assert_string_contains(errors[0], "%s: follow_up files form a cycle: " % BOSS_PATH)
		assert_string_contains(errors[0], "%s -> %s -> %s" % [ROOT_PATH, NEXT_PATH, ROOT_PATH])
	assert_eq(reload_touches(), before, "nothing changed")


func test_ac12_an_all_zero_stage_passes_on_reload() -> void:
	await build()
	write(STAGE_PATH, "move_speed", 0.0)
	write(STAGE_PATH, "attack_cooldown", 0.0)
	write(STAGE_PATH, "shift_duration", 0.0)
	assert_eq(_runner.reload_data(), PackedStringArray())
	assert_eq(_boss.logic.get_data().stages[0].shift_duration, 0.0)


func test_ac12_a_stage_speed_at_the_warrior_s_stops_the_scene_at_setup() -> void:
	write(STAGE_PATH, "move_speed", 5.0)
	await build()
	var errors: PackedStringArray = _runner.get_setup_errors()
	assert_eq(errors.size(), 1, str(errors))
	if errors.size() == 1:
		assert_string_contains(errors[0], "stages[0] (%s) move_speed 5" % STAGE_PATH)
	assert_push_error("must be below class warrior")
	assert_false(_runner.is_physics_processing())


func test_ac12_a_bad_stage_is_refused_by_the_boss_at_setup() -> void:
	write(STAGE_PATH, "shift_duration", -0.1)
	await build()
	assert_null(_boss.logic.get_data())
	assert_push_error_count(3, "the boss at _ready() and at the reset, and the runner")
	assert_string_contains("\n".join(_runner.get_setup_errors()), "boss_1: setup refused")


func test_ac20a_a_reload_dropping_the_live_stage_is_refused_as_a_whole() -> void:
	await build()
	await enter_stage_1()
	await run_until(func() -> bool: return boss_state() != EnemyLogic.State.STAGE_SHIFT)
	await run_until(func() -> bool: return boss_state() == EnemyLogic.State.WINDUP)
	assert_eq(_boss.logic.get_running_attack().id, &"stage_swipe")
	var before: Dictionary = reload_touches()
	write(ROOT_PATH, "damage", 33)  # Valid, and must not go in either.
	write(BOSS_PATH, "stages", [] as Array[EnemyStageData])
	var errors: PackedStringArray = _runner.reload_data()
	assert_eq(
		errors, PackedStringArray(["boss_1: in stage 1, but %s lists only 0 stages" % BOSS_PATH])
	)
	assert_eq(reload_touches(), before, "nothing changed anywhere")
	assert_eq(_boss.logic.get_data().attacks[1].damage, 20)


func test_ac20b_refused_mid_shift_the_shift_goes_on() -> void:
	await build()
	await enter_stage_1()
	await run_ticks(30)
	assert_eq(boss_state(), EnemyLogic.State.STAGE_SHIFT)
	var before: Dictionary = reload_touches()
	write(BOSS_PATH, "stages", [] as Array[EnemyStageData])
	assert_false(_runner.reload_data().is_empty())
	assert_eq(reload_touches(), before)
	var left: float = _boss.logic.get_stage_shift_left()
	await run_ticks(12)
	assert_almost_eq(_boss.logic.get_stage_shift_left(), left - 0.1, TIME, "unchanged, going on")


func test_ac20_an_accepted_reload_keeps_stage_shift_and_cooldown() -> void:
	await build()
	await enter_stage_1()
	await run_ticks(30)
	var left: float = _boss.logic.get_stage_shift_left()
	write(STAGE_PATH, "shift_duration", 3.0)
	write(STAGE_PATH, "attack_cooldown", 0.2)
	assert_eq(_runner.reload_data(), PackedStringArray())
	assert_eq(_boss.logic.get_stage_index(), 1)
	assert_eq(_boss.logic.get_stage_shift_left(), left, "a new shift_duration waits for a shift")
	assert_eq(_boss.logic.get_current_attack_cooldown(), 0.2)


func test_ac20c_shortening_the_chain_mid_pattern_ends_it_after_the_running_attack() -> void:
	await build()
	await run_ticks(30)
	assert_eq(_boss.logic.get_running_attack().id, &"root")
	write(ROOT_PATH, "follow_up", null)
	assert_eq(_runner.reload_data(), PackedStringArray())
	var latched: EnemyAttackData = _boss.logic.get_running_attack()
	await run_until(func() -> bool: return boss_state() == EnemyLogic.State.RECOVERY)
	assert_eq(_boss.logic.get_running_attack(), latched, "finishes as latched")
	assert_false(_boss.logic.has_pending_follow_up(), "no gap any more")
	await run_until(func() -> bool: return boss_state() != EnemyLogic.State.RECOVERY)
	assert_almost_eq(run_time(), 1.2, TIME, "the root's own recovery end")
	assert_ne(boss_state(), EnemyLogic.State.WINDUP, "no follow-up")
	assert_almost_eq(_boss.logic.get_cooldown_remaining(), 0.8, 1.0 / 120.0 + TIME, "cooldown")


func test_ac20d_a_new_follow_up_windup_applies_to_the_next_follow_up() -> void:
	await build()
	await run_ticks(30)
	write(NEXT_PATH, "windup", 0.6)
	assert_eq(_runner.reload_data(), PackedStringArray())
	assert_eq(_boss.logic.get_running_attack().windup, 0.5, "the root keeps its latched windup")
	await run_until(func() -> bool: return _boss.logic.get_pattern_depth() == 1)
	assert_eq(_boss.logic.get_running_attack().id, &"next")
	assert_eq(_boss.logic.get_running_attack().windup, 0.6, "the follow-up uses the edit")


func test_ac20e_removing_the_root_index_ends_the_pattern_after_the_running_attack() -> void:
	await build()
	await run_ticks(30)
	assert_eq(_boss.logic.get_pattern_root_index(), 1)
	write(BOSS_PATH, "attacks", [fresh(FILLER_PATH)] as Array[EnemyAttackData])
	assert_eq(_runner.reload_data(), PackedStringArray())
	await run_until(func() -> bool: return boss_state() == EnemyLogic.State.RECOVERY)
	assert_false(_boss.logic.has_pending_follow_up())
	await run_until(func() -> bool: return boss_state() != EnemyLogic.State.RECOVERY)
	assert_almost_eq(run_time(), 1.2, TIME)
	assert_ne(boss_state(), EnemyLogic.State.WINDUP, "no follow-up")


func _edit(path: String, field: String, value: Variant) -> void:
	write(path, field, value)


## Two stages at `percent` and the second file's.
func _two_stages(percent: int) -> void:
	write(STAGE_2_PATH, "enter_at_hp_percent", percent)
	write(BOSS_PATH, "stages", [fresh(STAGE_PATH), fresh(STAGE_2_PATH)] as Array[EnemyStageData])


func _null_stage() -> void:
	write(BOSS_PATH, "stages", [fresh(STAGE_PATH), null] as Array[EnemyStageData])
