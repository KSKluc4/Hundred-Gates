class_name FloorRun
extends RefCounted
## Where the player is on a floor and what HP they carry (F-011/C10-C13). Pure logic: it takes
## the player's HP as arguments and never holds a combatant. The glue reads "cleared" from the
## sim (C11) and reports it here.

signal room_cleared(room_index: int)
signal floor_cleared(floor_number: int)

const KEY_ROOM_INDEX: String = "room_index"
const KEY_ENTRY_HP: String = "entry_hp"
const KEY_ROOM_CLEARED: String = "room_cleared"
const KEY_FLOOR_CLEARED: String = "floor_cleared"

var _floor: FloorData
var _rules: FloorTunables
var _max_hp: int = 0
var _room_index: int = 0
var _entry_hp: int = 0
var _room_cleared: bool = false
var _floor_cleared: bool = false
var _exit_tiles: Array[Vector2i] = []


## A start room outside the floor is clamped into it. Entry HP is max: a run starts healthy.
func setup(floor_data: FloorData, rules: FloorTunables, max_hp: int, start_room: int = 0) -> void:
	_floor = floor_data
	_rules = rules
	_max_hp = max_hp
	_room_index = clampi(start_room, 0, maxi(0, floor_data.get_room_count() - 1))
	_entry_hp = max_hp
	_room_cleared = false
	_floor_cleared = false
	_refresh_exit_tiles()


func get_room() -> RoomData:
	return _floor.rooms[_room_index]


func get_room_index() -> int:
	return _room_index


## HP the player starts the current room with (C12).
func get_entry_hp() -> int:
	return _entry_hp


func is_room_cleared() -> bool:
	return _room_cleared


func is_floor_cleared() -> bool:
	return _floor_cleared


## C12: the heal to apply, once per room (0 the second time). A boss room clear heals nothing and
## finishes the floor. A dead player (0 HP) isn't healed. The amount is capped at max HP, so
## the caller can apply it as it is.
func report_room_cleared(current_hp: int) -> int:
	if _room_cleared:
		return 0
	_room_cleared = true
	room_cleared.emit(_room_index)
	if get_room().is_boss_room:
		if not _floor_cleared:
			_floor_cleared = true
			floor_cleared.emit(_floor.floor_number)
		return 0
	if current_hp <= 0:
		return 0
	var heal: int = roundi(_max_hp * _rules.room_clear_heal_fraction)
	return maxi(0, mini(heal, _max_hp - current_hp))


## C10: decided from the player's logic position, never from physics. Locked until the clear.
func is_exit_reached(player_position_tiles: Vector2) -> bool:
	if not _room_cleared:
		return false
	var tile: Vector2i = Vector2i(floori(player_position_tiles.x), floori(player_position_tiles.y))
	return _exit_tiles.has(tile)


## Moves to the next room. Refused before the clear and on the last room. C12: the boss room is
## entered at max HP when `boss_room_full_heal`, any other room with what the player carries.
func advance(current_hp: int) -> bool:
	if not _room_cleared or _room_index >= _floor.get_room_count() - 1:
		return false
	_room_index += 1
	_room_cleared = false
	if get_room().is_boss_room and _rules.boss_room_full_heal:
		_entry_hp = _max_hp
	else:
		_entry_hp = clampi(current_hp, 0, _max_hp)
	_refresh_exit_tiles()
	return true


## Placeholder death rule until F-012 (ASSUMPTION-3): the same room again, at full HP. The floor's
## own cleared flag stays, so a finished floor never announces itself twice.
func restart_room() -> void:
	_room_cleared = false
	_entry_hp = _max_hp


## G7.
func to_dict() -> Dictionary:
	return {
		KEY_ROOM_INDEX: _room_index,
		KEY_ENTRY_HP: _entry_hp,
		KEY_ROOM_CLEARED: _room_cleared,
		KEY_FLOOR_CLEARED: _floor_cleared,
	}


## C13: a snapshot that doesn't fit this floor is refused and changes nothing.
func from_dict(snapshot: Dictionary) -> bool:
	if _floor == null or not _is_snapshot_valid(snapshot):
		return false
	_room_index = snapshot[KEY_ROOM_INDEX]
	_entry_hp = snapshot[KEY_ENTRY_HP]
	_room_cleared = snapshot[KEY_ROOM_CLEARED]
	_floor_cleared = snapshot[KEY_FLOOR_CLEARED]
	_refresh_exit_tiles()
	return true


func _is_snapshot_valid(snapshot: Dictionary) -> bool:
	for key: String in [KEY_ROOM_INDEX, KEY_ENTRY_HP, KEY_ROOM_CLEARED, KEY_FLOOR_CLEARED]:
		if not snapshot.has(key):
			return false
	if not (snapshot[KEY_ROOM_INDEX] is int and snapshot[KEY_ENTRY_HP] is int):
		return false
	if not (snapshot[KEY_ROOM_CLEARED] is bool and snapshot[KEY_FLOOR_CLEARED] is bool):
		return false
	var index: int = snapshot[KEY_ROOM_INDEX]
	var hp: int = snapshot[KEY_ENTRY_HP]
	return index >= 0 and index < _floor.get_room_count() and hp >= 0 and hp <= _max_hp


## The exit tiles of the current room, kept so the per-tick check doesn't scan the grid.
func _refresh_exit_tiles() -> void:
	_exit_tiles = get_room().get_exit_tiles()
