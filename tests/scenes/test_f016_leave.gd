extends F016LootTest
## F-016 T5 (the world's part of AC14, AC15, AC16 without the quit to title): what a dead player
## takes (nothing), what leaving a room takes (everything that lies there: the exit, the boss
## room's door, debug N, Return to town) and shows (`Found:`, behind the heal of the same moment),
## what debug R discards, and what a character keeps (inventory and sword, through a death, a
## Return to town and a cleared floor). On a fixture tower, never on the shipped one.

const DEATH_DELAY: float = 0.5
const NEXT_ROOM_KEY: Key = KEY_N
const HURT_HP: int = 60
## The boss room's refill from HURT_HP.
const REFILL: int = 40
const THREE_IN_A_ROOM: Array[int] = [3]
const TWO_IN_A_ROOM: Array[int] = [2]
const TWO_ROOMS: Array[int] = [1, 1]
const ONE_ROOM: Array[int] = [1]
const AFAR_A: Vector2 = Vector2(8.0, 3.0)
const AFAR_B: Vector2 = Vector2(8.0, 6.0)


func _enter(spawn_counts: Array[int], pool_size: int = 2) -> void:
	var tower: TowerData = loot_tower(spawn_counts)
	await spawn_loot_game(tower, certain_catalog(tower, pool_size))
	await enter_frozen_floor()


func _owned_total() -> int:
	var total: int = 0
	for sword_id: StringName in inventory().get_ids():
		total += inventory().get_count(sword_id)
	return total


