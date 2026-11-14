class_name EnemyData
extends Resource
## One enemy archetype as data (F-004 §3, G9). Distances in tiles, times in seconds.

## Which brain decides for this enemy. A new kind of behavior is a new value and a new class.
## F-005/C13: new values are appended, so saved data keeps its meaning.
enum Brain { CHASER, CASTER, BRUTE }  # F-006/C13: BRUTE appended.

@export var id: StringName = &""
@export var brain: Brain = Brain.CHASER
@export var max_hp: int = 0
@export var hurtbox_radius_tiles: float = 0.0
@export var knockback_scale: float = 0.0
@export var move_speed: float = 0.0
@export var aggro_radius_tiles: float = 0.0
@export var stop_distance_tiles: float = 0.0
## F-005/C7: backs off straight away from the target below this. 0 never retreats.
@export var retreat_distance_tiles: float = 0.0
## F-006/C4: one cooldown shared by every attack in the list, from the end of any recovery.
@export var attack_cooldown: float = 0.0
## F-006/C4: in priority order. A brain uses the first one whose trigger band holds the target
## distance (EnemyBrain.pick_attack()).
@export var attacks: Array[EnemyAttackData] = []
## F-007/C3: stages 1..n in order, each entered at its HP percent. Empty for a plain enemy.
@export var stages: Array[EnemyStageData] = []


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
	if not stop_distance_tiles >= 0.0:
		errors.append("stop_distance_tiles must be >= 0")
	if not (retreat_distance_tiles >= 0.0 and retreat_distance_tiles <= stop_distance_tiles):
		errors.append("retreat_distance_tiles must be >= 0 and <= stop_distance_tiles")
	if not attack_cooldown >= 0.0:
		errors.append("attack_cooldown must be >= 0")
	errors.append_array(_attack_list_errors(attacks, step_rate, tunables))
	errors.append_array(_stages_errors(step_rate, tunables))
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
	# F-007/C13 (f): every stage walks too, so CombatRunner's setup and reload cover it.
	for index: int in stages.size():
		var stage: EnemyStageData = stages[index]
		if stage != null and not stage.move_speed < class_data.move_speed:
			errors.append(
				(
					"enemy %s %s move_speed %s must be below class %s move_speed %s"
					% [
						id,
						_stage_name(index),
						stage.move_speed,
						class_data.id,
						class_data.move_speed
					]
				)
			)
	return errors


## F-006/C9: at least one attack, no null entry, each valid on its own and of the brain's kind.
## F-007/C13 (a), (e): the same for every stage's list, and for every follow-up.
func _attack_list_errors(
	list: Array[EnemyAttackData], step_rate: int, tunables: EnemyCombatTunables
) -> PackedStringArray:
	var errors: PackedStringArray = []
	if list.is_empty():
		errors.append("attacks must not be empty")
	for index: int in list.size():
		var attack: EnemyAttackData = list[index]
		if attack == null:
			errors.append("attacks[%d] must not be null" % index)
			continue
		errors.append_array(_chain_errors(attack, step_rate, tunables))
	return errors


## F-007/C13 (a), (b): the attack, then every follow-up reachable from it, each with every
## attack check. A chain that comes back to an attack it already passed is a cycle.
func _chain_errors(
	root: EnemyAttackData, step_rate: int, tunables: EnemyCombatTunables
) -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen: Array[EnemyAttackData] = []
	var attack: EnemyAttackData = root
	while attack != null:
		seen.append(attack)
		for error: String in attack.validate_enemy(step_rate, tunables):
			errors.append("%s: %s" % [attack.id, error])
		errors.append_array(_attack_kind_errors(attack))
		if seen.has(attack.follow_up):
			errors.append("%s: follow_up %s closes a cycle" % [attack.id, attack.follow_up.id])
			break
		attack = attack.follow_up
	return errors


## F-007/C13 (c)-(e), (g), (h). Every error names the list position and the stage file.
func _stages_errors(step_rate: int, tunables: EnemyCombatTunables) -> PackedStringArray:
	var errors: PackedStringArray = []
	var previous: EnemyStageData = null
	for index: int in stages.size():
		var stage: EnemyStageData = stages[index]
		if stage == null:
			errors.append("stages[%d] must not be null" % index)
			continue
		var stage_errors: PackedStringArray = stage.validate()
		if previous != null and not stage.enter_at_hp_percent < previous.enter_at_hp_percent:
			stage_errors.append(
				(
					"enter_at_hp_percent must be below the previous stage's (%d)"
					% previous.enter_at_hp_percent
				)
			)
		stage_errors.append_array(_attack_list_errors(stage.attacks, step_rate, tunables))
		for error: String in stage_errors:
			errors.append("%s: %s" % [_stage_name(index), error])
		previous = stage
	return errors


## F-007/C13: `stages[i] (<resource_path>)`.
func _stage_name(index: int) -> String:
	var stage: EnemyStageData = stages[index]
	var path: String = stage.resource_path if stage != null else ""
	return "stages[%d] (%s)" % [index, path if not path.is_empty() else "built-in"]


## F-005/C9, F-006/C9: a brain may only use the attack kind it supports.
func _attack_kind_errors(attack: EnemyAttackData) -> PackedStringArray:
	var errors: PackedStringArray = []
	match brain:
		Brain.CHASER, Brain.BRUTE:
			if attack.is_projectile():
				errors.append(
					(
						"brain %s needs a melee attack, %s is a projectile"
						% [Brain.find_key(brain), attack.id]
					)
				)
		Brain.CASTER:
			if not attack.is_projectile():
				errors.append("brain CASTER needs a projectile attack, %s is melee" % attack.id)
	return errors
