class_name PlayerCombatTunables
extends Resource
## Combat rules shared by every class (D-005). Times in seconds.

## D-007: a rule of the grid, not a tunable. 30, 60 and 120 ticks/s all divide it.
const STEP_RATE_MULTIPLE: int = 120

@export var input_buffer_window: float = 0.0
@export_range(0.0, 1.0) var stick_deadzone: float = 0.0
## D-007: steps per second, a multiple of 120 so 30/60/120 ticks/s share the same instants.
@export var combat_step_rate: int = 0
@export var player_hurt_iframes: float = 0.0
@export var knockback_duration: float = 0.0
@export var hitstop_normal: float = 0.0
@export var hitstop_finisher: float = 0.0
@export_range(0.0, 1.0) var shake_intensity_hit: float = 0.0
@export_range(0.0, 1.0) var shake_intensity_finisher: float = 0.0
@export_range(0.0, 1.0) var shake_intensity_player_hurt: float = 0.0


## F-001/C17. Empty result means valid.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not input_buffer_window >= 0.0:
		errors.append("input_buffer_window must be >= 0")
	if not (stick_deadzone >= 0.0 and stick_deadzone < 1.0):
		errors.append("stick_deadzone must be >= 0 and < 1")
	return errors


## F-003/C18: separate from validate(), which keeps F-001's exact rules.
func validate_combat() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not (combat_step_rate > 0 and combat_step_rate % STEP_RATE_MULTIPLE == 0):
		errors.append("combat_step_rate must be a positive multiple of %d" % STEP_RATE_MULTIPLE)
	if not player_hurt_iframes >= 0.0:
		errors.append("player_hurt_iframes must be >= 0")
	if not knockback_duration > 0.0:
		errors.append("knockback_duration must be > 0")
	if not hitstop_normal >= 0.0:
		errors.append("hitstop_normal must be >= 0")
	if not hitstop_finisher >= 0.0:
		errors.append("hitstop_finisher must be >= 0")
	if not _is_unit_range(shake_intensity_hit):
		errors.append("shake_intensity_hit must be within 0-1")
	if not _is_unit_range(shake_intensity_finisher):
		errors.append("shake_intensity_finisher must be within 0-1")
	if not _is_unit_range(shake_intensity_player_hurt):
		errors.append("shake_intensity_player_hurt must be within 0-1")
	return errors


func _is_unit_range(value: float) -> bool:
	return value >= 0.0 and value <= 1.0
