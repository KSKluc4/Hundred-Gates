class_name FloorData
extends Resource
## One floor: a linear chain of rooms ending in the boss room (F-011, floors.md, G9).

@export var floor_number: int = 0
@export var rooms: Array[RoomData] = []


func get_room_count() -> int:
	return rooms.size()


## F-011/C8. Empty result means valid. Room errors are prefixed with the room id.
func validate(rules: FloorTunables) -> PackedStringArray:
	var errors: PackedStringArray = []
	if rooms.size() < 2:
		errors.append("rooms: a floor needs at least 2 rooms, has %d" % rooms.size())
	var seen_ids: Array[StringName] = []
	for index: int in rooms.size():
		var room: RoomData = rooms[index]
		if room == null:
			errors.append("rooms[%d] must not be null" % index)
			continue
		var is_last: bool = index == rooms.size() - 1
		if room.is_boss_room and not is_last:
			errors.append("rooms[%d] (%s): a boss room must be the last room" % [index, room.id])
		if is_last and not room.is_boss_room:
			errors.append("rooms[%d] (%s): the last room must be a boss room" % [index, room.id])
		if seen_ids.has(room.id):
			errors.append("rooms[%d]: duplicate room id %s" % [index, room.id])
		seen_ids.append(room.id)
		for error: String in room.validate(rules):
			errors.append("room %s: %s" % [room.id, error])
	return errors
