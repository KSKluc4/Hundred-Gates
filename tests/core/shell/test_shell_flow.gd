# gdlint:disable=max-public-methods
extends GutTest
## F-015 T1 (AC1, AC2): ShellFlow, the shell's state machine. Every method acts only from its
## "From" states and is refused (false, no signal, same state) from every other one (C2).

const STATES: Dictionary = {
	"TITLE": ShellFlow.State.TITLE,
	"PLAYING": ShellFlow.State.PLAYING,
	"PAUSED": ShellFlow.State.PAUSED,
	"SETTINGS": ShellFlow.State.SETTINGS,
	"CONFIRM_LEAVE": ShellFlow.State.CONFIRM_LEAVE,
	"CONFIRM_QUIT": ShellFlow.State.CONFIRM_QUIT,
	"DEAD": ShellFlow.State.DEAD,
}

# Every method of the C2 table, in the table's order.
const METHODS: Array[StringName] = [
	&"start_game",
	&"pause",
	&"resume",
	&"open_settings",
	&"close_settings",
	&"ask_leave",
	&"ask_quit",
	&"cancel_confirm",
	&"confirm_leave",
	&"confirm_quit",
	&"player_died",
	&"death_confirmed",
	&"back",
]

# A start situation is a state name, except that SETTINGS is two situations: reached from the
# title and reached from the pause menu.
const SITUATIONS: Array[String] = [
	"TITLE",
	"PLAYING",
	"PAUSED",
	"SETTINGS_FROM_TITLE",
	"SETTINGS_FROM_PAUSED",
	"CONFIRM_LEAVE",
	"CONFIRM_QUIT",
	"DEAD",
]

# method -> {situation -> the state it lands in}. A situation that is absent is refused.
const ACTS: Dictionary = {
	&"start_game": {"TITLE": "PLAYING"},
	&"pause": {"PLAYING": "PAUSED"},
	&"resume": {"PAUSED": "PLAYING"},
	&"open_settings": {"TITLE": "SETTINGS", "PAUSED": "SETTINGS"},
	&"close_settings": {"SETTINGS_FROM_TITLE": "TITLE", "SETTINGS_FROM_PAUSED": "PAUSED"},
	&"ask_leave": {"PAUSED": "CONFIRM_LEAVE"},
	&"ask_quit": {"PAUSED": "CONFIRM_QUIT"},
	&"cancel_confirm": {"CONFIRM_LEAVE": "PAUSED", "CONFIRM_QUIT": "PAUSED"},
	&"confirm_leave": {"CONFIRM_LEAVE": "PLAYING"},
	&"confirm_quit": {"CONFIRM_QUIT": "TITLE"},
	&"player_died": {"PLAYING": "DEAD"},
	&"death_confirmed": {"DEAD": "PLAYING"},
	&"back":
	{
		"PAUSED": "PLAYING",
		"SETTINGS_FROM_TITLE": "TITLE",
		"SETTINGS_FROM_PAUSED": "PAUSED",
		"CONFIRM_LEAVE": "PAUSED",
		"CONFIRM_QUIT": "PAUSED",
	},
}

# Situations in which the game below the shell is disabled (C6, is_game_paused()).
const GAME_PAUSED: Array[String] = [
	"PAUSED",
	"SETTINGS_FROM_PAUSED",
	"CONFIRM_LEAVE",
	"CONFIRM_QUIT",
]

var _flow: ShellFlow
var _emissions: Array = []


func before_each() -> void:
	_flow = ShellFlow.new()
	_emissions = []


func _on_state_changed(state: ShellFlow.State, previous: ShellFlow.State) -> void:
	_emissions.append([state, previous])


func _watch() -> void:
	_flow.state_changed.connect(_on_state_changed)


## Drives a new flow to a situation through its own methods.
func _drive_to(situation: String) -> void:
	match situation:
		"TITLE":
			pass
		"PLAYING":
			_flow.start_game()
		"PAUSED":
			_flow.start_game()
			_flow.pause(true)
		"SETTINGS_FROM_TITLE":
			_flow.open_settings()
		"SETTINGS_FROM_PAUSED":
			_flow.start_game()
			_flow.pause(true)
			_flow.open_settings()
		"CONFIRM_LEAVE":
			_flow.start_game()
			_flow.pause(true)
			_flow.ask_leave(true)
		"CONFIRM_QUIT":
			_flow.start_game()
			_flow.pause(true)
			_flow.ask_quit()
		"DEAD":
			_flow.start_game()
			_flow.player_died()
		_:
			fail_test("unknown start situation %s" % situation)


func _state_of(situation: String) -> ShellFlow.State:
	if situation.begins_with("SETTINGS"):
		return ShellFlow.State.SETTINGS
	return STATES[situation]


