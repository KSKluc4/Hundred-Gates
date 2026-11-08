class_name ProjectileSet
extends RefCounted
## One owner's projectiles, in launch order (F-005/C4, D-008). Launches, advances on the sim
## clock, ends, serializes them and builds their hitboxes. Knows nothing about its owner, so a
## player could own one later. Never asks physics: the owner's glue reports walls (C5).
## Tiles and seconds.

const SNAPSHOT_KEYS: Array[String] = ["projectiles", "next_projectile_serial"]
const PROJECTILE_KEYS: Array[String] = [
	"serial",
	"origin",
	"direction",
	"speed",
	"max_distance",
	"radius",
	"damage",
	"knockback_tiles",
	"travelled",
	"position",
	"spent",
	"hit_ids",
]
const FULL_CIRCLE_DEG: float = 360.0


## One projectile. Everything but the per-step fields is latched at launch (C4) and snapshotted.
class Projectile:
	extends RefCounted
	## D-008: identity is the owner's id plus this.
	var serial: int = 0
	var origin: Vector2 = Vector2.ZERO
	var direction: Vector2 = Vector2.ZERO
	var speed: float = 0.0
	var max_distance: float = 0.0
	var radius: float = 0.0
	var damage: int = 0
	var knockback_tiles: float = 0.0
	## Distance from the launch point along the direction.
	var travelled: float = 0.0
	var position: Vector2 = Vector2.ZERO
	## C4: stopped by max distance or a wall. It gets this step's contact, then goes.
	var spent: bool = false
	## C4: its own hit set, shared by reference with its hitbox. Not empty means it landed.
	var hit_ids: Array[StringName] = []
	# C5, per step only: never in a snapshot. Where this step's planned segment starts, and
	# whether it launched during this step (only those may be reported as blocked).
	var step_start: Vector2 = Vector2.ZERO
	var launched_in_step: bool = false

	func has_landed() -> bool:
		return not hit_ids.is_empty()

	## C4: removed before its owner's next step advances.
	func is_finished() -> bool:
		return spent or has_landed()

	func to_dict() -> Dictionary:
		var snapshot: Dictionary = {}
		for key: String in PROJECTILE_KEYS:
			snapshot[key] = get(key)
		snapshot["hit_ids"] = hit_ids.duplicate()
		return snapshot

	static func from_dict(snapshot: Dictionary) -> Projectile:
		var projectile: Projectile = Projectile.new()
		for key: String in PROJECTILE_KEYS:
			if key != "hit_ids":
				projectile.set(key, snapshot[key])
		projectile.hit_ids.assign(snapshot["hit_ids"])
		projectile.step_start = projectile.position
		return projectile


var _projectiles: Array[Projectile] = []
var _next_serial: int = 0


