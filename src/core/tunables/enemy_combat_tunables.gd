class_name EnemyCombatTunables
extends Resource
## Rules shared by every enemy attack (F-004/C8). Times in seconds.

## Shortest windup any enemy attack may have.
@export var min_telegraph: float = 0.0
## Shortest time any enemy attack may show its locked aim before going active.
@export var min_locked_telegraph: float = 0.0
## F-008/C7 (d): most projectiles one attack may launch at once. Each is wall-swept every step
## (D-008's cost). 16 by default, so a resource built with new() stays valid.
@export var max_volley_size: int = 16


## F-004/C12. Empty result means valid.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not min_telegraph >= 0.0:
		errors.append("min_telegraph must be >= 0")
	if not min_locked_telegraph >= 0.0:
		errors.append("min_locked_telegraph must be >= 0")
	if not min_locked_telegraph <= min_telegraph + CombatTiming.TIME_EPSILON:
		errors.append("min_locked_telegraph must be <= min_telegraph")
	if not max_volley_size >= 1:
		errors.append("max_volley_size must be >= 1")
	return errors
