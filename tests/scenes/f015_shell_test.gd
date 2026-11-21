# gdlint:disable=max-public-methods
class_name F015ShellTest
extends F012GameTest
## Shared by F-015's shell tests: spawn_shell() runs the real shell.tscn at 120 ticks/s with the
## player's input off and every outside effect stubbed (C12): a settings file of its own under
## `user://test_f015/` (its name carries the process id: two runs of the project at once share the
## folder), a window applier that records its calls and a quit handler that counts them, all set
## before the shell enters the tree. spawn_main_on_title() does the same for the real main scene
## (its `Shell` is wired by the same function), stays on the title screen and keeps the main scene
## for main_scene(). `start_game()` then chooses Start and waits for the input guard, and points
## F012GameTest's `_game` at the shell's game, so session(), player(), town(), floor_scene(),
## enter_floor_through_gate() and the rest work on it.
## The menu panel's choose guard is OFF here (`choose_guard_seconds = 0.0`): the scene tests choose
## by key or pad right after a menu opens, and what they test is the flow, not the guard. The
## guard's real default (0.3 s) is tested where it matters: tests/ui/test_f015_menu_panel.gd and
## tests/scenes/test_f015_clicks.gd, which put it back through `prepare`.
## after_each() puts the settings back, deletes the file, turns the 2D physics space on again (a
## failed test must not freeze the next ones) and lets go of every key and pad button.
##
## Events are real: `Input.parse_input_event` and a flush. Measured in 4.7.2 (key, pad button and
## mouse button, at 60 and 120 ticks/s, F-015 review round 1): an event posted BETWEEN two ticks
## (from a process frame) reads `Input.is_action_just_pressed()` as true in the next tick, whether
## it was a tap (a press and a release posted together) or a hold; one posted INSIDE a tick (from
## `physics_frame`, before the nodes' own step) reads true in the tick after that, never in its
## own. So a tap is as visible to the player's input as a hold; the input guard's tests still hold
## the key, as a person does, so that it also reads as pressed. The `_between_ticks` helpers wait
## for a process frame first, where the OS delivers an event; the others post at once, inside
## whatever tick the test is in.

const SHELL_SCENE_PATH: String = "res://src/world/shell.tscn"
const TEST_DIR: String = "user://test_f015"
## Frames a wait for the input guard may take before the test calls it stuck.
const GUARD_LIMIT_FRAMES: int = 20
## T6: ticks the game may take, after a leave or a death was confirmed, to show the town.
const TOWN_LIMIT_TICKS: int = 12
## T6: where a held click lands: on no entry of any menu.
const CLICK_POSITION: Vector2 = Vector2(1.0, 1.0)

var _shell: Shell
var _settings_file: String = ""
var _file_count: int = 0
var _window_modes: Array[int] = []
var _quit_calls: int = 0
var _held_pad_buttons: Array[JoyButton] = []
var _click_held: bool = false


func before_each() -> void:
	super.before_each()
	_window_modes = []
	_quit_calls = 0
	_held_pad_buttons = []
	_file_count += 1
	var script_name: String = (get_script() as Script).resource_path.get_file().get_basename()
	_settings_file = "%s/%s_%d_%d.cfg" % [TEST_DIR, script_name, OS.get_process_id(), _file_count]
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
	_stub_the_shell(_shell)
	if prepare.is_valid():
		prepare.call(_shell)
	add_child_autofree(_shell)
	await get_tree().physics_frame


## The real scenes/main.tscn on its title screen, as a launch gives it: its `Shell` is given exactly
## what spawn_shell() gives a shell (the settings file, the two stubs, the player's input off), then
## `prepare.call(shell)` may change any of it, all before the main scene enters the tree. It does
## not choose Start: the test is on the title screen. `_shell` is that shell and main_scene() the
## main scene.
func spawn_main_on_title(prepare: Callable = Callable()) -> void:
	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	_shell = _main.get_node(MAIN_SHELL_NODE)
	_stub_the_shell(_shell)
	if prepare.is_valid():
		prepare.call(_shell)
	add_child_autofree(_main)
	await get_tree().physics_frame


