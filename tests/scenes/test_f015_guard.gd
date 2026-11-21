extends F015ShellTest
## F-015 T7 (AC16's resume and Start cases, C7): the input guard through the REAL main scene, with
## the player's input on. A menu choice that leads to PLAYING is made by a key that is also the dash
## (Space, pad A) or by a click that is also the attack, and the player reads "just pressed" in the
## first physics tick after the press: the shell holds the game back so that tick never reaches it.
##
## Each case spawns scenes/main.tscn (spawn_main_on_title(), the player's input on), gets to the
## menu (the pause menu after a Start, or the title screen), HOLDS the key (a person's press lasts
## frames, and a held key also reads as pressed; a tap would read "just pressed" too, see the
## helper's header) and watches the player for
## WATCH_TICKS ticks once the game runs again: no dash, no attack, nothing buffered, no cooldown,
## the pause menu closed. Rates: 30, 60 and 120 physics ticks/s. At 60 two more timings, each
## ASSERTED before the guard is (a case whose timing was not produced is thrown away and tried
## again, and the test fails if it never is): TICKLESS, where three or more process frames pass
## between the press and the next tick, and STALLED, where the main thread is blocked right after
## the press so that the next frame runs two or more ticks. The test counts what it really got: a
## listener on `process_frame` and `physics_frame` logs every frame and every tick from the press
## on.
## A press posted inside a tick (IN_TICK) is guarded too.

enum Timing { BETWEEN, TICKLESS, STALLED, IN_TICK }

const PAD_A: JoyButton = JOY_BUTTON_A
const PAD_START: JoyButton = JOY_BUTTON_START
const RATES: Array[int] = [30, 60, 120]
const SLOW_RATE: int = 60
## Ticks the player is watched for once the game runs again.
const WATCH_TICKS: int = 10
## The ticks the guard takes, as far as this test needs it: a limit, not the guard's own number.
const GUARD_LIMIT_TICKS: int = 20
## TICKLESS: process frames with no tick between the press and the next tick, at least. A headless
## frame takes about 6 ms, so at 60 ticks/s (16.7 ms) two frames at most fall between ticks. So
## right after the press, for TICKLESS_FRAMES + 1 frames, the tick rate is TICKLESS_HOLD_RATE (a
## tick is due every second: none comes), then it is the case's rate again: the next tick is the
## first one, at the rate and with the delta under test. (`Engine.time_scale` does not do it: it
## scales the delta.) Start with TICKLESS runs on a one-floor fixture tower: building the shipped
## one blocks the thread for 0.8 s and, with the hold after it, the camera's canvas transform was
## seen to turn NaN when the rate came back (observed, cause not looked into; STALLED has the same
## stall and is clean).
const TICKLESS_FRAMES: int = 3
const TICKLESS_HOLD_RATE: int = 1
## STALLED: ticks in the frame after the press, at least; and how long the thread is blocked, in
## ticks of the rate in use.
const STALLED_TICKS: int = 2
const STALL_IN_TICKS: float = 3.5
## Attempts a timing gets before the test calls it not produced (a thread that hiccups at the wrong
## moment: the timings are made on purpose, they were produced at the first attempt in every run).
const MAX_ATTEMPTS: int = 3
const GUARD_CLICK_AT: Vector2 = Vector2(5.0, 5.0)
## Ticks a held movement key is watched for after a resume.
const WALK_TICKS: int = 20
const WALK_MIN_PX: float = 2.0

var _jitter_before: float
var _guard_click_down: bool = false


## The ticks and the frames, in the order the main loop ran them. "F" is a process frame, "T" a
## physics tick. A frame's ticks come before its process step.
class FrameLog:
	extends RefCounted
	var events: PackedStringArray = []

	func on_frame() -> void:
		events.append("F")

	func on_tick() -> void:
		events.append("T")

	## Process frames that ran before the first tick: the frames with no tick after the press.
	func frames_before_first_tick() -> int:
		var count: int = 0
		for event: String in events:
			if event == "T":
				break
			count += 1
		return count

	## Ticks that ran before the first process frame: the ticks of the frame after the press.
	func ticks_before_first_frame() -> int:
		var count: int = 0
		for event: String in events:
			if event == "F":
				break
			count += 1
		return count


class Tally:
	extends RefCounted
	var count: int = 0

	func bump() -> void:
		count += 1


