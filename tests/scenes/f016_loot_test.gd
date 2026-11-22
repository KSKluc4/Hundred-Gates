# gdlint:disable=max-public-methods
class_name F016LootTest
extends F012GameTest
## Shared by F-016's world tests (T5): a game on a fixture tower with a fixture catalog and a fixed
## seed, and the helpers every loot test uses (kill an enemy at a place, read the drops, walk the
## player onto one, read the inventory). The fixture room is wide and empty, so the enemies stand
## far from the player and from each other; their AI is turned off (freeze_enemies()) so that a drop
## lies exactly where its enemy fell and nothing hits anyone. F012GameTest took the shipped catalog
## off Tunables before each test; spawn_loot_game() gives the game a catalog of its own through the
## `loot_catalog` export. Nothing here depends on luck: use certain_catalog() where a drop must come
## and quiet_catalog() where none may.

## A fixed seed for the roller: the tests read what dropped, they never wait for it. Its first two
## regular rolls over a pool of two pick the first sword and then the second.
const LOOT_SEED: int = 12350
const BOSS_PERCENTS: Array[int] = [30, 20, 10]
const PICKUP_EPSILON: float = 0.01
## 24 x 9: P at (1, 4), the exit E at (23, 4) and (23, 5), room for three spawns far apart.
const LOOT_ROWS: Array[String] = [
	"########################",
	"#......................#",
	"#......................#",
	"#......................#",
	"#P.....................E",
	"#......................E",
	"#......................#",
	"#......................#",
	"########################",
]
## Where the spawns of a loot room stand, in the order they are filled.
const SPAWN_TILES: Array[Vector2i] = [Vector2i(12, 2), Vector2i(12, 6), Vector2i(18, 4)]
const VITALITY_ID: StringName = &"fixture_vitality"
const QUICKSTEP_ID: StringName = &"fixture_quickstep"
const MENDING_ID: StringName = &"fixture_mending"
const BIG_ID: StringName = &"fixture_big"
const BOSS_IDS: Array[StringName] = [&"fixture_boss_a", &"fixture_boss_b", &"fixture_boss_c"]


## A combat room of the loot floor with `spawn_count` chasers (1 to 3) at SPAWN_TILES.
static func loot_room(room_id: StringName, spawn_count: int) -> RoomData:
	var rows: PackedStringArray = PackedStringArray(LOOT_ROWS)
	for index: int in spawn_count:
		rows = RoomFixtures.with_tile(rows, SPAWN_TILES[index].x, SPAWN_TILES[index].y, "1")
	return RoomFixtures.room(room_id, rows)


## Floor `floor_number`: one combat room for each entry of `spawn_counts`, then a boss room.
static func loot_floor(floor_number: int, spawn_counts: Array[int]) -> FloorData:
	var data: FloorData = FloorData.new()
	data.floor_number = floor_number
	var list: Array[RoomData] = []
	for index: int in spawn_counts.size():
		var room_id: StringName = StringName("f%d_room_%d" % [floor_number, index + 1])
		list.append(loot_room(room_id, spawn_counts[index]))
	list.append(RoomFixtures.valid_boss_room(StringName("f%d_boss" % floor_number)))
	data.rooms = list
	return data


## The town and `floor_count` loot floors with the same combat rooms.
static func loot_tower(spawn_counts: Array[int], floor_count: int = 1) -> TowerData:
	var data: TowerData = TowerData.new()
	data.town = TowerFixtures.town_room()
	var floors: Array[FloorData] = []
	for number: int in range(1, floor_count + 1):
		floors.append(loot_floor(number, spawn_counts))
	data.floors = floors
	return data


## Three boss swords, one table for every floor (their ids are BOSS_IDS).
static func boss_swords() -> Array[SwordData]:
	var swords: Array[SwordData] = []
	for sword_id: StringName in BOSS_IDS:
		swords.append(ItemFixtures.make_sword(sword_id, 45))
	return swords


## Swords the tests own and equip. They sit in the regular pool of the catalogs below: known to the
## catalog, so they can be owned and equipped, and (with quiet_catalog()) never dropped. BIG has
## hits that differ from the Warrior's own.
static func gear() -> Array[SwordData]:
	var swords: Array[SwordData] = []
	swords.append(ItemFixtures.make_sword(BIG_ID, 48))
	swords.append(ItemFixtures.make_sword(VITALITY_ID, 42, SwordData.Kind.VITALITY, [], 8))
	swords.append(ItemFixtures.make_sword(QUICKSTEP_ID, 42, SwordData.Kind.QUICKSTEP, [], 0, 0.1))
	swords.append(ItemFixtures.make_sword(MENDING_ID, 42, SwordData.Kind.MENDING, [], 0, 0.0, 0.1))
	return swords


