# gdlint:disable=max-public-methods,max-file-lines
extends GutTest
## F-012 T5 (AC23): the gate menu. The keys and the stick go through the engine's input path
## (Input.parse_input_event), so `_input` is what answers them. The town scene's use of the menu
## is tested in test_f012_town. Whatever a test presses, after_each lets go of (CR-10).

const MENU_SCENE: PackedScene = preload("res://src/ui/town/gate_menu.tscn")
const LIST_PATH: NodePath = ^"Panel/List"
## A real stick passes through every value on its way: these cross the two deadzones of an up or a
## down (`move_*` 0.2, built-in `ui_*` 0.5) on different events (F-012/CR-3, review round 2).
const RAMP: Array[float] = [0.1, 0.3, 0.45, 0.7, 1.0]
## F-012/CR-18: a new town, so a new menu, is built on every return from a floor, and a stick held
## at a constant value sends no event. Some tests push the stick BEFORE the menu exists and then
## let go like this.
const RELEASE: Array[float] = [0.8, 0.4, 0.1, 0.0]
const HANDLED_ACTIONS: Array[StringName] = [
	&"ui_up",
	&"ui_down",
	&"move_up",
	&"move_down",
	&"ui_accept",
	&"interact",
	&"ui_cancel",
	&"ui_left",
	&"ui_right",
]

var _menu: GateMenu
var _chosen: Array[Vector2i] = []
var _closed: int = 0
var _held_keys: Array[Key] = []
var _held_pad_buttons: Array[JoyButton] = []
var _stick_axes: Array[JoyAxis] = []


func before_each() -> void:
	_chosen = []
	_closed = 0
	_held_keys = []
	_held_pad_buttons = []
	_stick_axes = []


## Leaves no pressed action or tilted stick behind for the next test.
func after_each() -> void:
	for key: Key in _held_keys:
		_send_key(key, false)
	for button: JoyButton in _held_pad_buttons:
		_send_pad_button(button, false)
	for axis: JoyAxis in _stick_axes:
		_send_stick(axis, 0.0, 1)
	Input.flush_buffered_events()
	for action: StringName in HANDLED_ACTIONS:
		assert_false(Input.is_action_pressed(action), "%s let go of" % action)
	# F-012/CR-22: the buttons a second open() replaced are queued, not gone, until the frame ends.
	await get_tree().process_frame


func test_ac23_entry_text_for_a_floor_from_its_start() -> void:
	assert_eq(GateMenu.entry_text(_entry(1, false, false)), "Floor 1 — from the start")
	assert_eq(GateMenu.entry_text(_entry(12, false, false)), "Floor 12 — from the start")


func test_ac23_entry_text_for_a_floor_at_its_boss() -> void:
	assert_eq(GateMenu.entry_text(_entry(1, true, false)), "Floor 1 — at the boss")


func test_ac23_entry_text_for_a_cleared_floor_ends_with_cleared() -> void:
	assert_eq(GateMenu.entry_text(_entry(2, false, true)), "Floor 2 — from the start (cleared)")
	assert_eq(GateMenu.entry_text(_entry(2, true, true)), "Floor 2 — at the boss (cleared)")


func test_ac23_the_menu_is_hidden_until_it_is_opened() -> void:
	_spawn_menu()
	assert_false(_menu.visible)
	assert_false(_menu.is_open())
	assert_eq(_menu.get_entry_count(), 0)
	assert_eq(_button_texts(), [] as Array[String], "nothing is listed yet")


func test_ac23_open_lists_every_entry_in_order_then_the_stay_entry() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	assert_true(_menu.is_open())
	assert_true(_menu.visible)
	assert_eq(_menu.get_entry_count(), 3, "the stay entry is not counted")
	var expected: Array[String] = [
		"Floor 1 — from the start (cleared)",
		"Floor 1 — at the boss (cleared)",
		"Floor 2 — from the start",
		"Stay in town",
	]
	assert_eq(_button_texts(), expected)


func test_ac23_the_focus_starts_on_the_last_floor_entry() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	assert_eq(_menu.get_focus_index(), 2)
	assert_true(_buttons()[2].has_focus(), "and the button really has it")


func test_ac23_with_no_entries_the_focus_starts_on_the_stay_entry() -> void:
	_spawn_menu()
	var none: Array[TowerEntry] = []
	_menu.open(none)
	assert_eq(_menu.get_entry_count(), 0)
	assert_eq(_button_texts(), ["Stay in town"] as Array[String])
	assert_eq(_menu.get_focus_index(), 0)
	assert_true(_buttons()[0].has_focus())


func test_ac23_ui_up_and_ui_down_move_the_focus() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press(&"ui_up")
	assert_eq(_menu.get_focus_index(), 1)
	assert_true(_buttons()[1].has_focus())
	_press(&"ui_up")
	assert_eq(_menu.get_focus_index(), 0)
	_press(&"ui_down")
	assert_eq(_menu.get_focus_index(), 1)
	_press(&"ui_down")
	_press(&"ui_down")
	assert_eq(_menu.get_focus_index(), 3, "down reaches the stay entry")


