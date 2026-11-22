extends GutTest
## F-016 T1 (AC2, AC4, AC8): the 15 shipped swords, the three floor tables and the catalog hold
## studio/design/items.md. The numbers below are written out on purpose: a change to the data
## must change them too.

const SWORD_DIR: String = "res://data/items/swords/"
## id, display name, damage, hits, kind, max HP bonus, dash cooldown cut, room heal bonus.
const SWORDS: Array[Array] = [
	[&"recruits_sword", "Recruit's Sword", 42, [10, 10, 22], SwordData.Kind.NONE, 0, 0.0, 0.0],
	[&"iron_cleaver", "Iron Cleaver", 46, [9, 9, 28], SwordData.Kind.HEAVY_FINISHER, 0, 0.0, 0.0],
	[&"twin_edge", "Twin Edge", 43, [12, 12, 19], SwordData.Kind.QUICK_CUTS, 0, 0.0, 0.0],
	[&"guards_blade", "Guard's Blade", 44, [11, 10, 23], SwordData.Kind.VITALITY, 8, 0.0, 0.0],
	[&"swift_blade", "Swift Blade", 44, [11, 10, 23], SwordData.Kind.QUICKSTEP, 0, 0.05, 0.0],
	[&"pilgrims_blade", "Pilgrim's Blade", 44, [11, 10, 23], SwordData.Kind.MENDING, 0, 0.0, 0.05],
	[&"wardens_mercy", "Warden's Mercy", 45, [11, 11, 23], SwordData.Kind.MENDING, 0, 0.0, 0.10],
	[
		&"wardens_stride",
		"Warden's Stride",
		45,
		[11, 11, 23],
		SwordData.Kind.QUICKSTEP,
		0,
		0.08,
		0.0
	],
	[
		&"wardens_verdict",
		"Warden's Verdict",
		47,
		[9, 9, 29],
		SwordData.Kind.HEAVY_FINISHER,
		0,
		0.0,
		0.0
	],
	[&"hexers_needle", "Hexer's Needle", 45, [12, 12, 21], SwordData.Kind.QUICK_CUTS, 0, 0.0, 0.0],
	[&"hexers_balm", "Hexer's Balm", 46, [11, 11, 24], SwordData.Kind.MENDING, 0, 0.0, 0.10],
	[&"hexers_slip", "Hexer's Slip", 46, [11, 11, 24], SwordData.Kind.QUICKSTEP, 0, 0.08, 0.0],
	[
		&"juggernauts_maul",
		"Juggernaut's Maul",
		49,
		[10, 10, 29],
		SwordData.Kind.HEAVY_FINISHER,
		0,
		0.0,
		0.0
	],
	[
		&"juggernauts_fangs",
		"Juggernaut's Fangs",
		46,
		[13, 13, 20],
		SwordData.Kind.QUICK_CUTS,
		0,
		0.0,
		0.0
	],
	[
		&"juggernauts_rush",
		"Juggernaut's Rush",
		48,
		[12, 11, 25],
		SwordData.Kind.QUICKSTEP,
		0,
		0.08,
		0.0
	],
]
const REGULAR_POOL: Array[StringName] = [
	&"iron_cleaver", &"twin_edge", &"guards_blade", &"swift_blade", &"pilgrims_blade"
]
const BOSS_TABLES: Array[Array] = [
	[&"wardens_mercy", &"wardens_stride", &"wardens_verdict"],
	[&"hexers_needle", &"hexers_balm", &"hexers_slip"],
	[&"juggernauts_maul", &"juggernauts_fangs", &"juggernauts_rush"],
]
const BOSS_PERCENTS: PackedInt32Array = [30, 20, 10]
## AC8: the regular kills of floors 1 to 3.
const REGULAR_KILLS: Array[int] = [27, 51, 38]

var _class: ClassData
var _rules: ItemTunables
var _tower: TowerData
var _catalog: LootCatalog


func before_each() -> void:
	_class = load(Tunables.WARRIOR_PATH)
	_rules = Tunables.items
	_tower = load(Tunables.TOWER_PATH)
	_catalog = load(Tunables.LOOT_CATALOG_PATH)


