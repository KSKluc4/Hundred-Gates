# gdlint:disable=max-public-methods,max-file-lines
extends F015ShellTest
## F-015 T5 (AC13-AC15, AC17, AC21, AC25, AC26's pause case; C6-C8, C12, C14-C16): the shell on its
## own, through shell.tscn. The title screen, Start and its failure, Quit, the pause and the resume,
## the physics space, the input guard, `pause` and cancel. Real input events, posted between two
## ticks unless a test says it posts inside one; 120 physics ticks/s, the player's input off unless
## a test turns it on. Tests of the paused state step frames with `await physics_frame`, never with
## run_ticks(), which submits commands nobody consumes while the game is disabled.

## The kinds of pause a scripted run takes. PLAIN: Escape, `frames` ticks, Escape. ZERO: Escape and
## Escape in the same instant. SETTINGS: pause, Settings, flip both entries twice, Back, Resume.
## CONFIRM: pause, the leave confirm (on a floor; the quit confirm elsewhere), Cancel, Resume.
enum Pause { PLAIN, ZERO, SETTINGS, CONFIRM }

const ESCAPE: Key = KEY_ESCAPE
const PAD_START: JoyButton = JOY_BUTTON_START
const PAD_B: JoyButton = JOY_BUTTON_B
const PAD_A: JoyButton = JOY_BUTTON_A
const MENU_LAYER: int = 10
const DIM_PATH: NodePath = ^"MenuLayer/Dim"
## A banner that is gone quickly: the HUD counts real time in `_process`.
const BANNER_SECONDS: float = 0.2
const PAUSED_FRAMES: int = 30
## Ticks the player must not dash in, after the game runs again.
const WATCH_TICKS: int = 10
## F-015/AC15: the walk into the corner of the town, and how long it is paused for.
const CORNER_TICKS: int = 300
const CORNER_PAUSE_FRAMES: int = 60
## The fight of AC15: its length, how long it is paused for, and how long it goes on after the last
## pause.
const FIGHT_TICKS: int = 1200
const FIGHT_PAUSE_FRAMES: int = 60
const FIGHT_TAIL_TICKS: int = 150
## The ticks the seeded pauses of the fight fall in.
const FIGHT_RANDOM_FIRST_TICK: int = 60
const FIGHT_RANDOM_LAST_TICK: int = 450
## F-015/AC15, the wall slide: a walk of four legs of SLIDE_LEG_TICKS ticks along the town's walls
## (into the south wall, up the east wall, down the west side, back), with a dash every 60 ticks.
## It crosses the seams between the wall bodies that a corner walk never reaches (C6).
const SLIDE_TICKS: int = 720
const SLIDE_LEG_TICKS: int = 180
## The control (two never-paused slides are the same) only needs the first part of the walk.
const CONTROL_TICKS: int = 360
const SLIDE_START_TILES: Vector2 = Vector2(2.5, 11.5)
const SLIDE_LEGS: Array[Vector2] = [
	Vector2(1.0, 1.0), Vector2(1.0, -0.4), Vector2(-0.3, 1.0), Vector2(-1.0, 0.6)
]
## The seeded schedule of mixed pauses (AC15): how many, the seed, and the lengths it picks from.
const RANDOM_SEED: int = 4
const RANDOM_PAUSES_MIN: int = 3
const RANDOM_PAUSES_MAX: int = 10
const RANDOM_FRAME_CHOICES: Array[int] = [1, 3, 7, 30]
const RANDOM_KINDS: Array[Pause] = [Pause.PLAIN, Pause.ZERO, Pause.SETTINGS, Pause.CONFIRM]
## What a test of the one-tick lag (DEV-6) watches after the pause: ticks.
const LAG_WATCH_TICKS: int = 10
## A rate low enough that most frames carry no physics tick: a press between ticks is easy to place.
const SLOW_TICKS_PER_SECOND: int = 30
const LAG_FRAME_LIMIT: int = 200

var _corner_reference: Dictionary = {}
var _fight_reference: Dictionary = {}
var _slide_reference: Dictionary = {}
var _entered: Array[Node] = []


func before_each() -> void:
	super.before_each()
	_entered = []


# --- AC13: the title screen and Start ---


func test_ac13_the_shell_starts_on_the_title_screen() -> void:
	await spawn_shell()
	assert_null(shell().get_game(), "no game yet")
	assert_null(shell().get_node_or_null("Game"), "and no Game node")
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)
	assert_true(panel().is_open())
	assert_eq(panel().get_heading(), ShellMenus.TITLE_HEADING)
	assert_eq(panel().get_body(), "")
	assert_eq(
		panel().get_entry_ids(),
		[ShellMenus.START, ShellMenus.SETTINGS, ShellMenus.QUIT] as Array[StringName]
	)
	assert_eq(panel().get_focus_id(), ShellMenus.START)
	assert_true(_dim().visible)
	assert_eq(_dim().color, shell().title_color, "an opaque screen behind the title")
	assert_true(space_is_active())


func test_ac13_the_scene_is_what_the_spec_names() -> void:
	await spawn_shell()
	var layer: CanvasLayer = shell().get_node("MenuLayer")
	assert_eq(layer.layer, MENU_LAYER)
	assert_true(_dim() is ColorRect)
	assert_eq(_dim().mouse_filter, Control.MOUSE_FILTER_IGNORE, "the dim lets the mouse through")
	assert_same(shell().get_node("MenuLayer/Menu"), panel())
	assert_eq(shell().process_physics_priority, 3, "after Game's 2")
	assert_eq(Shell.GAME_SCENE_PATH, "res://src/world/game.tscn")
	assert_eq(shell().dim_color, Color(0.0, 0.0, 0.0, 0.6))
	assert_eq(shell().title_color.a, 1.0, "the title's is opaque")


func test_ac13_start_builds_the_game_disabled_and_the_guard_begins() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	choose(ShellMenus.START)
	var game: Game = shell().get_game()
	assert_not_null(game)
	assert_same(shell().get_node("Game"), game, "the child is named Game")
	assert_eq(game.process_mode, Node.PROCESS_MODE_DISABLED, "disabled the moment it exists")
	assert_true(shell().is_guarding())
	assert_false(space_is_active(), "the physics space is stopped with it")
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_false(panel().is_open())
	assert_false(panel().visible)
	assert_false(_dim().visible)
	assert_eq(game.get_setup_errors(), PackedStringArray())