func _names_of(ids: Array[StringName]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for sword_id: StringName in ids:
		names.append(name_of(sword_id))
	return names


func _wait_for_the_town() -> void:
	var shown: Callable = func() -> bool: return town() != null and floor_scene() == null
	assert_true(await run_until(shown, WALK_LIMIT_TICKS), "the town is shown")


# --- AC14: the dead take nothing --------------------------------------------------------------


func test_ac14_a_dead_player_standing_on_a_drop_does_not_take_it() -> void:
	set_death_delay(DEATH_DELAY)
	await _enter(ONE_ROOM)
	kill(enemy())
	await run_ticks(1)
	assert_eq(drops().size(), 1)
	var lying: LootDrop = drops()[0]
	kill_player()
	put_player_at(lying.position)
	await run_ticks(5)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_eq(drops().size(), 1, "it still lies there")
	assert_eq(_owned_total(), 1, "and nothing was taken")
	assert_eq(banner(), "")


func test_ac14_take_all_and_debug_n_after_the_death_take_nothing_either() -> void:
	set_death_delay(DEATH_DELAY)
	await _enter(TWO_ROOMS)
	kill(enemy())
	await run_ticks(1)
	assert_eq(drops().size(), 1)
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	room().get_loot().take_all()
	assert_true(room().get_loot().pop_taken().is_empty(), "take_all() of a dead player")
	floor_scene().skip_room()  # What N does after a death: the floor moves on, the session ignores it.
	assert_eq(_owned_total(), 1, "nothing was taken")
	assert_eq(banner(), "", "and nothing was said")


func test_ac14_what_lies_in_the_room_is_not_owned_after_the_death_is_confirmed() -> void:
	set_death_delay(DEATH_DELAY)
	await _enter(ONE_ROOM)
	kill(enemy())
	await run_ticks(1)
	assert_eq(drops().size(), 1)
	kill_player()
	await run_ticks(2)
	assert_true(await confirm_death_when_ready(), "the death was confirmed")
	await _wait_for_the_town()
	assert_eq(inventory().get_ids(), [ItemFixtures.STARTER_ID] as Array[StringName])
	assert_eq(_owned_total(), 1)


func test_ac14_an_enemy_that_falls_in_the_players_death_tick_is_still_rolled_but_not_taken(
) -> void:
	set_death_delay(DEATH_DELAY)
	await _enter(ONE_ROOM)
	kill(enemy())
	kill_player()  # Between the same two ticks.
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_eq(drops().size(), 1, "the enemy was rolled, whether or not the player is alive")
	assert_eq(_owned_total(), 1, "and the dead player took nothing")


# --- AC15: leaving a room takes what lies in it ------------------------------------------------


func test_ac15_the_exit_takes_what_lies_in_the_room_and_shows_it() -> void:
	await _enter(TWO_ROOMS)
	kill(enemy())
	await run_ticks(2)
	assert_true(room().is_cleared())
	assert_eq(drops().size(), 1)
	var lying: StringName = drops()[0].sword_id
	assert_eq(banner(), "", "nothing yet: the sword lies far from the player")
	await walk_out_and_freeze()
	assert_eq(floor_scene().get_run().get_room_index(), 1)
	assert_eq(owned(lying), 1, "taken on the way out")
	assert_eq(banner(), "Found: %s" % name_of(lying))


func test_ac15_below_full_hp_the_exit_into_the_boss_room_joins_the_notice_behind_the_refill(
) -> void:
	await _enter(ONE_ROOM)
	kill(enemy())
	await run_ticks(2)
	var lying: StringName = drops()[0].sword_id
	set_hp(HURT_HP)
	await walk_out_and_freeze()
	assert_true(room().get_room_data().is_boss_room)
	assert_eq(hp(), max_hp())
	assert_eq(banner(), "+%d HP · Found: %s" % [REFILL, name_of(lying)])


func test_ac15_three_swords_are_read_as_the_first_two_and_one_more() -> void:
	await _enter(THREE_IN_A_ROOM, 3)
	kill_all()
	await run_ticks(2)
	var lying: Array[StringName] = drop_ids()
	assert_eq(lying.size(), 3)
	await walk_out_and_freeze()
	assert_eq(_owned_total(), 4, "all three were taken")
	var names: PackedStringArray = _names_of(lying)
	assert_eq(banner(), "Found: %s, %s +1 more" % [names[0], names[1]])
	assert_eq(banner(), ItemTexts.found_text(names))


func test_ac15_the_door_of_the_boss_room_takes_the_bosss_sword_and_shows_it() -> void:
	await spawn_loot_game(loot_tower(ONE_ROOM))
	session().get_progress().mark_boss_reached(1)
	await enter_frozen_floor(1, true)
	kill_boss()
	await run_ticks(2)
	assert_eq(drops().size(), 1, "the first win always drops")
	assert_eq(drops()[0].boss_floor, 1)
	var lying: StringName = drops()[0].sword_id
	assert_false(loot().is_boss_sword_taken(1), "it lies, it is not taken")
	await leave_by_exit()
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_eq(owned(lying), 1)
	assert_true(loot().is_boss_sword_taken(1), "and taking it ended the guarantee")
	assert_eq(banner(), "Found: %s" % name_of(lying), "shown in the town the door led to")


func test_ac15_debug_n_takes_what_lies_in_the_room_and_shows_it() -> void:
	await _enter(TWO_ROOMS)
	kill(enemy())
	await run_ticks(1)
	var lying: StringName = drops()[0].sword_id
	press_key(NEXT_ROOM_KEY)
	assert_eq(floor_scene().get_run().get_room_index(), 1, "N moved on")
	assert_eq(owned(lying), 1)
	assert_eq(banner(), "Found: %s" % name_of(lying), "at once, in the callback that reports it")
	assert_true(room().get_loot().get_drops().is_empty(), "the new room has none")


func test_ac15_return_to_town_takes_what_lies_in_the_room_even_in_the_middle_of_a_fight() -> void:
	await _enter(TWO_IN_A_ROOM)
	kill(enemy(0))
	await run_ticks(1)
	assert_true(enemy(1).logic.is_alive(), "the fight is not over")
	var lying: StringName = drops()[0].sword_id
	assert_true(game().leave_floor())
	assert_eq(owned(lying), 1, "taken from across the room")
	assert_eq(banner(), "Found: %s" % name_of(lying), "shown at once")
	await _wait_for_the_town()
	assert_eq(banner(), "Found: %s" % name_of(lying), "and still shown in the town")


func test_ac15_debug_r_discards_what_lies_and_takes_nothing() -> void:
	await _enter(TWO_ROOMS)
	kill(enemy())
	await run_ticks(1)
	assert_eq(drops().size(), 1)
	floor_scene().restart_room()
	assert_true(drops().is_empty(), "the room was built again")
	assert_eq(room().get_pickup_markers().get_markers().size(), 0, "with no marker")
	assert_eq(_owned_total(), 1, "nothing was taken")
	await run_ticks(2)
	assert_eq(banner(), "", "and nothing was said")


# --- AC16: what a character keeps -------------------------------------------------------------


func test_ac16_a_new_game_owns_the_starter_sword_once_and_has_it_equipped() -> void:
	var tower: TowerData = loot_tower(ONE_ROOM)
	await spawn_loot_game(tower, certain_catalog(tower))
	assert_eq(inventory().get_ids(), [ItemFixtures.STARTER_ID] as Array[StringName])
	assert_eq(owned(ItemFixtures.STARTER_ID), 1)
	assert_eq(inventory().get_equipped_id(), ItemFixtures.STARTER_ID)
	assert_eq(game().get_equipped_sword().id, ItemFixtures.STARTER_ID)


func test_ac16_a_death_and_the_return_keep_the_inventory_and_the_equipped_sword() -> void:
	set_death_delay(DEATH_DELAY)
	var tower: TowerData = loot_tower(ONE_ROOM)
	await spawn_loot_game(tower, quiet_catalog(tower))
	give(VITALITY_ID)
	game().equip_sword(VITALITY_ID)
	var before: Dictionary = inventory().to_dict()
	await enter_frozen_floor()
	kill_player()
	await run_ticks(2)
	assert_true(await confirm_death_when_ready())
	await _wait_for_the_town()
	assert_eq(inventory().to_dict(), before, "nothing lost, nothing changed")
	assert_eq(game().get_equipped_sword().id, VITALITY_ID)
	assert_eq(max_hp(), 108, "and the new town's player fights with it")


func test_ac16_return_to_town_keeps_the_inventory_and_the_equipped_sword() -> void:
	var tower: TowerData = loot_tower(ONE_ROOM)
	await spawn_loot_game(tower, quiet_catalog(tower))
	give(VITALITY_ID)
	game().equip_sword(VITALITY_ID)
	var before: Dictionary = inventory().to_dict()
	await enter_frozen_floor()
	assert_true(game().leave_floor())
	await _wait_for_the_town()
	assert_eq(inventory().to_dict(), before)
	assert_eq(game().get_equipped_sword().id, VITALITY_ID)
	assert_eq(max_hp(), 108)


func test_ac16_clearing_a_floor_keeps_what_was_owned_and_adds_what_was_taken() -> void:
	var tower: TowerData = loot_tower(ONE_ROOM)
	await spawn_loot_game(tower, certain_catalog(tower))
	var kept: StringName = give(&"fixture_sword_01")
	assert_true(game().equip_sword(kept))
	await enter_frozen_floor()
	kill(enemy())
	await run_ticks(2)
	await walk_out_and_freeze()
	assert_true(room().get_room_data().is_boss_room)
	await clear_boss_and_leave()
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_true(session().get_progress().is_floor_cleared(1))
	assert_eq(inventory().get_equipped_id(), kept, "still the one equipped before")
	assert_eq(owned(ItemFixtures.STARTER_ID), 1)
	assert_gte(owned(kept), 1)
	assert_true(loot().is_boss_sword_taken(1), "the boss's sword came with the clear")
	assert_eq(_owned_total(), 4, "the starter, the one given, the regular drop and the boss's")


# --- CR-1: the floor does not step once more after Return to town ------------------------------


func test_cr1_a_kill_after_the_yes_of_return_to_town_is_not_rolled() -> void:
	await _enter(TWO_IN_A_ROOM)
	kill(enemy(0))
	await run_ticks(1)
	assert_eq(drops().size(), 1, "one sword lies when the person leaves")
	var lying: StringName = drops()[0].sword_id
	var roller_before: Dictionary = loot().get_roller().to_dict()
	var old_floor: FloorScene = floor_scene()
	assert_true(game().leave_floor(), "the yes")
	assert_eq(owned(lying), 1, "what lay there was taken at the yes")
	assert_eq(banner(), "Found: %s" % name_of(lying), "and shown")
	assert_eq(old_floor.process_mode, Node.PROCESS_MODE_DISABLED, "the floor stands still")
	# The other enemy dies after the yes and before the next tick: the floor must not step.
	kill(enemy(1))
	await _wait_for_the_town()
	assert_false(is_instance_valid(old_floor) and old_floor.is_inside_tree(), "the floor is gone")
	assert_eq(loot().get_roller().to_dict(), roller_before, "nothing was rolled")
	assert_eq(_owned_total(), 2, "the starter and the one taken at the yes")
	assert_eq(owned(lying), 1)
	assert_eq(banner(), "Found: %s" % name_of(lying), "the notice is the same")


func test_cr1_a_sword_in_reach_of_a_kill_after_the_yes_is_not_taken_without_a_banner() -> void:
	await _enter(TWO_IN_A_ROOM)
	var roller_before: Dictionary = loot().get_roller().to_dict()
	var near: Vector2 = enemy(1).logic.get_position_tiles()
	put_player_at(near + Vector2(0.3, 0.0))
	assert_true(game().leave_floor())
	assert_eq(_owned_total(), 1, "nothing lay there")
	kill(enemy(1))
	await _wait_for_the_town()
	assert_eq(loot().get_roller().to_dict(), roller_before)
	assert_eq(_owned_total(), 1)
	assert_eq(banner(), "")


func test_cr1_a_refused_leave_changes_nothing() -> void:
	set_death_delay(DEATH_DELAY)
	await _enter(TWO_IN_A_ROOM)
	var old_floor: FloorScene = floor_scene()
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_false(game().leave_floor(), "refused in the death pause")
	assert_ne(old_floor.process_mode, Node.PROCESS_MODE_DISABLED, "the floor is as it was")
	assert_eq(floor_scene(), old_floor)
	assert_eq(_owned_total(), 1)
