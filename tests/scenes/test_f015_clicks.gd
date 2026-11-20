# gdlint:disable=max-public-methods
extends F015ShellTest
## F-015 code review, fixes A (C10, AC11): REAL positional clicks, keys and pad presses on the
## shell's menus, and the choose guard and the double-click rule that a double click needs. A choice
## that opens the next menu leaves an entry of it under the cursor and the focus on one: "Settings"
## opens a menu whose "Fullscreen" lay where "Settings" was (Fullscreen switched on and saved) and
## whose focus is on "Screen shake" (switched off and saved by a second Enter), and the top 3 px of
## the pause menu's "Quit to title" are the confirm's "Quit to title" (a quit with no confirmation,
## the progress lost).
##
## The panel here has its REAL guard (0.3 s): the shared helper turns it off, and
## `_spawn_title_with` puts it back before `prepare` runs.
##
## GUT's own GUI sits on CanvasLayer 128 and swallows every click below it; a control on a layer
## above it gets them (measured in plan review). So each test puts the shell's `MenuLayer` on 129
## and posts `InputEventMouseButton` events at the real position of a button (`get_global_rect()`
## in the canvas, taken to the window by the viewport's final transform), after a motion event to
## that point, as a mouse does. Waits for the guard are loops on real time (the guard counts real
## time), never a fixed number of frames. The player's input is off.
##
## Timing is never taken on trust. A watcher node (`Arrival`) sits in the menu layer in front of the
## panel in the input order and stamps every press and mouse release with the real time and the
## panel's guard at the moment the event ARRIVES. A double-click case is judged only when the second
## press really came inside the guard (a fast one) or really after it (a slow one); when the machine
## was too slow to produce that, the case is run again, up to ATTEMPTS times, and then fails with
## the numbers it measured. It never passes by luck and never fails because a frame was long.
##
## `double_click = true` is set BY HAND on the second press of the flagged cases, as the OS does it:
## the engine never makes that flag itself from events posted with `parse_input_event`.

enum From { TITLE, TOWN_PAUSE, FLOOR_PAUSE }

const ABOVE_GUT_LAYER: int = 129
const MENU_LAYER_PATH: NodePath = ^"MenuLayer"
const MENU_PATH: NodePath = ^"MenuLayer/Menu"
## MenuPanel's own default: the helper sets 0, these tests put it back.
const DEFAULT_CHOOSE_GUARD_SECONDS: float = 0.3
const GUARD_MSEC: int = 300
## How long a wait for the guard may take before a test calls it stuck, in milliseconds.
const GUARD_LIMIT_MSEC: int = 3000
## A guard far longer than any test: for the click or key that must come during it.
const LONG_GUARD_SECONDS: float = 30.0
## How many times a case that did not get its timing is run again before it fails.
const ATTEMPTS: int = 3
## The second click of a fast double click: Vector2i(frames after the first click, real msec after
## it); the msec is used when it is above 0. 2 to 20 frames is 15 to 120 ms at the test's frame
## rate.
const DOUBLE_CLICK_GAPS: Array[Vector2i] = [
	Vector2i(2, 0), Vector2i(8, 0), Vector2i(20, 0), Vector2i(0, 100)
]
## The second press of a slow double click, at least this long after the first, in milliseconds
## (Windows' default double-click time is 500).
const SLOW_GAPS_MSEC: Array[int] = [350, 500]
## The main thread is blocked this long in the frame of the first click, in milliseconds.
const STALL_MSEC: int = 500
## The key or pad press that follows an Enter or an A, in milliseconds.
const KEY_GAP_MSEC: int = 80
## Where in "Quit to title" the double click lands: pixels below its top edge. The confirm's own
## "Quit to title" overlaps the top 3 px of it.
const TOP_EDGE_OFFSETS_PX: Array[float] = [0.5, 1.5]
const CENTER: float = -1.0
## The death screen's delay for the tests that click it while it is disabled, in seconds.
const DEATH_DELAY_SECONDS: float = 1.2
const DEATH_WAIT_LIMIT_MSEC: int = 6000
## Frames the game gets after a click that must have changed nothing, to be sure it stays so.
const SETTLE_FRAMES: int = 6

var _arrival: Arrival

# --- a single click ---


func test_a_click_on_start_starts_the_game() -> void:
	await _spawn_title()
	await _wait_guard()
	await _click(_rect_of(ShellMenus.START).get_center())
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_not_null(shell().get_game(), "the game was built")
	assert_false(panel().is_open())