func before_each() -> void:
	super.before_each()
	_jitter_before = Engine.physics_jitter_fix
	Engine.physics_jitter_fix = 0.0  # Ticks come at the rate, not smoothed.
	_guard_click_down = false


func after_each() -> void:
	_release_guard_click()
	Engine.physics_jitter_fix = _jitter_before
	await super.after_each()  # Lets go of the keys and pads, and puts the tick rate back.


# --- AC16: resuming ---


func test_resume_by_space_does_not_dash() -> void:
	await _run_every_timing(false, &"space")


func test_resume_by_pad_a_does_not_dash() -> void:
	await _run_every_timing(false, &"pad_a")


func test_resume_by_enter_does_not_dash() -> void:
	await _run_every_timing(false, &"enter")


func test_resume_by_a_click_does_not_attack() -> void:
	await _run_every_timing(false, &"click")


func test_resume_by_escape_does_not_dash_attack_or_pause_again() -> void:
	await _run_every_timing(false, &"escape")


func test_resume_by_pad_start_does_not_dash_attack_or_pause_again() -> void:
	await _run_every_timing(false, &"pad_start")


# --- AC16: Start on the title ---


func test_start_by_space_does_not_dash() -> void:
	await _run_every_timing(true, &"space")


func test_start_by_pad_a_does_not_dash() -> void:
	await _run_every_timing(true, &"pad_a")


func test_start_by_enter_does_not_dash() -> void:
	await _run_every_timing(true, &"enter")


func test_start_by_a_click_does_not_attack() -> void:
	await _run_every_timing(true, &"click")


# --- AC16: a press posted inside a tick ---


func test_a_press_posted_inside_a_tick_is_guarded_on_resume() -> void:
	for entry: StringName in [&"space", &"pad_a", &"click"]:
		await _run_case(false, entry, SLOW_RATE, Timing.IN_TICK)
		await _run_case(false, entry, RATES[2], Timing.IN_TICK)


func test_a_press_posted_inside_a_tick_is_guarded_on_start() -> void:
	for entry: StringName in [&"space", &"pad_a", &"click"]:
		await _run_case(true, entry, SLOW_RATE, Timing.IN_TICK)
		await _run_case(true, entry, RATES[2], Timing.IN_TICK)


# --- AC16: held keys, is_guarding() and pause ---


func test_a_movement_key_held_through_the_resume_moves_the_player() -> void:
	await spawn_main_on_title(_input_on())
	await start_game()
	await hold_key_between_ticks(KEY_D)
	for _i: int in 5:
		await get_tree().physics_frame
	await tap_key(KEY_ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	await get_tree().process_frame
	choose(ShellMenus.RESUME)
	await _assert_walks_on()


func test_a_movement_key_held_through_start_moves_the_player() -> void:
	await spawn_main_on_title(_input_on())
	await hold_key_between_ticks(KEY_D)
	choose(ShellMenus.START)
	_game = shell().get_game()
	await _assert_walks_on()


func test_is_guarding_from_the_choice_until_the_game_runs_and_pause_does_nothing_on_resume(
) -> void:
	await spawn_main_on_title(_input_on())
	await start_game()
	await tap_key(KEY_ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED)
	await get_tree().process_frame
	choose(ShellMenus.RESUME)
	await _assert_pause_is_refused_while_guarding()


func test_is_guarding_from_the_choice_until_the_game_runs_and_pause_does_nothing_on_start() -> void:
	await spawn_main_on_title(_input_on())
	await get_tree().process_frame
	choose(ShellMenus.START)
	_game = shell().get_game()
	await _assert_pause_is_refused_while_guarding()


# --- the cases ---


## Every rate with the press between two ticks, then the two extra timings at 60.
func _run_every_timing(starting: bool, entry: StringName) -> void:
	for rate: int in RATES:
		await _run_case(starting, entry, rate, Timing.BETWEEN)
	await _run_case(starting, entry, SLOW_RATE, Timing.TICKLESS)
	await _run_case(starting, entry, SLOW_RATE, Timing.STALLED)


## One case, run again from a fresh main scene (up to MAX_ATTEMPTS) until its timing was produced.
func _run_case(starting: bool, entry: StringName, rate: int, timing: Timing) -> void:
	var label: String = (
		"%s by %s at %d ticks/s, %s"
		% ["Start" if starting else "resume", entry, rate, Timing.find_key(timing)]
	)
	for _attempt: int in MAX_ATTEMPTS:
		if await _attempt_case(starting, entry, rate, timing, label):
			return
	fail_test("%s: the timing was not produced in %d attempts" % [label, MAX_ATTEMPTS])


## Spawns, gets to the menu, presses, counts the frames and ticks, and (when the timing is the one
## asked for) lets the guard be judged. Returns whether the timing was produced.
func _attempt_case(
	starting: bool, entry: StringName, rate: int, timing: Timing, label: String
) -> bool:
	Engine.physics_ticks_per_second = rate
	var fixture: bool = starting and timing == Timing.TICKLESS
	await spawn_main_on_title(_input_on(TowerFixtures.tower_of(1, 1) if fixture else null))
	if not starting:
		await start_game()
		await tap_key(KEY_ESCAPE)
		assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "%s: paused first" % label)
		await get_tree().physics_frame
	await _wait_for_the_slot(timing)
	var frames: FrameLog = FrameLog.new()
	get_tree().process_frame.connect(frames.on_frame)
	get_tree().physics_frame.connect(frames.on_tick)
	_press(entry, ShellMenus.START if starting else ShellMenus.RESUME)
	if starting:
		_game = shell().get_game()
	_assert_the_choice_is_held(label)
	var dashes: Tally = Tally.new()
	if player() != null:
		player().motor.dash_started.connect(dashes.bump)
	if timing == Timing.STALLED:
		OS.delay_usec(int(STALL_IN_TICKS * 1000000.0 / rate))
	if timing == Timing.TICKLESS:
		Engine.physics_ticks_per_second = TICKLESS_HOLD_RATE
		for _i: int in TICKLESS_FRAMES + 1:
			await get_tree().process_frame
		Engine.physics_ticks_per_second = rate
	await get_tree().physics_frame  # The first tick after the press...
	await get_tree().process_frame  # ...and the end of its frame.
	get_tree().process_frame.disconnect(frames.on_frame)
	get_tree().physics_frame.disconnect(frames.on_tick)
	var produced: bool = _timing_was_produced(timing, frames)
	if produced:
		_assert_the_timing(label, timing, frames)
		await _assert_the_player_stays_still(label, dashes)
	await _dispose_of_the_scene()
	return produced


