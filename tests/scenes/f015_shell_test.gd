# gdlint:disable=max-public-methods
class_name F015ShellTest
extends F012GameTest
## Shared by F-015's shell tests: spawn_shell() runs the real shell.tscn at 120 ticks/s with the
## player's input off and every outside effect stubbed (C12): a settings file of its own under
## `user://test_f015/`, a window applier that records its calls and a quit handler that counts them,
## all set before the shell enters the tree. `start_game()` then chooses Start and waits for the
## input guard, and points F012GameTest's `_game` at the shell's game, so session(), player(),
## town(), floor_scene(), enter_floor_through_gate() and the rest work on it.
## after_each() puts the settings back, deletes the file, turns the 2D physics space on again (a
## failed test must not freeze the next ones) and lets go of every key and pad button.
##
## Events are real: `Input.parse_input_event` and a flush. A tap (press and release at once) is
## never "just pressed" for a tick, so a test that needs a press the player's input can read (the
## input guard) holds the key instead. The `_between_ticks` ones wait for a process frame first,
## where the OS delivers an event; the others post at once, inside whatever tick the test is in.

const SHELL_SCENE_PATH: String = "res://src/world/shell.tscn"
const TEST_DIR: String = "user://test_f015"
## Frames a wait for the input guard may take before the test calls it stuck.
const GUARD_LIMIT_FRAMES: int = 20

var _shell: Shell
var _settings_file: String = ""
var _file_count: int = 0
var _window_modes: Array[int] = []
var _quit_calls: int = 0
var _held_pad_buttons: Array[JoyButton] = []


func before_each() -> void:
	super.before_each()
	_window_modes = []
	_quit_calls = 0
	_held_pad_buttons = []
	_file_count += 1
	var script_name: String = (get_script() as Script).resource_path.get_file().get_basename()
	_settings_file = "%s/%s_%d.cfg" % [TEST_DIR, script_name, _file_count]
	DirAccess.make_dir_recursive_absolute(TEST_DIR)


func after_each() -> void:
	release_held_pads()
	UserSettings.reset_to_defaults()
	if FileAccess.file_exists(_settings_file):
		DirAccess.remove_absolute(_settings_file)
	DirAccess.remove_absolute(TEST_DIR)  # Only succeeds when it is empty: other files may share it.
	activate_physics_space()
	await super.after_each()


## The shell on the title screen. Before it enters the tree: its settings file, the two stubs and
## the player's input (off) are set, then `prepare.call(shell)` may change any of them (an empty
## `settings_path`, `tower_data`, `player_input_enabled = true`). The shipped tower is used when
## `prepare` sets none.
func spawn_shell(prepare: Callable = Callable()) -> void:
	_shell = (load(SHELL_SCENE_PATH) as PackedScene).instantiate()
	_shell.settings_path = _settings_file
	_shell.window_mode_applier = _record_window_mode
	_shell.quit_handler = _record_quit
	_shell.player_input_enabled = false
	if prepare.is_valid():
		prepare.call(_shell)
	add_child_autofree(_shell)
	await get_tree().physics_frame


## spawn_shell() with a fixture tower and, optionally, the player's input on.
func spawn_shell_on(tower: TowerData, input_enabled: bool = false) -> void:
	var prepare: Callable = func(shell_node: Shell) -> void:
		shell_node.tower_data = tower
		shell_node.player_input_enabled = input_enabled
	await spawn_shell(prepare)


func shell() -> Shell:
	return _shell


func flow() -> ShellFlow:
	return _shell.get_flow()


func panel() -> MenuPanel:
	return _shell.get_menu()


func choose(id: StringName) -> void:
	panel().choose(id)


## The settings file this test's shell is given (the test may write it before spawning).
func settings_file() -> String:
	return _settings_file


## Every mode the shell's window applier was called with, in order (DisplayServer.WindowMode).
func window_modes() -> Array[int]:
	return _window_modes


func quit_calls() -> int:
	return _quit_calls


## Chooses Start, points `_game` at the shell's game and waits until the input guard let it go and
## the physics space is back (one tick after the game, DEV-1): the game then has run for a tick,
## with no commands, and the test is at the start of the next.
func start_game() -> void:
	choose(ShellMenus.START)
	_game = _shell.get_game()
	assert_not_null(_game, "Start built the game")
	await wait_for_guard()
	await get_tree().physics_frame
	assert_true(space_is_active(), "the physics space is back")


## Waits, one physics tick at a time, until the shell's guard has let the game run; the test is then
## at the start of the first tick the game runs in, which is where run_ticks() expects to be. The
## physics space is still stopped there: it comes back during that tick (DEV-1).
func wait_for_guard() -> void:
	for _i: int in GUARD_LIMIT_FRAMES:
		if not _shell.is_guarding():
			break
		await get_tree().physics_frame
	assert_false(_shell.is_guarding(), "the guard let the game run")


## Whether the 2D physics space of the world the game is in steps.
func space_is_active() -> bool:
	return PhysicsServer2D.space_is_active(get_viewport().world_2d.space)


func activate_physics_space() -> void:
	PhysicsServer2D.space_set_active(get_viewport().world_2d.space, true)


# --- events ---


## A press and a release of a key between two ticks, as a tap. (F012SceneTest.press_key() posts at
## once, inside whatever tick the test is in.)
func tap_key(key: Key) -> void:
	await get_tree().process_frame
	press_key(key)


## A press and a release of a pad button between two ticks.
func tap_pad(button: JoyButton) -> void:
	await get_tree().process_frame
	press_pad(button)


## At once: a press and a release of a pad button.
func press_pad(button: JoyButton) -> void:
	_send_pad(button, true)
	_send_pad(button, false)


## The button stays down until release_pad() or after_each(); the player's input reads it as held.
func hold_pad(button: JoyButton) -> void:
	_send_pad(button, true)
	_held_pad_buttons.append(button)


## F012SceneTest.hold_key_between_ticks(), for a pad button.
func hold_pad_between_ticks(button: JoyButton) -> void:
	await get_tree().process_frame
	hold_pad(button)


func release_pad(button: JoyButton) -> void:
	_send_pad(button, false)
	_held_pad_buttons.erase(button)


func release_held_pads() -> void:
	for button: JoyButton in _held_pad_buttons:
		_send_pad(button, false)
	_held_pad_buttons.clear()


func _send_pad(button: JoyButton, pressed: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _record_window_mode(mode: DisplayServer.WindowMode) -> void:
	_window_modes.append(mode)


func _record_quit() -> void:
	_quit_calls += 1
