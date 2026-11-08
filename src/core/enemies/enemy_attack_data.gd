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
]
const FULL_CIRCLE_DEG: float = 360.0

## Seconds of windup during which the aim follows the target (CQ11).
@export var aim_track_time: float = 0.0
## Distance moved along the aim over the active phase.
@export var lunge_tiles: float = 0.0
## F-005/C4: tiles per second. 0 means a melee attack.
@export var projectile_speed_tiles: float = 0.0
## F-005/C4: the projectile stops exactly this far from its launch point. 0 for melee.
@export var projectile_max_distance_tiles: float = 0.0


## F-004/C6: a latched attack lives in snapshots, so it can be rebuilt without its file.
static func from_snapshot(snapshot: Dictionary) -> EnemyAttackData:
	var attack: EnemyAttackData = EnemyAttackData.new()
	for key: String in SNAPSHOT_KEYS + ENEMY_SNAPSHOT_KEYS:
		attack.set(key, snapshot[key])
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
	errors.append_array(_projectile_errors(step_rate))
	return errors


## F-005/C4: launches a projectile at the windup end instead of opening its own sector.
func is_projectile() -> bool:
	return projectile_speed_tiles > 0.0


func to_dict() -> Dictionary:
	var snapshot: Dictionary = super.to_dict()
	for key: String in ENEMY_SNAPSHOT_KEYS:
		snapshot[key] = get(key)
	return snapshot


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
