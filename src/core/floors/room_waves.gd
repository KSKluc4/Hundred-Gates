class_name RoomWaves
extends RefCounted
## F-014/C6: the director of a room with reinforcements. It sends the room's reserve enemies in
## to the player, a few at a time, each after a warning at an arrival point, until nobody is
## left to send. CombatSim calls step() once per step. Everything it knows about the enemies it
## reads from them on every call (C9): the only state of its own is what to_dict() holds.

const TIME_EPSILON: float = CombatTiming.TIME_EPSILON
const SNAPSHOT_KEYS: Array[String] = ["started", "next_index", "since_last", "pending"]
const PENDING_KEYS: Array[String] = ["index", "point", "left", "total"]
## F-014/C8: the tiers of choose_point(), best first.
const TIER_NEAR: int = 0
const TIER_IN_BOX: int = 1
const TIER_FAR_ENOUGH: int = 2
const TIER_FARTHEST: int = 3


## F-014/C9: one reinforcement on its way, as the glue draws it.
class Pending:
	extends RefCounted
	## Combat id of the enemy that arrives.
	var enemy_id: StringName = &""
	## Where it arrives, in tiles (an arrival point's centre).
	var point: Vector2 = Vector2.ZERO
	## Seconds of the warning that are left, and its whole length.
	var time_left: float = 0.0
	var total: float = 0.0
	# What the director keeps: the enemy's index in the reserve, the point's in the points.
	var reserve_index: int = 0
	var point_index: int = 0


var _placed: Array[EnemyLogic] = []
var _reserve: Array[EnemyLogic] = []
var _points: Array[Vector2] = []
var _max_engaged: int = 1
var _rules: FloorTunables = null
# The state of a snapshot (C10). Nothing else is stored.
var _started: bool = false
var _next_index: int = 0
var _since_last: float = 0.0
var _pending: Array[Pending] = []


## F-014/C6: the placed enemies and then the reserve in arrival order, the arrival points
## (tile centres, row-major), the resolved max_engaged and the rules. Starts the director over.
func setup(
	placed: Array[EnemyLogic],
	reserve: Array[EnemyLogic],
	arrival_points: Array[Vector2],
	max_engaged: int,
	rules: FloorTunables
) -> void:
	_placed = placed
	_reserve = reserve
	_points = arrival_points
	_max_engaged = max_engaged
	_rules = rules
	_started = false
	_next_index = 0
	_since_last = rules.wave_spawn_interval  # C7 (3): before any arrival the interval has passed.
	_pending = []


## F-014/C7: one step, in the order the rules list. `view` is the one this step's combatants
## sensed from: the players come from it, the room's enemies from their own logic as it is now.
func step(duration: float, view: CombatView) -> void:
	_advance_pending(duration)  # (1)
	# (2) A room with no placed enemy has nobody to wait for: it starts at once (CR-5).
	if not _started and (_placed.is_empty() or _any_aggroed_or_dead()):
		_started = true
	_since_last += duration  # (3)
	_send_while_allowed(view)  # (4), with (3b) in get_released_count()


## F-014/C9: the number of the room's enemies.
func get_kill_target() -> int:
	return _placed.size() + _reserve.size()


## F-014/C9: the room's enemies that are neither alive nor waiting.
func get_kill_count() -> int:
	var count: int = 0
	for enemy: EnemyLogic in _all_enemies():
		if _is_dead(enemy):
			count += 1
	return count


## F-014/C9: the arrivals whose warning is running, for the glue to draw. One whose enemy is no
## longer waiting (a test killed it) is left out at once. Copies: changing one changes nothing.
func get_pending() -> Array[Pending]:
	var list: Array[Pending] = []
	for entry: Pending in _pending:
		if _reserve[entry.reserve_index].is_waiting():
			list.append(_copy_of(entry))
	return list


## F-014/C7 (2): true from the first time any of the room's enemies was aggroed or dead.
func has_started() -> bool:
	return _started


