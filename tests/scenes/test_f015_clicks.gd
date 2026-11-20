extends F015ShellTest
## F-015 code review, fixes A (C10, AC11): REAL positional clicks on the shell's menus, and the
## pointer guard that a double click needs. A click that chooses an entry opens the next menu, and
## the second click of a double click lands on whatever entry is now under the cursor: "Settings"
## opened a menu whose "Fullscreen" lay where "Settings" was (Fullscreen switched on and saved), and
## the top 3 px of the pause menu's "Quit to title" are the confirm's "Quit to title" (a quit with
## no confirmation, the progress lost).
##
## GUT's own GUI sits on CanvasLayer 128 and swallows every click below it; a control on a layer
## above it gets them (measured in plan review). So each test puts the shell's `MenuLayer` on 129
## and posts `InputEventMouseButton` events at the real position of a button (`get_global_rect()`),
## after a motion event to that point, as a mouse does. Waits for the guard are loops on real time
## (the guard counts real time), never a fixed number of frames. The player's input is off.

const ABOVE_GUT_LAYER: int = 129
const MENU_LAYER_PATH: NodePath = ^"MenuLayer"
const MENU_PATH: NodePath = ^"MenuLayer/Menu"
## How long a wait for the guard may take before a test calls it stuck, in milliseconds.
const GUARD_LIMIT_MSEC: int = 3000
## A guard far longer than any test: for the click that must come during it.
const LONG_GUARD_SECONDS: float = 30.0
## The second click of a double click: Vector2i(frames after the first click, real msec after it);
## the msec is used when it is above 0. 2 to 20 frames is 15 to 120 ms at the test's frame rate.
const DOUBLE_CLICK_GAPS: Array[Vector2i] = [
	Vector2i(2, 0), Vector2i(8, 0), Vector2i(20, 0), Vector2i(0, 100)
]
## Where in "Quit to title" the double click lands: pixels below its top edge. The confirm's own
## "Quit to title" overlaps the top 3 px of it.
const TOP_EDGE_OFFSETS_PX: Array[float] = [0.5, 1.5]
## The death screen's delay for the tests that click it while it is disabled, in seconds.
const DEATH_DELAY_SECONDS: float = 1.2
const DEATH_WAIT_LIMIT_MSEC: int = 6000
## Frames the game gets after a click that must have changed nothing, to be sure it stays so.
const SETTLE_FRAMES: int = 6

# --- a single click ---


func test_a_click_on_start_starts_the_game() -> void:
	await _spawn_title()
	await _wait_guard()
	await _click(_rect_of(ShellMenus.START).get_center())
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_not_null(shell().get_game(), "the game was built")
	assert_false(panel().is_open())


func test_a_click_during_the_guard_does_nothing() -> void:
	var prepare: Callable = func(shell_node: Shell) -> void:
		(shell_node.get_node(MENU_PATH) as MenuPanel).pointer_guard_seconds = LONG_GUARD_SECONDS
	await _spawn_title_with(prepare)
	assert_true(panel().is_pointer_guarded(), "the premise: the title is guarded")
	await _click(_rect_of(ShellMenus.START).get_center())
	assert_eq(flow().get_state(), ShellFlow.State.TITLE, "the click did not reach Start")
	assert_null(shell().get_game())
	assert_true(panel().is_open())


# --- a double click on Settings ---


func test_a_double_click_on_settings_from_the_title_changes_nothing() -> void:
	for gap: Vector2i in DOUBLE_CLICK_GAPS:
		await _spawn_title()
		await _wait_guard()
		var at: Vector2 = _rect_of(ShellMenus.SETTINGS).get_center()
		await _double_click(at, gap)
		_assert_settings_open_and_untouched("title, gap %s" % gap)
		await _drop_shell()


func test_a_double_click_on_settings_from_the_towns_pause_menu_changes_nothing() -> void:
	for gap: Vector2i in DOUBLE_CLICK_GAPS:
		await _spawn_paused(false)
		var at: Vector2 = _rect_of(ShellMenus.SETTINGS).get_center()
		await _double_click(at, gap)
		_assert_settings_open_and_untouched("town pause menu, gap %s" % gap)
		await _drop_shell()


