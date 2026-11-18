class_name FloorDebugLabel
extends Label
## F-011/AC23: placeholder floor readout. Builds its text from the floor scene's getters every
## frame, so a restart, a skip or a room swap can't leave it stale (G6). Nothing reads it.

@export var floor_scene: FloorScene


func _process(_delta: float) -> void:
	text = get_text_now()


func get_text_now() -> String:
	if floor_scene == null:
		return ""
	var errors: PackedStringArray = floor_scene.get_setup_errors()
	if not errors.is_empty():
		return "FLOOR NOT BUILT\n%s" % "\n".join(errors)
	var run: FloorRun = floor_scene.get_run()
	var room: Room = floor_scene.get_room()
	if run == null or room == null:
		return ""
	var state: CombatState = room.get_player().motor.get_combat_state()
	var lines: PackedStringArray = [
		(
			"Floor %d  room %d / %d"
			% [
				floor_scene.floor_data.floor_number,
				run.get_room_index() + 1,
				floor_scene.floor_data.get_room_count()
			]
		),
		"HP %d / %d" % [state.get_hp(), state.get_max_hp()],
		"Enemies %d" % room.count_living_enemies(),
	]
	if room.is_door_open():
		lines.append("EXIT OPEN")
	if run.is_floor_cleared():
		lines.append("FLOOR CLEARED")
	return "\n".join(lines)
