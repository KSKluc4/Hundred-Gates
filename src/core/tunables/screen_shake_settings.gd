class_name ScreenShakeSettings
extends Resource
## Placeholder shake look (→ Art & Game Feel). Core never emits shake (F-003/C10).

@export var screen_shake_enabled: bool = true
@export var max_offset_px: float = 0.0
@export var decay_time: float = 0.0


## F-003/C18. Empty result means valid.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not max_offset_px >= 0.0:
		errors.append("max_offset_px must be >= 0")
	if not decay_time > 0.0:
		errors.append("decay_time must be > 0")
	return errors
