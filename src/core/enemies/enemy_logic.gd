# gdlint:disable=max-public-methods
# F-005: get_projectiles() is the 21st, for the glue's wall reports and the views.
class_name EnemyLogic
extends Combatant
## Everything every enemy shares (F-004 §3): the attack timeline, cooldown, chase movement,
## aggro, target, hit reaction, death and snapshots. Its brain only says what to do when free.
## Moves one step at a time on the shared grid (D-007), and time inside a step is exact (C5).

signal state_restored
## F-007/C7: once per stage entered, after the state changed.
signal stage_changed(stage_index: int)

## F-007/C7: STAGE_SHIFT appended, so saved state ints keep their meaning.
enum State { IDLE, CHASE, WINDUP, ACTIVE, RECOVERY, KNOCKBACK, DEAD, STAGE_SHIFT }

const TIME_EPSILON: float = CombatTiming.TIME_EPSILON
const INITIAL_AIM: Vector2 = Vector2.DOWN
const SNAPSHOT_KEYS: Array[String] = [
	"position",
	"state",
	"phase_elapsed",
	"attack",
	"aim",
	"aim_locked",
	"hit_ids",
	"cooldown_remaining",
	"aggroed",
	"target_id",
	"ai_enabled",
	"combat",
	"projectiles",
	"next_projectile_serial",
	"wall_stopped",
]

var _data: EnemyData = null
var _brain: EnemyBrain = null
var _state: State = State.IDLE
var _ai_enabled: bool = true
var _aggroed: bool = false
var _target_id: StringName = &""
var _aim: Vector2 = INITIAL_AIM
var _aim_locked: bool = false
var _cooldown_remaining: float = 0.0
# F-004/C5: every field latched at windup start, so a reload can't touch a running attack.
var _attack: EnemyAttackData = null
var _phase_elapsed: float = 0.0
# F-003/C8: ids, never references. Replaced, not cleared: a Hitbox from this contact shares it,
# and a trade may still mark it after this enemy died (F-004/C11, F-003/C16).
var _hit_ids: Array[StringName] = []
# Per-step only, set by sense(): never in a snapshot, like _tick_displacement.
var _move_direction: Vector2 = Vector2.ZERO
var _move_left: float = 0.0
# F-005/C4, D-008: this enemy's projectiles, snapshotted with it.
var _projectiles: ProjectileSet = ProjectileSet.new()
# Per-step only: sim time left in the step after the current segment, for a launch inside it.
var _step_time_left: float = 0.0
# F-006/C7: the running wall-stun attack was stopped by a wall, so its recovery is the stun.
var _wall_stopped: bool = false
# F-006/C7, C10: per-step only, never in a snapshot. end_step() clears both before any snapshot
# boundary. The charge's [start, planned_end] for the glue, and a short report not applied yet.
var _charge_segment: PackedVector2Array = PackedVector2Array()
var _stop_pending: bool = false
# F-007/C9: the running pattern, by position in the current data: the index the brain picked
# in the current stage's list, and how many follow-ups from it the running attack is. -1 = none.
var _pattern_root_index: int = -1
var _pattern_depth: int = 0
# F-007/C10: per-step only, never in a snapshot. The view sensed at this step start, for a
# follow-up that starts inside the step.
var _step_view: CombatView = null
# F-007/C5: 0 is EnemyData itself, n is EnemyData.stages[n - 1]. Only goes forward, except on
# the debug reset.
var _stage_index: int = 0
# F-007/C7: the stage shift's time left, on this enemy's clock (hitstop pauses it).
var _stage_shift_left: float = 0.0


func _init() -> void:
	_combat.died.connect(_enter_dead)  # First in line, so every other listener reads DEAD.