func test_ac23_move_up_and_move_down_move_the_focus_too() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press(&"move_up")
	assert_eq(_menu.get_focus_index(), 1)
	_press(&"move_up")
	assert_eq(_menu.get_focus_index(), 0)
	_press(&"move_down")
	_press(&"move_down")
	_press(&"move_down")
	assert_eq(_menu.get_focus_index(), 3)


func test_ac23_the_focus_stops_at_both_ends() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	for _i: int in 6:
		_press(&"ui_up")
	assert_eq(_menu.get_focus_index(), 0, "no wrapping to the stay entry")
	for _i: int in 6:
		_press(&"ui_down")
	assert_eq(_menu.get_focus_index(), 3, "no wrapping to the first entry")


func test_ac23_ui_accept_chooses_the_focused_entry() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press(&"ui_up")
	_press(&"ui_accept")
	assert_eq(_chosen, [Vector2i(1, 1)] as Array[Vector2i], "floor 1, at the boss")
	assert_false(_menu.is_open(), "choosing closes the menu")
	assert_eq(_closed, 0, "and that is not a cancel")


func test_ac23_interact_chooses_the_focused_entry() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press(&"interact")
	assert_eq(_chosen, [Vector2i(2, 0)] as Array[Vector2i], "floor 2, from the start")
	assert_false(_menu.is_open())
	assert_eq(_closed, 0)


func test_ac23_choosing_with_the_focus_on_the_stay_entry_closes_without_a_choice() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press(&"ui_down")
	assert_eq(_menu.get_focus_index(), 3)
	_press(&"ui_accept")
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_eq(_closed, 1)
	assert_false(_menu.is_open())


func test_ac23_ui_cancel_closes_without_a_choice() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press(&"ui_cancel")
	assert_eq(_closed, 1)
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_false(_menu.is_open())
	assert_false(_menu.visible)


func test_ac23_a_click_on_an_entry_is_the_same_choice() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_buttons()[0].pressed.emit()
	assert_eq(_chosen, [Vector2i(1, 0)] as Array[Vector2i])
	assert_eq(_closed, 0)
	assert_false(_menu.is_open())


func test_ac23_a_click_on_the_stay_entry_is_a_cancel() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_buttons()[3].pressed.emit()
	assert_eq(_closed, 1)
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_false(_menu.is_open())


func test_ac23_choose_emits_once_and_closes_without_closed() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_menu.choose(1)
	assert_eq(_chosen, [Vector2i(1, 1)] as Array[Vector2i])
	assert_eq(_closed, 0)
	assert_false(_menu.is_open())
	_menu.choose(1)
	assert_eq(_chosen.size(), 1, "a second choose on a closed menu does nothing")


func test_ac23_choose_with_an_index_outside_the_floor_entries_does_nothing() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_menu.choose(-1)
	_menu.choose(3)  # The stay entry is not a floor entry.
	_menu.choose(99)
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_eq(_closed, 0)
	assert_true(_menu.is_open(), "and the menu is still there")


func test_ac23_cancel_closes_and_emits_closed_once() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_menu.cancel()
	assert_eq(_closed, 1)
	assert_false(_menu.is_open())
	_menu.cancel()
	assert_eq(_closed, 1, "a second cancel on a closed menu does nothing")
	assert_eq(_chosen, [] as Array[Vector2i])


func test_ac23_close_hides_the_menu_without_a_signal() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_menu.close()
	assert_false(_menu.is_open())
	assert_false(_menu.visible)
	assert_eq(_closed, 0)
	assert_eq(_chosen, [] as Array[Vector2i])


func test_ac23_while_closed_the_menu_handles_no_input_at_all() -> void:
	_spawn_menu()
	var spy: InputSpy = _spy_on_unhandled_input()
	for action: StringName in [&"ui_up", &"ui_down", &"move_up", &"move_down"]:
		_press(action)
	for action: StringName in [&"ui_accept", &"interact", &"ui_cancel"]:
		_press(action)
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_eq(_closed, 0)
	assert_eq(spy.seen.size(), 7, "every event went by, unconsumed")
	_menu.open(_three_entries())
	_menu.close()
	spy.seen.clear()
	_press(&"ui_accept")
	_press(&"ui_cancel")
	assert_eq(spy.seen.size(), 2, "a menu that was closed again handles nothing either")
	assert_eq(_closed, 0)
	assert_eq(_chosen, [] as Array[Vector2i])


func test_ac23_while_open_the_menus_keys_are_consumed() -> void:
	_spawn_menu()
	var spy: InputSpy = _spy_on_unhandled_input()
	_menu.open(_three_entries())
	for action: StringName in [&"ui_up", &"ui_down", &"move_up", &"move_down"]:
		_press(action)
	_press(&"interact")  # Chooses, and closes.
	_menu.open(_three_entries())
	_press(&"ui_accept")
	_menu.open(_three_entries())
	_press(&"ui_cancel")
	assert_eq(spy.seen.size(), 0, "nothing behind the menu sees them")
	assert_eq(_chosen.size(), 2)
	assert_eq(_closed, 1)


