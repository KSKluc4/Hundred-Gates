class_name LootCatalog
extends Resource
## Every sword of the game and what each floor drops (F-016/C5, G9). `floors[i]` is floor i + 1;
## a null entry is a floor with no loot.

@export var starter_sword: SwordData
@export var floors: Array[FloorLoot] = []


## F-016/C5: the sword with this id, or null.
func get_sword(sword_id: StringName) -> SwordData:
	for sword: SwordData in get_all_swords():
		if sword.id == sword_id:
			return sword
	return null


## Each sword once (the same resource on several floors counts once): the starter first, then each
## floor's regular pool and boss table in floor order. Nulls are left out.
func get_all_swords() -> Array[SwordData]:
	var all: Array[SwordData] = []
	_add_unique(all, starter_sword)
	for loot: FloorLoot in floors:
		if loot == null:
			continue
		for sword: SwordData in loot.regular_swords:
			_add_unique(all, sword)
		for sword: SwordData in loot.boss_swords:
			_add_unique(all, sword)
	return all


## F-016/C5: floor `floor_number` counting from 1. Null when there is none.
func get_floor_loot(floor_number: int) -> FloorLoot:
	if floor_number < 1 or floor_number > floors.size():
		return null
	return floors[floor_number - 1]


## F-016/C5. Empty result means valid. All errors are returned, not the first. An empty boss table
## or an empty pool is allowed. A floor's errors start with `floor <n>: `.
func validate(tower: TowerData, class_data: ClassData, rules: ItemTunables) -> PackedStringArray:
	var errors: PackedStringArray = []
	if starter_sword == null:
		errors.append("starter_sword: the catalog needs a starter sword")
	if floors.size() != tower.get_floor_count():
		errors.append(
			(
				"floors: the catalog has %d floors, the tower has %d"
				% [floors.size(), tower.get_floor_count()]
			)
		)
	_check_swords(class_data, rules, errors)
	for index: int in floors.size():
		if floors[index] != null:
			_check_floor(
				floors[index], "floor %d" % (index + 1), tower.get_floor(index + 1), errors
			)
	return errors


func _add_unique(all: Array[SwordData], sword: SwordData) -> void:
	if sword != null and not all.has(sword):
		all.append(sword)


## Every sword valid, no id on two different swords, none twice in one list.
func _check_swords(class_data: ClassData, rules: ItemTunables, errors: PackedStringArray) -> void:
	var by_id: Dictionary[StringName, SwordData] = {}
	for sword: SwordData in get_all_swords():
		for error: String in sword.validate(class_data, rules):
			errors.append("sword %s: %s" % [sword.id, error])
		if by_id.has(sword.id):
			errors.append("duplicate sword id %s" % sword.id)
		by_id[sword.id] = sword
	for index: int in floors.size():
		if floors[index] == null:
			continue
		var where: String = "floor %d" % (index + 1)
		_check_list(floors[index].regular_swords, "%s: regular_swords" % where, errors)
		_check_list(floors[index].boss_swords, "%s: boss_swords" % where, errors)


## A sword twice in one pool or table would skew the pick; a null is an empty slot.
func _check_list(list: Array[SwordData], where: String, errors: PackedStringArray) -> void:
	var seen: Array[SwordData] = []
	for index: int in list.size():
		if list[index] == null:
			errors.append("%s[%d] must not be null" % [where, index])
		elif seen.has(list[index]):
			errors.append("duplicate sword id %s in %s" % [list[index].id, where])
		else:
			seen.append(list[index])


func _check_floor(
	loot: FloorLoot, where: String, floor_data: FloorData, errors: PackedStringArray
) -> void:
	if loot.boss_percents.size() != loot.boss_swords.size():
		errors.append(
			(
				"%s: boss_percents has %d entries, boss_swords has %d"
				% [where, loot.boss_percents.size(), loot.boss_swords.size()]
			)
		)
	for percent: int in loot.boss_percents:
		if percent < 1:
			errors.append("%s: every boss percent must be >= 1, found %d" % [where, percent])
	if loot.get_boss_percent_sum() > 100:
		errors.append(
			"%s: the boss percents add up to %d, above 100" % [where, loot.get_boss_percent_sum()]
		)
	if not loot.regular_drops_per_run >= 0.0:
		errors.append("%s: regular_drops_per_run must be >= 0" % where)
		return
	var kills: int = floor_data.get_regular_kill_count() if floor_data != null else 0
	if floor_data != null and loot.regular_drops_per_run > 0.0 and kills < 1:
		errors.append("%s: drops per run on a floor with no kill before the boss" % where)
	elif kills > 0 and loot.get_chance_per_kill(floor_data) > 1.0:
		errors.append(
			(
				"%s: %.2f drops per run over %d kills is a chance above 1"
				% [where, loot.regular_drops_per_run, kills]
			)
		)