func test_a_double_click_on_settings_from_a_floors_pause_menu_changes_nothing() -> void:
	for gap: Vector2i in DOUBLE_CLICK_GAPS:
		await _spawn_paused(true)
		var at: Vector2 = _rect_of(ShellMenus.SETTINGS).get_center()
		await _double_click(at, gap)
		_assert_settings_open_and_untouched("floor pause menu, gap %s" % gap)
		await _drop_shell()


# --- a double click that would reach the confirm's entry ---


func test_a_double_click_on_the_top_edge_of_quit_to_title_only_opens_the_confirm() -> void:
	for offset: float in TOP_EDGE_OFFSETS_PX:
		for gap: Vector2i in DOUBLE_CLICK_GAPS:
			await _spawn_paused(false)
			var top: Rect2 = _rect_of(ShellMenus.QUIT_TO_TITLE)
			var at: Vector2 = Vector2(top.get_center().x, top.position.y + offset)
			await _double_click(at, gap)
			var where: String = "%.1f px below the top, gap %s" % [offset, gap]
			assert_eq(flow().get_state(), ShellFlow.State.CONFIRM_QUIT, "the confirm, %s" % where)
			await _settle()
			assert_not_null(shell().get_game(), "the game is alive, %s" % where)
			assert_eq(flow().get_state(), ShellFlow.State.CONFIRM_QUIT, "and still asking")
			await _drop_shell()


func test_a_double_click_on_return_to_town_only_opens_the_confirm() -> void:
	for gap: Vector2i in DOUBLE_CLICK_GAPS:
		await _spawn_paused(true)
		var at: Vector2 = _rect_of(ShellMenus.LEAVE).get_center()
		await _double_click(at, gap)
		var where: String = "gap %s" % gap
		assert_eq(flow().get_state(), ShellFlow.State.CONFIRM_LEAVE, "the confirm, %s" % where)
		await _settle()
		assert_eq(session().get_place(), TowerSession.Place.FLOOR, "still on the floor, %s" % where)
		assert_eq(flow().get_state(), ShellFlow.State.CONFIRM_LEAVE, "and still asking")
		await _drop_shell()


# --- the death screen ---


func test_a_click_on_the_disabled_death_entry_does_nothing_and_on_the_enabled_one_returns() -> void:
	set_death_delay(DEATH_DELAY_SECONDS)
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	_raise_menu_layer()
	await start_game()
	await _go_to_floor()
	kill_player()
	assert_true(await tick_until(func() -> bool: return flow().get_state() == ShellFlow.State.DEAD))
	await _wait_guard()
	assert_false(panel().is_entry_enabled(ShellMenus.RETURN), "the premise: still disabled")
	await _click(_rect_of(ShellMenus.RETURN).get_center())
	assert_eq(flow().get_state(), ShellFlow.State.DEAD, "a click on the disabled entry did nothing")
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	var until: int = Time.get_ticks_msec() + DEATH_WAIT_LIMIT_MSEC
	while not panel().is_entry_enabled(ShellMenus.RETURN) and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	assert_true(panel().is_entry_enabled(ShellMenus.RETURN), "the delay passed")
	await _click(_rect_of(ShellMenus.RETURN).get_center())
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "a click on the enabled one returns")
	await wait_for_town()
	assert_eq(session().get_place(), TowerSession.Place.TOWN)


# --- the settings entries, in place ---


## Two clicks on "Fullscreen", the second 150 ms after the first (inside the time a guard started
## again by the first would still hold): both toggle.
func test_two_slow_clicks_on_fullscreen_toggle_twice() -> void:
	await _spawn_title()
	choose(ShellMenus.SETTINGS)
	await _wait_guard()
	var at: Vector2 = _rect_of(ShellMenus.FULLSCREEN).get_center()
	await _click(at)
	assert_true(UserSettings.settings.fullscreen, "the first click switched it on")
	await _wait_msec(150)
	await _click(at)
	assert_false(UserSettings.settings.fullscreen, "the second switched it off again")
	assert_eq(
		window_modes(),
		(
			[
				DisplayServer.WINDOW_MODE_WINDOWED,
				DisplayServer.WINDOW_MODE_FULLSCREEN,
				DisplayServer.WINDOW_MODE_WINDOWED
			]
			as Array[int]
		),
		"the start call, then one per click"
	)
	assert_eq(flow().get_state(), ShellFlow.State.SETTINGS)


# --- helpers ---


func _spawn_title() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	_raise_menu_layer()