func test_a_click_during_the_guard_does_nothing() -> void:
	await _spawn_title_with(_guard_of(LONG_GUARD_SECONDS))
	assert_true(panel().is_choose_guarded(), "the premise: the title is guarded")
	await _click(_rect_of(ShellMenus.START).get_center())
	assert_eq(flow().get_state(), ShellFlow.State.TITLE, "the click did not reach Start")
	assert_null(shell().get_game())
	assert_true(panel().is_open())


func test_enter_and_pad_a_during_the_guard_do_nothing() -> void:
	await _spawn_title_with(_guard_of(LONG_GUARD_SECONDS))
	assert_true(panel().is_choose_guarded(), "the premise: the title is guarded")
	await tap_key(KEY_ENTER)
	await tap_pad(JOY_BUTTON_A)
	await _settle()
	assert_eq(flow().get_state(), ShellFlow.State.TITLE, "neither reached Start")
	assert_null(shell().get_game())
	assert_true(panel().is_open())


# --- a fast double click (inside the guard) ---


func test_a_double_click_on_settings_from_the_title_changes_nothing() -> void:
	await _fast_cases_on_settings(From.TITLE, "title")


func test_a_double_click_on_settings_from_the_towns_pause_menu_changes_nothing() -> void:
	await _fast_cases_on_settings(From.TOWN_PAUSE, "town pause menu")


func test_a_double_click_on_settings_from_a_floors_pause_menu_changes_nothing() -> void:
	await _fast_cases_on_settings(From.FLOOR_PAUSE, "floor pause menu")


func test_a_double_click_on_the_top_edge_of_quit_to_title_only_opens_the_confirm() -> void:
	for flagged: bool in [true, false]:
		for offset: float in TOP_EDGE_OFFSETS_PX:
			for gap: Vector2i in DOUBLE_CLICK_GAPS:
				var where: String = (
					"%.1f px below the top, gap %s, flagged %s" % [offset, gap, flagged]
				)
				var gesture: Callable = _double_click_from.bind(
					From.TOWN_PAUSE, ShellMenus.QUIT_TO_TITLE, offset, gap, flagged, false
				)
				if await _produced(gesture, true, 0, where):
					await _assert_confirm_quit_and_alive(where)
					await _drop_shell()


func test_a_double_click_on_return_to_town_only_opens_the_confirm() -> void:
	for flagged: bool in [true, false]:
		for gap: Vector2i in DOUBLE_CLICK_GAPS:
			var where: String = "gap %s, flagged %s" % [gap, flagged]
			var gesture: Callable = _double_click_from.bind(
				From.FLOOR_PAUSE, ShellMenus.LEAVE, CENTER, gap, flagged, false
			)
			if await _produced(gesture, true, 0, where):
				assert_eq(
					flow().get_state(), ShellFlow.State.CONFIRM_LEAVE, "the confirm, %s" % where
				)
				await _settle()
				assert_eq(
					session().get_place(),
					TowerSession.Place.FLOOR,
					"still on the floor, %s" % where
				)
				assert_eq(flow().get_state(), ShellFlow.State.CONFIRM_LEAVE, "and still asking")
				await _drop_shell()


# --- a slow double click (after the guard) ---


## The OS marks the second press of a double click as one for as long as its double-click time
## (500 ms on Windows): the panel consumes it, guard or no guard.
func test_a_slow_flagged_second_click_on_settings_from_the_title_changes_nothing() -> void:
	await _slow_cases_on_settings(From.TITLE, "title", true)


func test_a_slow_flagged_second_click_on_settings_from_the_pause_menu_changes_nothing() -> void:
	await _slow_cases_on_settings(From.TOWN_PAUSE, "town pause menu", true)


func test_a_slow_flagged_second_click_on_the_top_edge_of_quit_to_title_does_not_quit() -> void:
	for slow: int in SLOW_GAPS_MSEC:
		var where: String = "0.5 px below the top, %d ms" % slow
		var gesture: Callable = _double_click_from.bind(
			From.TOWN_PAUSE, ShellMenus.QUIT_TO_TITLE, 0.5, Vector2i(0, slow), true, true
		)
		if await _produced(gesture, false, slow, where):
			await _assert_confirm_quit_and_alive(where)
			await _drop_shell()


## The same second click without the flag is a deliberate click after the guard, and acts.
func test_a_slow_second_click_without_the_flag_on_settings_from_the_title_acts() -> void:
	await _slow_cases_that_act_on_fullscreen(From.TITLE, "title")


