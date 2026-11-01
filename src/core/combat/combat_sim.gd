class_name CombatSim
extends RefCounted
## One scene's fight (F-003 §3). Runs every combatant on the shared step grid (D-007) and
## decides hits at the end of each step. One per scene, never a global (C6).

const SNAPSHOT_KEYS: Array[String] = ["step_rate", "time", "order", "combatants"]

var _combatants: Array[Combatant] = []
var _resolver: HitResolver = HitResolver.new()
var _step_rate: int = 0
var _tunables: PlayerCombatTunables
var _time: float = 0.0


## The sim stores its own rate: only a checked reload may change it (F-003/C18).
func setup(step_rate: int, tunables: PlayerCombatTunables) -> void:
	_step_rate = step_rate
	_tunables = tunables


## F-003/C19: registration order is what orders every contact.
func register(combatant: Combatant) -> void:
	_combatants.append(combatant)


func get_combatants() -> Array[Combatant]:
	return _combatants


func get_step_rate() -> int:
	return _step_rate


## Seconds of scene time since setup. At a contact, this is the contact instant.
func get_time() -> float:
	return _time


## F-003/C18: new rules apply to the next hit.
func set_tunables(tunables: PlayerCombatTunables) -> void:
	_tunables = tunables


## F-003/C15. Commands were submitted before this call. move_bodies is empty in core tests,
## where the logic's own integration stands.
func tick(delta: float, move_bodies: Callable = Callable()) -> void:
	var steps: int = CombatTiming.step_count(delta, _step_rate)
	var duration: float = delta / steps
	for _i: int in steps:
		for combatant: Combatant in _combatants:
			combatant.step(duration)
		if move_bodies.is_valid():
			move_bodies.call()
		_time += duration
		_apply_contact()
	for combatant: Combatant in _combatants:
		combatant.finish_tick()


## F-003/C18: why this rate can't take over now. Empty means it can. A running window fails
## only if it could lose its contact, so raising the rate always passes.
func rate_change_errors(new_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	for combatant: Combatant in _combatants:
		for error: String in combatant.get_running_window_errors(new_rate):
			errors.append("running hit or pulse on %s: %s" % [combatant.get_combat_id(), error])
	return errors


## From the next tick. The caller has checked rate_change_errors() first (F-003/C18).
func set_step_rate(step_rate: int) -> void:
	_step_rate = step_rate


## F-003/C19: valid only after finish_tick(), with nothing pending.
func to_dict() -> Dictionary:
	var entries: Dictionary = {}
	for combatant: Combatant in _combatants:
		entries[combatant.get_combat_id()] = combatant.to_dict()
	return {
		"step_rate": _step_rate,
		"time": _time,
		"order": _ids(),
		"combatants": entries,
	}


## F-003/C19: refuses other ids, another order or another rate, and then changes nothing.
## The glue then sets each body from its logic position, and views re-sync.
func from_dict(snapshot: Dictionary) -> bool:
	if not snapshot.has_all(SNAPSHOT_KEYS):
		push_error("CombatSim snapshot rejected: missing keys")
		return false
	if snapshot["step_rate"] != _step_rate:
		push_error("CombatSim snapshot rejected: step rate differs")
		return false
	if snapshot["order"] != _ids():
		push_error("CombatSim snapshot rejected: combatants differ")
		return false
	_time = snapshot["time"]
	for combatant: Combatant in _combatants:
		combatant.from_dict(snapshot["combatants"][combatant.get_combat_id()])
	return true


func _ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for combatant: Combatant in _combatants:
		ids.append(combatant.get_combat_id())
	return ids


## F-003/C16: candidates are found once, before any is applied. Only the target is rechecked,
## so hits at one instant trade and registration order never decides an exchange.
func _apply_contact() -> void:
	for candidate: HitCandidate in _resolver.find_candidates(_combatants):
		var target: Combatant = candidate.target
		if not target.can_be_hit():
			continue
		candidate.hitbox.mark_hit(target.get_combat_id())
		var event: HitEvent = HitEvent.from_candidate(candidate, target.get_knockback_scale())
		target.apply_hit(event, _tunables)
		candidate.attacker.get_combat_state().apply_landed(event, _tunables)
