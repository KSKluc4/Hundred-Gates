class_name EnemyWatch
extends SimProbe
## Registered last on a sim, this records one enemy from inside. sense() sees what the enemy
## decided at a step start, and the resolver asking for hitboxes marks each contact instant.
## Keeps to itself: far away and on the enemy team, so it never becomes a target or a hit.

const FAR_AWAY: Vector2 = Vector2(10000, 10000)
const STEPS_PER_SECOND: float = 120.0

var enemy: EnemyLogic
## Times each state was entered, by state.
var entered: Dictionary = {}
var aim_lock_times: Array[float] = []
var candidates_seen: int = 0
## One entry per contact, by step count. Assumes the default grid of 120 steps/s.
var contacts: Dictionary = {}

var _last_state: int = -1
var _was_locked: bool = false
var _resolver: HitResolver = HitResolver.new()
var _inside_contact: bool = false
# Weak: the sim holds this watch, and two strong references would never be freed.
var _sim_ref: WeakRef


func _init(watched: EnemyLogic, watched_sim: CombatSim) -> void:
	super(StringName("watch_%s" % watched.get_combat_id()))
	_team = Team.ENEMY
	_position = FAR_AWAY
	enemy = watched
	_sim_ref = weakref(watched_sim)
	_note_changes()


func sense(_view: CombatView) -> void:
	_note_changes()


## The resolver calls this at every contact. Looking for candidates asks again, so the guard
## keeps that second call from recording, or from recursing.
func get_live_hitbox() -> Hitbox:
	if _inside_contact:
		return null
	_inside_contact = true
	_note_changes()
	candidates_seen += _resolver.find_candidates(_sim().get_combatants()).size()
	contacts[roundi(_sim().get_time() * STEPS_PER_SECOND)] = _contact_sample()
	_inside_contact = false
	return null


func times_entered(state: EnemyLogic.State) -> Array:
	return entered.get(state, [])


func at(step_index: int) -> Dictionary:
	return contacts[step_index]


func _sim() -> CombatSim:
	return _sim_ref.get_ref() as CombatSim


func _note_changes() -> void:
	var state: int = enemy.get_state()
	if state != _last_state:
		_last_state = state
		if not entered.has(state):
			entered[state] = []
		entered[state].append(_sim().get_time())
	var locked: bool = enemy.is_aim_locked()
	if locked and not _was_locked:
		aim_lock_times.append(_sim().get_time())
	_was_locked = locked


func _contact_sample() -> Dictionary:
	var hitbox: Hitbox = enemy.get_live_hitbox()
	return {
		"position": enemy.get_position_tiles(),
		"state": enemy.get_state(),
		"aim": enemy.get_aim(),
		"target": enemy.get_target_id(),
		"cooldown": enemy.get_cooldown_remaining(),
		"has_hitbox": hitbox != null,
		"hitbox_direction": hitbox.direction if hitbox != null else Vector2.ZERO,
	}
