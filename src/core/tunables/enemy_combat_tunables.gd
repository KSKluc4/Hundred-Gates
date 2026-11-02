class_name EnemyCombatTunables
extends Resource
## Rules shared by every enemy attack (F-004/C8). Times in seconds.

## Shortest windup any enemy attack may have.
@export var min_telegraph: float = 0.0
## Shortest time any enemy attack may show its locked aim before going active.
@export var min_locked_telegraph: float = 0.0


## F-004/C12. Empty result means valid.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not min_telegraph >= 0.0:
		errors.append("min_telegraph must be >= 0")
	if not min_locked_telegraph >= 0.0:
		errors.append("min_locked_telegraph must be >= 0")
	if not min_locked_telegraph <= min_telegraph + CombatTiming.TIME_EPSILON:
		errors.append("min_locked_telegraph must be <= min_telegraph")
	return errors