## Calls one method; the two gated ones get `true` so that only the state can refuse.
func _call(method: StringName) -> bool:
	if method == &"pause" or method == &"ask_leave":
		return _flow.call(method, true)
	return _flow.call(method)


# --- AC1: the table ---


func test_ac1_starts_in_title() -> void:
	assert_eq(_flow.get_state(), ShellFlow.State.TITLE)


func test_ac1_the_table_covers_all_13_methods_and_8_start_situations() -> void:
	assert_eq(METHODS.size(), 13)
	assert_eq(ACTS.size(), 13)
	assert_eq(SITUATIONS.size(), 8, "7 states, SETTINGS counted twice")
	for method: StringName in METHODS:
		assert_true(ACTS.has(method), "the table lists %s" % method)
		assert_true(_flow.has_method(method), "ShellFlow has %s()" % method)


func test_ac1_every_state_times_every_method_acts_or_is_refused() -> void:
	var checked: int = 0
	for situation: String in SITUATIONS:
		for method: StringName in METHODS:
			_flow = ShellFlow.new()
			_emissions = []
			_drive_to(situation)
			var before: ShellFlow.State = _flow.get_state()
			assert_eq(before, _state_of(situation), "%s: driven to the right state" % situation)
			_watch()
			var acted: bool = _call(method)
			var label: String = "%s from %s" % [method, situation]
			var table: Dictionary = ACTS[method]
			if table.has(situation):
				var expected: ShellFlow.State = STATES[table[situation]]
				assert_true(acted, "%s acts" % label)
				assert_eq(_flow.get_state(), expected, "%s: new state" % label)
				assert_eq(_emissions.size(), 1, "%s: one signal" % label)
				if _emissions.size() == 1:
					assert_eq(_emissions[0][0], expected, "%s: signal's state" % label)
					assert_eq(_emissions[0][1], before, "%s: signal's previous" % label)
			else:
				assert_false(acted, "%s is refused" % label)
				assert_eq(_flow.get_state(), before, "%s: state unchanged" % label)
				assert_eq(_emissions.size(), 0, "%s: no signal" % label)
			checked += 1
	assert_eq(checked, 8 * 13, "every pair was checked")


func test_ac1_pause_is_refused_when_it_cannot_pause() -> void:
	_drive_to("PLAYING")
	_watch()
	assert_false(_flow.pause(false))
	assert_eq(_flow.get_state(), ShellFlow.State.PLAYING)
	assert_eq(_emissions.size(), 0)


func test_ac1_pause_works_after_a_refused_pause() -> void:
	_drive_to("PLAYING")
	_flow.pause(false)
	assert_true(_flow.pause(true))
	assert_eq(_flow.get_state(), ShellFlow.State.PAUSED)


func test_ac1_ask_leave_is_refused_when_not_on_a_floor() -> void:
	_drive_to("PAUSED")
	_watch()
	assert_false(_flow.ask_leave(false))
	assert_eq(_flow.get_state(), ShellFlow.State.PAUSED)
	assert_eq(_emissions.size(), 0)


func test_ac1_ask_leave_works_after_a_refused_ask() -> void:
	_drive_to("PAUSED")
	_flow.ask_leave(false)
	assert_true(_flow.ask_leave(true))
	assert_eq(_flow.get_state(), ShellFlow.State.CONFIRM_LEAVE)


func test_ac1_a_false_argument_in_the_wrong_state_is_refused_too() -> void:
	_watch()
	assert_false(_flow.pause(false), "TITLE, false")
	assert_false(_flow.ask_leave(false), "TITLE, false")
	assert_eq(_flow.get_state(), ShellFlow.State.TITLE)
	assert_eq(_emissions.size(), 0)


func test_ac1_the_signal_carries_the_new_state_then_the_previous_one() -> void:
	_watch()
	_flow.start_game()
	_flow.pause(true)
	_flow.open_settings()
	_flow.close_settings()
	assert_eq(
		_emissions,
		[
			[ShellFlow.State.PLAYING, ShellFlow.State.TITLE],
			[ShellFlow.State.PAUSED, ShellFlow.State.PLAYING],
			[ShellFlow.State.SETTINGS, ShellFlow.State.PAUSED],
			[ShellFlow.State.PAUSED, ShellFlow.State.SETTINGS],
		]
	)


func test_ac1_the_signal_is_emitted_after_the_state_has_changed() -> void:
	var seen: Array[ShellFlow.State] = []
	_flow.state_changed.connect(
		func(_state: ShellFlow.State, _previous: ShellFlow.State) -> void:
			seen.append(_flow.get_state())
	)
	_flow.start_game()
	assert_eq(seen, [ShellFlow.State.PLAYING], "a listener asking get_state() sees the new state")