func test_ac23_other_keys_pass_through_an_open_menu() -> void:
	_spawn_menu()
	var spy: InputSpy = _spy_on_unhandled_input()
	_menu.open(_three_entries())
	_press(&"debug_next_room")
	_press(&"attack")
	assert_eq(spy.seen.size(), 2, "the menu keeps only its own keys")
	assert_true(_menu.is_open())


func test_ac23_a_held_key_repeating_does_not_move_or_choose() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	for key: Key in [KEY_E, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
		_send_key(key, true, true)
	Input.flush_buffered_events()
	assert_true(_menu.is_open())
	assert_eq(_menu.get_focus_index(), 2)
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_eq(_closed, 0)


func test_ac23_a_held_key_moves_once_however_many_repeats_follow() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_send_key(KEY_UP, true)
	for _i: int in 4:
		_send_key(KEY_UP, true, true)
	_send_key(KEY_UP, false)
	Input.flush_buffered_events()
	assert_eq(_menu.get_focus_index(), 1, "the press moved, the repeats did not")


func test_ac23_the_helper_keys_match_both_action_families() -> void:
	# What the next tests stand on: one real key is an event for ui_* and for move_*.
	assert_true(_key_event(KEY_UP, true).is_action(&"ui_up"))
	assert_true(_key_event(KEY_UP, true).is_action(&"move_up"))
	assert_true(_key_event(KEY_DOWN, true).is_action(&"ui_down"))
	assert_true(_key_event(KEY_DOWN, true).is_action(&"move_down"))
	assert_true(_key_event(KEY_ENTER, true).is_action(&"ui_accept"))
	assert_true(_key_event(KEY_SPACE, true).is_action(&"ui_accept"))
	assert_true(_key_event(KEY_ESCAPE, true).is_action(&"ui_cancel"))
	assert_true(_key_event(KEY_E, true).is_action(&"interact"))


func test_ac23_one_up_arrow_press_moves_one_step_though_it_is_ui_up_and_move_up() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_UP)
	assert_eq(_menu.get_focus_index(), 1, "one step, not two")
	_press_key(KEY_UP)
	assert_eq(_menu.get_focus_index(), 0)


func test_ac23_one_down_arrow_press_moves_one_step() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_UP)
	_press_key(KEY_UP)
	_press_key(KEY_DOWN)
	assert_eq(_menu.get_focus_index(), 1)


func test_ac23_w_and_s_move_the_focus_too() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_W)
	assert_eq(_menu.get_focus_index(), 1)
	_press_key(KEY_S)
	assert_eq(_menu.get_focus_index(), 2)


func test_ac23_a_real_enter_press_chooses_once() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_ENTER)
	assert_eq(_chosen, [Vector2i(2, 0)] as Array[Vector2i])
	assert_eq(_closed, 0)
	assert_false(_menu.is_open())


func test_ac23_a_real_space_press_chooses_once() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_SPACE)
	assert_eq(_chosen, [Vector2i(2, 0)] as Array[Vector2i])
	assert_eq(_closed, 0)
	assert_false(_menu.is_open())


func test_ac23_a_real_e_press_chooses_once() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_UP)
	_press_key(KEY_E)
	assert_eq(_chosen, [Vector2i(1, 1)] as Array[Vector2i])
	assert_eq(_closed, 0)
	assert_false(_menu.is_open())


func test_ac23_a_real_escape_press_cancels_once() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_ESCAPE)
	assert_eq(_closed, 1)
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_false(_menu.is_open())


func test_ac23_one_stick_push_moves_one_step_however_many_events_it_sends() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, -0.1, 3)  # Inside the deadzone: nothing.
	assert_eq(_menu.get_focus_index(), 2)
	_send_stick(JOY_AXIS_LEFT_Y, -0.9, 5)
	assert_eq(_menu.get_focus_index(), 1, "five events, one push, one step")
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 3)
	assert_eq(_menu.get_focus_index(), 1, "still the same push")
	assert_true(_menu.is_open())


func test_ac23_one_stick_push_down_moves_one_step() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, 0.9, 5)
	assert_eq(_menu.get_focus_index(), 3)
	_send_stick(JOY_AXIS_LEFT_Y, 1.0, 3)
	assert_eq(_menu.get_focus_index(), 3, "the end of the list, and still one push")


func test_ac23_letting_go_of_the_stick_and_pushing_again_moves_a_second_step() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 4)
	assert_eq(_menu.get_focus_index(), 1)
	_send_stick(JOY_AXIS_LEFT_Y, 0.0, 1)
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 4)
	assert_eq(_menu.get_focus_index(), 0, "a second push, a second step")


