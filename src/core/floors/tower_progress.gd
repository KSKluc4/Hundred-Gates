class_name TowerProgress
extends RefCounted
## Which floors are cleared and which boss rooms were reached (F-012/C3, C7, D-006). Pure logic.
## Floor numbers count from 1. Marks only ever turn on: nothing un-clears or un-reaches.

signal floor_unlocked(floor_number: int)

const KEY_FLOOR_COUNT: String = "floor_count"
const KEY_CLEARED: String = "cleared"
const KEY_REACHED: String = "reached"

var _floor_count: int = 0
## Index = floor number - 1.
var _cleared: Array[bool] = []
var _reached: Array[bool] = []


## A fresh start: only floor 1 unlocked, nothing cleared or reached.
func setup(floor_count: int) -> void:
	_floor_count = maxi(0, floor_count)
	_cleared = _flags(false)
	_reached = _flags(false)


func get_floor_count() -> int:
	return _floor_count


## C3: floor n is unlocked when n is 1 or floor n - 1 is cleared. False outside 1..count.
func is_floor_unlocked(floor_number: int) -> bool:
	if not _is_known(floor_number):
		return false
	return floor_number == 1 or _cleared[floor_number - 2]


func is_floor_cleared(floor_number: int) -> bool:
	return _is_known(floor_number) and _cleared[floor_number - 1]


func is_boss_reached(floor_number: int) -> bool:
	return _is_known(floor_number) and _reached[floor_number - 1]


## The highest unlocked floor, 0 when there are no floors.
func get_highest_unlocked() -> int:
	if _floor_count < 1:
		return 0
	var highest: int = 1
	while highest < _floor_count and _cleared[highest - 1]:
		highest += 1
	return highest


## C3: true only if it changed something. Refused for a locked or unknown floor.
func mark_boss_reached(floor_number: int) -> bool:
	if not is_floor_unlocked(floor_number) or _reached[floor_number - 1]:
		return false
	_reached[floor_number - 1] = true
	return true


## C3: also marks the boss reached. Emits floor_unlocked(n + 1) when it newly clears floor n and
## n + 1 exists. True only if it changed something.
func mark_floor_cleared(floor_number: int) -> bool:
	if not is_floor_unlocked(floor_number) or _cleared[floor_number - 1]:
		return false
	_cleared[floor_number - 1] = true
	_reached[floor_number - 1] = true
	if floor_number < _floor_count:
		floor_unlocked.emit(floor_number + 1)
	return true


## What the tower gate lists: floors ascending; for each unlocked floor "from the start", then
## "at the boss" if that boss room was reached. Locked floors are not listed.
func get_entries() -> Array[TowerEntry]:
	var entries: Array[TowerEntry] = []
	for floor_number: int in range(1, _floor_count + 1):
		if not is_floor_unlocked(floor_number):
			break
		entries.append(_entry(floor_number, false))
		if is_boss_reached(floor_number):
			entries.append(_entry(floor_number, true))
	return entries


## G7.
func to_dict() -> Dictionary:
	return {
		KEY_FLOOR_COUNT: _floor_count,
		KEY_CLEARED: _cleared.duplicate(),
		KEY_REACHED: _reached.duplicate(),
	}


## C7: a snapshot that doesn't fit is refused and changes nothing. Emits nothing: it restores.
func from_dict(snapshot: Dictionary) -> bool:
	if _floor_count < 1 or not _is_snapshot_valid(snapshot):
		return false
	var cleared: Array = snapshot[KEY_CLEARED]
	var reached: Array = snapshot[KEY_REACHED]
	for index: int in _floor_count:
		_cleared[index] = cleared[index]
		_reached[index] = reached[index]
	return true


func _is_snapshot_valid(snapshot: Dictionary) -> bool:
	if not _has_shape(snapshot):
		return false
	return _flags_are_consistent(snapshot[KEY_CLEARED], snapshot[KEY_REACHED])


## Keys present, the right count, two lists of bools of that length.
func _has_shape(snapshot: Dictionary) -> bool:
	for key: String in [KEY_FLOOR_COUNT, KEY_CLEARED, KEY_REACHED]:
		if not snapshot.has(key):
			return false
	if not (snapshot[KEY_FLOOR_COUNT] is int and snapshot[KEY_FLOOR_COUNT] == _floor_count):
		return false
	if not (snapshot[KEY_CLEARED] is Array and snapshot[KEY_REACHED] is Array):
		return false
	var cleared: Array = snapshot[KEY_CLEARED]
	var reached: Array = snapshot[KEY_REACHED]
	if cleared.size() != _floor_count or reached.size() != _floor_count:
		return false
	for index: int in _floor_count:
		if not (cleared[index] is bool and reached[index] is bool):
			return false
	return true


## C3 on a snapshot: nothing cleared or reached above an uncleared floor, no clear without the
## boss reached.
func _flags_are_consistent(cleared: Array, reached: Array) -> bool:
	for index: int in _floor_count:
		var unlocked: bool = index == 0 or cleared[index - 1]
		if (cleared[index] or reached[index]) and not unlocked:
			return false  # a cleared floor above an uncleared one, or a boss reached on a locked one
		if cleared[index] and not reached[index]:
			return false  # a cleared floor whose boss was never reached
	return true


func _is_known(floor_number: int) -> bool:
	return floor_number >= 1 and floor_number <= _floor_count


func _flags(value: bool) -> Array[bool]:
	var flags: Array[bool] = []
	flags.resize(_floor_count)
	flags.fill(value)
	return flags


func _entry(floor_number: int, at_boss: bool) -> TowerEntry:
	var entry: TowerEntry = TowerEntry.new()
	entry.floor_number = floor_number
	entry.at_boss = at_boss
	entry.is_cleared = _cleared[floor_number - 1]
	return entry