## F-014/C7 (3b): how many reinforcements the placed enemies that are aggroed or dead have
## released so far. The reserve is split as evenly as it goes over the placed enemies, the
## first `reserve mod placed` shares one larger; k placed enemies release the first k shares.
## Computed from the enemies on every call.
func get_released_count() -> int:
	if _placed.is_empty():
		return _reserve.size()  # Nobody to wait for: nothing is held back, and the fight starts at once.
	var woken: int = 0
	for enemy: EnemyLogic in _placed:
		if enemy.is_aggroed() or _is_dead(enemy):
			woken += 1
	var share: int = _reserve.size() / _placed.size()
	var larger: int = _reserve.size() % _placed.size()
	return woken * share + mini(woken, larger)


## F-014/C7 (4): the index in the reserve of the next enemy to send (also how many have been
## started or passed over).
func get_next_index() -> int:
	return _next_index


## F-014/C8: the arrival point to use, or -1 for none. `points` are tile centres in row-major
## order; `taken` flags (non-zero) the ones with a pending arrival on them (empty: none).
## Candidates are the points not taken with no living enemy strictly nearer than
## `wave_spawn_gap_tiles`; a point's distance is to the nearest of `players` (living ones). Among
## candidates at least `wave_min_spawn_distance_tiles` away, inside the arrival box and with a
## walk of at most `wave_max_walk_tiles` the nearest wins; failing that the nearest far enough and
## inside the box; failing that the nearest far enough; failing that the farthest. A later point
## replaces an earlier one only when better by more than Geometry.DISTANCE_EPSILON.
## `walks` (F-014/C8, CR-1) is one walk per point, from that point to its nearest living player
## (NavGrid.walk_distance()); empty means none are known and every walk counts as short.
## Side-effect free, and the same call the director makes.
static func choose_point(
	points: Array[Vector2],
	taken: PackedByteArray,
	players: Array[Vector2],
	enemies: Array[Vector2],
	rules: FloorTunables,
	walks: PackedFloat64Array = PackedFloat64Array()
) -> int:
	if players.is_empty():
		return -1
	var eps: float = Geometry.DISTANCE_EPSILON
	var best: int = -1
	var best_tier: int = TIER_FARTHEST + 1
	var best_distance: float = 0.0
	for index: int in points.size():
		if index < taken.size() and taken[index] != 0:
			continue
		if _has_enemy_nearer_than(points[index], enemies, rules.wave_spawn_gap_tiles):
			continue
		var player: Vector2 = _nearest_of(points[index], players)
		var distance: float = points[index].distance_to(player)
		var walk: float = walks[index] if index < walks.size() else 0.0
		var tier: int = _tier_of(points[index], player, distance, walk, rules)
		if best < 0 or tier < best_tier:
			best = index
			best_tier = tier
			best_distance = distance
		elif tier == best_tier:
			# The first three tiers want the nearest, the last the farthest.
			var gain: float = (
				best_distance - distance if tier < TIER_FARTHEST else distance - best_distance
			)
			if gain > eps:
				best = index
				best_distance = distance
	return best


## F-014/C10. Nothing the enemies already say is in it.
func to_dict() -> Dictionary:
	var pending: Array[Dictionary] = []
	for entry: Pending in _pending:
		(
			pending
			. append(
				{
					"index": entry.reserve_index,
					"point": entry.point,
					"left": entry.time_left,
					"total": entry.total,
				}
			)
		)
	return {
		"started": _started,
		"next_index": _next_index,
		"since_last": _since_last,
		"pending": pending,
	}