## spawn_shell() with a fixture tower and, optionally, the player's input on.
func spawn_shell_on(tower: TowerData, input_enabled: bool = false) -> void:
	var prepare: Callable = func(shell_node: Shell) -> void:
		shell_node.tower_data = tower
		shell_node.player_input_enabled = input_enabled
	await spawn_shell(prepare)


## The one place that keeps a shell off the real settings file and the real window (C12), and its
## menu panel without a choose guard (see the header), for spawn_shell() and spawn_main_on_title().
## The panel node exists once the scene is instantiated, before the shell enters the tree.
func _stub_the_shell(shell_node: Shell) -> void:
	(shell_node.get_node(Shell.MENU_PATH) as MenuPanel).choose_guard_seconds = 0.0
	shell_node.settings_path = _settings_file
	shell_node.window_mode_applier = _record_window_mode
	shell_node.quit_handler = _record_quit
	shell_node.player_input_enabled = false


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
## the physics space is back (one tick after the game, F-015/DEV-6): the game then has run for a
## tick, with no commands, and the test is at the start of the next.
func start_game() -> void:
	choose(ShellMenus.START)
	_game = _shell.get_game()
	assert_not_null(_game, "Start built the game")
	await wait_for_guard()
	await get_tree().physics_frame
	assert_true(space_is_active(), "the physics space is back")


## Waits, one physics tick at a time, until the shell's guard has let the game run; the test is then
## at the start of the first tick the game runs in, which is where run_ticks() expects to be. The
## physics space is still stopped there: it comes back during that tick (F-015/DEV-6).
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


# --- T6: the menus' own steps ---


## Between two ticks: Escape pauses the game and the test checks the pause menu is open.
func pause_with_escape() -> void:
	await tap_key(KEY_ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "Escape paused the game")


## Moves the focus to entry `id` with the Up and Down keys, as a person does, one press each.
func focus_entry_by_keys(id: StringName) -> void:
	var ids: Array[StringName] = panel().get_entry_ids()
	var target: int = ids.find(id)
	assert_gte(target, 0, "the menu has an entry %s" % id)
	for _i: int in ids.size():
		var at: int = ids.find(panel().get_focus_id())
		if at == target:
			break
		await tap_key(KEY_DOWN if at < target else KEY_UP)
	assert_eq(panel().get_focus_id(), id, "the focus is on %s" % id)


## The instance ids of the panel's buttons: they change when the panel is opened again, and only
## then.
func entry_button_ids() -> Array[int]:
	var ids: Array[int] = []
	for node: Node in panel().find_children("*", "Button", true, false):
		ids.append(node.get_instance_id())
	return ids


## Waits, one physics tick at a time, until `condition` holds (at most `limit` ticks), with no
## commands submitted. Returns whether it held.
func tick_until(condition: Callable, limit: int = TOWN_LIMIT_TICKS) -> bool:
	for _i: int in limit:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


## After a leave or a death was confirmed: waits for the guard, then until the game has swapped the
## old floor for the town. The test is then between two ticks of the running game.
func wait_for_town() -> void:
	await wait_for_guard()
	var shown: Callable = func() -> bool: return town() != null and floor_scene() == null
	assert_true(await tick_until(shown), "the town is shown")


## The left mouse button goes down between two ticks and stays down until release_click(): `attack`
## is "just pressed" for the next tick, as for a click on an entry (a positional click cannot reach
## a control under GUT's layer, so the test calls choose() next, in the same frame).
func hold_click_between_ticks() -> void:
	await get_tree().process_frame
	_send_click(true)
	_click_held = true


func release_click() -> void:
	if _click_held:
		_send_click(false)
		_click_held = false


func _send_click(pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = CLICK_POSITION
	event.global_position = CLICK_POSITION
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
