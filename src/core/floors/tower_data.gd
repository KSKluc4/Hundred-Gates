class_name TowerData
extends Resource
## The town and the floors, in order (F-012/C9, D-012, G9). `floors[i].floor_number == i + 1`.

@export var town: RoomData
@export var floors: Array[FloorData] = []


func get_floor_count() -> int:
	return floors.size()


## Floor `floor_number` counting from 1. Null outside 1..count.
func get_floor(floor_number: int) -> FloorData:
	if floor_number < 1 or floor_number > floors.size():
		return null
	return floors[floor_number - 1]


## F-012/C9. Empty result means valid. Town errors start with `town: `, floor errors with
## `floor <n>: ` (n = position + 1). All errors are returned, not the first.
func validate(rules: FloorTunables) -> PackedStringArray:
	var errors: PackedStringArray = []
	var owners: Dictionary = {}  # room id -> where it was first seen
	if town == null:
		errors.append("town: the tower needs a town")
	else:
		if not town.is_safe_room:
			errors.append("town: the town must be a safe room")
		for error: String in town.validate(rules):
			errors.append("town: " + error)
		owners[town.id] = "town"
	if floors.is_empty():
		errors.append("floors: a tower needs at least 1 floor")
	for index: int in floors.size():
		var floor_data: FloorData = floors[index]
		var floor_name: String = "floor %d" % (index + 1)
		if floor_data == null:
			errors.append("%s: must not be null" % floor_name)
			continue
		if floor_data.floor_number != index + 1:
			errors.append(
				(
					"%s: floor_number must be %d, is %d"
					% [floor_name, index + 1, floor_data.floor_number]
				)
			)
		for error: String in floor_data.validate(rules):
			errors.append("%s: %s" % [floor_name, error])
		_check_room_ids(floor_data, floor_name, owners, errors)
	return errors


## A room id used twice across the tower. A repeat inside one floor is FloorData's to report.
func _check_room_ids(
	floor_data: FloorData, floor_name: String, owners: Dictionary, errors: PackedStringArray
) -> void:
	var seen_here: Array[StringName] = []
	for room: RoomData in floor_data.rooms:
		if room == null or seen_here.has(room.id):
			continue
		seen_here.append(room.id)
		if owners.has(room.id):
			errors.append(
				(
					"%s: room id %s is already used by %s, room ids must be unique across the tower"
					% [floor_name, room.id, owners[room.id]]
				)
			)
		else:
			owners[room.id] = floor_name
