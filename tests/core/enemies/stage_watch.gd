class_name StageWatch
extends SimProbe
## Registered after an enemy, this records it at every step start, right after it sensed
## (F-007 AC2): its stage, state, attack and shift time left, by step index (120 steps/s), and
## every stage_changed it emitted. Far away on the enemy team, like EnemyWatch.

var enemy: EnemyLogic
## By step index: what the enemy was right after that step start's sense().
var at_start: Dictionary = {}
## [stage_index, sim time, cooldown left] per stage_changed.
var changes: Array[Array] = []
var _sim_ref: WeakRef


func _init(watched: EnemyLogic, sim: CombatSim) -> void:
	super(StringName("stage_watch_%s" % watched.get_combat_id()))
	_team = Team.ENEMY
	_position = EnemyWatch.FAR_AWAY
	enemy = watched
	_sim_ref = weakref(sim)
	enemy.stage_changed.connect(_on_stage_changed)


func sense(_view: CombatView) -> void:
	var attack: EnemyAttackData = enemy.get_running_attack()
	at_start[roundi(_sim().get_time() * 120.0)] = {
		"stage": enemy.get_stage_index(),
		"state": enemy.get_state(),
		"attack": attack.id if attack != null else &"",
		"shift_left": enemy.get_stage_shift_left(),
		"in_hitstop": enemy.get_combat_state().is_in_hitstop(),
		"changes": changes.size(),
		"position": enemy.get_position_tiles(),
	}


## The first step index whose start found the enemy in `state`, or -1.
func first_start_in(state: EnemyLogic.State) -> int:
	return _first(func(entry: Dictionary) -> bool: return entry["state"] == state, -1)


## The first step index after `after` whose start found the enemy out of `state`, or -1.
func first_start_not_in(state: EnemyLogic.State, after: int) -> int:
	return _first(func(entry: Dictionary) -> bool: return entry["state"] != state, after)


func _first(matches: Callable, after: int) -> int:
	var steps: Array = at_start.keys()
	steps.sort()
	for step: int in steps:
		if step > after and matches.call(at_start[step]):
			return step
	return -1


func _sim() -> CombatSim:
	return _sim_ref.get_ref() as CombatSim


func _on_stage_changed(stage_index: int) -> void:
	changes.append([stage_index, _sim().get_time(), enemy.get_cooldown_remaining()])