func test_ac13_after_the_guard_the_town_is_shown_and_the_game_runs() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT)
	assert_true(space_is_active())
	assert_not_null(town(), "the town is shown")
	assert_eq(session().get_place(), TowerSession.Place.TOWN)
	assert_eq(location(), "Town")
	assert_false(panel().is_open())
	assert_false(_dim().visible)


func test_ac13_the_player_stands_still() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	var start: Vector2 = player().global_position
	for _i: int in 20:
		await get_tree().physics_frame
	assert_eq(player().global_position, start)
	assert_eq(player().motor.get_state(), PlayerMotor.State.IDLE)


func test_ac13_start_by_the_keyboard() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await tap_key(KEY_ENTER)
	assert_not_null(shell().get_game())
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)


func test_ac13_the_space_is_active_after_the_shell_is_freed() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	assert_true(space_is_active())
	shell().queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(space_is_active())


func test_ac13_the_space_is_active_after_the_shell_is_freed_while_paused() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	assert_false(space_is_active())
	shell().queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(space_is_active(), "the shell leaving the tree gives the space back")


func test_ac13_a_shell_freed_on_the_title_screen_leaves_the_space_alone() -> void:
	await spawn_shell()
	shell().queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(space_is_active())


# --- C12, C14: the settings file and the window applier at start ---


func test_c14_the_applier_is_called_once_with_the_loaded_value_true() -> void:
	UserSettings.settings.fullscreen = true
	assert_true(UserSettings.save_to(settings_file()))
	UserSettings.reset_to_defaults()
	await spawn_shell()
	assert_true(UserSettings.settings.fullscreen, "the file was loaded")
	assert_eq(window_modes(), [DisplayServer.WINDOW_MODE_FULLSCREEN] as Array[int])


func test_c14_the_applier_is_called_once_with_the_loaded_value_false() -> void:
	UserSettings.settings.fullscreen = false
	assert_true(UserSettings.save_to(settings_file()))
	UserSettings.settings.fullscreen = true  # What the shell must replace with the file's.
	await spawn_shell()
	assert_false(UserSettings.settings.fullscreen)
	assert_eq(window_modes(), [DisplayServer.WINDOW_MODE_WINDOWED] as Array[int])


func test_c14_a_missing_file_is_the_defaults_and_one_call() -> void:
	assert_false(FileAccess.file_exists(settings_file()))
	await spawn_shell()
	assert_eq(window_modes(), [DisplayServer.WINDOW_MODE_WINDOWED] as Array[int])
	assert_false(FileAccess.file_exists(settings_file()), "loading creates nothing")


func test_c14_the_applier_is_not_called_again_by_playing() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await tap_key(ESCAPE)
	await tap_key(ESCAPE)
	assert_eq(window_modes().size(), 1, "once at start, and the shell does not watch `changed`")


func test_c12_an_empty_path_neither_loads_nor_saves() -> void:
	UserSettings.settings.fullscreen = false
	assert_true(UserSettings.save_to(settings_file()))  # A file the shell must not read.
	UserSettings.settings.fullscreen = true
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(settings_file())
	var prepare: Callable = func(shell_node: Shell) -> void: shell_node.settings_path = ""
	await spawn_shell(prepare)
	assert_true(UserSettings.settings.fullscreen, "no load: the value in memory stays")
	assert_eq(window_modes(), [DisplayServer.WINDOW_MODE_FULLSCREEN] as Array[int])
	assert_eq(
		FileAccess.get_file_as_bytes(settings_file()), bytes_before, "and nothing was written"
	)


func test_c12_an_empty_path_creates_no_file() -> void:
	var prepare: Callable = func(shell_node: Shell) -> void: shell_node.settings_path = ""
	await spawn_shell(prepare)
	assert_false(FileAccess.file_exists(settings_file()))
	assert_eq(
		window_modes(), [DisplayServer.WINDOW_MODE_WINDOWED] as Array[int], "also with no path"
	)


# --- AC14: the pause ---


func test_ac14_escape_pauses_in_the_town() -> void:
	await _assert_pause_freezes(false, false)


func test_ac14_pad_start_pauses_in_the_town() -> void:
	await _assert_pause_freezes(false, true)


func test_ac14_escape_pauses_on_a_floor() -> void:
	await _assert_pause_freezes(true, false)


func test_ac14_pad_start_pauses_on_a_floor() -> void:
	await _assert_pause_freezes(true, true)


func _assert_pause_freezes(on_floor: bool, use_pad: bool) -> void:
	await spawn_shell_on(WaveFixtures.wave_tower(2))
	await start_game()
	if on_floor:
		await enter_floor_through_gate(1)
		var fresh: Array = _positions()
		await run_ticks(200, Vector2.RIGHT, Vector2.RIGHT)
		assert_ne(_positions(), fresh, "the fight is moving before the pause")
	hud().show_banner("Kept", BANNER_SECONDS)
	assert_true(hud().is_banner_visible())
	var before: Dictionary = await _pause_by(use_pad)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(space_is_active(), "the physics space is stopped")
	assert_true(panel().is_open())
	assert_eq(panel().get_heading(), ShellMenus.PAUSED_HEADING)
	assert_eq(panel().get_focus_id(), ShellMenus.RESUME)
	assert_eq(panel().get_entry_ids(), _pause_entries(on_floor))
	assert_true(_dim().visible)
	assert_eq(_dim().color, shell().dim_color, "a dim over the game, not the title's")
	for _i: int in PAUSED_FRAMES:
		await get_tree().physics_frame
		assert_eq(_sim().get_time(), before["time"], "the sim's clock stands still")
		assert_eq(_positions(), before["positions"], "enemies and projectiles stand still")
	assert_eq(_world()["sim"], before["sim"])
	await _step_for(BANNER_SECONDS * 2.0)
	assert_true(hud().is_banner_visible(), "a banner is kept past its own duration")
	await get_tree().process_frame
	_resume_by(&"escape")
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	await wait_for_guard()
	assert_true(hud().is_banner_visible(), "and still there when the game runs again")
	await _step_for(BANNER_SECONDS + 0.3)
	assert_false(hud().is_banner_visible(), "gone one duration after the resume")