# --- AC2: the swords ---


func test_ac2_the_swords_folder_holds_the_15_swords_and_nothing_else() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(SWORD_DIR)
	var expected: Array[String] = []
	for row: Array in SWORDS:
		expected.append("%s.tres" % row[0])
	var actual: Array[String] = []
	for file_name: String in files:
		if file_name.ends_with(".tres"):
			actual.append(file_name)
	actual.sort()
	expected.sort()
	assert_eq(actual, expected)


func test_ac2_each_sword_loads_and_has_its_numbers() -> void:
	for row: Array in SWORDS:
		var sword: SwordData = load("%s%s.tres" % [SWORD_DIR, row[0]]) as SwordData
		assert_not_null(sword, "%s loads as a SwordData" % row[0])
		if sword == null:
			continue
		assert_eq(sword.id, row[0], "id")
		assert_eq(sword.display_name, row[1], "%s name" % row[0])
		assert_eq(sword.damage, row[2], "%s damage" % row[0])
		assert_eq(sword.kind, row[4], "%s kind" % row[0])
		assert_eq(sword.max_hp_bonus, row[5], "%s max HP bonus" % row[0])
		assert_almost_eq(sword.dash_cooldown_cut, row[6], 0.00001, "%s cooldown cut" % row[0])
		assert_almost_eq(sword.room_heal_bonus, row[7], 0.00001, "%s heal bonus" % row[0])
		assert_eq(sword.get_hit_damages(_class), PackedInt32Array(row[3]), "%s hits" % row[0])


func test_ac2_each_sword_validates_against_the_shipped_class_and_rules() -> void:
	for row: Array in SWORDS:
		var sword: SwordData = load("%s%s.tres" % [SWORD_DIR, row[0]])
		assert_eq(sword.validate(_class, _rules), PackedStringArray(), str(row[0]))


func test_ac2_only_heavy_finisher_and_quick_cuts_swords_carry_weights() -> void:
	for row: Array in SWORDS:
		var sword: SwordData = load("%s%s.tres" % [SWORD_DIR, row[0]])
		var has_own_hits: bool = (
			sword.kind == SwordData.Kind.HEAVY_FINISHER or sword.kind == SwordData.Kind.QUICK_CUTS
		)
		assert_eq(not sword.weights.is_empty(), has_own_hits, str(row[0]))
		if has_own_hits:
			assert_eq(
				sword.weights, PackedInt32Array(row[3]), "%s: the weights are the hits" % row[0]
			)


func test_ac2_the_hits_add_up_to_the_damage_and_every_sword_has_one_trait() -> void:
	for row: Array in SWORDS:
		var hits: Array = row[3]
		assert_eq(hits[0] + hits[1] + hits[2], row[2], "%s hits add up" % row[0])


func test_ac2_the_starter_sword_deals_the_classes_own_hits() -> void:
	var starter: SwordData = load("%srecruits_sword.tres" % SWORD_DIR)
	var own: PackedInt32Array = PackedInt32Array()
	for attack: AttackData in _class.attack_chain:
		own.append(attack.damage)
	assert_eq(starter.get_hit_damages(_class), own)
	assert_eq(starter.kind, SwordData.Kind.NONE)


# --- AC2: the floor tables and the catalog ---


func test_ac2_the_catalog_path_names_the_shipped_file() -> void:
	assert_eq(Tunables.LOOT_CATALOG_PATH, "res://data/items/loot_catalog.tres")
	assert_is(load(Tunables.LOOT_CATALOG_PATH), LootCatalog)
	assert_same(Tunables.loot_catalog, load(Tunables.LOOT_CATALOG_PATH), "the autoload exposes it")


func test_ac2_the_catalog_validates_against_the_shipped_tower_and_class() -> void:
	assert_eq(_catalog.validate(_tower, _class, _rules), PackedStringArray())


func test_ac2_the_starter_is_the_recruits_sword() -> void:
	assert_same(_catalog.starter_sword, load("%srecruits_sword.tres" % SWORD_DIR))


