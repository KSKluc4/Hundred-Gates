# gdlint:disable=max-public-methods
extends GutTest
## F-016 T2 (C9-C11, C16, AC9, AC11-AC14): RoomLoot rolls for each death at the end of a step, lays
## the drop where the enemy died, lets the player take it by walking, and reports every take to the
## character. Driven by calling end_step() the way CombatSim does, on scripted actors.

const SEED: int = 777
const FLOOR: int = 2
const FAR: Vector2 = Vector2(30, 30)
const ENEMY_AT: Vector2 = Vector2(5, 5)
const BOSS_PERCENTS: Array[int] = [30, 20, 10]
const KILLS: int = 1000

var _tower: TowerData
var _pool: Array[SwordData]
var _boss_swords: Array[SwordData]
var _radius: float
var _catalog: LootCatalog
var _character: CharacterLoot
var _player: LootFixtures.Actor


func before_each() -> void:
	_tower = TowerFixtures.tower_of(3, 2)
	_pool = ItemFixtures.valid_swords(5)
	_boss_swords = [
		ItemFixtures.make_sword(&"boss_a", 45),
		ItemFixtures.make_sword(&"boss_b", 46),
		ItemFixtures.make_sword(&"boss_c", 47),
	]
	_radius = ItemFixtures.rules().pickup_radius_tiles
	_catalog = _catalog_with(2.0, _pool, _boss_swords)  # two kills a floor: a chance of 1
	_character = LootFixtures.character(_catalog, SEED)
	_player = LootFixtures.player(FAR)


func _catalog_with(
	drops_per_run: float, pool: Array[SwordData], boss: Array[SwordData]
) -> LootCatalog:
	var tables: Array[FloorLoot] = []
	for _floor: int in _tower.get_floor_count():
		tables.append(
			ItemFixtures.floor_loot(drops_per_run, pool, boss, PackedInt32Array(BOSS_PERCENTS))
		)
	return ItemFixtures.catalog_of(ItemFixtures.starter(), tables)


## The room `room_index` of the floor under test, with the player watched.
func _room(room_index: int = 0, character: CharacterLoot = _character) -> RoomLoot:
	var room: RoomLoot = LootFixtures.room_loot(character, _tower, FLOOR, room_index)
	room.watch_player(_player)
	return room


func _boss_room(character: CharacterLoot = _character) -> RoomLoot:
	return _room(_tower.get_floor(FLOOR).get_room_count() - 1, character)


func _reference() -> RandomNumberGenerator:
	var reference: RandomNumberGenerator = RandomNumberGenerator.new()
	reference.seed = SEED
	return reference


