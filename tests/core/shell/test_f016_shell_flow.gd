extends GutTest
## F-016 T4 (AC19, C17): the Equipment state of ShellFlow. The table-driven test of every state
## times every method is in test_shell_flow; these are the rules of the new state by name.

## Every state but PAUSED, SETTINGS counted twice (reached from the title and from the pause menu).
const SITUATIONS: Array[String] = [
	"TITLE",
	"PLAYING",
	"SETTINGS_FROM_TITLE",
	"SETTINGS_FROM_PAUSED",
	"CONFIRM_LEAVE",
	"CONFIRM_QUIT",
	"DEAD",
	"EQUIPMENT",
]

var _flow: ShellFlow
var _emissions: Array = []


func before_each() -> void:
	_flow = ShellFlow.new()
	_emissions = []
	_flow.state_changed.connect(
		func(state: ShellFlow.State, previous: ShellFlow.State) -> void:
			_emissions.append([state, previous])
	)


func test_ac19_the_old_states_keep_their_numbers_and_equipment_is_last() -> void:
	assert_eq(ShellFlow.State.TITLE, 0)
	assert_eq(ShellFlow.State.PLAYING, 1)
	assert_eq(ShellFlow.State.PAUSED, 2)
	assert_eq(ShellFlow.State.SETTINGS, 3)
	assert_eq(ShellFlow.State.CONFIRM_LEAVE, 4)
	assert_eq(ShellFlow.State.CONFIRM_QUIT, 5)
	assert_eq(ShellFlow.State.DEAD, 6)
	assert_eq(ShellFlow.State.EQUIPMENT, 7)
	assert_eq(ShellFlow.State.values().size(), 8)


func test_ac19_equipment_is_reached_from_the_pause_menu_and_nowhere_else() -> void:
	_flow.start_game()
	_flow.pause(true)
	_emissions = []
	assert_true(_flow.open_equipment())
	assert_eq(_flow.get_state(), ShellFlow.State.EQUIPMENT)
	assert_eq(_emissions, [[ShellFlow.State.EQUIPMENT, ShellFlow.State.PAUSED]])


func test_ac19_every_state_but_the_pause_menu_refuses_to_open_it() -> void:
	for label: String in SITUATIONS:
		_flow = ShellFlow.new()
		_drive_to(label)
		var before: ShellFlow.State = _flow.get_state()
		var signals: Array = []
		_flow.state_changed.connect(
			func(state: ShellFlow.State, _previous: ShellFlow.State) -> void: signals.append(state)
		)
		assert_false(_flow.open_equipment(), "open_equipment() from %s" % label)
		assert_eq(_flow.get_state(), before, "%s: unchanged" % label)
		assert_eq(signals.size(), 0, "%s: no signal" % label)


func test_ac19_close_equipment_goes_back_to_the_pause_menu() -> void:
	_to_equipment()
	_emissions = []
	assert_true(_flow.close_equipment())
	assert_eq(_flow.get_state(), ShellFlow.State.PAUSED)
	assert_eq(_emissions, [[ShellFlow.State.PAUSED, ShellFlow.State.EQUIPMENT]])
	assert_true(_flow.is_game_paused(), "the game stays stopped")


func test_ac19_back_closes_the_equipment_menu_like_close_equipment() -> void:
	_to_equipment()
	_emissions = []
	assert_true(_flow.back())
	assert_eq(_flow.get_state(), ShellFlow.State.PAUSED)
	assert_eq(_emissions, [[ShellFlow.State.PAUSED, ShellFlow.State.EQUIPMENT]])


func test_ac19_close_equipment_is_refused_everywhere_else() -> void:
	assert_false(_flow.close_equipment(), "title")
	_flow.start_game()
	assert_false(_flow.close_equipment(), "playing")
	_flow.pause(true)
	assert_false(_flow.close_equipment(), "the pause menu")
	_flow.open_settings()
	assert_false(_flow.close_equipment(), "settings")
	assert_eq(_flow.get_state(), ShellFlow.State.SETTINGS)


func test_ac19_the_game_is_stopped_in_the_equipment_menu() -> void:
	_to_equipment()
	assert_true(_flow.is_game_paused())


func test_ac19_the_equipment_menu_has_no_way_to_play_or_to_the_other_menus_but_back() -> void:
	_to_equipment()
	assert_false(_flow.resume(), "resume")
	assert_false(_flow.open_settings(), "settings")
	assert_false(_flow.ask_leave(true), "leave")
	assert_false(_flow.ask_quit(), "quit")
	assert_false(_flow.cancel_confirm(), "cancel_confirm")
	assert_false(_flow.player_died(), "player_died")
	assert_false(_flow.pause(true), "pause")
	assert_eq(_flow.get_state(), ShellFlow.State.EQUIPMENT)


func test_ac19_the_settings_origin_is_untouched_by_the_equipment_menu() -> void:
	_flow.open_settings()
	_flow.close_settings()
	_flow.start_game()
	_flow.pause(true)
	_flow.open_equipment()
	_flow.close_equipment()
	assert_eq(_flow.get_settings_origin(), ShellFlow.State.TITLE)
	_flow.open_settings()
	assert_true(
		_flow.is_game_paused(), "settings from the pause menu after an equipment round trip"
	)
	_flow.close_settings()
	assert_eq(_flow.get_state(), ShellFlow.State.PAUSED)


func test_ac19_a_full_round_trip_ends_in_the_game() -> void:
	_to_equipment()
	_flow.back()
	assert_true(_flow.resume())
	assert_eq(_flow.get_state(), ShellFlow.State.PLAYING)
	assert_false(_flow.is_game_paused())


func _drive_to(situation: String) -> void:
	match situation:
		"TITLE":
			pass
		"PLAYING":
			_flow.start_game()
		"SETTINGS_FROM_TITLE":
			_flow.open_settings()
		"SETTINGS_FROM_PAUSED":
			_to_pause()
			_flow.open_settings()
		"CONFIRM_LEAVE":
			_to_pause()
			_flow.ask_leave(true)
		"CONFIRM_QUIT":
			_to_pause()
			_flow.ask_quit()
		"DEAD":
			_flow.start_game()
			_flow.player_died()
		"EQUIPMENT":
			_to_equipment()
		_:
			fail_test("unknown situation %s" % situation)


func _to_pause() -> void:
	_flow.start_game()
	_flow.pause(true)


func _to_equipment() -> void:
	_flow.start_game()
	_flow.pause(true)
	_flow.open_equipment()