func test_ac1_a_game_can_start_again_after_a_quit() -> void:
	assert_true(_flow.start_game())
	assert_true(_flow.pause(true))
	assert_true(_flow.ask_quit())
	assert_true(_flow.confirm_quit())
	assert_eq(_flow.get_state(), ShellFlow.State.TITLE)
	assert_true(_flow.start_game())


func test_ac1_the_player_can_die_again_after_confirming_a_death() -> void:
	_drive_to("DEAD")
	assert_true(_flow.death_confirmed())
	assert_true(_flow.player_died())
	assert_eq(_flow.get_state(), ShellFlow.State.DEAD)


# --- AC2: settings origin, is_game_paused(), back() ---


func test_ac2_settings_from_title_returns_to_title() -> void:
	assert_true(_flow.open_settings())
	assert_eq(_flow.get_settings_origin(), ShellFlow.State.TITLE)
	assert_true(_flow.close_settings())
	assert_eq(_flow.get_state(), ShellFlow.State.TITLE)


func test_ac2_settings_from_pause_returns_to_pause() -> void:
	_drive_to("PAUSED")
	assert_true(_flow.open_settings())
	assert_eq(_flow.get_settings_origin(), ShellFlow.State.PAUSED)
	assert_true(_flow.close_settings())
	assert_eq(_flow.get_state(), ShellFlow.State.PAUSED)


func test_ac2_the_origin_follows_the_latest_open_settings() -> void:
	_flow.open_settings()
	assert_eq(_flow.get_settings_origin(), ShellFlow.State.TITLE)
	_flow.close_settings()
	_flow.start_game()
	_flow.pause(true)
	_flow.open_settings()
	assert_eq(_flow.get_settings_origin(), ShellFlow.State.PAUSED)
	_flow.close_settings()
	_flow.resume()
	_flow.pause(true)
	_flow.ask_quit()
	_flow.confirm_quit()
	_flow.open_settings()
	assert_eq(_flow.get_settings_origin(), ShellFlow.State.TITLE, "a title after a quit")
	assert_true(_flow.close_settings())
	assert_eq(_flow.get_state(), ShellFlow.State.TITLE)


func test_ac2_is_game_paused_is_false_for_settings_from_the_title_and_true_from_the_pause() -> void:
	_drive_to("SETTINGS_FROM_TITLE")
	assert_false(_flow.is_game_paused())
	_flow = ShellFlow.new()
	_drive_to("SETTINGS_FROM_PAUSED")
	assert_true(_flow.is_game_paused())


func test_ac2_is_game_paused_in_every_situation() -> void:
	for situation: String in SITUATIONS:
		_flow = ShellFlow.new()
		_drive_to(situation)
		assert_eq(_flow.is_game_paused(), GAME_PAUSED.has(situation), situation)


func test_ac2_is_game_paused_follows_a_settings_round_trip() -> void:
	_drive_to("PAUSED")
	_flow.open_settings()
	assert_true(_flow.is_game_paused(), "settings over the pause menu")
	_flow.close_settings()
	_flow.resume()
	assert_false(_flow.is_game_paused(), "playing")


func test_ac2_back_in_every_situation() -> void:
	var expected: Dictionary = ACTS[&"back"]
	for situation: String in SITUATIONS:
		_flow = ShellFlow.new()
		_emissions = []
		_drive_to(situation)
		var before: ShellFlow.State = _flow.get_state()
		_watch()
		var acted: bool = _flow.back()
		if expected.has(situation):
			var target: ShellFlow.State = STATES[expected[situation]]
			assert_true(acted, "back() from %s acts" % situation)
			assert_eq(
				_flow.get_state(),
				target,
				"back() from %s lands in %s" % [situation, expected[situation]]
			)
			assert_eq(_emissions, [[target, before]], "back() from %s: one signal" % situation)
		else:
			assert_false(acted, "back() from %s is refused" % situation)
			assert_eq(_flow.get_state(), before, "back() from %s changes nothing" % situation)
			assert_eq(_emissions.size(), 0, "back() from %s emits nothing" % situation)


func test_ac2_back_is_false_in_title_playing_and_dead() -> void:
	for situation: String in ["TITLE", "PLAYING", "DEAD"]:
		_flow = ShellFlow.new()
		_drive_to(situation)
		assert_false(_flow.back(), situation)


func test_ac2_back_from_a_confirm_lands_in_the_pause_menu_not_in_the_game() -> void:
	_drive_to("CONFIRM_LEAVE")
	_flow.back()
	assert_eq(_flow.get_state(), ShellFlow.State.PAUSED)
	assert_true(_flow.is_game_paused())
