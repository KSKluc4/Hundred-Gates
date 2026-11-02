class_name CombatBody
extends CharacterBody2D
## A fighter's body in a scene (F-003 T13): glue between one Combatant and Godot physics.
## CombatRunner drives every one of these. Holds no game logic (G6).

## F-003/C19: stable, set in the scene.
@export var combat_id: StringName = &""


func get_combatant() -> Combatant:
	return null


## F-003/C15 step 1: once per tick, before any step.
func submit_commands() -> void:
	pass


## F-003/C20: re-runs setup() from the scene's start position.
func reset_to_start() -> void:
	pass


## F-003/C15 step 2.2. move_and_slide() scales by the physics delta, not the step, so this
## velocity moves the body by exactly one step's displacement.
func move_with_combatant(physics_delta: float) -> void:
	var combatant: Combatant = get_combatant()
	velocity = combatant.get_tick_displacement_px() / physics_delta
	move_and_slide()
	combatant.sync_position(global_position)


## F-001/C18: the glue's half of a restore.
func sync_body_from_logic() -> void:
	global_position = get_combatant().get_position_px()