## The timing is asserted first; a case whose timing is not the one asked for is not judged.
func _timing_was_produced(timing: Timing, frames: FrameLog) -> bool:
	match timing:
		Timing.TICKLESS:
			return frames.frames_before_first_tick() >= TICKLESS_FRAMES
		Timing.STALLED:
			return frames.ticks_before_first_frame() >= STALLED_TICKS
	return true


## The timing, as the log counted it: asserted before the guard is judged.
func _assert_the_timing(label: String, timing: Timing, frames: FrameLog) -> void:
	match timing:
		Timing.TICKLESS:
			var tickless: int = frames.frames_before_first_tick()
			assert_gte(tickless, TICKLESS_FRAMES, "%s: frames with no tick after the press" % label)
		Timing.STALLED:
			var ticks: int = frames.ticks_before_first_frame()
			assert_gte(ticks, STALLED_TICKS, "%s: ticks in the frame after the press" % label)


## BETWEEN: a process frame, where the OS delivers an event. TICKLESS: the process step of the
## frame that has just had a tick, so the next tick is a whole tick away. STALLED: as BETWEEN, the
## thread is blocked after the press. IN_TICK: the start of a tick, before the nodes' own.
func _wait_for_the_slot(timing: Timing) -> void:
	match timing:
		Timing.IN_TICK:
			await get_tree().physics_frame
		Timing.TICKLESS:
			await get_tree().physics_frame
			await get_tree().process_frame
		_:
			await get_tree().process_frame


## The choice has been made by the press: the flow is PLAYING, nothing else changed it, the menu is
## shut, and the game is built and held back.
func _assert_the_choice_is_held(label: String) -> void:
	assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "%s: one press, one step" % label)
	assert_true(shell().is_guarding(), "%s: guarding from the choice" % label)
	assert_not_null(shell().get_game(), "%s: the game is built" % label)
	assert_eq(
		shell().get_game().process_mode,
		Node.PROCESS_MODE_DISABLED,
		"%s: and held back by the choice" % label
	)
	assert_false(panel().is_open(), "%s: the menu is shut" % label)


