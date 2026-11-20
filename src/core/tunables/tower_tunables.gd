class_name TowerTunables
extends Resource
## Timing of the tower loop (F-012/C14, G2). Seconds.

## F-012/C5: seconds of ticked time between the player's death and the town.
@export var death_return_delay: float = 1.5
## F-012/C14: seconds a HUD banner stays on screen.
@export var banner_duration: float = 2.5


## F-012/C14. Empty result means valid. Zero is allowed: the pause or banner is skipped.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not death_return_delay >= 0.0:
		errors.append("death_return_delay must be >= 0")
	if not banner_duration >= 0.0:
		errors.append("banner_duration must be >= 0")
	return errors