func test_ac23_a_stick_pushed_down_then_up_returns_to_where_it_started() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_UP)
	assert_eq(_menu.get_focus_index(), 1)
	_send_stick(JOY_AXIS_LEFT_Y, 1.0, 3)
	assert_eq(_menu.get_focus_index(), 2)
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 3)  # Straight through, without a stop in the middle.
	assert_eq(_menu.get_focus_index(), 1)


func test_ac23_a_stick_held_while_the_list_opens_does_not_move_the_focus() -> void:
	_spawn_menu()
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 2)  # Walking up into the gate with the stick.
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 5)
	assert_eq(_menu.get_focus_index(), 2, "the focus stays on the last floor entry")
	_send_stick(JOY_AXIS_LEFT_Y, 0.0, 1)
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 2)
	assert_eq(_menu.get_focus_index(), 1, "and the next push is a push")


func test_ac23_a_motion_on_the_other_axis_is_not_a_new_push() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 2)
	assert_eq(_menu.get_focus_index(), 1)
	# Another axis moves (the right stick: the left one's X is Godot's own ui_left / ui_right, which
	# the engine's focus navigation answers by itself). The up push is still the same push.
	_send_stick(JOY_AXIS_RIGHT_X, 1.0, 2)
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 2)
	assert_eq(_menu.get_focus_index(), 1)


func test_ac23_a_ramped_push_up_moves_exactly_one_step() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	for strength: float in RAMP:
		_send_stick(JOY_AXIS_LEFT_Y, -strength, 1)
	assert_eq(_menu.get_focus_index(), 1, "crossing 0.2 and then 0.5 is one push")


func test_ac23_a_ramped_push_down_moves_exactly_one_step() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_UP)
	_press_key(KEY_UP)
	assert_eq(_menu.get_focus_index(), 0)
	for strength: float in RAMP:
		_send_stick(JOY_AXIS_LEFT_Y, strength, 1)
	assert_eq(_menu.get_focus_index(), 1, "crossing 0.2 and then 0.5 is one push")


func test_ac23_a_stick_resting_between_the_deadzones_when_the_list_opens_is_not_a_push() -> void:
	# Past move_up's 0.2, short of ui_up's 0.5: when the list opens, a stick past the smaller
	# deadzone counts as already pushed (CR-18). Later pushes start at the larger one (CR-16).
	_send_stick(JOY_AXIS_LEFT_Y, -0.4, 1)
	_spawn_menu()
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, -0.9, 1)
	assert_eq(_menu.get_focus_index(), 2, "it was already held up")
	_send_stick(JOY_AXIS_LEFT_Y, 0.0, 1)
	_send_stick(JOY_AXIS_LEFT_Y, -0.9, 1)
	assert_eq(_menu.get_focus_index(), 1, "after a full release a push is a push")


func test_ac23_a_stick_easing_off_and_back_without_letting_go_is_not_a_new_push() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_UP)
	_press_key(KEY_UP)
	_send_stick(JOY_AXIS_LEFT_Y, 1.0, 1)
	assert_eq(_menu.get_focus_index(), 1)
	_send_stick(JOY_AXIS_LEFT_Y, 0.4, 1)  # ui_down lets go, move_down still holds.
	_send_stick(JOY_AXIS_LEFT_Y, 0.6, 1)
	assert_eq(_menu.get_focus_index(), 1, "the stick never came back inside the smallest deadzone")


func test_ac23_a_stick_that_comes_back_inside_the_smallest_deadzone_pushes_anew() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_UP)
	_press_key(KEY_UP)
	_send_stick(JOY_AXIS_LEFT_Y, 1.0, 1)
	assert_eq(_menu.get_focus_index(), 1)
	_send_stick(JOY_AXIS_LEFT_Y, 0.1, 1)
	_send_stick(JOY_AXIS_LEFT_Y, 1.0, 1)
	assert_eq(_menu.get_focus_index(), 2)


func test_ac23_a_slow_release_moves_nothing_on_the_way_back() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 1)
	assert_eq(_menu.get_focus_index(), 1)
	for strength: float in [0.6, 0.3, 0.1]:
		_send_stick(JOY_AXIS_LEFT_Y, -strength, 1)
	assert_eq(_menu.get_focus_index(), 1)
	_send_stick(JOY_AXIS_LEFT_Y, 1.0, 1)  # Straight over to the other side is a push down.
	assert_eq(_menu.get_focus_index(), 2)


func test_ac23_a_ramped_diagonal_push_moves_exactly_one_step_up() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	for strength: float in RAMP:
		_send_stick(JOY_AXIS_LEFT_X, -strength, 1)
		_send_stick(JOY_AXIS_LEFT_Y, -strength, 1)
	assert_eq(_menu.get_focus_index(), 1, "one step up, and nothing sideways")
	_assert_still_open_with_no_outcome()


