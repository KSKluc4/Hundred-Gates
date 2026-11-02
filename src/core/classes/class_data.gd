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
## D-005: the chain is data, one resource per hit, in order.
@export var attack_chain: Array[AttackData] = []
@export var attack_chain_window: float = 0.0
@export var max_hp: int = 0
@export var hurtbox_radius_tiles: float = 0.0
@export var knockback_scale: float = 0.0


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


## F-003/C18: separate from validate(), which keeps F-001's exact rules.
func validate_combat(step_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = _chain_errors(step_rate)
	if not attack_chain_window >= 0.0:
		errors.append("attack_chain_window must be >= 0")
	if not max_hp >= 1:
		errors.append("max_hp must be >= 1")
	if not hurtbox_radius_tiles > 0.0:
		errors.append("hurtbox_radius_tiles must be > 0")
	if not knockback_scale >= 0.0:
		errors.append("knockback_scale must be >= 0")
	return errors


func _chain_errors(step_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	if attack_chain.is_empty():
		errors.append("attack_chain must have at least one entry")
	for index: int in attack_chain.size():
		var attack: AttackData = attack_chain[index]
		if attack == null:
			errors.append("attack_chain entry %d is empty" % index)
			continue
		for error: String in attack.validate(step_rate):
			errors.append("%s: %s" % [attack.id, error])
		if attack.is_finisher and index != attack_chain.size() - 1:
			errors.append("%s: is_finisher is allowed on the last entry only" % attack.id)
	return errors
