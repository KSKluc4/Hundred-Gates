class_name RoomWallStub
extends RefCounted
## F-009: the four outer walls of a room, standing in for the glue's charge reports (F-006/C7)
## as a move_bodies callable, in any direction. The room spans (0, 0) to `size` in tiles; the
## brute's centre stays its hurtbox radius inside. Like BruteWallStub, it moves the body to
## where it got to and reports once per step with a segment. Projectiles fly through it.

var brute: EnemyLogic
var size: Vector2
## Step indexes (at 120 steps/s) whose report was short: the wall stops.
var stops: Array[int] = []
var _sim_ref: WeakRef


func _init(watched: EnemyLogic, sim: CombatSim, room_size: Vector2) -> void:
	brute = watched
	size = room_size
	_sim_ref = weakref(sim)


## The arena keeps it: a Callable alone doesn't keep its object alive.
func install(arena: BruteArena) -> RoomWallStub:
	arena.move_bodies = report
	arena.wall_stub = self
	return self


func report() -> void:
	var segment: PackedVector2Array = brute.get_charge_segment()
	if segment.is_empty():
		return
	var start: Vector2 = segment[0]
	var planned: Vector2 = segment[1]
	var inset: float = brute.get_data().hurtbox_radius_tiles
	var low: Vector2 = Vector2(inset, inset)
	var high: Vector2 = size - low
	var fraction: float = 1.0
	var travel: Vector2 = planned - start
	for axis: int in 2:
		if planned[axis] > high[axis] and travel[axis] > 0.0:
			fraction = minf(fraction, (high[axis] - start[axis]) / travel[axis])
		elif planned[axis] < low[axis] and travel[axis] < 0.0:
			fraction = minf(fraction, (low[axis] - start[axis]) / travel[axis])
	var reached: Vector2 = planned
	if fraction < 1.0:
		reached = start + travel * clampf(fraction, 0.0, 1.0)
		brute.sync_position(Units.vector_tiles_to_px(reached))
		var sim: CombatSim = _sim_ref.get_ref() as CombatSim
		stops.append(roundi(sim.get_time() * 120.0))
	brute.report_charge_reach(reached)