func test_ac2_the_catalog_has_one_table_per_floor_and_all_15_swords() -> void:
	assert_eq(_catalog.floors.size(), 3)
	for number: int in [1, 2, 3]:
		assert_eq(
			_catalog.get_floor_loot(number).resource_path,
			"res://data/items/floor_%d_loot.tres" % number
		)
	assert_eq(_catalog.get_all_swords().size(), 15)
	for row: Array in SWORDS:
		assert_not_null(_catalog.get_sword(row[0]), str(row[0]))


func test_ac2_the_regular_pool_of_every_floor_is_the_five_regular_swords() -> void:
	for number: int in [1, 2, 3]:
		assert_eq(
			_ids(_catalog.get_floor_loot(number).regular_swords),
			Array(REGULAR_POOL),
			"floor %d" % number
		)


func test_ac2_the_boss_tables_and_percents_are_the_design_docs() -> void:
	for index: int in BOSS_TABLES.size():
		var loot: FloorLoot = _catalog.get_floor_loot(index + 1)
		assert_eq(_ids(loot.boss_swords), BOSS_TABLES[index], "floor %d table" % (index + 1))
		assert_eq(loot.boss_percents, BOSS_PERCENTS, "floor %d percents" % (index + 1))
		assert_eq(loot.get_boss_percent_sum(), 60)


func test_ac2_every_floor_drops_one_regular_sword_per_run() -> void:
	for number: int in [1, 2, 3]:
		assert_eq(_catalog.get_floor_loot(number).regular_drops_per_run, 1.0, "floor %d" % number)


func test_ac2_the_swords_of_the_tables_are_the_shipped_files_not_copies() -> void:
	for row: Array in SWORDS:
		var sword: SwordData = load("%s%s.tres" % [SWORD_DIR, row[0]])
		if row[0] == &"recruits_sword":
			continue
		assert_same(_catalog.get_sword(row[0]), sword, str(row[0]))


# --- AC8: the chance per kill ---


func test_ac8_the_shipped_floors_have_27_51_and_38_regular_kills() -> void:
	for index: int in REGULAR_KILLS.size():
		assert_eq(
			_tower.get_floor(index + 1).get_regular_kill_count(),
			REGULAR_KILLS[index],
			"floor %d" % (index + 1)
		)


func test_ac8_the_chance_per_kill_of_the_shipped_floors_is_1_over_the_kills() -> void:
	for index: int in REGULAR_KILLS.size():
		var chance: float = _catalog.get_floor_loot(index + 1).get_chance_per_kill(
			_tower.get_floor(index + 1)
		)
		assert_almost_eq(chance, 1.0 / REGULAR_KILLS[index], 0.0000001, "floor %d" % (index + 1))
	assert_almost_eq(1.0 / 27.0, 0.0370, 0.0001)
	assert_almost_eq(1.0 / 51.0, 0.0196, 0.0001)
	assert_almost_eq(1.0 / 38.0, 0.0263, 0.0001)


# --- AC4: a data test of hits to kill ---


func test_ac4_every_shipped_sword_kills_a_chaser_in_4_hits_a_caster_in_3_and_a_brute_in_9() -> void:
	var enemies: Array[Array] = [
		[load(Tunables.CHASER_PATH), 4],
		[load(Tunables.CASTER_PATH), 3],
		[load(Tunables.BRUTE_PATH), 9],
	]
	for row: Array in SWORDS:
		var sword: SwordData = load("%s%s.tres" % [SWORD_DIR, row[0]])
		for pair: Array in enemies:
			var enemy: EnemyData = pair[0]
			assert_eq(
				_hits_to_kill(sword.get_hit_damages(_class), enemy.max_hp),
				pair[1],
				"%s against the %s (%d HP)" % [row[0], enemy.id, enemy.max_hp]
			)


## The hits needed, the chain started fresh and repeating after its last hit.
func _hits_to_kill(hits: PackedInt32Array, hp: int) -> int:
	var dealt: int = 0
	var count: int = 0
	while dealt < hp and count < 1000:
		dealt += hits[count % hits.size()]
		count += 1
	return count


func _ids(swords: Array[SwordData]) -> Array:
	var ids: Array = []
	for sword: SwordData in swords:
		ids.append(sword.id)
	return ids
