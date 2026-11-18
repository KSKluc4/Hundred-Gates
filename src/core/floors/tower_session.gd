class_name TowerSession
extends RefCounted
## Where the character is in the tower loop: town, on a floor, or in the pause after dying
## (F-012/C2, C4-C7, D-006). It owns the TowerProgress and is the only thing that changes it. The
## glue reports events here and shows the place this says (C12). Pure logic: no nodes, no time
## of its own; the pause is ticked by the caller.

signal place_changed(place: Place)
## `newly_unlocked` is the floor this clear opened, or 0: a replay, or the last floor.
signal floor_cleared(floor_number: int, newly_unlocked: int)

enum Place { TOWN, FLOOR, DEATH_PAUSE }

const KEY_PLACE: String = "place"
const KEY_FLOOR: String = "floor"
const KEY_START_ROOM: String = "start_room"
const KEY_DEATH_TIME_LEFT: String = "death_time_left"
const KEY_PROGRESS: String = "progress"

var _tower: TowerData
var _rules: TowerTunables
var _progress: TowerProgress = TowerProgress.new()
var _place: Place = Place.TOWN
var _floor_number: int = 0
var _start_room: int = 0
var _death_time_left: float = 0.0
## C6: the floor was cleared during this visit; only then may it be left through the door.
var _cleared_in_run: bool = false


## The town, with fresh progress.
func setup(tower: TowerData, rules: TowerTunables) -> void:
	_tower = tower
	_rules = rules
	_progress = TowerProgress.new()
	_progress.setup(tower.get_floor_count())
	_place = Place.TOWN
	_clear_visit()


func get_progress() -> TowerProgress:
	return _progress


func get_place() -> Place:
	return _place


## 0 in the town. The floor keeps its number through the death pause (the glue still shows it).
func get_floor_number() -> int:
	return _floor_number


## Null in the town.
func get_floor_data() -> FloorData:
	return _tower.get_floor(_floor_number) if _tower != null else null


## The room index the floor starts in: 0, or the boss room (the last one) for an "at the boss"
## entry. 0 in the town.
func get_start_room() -> int:
	return _start_room


## C4: only from the town, only for an unlocked floor, and "at the boss" only if that boss room
## was reached.
func enter_floor(floor_number: int, at_boss: bool) -> bool:
	if _tower == null or _place != Place.TOWN:
		return false
	var floor_data: FloorData = _tower.get_floor(floor_number)
	if floor_data == null or not _progress.is_floor_unlocked(floor_number):
		return false
	if at_boss and not _progress.is_boss_reached(floor_number):
		return false
	_floor_number = floor_number
	_start_room = floor_data.get_room_count() - 1 if at_boss else 0
	_cleared_in_run = false
	_set_place(Place.FLOOR)
	return true


## C3: a boss room counts as reached the moment it is entered. Ignored outside a floor and for an
## index outside the floor.
func report_room_entered(room_index: int) -> void:
	if _place != Place.FLOOR:
		return
	var floor_data: FloorData = get_floor_data()
	if floor_data == null or room_index < 0 or room_index >= floor_data.get_room_count():
		return
	var room: RoomData = floor_data.rooms[room_index]
	if room != null and room.is_boss_room:
		_progress.mark_boss_reached(_floor_number)


## Acts once per visit, and only on a floor (C5: after a death it is ignored).
func report_floor_cleared() -> void:
	if _place != Place.FLOOR or _cleared_in_run:
		return
	_cleared_in_run = true
	var newly_cleared: bool = _progress.mark_floor_cleared(_floor_number)
	var opened: int = 0
	if newly_cleared and _floor_number < _progress.get_floor_count():
		opened = _floor_number + 1
	floor_cleared.emit(_floor_number, opened)


## C6: true only on a floor that was cleared during this visit. Then the town.
func report_floor_exited() -> bool:
	if _place != Place.FLOOR or not _cleared_in_run:
		return false
	_go_to_town()
	return true


## C5: the death pause starts; a second report during it changes nothing.
func report_player_died() -> void:
	if _place != Place.FLOOR:
		return
	_death_time_left = maxf(0.0, _rules.death_return_delay)
	_set_place(Place.DEATH_PAUSE)