func test_ac14_the_pause_menu_of_a_floor_has_the_leave_entry() -> void:
	await spawn_shell_on(WaveFixtures.wave_tower(2))
	await start_game()
	await tap_key(ESCAPE)
	assert_false(panel().get_entry_ids().has(ShellMenus.LEAVE), "none in the town")
	await tap_key(ESCAPE)
	await wait_for_guard()
	await enter_floor_through_gate(1)
	await tap_key(ESCAPE)
	assert_true(panel().get_entry_ids().has(ShellMenus.LEAVE), "one on a floor")


# --- AC15: the resume ---


func test_ac15_resume_by_the_entry() -> void:
	await _assert_resume_restores(&"entry")


func test_ac15_resume_by_escape() -> void:
	await _assert_resume_restores(&"escape")


func test_ac15_resume_by_pad_b() -> void:
	await _assert_resume_restores(&"pad_b")


func test_ac15_resume_by_pad_start() -> void:
	await _assert_resume_restores(&"pad_start")


func _assert_resume_restores(method: StringName) -> void:
	await spawn_shell_on(WaveFixtures.wave_tower(2))
	await start_game()
	await enter_floor_through_gate(1)
	await run_ticks(120, Vector2.RIGHT, Vector2.RIGHT)
	var before: Dictionary = await _pause_by(false)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	for _i: int in 10:
		await get_tree().physics_frame
	await get_tree().process_frame
	_resume_by(method)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "resumed by %s" % method)
	assert_false(panel().is_open())
	assert_false(_dim().visible)
	var after: Dictionary = _world()
	assert_eq(after["sim"], before["sim"], "the sim's snapshot is what it was")
	assert_eq(after["session"], before["session"], "and the session's")
	assert_eq(after["positions"], before["positions"])
	await wait_for_guard()
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT, "the game runs again")
	await run_ticks(10)
	assert_true(space_is_active())
	assert_gt(_sim().get_time(), before["time"], "and the sim moves on")


## F-015/AC15: a fight paused in the middle of a dash and of an enemy's attack, then in the middle
## of a bolt's flight, and the same fight never paused: tick for tick the same.
func test_ac15_a_paused_fight_is_the_same_as_one_never_paused() -> void:
	if _fight_reference.is_empty():
		_fight_reference = await _fight([])
	var flags: Array = _fight_reference["flags"]
	var first: int = _choose_pause(flags, true, 100)
	assert_gt(first, 0, "the reference fight has a dash during an enemy's attack")
	var second: int = _choose_pause(flags, false, first + 30)
	assert_gt(second, first, "and a bolt in flight")
	var run: Dictionary = await _fight([first, second])
	var at_first: Dictionary = run["flags_at_pause"][0]
	assert_true(at_first["dash"] and at_first["attack"], "paused mid-dash and mid-attack")
	assert_true(run["flags_at_pause"][1]["bolts"] > 0, "and with a bolt in the air")
	var length: int = mini(second + FIGHT_TAIL_TICKS, FIGHT_TICKS)
	var trace: Array = run["trace"]
	var reference_trace: Array = _fight_reference["trace"]
	assert_eq(trace.size(), length)
	assert_eq(_first_difference(reference_trace.slice(0, length), trace), -1, "no tick differs")


## The same fight with the seeded schedule of mixed pauses (on a floor, so the leave confirm is one
## of the kinds), compared tick by tick.
func test_ac15_a_fight_with_a_seeded_schedule_of_mixed_pauses_is_the_same() -> void:
	if _fight_reference.is_empty():
		_fight_reference = await _fight([])
	var schedule: Dictionary = _random_schedule(FIGHT_RANDOM_FIRST_TICK, FIGHT_RANDOM_LAST_TICK)
	var pauses: Array[int] = []
	for tick: int in schedule.keys():
		pauses.append(tick)
	var run: Dictionary = await _fight(pauses, schedule)
	var length: int = mini(pauses.max() + FIGHT_TAIL_TICKS, FIGHT_TICKS)
	var trace: Array = run["trace"]
	assert_eq(trace.size(), length)
	var at: int = _first_difference(_fight_reference["trace"].slice(0, length), trace)
	assert_eq(at, -1, "pauses %s: no tick differs" % [schedule])


## F-015/AC15: a walk and a dash into the north-west corner of the town for 300 ticks. This is the
## case that differs, by up to 0.07 px for a dozen ticks, when the physics space keeps stepping
## while the game is disabled.
func test_ac15_a_walk_into_a_corner_paused_in_a_dash_is_the_same() -> void:
	await _assert_corner_walk_unchanged(53)


func test_ac15_a_walk_into_a_corner_paused_on_the_way_is_the_same() -> void:
	await _assert_corner_walk_unchanged(20)


func test_ac15_a_walk_into_a_corner_paused_in_the_corner_is_the_same() -> void:
	await _assert_corner_walk_unchanged(200)


func _assert_corner_walk_unchanged(pause_at: int) -> void:
	if _corner_reference.is_empty():
		_corner_reference = await _corner_walk(-1)
	var run: Dictionary = await _corner_walk(pause_at)
	assert_eq(
		_first_difference(_corner_reference["trace"], run["trace"]),
		-1,
		"paused for %d frames at tick %d: no tick differs" % [CORNER_PAUSE_FRAMES, pause_at]
	)
	assert_eq(run["final"], _corner_reference["final"])


# --- AC15: the wall slide (C6: the game's bodies stay in the space while it is stopped) ---


func test_ac15_two_slides_never_paused_are_the_same() -> void:
	await _slide_reference_run()
	var again: Dictionary = await _slide_walk({}, CONTROL_TICKS)
	var reference_start: Array = _slide_reference["trace"].slice(0, CONTROL_TICKS)
	assert_eq(_first_difference(reference_start, again["trace"]), -1, "no tick differs")


func test_ac15_a_slide_paused_at_30_for_60_frames_is_the_same() -> void:
	await _assert_slide_unchanged({30: [Pause.PLAIN, 60]})


func test_ac15_a_slide_paused_at_100_for_no_frame_is_the_same() -> void:
	await _assert_slide_unchanged({100: [Pause.ZERO, 0]})


func test_ac15_a_slide_paused_at_200_for_1_frame_is_the_same() -> void:
	await _assert_slide_unchanged({200: [Pause.PLAIN, 1]})


func test_ac15_a_slide_paused_at_250_for_5_frames_is_the_same() -> void:
	await _assert_slide_unchanged({250: [Pause.PLAIN, 5]})


