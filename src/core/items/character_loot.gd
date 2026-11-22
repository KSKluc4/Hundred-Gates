class_name CharacterLoot
extends RefCounted
## F-016/C13: everything loot-related one character owns for as long as its tower progress lives:
## the inventory, the roller, the catalog, and which floors' boss swords were taken. The session
## owns one. Rooms get a RoomLoot from make_room_loot() and report what they take back here.
## With no catalog (a game without loot) the character owns nothing and every roll is a no.

const KEY_ROLLER: String = "roller"
const KEY_INVENTORY: String = "inventory"
const KEY_BOSS_TAKEN: String = "boss_taken"

var _catalog: LootCatalog = null
var _inventory: Inventory = Inventory.new()
var _roller: LootRoller = LootRoller.new()
## Floor numbers whose boss sword was taken, in the order they were. C11: not the floors whose
## boss dropped one.
var _boss_taken: Array[int] = []


## Starts the character over: the catalog's starter sword, owned once and equipped, a roller
## seeded with `roller_seed`, no boss sword taken. A null catalog (or one without a starter) gives
## nothing. The inventory and the roller are the same objects as before.
func setup(catalog: LootCatalog, roller_seed: int) -> void:
	_catalog = catalog
	_inventory.from_dict({Inventory.KEY_OWNED: [], Inventory.KEY_EQUIPPED: ""})
	_roller.seed_with(roller_seed)
	_boss_taken = []
	if _catalog != null and _catalog.starter_sword != null:
		_inventory.add(_catalog.starter_sword.id)
		_inventory.equip(_catalog.starter_sword.id)


func get_catalog() -> LootCatalog:
	return _catalog


func get_inventory() -> Inventory:
	return _inventory


func get_roller() -> LootRoller:
	return _roller


## The sword the character fights with, or null (no catalog, nothing equipped).
func get_equipped_sword() -> SwordData:
	if _catalog == null:
		return null
	return _catalog.get_sword(_inventory.get_equipped_id())


## C11: a boss sword of this floor was taken, ever.
func is_boss_sword_taken(floor_number: int) -> bool:
	return _boss_taken.has(floor_number)


## Whether the catalog has a sword with this id.
func knows_sword(sword_id: StringName) -> bool:
	return _catalog != null and _catalog.get_sword(sword_id) != null


## C9, C13: a room's loot for room `room_index` of floor `floor_number`. The floor's tables and
## the pickup radius (`rules`) are read now. A character with no catalog, or a floor with no
## table, gets a room that drops nothing.
func make_room_loot(
	floor_number: int, floor_data: FloorData, room_index: int, rules: ItemTunables
) -> RoomLoot:
	var floor_loot: FloorLoot = null
	if _catalog != null:
		floor_loot = _catalog.get_floor_loot(floor_number)
	var radius: float = rules.pickup_radius_tiles if rules != null else 0.0
	var room_loot: RoomLoot = RoomLoot.new()
	room_loot.setup(self, floor_number, floor_data, room_index, floor_loot, radius)
	return room_loot


## What a RoomLoot calls when the player takes a drop: the sword is owned once more, and a boss's
## sword (`boss_floor` above 0) ends that floor's guarantee (C11).
func report_taken(sword_id: StringName, boss_floor: int) -> void:
	_inventory.add(sword_id)
	if boss_floor > 0 and not _boss_taken.has(boss_floor):
		_boss_taken.append(boss_floor)


## G7. The catalog is not part of it: the one that restores must be the one that saved.
func to_dict() -> Dictionary:
	return {
		KEY_ROLLER: _roller.to_dict(),
		KEY_INVENTORY: _inventory.to_dict(),
		KEY_BOSS_TAKEN: _boss_taken.duplicate(),
	}


## C13: why `snapshot` can't be restored, empty when it can. Besides the shapes: an owned id the
## catalog doesn't have, a floor outside the catalog's, a state with nothing equipped when there
## is a catalog, and, with no catalog, anything but the empty inventory and no floor.
func restore_errors(snapshot: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not snapshot.has_all([KEY_ROLLER, KEY_INVENTORY, KEY_BOSS_TAKEN]):
		errors.append("loot: missing keys")
		return errors
	if not (
		snapshot[KEY_ROLLER] is Dictionary
		and snapshot[KEY_INVENTORY] is Dictionary
		and snapshot[KEY_BOSS_TAKEN] is Array
	):
		errors.append("loot: wrong types")
		return errors
	errors.append_array(_roller.restore_errors(snapshot[KEY_ROLLER]))
	var scratch: Inventory = Inventory.new()
	errors.append_array(scratch.restore_errors(snapshot[KEY_INVENTORY]))
	if not errors.is_empty():
		return errors
	scratch.from_dict(snapshot[KEY_INVENTORY])
	errors.append_array(_inventory_errors(scratch))
	errors.append_array(_floor_errors(snapshot[KEY_BOSS_TAKEN]))
	return errors


## Refuses what restore_errors() lists, and then changes nothing.
func from_dict(snapshot: Dictionary) -> bool:
	if not restore_errors(snapshot).is_empty():
		return false
	_roller.from_dict(snapshot[KEY_ROLLER])
	_inventory.from_dict(snapshot[KEY_INVENTORY])
	_boss_taken = []
	for floor_number: int in snapshot[KEY_BOSS_TAKEN]:
		_boss_taken.append(floor_number)
	return true


func _inventory_errors(inventory: Inventory) -> PackedStringArray:
	var errors: PackedStringArray = []
	if _catalog == null:
		if not inventory.get_ids().is_empty():
			errors.append("loot: no catalog, but swords are owned")
		return errors
	if inventory.get_equipped_id() == &"":
		errors.append("loot: nothing is equipped")
	for sword_id: StringName in inventory.get_ids():
		if _catalog.get_sword(sword_id) == null:
			errors.append("loot: %s is not a sword of the catalog" % sword_id)
	return errors


func _floor_errors(floors: Array) -> PackedStringArray:
	var errors: PackedStringArray = []
	var floor_count: int = _catalog.floors.size() if _catalog != null else 0
	var seen: Array[int] = []
	for entry: Variant in floors:
		if not entry is int:
			errors.append("loot: a taken floor is not an integer")
		elif int(entry) < 1 or int(entry) > floor_count:
			errors.append("loot: floor %d is not one of the catalog's" % int(entry))
		elif seen.has(int(entry)):
			errors.append("loot: floor %d is listed twice" % int(entry))
		else:
			seen.append(int(entry))
	return errors