func test_a_slow_second_click_without_the_flag_on_settings_from_the_pause_menu_acts() -> void:
	await _slow_cases_that_act_on_fullscreen(From.TOWN_PAUSE, "town pause menu")


func test_a_slow_second_click_without_the_flag_on_quit_to_title_acts_on_the_confirm() -> void:
	for slow: int in SLOW_GAPS_MSEC:
		var where: String = "0.5 px below the top, %d ms" % slow
		var gesture: Callable = _double_click_from.bind(
			From.TOWN_PAUSE, ShellMenus.QUIT_TO_TITLE, 0.5, Vector2i(0, slow), false, true
		)
		if await _produced(gesture, false, slow, where):
			assert_eq(
				flow().get_state(), ShellFlow.State.TITLE, "a deliberate click quit, %s" % where
			)
			assert_null(shell().get_game(), "the game is gone, %s" % where)
			await _drop_shell()


# --- a stalled frame ---


## The main thread is blocked 500 ms in the frame of the first click; the second press was queued
## by then, and the panel's guard (real time) is over when it arrives.
func test_a_stall_after_the_first_click_on_settings_changes_nothing() -> void:
	var where: String = "title, a %d ms stall" % STALL_MSEC
	var gesture: Callable = _stalled_double_click_from.bind(From.TITLE, ShellMenus.SETTINGS, CENTER)
	if await _produced(gesture, false, STALL_MSEC, where):
		_assert_settings_open_and_untouched(where)
		await _drop_shell()


func test_a_stall_after_the_first_click_on_quit_to_title_does_not_quit() -> void:
	var where: String = "town pause menu, 0.5 px below the top, a %d ms stall" % STALL_MSEC
	var gesture: Callable = _stalled_double_click_from.bind(
		From.TOWN_PAUSE, ShellMenus.QUIT_TO_TITLE, 0.5
	)
	if await _produced(gesture, false, STALL_MSEC, where):
		await _assert_confirm_quit_and_alive(where)
		await _drop_shell()


# --- keys and the pad (no pointer at all) ---


func test_down_enter_enter_on_the_title_does_not_switch_screen_shake_off() -> void:
	var where: String = "title, Down, Enter, Enter %d ms apart" % KEY_GAP_MSEC
	if await _produced(_enter_twice_on_the_title, true, 0, where):
		_assert_settings_open_and_untouched(where)
		await _wait_guard()
		press_key(KEY_ENTER)
		await _settle()
		_assert_shake_switched_off_and_saved("a third Enter after the guard")
		await _drop_shell()


func test_pad_a_twice_on_settings_in_the_pause_menu_does_not_switch_screen_shake_off() -> void:
	var where: String = "pause menu, pad A twice %d ms apart" % KEY_GAP_MSEC
	if await _produced(_pad_a_twice_on_the_pause_menu, true, 0, where):
		_assert_settings_open_and_untouched(where)
		await _wait_guard()
		press_pad(JOY_BUTTON_A)
		await _settle()
		_assert_shake_switched_off_and_saved("a third pad A after the guard")
		await _drop_shell()


func test_a_click_on_settings_and_space_80_ms_later_does_not_switch_screen_shake_off() -> void:
	var where: String = "pause menu, a click, Space %d ms later" % KEY_GAP_MSEC
	if await _produced(_click_and_space_on_the_pause_menu, true, 0, where):
		_assert_settings_open_and_untouched(where)
		await _wait_guard()
		press_key(KEY_SPACE)
		await _settle()
		_assert_shake_switched_off_and_saved("a Space after the guard")
		await _drop_shell()


# --- the death screen ---


func test_a_click_on_the_disabled_death_entry_does_nothing_and_on_the_enabled_one_returns() -> void:
	set_death_delay(DEATH_DELAY_SECONDS)
	await _spawn_title_with(Callable())
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
	await _wait_guard()
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


# --- case runners ---


func _fast_cases_on_settings(from: From, name_of_menu: String) -> void:
	for flagged: bool in [true, false]:
		for gap: Vector2i in DOUBLE_CLICK_GAPS:
			var where: String = "%s, gap %s, flagged %s" % [name_of_menu, gap, flagged]
			var gesture: Callable = _double_click_from.bind(
				from, ShellMenus.SETTINGS, CENTER, gap, flagged, false
			)
			if await _produced(gesture, true, 0, where):
				_assert_settings_open_and_untouched(where)
				await _drop_shell()


