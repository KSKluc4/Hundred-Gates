class_name PlayerCombatTunables
extends Resource
## Combat rules shared by every class (D-005). Times in seconds.

@export var input_buffer_window: float = 0.0
@export_range(0.0, 1.0) var stick_deadzone: float = 0.0


## F-001/C17. Empty result means valid.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not input_buffer_window >= 0.0:
		errors.append("input_buffer_window must be >= 0")
	if not (stick_deadzone >= 0.0 and stick_deadzone < 1.0):
		errors.append("stick_deadzone must be >= 0 and < 1")
	return errors