## The title with `prepare` run on the shell before it enters the tree.
func _spawn_title_with(prepare: Callable) -> void:
	await spawn_shell(
		func(shell_node: Shell) -> void:
			shell_node.tower_data = TowerFixtures.tower_of(1, 1)
			prepare.call(shell_node)
	)
	_raise_menu_layer()


## The game started, on a floor or in the town, paused with Escape, the pointer guard over.
func _spawn_paused(on_floor: bool) -> void:
	await _spawn_title()
	await start_game()
	if on_floor:
		await _go_to_floor()
	await tap_key(KEY_ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "paused")
	await _wait_guard()


func _go_to_floor() -> void:
	assert_true(session().enter_floor(1, false), "the session went to the floor")
	var shown: Callable = func() -> bool: return floor_scene() != null
	assert_true(await tick_until(shown), "the floor is shown")


func _raise_menu_layer() -> void:
	(shell().get_node(MENU_LAYER_PATH) as CanvasLayer).layer = ABOVE_GUT_LAYER


## Frees the shell and puts everything a next round of the same test needs back as it was.
func _drop_shell() -> void:
	shell().queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	UserSettings.reset_to_defaults()
	window_modes().clear()
	activate_physics_space()
	if FileAccess.file_exists(settings_file()):
		DirAccess.remove_absolute(settings_file())


## Waits, on real time, until the panel's pointer guard is over, and for the frame in which its
## buttons take their places (a rectangle read before it is the old menu's).
func _wait_guard() -> void:
	var until: int = Time.get_ticks_msec() + GUARD_LIMIT_MSEC
	while panel().is_pointer_guarded() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	assert_false(panel().is_pointer_guarded(), "the pointer guard ended")
	await get_tree().process_frame
	await get_tree().process_frame


func _wait_msec(msec: int) -> void:
	var until: int = Time.get_ticks_msec() + msec
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


## A few frames and ticks in which nothing more should happen.
func _settle() -> void:
	for _i: int in SETTLE_FRAMES:
		await get_tree().physics_frame
		await get_tree().process_frame


## The settings menu is up, nothing was switched, the window was not touched again and nothing was
## saved: only the first click of the double click did anything.
func _assert_settings_open_and_untouched(where: String) -> void:
	assert_eq(flow().get_state(), ShellFlow.State.SETTINGS, "the settings menu, %s" % where)
	assert_true(UserSettings.settings.screen_shake_enabled, "shake untouched, %s" % where)
	assert_false(UserSettings.settings.fullscreen, "fullscreen untouched, %s" % where)
	assert_eq(window_modes().size(), 1, "the window applier ran once, at start, %s" % where)
	assert_false(FileAccess.file_exists(settings_file()), "nothing saved, %s" % where)


# --- real mouse events ---


## The rectangle of the live button of entry `id`, in the canvas's coordinates.
func _rect_of(id: StringName) -> Rect2:
	var buttons: Array[Button] = []
	for node: Node in panel().find_children("*", "Button", true, false):
		if not node.is_queued_for_deletion():
			buttons.append(node as Button)
	var index: int = panel().get_entry_ids().find(id)
	assert_gte(index, 0, "the menu has an entry %s" % id)
	assert_eq(buttons.size(), panel().get_entry_ids().size(), "one live button per entry")
	return buttons[index].get_global_rect()


## The pointer moves to `at`, the left button goes down and, a frame later, up.
func _click(at: Vector2) -> void:
	_move_mouse(at)
	await get_tree().process_frame
	_send_mouse(at, true, false)
	await get_tree().process_frame
	_send_mouse(at, false, false)
	await get_tree().process_frame


## Two clicks at `at`; the second press comes `gap.x` frames after the first release, or `gap.y`
## milliseconds of real time after it when that is above 0.
func _double_click(at: Vector2, gap: Vector2i) -> void:
	_move_mouse(at)
	await get_tree().process_frame
	_send_mouse(at, true, false)
	await get_tree().process_frame
	_send_mouse(at, false, false)
	if gap.y > 0:
		await _wait_msec(gap.y)
	else:
		for _i: int in gap.x:
			await get_tree().process_frame
	_send_mouse(at, true, true)
	await get_tree().process_frame
	_send_mouse(at, false, false)
	await get_tree().process_frame


func _move_mouse(at: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_mouse(at: Vector2, pressed: bool, double: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.double_click = double
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
