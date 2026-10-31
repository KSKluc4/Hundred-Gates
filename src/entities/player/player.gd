class_name Player
extends CharacterBody2D
## Glue between PlayerMotor and Godot physics (F-001 §3). Holds no game logic (G6).

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

var _class_data_path: String
var _tunables: PlayerCombatTunables

@onready var _input: PlayerInput = $PlayerInput
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_class_data_path = class_data.resource_path
	_tunables = Tunables.player_combat
	motor.setup(class_data, _tunables, Units.vector_px_to_tiles(global_position))
	motor.invulnerability_changed.connect(_on_invulnerability_changed)


## F-001/C15: commands, motor tick, then physics. The physics result is authoritative.
func _physics_process(delta: float) -> void:
	if input_enabled:
		var mouse_offset_px: Vector2 = get_global_mouse_position() - global_position
		_input.submit_commands(motor, mouse_offset_px, _tunables.stick_deadzone)
	motor.tick(delta)
	velocity = motor.get_tick_displacement_px() / delta
	move_and_slide()
	motor.sync_position(global_position)
	queue_redraw()


func _draw() -> void:
	var radius: float = (_collision_shape.shape as CircleShape2D).radius
	draw_circle(Vector2.ZERO, radius, body_color)
	var line_end: Vector2 = motor.get_facing() * radius * FACING_LINE_LENGTH_IN_RADII
	draw_line(Vector2.ZERO, line_end, facing_color)


func get_aim_mode() -> PlayerInputMapper.AimMode:
	return _input.get_aim_mode()


## F-001/C17: atomic. Re-reads both files from disk, and applies them only if both are
## valid. Returns the errors, empty when the reload was applied.
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
	if errors.is_empty():
		class_data = new_class_data
		_tunables = new_tunables
		Tunables.player_combat = new_tunables
		motor.apply_data(new_class_data, new_tunables)
	return errors


## F-001/C18: the glue's half of a restore. Sets the body before the next tick.
func restore_snapshot(snapshot: Dictionary) -> void:
	motor.from_dict(snapshot)
	global_position = motor.get_position_px()


func _load_ignoring_cache(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)


func _on_invulnerability_changed(is_invulnerable: bool) -> void:
	modulate = iframe_tint if is_invulnerable else Color.WHITE