## F-005/C9, C11: a projectile moves at most its own radius per combat step. A sampling limit
## for contact instants (D-007), not a swept-hit guarantee. Empty result means it holds.
static func sampling_errors(speed: float, radius: float, step_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	if step_rate <= 0:
		errors.append("step rate must be > 0")
	elif not speed / step_rate <= radius + Geometry.DISTANCE_EPSILON:
		errors.append(
			(
				"moves %s tiles per combat step at %d steps/s, more than its radius %s"
				% [speed / step_rate, step_rate, radius]
			)
		)
	return errors


## C4: setup() starts serials again from 0.
func reset() -> void:
	clear()
	_next_serial = 0


## C4: the owner died, or a debug reset. Serials stay used.
func clear() -> void:
	_projectiles = []


## In serial order (C4). Read only: the glue and the views look, logic changes them.
func get_projectiles() -> Array[Projectile]:
	return _projectiles


func get_next_serial() -> int:
	return _next_serial


## C4, C5: at the owner's step start. Removes the finished ones, and starts this step's segments.
func begin_step() -> void:
	var kept: Array[Projectile] = []
	for projectile: Projectile in _projectiles:
		if not projectile.is_finished():
			projectile.step_start = projectile.position
			projectile.launched_in_step = false
			kept.append(projectile)
	_projectiles = kept


## C4: on the sim clock, by the whole step, whatever the owner's hitstop or state.
func advance(duration: float) -> void:
	for projectile: Projectile in _projectiles:
		_fly(projectile, duration)


## C4: appears at `origin` at the launch instant, then flies for `flight_time`: the rest of the
## step after that instant. Returns its serial.
func launch(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	max_distance: float,
	radius: float,
	damage: int,
	knockback_tiles: float,
	flight_time: float
) -> int:
	var projectile: Projectile = Projectile.new()
	projectile.serial = _next_serial
	_next_serial += 1
	projectile.origin = origin
	projectile.direction = direction
	projectile.speed = speed
	projectile.max_distance = max_distance
	projectile.radius = radius
	projectile.damage = damage
	projectile.knockback_tiles = knockback_tiles
	projectile.position = origin
	projectile.step_start = origin
	projectile.launched_in_step = true
	_projectiles.append(projectile)
	_fly(projectile, flight_time)
	return projectile.serial


## C5: the glue swept this step's segment and got to `reached`. Short of the plan by more than
## DISTANCE_EPSILON is a wall stop: the projectile moves there and is spent. False (and an error)
## for a serial it doesn't hold.
func report_position(serial: int, reached: Vector2) -> bool:
	var projectile: Projectile = _find(serial)
	if projectile == null:
		push_error("ProjectileSet: position report for unknown projectile %d" % serial)
		return false
	var planned: float = (projectile.position - projectile.step_start).length()
	var got: float = (reached - projectile.step_start).dot(projectile.direction)
	if planned - got > Geometry.DISTANCE_EPSILON:
		projectile.position = reached
		projectile.travelled = (reached - projectile.origin).dot(projectile.direction)
		projectile.spent = true
	return true


## C5: born overlapping a wall. Removed now, before this step's contact: it never hits. Its
## serial stays used. Only for a projectile launched in this step: otherwise nothing changes,
## and it reports an error.
func report_blocked_launch(serial: int) -> bool:
	var projectile: Projectile = _find(serial)
	if projectile == null or not projectile.launched_in_step:
		push_error("ProjectileSet: blocked launch report for %d, not launched this step" % serial)
		return false
	_projectiles.erase(projectile)
	return true


## C4: a 360-degree circle per projectile, at its position. Pushes along its flight, lands on
## one hurtbox at most, and gives its owner no hitstop (C6).
func get_hitboxes(owner_id: StringName, team: Combatant.Team) -> Array[Hitbox]:
	var hitboxes: Array[Hitbox] = []
	for projectile: Projectile in _projectiles:
		var hitbox: Hitbox = Hitbox.new()
		hitbox.owner_id = owner_id
		hitbox.team = team
		hitbox.origin = projectile.position
		hitbox.direction = projectile.direction
		hitbox.arc_angle_deg = FULL_CIRCLE_DEG
		hitbox.range_tiles = projectile.radius
		hitbox.damage = projectile.damage
		hitbox.knockback_tiles = projectile.knockback_tiles
		hitbox.knockback_from_center = false
		hitbox.single_target = true
		hitbox.attacker_hitstop = false
		hitbox.hit_ids = projectile.hit_ids
		hitboxes.append(hitbox)
	return hitboxes


## C11: every projectile still in flight must keep its sampling limit at `step_rate`.
func rate_errors(step_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	for projectile: Projectile in _projectiles:
		if projectile.is_finished():
			continue
		for error: String in sampling_errors(projectile.speed, projectile.radius, step_rate):
			errors.append("projectile %d in flight %s" % [projectile.serial, error])
	return errors


## C10: valid at the snapshot boundary (F-003/C19).
func to_dict() -> Dictionary:
	var projectiles: Array[Dictionary] = []
	for projectile: Projectile in _projectiles:
		projectiles.append(projectile.to_dict())
	return {"projectiles": projectiles, "next_projectile_serial": _next_serial}


## The caller has checked the keys.
func from_dict(snapshot: Dictionary) -> void:
	_projectiles = []
	for entry: Dictionary in snapshot["projectiles"]:
		_projectiles.append(Projectile.from_dict(entry))
	_next_serial = snapshot["next_projectile_serial"]


## C4: exactly speed x time, and exactly to max distance, where it is spent.
func _fly(projectile: Projectile, time: float) -> void:
	if projectile.spent:
		return
	projectile.travelled += projectile.speed * time
	if projectile.travelled >= projectile.max_distance - Geometry.DISTANCE_EPSILON:
		projectile.travelled = projectile.max_distance
		projectile.spent = true
	projectile.position = projectile.origin + projectile.direction * projectile.travelled


func _find(serial: int) -> Projectile:
	for projectile: Projectile in _projectiles:
		if projectile.serial == serial:
			return projectile
	return null
