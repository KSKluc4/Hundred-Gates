class_name MotorDebugOverlay
extends CanvasLayer
## Live logic state for the debug scenes (G3). F5 reloads the data files (F-001/C17). With a
## runner, the keys go through it (F-003/C18, C20). F-001's scene has none, and keeps F5 on
## Player.reload_data().

const RELOAD_ACTION: StringName = &"debug_reload_tunables"
const PULSE_ACTION: StringName = &"debug_pulse_toggle"
const SHAKE_ACTION: StringName = &"debug_shake_toggle"
const RESET_ACTION: StringName = &"debug_reset"

@export var player: Player
@export var runner: CombatRunner

var _last_reload: String = "-"

@onready var _label: Label = $Label


func _process(_delta: float) -> void:
	_label.text = _build_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(RELOAD_ACTION):
		_reload()
	elif runner == null:
		return
	elif event.is_action_pressed(PULSE_ACTION):
		runner.toggle_pulse()
	elif event.is_action_pressed(SHAKE_ACTION):
		runner.toggle_shake()
	elif event.is_action_pressed(RESET_ACTION):
		runner.reset()


func _reload() -> void:
	var errors: PackedStringArray = player.reload_data() if runner == null else runner.reload_data()
	_last_reload = "ok" if errors.is_empty() else "reload rejected: %s" % ", ".join(errors)


func _build_text() -> String:
	var motor: PlayerMotor = player.motor
	var lines: PackedStringArray = [
		"state: %s" % PlayerMotor.State.find_key(motor.get_state()),
		# The body's velocity holds only one step's share of a tick (F-003 §2).
		"velocity: %.2f tiles/s" % motor.get_velocity_tiles().length(),
		"facing: (%.2f, %.2f)" % [motor.get_facing().x, motor.get_facing().y],
		"aim mode: %s" % PlayerInputMapper.AimMode.find_key(player.get_aim_mode()),
		"i-frames: %s" % _yes_no(motor.is_invulnerable()),
		"cooldown: %.2f s" % motor.get_cooldown_remaining(),
		"buffered dash: %s" % _yes_no(motor.has_buffered_dash()),
		"buffered attack: %s" % _yes_no(motor.has_buffered_attack()),
	]
	lines.append_array(_combat_lines(motor))
	lines.append("ticks/s: %d" % Engine.physics_ticks_per_second)
	lines.append("reload: %s" % _last_reload)
	return "\n".join(lines)


func _combat_lines(motor: PlayerMotor) -> PackedStringArray:
	var chain: AttackChain = motor.get_attack_chain()
	var state: CombatState = motor.get_combat_state()
	var phase: AttackChain.Phase = chain.get_phase()
	var lines: PackedStringArray = [
		"player hp: %d / %d" % [state.get_hp(), state.get_max_hp()],
		"chain: next hit %d" % (chain.get_next_index() + 1),
		"phase: %s (%.2f s)" % [AttackChain.Phase.find_key(phase), chain.get_phase_time_left()],
		"chain window: %.2f s" % chain.get_window_remaining(),
		"hitstop: %.2f s" % state.get_hitstop_remaining(),
		"hurt i-frames: %.2f s" % state.get_hurt_iframes_remaining(),
	]
	if runner != null:
		lines.append("shake: %s" % _on_off(runner.is_shake_on()))
		lines.append("pulse: %s" % _on_off(runner.is_pulse_on()))
	return lines


func _yes_no(value: bool) -> String:
	return "yes" if value else "no"


func _on_off(value: bool) -> String:
	return "on" if value else "off"