func test_ac15_a_slide_paused_at_340_for_60_frames_is_the_same() -> void:
	await _assert_slide_unchanged({340: [Pause.PLAIN, 60]})


func test_ac15_a_slide_paused_at_400_for_5_frames_is_the_same() -> void:
	await _assert_slide_unchanged({400: [Pause.PLAIN, 5]})


func test_ac15_a_slide_paused_at_500_for_1_frame_is_the_same() -> void:
	await _assert_slide_unchanged({500: [Pause.PLAIN, 1]})


## Three to ten pauses of mixed kinds at seeded ticks, in the same slide.
func test_ac15_a_slide_with_a_seeded_schedule_of_mixed_pauses_is_the_same() -> void:
	var schedule: Dictionary = _random_schedule(5, SLIDE_TICKS - 40)
	assert_gte(schedule.size(), RANDOM_PAUSES_MIN)
	await _assert_slide_unchanged(schedule)


func _assert_slide_unchanged(schedule: Dictionary) -> void:
	await _slide_reference_run()
	var run: Dictionary = await _slide_walk(schedule)
	var at: int = _first_difference(_slide_reference["trace"], run["trace"])
	assert_eq(at, -1, "pauses %s: no tick differs (position and snapshot)" % [schedule])
	assert_eq(run["trace"].size(), SLIDE_TICKS)
	assert_eq(run["final"], _slide_reference["final"])


# --- AC17: where `pause` does nothing ---


func test_ac17_escape_with_the_gate_list_open_closes_the_list_and_nothing_else() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await open_gate_menu()
	assert_false(game().is_pause_allowed())
	watch_signals(flow())
	await tap_key(ESCAPE)
	assert_false(menu().is_open(), "the gate list closed")
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_signal_not_emitted(flow(), "state_changed")
	assert_false(panel().is_open(), "and no pause menu opened")
	assert_ne(game().process_mode, Node.PROCESS_MODE_DISABLED)
	assert_true(space_is_active())


func test_ac17_pad_start_with_the_gate_list_open_does_nothing() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await open_gate_menu()
	watch_signals(flow())
	await tap_pad(PAD_START)
	assert_true(menu().is_open(), "the gate list is still open")
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_signal_not_emitted(flow(), "state_changed")
	assert_false(panel().is_open())
	assert_ne(game().process_mode, Node.PROCESS_MODE_DISABLED)


func test_ac17_pause_does_nothing_on_the_title_screen() -> void:
	await spawn_shell()
	watch_signals(flow())
	await tap_key(ESCAPE)
	await tap_pad(PAD_START)
	await tap_pad(PAD_B)
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)
	assert_signal_not_emitted(flow(), "state_changed")
	assert_true(panel().is_open())
	assert_eq(panel().get_heading(), ShellMenus.TITLE_HEADING)
	assert_null(shell().get_game())
	assert_true(space_is_active())


func test_ac17_pause_does_nothing_in_the_death_pause() -> void:
	set_death_delay(0.5)
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await enter_floor_through_gate(1)
	kill_player()
	await run_ticks(2)
	assert_eq(session().get_place(), TowerSession.Place.DEATH_PAUSE)
	# T6 (C21): the shell has opened the death screen by now; `pause` does nothing on it.
	assert_eq(flow().get_state(), ShellFlow.State.DEAD)
	watch_signals(flow())
	await tap_key(ESCAPE)
	await tap_pad(PAD_START)
	assert_eq(flow().get_state(), ShellFlow.State.DEAD, "no pause menu over the death screen")
	assert_signal_not_emitted(flow(), "state_changed")
	assert_true(panel().is_open())
	assert_eq(panel().get_heading(), ShellMenus.DEAD_HEADING, "still the death screen")
	assert_ne(game().process_mode, Node.PROCESS_MODE_DISABLED)
	assert_true(space_is_active())


func test_ac17_pause_does_nothing_between_a_gate_choice_and_the_floor() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await open_gate_menu()
	await get_tree().process_frame  # Between two ticks: the game has not swapped yet.
	menu().choose(0)
	assert_eq(session().get_place(), TowerSession.Place.FLOOR, "the session is on the floor")
	assert_not_null(town(), "while the town is still shown")
	assert_false(game().is_pause_allowed())
	watch_signals(flow())
	press_key(ESCAPE)
	press_pad(PAD_START)
	assert_signal_not_emitted(flow(), "state_changed")
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	await run_ticks(2)
	assert_not_null(floor_scene(), "the floor is shown")
	assert_true(game().is_pause_allowed())
	await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "and now it pauses")


# --- AC21: Quit ---


func test_ac21_quit_calls_the_handler_once_and_nothing_else() -> void:
	await spawn_shell()
	watch_signals(flow())
	choose(ShellMenus.QUIT)
	assert_eq(quit_calls(), 1)
	assert_eq(flow().get_state(), ShellFlow.State.TITLE)
	assert_signal_not_emitted(flow(), "state_changed")
	assert_null(shell().get_game())
	assert_true(panel().is_open(), "the title is still up")
	assert_false(FileAccess.file_exists(settings_file()), "nothing was saved")
	assert_eq(window_modes().size(), 1, "and the window was not touched")


func test_ac21_quit_by_the_keyboard() -> void:
	await spawn_shell()
	await tap_key(KEY_DOWN)
	await tap_key(KEY_DOWN)
	assert_eq(panel().get_focus_id(), ShellMenus.QUIT)
	await tap_key(KEY_ENTER)
	assert_eq(quit_calls(), 1)


func test_ac21_quit_is_not_called_by_anything_else() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await tap_key(ESCAPE)
	await tap_key(ESCAPE)
	assert_eq(quit_calls(), 0)


# --- AC25: a game that cannot start ---


