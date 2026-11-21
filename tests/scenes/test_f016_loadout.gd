extends F016LootTest
## F-016 T5 (AC17 through the running game, AC18): the sword is part of the player of every room.
## Equipping in town changes the town player's max HP at once and, on the next floor, the hits, the
## dash cooldown and the heal; equipping in the cleared room before a boss changes the player on
## screen at once and the boss room is entered at the new max HP; a room entered at 105 and a
## Vitality taken off leaves at most 100 and a FloorRun that accepts its own snapshot back; the
## seed.
## On a fixture tower, with a catalog whose regular drops never come (quiet_catalog()), so the only
## swords are the ones the test gives.

const CLASS_MAX_HP: int = 100
const VITALITY_MAX_HP: int = 108
const ENEMY_HP: int = 50
## One tile in front of the player, inside the first hit's range of 1.4.
const IN_FRONT: Vector2 = Vector2(1.0, 0.0)
const DEATH_PAUSE_SECONDS: float = 5.0
const GIVEN_SEED: int = 4242
const HURT_HP: int = 50


func _start(spawn_counts: Array[int] = [1]) -> void:
	var tower: TowerData = loot_tower(spawn_counts)
	await spawn_loot_game(tower, quiet_catalog(tower))


## Everything dead and the drops (there are none) and the heal come.
func _clear_here() -> void:
	kill_all()
	await run_ticks(2)
	assert_true(room().is_cleared(), "the room is cleared")


func _is_town() -> bool:
	return session().get_place() == TowerSession.Place.TOWN


func _back_in_town() -> void:
	assert_true(game().leave_floor(), "left the floor")
	var shown: Callable = func() -> bool: return town() != null and floor_scene() == null
	assert_true(await run_until(shown, WALK_LIMIT_TICKS), "the town is shown")


# --- AC18: the town ---------------------------------------------------------------------------


func test_ac18_equipping_vitality_in_town_changes_the_town_players_max_hp_and_fills_it() -> void:
	await _start()
	assert_eq(max_hp(), CLASS_MAX_HP)
	give(VITALITY_ID)
	assert_true(game().can_equip_sword())
	assert_true(game().equip_sword(VITALITY_ID))
	assert_eq(max_hp(), VITALITY_MAX_HP, "at once, on the player on screen")
	assert_eq(hp(), VITALITY_MAX_HP, "the town is at full HP")
	assert_eq(game().get_equipped_sword().id, VITALITY_ID)
	assert_eq(game().get_loadout().get_max_hp(), VITALITY_MAX_HP)


func test_ac18_a_floor_entered_with_vitality_starts_at_108_of_108() -> void:
	await _start()
	give(VITALITY_ID)
	game().equip_sword(VITALITY_ID)
	await enter_floor_through_gate(1)
	assert_eq(max_hp(), VITALITY_MAX_HP)
	assert_eq(hp(), VITALITY_MAX_HP)
	assert_eq(floor_scene().get_run().get_entry_hp(), VITALITY_MAX_HP)
	assert_eq(hud().get_health_bar().get_label_text(), "HP 108 / 108")


func test_ac18_the_town_built_after_a_return_has_the_swords_max_hp() -> void:
	await _start()
	give(VITALITY_ID)
	game().equip_sword(VITALITY_ID)
	await enter_floor_through_gate(1)
	await _back_in_town()
	assert_eq(max_hp(), VITALITY_MAX_HP)
	assert_eq(hp(), VITALITY_MAX_HP, "a town player enters at the loadout's max HP")


func test_ac18_equipping_in_town_changes_the_hits_of_the_next_floor_in_a_real_swing() -> void:
	await _start()
	give(BIG_ID)
	assert_true(game().equip_sword(BIG_ID))
	var big: SwordData = game().get_equipped_sword()
	var hits: PackedInt32Array = hits_of(big)
	assert_ne(hits[0], ItemFixtures.class_data().attack_chain[0].damage, "a sword with other hits")
	await enter_frozen_floor()
	for index: int in hits.size():
		assert_eq(player().motor.get_loadout().get_hit_damage(index), hits[index])
	var target: Enemy = enemy()
	target.logic.sync_position(Units.vector_tiles_to_px(player_tiles() + IN_FRONT))
	target.sync_body_from_logic()
	player().motor.submit(AttackCommand.new())
	var hurt: Callable = func() -> bool: return target.logic.get_combat_state().get_hp() < ENEMY_HP
	assert_true(await run_until(hurt, 60, Vector2.ZERO, Vector2.RIGHT), "the swing landed")
	var taken: int = ENEMY_HP - target.logic.get_combat_state().get_hp()
	assert_eq(taken, hits[0], "the first hit of the sword, not of the class")


