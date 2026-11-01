class_name AttackData
extends Resource
## One hit of a class's attack chain (D-005). Distances in tiles, times in seconds.

const SNAPSHOT_KEYS: Array[String] = [
	"id",
	"windup",
	"active",
	"recovery",
	"damage",
	"arc_angle_deg",
	"range_tiles",
	"knockback_tiles",
	"is_finisher",
]

@export var id: StringName = &""
@export var windup: float = 0.0
@export var active: float = 0.0
@export var recovery: float = 0.0
@export var damage: int = 0
@export var arc_angle_deg: float = 0.0
@export var range_tiles: float = 0.0
@export var knockback_tiles: float = 0.0
@export var is_finisher: bool = false


## F-003/C5: a latched hit lives in snapshots, so it can be rebuilt without its file.
static func from_dict(snapshot: Dictionary) -> AttackData:
	var attack: AttackData = AttackData.new()
	for key: String in SNAPSHOT_KEYS:
		attack.set(key, snapshot[key])
	return attack


## F-003/C18. Empty result means valid.
func validate(step_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"":
		errors.append("id must not be empty")
	if not windup >= 0.0:
		errors.append("windup must be >= 0")
	errors.append_array(CombatTiming.window_errors(windup, active, step_rate))
	if not recovery >= 0.0:
		errors.append("recovery must be >= 0")
	if not damage >= 1:
		errors.append("damage must be >= 1")
	if not (arc_angle_deg > 0.0 and arc_angle_deg <= 360.0):
		errors.append("arc_angle_deg must be > 0 and <= 360")
	if not range_tiles > 0.0:
		errors.append("range_tiles must be > 0")
	if not knockback_tiles >= 0.0:
		errors.append("knockback_tiles must be >= 0")
	return errors


func to_dict() -> Dictionary:
	var snapshot: Dictionary = {}
	for key: String in SNAPSHOT_KEYS:
		snapshot[key] = get(key)
	return snapshot
