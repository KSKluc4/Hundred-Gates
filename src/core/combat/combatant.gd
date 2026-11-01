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
	var window: PackedFloat64Array = _running_window()
	if window.is_empty():
		return PackedStringArray()
	return CombatTiming.window_errors(window[0], window[1], step_rate)


## F-003/C15: advances by one step of `duration` seconds.
func step(_duration: float) -> void:
	pass


## F-003/C15: the end of the tick, after its last step.
func finish_tick() -> void:
	pass


## What the last step moved. Named for F-001's API, which it keeps.
func get_tick_displacement_px() -> Vector2:
	return Units.vector_tiles_to_px(_tick_displacement)


func get_position_px() -> Vector2:
	return Units.vector_tiles_to_px(_position)


## F-001/C18: the physics result is authoritative in the scene.
func sync_position(position_px: Vector2) -> void:
	_position = Units.vector_px_to_tiles(position_px)


## F-003/C19: valid only after finish_tick(), with nothing pending.
func to_dict() -> Dictionary:
	return {}


func from_dict(_snapshot: Dictionary) -> void:
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