func test_ac25_invalid_data_leaves_the_title_screen_up_with_the_failure_line() -> void:
	var tower: TowerData = TowerFixtures.tower_of(2)
	tower.floors[1].floor_number = 5
	tower.town.is_safe_room = false
	var expected: PackedStringArray = tower.validate(Tunables.floors)
	assert_gt(expected.size(), 1, str(expected))
	await spawn_shell_on(tower)
	shell().child_entered_tree.connect(func(node: Node) -> void: _entered.append(node))
	watch_signals(flow())
	var line: String = ShellMenus.START_FAILED_FORMAT % expected.size()
	for attempt: int in 2:
		choose(ShellMenus.START)
		for error: String in expected:
			assert_push_error(error)
		assert_eq(_entered.size(), attempt + 1, "a game was built each time")
		assert_signal_not_emitted(flow(), "state_changed")
		assert_eq(flow().get_state(), ShellFlow.State.TITLE, "attempt %d" % attempt)
		assert_true(panel().is_open())
		assert_eq(panel().get_body(), line, "the title says how many errors")
		assert_eq(panel().get_focus_id(), ShellMenus.START)
		assert_null(shell().get_game())
		assert_true(space_is_active(), "the physics space is active")
		assert_false(shell().is_guarding())
		await get_tree().process_frame
		assert_null(shell().get_node_or_null("Game"), "no Game node is left after a frame")
		assert_false(is_instance_valid(_entered[attempt]), "the failed game was freed")
	assert_eq(shell().get_child_count(), 1, "nothing but the menu layer")


func test_ac25_the_failure_line_stays_whenever_the_title_is_shown_again() -> void:
	var tower: TowerData = TowerFixtures.tower_of(1)
	tower.town = null
	var expected: PackedStringArray = tower.validate(Tunables.floors)
	await spawn_shell_on(tower)
	choose(ShellMenus.START)
	for error: String in expected:
		assert_push_error(error)
	var line: String = ShellMenus.START_FAILED_FORMAT % expected.size()
	assert_eq(panel().get_body(), line)
	# The flow goes to the settings and back: the shell shows what it says, with the line.
	assert_true(flow().open_settings())
	assert_eq(panel().get_heading(), ShellMenus.SETTINGS_HEADING)
	assert_true(flow().close_settings())
	assert_eq(panel().get_heading(), ShellMenus.TITLE_HEADING)
	assert_eq(panel().get_body(), line, "shown again after Settings and Back")
	assert_eq(panel().get_focus_id(), ShellMenus.SETTINGS)


func test_ac25_a_start_that_works_after_a_failed_one_forgets_the_line() -> void:
	var bad: TowerData = TowerFixtures.tower_of(1)
	bad.town = null
	await spawn_shell_on(bad)
	choose(ShellMenus.START)
	for error: String in bad.validate(Tunables.floors):
		assert_push_error(error)
	assert_ne(panel().get_body(), "")
	shell().tower_data = TowerFixtures.tower_of(1)
	choose(ShellMenus.START)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_not_null(shell().get_game())
	# Back on the title by the flow's own ways, the body is empty again.
	await wait_for_guard()
	await tap_key(ESCAPE)
	assert_true(flow().ask_quit())
	assert_true(flow().confirm_quit())
	assert_eq(panel().get_heading(), ShellMenus.TITLE_HEADING)
	assert_eq(panel().get_body(), "", "a Start that worked cleared the count")


# --- AC26: one press, one step ---


func test_ac26_one_escape_from_the_pause_menu_resumes_and_does_not_pause_again() -> void:
	await _assert_single_step_resume(false)


func test_ac26_one_pad_start_from_the_pause_menu_resumes_and_does_not_pause_again() -> void:
	await _assert_single_step_resume(true)


func _assert_single_step_resume(use_pad: bool) -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1), true)
	await start_game()
	await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	watch_signals(flow())
	if use_pad:
		await tap_pad(PAD_START)
	else:
		await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	assert_signal_emit_count(flow(), "state_changed", 1, "one press, one change")
	await wait_for_guard()
	for _i: int in 5:
		await get_tree().physics_frame
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "no new pause")
	assert_signal_emit_count(flow(), "state_changed", 1)


func test_ac26_one_escape_from_a_confirm_lands_in_the_pause_menu() -> void:
	await _assert_single_step_back(ShellFlow.State.CONFIRM_QUIT, false)


func test_ac26_one_pad_start_from_a_confirm_lands_in_the_pause_menu() -> void:
	await _assert_single_step_back(ShellFlow.State.CONFIRM_QUIT, true)


func test_ac26_one_escape_from_the_settings_lands_in_the_pause_menu() -> void:
	await _assert_single_step_back(ShellFlow.State.SETTINGS, false)


func test_ac26_one_pad_start_from_the_settings_lands_in_the_pause_menu() -> void:
	await _assert_single_step_back(ShellFlow.State.SETTINGS, true)


## The flow is taken to `state` by its own methods (the entries that lead there are the next
## task's); the shell shows what it says, and one press goes back one step.
func _assert_single_step_back(state: ShellFlow.State, use_pad: bool) -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await tap_key(ESCAPE)
	if state == ShellFlow.State.SETTINGS:
		assert_true(flow().open_settings())
	else:
		assert_true(flow().ask_quit())
	assert_eq(flow().get_state(), state)
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED, "the game stayed stopped")
	assert_false(space_is_active())
	watch_signals(flow())
	if use_pad:
		await tap_pad(PAD_START)
	else:
		await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "one step back, not two")
	assert_signal_emit_count(flow(), "state_changed", 1)
	assert_true(panel().is_open())
	assert_eq(panel().get_heading(), ShellMenus.PAUSED_HEADING)
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(space_is_active())
	var led_here: StringName = (
		ShellMenus.SETTINGS if state == ShellFlow.State.SETTINGS else ShellMenus.QUIT_TO_TITLE
	)
	assert_eq(panel().get_focus_id(), led_here, "the focus is on the entry that led there")


# --- C7: the input guard ---


func test_c7_resume_by_space_does_not_dash() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1), true)
	await start_game()
	await tap_key(ESCAPE)
	await hold_key_between_ticks(KEY_SPACE)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "Space resumed")
	await _assert_no_dash_after_the_guard()


func test_c7_resume_by_pad_a_does_not_dash() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1), true)
	await start_game()
	await tap_key(ESCAPE)
	await hold_pad_between_ticks(PAD_A)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "pad A resumed")
	await _assert_no_dash_after_the_guard()


func test_c7_start_by_space_does_not_dash() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1), true)
	await hold_key_between_ticks(KEY_SPACE)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "Space started the game")
	_game = shell().get_game()
	await _assert_no_dash_after_the_guard()


func test_c7_a_press_posted_inside_a_tick_is_guarded_too_on_resume() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1), true)
	await start_game()
	await tap_key(ESCAPE)
	await get_tree().physics_frame
	hold_key(KEY_SPACE)  # Inside a tick: the one just-pressed is the next.
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	await _assert_no_dash_after_the_guard()


