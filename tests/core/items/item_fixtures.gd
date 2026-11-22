class_name ItemFixtures
extends RefCounted
## Swords and loot catalogs built in code for F-016 tests (no files besides the shipped class and
## enemies). Built on TowerFixtures. Every catalog this builds validates against the tower it is
## given and the shipped warrior with the shipped item rules.

## The ids of valid_swords(), then a number from 01.
const SWORD_ID_PREFIX: String = "fixture_sword_"
const STARTER_ID: StringName = &"fixture_starter"
## What a regular pool, and a boss table, holds when the caller gives none.
const DEFAULT_POOL_SIZE: int = 2
const DEFAULT_BOSS_PERCENTS: Array[int] = [30, 20, 10]


## The shipped warrior (shared and cached: never write to it).
static func class_data() -> ClassData:
	return load(Tunables.WARRIOR_PATH)


## A copy of the shipped item rules: a test may change it.
static func rules() -> ItemTunables:
	return Tunables.items.duplicate()


## One sword with whatever the caller sets. `weights` empty means the class chain's own.
static func make_sword(
	sword_id: StringName,
	damage: int = 42,
	kind: SwordData.Kind = SwordData.Kind.NONE,
	weights: PackedInt32Array = PackedInt32Array(),
	max_hp_bonus: int = 0,
	dash_cooldown_cut: float = 0.0,
	room_heal_bonus: float = 0.0
) -> SwordData:
	var sword: SwordData = SwordData.new()
	sword.id = sword_id
	sword.display_name = "Sword %s" % sword_id
	sword.damage = damage
	sword.weights = weights
	sword.kind = kind
	sword.max_hp_bonus = max_hp_bonus
	sword.dash_cooldown_cut = dash_cooldown_cut
	sword.room_heal_bonus = room_heal_bonus
	return sword


## The starter of the fixture catalogs: the shipped Recruit's Sword numbers under another id.
static func starter() -> SwordData:
	return make_sword(STARTER_ID, 42)


## `count` distinct valid swords (distinct ids, names and damages 30 to 44), every fourth one with
## no trait, with Vitality, with Quickstep, with Mending in turn. Each validates against the
## shipped warrior and item rules.
static func valid_swords(count: int = 17) -> Array[SwordData]:
	var swords: Array[SwordData] = []
	for index: int in count:
		var sword_id: StringName = StringName("%s%02d" % [SWORD_ID_PREFIX, index + 1])
		var damage: int = 30 + index % 15
		match index % 4:
			1:
				swords.append(make_sword(sword_id, damage, SwordData.Kind.VITALITY, [], 8))
			2:
				swords.append(make_sword(sword_id, damage, SwordData.Kind.QUICKSTEP, [], 0, 0.05))
			3:
				swords.append(
					make_sword(sword_id, damage, SwordData.Kind.MENDING, [], 0, 0.0, 0.05)
				)
			_:
				swords.append(make_sword(sword_id, damage))
	return swords


## A catalog for `tower`: the fixture starter and, on every floor, the same regular pool of
## DEFAULT_POOL_SIZE swords (one drop per run) and its own boss table of three swords at 30, 20
## and 10 percent.
static func fixture_catalog(tower: TowerData) -> LootCatalog:
	var pool: Array[SwordData] = valid_swords(DEFAULT_POOL_SIZE)
	var floor_tables: Array[FloorLoot] = []
	for floor_number: int in range(1, tower.get_floor_count() + 1):
		var boss: Array[SwordData] = []
		for index: int in DEFAULT_BOSS_PERCENTS.size():
			boss.append(
				make_sword(StringName("fixture_boss_%d_%d" % [floor_number, index + 1]), 45)
			)
		var percents: PackedInt32Array = PackedInt32Array(DEFAULT_BOSS_PERCENTS)
		floor_tables.append(floor_loot(1.0, pool, boss, percents))
	return catalog_of(starter(), floor_tables)


## A catalog for `tower` whose every regular drop is certain (`regular_certain`: the drops per run
## equal the floor's kills before the boss, so the chance is 1) or impossible (zero drops), and
## whose boss table on every floor is `boss_swords` with `boss_percents`. The regular pool is
## `regular_swords`, or DEFAULT_POOL_SIZE valid swords when it is empty. The same sword resources
## serve every floor: ids are unique, floors only differ in their drops per run.
static func catalog_with(
	tower: TowerData,
	regular_certain: bool,
	boss_swords: Array[SwordData],
	boss_percents: PackedInt32Array,
	regular_swords: Array[SwordData] = []
) -> LootCatalog:
	var pool: Array[SwordData] = regular_swords
	if pool.is_empty():
		pool = valid_swords(DEFAULT_POOL_SIZE)
	var floor_tables: Array[FloorLoot] = []
	for floor_number: int in range(1, tower.get_floor_count() + 1):
		var drops: float = 0.0
		if regular_certain:
			drops = float(tower.get_floor(floor_number).get_regular_kill_count())
		floor_tables.append(floor_loot(drops, pool, boss_swords, boss_percents))
	return catalog_of(starter(), floor_tables)


static func floor_loot(
	drops_per_run: float,
	regular_swords: Array[SwordData],
	boss_swords: Array[SwordData],
	boss_percents: PackedInt32Array
) -> FloorLoot:
	var loot: FloorLoot = FloorLoot.new()
	loot.regular_drops_per_run = drops_per_run
	loot.regular_swords = regular_swords
	loot.boss_swords = boss_swords
	loot.boss_percents = boss_percents
	return loot


static func catalog_of(starter_sword: SwordData, floor_tables: Array[FloorLoot]) -> LootCatalog:
	var catalog: LootCatalog = LootCatalog.new()
	catalog.starter_sword = starter_sword
	catalog.floors = floor_tables
	return catalog