## A catalog for `tower` whose every regular drop is certain and whose pool is `pool_size` fixture
## swords; each floor's boss table is boss_swords() at BOSS_PERCENTS.
static func certain_catalog(tower: TowerData, pool_size: int = 2) -> LootCatalog:
	return ItemFixtures.catalog_with(
		tower,
		true,
		boss_swords(),
		PackedInt32Array(BOSS_PERCENTS),
		ItemFixtures.valid_swords(pool_size)
	)


## A catalog for `tower` whose regular drops never come, with gear() in its pool.
static func quiet_catalog(tower: TowerData) -> LootCatalog:
	var pool: Array[SwordData] = ItemFixtures.valid_swords(2)
	pool.append_array(gear())
	return ItemFixtures.catalog_with(
		tower, false, boss_swords(), PackedInt32Array(BOSS_PERCENTS), pool
	)


## The game on `tower` with `catalog` (certain_catalog() when null) and `loot_seed`.
func spawn_loot_game(
	tower: TowerData, catalog: LootCatalog = null, seed_value: int = LOOT_SEED
) -> void:
	var used: LootCatalog = catalog if catalog != null else certain_catalog(tower)
	var prepare: Callable = func(game_node: Game) -> void:
		game_node.loot_catalog = used
		game_node.loot_seed = seed_value
	await spawn_game(tower, prepare)


func loot() -> CharacterLoot:
	return session().get_loot()


func inventory() -> Inventory:
	return loot().get_inventory()


func banner() -> String:
	return hud().get_banner_text()


## The display name of a sword of the game's catalog.
func name_of(sword_id: StringName) -> String:
	return loot().get_catalog().get_sword(sword_id).display_name


## The room's lying drops, in the order they dropped.
func drops() -> Array[LootDrop]:
	return room().get_loot().get_drops()


func drop_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for drop: LootDrop in drops():
		ids.append(drop.sword_id)
	return ids


## Turns the AI of every enemy of the room off: nobody moves, nobody hits. Call it again for each
## room a test enters.
func freeze_enemies() -> void:
	for target: Enemy in room().get_enemies():
		target.logic.set_ai_enabled(false)


## The town's gate, floor `floor_number`, and the enemies of its first room frozen.
func enter_frozen_floor(floor_number: int = 1, at_boss: bool = false) -> void:
	await enter_floor_through_gate(floor_number, at_boss)
	freeze_enemies()


## Puts `target` at `tiles` (logic first, then the body) and kills it, between two ticks. The drop
## comes at the end of the next combat step.
func kill_enemy_at(target: Enemy, tiles: Vector2) -> void:
	target.logic.sync_position(Units.vector_tiles_to_px(tiles))
	target.sync_body_from_logic()
	kill(target)


func owned(sword_id: StringName) -> int:
	return inventory().get_count(sword_id)


## Gives the character a sword of the catalog (as a pickup would) and returns its id.
func give(sword_id: StringName) -> StringName:
	inventory().add(sword_id)
	return sword_id


## From a cleared room: walks out of its open door and waits for the next room, whose enemies are
## frozen.
func walk_out_and_freeze() -> void:
	var index: int = floor_scene().get_run().get_room_index()
	put_player_at_door()
	var moved: Callable = func() -> bool: return floor_scene().get_run().get_room_index() != index
	assert_true(await run_until(moved, WALK_LIMIT_TICKS, door_outward()), "the next room")
	freeze_enemies()


## Kills every enemy of the room and lets the drops come; the
## room is then cleared and its swords lie where the enemies fell.
func clear_room_leaving_drops() -> void:
	kill_all()
	await run_ticks(2)
	assert_true(room().is_cleared(), "the room is cleared")


## Hits to reach: the sword's own hits, from the Warrior's chain.
func hits_of(sword: SwordData) -> PackedInt32Array:
	return sword.get_hit_damages(ItemFixtures.class_data())


## Two frames for a draw pass to run, then back at the start of a physics tick, where run_ticks()
## expects to be (after a process frame the next tick has not run yet).
func wait_draw() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame


## The player's tile, as the logic has it.
func player_tiles() -> Vector2:
	return player().motor.get_position_tiles()