func test_ac18_equipping_quickstep_in_town_gives_the_next_floor_a_shorter_dash_cooldown() -> void:
	await _start()
	var class_cooldown: float = ItemFixtures.class_data().dash_cooldown
	give(QUICKSTEP_ID)
	game().equip_sword(QUICKSTEP_ID)
	await enter_frozen_floor()
	var cooldown: float = player().motor.get_loadout().get_dash_cooldown()
	assert_almost_eq(cooldown, class_cooldown - 0.1, 0.0001)
	player().motor.submit(DashCommand.new())
	var started: Callable = func() -> bool:
		return player().motor.get_state() == PlayerMotor.State.DASHING
	assert_true(await run_until(started, 10, Vector2.RIGHT, Vector2.RIGHT), "the dash started")
	var over: Callable = func() -> bool:
		return player().motor.get_state() != PlayerMotor.State.DASHING
	assert_true(await run_until(over, 60, Vector2.RIGHT, Vector2.RIGHT), "the dash ended")
	var left: float = float(player().motor.to_dict()["cooldown_remaining"])
	assert_lte(left, class_cooldown - 0.1, "the cooldown that starts is the sword's")
	assert_gt(left, 0.0, "and it is running")


func test_ac18_equipping_mending_in_town_changes_the_next_floors_room_clear_heal() -> void:
	await _start()
	give(MENDING_ID)
	game().equip_sword(MENDING_ID)
	await enter_frozen_floor()
	set_hp(HURT_HP)
	kill_all()
	await run_ticks(2)
	var healed: int = roundi(CLASS_MAX_HP * (Tunables.floors.room_clear_heal_fraction + 0.1))
	assert_eq(healed, 40, "30 % and the sword's 10")
	assert_eq(hp(), HURT_HP + healed)
	assert_eq(banner(), "+%d HP" % healed)


## CR-2: the town is always at full HP (items.md, "Owning and switching"), whatever is equipped.
func test_cr2_vitality_in_town_reads_108_of_108_and_taking_it_off_reads_100_of_100() -> void:
	await _start()
	give(VITALITY_ID)
	assert_true(game().equip_sword(VITALITY_ID))
	assert_eq(hp(), VITALITY_MAX_HP)
	assert_eq(hud().get_health_bar().get_label_text(), "HP 108 / 108", "and the bar says so")
	assert_true(game().equip_sword(ItemFixtures.STARTER_ID))
	assert_eq(max_hp(), CLASS_MAX_HP)
	assert_eq(hp(), CLASS_MAX_HP)
	assert_true(game().equip_sword(VITALITY_ID))
	assert_eq(hp(), VITALITY_MAX_HP, "and on again")


func test_cr2_on_a_floor_equipping_still_heals_nothing() -> void:
	await _start()
	await enter_frozen_floor()
	await _clear_here()
	set_hp(HURT_HP)
	give(VITALITY_ID)
	assert_true(game().equip_sword(VITALITY_ID))
	assert_eq(max_hp(), VITALITY_MAX_HP)
	assert_eq(hp(), HURT_HP, "no heal on a floor")


# --- AC18: the cleared room before a boss -----------------------------------------------------


func test_ac18_equipping_in_the_cleared_pre_boss_room_changes_the_player_at_once() -> void:
	await _start()
	await enter_frozen_floor()
	give(VITALITY_ID)
	assert_false(game().can_equip_sword(), "not before the room is cleared")
	assert_false(game().equip_sword(VITALITY_ID))
	await _clear_here()
	assert_true(game().can_equip_sword())
	assert_true(game().equip_sword(VITALITY_ID))
	assert_eq(max_hp(), VITALITY_MAX_HP, "at once, with no tick between")
	assert_eq(hp(), CLASS_MAX_HP, "and no heal")
	assert_eq(floor_scene().get_run().get_entry_hp(), CLASS_MAX_HP)


func test_ac18_the_boss_room_is_entered_at_the_new_max_hp() -> void:
	await _start()
	await enter_frozen_floor()
	await _clear_here()
	give(VITALITY_ID)
	assert_true(game().equip_sword(VITALITY_ID))
	await walk_out_and_freeze()
	assert_true(room().get_room_data().is_boss_room)
	assert_eq(max_hp(), VITALITY_MAX_HP)
	assert_eq(hp(), VITALITY_MAX_HP, "the boss room's full heal uses the new max HP")
	assert_eq(floor_scene().get_run().get_entry_hp(), VITALITY_MAX_HP)
	assert_eq(banner(), "+8 HP", "and the refill says so")


