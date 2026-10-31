class_name ClassData
extends Resource
## One playable class as data (D-005). Distances in tiles, times in seconds.
## Anything a future class could do differently belongs here, not in code (G9).

@export var id: StringName = &""
@export var display_name: String = ""
@export var weapon_family: StringName = &""
@export var move_speed: float = 0.0
@export var move_accel_time: float = 0.0
@export var move_decel_time: float = 0.0
@export var dash_distance: float = 0.0
@export var dash_duration: float = 0.0
@export var dash_iframe_duration: float = 0.0
@export var dash_cooldown: float = 0.0


## F-001/C17. Empty result means valid.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not move_speed > 0.0:
		errors.append("move_speed must be > 0")
	if not move_accel_time >= 0.0:
		errors.append("move_accel_time must be >= 0")
	if not move_decel_time >= 0.0:
		errors.append("move_decel_time must be >= 0")
	if not dash_distance > 0.0:
		errors.append("dash_distance must be > 0")
	if not dash_duration > 0.0:
		errors.append("dash_duration must be > 0")
	if not (dash_iframe_duration > 0.0 and dash_iframe_duration < dash_duration):
		errors.append("dash_iframe_duration must be > 0 and < dash_duration")
	if not dash_cooldown >= 0.0:
		errors.append("dash_cooldown must be >= 0")
	return errors
