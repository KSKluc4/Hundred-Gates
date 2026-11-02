class_name EnemyData
extends Resource
## One enemy archetype as data (F-004 §3, G9). Distances in tiles, times in seconds.

## Which brain decides for this enemy. A new kind of behavior is a new value and a new class.
enum Brain { CHASER }

@export var id: StringName = &""
@export var brain: Brain = Brain.CHASER
@export var max_hp: int = 0
@export var hurtbox_radius_tiles: float = 0.0
@export var knockback_scale: float = 0.0
@export var move_speed: float = 0.0
@export var aggro_radius_tiles: float = 0.0
@export var attack_range_tiles: float = 0.0
@export var stop_distance_tiles: float = 0.0
@export var attack_cooldown: float = 0.0
@export var attack: EnemyAttackData = null


## F-004/C12. Empty result means valid. The speed rule isn't here: see validate_against_class().
func validate(step_rate: int, tunables: EnemyCombatTunables) -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"":
		errors.append("id must not be empty")
	if not Brain.values().has(brain):
		errors.append("brain must be a known value")
	if not max_hp >= 1:
		errors.append("max_hp must be >= 1")
	if not hurtbox_radius_tiles > 0.0:
		errors.append("hurtbox_radius_tiles must be > 0")
	if not knockback_scale >= 0.0:
		errors.append("knockback_scale must be >= 0")
	if not move_speed >= 0.0:
		errors.append("move_speed must be >= 0")
	if not aggro_radius_tiles >= 0.0:
		errors.append("aggro_radius_tiles must be >= 0")
	if not attack_range_tiles > 0.0:
		errors.append("attack_range_tiles must be > 0")
	if not stop_distance_tiles >= 0.0:
		errors.append("stop_distance_tiles must be >= 0")
	if not attack_cooldown >= 0.0:
		errors.append("attack_cooldown must be >= 0")
	if attack == null:
		errors.append("attack must be set")
	else:
		for error: String in attack.validate_enemy(step_rate, tunables):
			errors.append("%s: %s" % [attack.id, error])
	return errors


## F-004/C12: "never faster than the player on foot". Walking speed only: lunges may be faster.
## Strict, and a plain comparison: both sides are authored values, so no epsilon.
func validate_against_class(class_data: ClassData) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not move_speed < class_data.move_speed:
		errors.append(
			(
				"enemy %s move_speed %s must be below class %s move_speed %s"
				% [id, move_speed, class_data.id, class_data.move_speed]
			)
		)
	return errors