## F-004/C15: re-running this is the debug reset. Returns false and changes nothing if the
## data is invalid.
func setup(
	data: EnemyData,
	enemy_tunables: EnemyCombatTunables,
	step_rate: int,
	start_position_tiles: Vector2,
	combat_id: StringName
) -> bool:
	if not _accepts(data, enemy_tunables, step_rate):
		return false
	_data = data
	_brain = EnemyBrain.for_data(data)
	_combat_id = combat_id
	_team = Team.ENEMY
	_position = start_position_tiles
	_tick_displacement = Vector2.ZERO
	_state = State.IDLE
	_ai_enabled = true
	_aggroed = false
	_target_id = &""
	_aim = INITIAL_AIM
	_cooldown_remaining = 0.0
	_stage_index = 0  # F-007/C5: the debug reset is the only way back.
	_stage_shift_left = 0.0
	_clear_attack()
	_clear_intent()
	_clear_charge_report()
	_projectiles.reset()  # F-005/C4: serials start again from 0.
	_combat.setup(data.max_hp, false)  # F-004/C7: no hurt i-frames for enemies.
	return true


## F-004/C12: replaces data only. A running attack keeps what it latched.
func apply_data(data: EnemyData, enemy_tunables: EnemyCombatTunables, step_rate: int) -> bool:
	if not _accepts(data, enemy_tunables, step_rate):
		return false
	var stage_errors: PackedStringArray = reload_errors(data)
	if not stage_errors.is_empty():  # F-007/C19: a guard. CombatRunner refuses it first.
		push_error("EnemyLogic data rejected: %s" % ", ".join(stage_errors))
		return false
	_data = data
	_brain = EnemyBrain.for_data(data)
	_combat.set_max_hp(data.max_hp)
	return true


## F-007/C19: why `candidate` can't replace the data now, empty when it can. A candidate that
## no longer lists the stage this enemy is in is refused: stages never go back (C5), and two
## versions of a boss can't live at once.
func reload_errors(candidate: EnemyData) -> PackedStringArray:
	var errors: PackedStringArray = []
	if candidate != null and _stage_index > candidate.stages.size():
		errors.append(
			(
				"%s: in stage %d, but %s lists only %d stages"
				% [_combat_id, _stage_index, candidate.resource_path, candidate.stages.size()]
			)
		)
	return errors


## F-004/C4. Debug keys act between ticks. A running attack and knockback still finish.
func set_ai_enabled(enabled: bool) -> void:
	_ai_enabled = enabled


func is_ai_enabled() -> bool:
	return _ai_enabled


## F-004/C4: a step start. All of the enemy's reading of the world happens here, from a view
## that is the same for everyone, and the decision then holds for the whole step.
func sense(view: CombatView) -> void:
	_clear_intent()
	_clear_charge_report()
	# F-005/C4, C5: the step start. Spent and landed projectiles go before this step advances.
	_projectiles.begin_step()
	_tick_displacement = Vector2.ZERO  # A windup of 0 launches here, from where it stands.
	_step_view = view
	if _data == null:
		return
	if _is_free():
		_enter_deepest_stage()  # F-007/C6: after the view is sensed, before the brain decides.
	if _is_free():
		if _ai_enabled:
			_decide(view)
		else:
			_state = State.IDLE
			_target_id = &""
	elif _state == State.WINDUP and not _aim_locked:
		_aim_at_target(view)


func step(duration: float) -> void:
	if _data == null:
		return
	_tick_displacement = Vector2.ZERO
	_charge_segment = PackedVector2Array()
	_projectiles.advance(duration)  # F-005/C4: the sim clock, never this enemy's hitstop.
	var remaining: float = _combat.consume_hitstop(duration)  # F-003/C7, C15: hitstop first.
	while remaining > TIME_EPSILON and _state != State.DEAD:
		var segment: float = minf(remaining, _time_to_next_event())
		_step_time_left = remaining - segment
		_advance(segment)
		remaining -= segment
	_step_time_left = 0.0
	var step_start: Vector2 = _position
	_position += _tick_displacement
	_plan_charge_segment(step_start)
	_clear_intent()


