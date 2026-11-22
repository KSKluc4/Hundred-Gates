class_name RoomLoot
extends RefCounted
## F-016/C9: the loot of one room. It hears its enemies die, rolls for each of them at one fixed
## point of the combat step, holds the drops where they fell, and lets the player's position take
## them. CombatSim calls end_step() once at the end of every combat step (never once per physics
## tick, so nothing here depends on the tick rate). Made by CharacterLoot.make_room_loot(); what is
## taken is reported back to it. Reads no clock and no frame count.

const KEY_DROPS: String = "drops"
const KEY_SWORD: String = "sword"
const KEY_POSITION: String = "position"
const KEY_BOSS_FLOOR: String = "boss_floor"

var _character: CharacterLoot = null
var _floor_number: int = 0
var _is_boss_room: bool = false
## Null: this floor has no loot, and nothing here rolls or draws.
var _floor_loot: FloorLoot = null
var _chance_per_kill: float = 0.0
var _pickup_radius: float = 0.0
## Everything watched, in the order of watch_enemy(): a death is told by index, so the signal holds
## no reference to the combatant (that would be a cycle).
var _enemies: Array[Combatant] = []
var _rolled: Array[bool] = []
## Indexes into _enemies of the deaths not rolled yet, in the order `died` fired.
var _queue: Array[int] = []
var _player: Combatant = null
var _drops: Array[LootDrop] = []
var _taken: Array[StringName] = []


## `character` hears every take. The room is the boss room when `room_index` is the floor's last.
## A null `floor_loot` (or a null `floor_data`) is a room that drops nothing. `pickup_radius` is in
## tiles.
func setup(
	character: CharacterLoot,
	floor_number: int,
	floor_data: FloorData,
	room_index: int,
	floor_loot: FloorLoot,
	pickup_radius: float
) -> void:
	_character = character
	_floor_number = floor_number
	_is_boss_room = floor_data != null and room_index == floor_data.get_room_count() - 1
	_floor_loot = floor_loot if floor_data != null else null
	_chance_per_kill = 0.0
	if _floor_loot != null:
		_chance_per_kill = _floor_loot.get_chance_per_kill(floor_data)
	_pickup_radius = pickup_radius


func get_floor_number() -> int:
	return _floor_number


func is_boss_room() -> bool:
	return _is_boss_room


## An enemy that counts toward the room's kill target. Each death is rolled once, however often
## it dies. Watching the same combatant twice does nothing the second time.
func watch_enemy(combatant: Combatant) -> void:
	if _enemies.has(combatant):
		return
	_enemies.append(combatant)
	_rolled.append(false)
	combatant.get_combat_state().died.connect(_on_enemy_died.bind(_enemies.size() - 1))


## The player: it takes what lies within reach while it is alive. With none watched nothing is
## taken by walking.
func watch_player(combatant: Combatant) -> void:
	_player = combatant


## C9: the end of one combat step. (1) Every death since the last call is rolled, in the order it
## happened, whether or not the player is alive; each drop lies where its enemy is. (2) If the
## player is alive, every drop in reach is taken, in the order they dropped.
func end_step() -> void:
	_roll_queued_deaths()
	if _player_is_alive():
		_take_in_reach()


## The drops lying here, in the order they dropped. For drawing; changing the list changes
## nothing in the room.
func get_drops() -> Array[LootDrop]:
	return _drops.duplicate()


## What was taken since the last call, in the order taken. Empties the list.
func pop_taken() -> Array[StringName]:
	var taken: Array[StringName] = _taken
	_taken = []
	return taken


## C16: takes everything that still lies here, in drop order, wherever the player is. Takes nothing
## when the player is dead. The swords are in the list pop_taken() returns.
func take_all() -> void:
	if _player != null and not _player.is_alive():
		return
	while not _drops.is_empty():
		_take(_drops[0])


## G7: the lying drops only. The queue of deaths is empty between steps, and what an enemy was
## rolled for belongs to the room that watches it.
func to_dict() -> Dictionary:
	var entries: Array[Dictionary] = []
	for drop: LootDrop in _drops:
		(
			entries
			. append(
				{
					KEY_SWORD: String(drop.sword_id),
					KEY_POSITION: drop.position,
					KEY_BOSS_FLOOR: drop.boss_floor,
				}
			)
		)
	return {KEY_DROPS: entries}


