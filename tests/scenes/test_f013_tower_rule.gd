extends F012GameTest
## F-013 T5 (AC10, C7): a `Game` on a fixture tower whose `screen_size_tiles` is larger than one
## of its rooms builds nothing and says why; with the rule off, or with every room large enough,
## it builds as before. The fixture tower has a 24 x 14 town and 12 x 8 floor rooms.


func test_ac10_a_room_smaller_than_the_screen_builds_nothing_and_reports_it() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	tower.screen_size_tiles = Vector2i(13, 8)
	await spawn_game(tower)
	var errors: PackedStringArray = game().get_setup_errors()
	assert_eq(errors.size(), 4, "the two rooms of each floor, not the town: %s" % errors)
	assert_true(
		_any(errors, "floor 1: screen: room f1_room_1 is 12 x 8, smaller than one screen (13 x 8)"),
		str(errors)
	)
	assert_true(
		_any(errors, "floor 2: screen: room f2_boss is 12 x 8, smaller than one screen (13 x 8)"),
		str(errors)
	)
	for error: String in errors:
		assert_push_error(error)
	_assert_nothing_built()


func test_ac10_a_town_smaller_than_the_screen_builds_nothing_and_reports_it() -> void:
	var tower: TowerData = TowerFixtures.tower_of(1)
	tower.screen_size_tiles = Vector2i(12, 15)
	await spawn_game(tower)
	var errors: PackedStringArray = game().get_setup_errors()
	assert_true(
		_any(errors, "town: screen: room town is 24 x 14, smaller than one screen (12 x 15)"),
		str(errors)
	)
	for error: String in errors:
		assert_push_error(error)
	_assert_nothing_built()


func test_ac10_a_tower_that_leaves_the_rule_at_zero_builds_normally() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	assert_eq(tower.screen_size_tiles, Vector2i.ZERO)
	await spawn_game(tower)
	assert_eq(game().get_setup_errors(), PackedStringArray())
	assert_not_null(town())
	assert_true(game().is_physics_processing())


func test_ac10_a_tower_whose_rooms_are_exactly_one_screen_large_builds_normally() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	tower.screen_size_tiles = Vector2i(12, 8)
	await spawn_game(tower)
	assert_eq(game().get_setup_errors(), PackedStringArray())
	assert_not_null(town())
	await enter_floor_through_gate(1)
	assert_not_null(floor_scene(), "and a floor can be entered")


func _assert_nothing_built() -> void:
	assert_null(session())
	assert_null(town())
	assert_null(floor_scene())
	assert_null(game().get_player())
	assert_false(game().is_physics_processing(), "nothing steps")
	assert_eq(game().get_child_count(), 1, "only the HUD")


func _any(errors: PackedStringArray, part: String) -> bool:
	for error: String in errors:
		if error.contains(part):
			return true
	return false