## F-006/C7 (D-008): this step's planned charge movement, [start, planned_end] in tiles, for
## the glue to sweep against walls. Empty when no wall-stun lunge moved in this step, or once
## it was reported.
func get_charge_segment() -> PackedVector2Array:
	return _charge_segment


## F-006/C7: the glue's report of where the charge got to this step. Short of the plan by more
## than DISTANCE_EPSILON is a wall stop, but it only takes effect in end_step(), after this
## step's contact: nothing else changes here. With no segment to report on, nothing changes.
func report_charge_reach(reached: Vector2) -> bool:
	if _charge_segment.is_empty():
		push_error("EnemyLogic %s: charge report with no charge segment this step" % _combat_id)
		return false
	var start: Vector2 = _charge_segment[0]
	var planned: Vector2 = _charge_segment[1] - start
	_charge_segment = PackedVector2Array()
	var got: float = (reached - start).dot(planned.normalized())
	if planned.length() - got > Geometry.DISTANCE_EPSILON:
		_stop_pending = true
	return true


## F-006/C7: a pending wall stop becomes the stun here, after the contact that could still hit.
func end_step() -> void:
	if _stop_pending:
		_apply_wall_stop()
	_clear_charge_report()


## F-004/C7. Everything a hit needs from CombatState runs there. get_knockback_scale() has
## already made a committed enemy's distance 0, so this only has to leave its state alone.
func apply_hit(event: HitEvent, tunables: PlayerCombatTunables) -> void:
	_aggroed = true  # From the next step start (C5).
	if not _is_planted():
		_state = State.KNOCKBACK if event.knockback_tiles > 0.0 else State.IDLE
	_combat.apply_hit(event, tunables)


## F-004/C7: planted while committed. HitEvent reads this at the moment the hit is applied.
func get_knockback_scale() -> float:
	return 0.0 if _is_planted() else _data.knockback_scale


## F-004/C4.
func is_alive() -> bool:
	return super.is_alive() and _state != State.DEAD


func get_state() -> State:
	return _state


func get_data() -> EnemyData:
	return _data


## F-007/C4: the attack list of the current stage. Stage 0 is EnemyData's own.
func get_current_attacks() -> Array[EnemyAttackData]:
	var stage: EnemyStageData = _current_stage()
	return stage.attacks if stage != null else _data.attacks


## F-007/C4: walking speed in the current stage.
func get_current_move_speed() -> float:
	var stage: EnemyStageData = _current_stage()
	return stage.move_speed if stage != null else _data.move_speed


## F-007/C4, C8: the cooldown the next finished attack (or pattern) starts.
func get_current_attack_cooldown() -> float:
	var stage: EnemyStageData = _current_stage()
	return stage.attack_cooldown if stage != null else _data.attack_cooldown


## F-007/C5: 0 until the first stage is entered.
func get_stage_index() -> int:
	return _stage_index


## F-007/C7: 0 outside a stage shift.
func get_stage_shift_left() -> float:
	return _stage_shift_left


func is_aggroed() -> bool:
	return _aggroed


## F-004/C5: within TIME_EPSILON of 0.
func is_attack_ready() -> bool:
	return _cooldown_remaining <= TIME_EPSILON


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


## Empty when there's no target.
func get_target_id() -> StringName:
	return _target_id


func get_aim() -> Vector2:
	return _aim


func is_aim_locked() -> bool:
	return _aim_locked


## F-006/C7: the running attack's recovery is a wall stun.
func is_wall_stopped() -> bool:
	return _wall_stopped


## The latched attack, for the telegraph view. Null outside an attack.
func get_running_attack() -> EnemyAttackData:
	return _attack


## F-007/C9: the list index the running pattern started from, or -1 outside an attack.
func get_pattern_root_index() -> int:
	return _pattern_root_index