func _slow_cases_on_settings(from: From, name_of_menu: String, flagged: bool) -> void:
	for slow: int in SLOW_GAPS_MSEC:
		var where: String = "%s, %d ms, flagged %s" % [name_of_menu, slow, flagged]
		var gesture: Callable = _double_click_from.bind(
			from, ShellMenus.SETTINGS, CENTER, Vector2i(0, slow), flagged, true
		)
		if await _produced(gesture, false, slow, where):
			_assert_settings_open_and_untouched(where)
			await _drop_shell()


## The second click, not marked, lands on "Fullscreen" where "Settings" was: a deliberate click.
func _slow_cases_that_act_on_fullscreen(from: From, name_of_menu: String) -> void:
	for slow: int in SLOW_GAPS_MSEC:
		var where: String = "%s, %d ms, not flagged" % [name_of_menu, slow]
		var gesture: Callable = _double_click_from.bind(
			from, ShellMenus.SETTINGS, CENTER, Vector2i(0, slow), false, true
		)
		if await _produced(gesture, false, slow, where):
			assert_eq(flow().get_state(), ShellFlow.State.SETTINGS, "the settings menu, %s" % where)
			assert_true(UserSettings.settings.fullscreen, "the second click acted, %s" % where)
			assert_eq(window_modes().size(), 2, "the window applier ran twice, %s" % where)
			await _drop_shell()


## Runs `gesture` (it spawns what it needs, posts the events and returns the Timing it measured)
## until the timing is the wanted one: the second press inside the guard (`inside_guard`) or after
## it and at least `min_gap_msec` after the first. A try that missed is dropped. Returns true with
## the scene alive for the test to judge, or false after failing with every measurement.
func _produced(gesture: Callable, inside_guard: bool, min_gap_msec: int, where: String) -> bool:
	var seen: Array[String] = []
	for _attempt: int in ATTEMPTS:
		var timing: Timing = await gesture.call()
		if timing.is_wanted(inside_guard, min_gap_msec):
			return true
		seen.append(timing.describe())
		gut.p("RETRY %s: the timing was not produced (%s)" % [where, timing.describe()])
		await _drop_shell()
	var wanted: String = "inside the guard" if inside_guard else "after it, >= %d ms" % min_gap_msec
	fail_test(
		(
			"%s: the second press was not %s in %d tries (measured: %s)"
			% [where, wanted, ATTEMPTS, "; ".join(seen)]
		)
	)
	return false


# --- the gestures ---


## Two clicks on entry `id` of the menu `from` gives; `top_offset` is pixels below the entry's top
## edge, or CENTER. The second press is `gap.x` frames after the first release, or `gap.y`
## milliseconds of real time after it when that is above 0 (and, with `after_guard`, not before the
## guard is over). `flagged` sets the OS's double-click mark on it.
func _double_click_from(
	from: From, id: StringName, top_offset: float, gap: Vector2i, flagged: bool, after_guard: bool
) -> Timing:
	await _spawn_from(from)
	var at: Vector2 = _point_of(id, top_offset)
	_move_mouse(at)
	await get_tree().process_frame
	_send_mouse(at, true, false)
	await get_tree().process_frame
	_send_mouse(at, false, false)
	var released: int = Time.get_ticks_msec()
	if gap.y > 0:
		var limit: int = released + gap.y + GUARD_LIMIT_MSEC
		while Time.get_ticks_msec() < limit:
			var over: bool = Time.get_ticks_msec() >= released + gap.y
			if over and not (after_guard and panel().is_choose_guarded()):
				break
			await get_tree().process_frame
	else:
		for _i: int in gap.x:
			await get_tree().process_frame
	_send_mouse(at, true, flagged)
	await get_tree().process_frame
	_send_mouse(at, false, false)
	await get_tree().process_frame
	return _arrival.timing_of_a_click_and_the_next_press()


## The first click as above; then the main thread is blocked STALL_MSEC and the flagged second
## click is queued (posted, not flushed) in that same frame. The panel's `_process` runs at the end
## of the frame, after the guard's time is over, and the click is delivered after that: the order
## the reviewers measured.
func _stalled_double_click_from(from: From, id: StringName, top_offset: float) -> Timing:
	await _spawn_from(from)
	var at: Vector2 = _point_of(id, top_offset)
	_move_mouse(at)
	await get_tree().process_frame
	_send_mouse(at, true, false)
	await get_tree().process_frame
	_send_mouse(at, false, false)
	OS.delay_msec(STALL_MSEC)
	_queue_mouse(at, true, true)
	_queue_mouse(at, false, false)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	return _arrival.timing_of_a_click_and_the_next_press()


