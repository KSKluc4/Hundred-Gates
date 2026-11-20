class_name CameraTunables
extends Resource
## How a room's camera follows the player (F-013/C3, G2). Presentation settings: nothing in
## core reads them (F-013/C1).

## F-013/C3: the engine's position smoothing on the room's camera.
@export var follow_smoothing_enabled: bool = true
## F-013/C3: Camera2D.position_smoothing_speed. Larger is a tighter follow.
@export var follow_smoothing_speed: float = 8.0
## F-013/C5: width in tiles of the wall-coloured strips just outside a room, so a shake at an
## edge never shows empty space.
@export var outside_margin_tiles: int = 2


## F-013/C3. Empty result means valid. Written so that NaN fails too.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not follow_smoothing_speed > 0.0:
		errors.append("follow_smoothing_speed must be > 0")
	if not outside_margin_tiles >= 0:
		errors.append("outside_margin_tiles must be >= 0")
	return errors
