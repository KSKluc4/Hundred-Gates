class_name EnemyAttackData
extends AttackData
## One enemy attack (F-004/C5). An AttackData that also tracks, then locks, and may lunge.
## F-005: a projectile_speed_tiles above 0 makes it a projectile attack. Then range_tiles is
## the projectile's radius, and the attack's own sector never exists (C8).

const ENEMY_SNAPSHOT_KEYS: Array[String] = [
	"aim_track_time",
	"lunge_tiles",
	"projectile_speed_tiles",
	"projectile_max_distance_tiles",
	"trigger_min_tiles",
	"trigger_max_tiles",
	"wall_stun_duration",
	"volley_angles_deg",  # F-008/C3: appended.
]
const FULL_CIRCLE_DEG: float = 360.0
const HALF_CIRCLE_DEG: float = 180.0
## F-008/C7 (c): two volley entries closer than this, modulo 360, point the same way.
const VOLLEY_ANGLE_EPSILON_DEG: float = 0.01
## F-008 CR-1: float rounding allowed at that cutoff, so a gap of exactly 0.01 passes in any
## list order. Far below the cutoff: [0, 0.005] is still rejected.
const VOLLEY_ANGLE_ROUNDING_DEG: float = 1e-9

## Seconds of windup during which the aim follows the target (CQ11).
@export var aim_track_time: float = 0.0
## Distance moved along the aim over the active phase.
@export var lunge_tiles: float = 0.0
## F-005/C4: tiles per second. 0 means a melee attack.
@export var projectile_speed_tiles: float = 0.0
## F-005/C4: the projectile stops exactly this far from its launch point. 0 for melee.
@export var projectile_max_distance_tiles: float = 0.0
## F-006/C4: the trigger band. A brain may start this attack when the target's distance is
## within [trigger_min_tiles, trigger_max_tiles] (EnemyBrain.pick_attack()).
@export var trigger_min_tiles: float = 0.0
@export var trigger_max_tiles: float = 0.0
## F-006/C7: above 0, a charge stopped by a wall recovers this long instead of `recovery`.
@export var wall_stun_duration: float = 0.0
## F-007/C9: null = none. Its windup starts the instant this attack's recovery ends. Never
## snapshotted: EnemyLogic reads a pattern from the current data by position, never from here.
@export var follow_up: EnemyAttackData = null
## F-008/C3: a volley. Degrees from the locked aim, one projectile per entry, launched in this
## order. Empty = one projectile along the aim. Must be empty for a melee attack.
@export var volley_angles_deg: PackedFloat64Array = PackedFloat64Array()


## F-004/C6: a latched attack lives in snapshots, so it can be rebuilt without its file.
static func from_snapshot(snapshot: Dictionary) -> EnemyAttackData:
	var attack: EnemyAttackData = EnemyAttackData.new()
	for key: String in SNAPSHOT_KEYS + ENEMY_SNAPSHOT_KEYS:
		attack.set(key, snapshot[key])
	# F-008/C3: its own list, never the snapshot's. Packed arrays are shared by reference.
	attack.volley_angles_deg = PackedFloat64Array(snapshot["volley_angles_deg"])
	return attack


## F-004/C8, C12: on top of AttackData.validate(). Data that breaks the telegraph floor is
## rejected, never clamped. Exact minimums pass. Empty result means valid.
func validate_enemy(step_rate: int, tunables: EnemyCombatTunables) -> PackedStringArray:
	var errors: PackedStringArray = validate(step_rate)
	var epsilon: float = CombatTiming.TIME_EPSILON
	if not aim_track_time >= 0.0:
		errors.append("aim_track_time must be >= 0")
	if not windup >= tunables.min_telegraph - epsilon:
		errors.append("windup must be >= min_telegraph (%s)" % tunables.min_telegraph)
	if not windup - aim_track_time >= tunables.min_locked_telegraph - epsilon:
		errors.append(
			(
				"windup - aim_track_time must be >= min_locked_telegraph (%s)"
				% tunables.min_locked_telegraph
			)
		)
	if not lunge_tiles >= 0.0:
		errors.append("lunge_tiles must be >= 0")
	if is_finisher:
		errors.append("is_finisher must be false")
	errors.append_array(_trigger_errors())
	errors.append_array(_wall_stun_errors(step_rate))
	errors.append_array(_projectile_errors(step_rate))
	errors.append_array(_volley_errors(tunables))
	return errors


## F-005/C4: launches a projectile at the windup end instead of opening its own sector.
func is_projectile() -> bool:
	return projectile_speed_tiles > 0.0


## F-006/C7: a melee attack that a wall can stop, and then stuns.
func is_wall_stun() -> bool:
	return not is_projectile() and wall_stun_duration > 0.0