func test_c7_a_press_posted_inside_a_tick_is_guarded_too_on_start() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1), true)
	await get_tree().physics_frame
	hold_key(KEY_SPACE)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	_game = shell().get_game()
	await _assert_no_dash_after_the_guard()


## The game runs only in the third tick after a choice made between ticks: nothing in the first,
## the enable in the second, never in the input callback.
func test_c7_the_guard_holds_for_two_of_the_shells_ticks() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await tap_key(ESCAPE)
	await get_tree().process_frame
	choose(ShellMenus.RESUME)
	assert_true(shell().is_guarding(), "from the choice")
	assert_eq(
		game().process_mode, Node.PROCESS_MODE_DISABLED, "the game was not enabled by the choice"
	)
	assert_false(space_is_active())
	await get_tree().physics_frame  # The start of the first tick.
	assert_true(shell().is_guarding())
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED)
	await get_tree().physics_frame  # The start of the second: the shell enables the game in it.
	assert_true(shell().is_guarding())
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED, "not before the second tick ends")
	assert_false(space_is_active())
	await get_tree().physics_frame
	assert_false(shell().is_guarding(), "until the game runs")
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT)
	assert_false(space_is_active(), "the space follows in the tick the game first runs in (DEV-6)")
	await get_tree().physics_frame
	assert_true(space_is_active())


func test_c7_the_guard_never_looks_at_the_game_apart_from_its_enable() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	choose(ShellMenus.START)
	for _i: int in 6:
		assert_eq(
			shell().is_guarding(),
			shell().get_game().process_mode == Node.PROCESS_MODE_DISABLED,
			"guarding is exactly the time the game is held back"
		)
		await get_tree().physics_frame
	assert_false(shell().is_guarding())


func test_c7_escape_and_pad_start_during_the_guard_open_no_pause_menu() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1), true)
	await start_game()
	await tap_key(ESCAPE)
	await get_tree().process_frame
	choose(ShellMenus.RESUME)
	watch_signals(flow())
	press_key(ESCAPE)
	press_pad(PAD_START)
	assert_true(shell().is_guarding())
	await get_tree().physics_frame
	press_key(ESCAPE)
	press_pad(PAD_START)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "no pause during the guard")
	assert_signal_not_emitted(flow(), "state_changed")
	assert_false(panel().is_open())
	await wait_for_guard()
	await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "and pause is back once the game runs")


func test_c7_a_movement_key_held_through_the_resume_moves_the_player() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1), true)
	await start_game()
	await hold_key_between_ticks(KEY_D)
	for _i: int in 5:
		await get_tree().physics_frame
	await tap_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	var paused_at: Vector2 = player().global_position
	for _i: int in 10:
		await get_tree().physics_frame
	assert_eq(player().global_position, paused_at, "standing still while paused")
	await get_tree().process_frame
	choose(ShellMenus.RESUME)
	await wait_for_guard()
	var resumed_at: Vector2 = player().global_position
	for _i: int in 20:
		await get_tree().physics_frame
	assert_gt(player().global_position.x, resumed_at.x + 2.0, "the held key walks the player")
	assert_ne(player().motor.get_state(), PlayerMotor.State.DASHING)


## With the player's input on and a key down that is also the dash: after the choice has been made,
## the game runs again and the player must not dash in the next WATCH_TICKS ticks.
func _assert_no_dash_after_the_guard() -> void:
	assert_true(shell().is_guarding(), "the guard began with the choice")
	await wait_for_guard()
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT, "the game runs again")
	for tick: int in WATCH_TICKS:
		await get_tree().physics_frame
		assert_ne(player().motor.get_state(), PlayerMotor.State.DASHING, "tick %d" % tick)
		assert_ne(player().motor.get_state(), PlayerMotor.State.ATTACKING, "tick %d" % tick)


# --- DEV-6: a pause in the one tick the space lags behind the game ---


## The game was enabled in the last tick and the space follows in the next (`_space_follows`). A
## pause posted inside that tick: the space must stay inactive until the resume.
func test_dev6_a_pause_posted_inside_the_tick_the_space_lags_keeps_the_space_off() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await tap_key(ESCAPE)
	await get_tree().process_frame
	choose(ShellMenus.RESUME)
	await wait_for_guard()
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT, "the premise: the game runs again")
	assert_false(space_is_active(), "and the space still lags")
	press_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "paused in the lag")
	await _assert_stopped_for(LAG_WATCH_TICKS)
	await get_tree().process_frame
	choose(ShellMenus.RESUME)
	await wait_for_guard()
	await run_ticks(3)
	assert_true(space_is_active(), "the resume gave the space back")


## The same, the pause posted between two ticks (at a rate where most frames have none).
func test_dev6_a_pause_posted_between_ticks_right_after_the_enable_keeps_the_space_off() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	Engine.physics_ticks_per_second = SLOW_TICKS_PER_SECOND
	await tap_key(ESCAPE)
	await get_tree().process_frame
	choose(ShellMenus.RESUME)
	var in_the_lag: bool = false
	for _i: int in LAG_FRAME_LIMIT:
		await get_tree().process_frame
		if not shell().is_guarding() and not space_is_active():
			in_the_lag = true
			break
	assert_true(in_the_lag, "a frame between the enable tick and the next one was found")
	press_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "paused in the lag")
	await _assert_stopped_for(LAG_WATCH_TICKS)


## For `ticks` ticks the game is disabled, the space is inactive and the sim's clock stands still.
func _assert_stopped_for(ticks: int) -> void:
	var time: float = _sim().get_time()
	for tick: int in ticks:
		await get_tree().physics_frame
		assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED, "tick %d" % tick)
		assert_false(space_is_active(), "the space stays off, tick %d" % tick)
		assert_eq(_sim().get_time(), time, "the sim's clock stands still, tick %d" % tick)


# --- C8: an event the flow acted on is consumed ---