func test_ac18_taking_vitality_off_in_a_room_entered_at_105_leaves_at_most_100_and_a_good_run(
) -> void:
	await _start([1, 1])
	give(VITALITY_ID)
	game().equip_sword(VITALITY_ID)
	await enter_frozen_floor()
	await _clear_here()
	set_hp(105)
	await walk_out_and_freeze()
	var run: FloorRun = floor_scene().get_run()
	assert_eq(run.get_entry_hp(), 105, "entered at 105 of 108")
	await _clear_here()
	assert_true(game().can_equip_sword(), "the cleared room before the boss")
	assert_true(game().equip_sword(ItemFixtures.STARTER_ID))
	assert_lte(max_hp(), CLASS_MAX_HP)
	assert_lte(hp(), CLASS_MAX_HP, "clamped down at once")
	assert_lte(run.get_entry_hp(), CLASS_MAX_HP, "the run's entry HP follows")
	var snapshot: Dictionary = run.to_dict()
	assert_true(run.from_dict(snapshot), "and the run accepts its own snapshot back")
	assert_eq(run.to_dict(), snapshot)


# --- AC17: where equipping is allowed, through the game ----------------------------------------


func test_ac17_in_town_yes_and_never_for_a_sword_that_is_not_owned() -> void:
	await _start()
	assert_true(game().can_equip_sword())
	assert_false(game().equip_sword(VITALITY_ID), "not owned")
	assert_eq(game().get_equipped_sword().id, ItemFixtures.STARTER_ID)
	give(VITALITY_ID)
	assert_true(game().equip_sword(VITALITY_ID))
	assert_true(game().equip_sword(VITALITY_ID), "the equipped one again is a yes")
	assert_true(game().equip_sword(ItemFixtures.STARTER_ID), "and back")


func test_ac17_on_a_floor_only_in_the_cleared_room_before_the_boss() -> void:
	await _start([1, 1])
	give(VITALITY_ID)
	await enter_frozen_floor()
	assert_false(game().can_equip_sword(), "the first room, not cleared")
	assert_false(game().equip_sword(VITALITY_ID))
	await _clear_here()
	assert_false(game().can_equip_sword(), "the first room, cleared: not the one before the boss")
	assert_false(game().equip_sword(VITALITY_ID))
	await walk_out_and_freeze()
	assert_false(game().can_equip_sword(), "the room before the boss, not cleared")
	assert_false(game().equip_sword(VITALITY_ID))
	await _clear_here()
	assert_true(game().can_equip_sword(), "the room before the boss, cleared")
	assert_false(game().equip_sword(BIG_ID), "but only a sword that is owned")
	assert_eq(game().get_equipped_sword().id, ItemFixtures.STARTER_ID, "nothing changed")
	await walk_out_and_freeze()
	assert_true(room().get_room_data().is_boss_room)
	assert_false(game().can_equip_sword(), "the boss room, not cleared")
	assert_false(game().equip_sword(VITALITY_ID))
	kill_boss()
	await run_ticks(2)
	assert_true(room().is_cleared())
	assert_false(game().can_equip_sword(), "the boss room, cleared")
	assert_false(game().equip_sword(VITALITY_ID))
	assert_eq(game().get_equipped_sword().id, ItemFixtures.STARTER_ID, "nothing changed")


func test_ac17_not_in_the_death_pause() -> void:
	set_death_delay(DEATH_PAUSE_SECONDS)
	await _start()
	give(VITALITY_ID)
	await enter_frozen_floor()
	await _clear_here()
	assert_true(game().can_equip_sword(), "cleared and before the boss")
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	assert_false(game().can_equip_sword())
	assert_false(game().equip_sword(VITALITY_ID))


func test_ac17_a_floor_entered_at_the_boss_has_no_place_to_equip() -> void:
	await _start()
	give(VITALITY_ID)
	session().get_progress().mark_boss_reached(1)
	await enter_frozen_floor(1, true)
	assert_true(room().get_room_data().is_boss_room)
	assert_false(game().can_equip_sword())
	kill_boss()
	await run_ticks(2)
	assert_true(room().is_cleared())
	assert_false(game().can_equip_sword(), "not even once the boss is down")
	assert_false(game().equip_sword(VITALITY_ID))


# --- AC18: the seed ---------------------------------------------------------------------------


func test_ac18_a_seed_of_zero_gives_the_session_a_non_zero_one() -> void:
	var tower: TowerData = loot_tower([1])
	var drawn: Callable = func(game_node: Game) -> void:
		game_node.loot_catalog = quiet_catalog(tower)
	await spawn_game(tower, drawn)
	assert_eq(loot().get_roller().get_seed() != 0, true, "a seed was drawn in the world")
	assert_eq(game().loot_seed, loot().get_roller().get_seed(), "and the game says which")


func test_ac18_a_given_seed_is_used_as_it_is() -> void:
	var tower: TowerData = loot_tower([1])
	await spawn_loot_game(tower, quiet_catalog(tower), GIVEN_SEED)
	assert_eq(loot().get_roller().get_seed(), GIVEN_SEED)
	assert_eq(game().loot_seed, GIVEN_SEED)
