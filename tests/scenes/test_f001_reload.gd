extends GutTest
## AC16 end to end in the debug scene, plus the real keyboard path. Works on user:// copies
## of the data files, so a failed test can never damage the real ones.

const SCENE: PackedScene = preload("res://scenes/debug/f001_movement.tscn")
const TEMP_CLASS_PATH: String = "user://test_f001_warrior.tres"
const TEMP_TUNABLES_PATH: String = "user://test_f001_player_combat.tres"
const WARRIOR_PATH: String = "res://data/classes/warrior.tres"

var _player: Player
var _overlay_label: Label
var _tunables_before: PlayerCombatTunables


func before_each() -> void:
	_tunables_before = Tunables.player_combat
	_write_class_data("id", &"warrior")
	_write_tunables("input_buffer_window", Tunables.player_combat.input_buffer_window)


func after_each() -> void:
	Tunables.player_combat = _tunables_before
	DirAccess.remove_absolute(TEMP_CLASS_PATH)
	DirAccess.remove_absolute(TEMP_TUNABLES_PATH)


func test_ac16_valid_reload_during_a_dash_and_i_frames_keeps_state() -> void:
	_spawn()
	var start: Vector2 = _player.global_position
	await _run_ticks(3, Vector2.RIGHT, true, 1)
	assert_eq(_player.motor.get_state(), PlayerMotor.State.DASHING)
	assert_true(_player.motor.is_invulnerable())
	var window: PackedFloat64Array = _player.motor.get_iframe_window()

	_write_class_data("dash_distance", 6.0)
	_press_reload()

	assert_eq(_player.motor.get_state(), PlayerMotor.State.DASHING)
	assert_true(_player.motor.is_invulnerable(), "i-frames survive the reload")
	assert_eq(_player.motor.get_iframe_window(), window)
	assert_string_contains(await _overlay_text(), "reload: ok")
	await _run_ticks(30)
	assert_almost_eq(_player.global_position.x, start.x + 48.0, 0.2, "latched old distance")


func test_ac16_valid_reload_changes_the_next_dash() -> void:
	_spawn()
	_write_class_data("dash_distance", 6.0)
	_press_reload()
	var start: Vector2 = _player.global_position
	await _run_ticks(1, Vector2.LEFT, true, 1)
	await _run_ticks(40)
	assert_almost_eq(_player.global_position.x, start.x - 96.0, 0.2)
	assert_eq(_player.class_data.dash_distance, 6.0)


func test_ac16_reload_during_cooldown_keeps_the_remaining_time() -> void:
	_spawn()
	await _run_ticks(12, Vector2.RIGHT, true, 1)
	var remaining: float = _player.motor.get_cooldown_remaining()
	assert_gt(remaining, 0.0)
	_write_class_data("dash_cooldown", 5.0)
	_press_reload()
	var after: float = _player.motor.get_cooldown_remaining()
	assert_gt(after, 0.0)
	assert_lte(after, remaining, "the new value only applies to the next cooldown")


func test_ac16_reload_keeps_a_buffered_dash() -> void:
	_spawn()
	await _run_ticks(25, Vector2.ZERO, true, 1)
	await _run_ticks(1, Vector2.ZERO, true, 1)
	assert_true(_player.motor.has_buffered_dash(), "pressed during cooldown")
	_write_tunables("stick_deadzone", 0.3)
	_press_reload()
	assert_true(_player.motor.has_buffered_dash())
	assert_eq(Tunables.player_combat.stick_deadzone, 0.3, "the autoload follows the reload")


func test_ac16_invalid_class_is_rejected_and_shown() -> void:
	_spawn()
	_write_class_data("dash_iframe_duration", 0.5)
	_press_reload()
	assert_string_contains(await _overlay_text(), "reload rejected: dash_iframe_duration")
	assert_eq(_player.class_data.dash_iframe_duration, 0.11)


