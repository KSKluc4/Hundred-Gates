class_name StepEndProbe
extends SimProbe
## Registered after an enemy, this records it right after its end_step() (F-006/C7): the
## sim calls end_step() in registration order, once per step, after that step's contact.

var enemy: EnemyLogic
## By step index: the enemy's snapshot right after that step.
var after_step: Dictionary = {}
var _sim_ref: WeakRef


func _init(watched: EnemyLogic, sim: CombatSim) -> void:
	super(StringName("end_probe_%s" % watched.get_combat_id()))
	_team = Team.ENEMY
	_position = EnemyWatch.FAR_AWAY
	enemy = watched
	_sim_ref = weakref(sim)


func end_step() -> void:
	var sim: CombatSim = _sim_ref.get_ref() as CombatSim
	var sample: Dictionary = enemy.to_dict()
	sample["segment"] = enemy.get_charge_segment()
	after_step[roundi(sim.get_time() * 120.0)] = sample