func test_ac23_a_key_held_when_the_list_opens_and_then_released_costs_no_stick_push() -> void:
	_spawn_menu()
	_send_key(KEY_W, true)
	Input.flush_buffered_events()
	_menu.open(_three_entries())
	_send_key(KEY_W, false)
	Input.flush_buffered_events()
	_send_stick(JOY_AXIS_LEFT_Y, -0.9, 2)  # Straight from rest, as a flick.
	assert_eq(_menu.get_focus_index(), 1, "the first push counts")


func test_ac23_the_dpad_held_when_the_list_opens_and_then_released_costs_no_stick_push() -> void:
	_spawn_menu()
	_send_pad_button(JOY_BUTTON_DPAD_UP, true)
	_menu.open(_three_entries())
	_send_pad_button(JOY_BUTTON_DPAD_UP, false)
	_send_stick(JOY_AXIS_LEFT_Y, -0.9, 2)  # Straight from rest, as a flick.
	assert_eq(_menu.get_focus_index(), 1, "the first push counts")


func test_ac23_a_key_and_a_stick_push_are_two_presses() -> void:
	# The rule: each source is its own press. A held W gives one step (repeats are not presses)
	# and a stick push on top of it gives another; neither blocks the other.
	_spawn_menu()
	_menu.open(_three_entries())
	_send_key(KEY_W, true)
	Input.flush_buffered_events()
	assert_eq(_menu.get_focus_index(), 1)
	for strength: float in RAMP:
		_send_stick(JOY_AXIS_LEFT_Y, -strength, 1)
	assert_eq(_menu.get_focus_index(), 0, "the stick pushed too")


func test_ac23_a_stick_held_down_does_not_block_a_key_or_the_dpad() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_UP)
	assert_eq(_menu.get_focus_index(), 1)
	_send_stick(JOY_AXIS_LEFT_Y, 1.0, 1)
	assert_eq(_menu.get_focus_index(), 2)
	_press_key(KEY_UP)
	assert_eq(_menu.get_focus_index(), 1, "a key while the stick holds down")
	_press_pad_button(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_menu.get_focus_index(), 2, "the d-pad too")


func test_ac23_a_release_that_overshoots_the_centre_is_not_a_push_back() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	for value: float in [-1.0, -0.5, 0.1, 0.25, 0.1, 0.0]:
		_send_stick(JOY_AXIS_LEFT_Y, value, 1)
	assert_eq(_menu.get_focus_index(), 1, "one step up and none back down")


func test_ac23_a_stick_jittering_around_the_smaller_deadzone_never_pushes() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	for value: float in [-0.25, -0.15, -0.25, -0.15, -0.25]:
		_send_stick(JOY_AXIS_LEFT_Y, value, 1)
	assert_eq(_menu.get_focus_index(), 2, "a push starts at 0.5, not at 0.2")
	for value: float in [0.25, 0.15, 0.25, 0.15, 0.25]:
		_send_stick(JOY_AXIS_LEFT_Y, value, 1)
	assert_eq(_menu.get_focus_index(), 2)


func test_ac23_a_stick_jittering_between_the_deadzones_after_a_push_stays_one_push() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	for value: float in [-1.0, -0.4, -0.25, -0.45, -0.25, -0.6, -0.3]:
		_send_stick(JOY_AXIS_LEFT_Y, value, 1)
	assert_eq(_menu.get_focus_index(), 1, "it never came back inside 0.2")


func test_ac23_a_stick_past_the_larger_deadzone_when_the_list_opens_is_not_a_push() -> void:
	_spawn_menu()
	_send_stick(JOY_AXIS_LEFT_Y, -0.6, 1)
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, -0.8, 2)
	assert_eq(_menu.get_focus_index(), 2, "it was already pushing")
	_send_stick(JOY_AXIS_LEFT_Y, 0.0, 1)
	_send_stick(JOY_AXIS_LEFT_Y, -0.8, 1)
	assert_eq(_menu.get_focus_index(), 1, "after a full release a push is a push")


func test_ac23_a_stick_pushed_while_the_list_was_closed_and_still_held_is_not_a_push() -> void:
	_spawn_menu()
	for strength: float in RAMP:  # The player walks up to the gate with the stick.
		_send_stick(JOY_AXIS_LEFT_Y, -strength, 1)
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 3)
	assert_eq(_menu.get_focus_index(), 2, "the push began before the list did")


func test_ac23_a_stick_pushed_and_let_go_while_the_list_was_closed_leaves_no_trace() -> void:
	_spawn_menu()
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 2)
	_send_stick(JOY_AXIS_LEFT_Y, 0.0, 1)
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 2)
	assert_eq(_menu.get_focus_index(), 1)


func test_ac23_a_real_pad_a_press_chooses_the_focused_entry_once() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_pad_button(JOY_BUTTON_A)
	assert_eq(_chosen, [Vector2i(2, 0)] as Array[Vector2i], "once")
	assert_eq(_closed, 0)
	assert_false(_menu.is_open())


