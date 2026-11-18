class_name FloorTunables
extends Resource
## Rules shared by every room and floor (F-011/C9, G2). Sizes and distances in tiles.

## F-011/C12: share of max HP restored when a non-boss room is cleared.
@export var room_clear_heal_fraction: float = 0.30
## F-011/C12: entering the boss room sets HP to max.
@export var boss_room_full_heal: bool = true
## F-011/C16: nearest a spawn may be to the player start, centre to centre.
@export var min_spawn_distance_tiles: float = 4.0
## F-011/C16: most spawns in a combat room.
@export var max_enemies_per_room: int = 6
@export var min_room_size: Vector2i = Vector2i(8, 6)
@export var max_room_size: Vector2i = Vector2i(40, 22)
## F-011/C16: shortest run of exit tiles.
@export var exit_min_width_tiles: int = 2


## F-011/C9. Empty result means valid.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not (room_clear_heal_fraction >= 0.0 and room_clear_heal_fraction <= 1.0):
		errors.append("room_clear_heal_fraction must be between 0 and 1")
	if not min_spawn_distance_tiles >= 0.0:
		errors.append("min_spawn_distance_tiles must be >= 0")
	if not max_enemies_per_room >= 1:
		errors.append("max_enemies_per_room must be >= 1")
	if not (min_room_size.x >= 1 and min_room_size.y >= 1):
		errors.append("min_room_size must be > 0 on both axes")
	if not (max_room_size.x >= 1 and max_room_size.y >= 1):
		errors.append("max_room_size must be > 0 on both axes")
	if not (min_room_size.x <= max_room_size.x and min_room_size.y <= max_room_size.y):
		errors.append("min_room_size must not exceed max_room_size")
	if not exit_min_width_tiles >= 1:
		errors.append("exit_min_width_tiles must be >= 1")
	return errors
