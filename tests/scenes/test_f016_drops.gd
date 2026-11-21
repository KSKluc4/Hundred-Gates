extends F016LootTest
## F-016 T5 (AC13, AC24): in the running game an enemy's drop appears where it fell at the end of
## the combat step of its death, the player takes it by standing within the pickup radius, the
## banner says `Found:` (joined behind a heal shown in the same physics frame), and a placeholder
## marker is drawn where every sword lies. On a fixture tower (F016LootTest: a wide room, enemies
## frozen where they stand, certain drops), never on the shipped one.

const TWO_IN_ONE_ROOM: Array[int] = [2]
const NEAR_A: Vector2 = Vector2(10.0, 4.0)
const NEAR_B: Vector2 = Vector2(10.4, 4.0)
const BETWEEN: Vector2 = Vector2(10.2, 4.0)
const APART_A: Vector2 = Vector2(8.0, 4.0)
const APART_B: Vector2 = Vector2(14.0, 4.0)
const HURT_HP: int = 60


func _enter(spawn_counts: Array[int] = [1], catalog: LootCatalog = null) -> void:
	await spawn_loot_game(loot_tower(spawn_counts), catalog)
	await enter_frozen_floor()


func _radius() -> float:
	return Tunables.items.pickup_radius_tiles


func _total_owned() -> int:
	var total: int = 0
	for sword_id: StringName in inventory().get_ids():
		total += inventory().get_count(sword_id)
	return total


## Two enemies fall at NEAR_A and NEAR_B, in that order, with the player at `player_at` (null: left
## where it is), then runs the tick that rolls and takes.
func _kill_the_pair(player_at: Variant, first: Vector2 = NEAR_A, second: Vector2 = NEAR_B) -> void:
	kill_enemy_at(room().get_enemies()[0], first)
	kill_enemy_at(room().get_enemies()[1], second)
	if player_at is Vector2:
		put_player_at(player_at)
	await run_ticks(1)


# --- AC13: the drop and the pickup ------------------------------------------------------------


func test_ac13_the_drop_appears_where_the_enemy_fell_at_the_end_of_the_step_of_its_death() -> void:
	await _enter()
	assert_true(drops().is_empty())
	kill(enemy())
	assert_true(drops().is_empty(), "nothing is rolled between two steps")
	await run_ticks(1)
	assert_eq(drops().size(), 1, "the step that follows the death rolled it")
	assert_eq(drops()[0].position, enemy().logic.get_position_tiles(), "where the enemy fell")
	assert_eq(drops()[0].boss_floor, 0, "not a boss's")
	assert_not_null(loot().get_catalog().get_sword(drops()[0].sword_id), "a sword of the catalog")


func test_ac13_a_player_001_tiles_inside_the_radius_takes_it_in_that_step() -> void:
	await _enter()
	var spot: Vector2 = enemy().logic.get_position_tiles()
	put_player_at(spot + Vector2(_radius() - PICKUP_EPSILON, 0.0))
	assert_eq(_total_owned(), 1, "the starter")
	kill(enemy())
	await run_ticks(1)
	assert_true(drops().is_empty(), "taken in the step it dropped")
	assert_eq(_total_owned(), 2, "the count rose")
	var found: StringName = inventory().get_ids()[1]
	assert_eq(owned(found), 1)
	assert_eq(banner(), "Found: %s" % name_of(found))


func test_ac13_a_player_001_tiles_outside_the_radius_does_not_and_a_step_closer_does() -> void:
	await _enter()
	var spot: Vector2 = enemy().logic.get_position_tiles()
	put_player_at(spot + Vector2(_radius() + PICKUP_EPSILON, 0.0))
	kill(enemy())
	await run_ticks(3)
	assert_eq(drops().size(), 1, "it lies there")
	assert_eq(_total_owned(), 1, "nothing was taken")
	assert_eq(banner(), "", "and nothing was said")
	var lying: StringName = drops()[0].sword_id
	put_player_at(spot + Vector2(_radius() - PICKUP_EPSILON, 0.0))
	await run_ticks(1)
	assert_true(drops().is_empty())
	assert_eq(owned(lying), 1)
	assert_eq(banner(), "Found: %s" % name_of(lying))


func test_ac13_taking_a_sword_already_owned_raises_its_count() -> void:
	await _enter(TWO_IN_ONE_ROOM, certain_catalog(loot_tower(TWO_IN_ONE_ROOM), 1))
	await _kill_the_pair(BETWEEN)
	assert_eq(inventory().get_ids().size(), 2, "the starter and the one sword of the pool")
	var only: StringName = inventory().get_ids()[1]
	assert_eq(owned(only), 2, "the second one is a count")
	assert_eq(banner(), "Found: %s, %s" % [name_of(only), name_of(only)])