func test_ac23_a_real_pad_a_press_on_the_stay_entry_cancels_once() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_DOWN)
	_press_pad_button(JOY_BUTTON_A)
	assert_eq(_closed, 1)
	assert_eq(_chosen, [] as Array[Vector2i])


func test_ac23_a_real_pad_b_press_cancels_once() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_pad_button(JOY_BUTTON_B)
	assert_eq(_closed, 1)
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_false(_menu.is_open())


func test_ac23_pad_x_does_nothing_and_pad_y_chooses() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_pad_button(JOY_BUTTON_X)
	assert_true(_menu.is_open())
	assert_eq(_menu.get_focus_index(), 2)
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_eq(_closed, 0)
	_press_pad_button(JOY_BUTTON_Y)  # interact
	assert_eq(_chosen, [Vector2i(2, 0)] as Array[Vector2i])
	assert_false(_menu.is_open())


func test_ac23_no_single_press_matches_two_of_the_choose_actions() -> void:
	# What keeps a choice from firing twice: one real press, one choose action.
	var presses: Array[InputEvent] = [
		_key_event(KEY_ENTER, true),
		_key_event(KEY_KP_ENTER, true),
		_key_event(KEY_SPACE, true),
		_key_event(KEY_E, true),
		_pad_button_event(JOY_BUTTON_A, true),
		_pad_button_event(JOY_BUTTON_Y, true),
	]
	for press: InputEvent in presses:
		var matched: int = 0
		for action: StringName in GateMenu.CHOOSE_ACTIONS:
			if press.is_action(action):
				matched += 1
		assert_eq(matched, 1, str(press))


func test_ac23_a_menu_born_while_the_stick_is_held_up_stays_put_until_a_new_push() -> void:
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 3)
	_spawn_menu()
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, -0.98, 1)
	assert_eq(_menu.get_focus_index(), 2, "a small change is not a push")
	for strength: float in RELEASE:
		_send_stick(JOY_AXIS_LEFT_Y, -strength, 1)
		assert_eq(_menu.get_focus_index(), 2, "letting go moves nothing (%s)" % strength)
	for strength: float in RAMP:
		_send_stick(JOY_AXIS_LEFT_Y, -strength, 1)
	assert_eq(_menu.get_focus_index(), 1, "and the next push is one step")


func test_ac23_a_menu_born_while_the_stick_is_held_down_stays_put_until_a_new_push() -> void:
	_send_stick(JOY_AXIS_LEFT_Y, 1.0, 3)
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_UP)
	_press_key(KEY_UP)
	assert_eq(_menu.get_focus_index(), 0)
	_send_stick(JOY_AXIS_LEFT_Y, 0.98, 1)
	assert_eq(_menu.get_focus_index(), 0, "a small change is not a push")
	for strength: float in RELEASE:
		_send_stick(JOY_AXIS_LEFT_Y, strength, 1)
		assert_eq(_menu.get_focus_index(), 0, "letting go moves nothing (%s)" % strength)
	for strength: float in RAMP:
		_send_stick(JOY_AXIS_LEFT_Y, strength, 1)
	assert_eq(_menu.get_focus_index(), 1, "and the next push is one step")


func test_ac23_a_stick_held_up_at_open_does_not_block_a_push_down_after_it_is_released() -> void:
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 2)
	_spawn_menu()
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, 0.0, 1)
	_send_stick(JOY_AXIS_LEFT_Y, 1.0, 2)
	assert_eq(_menu.get_focus_index(), 3, "one step down")


func test_ac23_a_stick_held_up_at_open_and_flipped_straight_down_pushes_down() -> void:
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 2)
	_spawn_menu()
	_menu.open(_three_entries())
	_send_stick(JOY_AXIS_LEFT_Y, 1.0, 2)
	assert_eq(_menu.get_focus_index(), 3, "the other direction was never held")


func test_ac23_a_key_held_before_the_menu_exists_and_released_then_a_stick_push_is_one_step(
) -> void:
	_send_key(KEY_W, true)
	Input.flush_buffered_events()
	_spawn_menu()
	_menu.open(_three_entries())
	_send_key(KEY_W, false)
	Input.flush_buffered_events()
	_send_stick(JOY_AXIS_LEFT_Y, -0.9, 2)
	assert_eq(_menu.get_focus_index(), 1, "no stick was held, so this is a push")


func test_ac23_a_menu_born_while_a_key_and_the_stick_are_both_held_knows_only_the_stick() -> void:
	_send_key(KEY_W, true)
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 3)
	_spawn_menu()
	_menu.open(_three_entries())
	assert_eq(_menu.get_focus_index(), 2, "opening is not a push")
	_send_key(KEY_W, false)
	Input.flush_buffered_events()
	assert_eq(_menu.get_focus_index(), 2, "letting go of the key moves nothing")
	for strength: float in RELEASE:
		_send_stick(JOY_AXIS_LEFT_Y, -strength, 1)
		assert_eq(
			_menu.get_focus_index(), 2, "letting go of the stick moves nothing (%s)" % strength
		)
	for strength: float in RAMP:
		_send_stick(JOY_AXIS_LEFT_Y, -strength, 1)
	assert_eq(_menu.get_focus_index(), 1, "a new stick push is one step")
	_press_key(KEY_W)
	assert_eq(_menu.get_focus_index(), 0, "and a key press on top of it is one more")