## F-006/C9, C11: a wall-stun attack's recovery lasts at least two combat steps at this rate, so
## the attack is still latched when its last lunge step's report is applied (end_step()). Same
## shape as CombatTiming.window_errors(). Empty for any other attack.
func wall_stun_recovery_errors(step_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not is_wall_stun() or step_rate <= 0:
		return errors
	var min_recovery: float = 2.0 / step_rate
	if recovery < min_recovery - CombatTiming.TIME_EPSILON:
		errors.append(
			"recovery must be >= 2 combat steps (%.4f s) for a wall-stun attack" % min_recovery
		)
	return errors


func to_dict() -> Dictionary:
	var snapshot: Dictionary = super.to_dict()
	for key: String in ENEMY_SNAPSHOT_KEYS:
		snapshot[key] = get(key)
	snapshot["volley_angles_deg"] = volley_angles_deg.duplicate()  # F-008/C3: a copy.
	return snapshot


## F-008/C3, C4: the direction of every projectile this attack launches along `aim`, in list
## order. One, along the aim, for an empty list.
func volley_directions(aim: Vector2) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	if volley_angles_deg.is_empty():
		directions.append(aim)
		return directions
	for angle: float in volley_angles_deg:
		directions.append(aim.rotated(deg_to_rad(angle)))
	return directions


## F-006/C9. Bands of different attacks may overlap: list order decides.
func _trigger_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not trigger_min_tiles >= 0.0:
		errors.append("trigger_min_tiles must be >= 0")
	if not trigger_max_tiles > 0.0:
		errors.append("trigger_max_tiles must be > 0")
	if not trigger_min_tiles <= trigger_max_tiles:
		errors.append("trigger_min_tiles must be <= trigger_max_tiles")
	return errors


## F-006/C9. Rejected, never clamped.
func _wall_stun_errors(step_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not wall_stun_duration >= 0.0:
		errors.append("wall_stun_duration must be >= 0")
	if not wall_stun_duration > 0.0:
		return errors
	if is_projectile():
		errors.append("wall_stun_duration > 0 needs a melee attack, not a projectile")
		return errors
	if not lunge_tiles > 0.0:
		errors.append("wall_stun_duration > 0 needs lunge_tiles > 0")
	errors.append_array(wall_stun_recovery_errors(step_rate))
	if not wall_stun_duration >= recovery - CombatTiming.TIME_EPSILON:
		errors.append("wall_stun_duration must be >= recovery (a wall never shortens the punish)")
	return errors


## F-005/C9. Rejected, never clamped.
func _projectile_errors(step_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not projectile_speed_tiles >= 0.0:
		errors.append("projectile_speed_tiles must be >= 0")
	if not projectile_max_distance_tiles >= 0.0:
		errors.append("projectile_max_distance_tiles must be >= 0")
	if not is_projectile():
		if projectile_max_distance_tiles != 0.0:
			errors.append("projectile_max_distance_tiles must be 0 for a melee attack")
		return errors
	if arc_angle_deg != FULL_CIRCLE_DEG:
		errors.append("arc_angle_deg must be 360 for a projectile attack")
	if lunge_tiles != 0.0:
		errors.append("lunge_tiles must be 0 for a projectile attack")
	if not projectile_max_distance_tiles > 0.0:
		errors.append("projectile_max_distance_tiles must be > 0 for a projectile attack")
	for error: String in ProjectileSet.sampling_errors(
		projectile_speed_tiles, range_tiles, step_rate
	):
		errors.append("projectile %s" % error)
	return errors


## F-008/C7. Rejected, never clamped.
func _volley_errors(tunables: EnemyCombatTunables) -> PackedStringArray:
	var errors: PackedStringArray = []
	if volley_angles_deg.is_empty():
		return errors
	if not is_projectile():
		errors.append("volley_angles_deg must be empty for a melee attack")
		return errors
	if volley_angles_deg.size() > tunables.max_volley_size:
		errors.append(
			(
				"volley_angles_deg has %d entries, more than max_volley_size (%d)"
				% [volley_angles_deg.size(), tunables.max_volley_size]
			)
		)
	for index: int in volley_angles_deg.size():
		var angle: float = volley_angles_deg[index]
		if not (is_finite(angle) and absf(angle) <= HALF_CIRCLE_DEG):
			errors.append("volley_angles_deg[%d] must be finite and within -180..180" % index)
			continue
		for other: int in index:
			if _same_direction(angle, volley_angles_deg[other]):
				errors.append("volley_angles_deg[%d] and [%d] point the same way" % [other, index])
	return errors


## F-008/C7 (c): closer than VOLLEY_ANGLE_EPSILON_DEG modulo 360, so -180 and 180 are one way.
## False for a non-finite angle: that one has its own error.
## Symmetric in a and b (F-008 CR-1): the gap is taken from |a - b|, never from a signed wrap.
static func _same_direction(a: float, b: float) -> bool:
	if not (is_finite(a) and is_finite(b)):
		return false
	var gap: float = fposmod(absf(a - b), FULL_CIRCLE_DEG)
	gap = minf(gap, FULL_CIRCLE_DEG - gap)
	return gap < VOLLEY_ANGLE_EPSILON_DEG - VOLLEY_ANGLE_ROUNDING_DEG