func test_ac13_two_drops_in_reach_are_taken_in_the_order_they_dropped_and_named_in_one_banner(
) -> void:
	# The same seed twice: first the pair lies where the player is not, to read the drop order; then
	# the player stands between them.
	await _enter(TWO_IN_ONE_ROOM)
	await _kill_the_pair(null)
	var lying: Array[StringName] = drop_ids()
	assert_eq(lying.size(), 2)
	assert_ne(lying[0], lying[1], "the seed gives two different swords (the test reads the order)")
	game().queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await _enter(TWO_IN_ONE_ROOM)
	var reported: Array[Array] = []
	floor_scene().loot_taken.connect(func(ids: Array[StringName]) -> void: reported.append(ids))
	await _kill_the_pair(BETWEEN)
	assert_true(drops().is_empty(), "both were in reach")
	assert_eq(reported.size(), 1, "told once")
	assert_eq(reported[0], lying, "in the order they dropped")
	assert_eq(inventory().get_ids().slice(1), lying, "and owned in that order")
	var names: PackedStringArray = [name_of(lying[0]), name_of(lying[1])]
	assert_eq(banner(), ItemTexts.found_text(names))
	assert_eq(banner(), "Found: %s, %s" % [names[0], names[1]])


func test_ac13_a_heal_shown_in_the_same_tick_goes_in_front_of_the_found_notice() -> void:
	await _enter()
	var spot: Vector2 = enemy().logic.get_position_tiles()
	put_player_at(spot + Vector2(0.3, 0.0))
	set_hp(HURT_HP)
	kill(enemy())
	await run_ticks(1)
	var found: StringName = inventory().get_ids()[1]
	var healed: int = roundi(max_hp() * Tunables.floors.room_clear_heal_fraction)
	assert_eq(hp(), HURT_HP + healed, "the room's clear healed")
	assert_eq(banner(), "+%d HP · Found: %s" % [healed, name_of(found)])


# --- C20: the join, whichever part comes first ------------------------------------------------


func test_c20_the_other_part_is_first_whichever_arrived_first_and_a_later_frame_replaces() -> void:
	await _enter()
	var sword: Array[StringName] = [ItemFixtures.STARTER_ID]
	var text: String = name_of(ItemFixtures.STARTER_ID)
	floor_scene().healed.emit(5)
	floor_scene().loot_taken.emit(sword)
	assert_eq(banner(), "+5 HP · Found: %s" % text, "the heal first, the notice after it")
	await run_ticks(1)
	floor_scene().loot_taken.emit(sword)
	floor_scene().healed.emit(6)
	assert_eq(banner(), "+6 HP · Found: %s" % text, "the notice first, and it is still last")
	await run_ticks(1)
	floor_scene().healed.emit(7)
	assert_eq(banner(), "+7 HP", "a new banner in a later frame replaces the old one")
	await run_ticks(1)
	floor_scene().loot_taken.emit(sword)
	assert_eq(banner(), "Found: %s" % text, "and so does a notice")
	await run_ticks(1)
	floor_scene().loot_taken.emit(sword)
	floor_scene().loot_taken.emit(sword)
	assert_eq(banner(), "Found: %s, %s" % [text, text], "two notices of a frame are one")
	await run_ticks(1)
	var three: Array[StringName] = [sword[0], sword[0], sword[0]]
	floor_scene().loot_taken.emit(three)
	assert_eq(banner(), "Found: %s, %s +1 more" % [text, text], "two names and the rest counted")


func test_c20_a_clear_and_a_notice_of_the_same_frame_are_joined_too() -> void:
	await _enter()
	var sword: Array[StringName] = [ItemFixtures.STARTER_ID]
	session().floor_cleared.emit(1, 2)
	floor_scene().loot_taken.emit(sword)
	var cleared: String = Game.cleared_banner_text(1, 2, 1)
	assert_eq(banner(), "%s · Found: %s" % [cleared, name_of(ItemFixtures.STARTER_ID)])


# --- AC24: the markers ------------------------------------------------------------------------


func test_ac24_a_marker_is_drawn_where_each_sword_lies_and_gone_when_it_is_taken() -> void:
	await _enter(TWO_IN_ONE_ROOM)
	var markers: PickupMarkers = room().get_pickup_markers()
	assert_not_null(markers)
	assert_eq(markers.get_markers().size(), 0, "nothing lies yet")
	await _kill_the_pair(null, APART_A, APART_B)
	var lying: Array[LootDrop] = drops()
	var shown: Array[Dictionary] = markers.get_markers()
	assert_eq(shown.size(), 2)
	for index: int in 2:
		assert_eq(shown[index]["position_px"], Units.vector_tiles_to_px(lying[index].position))
		assert_eq(shown[index]["sword_id"], lying[index].sword_id)
		assert_eq(shown[index]["size_px"], markers.marker_size_px)
		assert_eq(shown[index]["color"], markers.marker_color)
	await wait_draw()
	assert_eq(markers.get_last_drawn().size(), 2, "and the draw pass drew both")
	put_player_at(lying[0].position + Vector2(0.1, 0.0))
	var second: LootDrop = lying[1]
	await run_ticks(1)
	assert_eq(markers.get_markers().size(), 1, "the taken one is gone in that very step")
	assert_eq(markers.get_markers()[0]["position_px"], Units.vector_tiles_to_px(second.position))
	await wait_draw()
	assert_eq(markers.get_last_drawn().size(), 1)
	put_player_at(second.position)
	await run_ticks(1)
	assert_eq(markers.get_markers().size(), 0)
	await wait_draw()
	assert_eq(markers.get_last_drawn().size(), 0)