## `pause` (pad Start) reaches a node that comes after the shell in `_unhandled_input` only when the
## flow refused it: on the title screen. When the flow paused, or went back, it is marked handled.
func test_c8_an_event_the_flow_acted_on_is_handled_and_a_refused_one_is_not() -> void:
	var spy: PauseSpy = PauseSpy.new()
	add_child_autofree(spy)  # Before the shell: it hears unhandled input after it.
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await tap_pad(PAD_START)
	assert_eq(flow().get_state(), ShellFlow.State.TITLE, "refused on the title screen")
	assert_eq(spy.presses, 1, "so the event went on")
	await start_game()
	spy.presses = 0
	await tap_pad(PAD_START)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "the flow paused")
	assert_eq(spy.presses, 0, "and the event was consumed")
	await tap_pad(PAD_START)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "the flow went back")
	assert_eq(spy.presses, 0, "and that one too")


# --- C6: the stop is applied again when a stopped shell enters the tree ---


func test_c6_a_paused_shell_put_back_in_the_tree_stops_the_space_again() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	await tap_key(ESCAPE)
	assert_false(space_is_active())
	var parent: Node = shell().get_parent()
	parent.remove_child(shell())
	assert_true(space_is_active(), "leaving the tree gives the space back")
	parent.add_child(shell())
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	assert_eq(game().process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(space_is_active(), "the game is stopped, so the space is again")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(space_is_active(), "and it stays so")
	choose(ShellMenus.RESUME)
	await wait_for_guard()
	await run_ticks(3)
	assert_true(space_is_active(), "the resume gives it back")


func test_c6_a_shell_put_back_in_the_tree_while_running_leaves_the_space_on() -> void:
	await spawn_shell_on(TowerFixtures.tower_of(1, 1))
	await start_game()
	var parent: Node = shell().get_parent()
	parent.remove_child(shell())
	parent.add_child(shell())
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(space_is_active())
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT)


# --- helpers ---


func _dim() -> ColorRect:
	return shell().get_node(DIM_PATH)


func _pause_entries(on_floor: bool) -> Array[StringName]:
	var ids: Array[StringName] = [ShellMenus.RESUME, ShellMenus.EQUIPMENT_ID]
	if on_floor:
		ids.append(ShellMenus.LEAVE)
	ids.append(ShellMenus.SETTINGS)
	ids.append(ShellMenus.QUIT_TO_TITLE)
	return ids


## Between two ticks: the world as it is, then the pause key (Escape, or pad Start). What was taken.
func _pause_by(use_pad: bool) -> Dictionary:
	await get_tree().process_frame
	var before: Dictionary = _world()
	if use_pad:
		press_pad(PAD_START)
	else:
		press_key(ESCAPE)
	return before


## At once: what resumes the game, by the entry, Escape, pad B or pad Start.
func _resume_by(method: StringName) -> void:
	match method:
		&"entry":
			choose(ShellMenus.RESUME)
		&"escape":
			press_key(ESCAPE)
		&"pad_b":
			press_pad(PAD_B)
		&"pad_start":
			press_pad(PAD_START)
		_:
			fail_test("no such way to resume: %s" % method)


## Real seconds on physics ticks, the game running or not.
func _step_for(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame


func _shown_room() -> Room:
	return town().get_room() if town() != null else floor_scene().get_room()


func _sim() -> CombatSim:
	return _shown_room().get_runner().get_sim()


## Where the player, the enemies and their projectiles are.
func _positions() -> Array:
	var list: Array = [player().global_position]
	for node: Enemy in _shown_room().get_enemies():
		list.append(node.global_position)
		for bolt: ProjectileSet.Projectile in node.logic.get_projectiles().get_projectiles():
			list.append(bolt.position)
	return list


## What a pause must not change.
func _world() -> Dictionary:
	return {
		"sim": JSON.stringify(_sim().to_dict()),
		"session": JSON.stringify(session().to_dict()),
		"positions": _positions(),
		"time": _sim().get_time(),
	}


func _drop_shell() -> void:
	shell().queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _first_difference(first: Array, second: Array) -> int:
	for index: int in mini(first.size(), second.size()):
		if first[index] != second[index]:
			return index
	return -1


## Pauses with Escape (inside a tick, from where a test stands), steps `frames` ticks of the stopped
## game and resumes with Escape. Leaves the test at the start of the first tick the game runs in.
func _pause_and_resume(frames: int) -> void:
	press_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	for _i: int in frames:
		await get_tree().physics_frame
	press_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING)
	await wait_for_guard()


## The town: the player walks into the north-west corner for CORNER_TICKS ticks and dashes every
## second, with one pause at tick `pause_at` (none when negative). At the start of each tick the
## sim's snapshot (its hash) and the player's position, and the full snapshot at the end.
func _corner_walk(pause_at: int) -> Dictionary:
	await spawn_shell_on(WaveFixtures.wave_tower(2))
	await start_game()
	var trace: Array = []
	var into: Vector2 = Vector2(-1.0, -1.0).normalized()
	for tick: int in CORNER_TICKS:
		trace.append([JSON.stringify(_sim().to_dict()).hash(), player().global_position])
		if tick == pause_at:
			await _pause_and_resume(CORNER_PAUSE_FRAMES)
		player().motor.submit(MoveCommand.new(into))
		player().motor.submit(AimCommand.new(into))
		if tick % 60 == 50:
			player().motor.submit(DashCommand.new())
		await get_tree().physics_frame
	var result: Dictionary = {"trace": trace, "final": JSON.stringify(_sim().to_dict())}
	await _drop_shell()
	return result


## The scripted commands of the fight: walk about, attack, dash, and keep the player alive.
func _fight_commands(tick: int) -> void:
	var move: Vector2 = Vector2.RIGHT
	if tick >= 150:
		move = Vector2.RIGHT.rotated(tick * 0.02)
	player().motor.submit(MoveCommand.new(move))
	player().motor.submit(AimCommand.new(move))
	if tick % 70 == 40:
		player().motor.submit(DashCommand.new())
	elif tick % 15 == 0:
		player().motor.submit(AttackCommand.new())
	if tick % 20 == 0:
		set_hp(max_hp())


## What is going on in the fight right now.
func _fight_flags() -> Dictionary:
	var attacking: bool = false
	var bolts: int = 0
	for node: Enemy in room().get_enemies():
		var state: EnemyLogic.State = node.logic.get_state()
		if state == EnemyLogic.State.WINDUP or state == EnemyLogic.State.ACTIVE:
			attacking = true
		bolts += node.logic.get_projectiles().get_projectiles().size()
	var waves: RoomWaves = room().get_waves()
	return {
		"dash": player().motor.get_state() == PlayerMotor.State.DASHING,
		"attack": attacking,
		"bolts": bolts,
		"pending": waves.get_pending().size() if waves != null else 0,
	}


