# gdlint:disable=max-public-methods
# F-005: get_projectiles() is the 21st, for the glue's wall reports and the views.
class_name EnemyLogic
extends Combatant
## Everything every enemy shares (F-004 §3): the attack timeline, cooldown, chase movement,
## aggro, target, hit reaction, death and snapshots. Its brain only says what to do when free.
## Moves one step at a time on the shared grid (D-007), and time inside a step is exact (C5).

signal state_restored

enum State { IDLE, CHASE, WINDUP, ACTIVE, RECOVERY, KNOCKBACK, DEAD }

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
	_clear_attack()
	_clear_intent()
	_projectiles.reset()  # F-005/C4: serials start again from 0.
	_combat.setup(data.max_hp, false)  # F-004/C7: no hurt i-frames for enemies.
	return true


## F-004/C12: replaces data only. A running attack keeps what it latched.
func apply_data(data: EnemyData, enemy_tunables: EnemyCombatTunables, step_rate: int) -> bool:
	if not _accepts(data, enemy_tunables, step_rate):
		return false
	_data = data
	_brain = EnemyBrain.for_data(data)
	_combat.set_max_hp(data.max_hp)
	return true


## F-004/C4. Debug keys act between ticks. A running attack and knockback still finish.
func set_ai_enabled(enabled: bool) -> void:
	_ai_enabled = enabled


func is_ai_enabled() -> bool:
	return _ai_enabled


## F-004/C4: a step start. All of the enemy's reading of the world happens here, from a view
## that is the same for everyone, and the decision then holds for the whole step.
func sense(view: CombatView) -> void:
	_clear_intent()
	# F-005/C4, C5: the step start. Spent and landed projectiles go before this step advances.
	_projectiles.begin_step()
	_tick_displacement = Vector2.ZERO  # A windup of 0 launches here, from where it stands.
	if _data == null:
		return
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
	_projectiles.advance(duration)  # F-005/C4: the sim clock, never this enemy's hitstop.
	var remaining: float = _combat.consume_hitstop(duration)  # F-003/C7, C15: hitstop first.
	while remaining > TIME_EPSILON and _state != State.DEAD:
		var segment: float = minf(remaining, _time_to_next_event())
		_step_time_left = remaining - segment
		_advance(segment)
		remaining -= segment
	_step_time_left = 0.0
	_position += _tick_displacement
	_clear_intent()


## F-004/C7. Everything a hit needs from CombatState runs there. get_knockback_scale() has
## already made a committed enemy's distance 0, so this only has to leave its state alone.
func apply_hit(event: HitEvent, tunables: PlayerCombatTunables) -> void:
	_aggroed = true  # From the next step start (C5).
	if not _is_committed():
		_state = State.KNOCKBACK if event.knockback_tiles > 0.0 else State.IDLE
	_combat.apply_hit(event, tunables)


## F-004/C7: planted while committed. HitEvent reads this at the moment the hit is applied.
func get_knockback_scale() -> float:
	return 0.0 if _is_committed() else _data.knockback_scale


## F-004/C4.
func is_alive() -> bool:
	return super.is_alive() and _state != State.DEAD


func get_state() -> State:
	return _state


func get_data() -> EnemyData:
	return _data


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


## The latched attack, for the telegraph view. Null outside an attack.
func get_running_attack() -> EnemyAttackData:
	return _attack


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
	_combat.from_dict(snapshot["combat"])
	_projectiles.from_dict(snapshot)
	_clear_intent()
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
	return errors


## F-004/C4.
func _is_free() -> bool:
	return (_state == State.IDLE or _state == State.CHASE) and not _combat.is_in_hitstop()


func _is_committed() -> bool:
	return _state == State.WINDUP or _state == State.ACTIVE or _state == State.RECOVERY


func _decide(view: CombatView) -> void:
	var intent: EnemyIntent = _brain.decide(self, view)
	_target_id = intent.target_id
	if not intent.has_target():
		_state = State.IDLE
		return
	_aggroed = true
	if intent.start_attack:
		_start_attack(view)
		return
	_state = State.CHASE
	_move_direction = intent.move_direction
	_move_left = intent.max_move_distance


## F-004/C5: WINDUP begins at this step start, so it aims from this view. With an
## aim_track_time of 0 that's also where it locks.
func _start_attack(view: CombatView) -> void:
	_attack = _data.attack.duplicate()
	_hit_ids = []
	_phase_elapsed = 0.0
	_aim_locked = false
	_state = State.WINDUP
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
	return INF


func _phase_time_left() -> float:
	match _state:
		State.WINDUP:
			return _attack.windup - _phase_elapsed
		State.ACTIVE:
			return _attack.active - _phase_elapsed
		State.RECOVERY:
			return _attack.recovery - _phase_elapsed
	return 0.0


func _advance(segment: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - segment)
	match _state:
		State.IDLE, State.CHASE:
			_advance_move(segment)
		State.KNOCKBACK:
			_advance_knockback(segment)
		State.ACTIVE:
			_tick_displacement += _aim * (_attack.lunge_tiles / _attack.active) * segment
			_advance_phase(segment)
		_:
			_advance_phase(segment)


## F-004/C5: never closer than the intent allows. An enemy that became free mid-step has no
## intent, so it holds still for the rest of that step (C4).
func _advance_move(segment: float) -> void:
	var distance: float = minf(_data.move_speed * segment, _move_left)
	_tick_displacement += _move_direction * distance
	_move_left -= distance


## AC12: the distance is never recalculated, so a wall can't change when knockback ends.
func _advance_knockback(segment: float) -> void:
	_tick_displacement += _combat.get_knockback_velocity() * segment
	_combat.advance_knockback(segment)
	if not _combat.has_knockback():
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
				_finish_attack()


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


## F-004/C5: the punish window is over, and the cooldown starts.
func _finish_attack() -> void:
	_clear_attack()
	_cooldown_remaining = _data.attack_cooldown
	_state = State.IDLE


func _clear_attack() -> void:
	_attack = null
	_phase_elapsed = 0.0
	_aim_locked = false
	_hit_ids = []


func _clear_intent() -> void:
	_move_direction = Vector2.ZERO
	_move_left = 0.0


## F-004/C11: at the contact instant. The hit that killed it may have started a push, which
## a dead enemy never takes. A hit its hitbox found at this contact still lands (F-003/C16).
func _enter_dead() -> void:
	_state = State.DEAD
	_target_id = &""
	_clear_attack()
	_combat.stop_knockback()
	_projectiles.clear()  # F-005/C4: candidates found at this contact still land (F-003/C16).