func _enter_twice_on_the_title() -> Timing:
	await _spawn_from(From.TITLE)
	await tap_key(KEY_DOWN)
	assert_eq(panel().get_focus_id(), ShellMenus.SETTINGS, "Down moved the focus to Settings")
	_arrival.forget()
	await tap_key(KEY_ENTER)
	await _wait_msec(KEY_GAP_MSEC)
	press_key(KEY_ENTER)
	await _settle()
	return _arrival.timing_of_two_presses()


func _pad_a_twice_on_the_pause_menu() -> Timing:
	await _spawn_from(From.TOWN_PAUSE)
	await focus_entry_by_keys(ShellMenus.SETTINGS)
	_arrival.forget()
	await tap_pad(JOY_BUTTON_A)
	await _wait_msec(KEY_GAP_MSEC)
	press_pad(JOY_BUTTON_A)
	await _settle()
	return _arrival.timing_of_two_presses()


func _click_and_space_on_the_pause_menu() -> Timing:
	await _spawn_from(From.TOWN_PAUSE)
	_arrival.forget()
	await _click(_rect_of(ShellMenus.SETTINGS).get_center())
	await _wait_msec(KEY_GAP_MSEC)
	press_key(KEY_SPACE)
	await _settle()
	return _arrival.timing_of_a_click_and_the_next_press()


# --- helpers ---


func _spawn_title() -> void:
	await _spawn_title_with(Callable())


## The title with the panel's real guard (the shared helper turns it off), `prepare` run on the
## shell before it enters the tree, the menu layer above GUT's and the arrival watcher in place.
func _spawn_title_with(prepare: Callable) -> void:
	await spawn_shell(
		func(shell_node: Shell) -> void:
			shell_node.tower_data = TowerFixtures.tower_of(1, 1)
			_menu_of(shell_node).choose_guard_seconds = DEFAULT_CHOOSE_GUARD_SECONDS
			if prepare.is_valid():
				prepare.call(shell_node)
	)
	(shell().get_node(MENU_LAYER_PATH) as CanvasLayer).layer = ABOVE_GUT_LAYER
	_arrival = Arrival.new()
	_arrival.panel = panel()
	shell().get_node(MENU_LAYER_PATH).add_child(_arrival)


## A `prepare` that gives the panel a guard of `seconds`.
func _guard_of(seconds: float) -> Callable:
	return func(shell_node: Shell) -> void: _menu_of(shell_node).choose_guard_seconds = seconds


func _menu_of(shell_node: Shell) -> MenuPanel:
	return shell_node.get_node(MENU_PATH) as MenuPanel


## The menu `from` names, on screen with its guard over.
func _spawn_from(from: From) -> void:
	match from:
		From.TITLE:
			await _spawn_title()
			await _wait_guard()
		From.TOWN_PAUSE:
			await _spawn_paused(false)
		From.FLOOR_PAUSE:
			await _spawn_paused(true)
	_arrival.forget()


## The game started, on a floor or in the town, paused with Escape, the guard over.
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


## Waits, on real time, until the panel's guard is over, and for the frame in which its buttons take
## their places (a rectangle read before it is the old menu's).
func _wait_guard() -> void:
	var until: int = Time.get_ticks_msec() + GUARD_LIMIT_MSEC
	while panel().is_choose_guarded() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	assert_false(panel().is_choose_guarded(), "the choose guard ended")
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
## saved: only the first click (or key) did anything.
func _assert_settings_open_and_untouched(where: String) -> void:
	assert_eq(flow().get_state(), ShellFlow.State.SETTINGS, "the settings menu, %s" % where)
	assert_true(UserSettings.settings.screen_shake_enabled, "shake untouched, %s" % where)
	assert_false(UserSettings.settings.fullscreen, "fullscreen untouched, %s" % where)
	assert_eq(window_modes().size(), 1, "the window applier ran once, at start, %s" % where)
	assert_false(FileAccess.file_exists(settings_file()), "nothing saved, %s" % where)


func _assert_shake_switched_off_and_saved(where: String) -> void:
	assert_false(UserSettings.settings.screen_shake_enabled, "shake switched off, %s" % where)
	assert_true(FileAccess.file_exists(settings_file()), "and saved, %s" % where)
	assert_eq(flow().get_state(), ShellFlow.State.SETTINGS, "still in the settings, %s" % where)


