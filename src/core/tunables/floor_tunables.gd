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
## F-014/C4: how many enemies may be engaged at once when a room leaves its own `max_engaged` at 0.
@export var wave_max_engaged: int = 3
## F-014/C4: seconds a marker shows before a reinforcement arrives.
@export var wave_spawn_warning_duration: float = 0.8
## F-014/C4: seconds between the starts of two arrivals.
@export var wave_spawn_interval: float = 1.5
## F-014/C4: nearest an arrival may be chosen to the player, in tiles.
@export var wave_min_spawn_distance_tiles: float = 6.0
## F-014/C4: nearest an arrival point may be to another, to a spawn tile or to a living enemy.
@export var wave_spawn_gap_tiles: float = 1.5
## F-014/C4: fewest `S` tiles a room with reinforcements needs.
@export var wave_min_arrival_points: int = 2
## F-014/C4: most enemies a room may have in all (spawns plus reinforcements).
@export var max_kill_target: int = 30
## F-014/C4: how far from the player, horizontally and vertically, an arrival is preferred.
@export var wave_arrival_box_tiles: Vector2 = Vector2(19, 10)
## F-014/C4 (CR-1): the longest walk, in tiles, from an arrival point to the player that still
## counts as near in C8's first tier.
@export var wave_max_walk_tiles: float = 18.0


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
	_validate_waves(errors)
	return errors


## F-014/C4. Written as `not x >= y`, so a NaN fails too.
func _validate_waves(errors: PackedStringArray) -> void:
	if not wave_max_engaged >= 1:
		errors.append("wave_max_engaged must be >= 1")
	if not wave_spawn_warning_duration >= 0.0:
		errors.append("wave_spawn_warning_duration must be >= 0")
	if not wave_spawn_interval >= 0.0:
		errors.append("wave_spawn_interval must be >= 0")
	if not wave_min_spawn_distance_tiles >= 0.0:
		errors.append("wave_min_spawn_distance_tiles must be >= 0")
	if not wave_spawn_gap_tiles >= 0.0:
		errors.append("wave_spawn_gap_tiles must be >= 0")
	if not wave_min_arrival_points >= 1:
		errors.append("wave_min_arrival_points must be >= 1")
	if not max_kill_target >= 1:
		errors.append("max_kill_target must be >= 1")
	if not (wave_arrival_box_tiles.x > 0.0 and wave_arrival_box_tiles.y > 0.0):
		errors.append("wave_arrival_box_tiles must be > 0 on both axes")
	if not wave_max_walk_tiles >= 0.0:
		errors.append("wave_max_walk_tiles must be >= 0")
