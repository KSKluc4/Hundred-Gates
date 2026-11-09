class_name BruteWallStub
extends RefCounted
## Stands in for the glue's charge reports (F-006/C7) as a move_bodies callable: a wall whose
## face stops the brute's centre at x = limit, for a charge in +x, when the segment starts with
## y inside `span` (a pillar). Like the glue, it moves the body to where it got to (F-001/C18)
## and reports once per step with a segment.

var brute: EnemyLogic
var limit: float
var span: Vector2 = Vector2(-INF, INF)
## One entry per report: the step end, what was reported, and the brute right after it.
var reports: Array[Dictionary] = []
var _sim_ref: WeakRef


func _init(watched: EnemyLogic, sim: CombatSim, wall_limit: float = INF) -> void:
	brute = watched
	limit = wall_limit
	_sim_ref = weakref(sim)


## The arena keeps it: a Callable alone doesn't keep its object alive.
func install(arena: BruteArena) -> BruteWallStub:
	arena.move_bodies = report
	arena.wall_stub = self
	return self


func report() -> void:
	var segment: PackedVector2Array = brute.get_charge_segment()
	if segment.is_empty():
		return
	var start: Vector2 = segment[0]
	var reached: Vector2 = segment[1]
	if reached.x > limit and start.y >= span.x and start.y <= span.y:
		var fraction: float = 0.0
		if reached.x > start.x:
			fraction = clampf((limit - start.x) / (reached.x - start.x), 0.0, 1.0)
		reached = start + (reached - start) * fraction
		brute.sync_position(Units.vector_tiles_to_px(reached))
	var accepted: bool = brute.report_charge_reach(reached)
	var sim: CombatSim = _sim_ref.get_ref() as CombatSim
	(
		reports
		. append(
			{
				"step": roundi(sim.get_time() * 120.0),
				"start": start,
				"planned": segment[1],
				"reached": reached,
				"accepted": accepted,
				"state": brute.get_state(),
				"wall_stopped": brute.is_wall_stopped(),
				"has_hitbox": brute.get_live_hitbox() != null,
				"segment_after": brute.get_charge_segment(),
			}
		)
	)


## The step index of the first short report, or -1.
func stop_step() -> int:
	for entry: Dictionary in reports:
		if entry["reached"] != entry["planned"]:
			return entry["step"]
	return -1
