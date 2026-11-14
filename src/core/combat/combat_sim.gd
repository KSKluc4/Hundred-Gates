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


func get_tunables() -> PlayerCombatTunables:
	return _tunables


## F-003/C18: new rules apply to the next hit.
func set_tunables(tunables: PlayerCombatTunables) -> void:
	_tunables = tunables


## F-003/C15. Commands were submitted before this call. move_bodies is empty in core tests,
## where the logic's own integration stands.
func tick(delta: float, move_bodies: Callable = Callable()) -> void:
	var steps: int = CombatTiming.step_count(delta, _step_rate)
	var duration: float = delta / steps
	for _i: int in steps:
		var view: CombatView = CombatView.capture(_combatants)  # F-004/C4: one, for everyone.
		for combatant: Combatant in _combatants:
			combatant.sense(view)
		for combatant: Combatant in _combatants:
			combatant.step(duration)
		_time += duration
		for combatant: Combatant in _combatants:
			combatant.fire_due_actions()  # On the contact's own instant, so it sees them.
		if move_bodies.is_valid():
			move_bodies.call()
		_apply_contact()
		for combatant: Combatant in _combatants:
			combatant.end_step()  # F-006/C7: after this step's contact, in registration order.
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
## F-007/C14: also a state any combatant refuses (restore_errors()), checked for all first.
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
	var errors: PackedStringArray = []
	for combatant: Combatant in _combatants:
		var entry: Dictionary = snapshot["combatants"][combatant.get_combat_id()]
		errors.append_array(combatant.restore_errors(entry))
	if not errors.is_empty():  # F-007/C14: before anything changes.
		push_error("CombatSim snapshot rejected: %s" % ", ".join(errors))
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
## F-005/C6: a single-target hitbox stops at its first landed hit at this contact.
func _apply_contact() -> void:
	var landed: Array[Hitbox] = []
	for candidate: HitCandidate in _resolver.find_candidates(_combatants):
		var hitbox: Hitbox = candidate.hitbox
		var target: Combatant = candidate.target
		if hitbox.single_target and landed.has(hitbox):
			continue
		if not target.can_be_hit():
			continue
		hitbox.mark_hit(target.get_combat_id())
		landed.append(hitbox)
		var event: HitEvent = HitEvent.from_candidate(candidate, target.get_knockback_scale())
		target.apply_hit(event, _tunables)
		var attacker_state: CombatState = candidate.attacker.get_combat_state()
		attacker_state.apply_landed(event, _tunables, hitbox.attacker_hitstop)