## F-014/C10: why this snapshot can't be restored here. Empty means it can. Checked before
## anything changes.
func restore_errors(snapshot: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not snapshot.has_all(SNAPSHOT_KEYS):
		errors.append("waves: snapshot is missing keys")
		return errors
	if typeof(snapshot["started"]) != TYPE_BOOL:
		errors.append("waves: started must be a bool")
	if typeof(snapshot["next_index"]) != TYPE_INT:
		errors.append("waves: next_index must be an int")
	elif snapshot["next_index"] < 0 or snapshot["next_index"] > _reserve.size():
		errors.append(
			"waves: next_index %d is outside 0 to %d" % [snapshot["next_index"], _reserve.size()]
		)
	if not _is_number(snapshot["since_last"]) or not snapshot["since_last"] >= 0.0:
		errors.append("waves: since_last must be a number >= 0")
	if typeof(snapshot["pending"]) != TYPE_ARRAY:
		errors.append("waves: pending must be an array")
		return errors
	var seen: Array[int] = []
	for entry: Variant in snapshot["pending"]:
		errors.append_array(_pending_errors(entry, snapshot, seen))
	if errors.is_empty() and not snapshot["started"]:
		if snapshot["next_index"] > 0 or not snapshot["pending"].is_empty():
			errors.append("waves: arrivals were started but the fight has not")
	return errors


## F-014/C10: refuses what restore_errors() lists, and then changes nothing.
func from_dict(snapshot: Dictionary) -> bool:
	var errors: PackedStringArray = restore_errors(snapshot)
	if not errors.is_empty():
		push_error("RoomWaves snapshot rejected: %s" % ", ".join(errors))
		return false
	_started = snapshot["started"]
	_next_index = snapshot["next_index"]
	_since_last = snapshot["since_last"]
	_pending = []
	for entry: Dictionary in snapshot["pending"]:
		var restored: Pending = Pending.new()
		restored.reserve_index = entry["index"]
		restored.enemy_id = _reserve[restored.reserve_index].get_combat_id()
		restored.point = entry["point"]
		restored.point_index = _points.find(restored.point)
		restored.time_left = entry["left"]
		restored.total = entry["total"]
		_pending.append(restored)
	return true


## C7 (1): the countdowns go down; the ones that ran out arrive; one whose enemy is no longer
## waiting is dropped without a word. Nothing is rechecked at the point.
func _advance_pending(duration: float) -> void:
	var still: Array[Pending] = []
	for entry: Pending in _pending:
		var enemy: EnemyLogic = _reserve[entry.reserve_index]
		if not enemy.is_waiting():
			continue
		entry.time_left -= duration
		if entry.time_left <= TIME_EPSILON:
			enemy.arrive(entry.point)
		else:
			still.append(entry)
	_pending = still


## C7 (4): sends reinforcements for as long as every condition holds.
func _send_while_allowed(view: CombatView) -> void:
	var players: Array[Vector2] = _living_players(view)
	while _started and _next_index < _reserve.size() and _next_index < get_released_count():
		if not _reserve[_next_index].is_waiting():
			_next_index += 1  # Passed over, silently: it uses a slot of its share.
			continue
		if players.is_empty():
			return
		if _count_engaged() + _pending.size() >= _max_engaged:
			return
		if _since_last + TIME_EPSILON < _rules.wave_spawn_interval:
			return
		var taken: PackedByteArray = _taken_flags()
		var enemies: Array[Vector2] = _living_enemy_positions()
		var walks: PackedFloat64Array = _walks_to_players(view.nav, taken, players, enemies)
		var index: int = choose_point(_points, taken, players, enemies, _rules, walks)
		if index < 0:
			return
		var entry: Pending = Pending.new()
		entry.reserve_index = _next_index
		entry.enemy_id = _reserve[_next_index].get_combat_id()
		entry.point_index = index
		entry.point = _points[index]
		entry.time_left = _rules.wave_spawn_warning_duration
		entry.total = _rules.wave_spawn_warning_duration
		_pending.append(entry)
		_next_index += 1
		_since_last = 0.0


## F-014/C6, C8 (CR-1): one walk per candidate point, from the point to its nearest living player,
## by the room's nav grid. Empty without a grid. Only the points choose_point() may pick are asked
## (a taken point or one with an enemy on it gets 0 and is never read).
func _walks_to_players(
	nav: NavGrid, taken: PackedByteArray, players: Array[Vector2], enemies: Array[Vector2]
) -> PackedFloat64Array:
	var walks: PackedFloat64Array = PackedFloat64Array()
	if nav == null:
		return walks
	walks.resize(_points.size())
	for index: int in _points.size():
		if taken[index] != 0:
			continue
		if _has_enemy_nearer_than(_points[index], enemies, _rules.wave_spawn_gap_tiles):
			continue
		walks[index] = nav.walk_distance(_points[index], _nearest_of(_points[index], players))
	return walks


func _all_enemies() -> Array[EnemyLogic]:
	var all: Array[EnemyLogic] = []
	all.append_array(_placed)
	all.append_array(_reserve)
	return all


## Dead is not alive and not waiting: a waiting enemy is not alive either.
func _is_dead(enemy: EnemyLogic) -> bool:
	return not enemy.is_alive() and not enemy.is_waiting()


func _any_aggroed_or_dead() -> bool:
	for enemy: EnemyLogic in _all_enemies():
		if enemy.is_aggroed() or _is_dead(enemy):
			return true
	return false


## Alive and aggroed: on the player, or on its way to them.
func _count_engaged() -> int:
	var count: int = 0
	for enemy: EnemyLogic in _all_enemies():
		if enemy.is_alive() and enemy.is_aggroed():
			count += 1
	return count


func _living_players(view: CombatView) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for entry: CombatView.Entry in view.get_entries():
		if entry.team == Combatant.Team.PLAYER and entry.is_alive:
			positions.append(entry.position)
	return positions


func _living_enemy_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for enemy: EnemyLogic in _all_enemies():
		if enemy.is_alive():
			positions.append(enemy.get_position_tiles())
	return positions


func _taken_flags() -> PackedByteArray:
	var taken: PackedByteArray = PackedByteArray()
	taken.resize(_points.size())
	for entry: Pending in _pending:
		taken[entry.point_index] = 1
	return taken


func _copy_of(entry: Pending) -> Pending:
	var copy: Pending = Pending.new()
	copy.enemy_id = entry.enemy_id
	copy.point = entry.point
	copy.time_left = entry.time_left
	copy.total = entry.total
	copy.reserve_index = entry.reserve_index
	copy.point_index = entry.point_index
	return copy


## Why one pending entry of a snapshot can't be restored. `seen` collects the reserve indices.
func _pending_errors(entry: Variant, snapshot: Dictionary, seen: Array[int]) -> PackedStringArray:
	var errors: PackedStringArray = []
	if typeof(entry) != TYPE_DICTIONARY or not entry.has_all(PENDING_KEYS):
		errors.append("waves: a pending arrival is missing keys")
		return errors
	if typeof(entry["index"]) != TYPE_INT:
		errors.append("waves: pending index must be an int")
	elif entry["index"] < 0 or entry["index"] >= _reserve.size():
		errors.append("waves: pending index %d is outside the reserve" % entry["index"])
	elif typeof(snapshot["next_index"]) == TYPE_INT and entry["index"] >= snapshot["next_index"]:
		errors.append("waves: pending index %d was not started" % entry["index"])
	elif seen.has(entry["index"]):
		errors.append("waves: pending index %d is listed twice" % entry["index"])
	else:
		seen.append(entry["index"])
	if typeof(entry["point"]) != TYPE_VECTOR2 or not _points.has(entry["point"]):
		errors.append("waves: a pending arrival is not at an arrival point")
	if not _is_number(entry["total"]) or not entry["total"] >= 0.0:
		errors.append("waves: pending total must be a number >= 0")
	elif (
		not _is_number(entry["left"])
		or not (entry["left"] >= 0.0 and entry["left"] <= entry["total"] + TIME_EPSILON)
	):
		errors.append("waves: pending left must be between 0 and its total")
	return errors


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


static func _has_enemy_nearer_than(point: Vector2, enemies: Array[Vector2], gap: float) -> bool:
	for position: Vector2 in enemies:
		if point.distance_to(position) < gap - Geometry.DISTANCE_EPSILON:
			return true
	return false


## The first of the nearest: an earlier player wins a tie.
static func _nearest_of(point: Vector2, others: Array[Vector2]) -> Vector2:
	var nearest: Vector2 = others[0]
	for other: Vector2 in others:
		if point.distance_to(other) < point.distance_to(nearest) - Geometry.DISTANCE_EPSILON:
			nearest = other
	return nearest


## 0: far enough, inside the arrival box and a short walk; 1: far enough and inside the box;
## 2: far enough; 3: none of them. Boundaries count as inside, within Geometry.DISTANCE_EPSILON,
## so a tick rate can't move them.
static func _tier_of(
	point: Vector2, player: Vector2, distance: float, walk: float, rules: FloorTunables
) -> int:
	var eps: float = Geometry.DISTANCE_EPSILON
	if distance < rules.wave_min_spawn_distance_tiles - eps:
		return TIER_FARTHEST
	var offset: Vector2 = (point - player).abs()
	var inside: bool = (
		offset.x <= rules.wave_arrival_box_tiles.x + eps
		and offset.y <= rules.wave_arrival_box_tiles.y + eps
	)
	if not inside:
		return TIER_FAR_ENOUGH
	return TIER_NEAR if walk <= rules.wave_max_walk_tiles + eps else TIER_IN_BOX
