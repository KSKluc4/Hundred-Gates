extends F004SceneTest
## AC20b: the speed rule at scene setup (C12). A fight whose data breaks it never starts.


func test_ac20b_a_chaser_as_fast_as_the_warrior_stops_the_fight() -> void:
	var fast: EnemyData = chaser_copy()
	fast.move_speed = 5.0
	await spawn(func() -> void: _chasers[0].data = fast)
	assert_push_error("CombatRunner")
	await wait_physics_frames(10)
	var errors: PackedStringArray = _runner.get_setup_errors()
	assert_eq(errors.size(), 1, "only chaser_1 has the fast data: %s" % [errors])
	assert_string_contains(errors[0], "chaser_1")
	assert_string_contains(errors[0], "move_speed 5.0 must be below class warrior move_speed 5.0")
	assert_eq(_runner.get_sim().get_time(), 0.0, "nothing stepped")
	assert_false(_runner.is_physics_processing())


func test_ac20b_a_warrior_slowed_to_the_chaser_stops_the_fight() -> void:
	var slow: ClassData = (load(Tunables.WARRIOR_PATH) as ClassData).duplicate()
	slow.move_speed = 3.0
	await spawn(func() -> void: _player.class_data = slow)
	assert_push_error_count(3, "one per chaser")
	await wait_physics_frames(10)
	var errors: PackedStringArray = _runner.get_setup_errors()
	assert_eq(errors.size(), 3, "every chaser against the class: %s" % [errors])
	for index: int in errors.size():
		assert_string_contains(errors[index], "chaser_%d" % (index + 1))
		assert_string_contains(errors[index], "move_speed 3.0 must be below class warrior")
		assert_string_contains(errors[index], "move_speed 3.0")
	assert_eq(_runner.get_sim().get_time(), 0.0, "nothing stepped")


func test_ac20b_with_default_data_the_list_is_empty_and_the_fight_runs() -> void:
	await spawn()
	await wait_physics_frames(10)
	assert_eq(_runner.get_setup_errors().size(), 0)
	assert_gt(_runner.get_sim().get_time(), 0.0)
	assert_true(_runner.is_physics_processing())
