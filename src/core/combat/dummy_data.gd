class_name DummyData
extends Resource
## The training dummy. Not an enemy type: F-004 designs those on its own (F-003 §3).
## Distances in tiles, times in seconds. knockback_scale is per instance, set in the scene.

@export var max_hp: int = 0
@export var hurtbox_radius_tiles: float = 0.0
@export var respawn_delay: float = 0.0
@export var pulse_interval: float = 0.0
@export var pulse_telegraph: float = 0.0
@export var pulse_active: float = 0.0
@export var pulse_radius_tiles: float = 0.0
@export var pulse_damage: int = 0
@export var pulse_knockback_tiles: float = 0.0


## F-003/C18. Empty result means valid.
func validate(step_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not max_hp >= 1:
		errors.append("max_hp must be >= 1")
	if not hurtbox_radius_tiles > 0.0:
		errors.append("hurtbox_radius_tiles must be > 0")
	if not respawn_delay >= 0.0:
		errors.append("respawn_delay must be >= 0")
	if not pulse_interval > 0.0:
		errors.append("pulse_interval must be > 0")
	if not pulse_telegraph >= 0.0:
		errors.append("pulse_telegraph must be >= 0")
	for error: String in CombatTiming.window_errors(pulse_telegraph, pulse_active, step_rate):
		errors.append("pulse: %s" % error)
	var cycle: float = pulse_telegraph + pulse_active
	if cycle > pulse_interval + CombatTiming.TIME_EPSILON:
		errors.append("pulse_telegraph + pulse_active must be <= pulse_interval")
	if not pulse_radius_tiles > 0.0:
		errors.append("pulse_radius_tiles must be > 0")
	if not pulse_damage >= 1:
		errors.append("pulse_damage must be >= 1")
	if not pulse_knockback_tiles >= 0.0:
		errors.append("pulse_knockback_tiles must be >= 0")
	return errors