## Counts the death pause down. A delay of 0 reaches the town on the next tick, not before.
func tick(delta: float) -> void:
	if _place != Place.DEATH_PAUSE:
		return
	_death_time_left -= delta
	if _death_time_left <= 0.0:
		_go_to_town()


## Seconds of pause left. 0 outside the death pause.
func get_death_time_left() -> float:
	return _death_time_left


## G7: the progress snapshot is part of it.
func to_dict() -> Dictionary:
	return {
		KEY_PLACE: int(_place),
		KEY_FLOOR: _floor_number,
		KEY_START_ROOM: _start_room,
		KEY_DEATH_TIME_LEFT: _death_time_left,
		KEY_PROGRESS: _progress.to_dict(),
	}


## C7: a snapshot that doesn't fit is refused and changes nothing. The "cleared during this
## visit" flag is not saved: a restored floor starts over, and its exit stays shut until it is
## cleared again.
func from_dict(snapshot: Dictionary) -> bool:
	if _tower == null or not snapshot.has(KEY_PROGRESS) or not snapshot[KEY_PROGRESS] is Dictionary:
		return false
	var scratch: TowerProgress = TowerProgress.new()
	scratch.setup(_tower.get_floor_count())
	if not scratch.from_dict(snapshot[KEY_PROGRESS]) or not _fits(snapshot, scratch):
		return false
	var before: Place = _place
	_progress.from_dict(snapshot[KEY_PROGRESS])
	_place = snapshot[KEY_PLACE] as Place
	_floor_number = snapshot[KEY_FLOOR]
	_start_room = snapshot[KEY_START_ROOM]
	_death_time_left = float(snapshot[KEY_DEATH_TIME_LEFT])
	_cleared_in_run = false
	if _place != before:
		place_changed.emit(_place)
	return true


## Everything but the progress snapshot, which `scratch` already accepted.
func _fits(snapshot: Dictionary, scratch: TowerProgress) -> bool:
	if not _has_types(snapshot):
		return false
	var place: int = snapshot[KEY_PLACE]
	var floor_number: int = snapshot[KEY_FLOOR]
	var start_room: int = snapshot[KEY_START_ROOM]
	var time_left: float = float(snapshot[KEY_DEATH_TIME_LEFT])
	# Time is left only in the pause, and never more than the delay.
	var most: float = maxf(0.0, _rules.death_return_delay) if place == Place.DEATH_PAUSE else 0.0
	if not (time_left >= 0.0 and time_left <= most):
		return false
	if place == Place.TOWN:
		return floor_number == 0 and start_room == 0
	return _fits_floor(floor_number, start_room, scratch)


## The four keys exist, hold numbers, and the place is one of the three.
func _has_types(snapshot: Dictionary) -> bool:
	for key: String in [KEY_PLACE, KEY_FLOOR, KEY_START_ROOM, KEY_DEATH_TIME_LEFT]:
		if not snapshot.has(key):
			return false
	var place: Variant = snapshot[KEY_PLACE]
	if not (place is int and snapshot[KEY_FLOOR] is int and snapshot[KEY_START_ROOM] is int):
		return false
	var time_left: Variant = snapshot[KEY_DEATH_TIME_LEFT]
	if not (time_left is float or time_left is int):
		return false
	return place >= Place.TOWN and place <= Place.DEATH_PAUSE


## A floor the character may be on: unlocked, and a start room that entering could have given.
func _fits_floor(floor_number: int, start_room: int, scratch: TowerProgress) -> bool:
	var floor_data: FloorData = _tower.get_floor(floor_number)
	if floor_data == null or not scratch.is_floor_unlocked(floor_number):
		return false
	if start_room == 0:
		return true
	return start_room == floor_data.get_room_count() - 1 and scratch.is_boss_reached(floor_number)


func _set_place(place: Place) -> void:
	if place == _place:
		return
	_place = place
	place_changed.emit(_place)


func _go_to_town() -> void:
	_clear_visit()
	_set_place(Place.TOWN)


## Back to "in the town": no floor, no start room, no pause, nothing cleared this visit.
func _clear_visit() -> void:
	_floor_number = 0
	_start_room = 0
	_death_time_left = 0.0
	_cleared_in_run = false