func test_ac24_a_boss_sword_is_marked_in_its_own_colour() -> void:
	await spawn_loot_game(loot_tower([1]))
	session().get_progress().mark_boss_reached(1)
	await enter_frozen_floor(1, true)
	assert_true(room().get_room_data().is_boss_room)
	kill_boss()
	await run_ticks(1)
	assert_eq(drops().size(), 1, "the first win always drops")
	assert_eq(drops()[0].boss_floor, 1)
	var markers: PickupMarkers = room().get_pickup_markers()
	assert_eq(markers.get_markers().size(), 1)
	assert_true(markers.get_markers()[0]["boss"])
	assert_eq(markers.get_markers()[0]["color"], markers.boss_marker_color)


## What the engine draws by: the node's z_index plus those of its ancestors while each is relative.
func _effective_z(item: CanvasItem) -> int:
	var total: int = 0
	var node: Node = item
	while node is CanvasItem:
		total += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative:
			break
		node = node.get_parent()
	return total


## Every canvas item of `body` (its own and its children's: shape, bar, telegraph, numbers).
func _highest_z_in(body: Node) -> int:
	var highest: int = _effective_z(body as CanvasItem)
	for child: Node in body.find_children("*", "CanvasItem", true, false):
		highest = maxi(highest, _effective_z(child as CanvasItem))
	return highest


func _assert_drawn_above(markers: PickupMarkers, dead: Enemy) -> void:
	var z: int = _effective_z(markers)
	assert_gt(z, _highest_z_in(dead), "above the dead enemy the sword lies under, and its views")
	assert_gt(z, _highest_z_in(player()), "above the player")
	for other: Enemy in room().get_enemies():
		assert_gt(z, _highest_z_in(other), "above every enemy of the room")
	assert_eq(markers.z_index, markers.draw_order, "the export is what the node draws by")


func test_ac24_a_drop_in_a_regular_room_is_drawn_above_the_dead_enemy_it_lies_under() -> void:
	await _enter(TWO_IN_ONE_ROOM)
	var dead: Enemy = room().get_enemies()[0]
	kill(dead)
	await run_ticks(1)
	assert_eq(drops().size(), 1)
	assert_eq(drops()[0].position, dead.logic.get_position_tiles(), "it lies under the corpse")
	_assert_drawn_above(room().get_pickup_markers(), dead)


func test_ac24_a_boss_sword_is_drawn_above_the_dead_boss() -> void:
	await spawn_loot_game(loot_tower([1]))
	session().get_progress().mark_boss_reached(1)
	await enter_frozen_floor(1, true)
	var boss: Enemy = enemy()
	kill_boss()
	await run_ticks(1)
	assert_eq(drops().size(), 1)
	assert_eq(drops()[0].position, boss.logic.get_position_tiles(), "under the boss's body")
	_assert_drawn_above(room().get_pickup_markers(), boss)


func test_ac24_the_markers_are_above_a_reserve_enemys_views_too() -> void:
	var tower: TowerData = TowerFixtures.tower_of(1, 1)
	tower.floors[0].rooms[0] = WaveFixtures.wave_room(&"f1_room_1")
	await spawn_loot_game(tower)
	await enter_frozen_floor()
	var arrival: Enemy = room().get_reserve_enemies()[0]
	assert_true(room().get_reserve_enemies().has(arrival))
	assert_gt(_effective_z(room().get_pickup_markers()), _highest_z_in(arrival), "above a reserve")


func test_ac24_the_markers_read_nothing_but_the_drops_they_are_given() -> void:
	var tower: TowerData = loot_tower([1])
	var character: CharacterLoot = LootFixtures.character(certain_catalog(tower), LOOT_SEED)
	var room_loot: RoomLoot = LootFixtures.room_loot(character, tower, 1, 0)
	var markers: PickupMarkers = PickupMarkers.new()
	assert_eq(markers.get_markers().size(), 0, "no loot given")
	markers.setup(room_loot)
	assert_eq(markers.get_markers().size(), 0, "nothing lies")
	var lying: Dictionary = {
		RoomLoot.KEY_DROPS:
		[
			{
				RoomLoot.KEY_SWORD: String(ItemFixtures.STARTER_ID),
				RoomLoot.KEY_POSITION: Vector2(3.5, 4.5),
				RoomLoot.KEY_BOSS_FLOOR: 0,
			}
		]
	}
	assert_true(room_loot.from_dict(lying))
	var shown: Array[Dictionary] = markers.get_markers()
	assert_eq(shown.size(), 1)
	assert_eq(shown[0]["position_px"], Units.vector_tiles_to_px(Vector2(3.5, 4.5)))
	assert_eq(shown[0]["sword_id"], ItemFixtures.STARTER_ID)
	markers.free()