func test_ac23_left_and_right_keys_leave_the_focus_alone() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_UP)
	for key: Key in [KEY_LEFT, KEY_RIGHT, KEY_LEFT]:
		_press_key(key)
		assert_eq(_menu.get_focus_index(), 1, "the list is one column")
	assert_true(_buttons()[1].has_focus())
	_assert_still_open_with_no_outcome()


func test_ac23_left_and_right_on_the_stick_leave_the_focus_alone() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	for axis_value: float in [-1.0, 0.0, 1.0, 0.0]:
		_send_stick(JOY_AXIS_LEFT_X, axis_value, 4)
		assert_eq(_menu.get_focus_index(), 2)
	assert_true(_buttons()[2].has_focus())
	_assert_still_open_with_no_outcome()


func test_ac23_left_and_right_do_nothing_on_the_ends_of_the_list_either() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_DOWN)
	assert_eq(_menu.get_focus_index(), 3)
	_press_key(KEY_LEFT)
	_press_key(KEY_RIGHT)
	assert_eq(_menu.get_focus_index(), 3, "on the stay entry")
	for _i: int in 3:
		_press_key(KEY_UP)
	_press_key(KEY_RIGHT)
	assert_eq(_menu.get_focus_index(), 0, "on the first entry")
	_assert_still_open_with_no_outcome()


func test_ac23_every_button_is_its_own_left_and_right_neighbour() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	for button: Button in _buttons():
		assert_eq(button.get_node(button.focus_neighbor_left), button)
		assert_eq(button.get_node(button.focus_neighbor_right), button)


func test_ac23_a_diagonal_stick_push_moves_exactly_one_step_up() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	for _i: int in 3:  # Up and left, a burst of both axes, as a diagonal arrives.
		_send_stick(JOY_AXIS_LEFT_X, -1.0, 1)
		_send_stick(JOY_AXIS_LEFT_Y, -1.0, 1)
	assert_eq(_menu.get_focus_index(), 1, "one step up, and nothing sideways")
	_assert_still_open_with_no_outcome()
	_send_stick(JOY_AXIS_LEFT_X, 0.0, 1)
	_send_stick(JOY_AXIS_LEFT_Y, 0.0, 1)
	_send_stick(JOY_AXIS_LEFT_X, -1.0, 2)
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 2)
	assert_eq(_menu.get_focus_index(), 0, "a second diagonal, a second step")


func test_ac23_left_and_right_do_not_reach_what_is_behind_the_menu() -> void:
	_spawn_menu()
	var seen: Array[InputEvent] = []
	var spy: InputSpy = _spy_on_unhandled_input()
	spy.also_record = seen
	_menu.open(_three_entries())
	_press_key(KEY_LEFT)
	_press_key(KEY_RIGHT)
	_send_stick(JOY_AXIS_LEFT_X, -1.0, 3)
	_send_stick(JOY_AXIS_LEFT_X, 1.0, 3)
	assert_eq(seen.size(), 0, "consumed, press and release alike")
	_menu.close()
	_press_key(KEY_LEFT)
	assert_gt(seen.size(), 0, "a closed menu consumes nothing")


func test_ac23_up_and_down_events_are_all_consumed_so_the_engines_navigation_never_sees_them(
) -> void:
	_spawn_menu()
	var seen: Array[InputEvent] = []
	var spy: InputSpy = _spy_on_unhandled_input()
	spy.also_record = seen
	_menu.open(_three_entries())
	_send_key(KEY_UP, true)
	for _i: int in 3:
		_send_key(KEY_UP, true, true)
	_send_key(KEY_UP, false)
	_send_key(KEY_DOWN, true, true)  # A repeat on its own, as in a held key.
	_send_key(KEY_DOWN, false)
	Input.flush_buffered_events()
	assert_eq(_menu.get_focus_index(), 1, "one key press up, the repeats added nothing")
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 4)
	assert_eq(_menu.get_focus_index(), 0, "one push up, one step")
	_send_stick(JOY_AXIS_LEFT_Y, 1.0, 4)
	assert_eq(_menu.get_focus_index(), 1, "one push down, one step")
	assert_eq(seen.size(), 0, "presses, repeats, releases and non-crossing stick events")


func test_ac23_stick_motion_never_chooses_or_cancels() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	for axis_value: float in [-1.0, 1.0, 0.0]:
		_send_stick(JOY_AXIS_LEFT_Y, axis_value, 3)
		_send_stick(JOY_AXIS_RIGHT_X, axis_value, 3)
	assert_true(_menu.is_open())
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_eq(_closed, 0)