## F-007/C9: 0 for the pattern's first attack, n for its n-th follow-up.
func get_pattern_depth() -> int:
	return _pattern_depth


## F-007/C20: this recovery is a gap, not the punish window. Reads only logic state and the
## current data (C9), so it is right after a reload, a reset or a restore.
func has_pending_follow_up() -> bool:
	if _data == null or _state != State.RECOVERY or _wall_stopped:
		return false
	return _pattern_attack(_pattern_depth + 1) != null


## F-005/C5, C12: the glue reports walls to it, and the views draw it. Nothing else changes it.
func get_projectiles() -> ProjectileSet:
	return _projectiles


## F-004/C6: valid at the snapshot boundary, F-003/C19. The state holds the attack phase and
## "dead", and _phase_elapsed the lunge's progress: it runs at constant speed on that clock.
func to_dict() -> Dictionary:
	var snapshot: Dictionary = {
		"position": _position,
		"state": _state,
		"phase_elapsed": _phase_elapsed,
		"attack": _attack.to_dict() if _attack != null else {},
		"aim": _aim,
		"aim_locked": _aim_locked,
		"hit_ids": _hit_ids.duplicate(),
		"cooldown_remaining": _cooldown_remaining,
		"aggroed": _aggroed,
		"target_id": _target_id,
		"ai_enabled": _ai_enabled,
		"combat": _combat.to_dict(),
		"wall_stopped": _wall_stopped,
	}
	snapshot.merge(_projectiles.to_dict())  # F-005/C10.
	return snapshot


func from_dict(snapshot: Dictionary) -> void:
	if not snapshot.has_all(SNAPSHOT_KEYS):
		push_error("EnemyLogic snapshot rejected: missing keys")
		return
	_position = snapshot["position"]
	_state = snapshot["state"]
	_phase_elapsed = snapshot["phase_elapsed"]
	var attack: Dictionary = snapshot["attack"]
	_attack = null if attack.is_empty() else EnemyAttackData.from_snapshot(attack)
	_aim = snapshot["aim"]
	_aim_locked = snapshot["aim_locked"]
	_hit_ids = []
	_hit_ids.assign(snapshot["hit_ids"])
	_cooldown_remaining = snapshot["cooldown_remaining"]
	_aggroed = snapshot["aggroed"]
	_target_id = snapshot["target_id"]
	_ai_enabled = snapshot["ai_enabled"]
	_wall_stopped = snapshot["wall_stopped"]
	_combat.from_dict(snapshot["combat"])
	_projectiles.from_dict(snapshot)
	_clear_intent()
	_clear_charge_report()
	state_restored.emit()


func _accepts(data: EnemyData, enemy_tunables: EnemyCombatTunables, step_rate: int) -> bool:
	if data == null or enemy_tunables == null:
		push_error("EnemyLogic data rejected: missing resource")
		return false
	var errors: PackedStringArray = enemy_tunables.validate()
	errors.append_array(data.validate(step_rate, enemy_tunables))
	if not errors.is_empty():
		push_error("EnemyLogic data rejected: %s" % ", ".join(errors))
		return false
	return true


func _is_protected() -> bool:
	return _state == State.DEAD  # F-004/C11: not a hit it can take, ever.


## F-004/C12: while the window can still be lost, like AttackChain's.
func _running_window() -> PackedFloat64Array:
	if _state == State.WINDUP or _state == State.ACTIVE:
		return PackedFloat64Array([_attack.windup, _attack.active])
	return PackedFloat64Array()


func _hurtbox_radius() -> float:
	return _data.hurtbox_radius_tiles if _data != null else 0.0