## One fight on floor 1 of the wave tower, paused (Escape, 60 ticks, Escape) at each tick of
## `pauses`, or by the `[Pause kind, frames]` that `kinds` gives for that tick. The trace has, per
## tick, the sim's snapshot and where everything is; a run with pauses stops FIGHT_TAIL_TICKS after
## the last one.
func _fight(pauses: Array[int], kinds: Dictionary = {}) -> Dictionary:
	set_death_delay(100000.0)
	await spawn_shell_on(WaveFixtures.wave_tower(2))
	await start_game()
	await enter_floor_through_gate(1)
	var length: int = FIGHT_TICKS
	if not pauses.is_empty():
		var last: int = pauses.max()
		length = mini(last + FIGHT_TAIL_TICKS, FIGHT_TICKS)
	var trace: Array = []
	var flags: Array = []
	var flags_at_pause: Array = []
	for tick: int in length:
		trace.append([JSON.stringify(_sim().to_dict()).hash(), _positions()])
		flags.append(_fight_flags())
		if tick in pauses:
			flags_at_pause.append(flags[tick])
			if kinds.has(tick):
				await _pause_of(kinds[tick][0], kinds[tick][1])
			else:
				await _pause_and_resume(FIGHT_PAUSE_FRAMES)
		_fight_commands(tick)
		await get_tree().physics_frame
	var result: Dictionary = {"trace": trace, "flags": flags, "flags_at_pause": flags_at_pause}
	await _drop_shell()
	return result


## A tick of the reference fight with a dash during an enemy's attack (`want_dash`), or with a bolt
## in flight and a reinforcement on its way, from tick `from` on; -1 when there is none.
func _choose_pause(flags: Array, want_dash: bool, from: int) -> int:
	for want_pending: bool in [true, false]:
		for tick: int in range(from, flags.size() - FIGHT_TAIL_TICKS):
			var now: Dictionary = flags[tick]
			if want_dash and not (now["dash"] and now["attack"]):
				continue
			if not want_dash and now["bolts"] == 0:
				continue
			if want_pending and now["pending"] == 0:
				continue
			return tick
	return -1


## The slide of AC15 never paused: made once per script, and every paused slide is compared to it.
func _slide_reference_run() -> void:
	if _slide_reference.is_empty():
		_slide_reference = await _slide_walk({})


## The town: the player is put against the west wall and walks SLIDE_LEGS, a leg per
## SLIDE_LEG_TICKS ticks, with a dash every 60, for `ticks` ticks. `schedule` maps a tick to
## `[Pause kind, frames]`: the pause is taken at the start of that tick. At the start of each tick:
## the sim's snapshot (its hash) and where everything is; at the end the full snapshot.
func _slide_walk(schedule: Dictionary, ticks: int = SLIDE_TICKS) -> Dictionary:
	await spawn_shell_on(WaveFixtures.wave_tower(2))
	await start_game()
	put_player_at(SLIDE_START_TILES)
	var trace: Array = []
	for tick: int in ticks:
		trace.append([JSON.stringify(_sim().to_dict()).hash(), _positions()])
		if schedule.has(tick):
			await _pause_of(schedule[tick][0], schedule[tick][1])
		var leg: int = floori(float(tick) / SLIDE_LEG_TICKS) % SLIDE_LEGS.size()
		var move: Vector2 = SLIDE_LEGS[leg].normalized()
		player().motor.submit(MoveCommand.new(move))
		player().motor.submit(AimCommand.new(move))
		if tick % 60 == 50:
			player().motor.submit(DashCommand.new())
		await get_tree().physics_frame
	var result: Dictionary = {"trace": trace, "final": JSON.stringify(_sim().to_dict())}
	await _drop_shell()
	return result


## One pause of `kind` (Pause), `frames` ticks at each stop, from where a test stands (inside a
## tick), ended by a resume. Leaves the test at the start of the first tick the game runs in.
func _pause_of(kind: Pause, frames: int) -> void:
	var on_floor: bool = session().get_place() == TowerSession.Place.FLOOR
	var name_of_kind: String = Pause.keys()[kind]
	press_key(ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "paused (%s)" % name_of_kind)
	match kind:
		Pause.PLAIN:
			await _wait_ticks(frames)
			press_key(ESCAPE)
		Pause.ZERO:
			press_key(ESCAPE)
		Pause.SETTINGS:
			await _wait_ticks(frames)
			choose(ShellMenus.SETTINGS)
			choose(ShellMenus.SHAKE)
			choose(ShellMenus.FULLSCREEN)
			await _wait_ticks(frames)
			choose(ShellMenus.SHAKE)
			choose(ShellMenus.FULLSCREEN)
			choose(ShellMenus.BACK)
			choose(ShellMenus.RESUME)
		Pause.CONFIRM:
			choose(ShellMenus.LEAVE if on_floor else ShellMenus.QUIT_TO_TITLE)
			await _wait_ticks(frames)
			choose(ShellMenus.CANCEL)
			choose(ShellMenus.RESUME)
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "resumed (%s)" % name_of_kind)
	await wait_for_guard()


func _wait_ticks(ticks: int) -> void:
	for _i: int in ticks:
		await get_tree().physics_frame


## Three to ten pauses at seeded, distinct ticks from `first_tick` to `last_tick`, each of a seeded
## kind from RANDOM_KINDS and a seeded length.
func _random_schedule(first_tick: int, last_tick: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = RANDOM_SEED
	var schedule: Dictionary = {}
	var count: int = rng.randi_range(RANDOM_PAUSES_MIN, RANDOM_PAUSES_MAX)
	while schedule.size() < count:
		var tick: int = rng.randi_range(first_tick, last_tick)
		var kind: Pause = RANDOM_KINDS[rng.randi_range(0, RANDOM_KINDS.size() - 1)]
		var frames: int = RANDOM_FRAME_CHOICES[rng.randi_range(0, RANDOM_FRAME_CHOICES.size() - 1)]
		schedule[tick] = [kind, 0 if kind == Pause.ZERO else frames]
	return schedule


## Counts the `pause` presses that reach `_unhandled_input` (nobody consumed them).
class PauseSpy:
	extends Node
	var presses: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"pause"):
			presses += 1
