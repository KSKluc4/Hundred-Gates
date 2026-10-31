class_name MotorDebugOverlay
extends CanvasLayer
## Live motor state for the F-001 debug scene (G3). F5 reloads the data files (F-001/C17).

const RELOAD_ACTION: StringName = &"debug_reload_tunables"

@export var player: Player

var _last_reload: String = "-"

@onready var _label: Label = $Label


func _process(_delta: float) -> void:
	_label.text = _build_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(RELOAD_ACTION):
		_reload()


func _reload() -> void:
	var errors: PackedStringArray = player.reload_data()
	_last_reload = "ok" if errors.is_empty() else "reload rejected: %s" % ", ".join(errors)


func _build_text() -> String:
	var motor: PlayerMotor = player.motor
	var velocity_tiles: Vector2 = Units.vector_px_to_tiles(player.velocity)
	var lines: PackedStringArray = [
		"state: %s" % PlayerMotor.State.find_key(motor.get_state()),
		"velocity: %.2f tiles/s" % velocity_tiles.length(),
		"facing: (%.2f, %.2f)" % [motor.get_facing().x, motor.get_facing().y],
		"aim mode: %s" % PlayerInputMapper.AimMode.find_key(player.get_aim_mode()),
		"i-frames: %s" % _yes_no(motor.is_invulnerable()),
		"cooldown: %.2f s" % motor.get_cooldown_remaining(),
		"buffered dash: %s" % _yes_no(motor.has_buffered_dash()),
		"ticks/s: %d" % Engine.physics_ticks_per_second,
		"reload: %s" % _last_reload,
	]
	return "\n".join(lines)


func _yes_no(value: bool) -> String:
	return "yes" if value else "no"