## After the guard: ten ticks of a player who must not have acted.
func _assert_the_player_stays_still(label: String, dashes: Tally) -> void:
	await wait_for_guard()
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT, "%s: the game runs again" % label)
	assert_not_null(player(), "%s: the player is there" % label)
	for tick: int in WATCH_TICKS:
		await get_tree().physics_frame
		_assert_no_action("%s, tick %d" % [label, tick])
	assert_eq(dashes.count, 0, "%s: no dash started" % label)
	assert_eq(
		flow().get_state(), ShellFlow.State.PLAYING, "%s: the pause did not come back" % label
	)
	assert_false(panel().is_open(), "%s: and no menu opened" % label)


func _assert_no_action(label: String) -> void:
	var motor: PlayerMotor = player().motor
	assert_ne(motor.get_state(), PlayerMotor.State.DASHING, "%s: dashing" % label)
	assert_ne(motor.get_state(), PlayerMotor.State.ATTACKING, "%s: attacking" % label)
	assert_false(motor.has_buffered_dash(), "%s: a dash is buffered" % label)
	assert_false(motor.has_buffered_attack(), "%s: an attack is buffered" % label)
	assert_eq(motor.get_cooldown_remaining(), 0.0, "%s: a dash is cooling down" % label)
	assert_eq(motor.get_attack_chain().get_next_index(), 0, "%s: an attack was thrown" % label)


## A key down that is also the dash and a movement key held through the choice: the player walks.
func _assert_walks_on() -> void:
	await wait_for_guard()
	var at: Vector2 = player().global_position
	for _i: int in WALK_TICKS:
		await get_tree().physics_frame
	assert_gt(player().global_position.x, at.x + WALK_MIN_PX, "the held key walks the player")
	assert_ne(player().motor.get_state(), PlayerMotor.State.DASHING)


## Escape and pad Start are pressed in every tick from the choice until the game runs: nothing
## happens, and is_guarding() is exactly the time the game is held back.
func _assert_pause_is_refused_while_guarding() -> void:
	assert_true(shell().is_guarding(), "guarding from the choice")
	watch_signals(flow())
	var ticks: int = 0
	while shell().is_guarding() and ticks < GUARD_LIMIT_TICKS:
		press_key(KEY_ESCAPE)
		press_pad(PAD_START)
		assert_eq(flow().get_state(), ShellFlow.State.PLAYING, "no pause in tick %d" % ticks)
		assert_eq(
			game().process_mode,
			Node.PROCESS_MODE_DISABLED,
			"held back while guarding, tick %d" % ticks
		)
		await get_tree().physics_frame
		ticks += 1
	assert_false(shell().is_guarding(), "the guard let the game run")
	assert_signal_not_emitted(flow(), "state_changed")
	assert_false(panel().is_open(), "and no pause menu opened")
	assert_eq(game().process_mode, Node.PROCESS_MODE_INHERIT)
	await tap_key(KEY_ESCAPE)
	assert_eq(flow().get_state(), ShellFlow.State.PAUSED, "pause is back once the game runs")


# --- the scene and the events ---


## What spawn_main_on_title() is given here: the player's input ON, and `tower` (null is the shipped
## tower) for the shell to build.
func _input_on(tower: TowerData = null) -> Callable:
	return func(shell_node: Shell) -> void:
		shell_node.tower_data = tower
		shell_node.player_input_enabled = true


## Lets go of what is held and frees the main scene, so the next attempt starts clean.
func _dispose_of_the_scene() -> void:
	release_held_keys()
	release_held_pads()
	_release_guard_click()
	if is_instance_valid(_main):
		_main.queue_free()
	await get_tree().process_frame


## At once, and held: the key or button stays down until _dispose_of_the_scene() or after_each().
## A click is the left mouse button (so `attack` is "just pressed") and, in the same frame, the
## panel's own `choose()`, which is what a click on the entry reaches (a positional click cannot get
## under GUT's layer).
func _press(entry: StringName, target: StringName) -> void:
	match entry:
		&"space":
			hold_key(KEY_SPACE)
		&"enter":
			hold_key(KEY_ENTER)
		&"escape":
			hold_key(KEY_ESCAPE)
		&"pad_a":
			hold_pad(PAD_A)
		&"pad_start":
			hold_pad(PAD_START)
		&"click":
			_post_guard_click(true)
			panel().choose(target)
		_:
			fail_test("no such entry: %s" % entry)


func _post_guard_click(pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = GUARD_CLICK_AT
	event.global_position = GUARD_CLICK_AT
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_guard_click_down = pressed


func _release_guard_click() -> void:
	if _guard_click_down:
		_post_guard_click(false)