func test_ac23_open_again_rebuilds_the_list() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press(&"ui_up")
	var one: Array[TowerEntry] = [_entry(1, false, false)]
	_menu.open(one)
	assert_eq(_menu.get_entry_count(), 1)
	assert_eq(_button_texts(), ["Floor 1 — from the start", "Stay in town"] as Array[String])
	assert_eq(_menu.get_focus_index(), 0, "the focus starts again on the last floor entry")
	assert_eq(_list().get_child_count(), 2, "the old buttons are gone, not hidden")
	assert_true(_menu.is_open())
	_press(&"ui_accept")
	assert_eq(_chosen, [Vector2i(1, 0)] as Array[Vector2i], "the new list is the live one")


func test_ac23_open_again_after_closing_works() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press(&"ui_cancel")
	assert_false(_menu.is_open())
	_menu.open(_three_entries())
	assert_true(_menu.is_open())
	assert_true(_menu.visible)
	assert_eq(_menu.get_focus_index(), 2)
	_press(&"ui_accept")
	assert_eq(_chosen, [Vector2i(2, 0)] as Array[Vector2i])
	assert_eq(_closed, 1)


func _assert_still_open_with_no_outcome() -> void:
	assert_true(_menu.is_open())
	assert_eq(_chosen, [] as Array[Vector2i], "nothing chosen")
	assert_eq(_closed, 0, "nothing cancelled")


func _spawn_menu() -> void:
	_menu = MENU_SCENE.instantiate()
	_menu.entry_chosen.connect(
		func(floor_number: int, at_boss: bool) -> void:
			_chosen.append(Vector2i(floor_number, 1 if at_boss else 0))
	)
	_menu.closed.connect(func() -> void: _closed += 1)
	add_child_autofree(_menu)


## Floor 1 from the start and at the boss, both cleared, then floor 2 from the start.
func _three_entries() -> Array[TowerEntry]:
	return [_entry(1, false, true), _entry(1, true, true), _entry(2, false, false)]


func _entry(floor_number: int, at_boss: bool, is_cleared: bool) -> TowerEntry:
	var entry: TowerEntry = TowerEntry.new()
	entry.floor_number = floor_number
	entry.at_boss = at_boss
	entry.is_cleared = is_cleared
	return entry


func _list() -> VBoxContainer:
	return _menu.get_node(LIST_PATH)


func _buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _list().get_children():
		buttons.append(child as Button)
	return buttons


func _button_texts() -> Array[String]:
	var texts: Array[String] = []
	for button: Button in _buttons():
		texts.append(button.text)
	return texts


## A press and a release of an input action through the engine's input path.
func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


## A press and a release of a key, which the input map turns into actions.
func _press_key(key: Key) -> void:
	_send_key(key, true)
	_send_key(key, false)
	Input.flush_buffered_events()


## One key event through the engine's input path, not flushed. Both `keycode` and
## `physical_keycode` are set, so it matches the built-in `ui_*` actions and the project's
## `move_*` / `interact` ones alike.
func _send_key(key: Key, pressed: bool, echo: bool = false) -> void:
	if pressed and not _held_keys.has(key):
		_held_keys.append(key)
	Input.parse_input_event(_key_event(key, pressed, echo))


func _key_event(key: Key, pressed: bool, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	event.echo = echo
	return event


## A press and a release of a pad button, as a tap. Pad A is `ui_accept` and `dodge`, B `ui_cancel`,
## X `attack`, Y `interact`.
func _press_pad_button(button: JoyButton) -> void:
	_send_pad_button(button, true)
	_send_pad_button(button, false)


func _send_pad_button(button: JoyButton, pressed: bool) -> void:
	if pressed and not _held_pad_buttons.has(button):
		_held_pad_buttons.append(button)
	Input.parse_input_event(_pad_button_event(button, pressed))
	Input.flush_buffered_events()


func _pad_button_event(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


## `count` joypad motion events on `axis` with the same value and one flush: how a stick held past
## its deadzone arrives.
func _send_stick(axis: JoyAxis, axis_value: float, count: int) -> void:
	if not _stick_axes.has(axis):
		_stick_axes.append(axis)
	for _i: int in count:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = axis_value
		Input.parse_input_event(event)
	Input.flush_buffered_events()


## Records every pressed action that reaches `_unhandled_input`, i.e. that nobody consumed.
func _spy_on_unhandled_input() -> InputSpy:
	var spy: InputSpy = InputSpy.new()
	add_child_autofree(spy)
	return spy


class InputSpy:
	extends Node
	var seen: Array[StringName] = []
	## When set, every event that reaches `_unhandled_input` is also put here.
	var also_record: Array[InputEvent] = []

	func _unhandled_input(event: InputEvent) -> void:
		also_record.append(event)
		if event is InputEventAction and (event as InputEventAction).pressed:
			seen.append((event as InputEventAction).action)
