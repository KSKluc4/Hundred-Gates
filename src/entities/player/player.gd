class_name Player
extends CombatBody
## Glue between PlayerMotor and Godot physics (F-001 §3). Holds no game logic (G6).
## Has no tick of its own: CombatRunner steps it (AC31).

## F-003/C18: the sim must follow a reload that went through this node.
signal data_reloaded(tunables: PlayerCombatTunables)

const DEFAULT_CLASS_DATA_PATH: String = "res://data/classes/warrior.tres"  # G5
const FACING_LINE_LENGTH_IN_RADII: float = 2.0

## D-005: another class is another resource, no code change.
@export var class_data: ClassData = preload(DEFAULT_CLASS_DATA_PATH)
## Off for scripted runs: commands then come from whoever calls motor.submit().
@export var input_enabled: bool = true
@export var body_color: Color = Color(0.85, 0.3, 0.25)
@export var facing_color: Color = Color.WHITE
@export var iframe_tint: Color = Color(0.4, 0.9, 1.0)

var motor: PlayerMotor = PlayerMotor.new()
var tunables_path: String = Tunables.PLAYER_COMBAT_PATH
## F-003/C18: the sim's rate, set by CombatRunner. 0 until a runner has set it.
var combat_step_rate: int = 0

var _class_data_path: String
var _start_position: Vector2
var _tunables: PlayerCombatTunables

@onready var _input: PlayerInput = $PlayerInput
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_class_data_path = class_data.resource_path
	_tunables = Tunables.player_combat
	_start_position = global_position
	_setup_motor()
	motor.invulnerability_changed.connect(_on_invulnerability_changed)
	motor.state_restored.connect(_refresh_from_state)
	_refresh_from_state()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var radius: float = (_collision_shape.shape as CircleShape2D).radius
	draw_circle(Vector2.ZERO, radius, body_color)
	var line_end: Vector2 = motor.get_facing() * radius * FACING_LINE_LENGTH_IN_RADII
	draw_line(Vector2.ZERO, line_end, facing_color)


func get_combatant() -> Combatant:
	return motor


## F-001/C15 step 1. CombatRunner calls this once per tick.
func submit_commands() -> void:
	if input_enabled:
		var mouse_offset_px: Vector2 = get_global_mouse_position() - global_position
		_input.submit_commands(motor, mouse_offset_px, _tunables.stick_deadzone)


func reset_to_start() -> void:
	_setup_motor()
	global_position = _start_position
	_refresh_from_state()


func get_tunables() -> PlayerCombatTunables:
	return _tunables


func get_class_data_path() -> String:
	return _class_data_path


func get_aim_mode() -> PlayerInputMapper.AimMode:
	return _input.get_aim_mode()


## F-001/C17: atomic. Re-reads both files from disk, and applies them only if both are
## valid. Returns the errors, empty when the reload was applied. F-003/C18: F-001's F5 path,
## so it never changes the sim's rate.
func reload_data() -> PackedStringArray:
	var new_class_data: ClassData = _load_ignoring_cache(_class_data_path) as ClassData
	var new_tunables: PlayerCombatTunables = (
		_load_ignoring_cache(tunables_path) as PlayerCombatTunables
	)
	var errors: PackedStringArray = []
	if new_class_data == null:
		errors.append("could not load %s" % _class_data_path)
	else:
		errors.append_array(new_class_data.validate())
	if new_tunables == null:
		errors.append("could not load %s" % tunables_path)
	else:
		errors.append_array(new_tunables.validate())
		errors.append_array(new_tunables.validate_combat())
		if new_class_data != null:
			errors.append_array(new_class_data.validate_combat(new_tunables.combat_step_rate))
		if combat_step_rate != 0 and new_tunables.combat_step_rate != combat_step_rate:
			errors.append("combat_step_rate must stay %d here" % combat_step_rate)
	if errors.is_empty():
		apply_reloaded_data(new_class_data, new_tunables)
	return errors


## F-003/C18: applies data that has already passed every check.
func apply_reloaded_data(new_class_data: ClassData, new_tunables: PlayerCombatTunables) -> void:
	class_data = new_class_data
	_tunables = new_tunables
	Tunables.player_combat = new_tunables
	motor.apply_data(new_class_data, new_tunables)
	data_reloaded.emit(new_tunables)


## F-001/C18: the glue's half of a restore. Sets the body before the next tick.
func restore_snapshot(snapshot: Dictionary) -> void:
	motor.from_dict(snapshot)
	global_position = motor.get_position_px()


func _load_ignoring_cache(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	# DEEP: warrior.tres references the attack files, and a plain IGNORE would take those
	# from the cache, silently ignoring edits to them (F-003 §2).
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)


func _on_invulnerability_changed(_is_invulnerable: bool) -> void:
	_refresh_from_state()


func _setup_motor() -> void:
	var start_tiles: Vector2 = Units.vector_px_to_tiles(_start_position)
	motor.setup(class_data, _tunables, start_tiles, Vector2.DOWN, combat_id)


## F-003/C12: the one place presentation reads motor state, so it can't go stale.
func _refresh_from_state() -> void:
	modulate = iframe_tint if motor.is_invulnerable() else Color.WHITE