## Why `snapshot` can't be restored, empty when it can. A sword must be one the character's
## catalog knows, and a boss floor is this room's own floor, and only in the boss room.
func restore_errors(snapshot: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not snapshot.has(KEY_DROPS) or not snapshot[KEY_DROPS] is Array:
		errors.append("room loot: no list of drops")
		return errors
	for entry: Variant in snapshot[KEY_DROPS]:
		var problem: String = _drop_error(entry)
		if not problem.is_empty():
			errors.append(problem)
			return errors
	return errors


## Refuses what restore_errors() lists, and then changes nothing. Replaces the lying drops.
func from_dict(snapshot: Dictionary) -> bool:
	if not restore_errors(snapshot).is_empty():
		return false
	_drops = []
	for entry: Dictionary in snapshot[KEY_DROPS]:
		_drops.append(
			LootDrop.make(StringName(entry[KEY_SWORD]), entry[KEY_POSITION], entry[KEY_BOSS_FLOOR])
		)
	return true


func _on_enemy_died(index: int) -> void:
	_queue.append(index)


func _player_is_alive() -> bool:
	return _player != null and _player.is_alive()


func _roll_queued_deaths() -> void:
	var queued: Array[int] = _queue
	_queue = []
	for index: int in queued:
		if _rolled[index]:
			continue
		_rolled[index] = true
		_roll_for(_enemies[index])


## C10, C11. A floor without loot rolls nothing and draws nothing.
func _roll_for(enemy: Combatant) -> void:
	if _floor_loot == null or _character == null:
		return
	var sword: SwordData = _boss_sword() if _is_boss_room else _regular_sword()
	if sword != null:
		var boss_floor: int = _floor_number if _is_boss_room else 0
		_drops.append(LootDrop.make(sword.id, enemy.get_position_tiles(), boss_floor))


func _regular_sword() -> SwordData:
	var pool: Array[SwordData] = _floor_loot.regular_swords
	var pick: int = _character.get_roller().roll_regular(_chance_per_kill, pool.size())
	return pool[pick] if pick >= 0 else null


## C11: the guarantee holds until the character has taken a boss sword of this floor.
func _boss_sword() -> SwordData:
	var table: Array[SwordData] = _floor_loot.boss_swords
	if table.is_empty():
		return null
	var guaranteed: bool = not _character.is_boss_sword_taken(_floor_number)
	var pick: int = _character.get_roller().roll_boss(_floor_loot.boss_percents, guaranteed)
	return table[pick] if pick >= 0 and pick < table.size() else null


## Centre to centre, up to the radius plus the sim's distance epsilon.
func _take_in_reach() -> void:
	var player_at: Vector2 = _player.get_position_tiles()
	var reach: float = _pickup_radius + Geometry.DISTANCE_EPSILON
	for drop: LootDrop in _drops.duplicate():
		if drop.position.distance_to(player_at) <= reach:
			_take(drop)


func _take(drop: LootDrop) -> void:
	_drops.erase(drop)
	_taken.append(drop.sword_id)
	_character.report_taken(drop.sword_id, drop.boss_floor)


func _drop_error(entry: Variant) -> String:
	if not (entry is Dictionary and entry.has_all([KEY_SWORD, KEY_POSITION, KEY_BOSS_FLOOR])):
		return "room loot: a drop is not {sword, position, boss_floor}"
	var text: bool = entry[KEY_SWORD] is String or entry[KEY_SWORD] is StringName
	if not (text and entry[KEY_POSITION] is Vector2 and entry[KEY_BOSS_FLOOR] is int):
		return "room loot: a drop has wrong types"
	var at: Vector2 = entry[KEY_POSITION]
	if not (is_finite(at.x) and is_finite(at.y)):
		return "room loot: %s lies at a position that is not a number" % entry[KEY_SWORD]
	if _character == null or not _character.knows_sword(StringName(entry[KEY_SWORD])):
		return "room loot: %s is not a sword of the catalog" % entry[KEY_SWORD]
	var boss_floor: int = entry[KEY_BOSS_FLOOR]
	if boss_floor != 0 and not (_is_boss_room and boss_floor == _floor_number):
		return "room loot: %s has a boss floor that is not this room's" % entry[KEY_SWORD]
	return ""