## The confirm is up, the game is alive and it stays so.
func _assert_confirm_quit_and_alive(where: String) -> void:
	assert_eq(flow().get_state(), ShellFlow.State.CONFIRM_QUIT, "the confirm, %s" % where)
	await _settle()
	assert_not_null(shell().get_game(), "the game is alive, %s" % where)
	assert_eq(flow().get_state(), ShellFlow.State.CONFIRM_QUIT, "and still asking, %s" % where)
	assert_eq(quit_calls(), 0, "the application was not asked to quit, %s" % where)


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


## Where a click on entry `id` lands, in the canvas: its centre, or `top_offset` px below its top.
func _point_of(id: StringName, top_offset: float) -> Vector2:
	var rect: Rect2 = _rect_of(id)
	if top_offset == CENTER:
		return rect.get_center()
	return Vector2(rect.get_center().x, rect.position.y + top_offset)


## A canvas point in the window's coordinates, where the OS posts its events: the posted events go
## through the viewport's final transform (the identity in the headless window, not elsewhere).
func _window_point(canvas_point: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * canvas_point


## The pointer moves to `at`, the left button goes down and, a frame later, up.
func _click(at: Vector2) -> void:
	_move_mouse(at)
	await get_tree().process_frame
	_send_mouse(at, true, false)
	await get_tree().process_frame
	_send_mouse(at, false, false)
	await get_tree().process_frame


func _move_mouse(at: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = _window_point(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_mouse(at: Vector2, pressed: bool, double: bool) -> void:
	Input.parse_input_event(_mouse_event(at, pressed, double))
	Input.flush_buffered_events()


## Posted, not flushed: it waits for the engine's own flush, at the start of the next frame.
func _queue_mouse(at: Vector2, pressed: bool, double: bool) -> void:
	Input.parse_input_event(_mouse_event(at, pressed, double))


func _mouse_event(at: Vector2, pressed: bool, double: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.double_click = double
	event.position = _window_point(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	return event


## What the watcher measured of one gesture.
class Timing:
	extends RefCounted
	## When the choice that opened the menu arrived (the first click's release, or the first key).
	var opened_msec: int = -1
	## When the second press arrived, and the panel's guard at that moment.
	var second_msec: int = -1
	var guarded_at_second: bool = false

	func gap_msec() -> int:
		return second_msec - opened_msec

	## `inside_guard`: the second press came while the guard held, and under the guard's time since
	## the choice (the flag alone may be a frame late). Otherwise: the guard was over, and at least
	## `min_gap_msec` had passed.
	func is_wanted(inside_guard: bool, min_gap_msec: int) -> bool:
		if opened_msec < 0 or second_msec < 0:
			return false
		if inside_guard:
			return guarded_at_second and gap_msec() < GUARD_MSEC
		return not guarded_at_second and gap_msec() >= min_gap_msec

	func describe() -> String:
		if opened_msec < 0 or second_msec < 0:
			return "the events never arrived"
		return (
			"%d ms after the choice, guard %s" % [gap_msec(), "on" if guarded_at_second else "off"]
		)


## Stamps every press (key, pad button, mouse button) and every mouse release at the moment it
## arrives at `_input`, with the panel's guard then. It sits after the panel in the tree, so it is
## asked first, before the panel can consume the event.
class Arrival:
	extends Node
	var panel: MenuPanel
	var presses: Array[Vector2i] = []
	var mouse_releases: Array[Vector2i] = []

	func _input(event: InputEvent) -> void:
		var stamp: Vector2i = Vector2i(Time.get_ticks_msec(), 1 if panel.is_choose_guarded() else 0)
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button != null and not button.pressed:
			mouse_releases.append(stamp)
		elif event.is_pressed() and not event.is_echo():
			presses.append(stamp)

	func forget() -> void:
		presses.clear()
		mouse_releases.clear()

	## The choice that opened the menu was the first two presses' first; the second press is the
	## second.
	func timing_of_two_presses() -> Timing:
		var timing: Timing = Timing.new()
		if presses.size() >= 2:
			timing.opened_msec = presses[0].x
			timing.second_msec = presses[1].x
			timing.guarded_at_second = presses[1].y == 1
		return timing

	## A click opens the menu on its release; the next press (a second click's, or a key's) is the
	## second press.
	func timing_of_a_click_and_the_next_press() -> Timing:
		var timing: Timing = Timing.new()
		if not mouse_releases.is_empty() and presses.size() >= 2:
			timing.opened_msec = mouse_releases[0].x
			timing.second_msec = presses[1].x
			timing.guarded_at_second = presses[1].y == 1
		return timing