func _ids(drops: Array[LootDrop]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for drop: LootDrop in drops:
		ids.append(drop.sword_id)
	return ids


## A watched enemy of `room` at `at`.
func _watched(room: RoomLoot, at: Vector2 = ENEMY_AT) -> LootFixtures.Actor:
	var enemy: LootFixtures.Actor = LootFixtures.enemy(&"enemy", at)
	room.watch_enemy(enemy)
	return enemy


func _owned_count() -> int:
	var total: int = 0
	var inventory: Inventory = _character.get_inventory()
	for sword_id: StringName in inventory.get_ids():
		total += inventory.get_count(sword_id)
	return total


# --- AC13: where and when a drop appears ---


func test_ac13_a_drop_appears_where_the_enemy_died_at_the_end_of_the_step() -> void:
	var room: RoomLoot = _room()
	var enemy: LootFixtures.Actor = _watched(room)
	enemy.kill()
	assert_true(room.get_drops().is_empty(), "nothing before the step ends")
	room.end_step()
	var drops: Array[LootDrop] = room.get_drops()
	assert_eq(drops.size(), 1)
	assert_eq(drops[0].position, ENEMY_AT)
	assert_eq(drops[0].boss_floor, 0, "a regular drop")
	var pool_ids: Array[StringName] = [
		_pool[0].id, _pool[1].id, _pool[2].id, _pool[3].id, _pool[4].id
	]
	assert_true(pool_ids.has(drops[0].sword_id), "a sword of the pool")


func test_ac13_the_drop_lies_where_the_enemy_is_when_the_step_ends() -> void:
	var room: RoomLoot = _room()
	var enemy: LootFixtures.Actor = _watched(room, Vector2(1, 1))
	enemy.kill()
	enemy.place(Vector2(2.5, 3.5))
	room.end_step()
	assert_eq(room.get_drops()[0].position, Vector2(2.5, 3.5))


func test_ac13_a_player_just_inside_the_radius_takes_it_in_that_step() -> void:
	var room: RoomLoot = _room()
	_player.place(ENEMY_AT + Vector2(_radius - 0.01, 0))
	_watched(room).kill()
	room.end_step()
	assert_true(room.get_drops().is_empty(), "taken")
	assert_eq(_owned_count(), 2, "the starter and the drop")
	assert_eq(room.pop_taken().size(), 1)


func test_ac13_a_player_just_outside_the_radius_does_not() -> void:
	var room: RoomLoot = _room()
	_player.place(ENEMY_AT + Vector2(_radius + 0.01, 0))
	_watched(room).kill()
	room.end_step()
	assert_eq(room.get_drops().size(), 1)
	assert_eq(_owned_count(), 1, "only the starter")
	assert_true(room.pop_taken().is_empty())


func test_ac13_the_radius_itself_takes_and_a_diagonal_is_measured_centre_to_centre() -> void:
	var room: RoomLoot = _room()
	_player.place(ENEMY_AT + Vector2(_radius, 0))
	_watched(room).kill()
	room.end_step()
	assert_true(room.get_drops().is_empty(), "exactly the radius takes")
	var diagonal: RoomLoot = _room()
	var step: float = (_radius + 0.01) / sqrt(2.0)
	_player.place(ENEMY_AT + Vector2(step, step))
	_watched(diagonal).kill()
	diagonal.end_step()
	assert_eq(diagonal.get_drops().size(), 1, "0.01 outside along a diagonal")
	_player.place(ENEMY_AT + Vector2(step - 0.02, step - 0.02))
	diagonal.end_step()
	assert_true(diagonal.get_drops().is_empty(), "walking in takes it at the next step")


func test_ac13_a_drop_is_taken_at_the_step_the_player_comes_into_reach() -> void:
	var room: RoomLoot = _room()
	_watched(room).kill()
	room.end_step()
	for x: float in [10.0, 8.0, 6.0, 5.9]:
		_player.place(Vector2(x, 5))
		room.end_step()
		assert_eq(room.get_drops().size(), 1, "at x = %.1f it still lies" % x)
	_player.place(Vector2(5.8, 5))
	room.end_step()
	assert_true(room.get_drops().is_empty())
	assert_eq(room.pop_taken().size(), 1)


func test_ac13_a_taken_sword_is_in_the_inventory_and_a_second_one_is_a_count() -> void:
	var catalog: LootCatalog = _catalog_with(2.0, [_pool[0]] as Array[SwordData], _boss_swords)
	var character: CharacterLoot = LootFixtures.character(catalog, SEED)
	var room: RoomLoot = _room(0, character)
	_player.place(ENEMY_AT)
	_watched(room).kill()
	room.end_step()
	assert_eq(character.get_inventory().get_count(_pool[0].id), 1)
	_watched(room).kill()
	room.end_step()
	assert_eq(character.get_inventory().get_count(_pool[0].id), 2, "owned twice is a count")
	assert_eq(room.pop_taken(), [_pool[0].id, _pool[0].id] as Array[StringName])


func test_ac13_two_drops_in_reach_are_taken_in_drop_order() -> void:
	var room: RoomLoot = _room()
	var first: LootFixtures.Actor = _watched(room, ENEMY_AT)
	var second: LootFixtures.Actor = _watched(room, ENEMY_AT + Vector2(0.3, 0))
	_player.place(ENEMY_AT)
	var reference: RandomNumberGenerator = _reference()
	var expected: Array[StringName] = []
	for _i: int in 2:
		reference.randf()
		expected.append(_pool[reference.randi_range(0, 4)].id)
	second.kill()  # the order the deaths happened in, not the order they were watched in
	first.kill()
	room.end_step()
	assert_true(room.get_drops().is_empty())
	assert_eq(room.pop_taken(), expected, "both, in the order they dropped")


func test_c9_the_drops_lie_in_the_order_they_dropped() -> void:
	var room: RoomLoot = _room()
	var enemies: Array[LootFixtures.Actor] = []
	for index: int in 4:
		enemies.append(_watched(room, Vector2(5 + index, 5)))
	enemies[2].kill()
	room.end_step()
	enemies[0].kill()
	enemies[3].kill()
	room.end_step()
	enemies[1].kill()
	room.end_step()
	var xs: Array[float] = []
	for drop: LootDrop in room.get_drops():
		xs.append(drop.position.x)
	assert_eq(xs, [7.0, 5.0, 8.0, 6.0] as Array[float])


func test_c9_deaths_between_steps_are_rolled_in_the_order_they_happened() -> void:
	var room: RoomLoot = _room()
	var enemies: Array[LootFixtures.Actor] = []
	for index: int in 3:
		enemies.append(_watched(room, Vector2(5 + index, 5)))
	enemies[2].kill()
	enemies[0].kill()
	enemies[1].kill()
	assert_true(room.get_drops().is_empty())
	room.end_step()
	var xs: Array[float] = []
	for drop: LootDrop in room.get_drops():
		xs.append(drop.position.x)
	assert_eq(xs, [7.0, 5.0, 6.0] as Array[float])


func test_c9_get_drops_is_a_copy() -> void:
	var room: RoomLoot = _room()
	_watched(room).kill()
	room.end_step()
	room.get_drops().clear()
	assert_eq(room.get_drops().size(), 1)


func test_c9_pop_taken_empties_the_list() -> void:
	var room: RoomLoot = _room()
	_player.place(ENEMY_AT)
	_watched(room).kill()
	room.end_step()
	assert_eq(room.pop_taken().size(), 1)
	assert_true(room.pop_taken().is_empty())


# --- AC14: the player's death ---


func test_ac14_a_dead_player_takes_nothing_by_walking_but_the_deaths_are_still_rolled() -> void:
	var room: RoomLoot = _room()
	_player.place(ENEMY_AT)
	_player.kill()
	var enemy: LootFixtures.Actor = _watched(room)
	enemy.kill()
	room.end_step()
	assert_eq(room.get_drops().size(), 1, "rolled, and it lies")
	assert_eq(_owned_count(), 1, "nothing taken")
	assert_true(room.pop_taken().is_empty())
	room.end_step()
	assert_eq(room.get_drops().size(), 1, "still nothing at the next step")


func test_ac14_a_dead_player_takes_nothing_by_take_all() -> void:
	var room: RoomLoot = _room()
	for index: int in 3:
		_watched(room, Vector2(5 + index, 5)).kill()
	room.end_step()
	_player.kill()
	room.take_all()
	assert_eq(room.get_drops().size(), 3)
	assert_eq(_owned_count(), 1)
	assert_true(room.pop_taken().is_empty())


func test_ac14_a_player_dying_in_the_same_step_takes_nothing_of_what_that_step_dropped() -> void:
	var room: RoomLoot = _room()
	_player.place(ENEMY_AT)
	var enemy: LootFixtures.Actor = _watched(room)
	enemy.kill()
	_player.kill()  # the same step, the player's end of it
	room.end_step()
	assert_eq(room.get_drops().size(), 1)
	assert_eq(_owned_count(), 1)


func test_ac14_an_enemy_dying_after_the_player_is_rolled_too() -> void:
	var room: RoomLoot = _room()
	_player.kill()
	room.end_step()
	var enemy: LootFixtures.Actor = _watched(room)
	enemy.kill()
	room.end_step()
	assert_eq(room.get_drops().size(), 1)


func test_ac14_an_enemy_that_dies_twice_is_rolled_once() -> void:
	var room: RoomLoot = _room()
	_player.place(FAR)
	var enemy: LootFixtures.Actor = _watched(room)
	enemy.kill()
	room.end_step()
	enemy.revive()
	enemy.kill()
	room.end_step()
	assert_eq(room.get_drops().size(), 1)
	var reference: RandomNumberGenerator = _reference()
	reference.randf()
	reference.randi_range(0, 4)
	assert_eq(_character.get_roller().get_state(), reference.state, "one roll, one drop's draws")


func test_ac14_two_deaths_of_one_enemy_in_one_step_are_rolled_once() -> void:
	var room: RoomLoot = _room()
	var enemy: LootFixtures.Actor = _watched(room)
	enemy.kill()
	enemy.revive()
	enemy.kill()
	room.end_step()
	assert_eq(room.get_drops().size(), 1)


func test_c9_watching_one_enemy_twice_rolls_it_once() -> void:
	var room: RoomLoot = _room()
	var enemy: LootFixtures.Actor = _watched(room)
	room.watch_enemy(enemy)
	enemy.kill()
	room.end_step()
	assert_eq(room.get_drops().size(), 1)


func test_c9_an_enemy_that_never_dies_is_never_rolled() -> void:
	var room: RoomLoot = _room()
	_watched(room)
	room.end_step()
	room.end_step()
	assert_true(room.get_drops().is_empty())
	assert_eq(_character.get_roller().get_state(), _reference().state, "no draw")


func test_c9_with_no_player_watched_nothing_is_taken_by_walking() -> void:
	var room: RoomLoot = LootFixtures.room_loot(_character, _tower, FLOOR, 0)
	_watched(room).kill()
	room.end_step()
	room.end_step()
	assert_eq(room.get_drops().size(), 1)
	assert_eq(_owned_count(), 1)


# --- C16: take_all ---


func test_c16_take_all_takes_the_rest_in_drop_order_wherever_the_player_is() -> void:
	var room: RoomLoot = _room()
	for index: int in 4:
		_watched(room, Vector2(5 + index, 5)).kill()
	room.end_step()
	var lying: Array[StringName] = _ids(room.get_drops())
	room.take_all()
	assert_true(room.get_drops().is_empty())
	assert_eq(room.pop_taken(), lying, "all four, in drop order")
	assert_eq(_owned_count(), 5)
	room.take_all()
	assert_true(room.pop_taken().is_empty(), "a second call has nothing to take")


func test_c16_take_all_with_nothing_lying_does_nothing() -> void:
	var room: RoomLoot = _room()
	room.take_all()
	assert_true(room.pop_taken().is_empty())
	assert_eq(_owned_count(), 1)


func test_c16_a_boss_sword_taken_by_take_all_ends_the_guarantee() -> void:
	var room: RoomLoot = _boss_room()
	_watched(room).kill()
	room.end_step()
	assert_false(_character.is_boss_sword_taken(FLOOR))
	room.take_all()
	assert_true(_character.is_boss_sword_taken(FLOOR))


func test_c16_take_all_while_the_player_lives_takes_even_with_none_watched() -> void:
	var room: RoomLoot = LootFixtures.room_loot(_character, _tower, FLOOR, 0)
	_watched(room).kill()
	room.end_step()
	room.take_all()
	assert_true(room.get_drops().is_empty())
	assert_eq(_owned_count(), 2)


# --- C10, C11: what draws and what does not ---


func _assert_draws_nothing(character: CharacterLoot, room_index: int, message: String) -> void:
	var before: Dictionary = character.get_roller().to_dict()
	var room: RoomLoot = _room(room_index, character)
	_watched(room).kill()
	room.end_step()
	assert_true(room.get_drops().is_empty(), "%s: no drop" % message)
	assert_eq_deep(character.get_roller().to_dict(), before)


func test_ac9_a_character_without_a_catalog_draws_nothing() -> void:
	var bare: CharacterLoot = LootFixtures.character(null, SEED)
	_assert_draws_nothing(bare, 0, "regular room")
	_assert_draws_nothing(bare, 2, "boss room")


func test_ac9_a_floor_without_a_loot_table_draws_nothing() -> void:
	var tables: Array[FloorLoot] = [null, null, null]
	var catalog: LootCatalog = ItemFixtures.catalog_of(ItemFixtures.starter(), tables)
	var character: CharacterLoot = LootFixtures.character(catalog, SEED)
	_assert_draws_nothing(character, 0, "regular room")
	_assert_draws_nothing(character, 2, "boss room")


func test_ac9_an_empty_pool_draws_nothing_in_a_regular_room_and_the_boss_still_rolls() -> void:
	var catalog: LootCatalog = _catalog_with(2.0, [] as Array[SwordData], _boss_swords)
	var character: CharacterLoot = LootFixtures.character(catalog, SEED)
	_assert_draws_nothing(character, 0, "regular room")
	var boss: RoomLoot = _boss_room(character)
	_watched(boss).kill()
	boss.end_step()
	assert_eq(boss.get_drops().size(), 1, "the boss table is another table")


func test_ac9_zero_drops_per_run_draws_nothing_in_a_regular_room_and_the_boss_still_rolls() -> void:
	var catalog: LootCatalog = _catalog_with(0.0, _pool, _boss_swords)
	var character: CharacterLoot = LootFixtures.character(catalog, SEED)
	_assert_draws_nothing(character, 0, "regular room")
	var boss: RoomLoot = _boss_room(character)
	_watched(boss).kill()
	boss.end_step()
	assert_eq(boss.get_drops().size(), 1)


func test_ac9_an_empty_boss_table_draws_nothing_in_the_boss_room_and_regular_rooms_still_roll(
) -> void:
	var catalog: LootCatalog = _catalog_with(2.0, _pool, [] as Array[SwordData])
	catalog.floors[FLOOR - 1].boss_percents = PackedInt32Array()
	var character: CharacterLoot = LootFixtures.character(catalog, SEED)
	_assert_draws_nothing(character, 2, "boss room")
	var regular: RoomLoot = _room(0, character)
	_watched(regular).kill()
	regular.end_step()
	assert_eq(regular.get_drops().size(), 1)


func test_c10_a_regular_kill_draws_one_float_and_an_index_only_on_a_drop() -> void:
	# A chance of 0.5: both a miss and a drop happen within 40 kills.
	var catalog: LootCatalog = _catalog_with(1.0, _pool, _boss_swords)
	var character: CharacterLoot = LootFixtures.character(catalog, SEED)
	var room: RoomLoot = _room(0, character)
	var reference: RandomNumberGenerator = _reference()
	var expected: Array[StringName] = []
	for _i: int in 40:
		_watched(room).kill()
		room.end_step()
		if reference.randf() < 0.5:
			expected.append(_pool[reference.randi_range(0, 4)].id)
		assert_eq(character.get_roller().get_state(), reference.state)
	assert_eq(_ids(room.get_drops()), expected)
	assert_gt(expected.size(), 0)
	assert_lt(expected.size(), 40)


func test_c10_the_boss_room_never_rolls_as_a_regular_kill() -> void:
	var room: RoomLoot = _boss_room()
	_watched(room).kill()
	room.end_step()
	var reference: RandomNumberGenerator = _reference()
	reference.randi_range(1, 60)  # the guaranteed roll: no float first
	assert_eq(_character.get_roller().get_state(), reference.state)


func test_c10_a_regular_room_never_rolls_the_boss_table() -> void:
	var room: RoomLoot = _room()
	_watched(room).kill()
	room.end_step()
	assert_false(_ids(room.get_drops())[0] in [&"boss_a", &"boss_b", &"boss_c"])


func test_c6_the_chance_per_kill_is_the_drops_per_run_over_the_floors_regular_kills() -> void:
	# Four combat rooms of one chaser each, one drop per run: a chance of 0.25.
	_tower = TowerFixtures.tower_of(1, 4)
	var catalog: LootCatalog = ItemFixtures.catalog_of(
		ItemFixtures.starter(),
		[ItemFixtures.floor_loot(1.0, _pool, _boss_swords, PackedInt32Array(BOSS_PERCENTS))]
	)
	var character: CharacterLoot = LootFixtures.character(catalog, SEED)
	var room: RoomLoot = character.make_room_loot(1, _tower.get_floor(1), 0, ItemFixtures.rules())
	var reference: RandomNumberGenerator = _reference()
	var expected: Array[StringName] = []
	for _i: int in KILLS:
		_watched(room).kill()
		if reference.randf() < 0.25:
			expected.append(_pool[reference.randi_range(0, 4)].id)
	room.end_step()
	assert_eq(_ids(room.get_drops()), expected)
	assert_between(expected.size(), 180, 320, "about a quarter of the kills")


# --- AC9: 1,000 kills of each kind against the reference's values ---


func test_ac9_a_thousand_regular_kills_drop_what_the_reference_says() -> void:
	var catalog: LootCatalog = _catalog_with(0.6, _pool, _boss_swords)  # 0.6 over 2 kills: 0.3
	var character: CharacterLoot = LootFixtures.character(catalog, SEED)
	var room: RoomLoot = _room(0, character)
	var reference: RandomNumberGenerator = _reference()
	var expected: Array[StringName] = []
	for _i: int in KILLS:
		_watched(room).kill()
		if reference.randf() < 0.3:
			expected.append(_pool[reference.randi_range(0, 4)].id)
	room.end_step()
	assert_eq(_ids(room.get_drops()), expected)
	assert_eq(character.get_roller().get_state(), reference.state)
	assert_between(expected.size(), 200, 400, "a spread of both outcomes")


func _thousand_boss_wins(character: CharacterLoot, upper: int) -> Array[StringName]:
	var room: RoomLoot = _boss_room(character)
	var reference: RandomNumberGenerator = _reference()
	var expected: Array[StringName] = []
	for _i: int in KILLS:
		_watched(room).kill()
		var pick: int = LootRoller.boss_pick(
			reference.randi_range(1, upper), PackedInt32Array(BOSS_PERCENTS)
		)
		if pick >= 0:
			expected.append(_boss_swords[pick].id)
	room.end_step()
	assert_eq(_ids(room.get_drops()), expected)
	assert_eq(character.get_roller().get_state(), reference.state)
	return expected


func test_ac9_a_thousand_guaranteed_boss_wins_drop_what_the_reference_says() -> void:
	var expected: Array[StringName] = _thousand_boss_wins(_character, 60)
	assert_eq(expected.size(), KILLS, "every guaranteed win drops")


func test_ac9_a_thousand_repeat_boss_wins_drop_what_the_reference_says() -> void:
	_character.report_taken(&"boss_a", FLOOR)
	var expected: Array[StringName] = _thousand_boss_wins(_character, 100)
	assert_between(expected.size(), 500, 700, "about sixty in a hundred")


# --- C11, AC11: the guarantee ---


func test_c11_a_guaranteed_win_always_drops_a_boss_sword_of_the_floor() -> void:
	var room: RoomLoot = _boss_room()
	_watched(room).kill()
	room.end_step()
	var drops: Array[LootDrop] = room.get_drops()
	assert_eq(drops.size(), 1)
	assert_eq(drops[0].boss_floor, FLOOR)
	assert_true(drops[0].sword_id in [&"boss_a", &"boss_b", &"boss_c"])


func test_ac11_the_flag_is_set_when_the_sword_is_taken_and_not_when_it_drops() -> void:
	var room: RoomLoot = _boss_room()
	_watched(room).kill()
	room.end_step()
	assert_eq(room.get_drops().size(), 1)
	assert_false(_character.is_boss_sword_taken(FLOOR), "it dropped, nobody took it")
	_player.place(ENEMY_AT)
	room.end_step()
	assert_true(_character.is_boss_sword_taken(FLOOR), "taken")


func test_ac11_a_drop_left_behind_by_a_death_keeps_the_next_win_guaranteed() -> void:
	var first: RoomLoot = _boss_room()
	_watched(first).kill()
	_player.kill()
	first.end_step()  # the boss dies in the step the player dies: the drop lies, nobody takes it
	first.take_all()
	assert_eq(first.get_drops().size(), 1)
	assert_false(_character.is_boss_sword_taken(FLOOR))
	# The next win, in a new room: still rolled over 1 to the sum.
	_player = LootFixtures.player(FAR)
	var second: RoomLoot = _boss_room()
	var before: Dictionary = _character.get_roller().to_dict()
	_watched(second).kill()
	second.end_step()
	assert_eq(second.get_drops().size(), 1, "guaranteed again")
	var reference: RandomNumberGenerator = RandomNumberGenerator.new()
	reference.seed = before[LootRoller.KEY_SEED]
	reference.state = before[LootRoller.KEY_STATE]
	reference.randi_range(1, 60)
	assert_eq(_character.get_roller().get_state(), reference.state, "over 1 to the sum")


func test_ac11_after_one_is_taken_the_next_win_rolls_the_percentages() -> void:
	var first: RoomLoot = _boss_room()
	_player.place(ENEMY_AT)
	_watched(first).kill()
	first.end_step()
	assert_true(_character.is_boss_sword_taken(FLOOR))
	_player = LootFixtures.player(FAR)
	var second: RoomLoot = _boss_room()
	var before: Dictionary = _character.get_roller().to_dict()
	_watched(second).kill()
	second.end_step()
	var reference: RandomNumberGenerator = RandomNumberGenerator.new()
	reference.seed = before[LootRoller.KEY_SEED]
	reference.state = before[LootRoller.KEY_STATE]
	reference.randi_range(1, 100)
	assert_eq(_character.get_roller().get_state(), reference.state, "over 1 to 100")


func test_ac11_other_floors_flags_are_untouched() -> void:
	var room: RoomLoot = _boss_room()
	_player.place(ENEMY_AT)
	_watched(room).kill()
	room.end_step()
	assert_true(_character.is_boss_sword_taken(FLOOR))
	for floor_number: int in [1, 3]:
		assert_false(_character.is_boss_sword_taken(floor_number), "floor %d" % floor_number)
	# And floor 1's boss is still guaranteed.
	var other: RoomLoot = LootFixtures.room_loot(_character, _tower, 1, 2)
	other.watch_player(_player)
	var before: Dictionary = _character.get_roller().to_dict()
	_watched(other).kill()
	other.end_step()
	var reference: RandomNumberGenerator = RandomNumberGenerator.new()
	reference.seed = before[LootRoller.KEY_SEED]
	reference.state = before[LootRoller.KEY_STATE]
	reference.randi_range(1, 60)
	assert_eq(_character.get_roller().get_state(), reference.state)


func test_ac11_taking_a_regular_sword_never_ends_a_guarantee() -> void:
	var room: RoomLoot = _room()
	_player.place(ENEMY_AT)
	_watched(room).kill()
	room.end_step()
	for floor_number: int in range(1, 4):
		assert_false(_character.is_boss_sword_taken(floor_number))


# --- G7: the room's own snapshot ---


## A boss room of floor 2 whose boss dropped a sword that still lies, and a regular drop beside it.
func _room_with_two_drops() -> RoomLoot:
	var room: RoomLoot = _boss_room()
	_watched(room, Vector2(4.25, 6.5)).kill()
	_watched(room, Vector2(9, 3)).kill()
	room.end_step()
	assert_eq(room.get_drops().size(), 2)
	return room


func test_ac12_the_lying_drops_round_trip_with_their_source() -> void:
	var source: RoomLoot = _room_with_two_drops()
	var copy: RoomLoot = _boss_room(LootFixtures.character(_catalog, 1))
	assert_true(copy.from_dict(source.to_dict()))
	var expected: Array[LootDrop] = source.get_drops()
	var got: Array[LootDrop] = copy.get_drops()
	assert_eq(got.size(), 2)
	for index: int in 2:
		assert_eq(got[index].sword_id, expected[index].sword_id)
		assert_eq(got[index].position, expected[index].position)
		assert_eq(got[index].boss_floor, expected[index].boss_floor)
	assert_eq_deep(copy.to_dict(), source.to_dict())


func test_ac12_a_regular_room_and_its_drops_round_trip_with_no_boss_floor() -> void:
	var source: RoomLoot = _room()
	_watched(source).kill()
	source.end_step()
	var copy: RoomLoot = _room()
	assert_true(copy.from_dict(source.to_dict()))
	assert_eq(copy.get_drops()[0].boss_floor, 0)
	assert_eq(copy.get_drops()[0].position, ENEMY_AT)


func test_ac12_a_boss_sword_taken_after_a_restore_sets_the_floors_flag() -> void:
	var source: RoomLoot = _room_with_two_drops()
	var snapshot: Dictionary = source.to_dict()
	var fresh_character: CharacterLoot = LootFixtures.character(_catalog, 1)
	assert_false(fresh_character.is_boss_sword_taken(FLOOR))
	_player = LootFixtures.player(Vector2(4.25, 6.5))  # on the first drop, which is the boss's
	var restored: RoomLoot = _boss_room(fresh_character)
	assert_true(restored.from_dict(snapshot))
	restored.end_step()
	assert_true(fresh_character.is_boss_sword_taken(FLOOR))
	assert_eq(restored.get_drops().size(), 1, "the other drop lies still")
	assert_eq(fresh_character.get_inventory().get_ids().size(), 2)


func test_ac12_a_restore_replaces_the_drops_that_lay_there() -> void:
	var source: RoomLoot = _room_with_two_drops()
	var target: RoomLoot = _boss_room()
	_watched(target).kill()
	target.end_step()
	assert_true(target.from_dict(source.to_dict()))
	assert_eq(target.get_drops().size(), 2)


func test_ac12_an_empty_room_round_trips() -> void:
	var room: RoomLoot = _room()
	var copy: RoomLoot = _room()
	_watched(copy).kill()
	copy.end_step()
	assert_true(copy.from_dict(room.to_dict()))
	assert_true(copy.get_drops().is_empty())


func _assert_refused(room: RoomLoot, snapshot: Dictionary, message: String) -> void:
	var before: Dictionary = room.to_dict()
	assert_false(room.from_dict(snapshot), message)
	assert_eq_deep(room.to_dict(), before)


func _drop_entry(sword: String, position: Variant, boss_floor: Variant) -> Dictionary:
	return {
		RoomLoot.KEY_SWORD: sword,
		RoomLoot.KEY_POSITION: position,
		RoomLoot.KEY_BOSS_FLOOR: boss_floor,
	}


func test_ac12_a_malformed_room_snapshot_is_refused_and_changes_nothing() -> void:
	var room: RoomLoot = _room_with_two_drops()
	var pool_id: String = String(_pool[0].id)
	_assert_refused(room, {}, "no key")
	_assert_refused(room, {RoomLoot.KEY_DROPS: "x"}, "drops not a list")
	_assert_refused(room, {RoomLoot.KEY_DROPS: [1]}, "an entry not a dictionary")
	_assert_refused(room, {RoomLoot.KEY_DROPS: [{RoomLoot.KEY_SWORD: pool_id}]}, "a half entry")
	_assert_refused(
		room, {RoomLoot.KEY_DROPS: [_drop_entry(pool_id, Vector2.ZERO, 0.0)]}, "a float floor"
	)
	_assert_refused(
		room,
		{RoomLoot.KEY_DROPS: [_drop_entry(pool_id, [1, 2], 0)]},
		"a position that is no vector"
	)
	_assert_refused(
		room, {RoomLoot.KEY_DROPS: [_drop_entry("not_a_sword", Vector2.ZERO, 0)]}, "unknown sword"
	)
	_assert_refused(room, {RoomLoot.KEY_DROPS: [_drop_entry("", Vector2.ZERO, 0)]}, "an empty id")
	var good: Dictionary = _drop_entry(pool_id, Vector2(1, 1), 0)
	_assert_refused(
		room,
		{RoomLoot.KEY_DROPS: [good, _drop_entry("x", Vector2.ZERO, 0)]},
		"one bad entry among good ones"
	)


func test_ac12_a_boss_floor_is_only_valid_in_the_boss_room_of_that_floor() -> void:
	var boss: RoomLoot = _boss_room()
	var regular: RoomLoot = _room()
	var pool_id: String = String(_pool[0].id)
	_assert_refused(
		regular,
		{RoomLoot.KEY_DROPS: [_drop_entry(pool_id, Vector2.ZERO, FLOOR)]},
		"a boss drop in a regular room"
	)
	_assert_refused(
		boss,
		{RoomLoot.KEY_DROPS: [_drop_entry("boss_a", Vector2.ZERO, FLOOR + 1)]},
		"another floor's boss"
	)
	_assert_refused(
		boss, {RoomLoot.KEY_DROPS: [_drop_entry("boss_a", Vector2.ZERO, -1)]}, "a negative floor"
	)
	assert_true(boss.from_dict({RoomLoot.KEY_DROPS: [_drop_entry("boss_a", Vector2.ZERO, FLOOR)]}))


func test_ac12_a_room_of_a_character_without_a_catalog_refuses_any_drop() -> void:
	var bare: CharacterLoot = LootFixtures.character(null, 0)
	var room: RoomLoot = _room(0, bare)
	var snapshot: Dictionary = {
		RoomLoot.KEY_DROPS: [_drop_entry(String(_pool[0].id), Vector2.ZERO, 0)]
	}
	_assert_refused(room, snapshot, "no catalog to know the sword")
	assert_true(room.from_dict({RoomLoot.KEY_DROPS: []}), "the empty list is fine")


## CR-8: a drop at a position that is not a number can never be reached and is refused.
func test_cr8_a_drop_at_a_nan_or_infinite_position_is_refused_and_changes_nothing() -> void:
	var room: RoomLoot = _room_with_two_drops()
	var pool_id: String = String(_pool[0].id)
	for bad: Vector2 in [
		Vector2(NAN, 1.0),
		Vector2(1.0, NAN),
		Vector2(INF, 1.0),
		Vector2(1.0, -INF),
		Vector2(NAN, INF),
	]:
		_assert_refused(
			room, {RoomLoot.KEY_DROPS: [_drop_entry(pool_id, bad, 0)]}, "position %s" % bad
		)
	var good: Dictionary = _drop_entry(pool_id, Vector2(1, 1), 0)
	_assert_refused(
		room,
		{RoomLoot.KEY_DROPS: [good, _drop_entry(pool_id, Vector2(NAN, NAN), 0)]},
		"one bad position among good entries"
	)
	assert_true(room.from_dict({RoomLoot.KEY_DROPS: [good]}), "a finite position is still fine")
