class_name EnemyStageData
extends Resource
## F-007/C3: one boss stage after stage 0, as data (G9). Stage 0 is EnemyData itself. A stage
## swaps only these values: every other one (HP, radii, distances, knockback scale, brain)
## stays EnemyData's in every stage. Times in seconds, speeds in tiles per second.

## F-007/C5: holds when hp * 100 <= max_hp * enter_at_hp_percent. 1-99, strictly decreasing
## along EnemyData.stages.
@export var enter_at_hp_percent: int = 0
## F-007/C7: the planted pause when this stage is entered. 0 = no shift state.
@export var shift_duration: float = 0.0
## F-006/C4 rules, as EnemyData.attacks: in priority order, first band that holds wins.
@export var attacks: Array[EnemyAttackData] = []
@export var move_speed: float = 0.0
## F-007/C8: applies from the next time a cooldown starts.
@export var attack_cooldown: float = 0.0


## F-007/C5: integers, so the line is exact at any HP.
func holds(hp: int, max_hp: int) -> bool:
	return hp * 100 <= max_hp * enter_at_hp_percent


## F-007/C13 (c)-(d), (h): this stage's own values. The order of percents, the attack list
## and the speed rule are checked by EnemyData, which knows the other stages and the brain.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not (enter_at_hp_percent >= 1 and enter_at_hp_percent <= 99):
		errors.append("enter_at_hp_percent must be 1-99")
	if not shift_duration >= 0.0:
		errors.append("shift_duration must be >= 0")
	if not move_speed >= 0.0:
		errors.append("move_speed must be >= 0")
	if not attack_cooldown >= 0.0:
		errors.append("attack_cooldown must be >= 0")
	return errors