## F-004/C5: built fresh at every contact, so the sector's origin follows the lunge.
## F-005/C8: a projectile attack's own sector never exists.
func _build_live_hitbox() -> Hitbox:
	if _state != State.ACTIVE or _attack.is_projectile():
		return null
	var hitbox: Hitbox = Hitbox.new()
	hitbox.owner_id = _combat_id
	hitbox.team = _team
	hitbox.origin = _position
	hitbox.direction = _aim
	hitbox.arc_angle_deg = _attack.arc_angle_deg
	hitbox.range_tiles = _attack.range_tiles
	hitbox.damage = _attack.damage
	hitbox.knockback_tiles = _attack.knockback_tiles
	hitbox.hit_ids = _hit_ids
	return hitbox


## F-005/C4, C6: after the own sector, in serial order. Never paused by this enemy's hitstop.
func _build_extra_hitboxes() -> Array[Hitbox]:
	return _projectiles.get_hitboxes(_combat_id, _team)


## F-005/C11: projectiles in flight, and the pending one of a latched attack in WINDUP, must
## keep their sampling limit at the new rate, on their latched speed and radius.
func _extra_rate_errors(step_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = _projectiles.rate_errors(step_rate)
	if _state == State.WINDUP and _attack.is_projectile():
		var speed: float = _attack.projectile_speed_tiles
		for error: String in ProjectileSet.sampling_errors(speed, _attack.range_tiles, step_rate):
			errors.append("pending projectile of %s %s" % [_attack.id, error])
	# F-006/C11: the running charge must still be latched when its last report is applied.
	if (_state == State.WINDUP or _state == State.ACTIVE) and _attack.is_wall_stun():
		for error: String in _attack.wall_stun_recovery_errors(step_rate):
			errors.append("%s %s" % [_attack.id, error])
	return errors


## F-004/C4.
func _is_free() -> bool:
	return (_state == State.IDLE or _state == State.CHASE) and not _combat.is_in_hitstop()


func _is_committed() -> bool:
	return _state == State.WINDUP or _state == State.ACTIVE or _state == State.RECOVERY


## F-004/C7, F-007/C7: never pushed, and a hit doesn't change the state.
func _is_planted() -> bool:
	return _is_committed() or _state == State.STAGE_SHIFT


## F-007/C3: null in stage 0.
func _current_stage() -> EnemyStageData:
	if _data == null or _stage_index == 0:
		return null
	return _data.stages[_stage_index - 1]


## F-007/C5, C6, C7: the deepest stage that holds, skipping any in between. A shift of 0 leaves
## the enemy free, so it decides in this same step with the new values.
func _enter_deepest_stage() -> void:
	var deepest: int = _stage_index
	for index: int in range(_stage_index, _data.stages.size()):
		if _data.stages[index].holds(_combat.get_hp(), _combat.get_max_hp()):
			deepest = index + 1
	if deepest == _stage_index:
		return
	_stage_index = deepest
	var shift: float = _current_stage().shift_duration
	if shift > TIME_EPSILON:
		_state = State.STAGE_SHIFT
		_stage_shift_left = shift
		_clear_intent()
	stage_changed.emit(_stage_index)


func _decide(view: CombatView) -> void:
	var intent: EnemyIntent = _brain.decide(self, view)
	_target_id = intent.target_id
	if not intent.has_target():
		_state = State.IDLE
		return
	_aggroed = true
	if intent.start_attack:
		_start_attack(view, intent.attack_index)
		return
	_state = State.CHASE
	_move_direction = intent.move_direction
	_move_left = intent.max_move_distance


## F-004/C5: WINDUP begins at this step start, so it aims from this view. With an
## aim_track_time of 0 that's also where it locks. F-006/C4: the brain picked which attack.
func _start_attack(view: CombatView, attack_index: int) -> void:
	_pattern_root_index = attack_index  # F-007/C9: the pattern root.
	_pattern_depth = 0
	_latch(get_current_attacks()[attack_index])
	_aim_at_target(view)
	_update_aim_lock()
	_cross_finished_phases()


## F-004/C5: keeps its previous value if the direction is zero.
func _aim_at_target(view: CombatView) -> void:
	var target: CombatView.Entry = view.find(_target_id)
	if target != null and target.position != _position:
		_aim = _position.direction_to(target.position)


## F-004/C5: from aim_track_time on, the aim never changes.
func _update_aim_lock() -> void:
	if _phase_elapsed >= _attack.aim_track_time - TIME_EPSILON:
		_aim_locked = true


## Phase and knockback ends fall at exact times inside a step, and overshoot carries (C5).
func _time_to_next_event() -> float:
	match _state:
		State.WINDUP, State.ACTIVE, State.RECOVERY:
			return _phase_time_left()
		State.KNOCKBACK:
			return _combat.get_knockback_time_left()
		State.STAGE_SHIFT:
			return _stage_shift_left
	return INF


func _phase_time_left() -> float:
	match _state:
		State.WINDUP:
			return _attack.windup - _phase_elapsed
		State.ACTIVE:
			return _attack.active - _phase_elapsed
		State.RECOVERY:
			# F-006/C7: the stun is the recovery, lengthened.
			var recovery: float = _attack.wall_stun_duration if _wall_stopped else _attack.recovery
			return recovery - _phase_elapsed
	return 0.0


func _advance(segment: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - segment)
	match _state:
		State.IDLE, State.CHASE:
			_advance_move(segment)
		State.KNOCKBACK:
			_advance_knockback(segment)
		State.STAGE_SHIFT:
			_advance_stage_shift(segment)
		State.ACTIVE:
			_tick_displacement += _aim * (_attack.lunge_tiles / _attack.active) * segment
			_advance_phase(segment)
		_:
			_advance_phase(segment)


## F-004/C5: never closer than the intent allows. An enemy that became free mid-step has no
## intent, so it holds still for the rest of that step (C4).
func _advance_move(segment: float) -> void:
	var distance: float = minf(get_current_move_speed() * segment, _move_left)
	_tick_displacement += _move_direction * distance
	_move_left -= distance


## AC12: the distance is never recalculated, so a wall can't change when knockback ends.
func _advance_knockback(segment: float) -> void:
	_tick_displacement += _combat.get_knockback_velocity() * segment
	_combat.advance_knockback(segment)
	if not _combat.has_knockback():
		_state = State.IDLE


## F-007/C7: planted, no attack, no move. The cooldown keeps counting in _advance() (C8).
func _advance_stage_shift(segment: float) -> void:
	_stage_shift_left -= segment
	if _stage_shift_left <= TIME_EPSILON:
		_stage_shift_left = 0.0
		_state = State.IDLE


func _advance_phase(segment: float) -> void:
	_phase_elapsed += segment
	if _state == State.WINDUP:
		_update_aim_lock()
	_cross_finished_phases()


## F-003/C15: a phase reaching its end crosses now, so the contact at this instant sees the
## new phase. A loop, because windup and recovery may be 0.
func _cross_finished_phases() -> void:
	while _is_committed() and _phase_time_left() <= TIME_EPSILON:
		_phase_elapsed = 0.0
		match _state:
			State.WINDUP:
				_aim_locked = true
				_state = State.ACTIVE
				if _attack.is_projectile():
					_launch_projectile()
			State.ACTIVE:
				_state = State.RECOVERY
			State.RECOVERY:
				_end_recovery()


## F-005/C4, C8: at the exact instant the windup ends, from where the enemy is, along the
## locked aim, with the latched values. It flies the rest of this step on the sim clock.
func _launch_projectile() -> void:
	_projectiles.launch(
		_position + _tick_displacement,
		_aim,
		_attack.projectile_speed_tiles,
		_attack.projectile_max_distance_tiles,
		_attack.range_tiles,
		_attack.damage,
		_attack.knockback_tiles,
		_step_time_left
	)


## F-006/C7: only a latched wall-stun attack whose lunge moved this step has a segment. A
## stopped charge doesn't move again, and a step spent in hitstop doesn't move at all.
func _plan_charge_segment(step_start: Vector2) -> void:
	if _attack == null or not _attack.is_wall_stun() or _wall_stopped:
		return
	if _tick_displacement == Vector2.ZERO:
		return
	_charge_segment = PackedVector2Array([step_start, _position])


## F-006/C7: C9 keeps a wall-stun attack latched until here (recovery >= 2 steps), so only
## these three states can hold a pending stop. Death wins (F-004/C11).
func _apply_wall_stop() -> void:
	match _state:
		State.DEAD:
			pass
		State.ACTIVE:
			_state = State.RECOVERY  # The rest of active is dropped at this contact instant.
			_phase_elapsed = 0.0
			_wall_stopped = true
		State.RECOVERY:
			_wall_stopped = true  # Active ended earlier in this step: keep the time since.
		_:
			push_error(
				(
					"EnemyLogic %s: wall stop pending in state %s"
					% [_combat_id, State.find_key(_state)]
				)
			)


func _clear_charge_report() -> void:
	_charge_segment = PackedVector2Array()
	_stop_pending = false


## F-004/C5: one attack instance (F-007/C11), latched at its windup start. F-007/C9: the copy
## keeps no follow-up, so nothing can read a pattern from a pre-reload resource.
func _latch(attack: EnemyAttackData) -> void:
	_attack = attack.duplicate()
	_attack.follow_up = null
	_hit_ids = []
	_phase_elapsed = 0.0
	_aim_locked = false
	_state = State.WINDUP


## F-007/C9-C12: at the exact instant a recovery ends. If the pattern goes on, the follow-up's
## windup starts now: no free moment, no brain, no cooldown, no trigger band. Its target is
## re-picked from this step's view (C10). A wall stop (C12) or no living player ends it.
func _end_recovery() -> void:
	var next: EnemyAttackData = null if _wall_stopped else _pattern_attack(_pattern_depth + 1)
	var target: CombatView.Entry = null
	if next != null and _step_view != null:
		target = EnemyBrain.nearest_player(_step_view, _position)
	if target == null:
		_finish_attack()
		return
	_pattern_depth += 1
	_target_id = target.combat_id
	_latch(next)
	_aim_at_target(_step_view)
	_update_aim_lock()


## F-007/C9: the pattern's attack at `depth`, from the current data by position: the root
## index in the current list, then `depth` follow-ups. Null when it no longer resolves.
func _pattern_attack(depth: int) -> EnemyAttackData:
	var attacks: Array[EnemyAttackData] = get_current_attacks()
	if _pattern_root_index < 0 or _pattern_root_index >= attacks.size():
		return null
	var attack: EnemyAttackData = attacks[_pattern_root_index]
	for _i: int in depth:
		if attack == null:
			return null
		attack = attack.follow_up
	return attack


## F-004/C5: the punish window is over, and the cooldown starts. F-007/C11: at a pattern's
## last recovery (or wall stun) end.
func _finish_attack() -> void:
	_clear_attack()
	_cooldown_remaining = get_current_attack_cooldown()
	_state = State.IDLE


func _clear_attack() -> void:
	_attack = null
	_phase_elapsed = 0.0
	_aim_locked = false
	_hit_ids = []
	_wall_stopped = false  # F-006/C7: when the attack ends, on reset and on death.
	_pattern_root_index = -1
	_pattern_depth = 0


func _clear_intent() -> void:
	_move_direction = Vector2.ZERO
	_move_left = 0.0


## F-004/C11: at the contact instant. The hit that killed it may have started a push, which
## a dead enemy never takes. A hit its hitbox found at this contact still lands (F-003/C16).
func _enter_dead() -> void:
	_state = State.DEAD
	_target_id = &""
	_stage_shift_left = 0.0
	_clear_attack()
	_combat.stop_knockback()
	_projectiles.clear()  # F-005/C4: candidates found at this contact still land (F-003/C16).