func test_ac16_rejection_during_a_dash_changes_nothing() -> void:
	_spawn()
	var start: Vector2 = _player.global_position
	await _run_ticks(3, Vector2.RIGHT, true, 1)
	var snapshot: Dictionary = _player.motor.to_dict()
	_write_class_data("dash_duration", 0.0)
	_player.input_enabled = false
	var errors: PackedStringArray = _player.reload_data()
	assert_false(errors.is_empty())
	assert_eq_deep(_player.motor.to_dict(), snapshot)
	await _run_ticks(30)
	assert_almost_eq(_player.global_position.x, start.x + 48.0, 0.2)


func test_ac16_reload_is_atomic_across_both_files() -> void:
	_spawn()
	var tunables_before: PlayerCombatTunables = Tunables.player_combat
	_write_class_data("dash_distance", 6.0)
	_write_tunables("stick_deadzone", 1.0)
	_press_reload()
	assert_string_contains(await _overlay_text(), "reload rejected: stick_deadzone")
	assert_eq(_player.class_data.dash_distance, 3.0, "the valid file is not applied either")
	assert_eq(Tunables.player_combat, tunables_before)


func test_ac16_missing_file_is_rejected() -> void:
	_spawn()
	DirAccess.remove_absolute(TEMP_TUNABLES_PATH)
	_press_reload()
	assert_string_contains(await _overlay_text(), "reload rejected: could not load")


func test_real_keys_reach_the_motor() -> void:
	_spawn()
	_player.input_enabled = true
	var start: Vector2 = _player.global_position
	_send_key(KEY_D, true)
	await wait_physics_frames(10)
	assert_gt(_player.global_position.x, start.x, "held D moves right")
	_send_key(KEY_SPACE, true)
	await wait_physics_frames(3)
	assert_eq(_player.motor.get_state(), PlayerMotor.State.DASHING, "Space dashes")
	_send_key(KEY_SPACE, false)
	_send_key(KEY_D, false)
	await wait_physics_frames(30)
	assert_eq(_player.motor.get_state(), PlayerMotor.State.IDLE, "release stops")


func _spawn() -> void:
	var scene: Node = SCENE.instantiate()
	_player = scene.get_node("Player")
	_overlay_label = scene.get_node("MotorDebugOverlay/Label")
	_player.class_data = ResourceLoader.load(TEMP_CLASS_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	_player.tunables_path = TEMP_TUNABLES_PATH
	_player.input_enabled = false
	add_child_autofree(scene)


func _write_class_data(field: String, value: Variant) -> void:
	var data: ClassData = (load(WARRIOR_PATH) as ClassData).duplicate()
	data.set(field, value)
	assert_eq(ResourceSaver.save(data, TEMP_CLASS_PATH), OK)


func _write_tunables(field: String, value: Variant) -> void:
	var tunables: PlayerCombatTunables = _tunables_before.duplicate()
	tunables.set(field, value)
	assert_eq(ResourceSaver.save(tunables, TEMP_TUNABLES_PATH), OK)


## F5 through the real input path. Dispatches now, so no tick passes during a reload.
func _press_reload() -> void:
	_send_key(KEY_F5, true)
	_send_key(KEY_F5, false)
	Input.flush_buffered_events()


## The overlay writes its text on the next process frame.
func _overlay_text() -> String:
	await wait_process_frames(1)
	return _overlay_label.text


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


## One Player tick per iteration. dash_ticks: how many ticks press dash, from the first.
func _run_ticks(
	ticks: int, move: Vector2 = Vector2.ZERO, dash: bool = false, dash_ticks: int = 0
) -> void:
	for index: int in ticks:
		_player.motor.submit(MoveCommand.new(move))
		_player.motor.submit(AimCommand.new(Vector2.ZERO))
		if dash and index < dash_ticks:
			_player.motor.submit(DashCommand.new())
		await get_tree().physics_frame
