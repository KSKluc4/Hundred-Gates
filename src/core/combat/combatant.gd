# gdlint:disable=max-public-methods
# F-005/C6 adds get_live_hitboxes() to an API that already had 20 public methods.
class_name Combatant
extends RefCounted
## Anything that fights on the shared step grid (D-007). CombatSim only talks to this API.
## Shared behavior lives here, so a rule like "no hitbox in hitstop" exists once.
## Tiles and seconds inside, like PlayerMotor (F-001/C7).

enum Team { PLAYER, ENEMY }

var _combat_id: StringName = &""
var _team: Team = Team.PLAYER
var _position: Vector2 = Vector2.ZERO
# Per-step only: never in a snapshot, like F-001's per-tick values (F-001/C5).
var _tick_displacement: Vector2 = Vector2.ZERO
# One object for life, so listeners stay connected through a reset (F-003/C20).
var _combat: CombatState = CombatState.new()


## F-003/C19: stable, set in the scene.
func get_combat_id() -> StringName:
	return _combat_id


func get_team() -> Team:
	return _team


func get_combat_state() -> CombatState:
	return _combat


## From the next contact instant, so hurtbox_radius_tiles hot-reloads (F-003/C18).
func get_hurtbox() -> Hurtbox:
	return Hurtbox.new(_combat_id, _team, _position, _hurtbox_radius())


## F-003/C15: null unless a hitbox is live at this contact instant. Active time runs on the
## owner's clock, so hitstop must not stretch its reach.
func get_live_hitbox() -> Hitbox:
	if _combat.is_in_hitstop():
		return null
	return _build_live_hitbox()


## F-005/C6 (D-008): every hitbox live at this contact instant, in this owner's order: its own
## sector from get_live_hitbox(), if any, then any others it owns (projectiles). Every hitbox
## reader uses this one.
func get_live_hitboxes() -> Array[Hitbox]:
	var hitboxes: Array[Hitbox] = []
	var own: Hitbox = get_live_hitbox()
	if own != null:
		hitboxes.append(own)
	hitboxes.append_array(_build_extra_hitboxes())
	return hitboxes


## F-003/C16: the recheck on the target, as it is at this moment in the batch.
func can_be_hit() -> bool:
	return not _combat.is_hurt_protected() and not _is_protected()


## F-003/C16: lands the hit on this combatant, in the AC11 order.
func apply_hit(event: HitEvent, tunables: PlayerCombatTunables) -> void:
	_combat.apply_hit(event, tunables)


## AC12: the target's scale. From the next contact instant (F-003/C18).
func get_knockback_scale() -> float:
	return 1.0


## F-003/C18: the rate check, for a running window on its latched values. Empty means it
## still gets a contact at this rate, or that no window is left to lose.
func get_running_window_errors(step_rate: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	var window: PackedFloat64Array = _running_window()
	if not window.is_empty():
		errors.append_array(CombatTiming.window_errors(window[0], window[1], step_rate))
	errors.append_array(_extra_rate_errors(step_rate))
	return errors


## F-004/C4: what a CombatView reports. HP is what every combatant shares.
func is_alive() -> bool:
	return _combat.get_hp() > 0


## F-004/C4: at each step start, before anyone advances. Only enemies have a use for it.
func sense(_view: CombatView) -> void:
	pass


## F-003/C15: advances by one step of `duration` seconds.
func step(_duration: float) -> void:
	pass


## F-003/C15, C17: fires what came due exactly on the last step's end, so that instant's
## contact sees it. Only CombatSim calls this: F-001's tick() keeps its own timeline.
func fire_due_actions() -> void:
	_fire_due_actions()


## F-003/C15: the end of the tick, after its last step.
func finish_tick() -> void:
	pass


## What the last step moved. Named for F-001's API, which it keeps.
func get_tick_displacement_px() -> Vector2:
	return Units.vector_tiles_to_px(_tick_displacement)


func get_position_px() -> Vector2:
	return Units.vector_tiles_to_px(_position)


func get_position_tiles() -> Vector2:
	return _position


## F-001/C18: the physics result is authoritative in the scene.
func sync_position(position_px: Vector2) -> void:
	_position = Units.vector_px_to_tiles(position_px)


## F-003/C19: valid only after finish_tick(), with nothing pending.
func to_dict() -> Dictionary:
	return {}


func from_dict(_snapshot: Dictionary) -> void:
	pass


func _fire_due_actions() -> void:
	pass


func _is_protected() -> bool:
	return false


## [lead, active] of the latched window not yet finished, or empty.
func _running_window() -> PackedFloat64Array:
	return PackedFloat64Array()


func _hurtbox_radius() -> float:
	return 0.0


func _build_live_hitbox() -> Hitbox:
	return null


## F-005/C6: hitboxes after the own sector. Never paused by this owner's hitstop.
func _build_extra_hitboxes() -> Array[Hitbox]:
	return []


## F-005/C11: rate errors for latched values other than the running window.
func _extra_rate_errors(_step_rate: int) -> PackedStringArray:
	return PackedStringArray()
