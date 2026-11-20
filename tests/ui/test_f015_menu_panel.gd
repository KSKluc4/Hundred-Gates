# gdlint:disable=max-public-methods,max-file-lines
extends GutTest
## F-015 T4 (AC11): the menu panel. Keys, the d-pad and the stick go through the engine's input
## path (Input.parse_input_event) so `_input` answers them, as in test_gate_menu. A positional mouse
## click cannot get under GUT's own layer, so a click is the button's own `pressed` (which reaches
## `choose`) or `choose(id)` itself. Whatever a test presses, after_each lets go of.

const PANEL_SCENE: PackedScene = preload("res://src/ui/menus/menu_panel.tscn")
const HEADING_PATH: NodePath = ^"Panel/Content/Heading"
const BODY_PATH: NodePath = ^"Panel/Content/Body"
const BUTTONS_PATH: NodePath = ^"Panel/Content/Buttons"
## A short pointer guard for the tests that wait for it (the default is 0.3 s), in seconds. A change
## in place is made LATE_MSEC into it; a guard that ends before NOT_RESTARTED_MSEC was not started
## again by it (that would end at LATE_MSEC + the guard, 430 and more). And how long a wait for it
## may take before the test calls it stuck.
const GUARD_SECONDS: float = 0.25
const LATE_MSEC: int = 180
const NOT_RESTARTED_MSEC: int = 350
const GUARD_WAIT_LIMIT_MSEC: int = 3000
## A real stick passes through every value on its way (as in test_gate_menu).
const RAMP: Array[float] = [0.1, 0.3, 0.45, 0.7, 1.0]
const HANDLED_ACTIONS: Array[StringName] = [
	&"ui_up",
	&"ui_down",
	&"move_up",
	&"move_down",
	&"ui_accept",
	&"interact",
	&"ui_cancel",
	&"pause",
	&"ui_left",
	&"ui_right",
]

var _panel: MenuPanel
var _chosen: Array[StringName] = []
var _cancelled: int = 0
var _held_keys: Array[Key] = []
var _held_pad_buttons: Array[JoyButton] = []
var _stick_axes: Array[JoyAxis] = []


func before_each() -> void:
	_chosen = []
	_cancelled = 0
	_held_keys = []
	_held_pad_buttons = []
	_stick_axes = []


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
	# The buttons a second open() replaced are queued, not gone, until the frame ends.
	await get_tree().process_frame


# --- what open() shows ---


func test_ac11_the_panel_is_hidden_until_it_is_opened() -> void:
	_spawn_panel()
	assert_false(_panel.visible)
	assert_false(_panel.is_open())
	assert_eq(_panel.get_entry_ids(), [] as Array[StringName])
	assert_eq(_panel.get_focus_id(), &"", "no entry, no focus")
	assert_eq(_buttons().size(), 0)


func test_ac11_the_panel_is_a_list_menu() -> void:
	_spawn_panel()
	assert_true(_panel is ListMenu)


func test_ac11_open_shows_the_heading_and_the_body() -> void:
	_spawn_panel()
	_panel.open("Paused", "Nothing is saved.", _entries(), &"b")
	assert_true(_panel.is_open())
	assert_true(_panel.visible)
	assert_eq(_panel.get_heading(), "Paused")
	assert_eq(_heading_label().text, "Paused")
	assert_true(_heading_label().visible)
	assert_eq(_panel.get_body(), "Nothing is saved.")
	assert_eq(_body_label().text, "Nothing is saved.")
	assert_true(_body_label().visible)


func test_ac11_the_body_is_hidden_when_it_is_empty() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_false(_body_label().visible)
	assert_eq(_panel.get_body(), "")
	_panel.open("Paused", "Now there is one.", _entries(), &"a")
	assert_true(_body_label().visible, "a body shows again when the next menu has one")
	_panel.open("Paused", "", _entries(), &"a")
	assert_false(_body_label().visible, "and hides again")


func test_ac11_the_body_wraps_inside_the_panel_and_keeps_its_lines() -> void:
	_spawn_panel()
	_panel.open("You died", "Floor 1\nKills 2 / 3", _entries(), &"a")
	assert_ne(_body_label().autowrap_mode, TextServer.AUTOWRAP_OFF)
	assert_eq(_panel.get_body().split("\n").size(), 2)


func test_ac11_open_lists_every_entry_in_order_with_its_text() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_eq(_panel.get_entry_ids(), [&"a", &"b", &"c"] as Array[StringName])
	assert_eq(_button_texts(), ["Alpha", "Beta", "Gamma"] as Array[String])
	assert_eq(_panel.get_entry_text(&"a"), "Alpha")
	assert_eq(_panel.get_entry_text(&"c"), "Gamma")
	assert_true(_panel.is_entry_enabled(&"a"))
	assert_false(_panel.is_entry_enabled(&"c"), "the third was given as disabled")
	assert_true(_buttons()[2].disabled)


func test_ac11_the_focus_starts_on_the_given_entry() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	assert_eq(_panel.get_focus_id(), &"b")
	assert_eq(_panel.get_focus_index(), 1)
	assert_true(_buttons()[1].has_focus(), "and the button really has it")


func test_ac11_an_unknown_focus_id_focuses_the_first_entry() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"nope")
	assert_eq(_panel.get_focus_id(), &"a")
	assert_true(_buttons()[0].has_focus())


func test_ac11_the_focus_can_start_on_a_disabled_entry() -> void:
	_spawn_panel()
	_panel.open("You died", "", _entries(), &"c")
	assert_eq(_panel.get_focus_id(), &"c")
	assert_true(_buttons()[2].has_focus(), "a disabled button can hold the focus")


func test_ac11_unknown_ids_have_no_text_and_are_not_enabled() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_eq(_panel.get_entry_text(&"nope"), "")
	assert_false(_panel.is_entry_enabled(&"nope"))


func test_ac11_the_defaults_are_the_gate_lists() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_eq(_panel.font_size, 8)
	assert_eq(_panel.panel_min_width_px, 160.0)
	assert_eq(_panel.button_separation_px, 2)
	assert_eq(_buttons()[0].get_theme_font_size(&"font_size"), 8)
	assert_eq(_list().get_theme_constant(&"separation"), 2)
	assert_gte(_panel.get_node(^"Panel").custom_minimum_size.x, 160.0)


func test_ac11_open_again_rebuilds_the_entries() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	_press(&"ui_down")
	var one: Array[MenuEntry] = [MenuEntry.make(&"only", "Only")]
	_panel.open("Other", "", one, &"only")
	assert_eq(_panel.get_entry_ids(), [&"only"] as Array[StringName])
	assert_eq(_button_texts(), ["Only"] as Array[String])
	assert_eq(_list().get_child_count(), 1, "the old buttons are gone, not hidden")
	assert_eq(_panel.get_heading(), "Other")
	assert_eq(_panel.get_focus_id(), &"only")
	_press(&"ui_accept")
	assert_eq(_chosen, [&"only"] as Array[StringName], "the new list is the live one")


func test_ac11_open_does_not_keep_the_callers_entries() -> void:
	_spawn_panel()
	var entries: Array[MenuEntry] = _entries()
	_panel.open("Paused", "", entries, &"a")
	entries[0].text = "changed behind its back"
	entries.clear()
	assert_eq(_panel.get_entry_ids(), [&"a", &"b", &"c"] as Array[StringName])
	assert_eq(_panel.get_entry_text(&"a"), "Alpha")


# --- the focus ---


func test_ac11_ui_up_and_ui_down_move_the_focus() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_press(&"ui_up")
	assert_eq(_panel.get_focus_id(), &"a")
	assert_true(_buttons()[0].has_focus())
	_press(&"ui_down")
	_press(&"ui_down")
	assert_eq(_panel.get_focus_id(), &"c")
	assert_true(_buttons()[2].has_focus())


func test_ac11_move_up_and_move_down_move_the_focus_too() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_press(&"move_up")
	assert_eq(_panel.get_focus_id(), &"a")
	_press(&"move_down")
	_press(&"move_down")
	assert_eq(_panel.get_focus_id(), &"c")


func test_ac11_the_focus_stops_at_both_ends() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	for _i: int in 6:
		_press(&"ui_up")
	assert_eq(_panel.get_focus_id(), &"a", "no wrapping to the last entry")
	for _i: int in 6:
		_press(&"ui_down")
	assert_eq(_panel.get_focus_id(), &"c", "no wrapping to the first entry")


func test_ac11_one_arrow_key_press_moves_one_step_though_it_is_two_actions() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"c")
	_press_key(KEY_UP)
	assert_eq(_panel.get_focus_id(), &"b", "one step, not two")
	_press_key(KEY_UP)
	assert_eq(_panel.get_focus_id(), &"a")
	_press_key(KEY_DOWN)
	assert_eq(_panel.get_focus_id(), &"b")


func test_ac11_w_and_s_move_the_focus_too() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_press_key(KEY_W)
	assert_eq(_panel.get_focus_id(), &"a")
	_press_key(KEY_S)
	assert_eq(_panel.get_focus_id(), &"b")


func test_ac11_the_dpad_moves_one_step() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_press_pad_button(JOY_BUTTON_DPAD_UP)
	assert_eq(_panel.get_focus_id(), &"a")
	_press_pad_button(JOY_BUTTON_DPAD_DOWN)
	_press_pad_button(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_panel.get_focus_id(), &"c")


func test_ac11_one_stick_push_moves_one_step_however_many_events_it_sends() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"c")
	_send_stick(JOY_AXIS_LEFT_Y, -0.1, 3)  # Inside the deadzone: nothing.
	assert_eq(_panel.get_focus_id(), &"c")
	_send_stick(JOY_AXIS_LEFT_Y, -0.9, 5)
	assert_eq(_panel.get_focus_id(), &"b", "five events, one push, one step")
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 3)
	assert_eq(_panel.get_focus_id(), &"b", "still the same push")
	_send_stick(JOY_AXIS_LEFT_Y, 0.0, 1)
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 3)
	assert_eq(_panel.get_focus_id(), &"a", "a second push, a second step")


func test_ac11_a_ramped_stick_push_down_moves_exactly_one_step() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	for strength: float in RAMP:
		_send_stick(JOY_AXIS_LEFT_Y, strength, 1)
	assert_eq(_panel.get_focus_id(), &"b", "crossing 0.2 and then 0.5 is one push")


func test_ac11_the_stick_stops_at_the_ends_too() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"c")
	_send_stick(JOY_AXIS_LEFT_Y, 1.0, 3)
	assert_eq(_panel.get_focus_id(), &"c")
	_send_stick(JOY_AXIS_LEFT_Y, 0.0, 1)
	_panel.open("Paused", "", _entries(), &"a")
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 3)
	assert_eq(_panel.get_focus_id(), &"a")


func test_ac11_a_stick_held_when_the_panel_opens_does_not_move_the_focus() -> void:
	_spawn_panel()
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 2)  # Held up as the menu opens.
	_panel.open("Paused", "", _entries(), &"c")
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 5)
	assert_eq(_panel.get_focus_id(), &"c", "the focus stays where open() put it")
	_send_stick(JOY_AXIS_LEFT_Y, 0.0, 1)
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 2)
	assert_eq(_panel.get_focus_id(), &"b", "and the next push is a push")


func test_ac11_the_stick_held_again_when_a_second_menu_opens_is_still_not_a_push() -> void:
	# The shell opens a different menu over the same panel on every choice.
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"c")
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 2)
	assert_eq(_panel.get_focus_id(), &"b")
	_panel.open("Settings", "", _entries(), &"c")
	_send_stick(JOY_AXIS_LEFT_Y, -1.0, 3)
	assert_eq(_panel.get_focus_id(), &"c", "a stick still held up from before is not a push")


func test_ac11_left_and_right_keys_and_stick_leave_the_focus_alone() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	for key: Key in [KEY_LEFT, KEY_RIGHT, KEY_LEFT]:
		_press_key(key)
		assert_eq(_panel.get_focus_id(), &"b", "the list is one column")
	for axis_value: float in [-1.0, 0.0, 1.0, 0.0]:
		_send_stick(JOY_AXIS_LEFT_X, axis_value, 4)
		assert_eq(_panel.get_focus_id(), &"b")
	assert_true(_buttons()[1].has_focus())
	assert_eq(_chosen, [] as Array[StringName])
	assert_eq(_cancelled, 0)


func test_ac11_every_button_is_its_own_left_and_right_neighbour() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	for button: Button in _buttons():
		assert_eq(button.get_node(button.focus_neighbor_left), button)
		assert_eq(button.get_node(button.focus_neighbor_right), button)


func test_ac11_a_held_key_repeating_does_not_move_or_choose() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	for key: Key in [KEY_E, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
		_send_key(key, true, true)
	Input.flush_buffered_events()
	assert_eq(_panel.get_focus_id(), &"b")
	assert_eq(_chosen, [] as Array[StringName])
	assert_eq(_cancelled, 0)


func test_ac11_the_focus_follows_godots_own_focus_moves() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	_buttons()[2].grab_focus()  # Tab or the mouse.
	assert_eq(_panel.get_focus_id(), &"c")
	_press(&"ui_up")
	assert_eq(_panel.get_focus_id(), &"b")


# --- choosing ---


func test_ac11_ui_accept_chooses_the_focused_entry_once() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_press(&"ui_accept")
	assert_eq(_chosen, [&"b"] as Array[StringName])
	assert_eq(_cancelled, 0)


func test_ac11_interact_chooses_the_focused_entry_once() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	_press(&"interact")
	assert_eq(_chosen, [&"a"] as Array[StringName])


func test_ac11_real_enter_space_e_and_pad_a_and_y_each_choose_once() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_press_key(KEY_ENTER)
	assert_eq(_chosen, [&"b"] as Array[StringName], "enter")
	_press_key(KEY_SPACE)
	assert_eq(_chosen.size(), 2, "space")
	_press_key(KEY_E)
	assert_eq(_chosen.size(), 3, "e")
	_press_pad_button(JOY_BUTTON_A)
	assert_eq(_chosen.size(), 4, "pad a")
	_press_pad_button(JOY_BUTTON_Y)
	assert_eq(_chosen.size(), 5, "pad y")
	assert_eq(_cancelled, 0)


func test_ac11_choosing_does_not_close_the_panel() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_press(&"ui_accept")
	assert_true(_panel.is_open(), "the shell decides what is shown next")
	assert_true(_panel.visible)
	_press(&"ui_accept")
	assert_eq(_chosen.size(), 2, "so it can be chosen again")


func test_ac11_choose_by_id_emits_that_entry_once_wherever_the_focus_is() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	_panel.choose(&"b")
	assert_eq(_chosen, [&"b"] as Array[StringName])
	assert_eq(_panel.get_focus_id(), &"a", "a click does not need to move the focus")
	assert_true(_panel.is_open())


func test_ac11_a_click_is_the_buttons_own_pressed_and_reaches_choose() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	_buttons()[1].pressed.emit()
	assert_eq(_chosen, [&"b"] as Array[StringName])
	_buttons()[0].pressed.emit()
	assert_eq(_chosen, [&"b", &"a"] as Array[StringName])


func test_ac11_choose_with_an_unknown_id_does_nothing() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	_panel.choose(&"nope")
	_panel.choose(&"")
	assert_eq(_chosen, [] as Array[StringName])
	assert_eq(_cancelled, 0)
	assert_true(_panel.is_open())


func test_ac11_choose_while_closed_does_nothing() -> void:
	_spawn_panel()
	_panel.choose(&"a")
	assert_eq(_chosen, [] as Array[StringName])
	_panel.open("Paused", "", _entries(), &"a")
	_panel.close()
	_panel.choose(&"a")
	assert_eq(_chosen, [] as Array[StringName])


# --- cancelling ---


func test_ac11_ui_cancel_emits_cancelled_once_and_the_panel_stays_open() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_press(&"ui_cancel")
	assert_eq(_cancelled, 1)
	assert_eq(_chosen, [] as Array[StringName])
	assert_true(_panel.is_open(), "the shell decides what is shown next")
	assert_true(_panel.visible)
	assert_eq(_panel.get_focus_id(), &"b")


func test_ac11_a_real_escape_press_cancels_once() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_press_key(KEY_ESCAPE)
	assert_eq(_cancelled, 1, "Escape is ui_cancel and pause, and it is one cancel")
	assert_eq(_chosen, [] as Array[StringName])


func test_ac11_a_real_pad_b_press_cancels_once() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_press_pad_button(JOY_BUTTON_B)
	assert_eq(_cancelled, 1)
	assert_eq(_chosen, [] as Array[StringName])


func test_ac11_escape_is_consumed_so_the_shells_pause_does_not_also_see_it() -> void:
	_spawn_panel()
	var spy: InputSpy = _spy_on_unhandled_input()
	_panel.open("Paused", "", _entries(), &"b")
	_press_key(KEY_ESCAPE)
	assert_eq(spy.pressed_count(), 0, "nothing behind the panel saw the Escape")
	assert_eq(_cancelled, 1)


func test_ac11_a_pause_only_event_is_neither_handled_nor_consumed() -> void:
	_spawn_panel()
	var spy: InputSpy = _spy_on_unhandled_input()
	_panel.open("Paused", "", _entries(), &"b")
	var start: InputEventJoypadButton = _pad_button_event(JOY_BUTTON_START, true)
	assert_true(start.is_action(&"pause"), "the premise: pad Start is pause")
	assert_false(start.is_action(&"ui_cancel"), "and not ui_cancel")
	_press_pad_button(JOY_BUTTON_START)
	assert_eq(_cancelled, 0, "the panel does not cancel on pause")
	assert_eq(_chosen, [] as Array[StringName])
	assert_eq(spy.pressed_count(), 1, "the press reached what is behind the panel")
	assert_true(_panel.is_open())
	assert_eq(_panel.get_focus_id(), &"b")


# --- disabled entries ---


func test_ac11_a_disabled_entry_can_be_reached_by_moving_and_is_not_skipped() -> void:
	_spawn_panel()
	_panel.open("You died", "", _entries(), &"a")
	_press(&"ui_down")
	_press(&"ui_down")
	assert_eq(_panel.get_focus_id(), &"c", "the disabled entry is the next one down")
	assert_true(_buttons()[2].has_focus())
	_press(&"ui_up")
	assert_eq(_panel.get_focus_id(), &"b", "and moving on from it works")


func test_ac11_a_disabled_entry_in_the_middle_is_stopped_on_both_ways() -> void:
	_spawn_panel()
	var entries: Array[MenuEntry] = [
		MenuEntry.make(&"a", "Alpha"),
		MenuEntry.make(&"b", "Beta", false),
		MenuEntry.make(&"c", "Gamma"),
	]
	_panel.open("Paused", "", entries, &"a")
	_press(&"ui_down")
	assert_eq(_panel.get_focus_id(), &"b", "down stops on the disabled entry")
	assert_true(_buttons()[1].has_focus())
	_press(&"ui_accept")
	assert_eq(_chosen, [] as Array[StringName], "and choosing there does nothing")
	_press(&"ui_down")
	assert_eq(_panel.get_focus_id(), &"c")
	_press(&"ui_up")
	assert_eq(_panel.get_focus_id(), &"b", "up stops on it too")


func test_ac11_choosing_a_disabled_entry_by_key_does_nothing() -> void:
	_spawn_panel()
	_panel.open("You died", "", _entries(), &"c")
	_press(&"ui_accept")
	_press(&"interact")
	_press_key(KEY_ENTER)
	_press_key(KEY_SPACE)
	_press_key(KEY_E)
	assert_eq(_chosen, [] as Array[StringName])
	assert_true(_panel.is_open())
	assert_eq(_panel.get_focus_id(), &"c")


func test_ac11_choosing_a_disabled_entry_by_pad_does_nothing() -> void:
	_spawn_panel()
	_panel.open("You died", "", _entries(), &"c")
	_press_pad_button(JOY_BUTTON_A)
	_press_pad_button(JOY_BUTTON_Y)
	assert_eq(_chosen, [] as Array[StringName])


func test_ac11_choosing_a_disabled_entry_by_choose_or_a_click_does_nothing() -> void:
	_spawn_panel()
	_panel.open("You died", "", _entries(), &"c")
	_panel.choose(&"c")
	_buttons()[2].pressed.emit()  # The engine ignores a click here; this is a press by code.
	assert_eq(_chosen, [] as Array[StringName])
	assert_eq(_cancelled, 0)


func test_ac11_a_disabled_entry_does_not_stop_the_others_or_cancel() -> void:
	_spawn_panel()
	_panel.open("You died", "", _entries(), &"c")
	_panel.choose(&"a")
	_press(&"ui_cancel")
	assert_eq(_chosen, [&"a"] as Array[StringName])
	assert_eq(_cancelled, 1)


func test_ac11_enabling_a_disabled_entry_lets_it_be_chosen_with_the_focus_unmoved() -> void:
	_spawn_panel()
	_panel.open("You died", "", _entries(), &"c")
	_press(&"ui_accept")
	assert_eq(_chosen.size(), 0)
	_panel.set_entry_enabled(&"c", true)
	assert_true(_panel.is_entry_enabled(&"c"))
	assert_eq(_panel.get_focus_id(), &"c")
	assert_true(_buttons()[2].has_focus())
	_press(&"ui_accept")
	assert_eq(_chosen, [&"c"] as Array[StringName])


func test_ac11_disabling_the_focused_entry_keeps_the_focus_on_it() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_panel.set_entry_enabled(&"b", false)
	assert_false(_panel.is_entry_enabled(&"b"))
	assert_eq(_panel.get_focus_id(), &"b")
	assert_true(_buttons()[1].has_focus(), "the button keeps the real focus too")
	_press(&"ui_accept")
	assert_eq(_chosen, [] as Array[StringName])
	_press(&"ui_up")
	assert_eq(_panel.get_focus_id(), &"a")


# --- changing the menu in place ---


func test_ac11_set_body_changes_it_and_keeps_the_focus() -> void:
	_spawn_panel()
	_panel.open("Title", "", _entries(), &"b")
	_panel.set_body("Something went wrong.")
	assert_eq(_panel.get_body(), "Something went wrong.")
	assert_true(_body_label().visible, "a body set on a menu that had none shows")
	assert_eq(_panel.get_focus_id(), &"b")
	assert_true(_buttons()[1].has_focus())
	_panel.set_body("")
	assert_false(_body_label().visible, "and an empty one hides again")
	assert_eq(_panel.get_focus_id(), &"b")


func test_ac11_set_entry_text_changes_that_entry_and_keeps_the_focus() -> void:
	_spawn_panel()
	_panel.open("Settings", "", _entries(), &"b")
	_panel.set_entry_text(&"b", "Beta: Off")
	assert_eq(_panel.get_entry_text(&"b"), "Beta: Off")
	assert_eq(_button_texts(), ["Alpha", "Beta: Off", "Gamma"] as Array[String])
	assert_eq(_panel.get_focus_id(), &"b")
	assert_true(_buttons()[1].has_focus())
	_press(&"ui_accept")
	assert_eq(_chosen, [&"b"] as Array[StringName], "and it still chooses the same entry")


func test_ac11_set_entry_enabled_changes_that_entry_and_keeps_the_focus() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	_panel.set_entry_enabled(&"b", false)
	assert_eq(_panel.get_focus_id(), &"a")
	assert_true(_buttons()[0].has_focus())
	assert_true(_buttons()[1].disabled)
	assert_false(_panel.is_entry_enabled(&"b"))
	assert_true(_panel.is_entry_enabled(&"a"), "the others are unchanged")


func test_ac11_set_entry_calls_with_an_unknown_id_change_nothing() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_panel.set_entry_text(&"nope", "x")
	_panel.set_entry_enabled(&"nope", false)
	assert_eq(_button_texts(), ["Alpha", "Beta", "Gamma"] as Array[String])
	assert_eq(_panel.get_focus_id(), &"b")


func test_ac11_set_calls_before_open_change_nothing_and_do_not_crash() -> void:
	_spawn_panel()
	_panel.set_body("x")
	_panel.set_entry_text(&"a", "x")
	_panel.set_entry_enabled(&"a", false)
	assert_eq(_panel.get_entry_ids(), [] as Array[StringName])
	_panel.open("Paused", "", _entries(), &"a")
	assert_eq(_panel.get_body(), "", "a menu starts from its own body")


# --- closed ---


func test_ac11_while_closed_the_panel_handles_no_input_at_all() -> void:
	_spawn_panel()
	var spy: InputSpy = _spy_on_unhandled_input()
	for action: StringName in [&"ui_up", &"ui_down", &"ui_accept", &"interact", &"ui_cancel"]:
		_press(action)
	_press_key(KEY_ESCAPE)
	_press_pad_button(JOY_BUTTON_START)
	assert_eq(_chosen, [] as Array[StringName])
	assert_eq(_cancelled, 0)
	assert_eq(spy.pressed_count(), 7, "every press went by, unconsumed")
	_panel.open("Paused", "", _entries(), &"a")
	_panel.close()
	spy.events.clear()
	_press(&"ui_accept")
	_press(&"ui_cancel")
	assert_eq(spy.pressed_count(), 2, "a panel that was closed again handles nothing either")
	assert_eq(_cancelled, 0)
	assert_eq(_chosen, [] as Array[StringName])


func test_ac11_close_hides_the_panel_without_a_signal() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	_panel.close()
	assert_false(_panel.is_open())
	assert_false(_panel.visible)
	assert_eq(_chosen, [] as Array[StringName])
	assert_eq(_cancelled, 0)


func test_ac11_while_open_its_keys_are_consumed_and_other_keys_pass_through() -> void:
	_spawn_panel()
	var spy: InputSpy = _spy_on_unhandled_input()
	_panel.open("Paused", "", _entries(), &"b")
	for action: StringName in [
		&"ui_up", &"ui_down", &"move_up", &"move_down", &"ui_left", &"ui_right"
	]:
		_press(action)
	_press(&"ui_accept")
	_press(&"ui_cancel")
	assert_eq(spy.pressed_count(), 0, "nothing behind the panel sees them")
	_press(&"debug_next_room")
	_press(&"attack")
	assert_eq(spy.pressed_count(), 2, "the panel keeps only its own keys")
	assert_true(_panel.is_open())


# --- opened again ---


func test_ac11_opened_again_after_close_a_button_has_the_focus_again() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	assert_true(_buttons()[1].has_focus())
	_panel.close()
	assert_false(_buttons()[1].has_focus(), "hiding drops the focus")
	_panel.open("Paused", "", _entries(), &"b")
	assert_true(_panel.is_open())
	assert_true(_panel.visible)
	assert_true(_buttons()[1].has_focus())
	_press(&"ui_accept")
	assert_eq(_chosen, [&"b"] as Array[StringName])


func test_ac11_opened_again_after_hide_a_button_has_the_focus_again() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"b")
	_panel.hide()
	assert_false(_buttons()[1].has_focus(), "hiding drops the focus")
	_panel.open("Paused", "", _entries(), &"c")
	assert_true(_panel.visible)
	assert_true(_buttons()[2].has_focus())
	assert_eq(_panel.get_focus_id(), &"c")


func test_ac11_open_while_open_with_the_same_menu_takes_the_focus_back() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	_buttons()[0].release_focus()
	assert_false(_buttons()[0].has_focus())
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(_buttons()[0].has_focus())


# --- the pointer guard (a double click must not act on the menu that opens under the cursor) ---


func test_guard_the_default_is_a_third_of_a_second() -> void:
	_spawn_panel()
	assert_eq(_panel.pointer_guard_seconds, 0.3)


func test_guard_the_entries_ignore_the_pointer_right_after_open() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(_panel.is_pointer_guarded())
	assert_eq(_buttons().size(), 3)
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_guard_the_entries_take_the_pointer_again_after_the_time() -> void:
	_spawn_panel()
	_panel.pointer_guard_seconds = GUARD_SECONDS
	_panel.open("Paused", "", _entries(), &"a")
	var opened_at: int = Time.get_ticks_msec()
	assert_true(await _wait_until_unguarded(), "the guard ended")
	var elapsed_msec: int = Time.get_ticks_msec() - opened_at
	assert_gte(elapsed_msec, roundi(GUARD_SECONDS * 1000.0), "not before its time (real time)")
	assert_false(_panel.is_pointer_guarded())
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_guard_a_guard_of_zero_is_no_guard() -> void:
	_spawn_panel()
	_panel.pointer_guard_seconds = 0.0
	_panel.open("Paused", "", _entries(), &"a")
	assert_false(_panel.is_pointer_guarded())
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_guard_every_open_starts_it_again() -> void:
	_spawn_panel()
	_panel.pointer_guard_seconds = GUARD_SECONDS
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(await _wait_until_unguarded())
	_panel.open("Other", "", _entries(), &"b")
	assert_true(_panel.is_pointer_guarded(), "a new menu is guarded again")
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_true(await _wait_until_unguarded())
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_guard_choose_by_code_works_during_the_guard() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(_panel.is_pointer_guarded())
	_panel.choose(&"b")
	assert_eq(_chosen, [&"b"] as Array[StringName])


func test_guard_the_keys_and_the_focus_work_during_the_guard() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(_panel.is_pointer_guarded())
	_press(&"ui_down")
	assert_eq(_panel.get_focus_id(), &"b", "the focus moves")
	_press(&"ui_accept")
	assert_eq(_chosen, [&"b"] as Array[StringName], "ui_accept chooses")
	_press(&"interact")
	assert_eq(_chosen, [&"b", &"b"] as Array[StringName], "interact chooses")
	_press(&"ui_cancel")
	assert_eq(_cancelled, 1, "ui_cancel cancels")
	assert_true(_panel.is_pointer_guarded(), "and the guard is still on")


func test_guard_a_click_on_the_button_itself_is_the_one_thing_it_stops() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_eq(
		_buttons()[0].mouse_filter, Control.MOUSE_FILTER_IGNORE, "the pointer cannot reach it"
	)
	_buttons()[0].pressed.emit()
	assert_eq(_chosen, [&"a"] as Array[StringName], "but the button's own pressed still chooses")


## In-place changes are not a new menu: they do not start the guard again, so a click that toggles
## an entry (Fullscreen) works twice in a row.
func test_guard_changes_in_place_do_not_restart_it() -> void:
	_spawn_panel()
	_panel.pointer_guard_seconds = GUARD_SECONDS
	_panel.open("Paused", "", _entries(), &"a")
	var opened_at: int = Time.get_ticks_msec()
	await _wait_msec(LATE_MSEC)
	assert_true(_panel.is_pointer_guarded(), "the premise: late in the guard, not past it")
	_panel.set_entry_text(&"a", "Changed")
	_panel.set_entry_enabled(&"c", true)
	_panel.set_body("Something else")
	assert_true(await _wait_until_unguarded(), "the guard ended")
	var elapsed_msec: int = Time.get_ticks_msec() - opened_at
	assert_lt(elapsed_msec, NOT_RESTARTED_MSEC, "on its first time, not restarted")
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_guard_changes_in_place_after_the_guard_do_not_start_it() -> void:
	_spawn_panel()
	_panel.pointer_guard_seconds = GUARD_SECONDS
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(await _wait_until_unguarded())
	_panel.set_entry_text(&"a", "Changed")
	_panel.set_entry_enabled(&"c", true)
	_panel.set_body("Something else")
	assert_false(_panel.is_pointer_guarded())
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)


# --- helpers ---


## Real time, on process frames (the guard counts real time, not frames).
func _wait_msec(msec: int) -> void:
	var until: int = Time.get_ticks_msec() + msec
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


## Waits for the guard to end, for at most GUARD_WAIT_LIMIT_MSEC; true if it did.
func _wait_until_unguarded() -> bool:
	var until: int = Time.get_ticks_msec() + GUARD_WAIT_LIMIT_MSEC
	while _panel.is_pointer_guarded() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	return not _panel.is_pointer_guarded()


func _spawn_panel() -> void:
	_panel = PANEL_SCENE.instantiate()
	_panel.entry_chosen.connect(func(id: StringName) -> void: _chosen.append(id))
	_panel.cancelled.connect(func() -> void: _cancelled += 1)
	add_child_autofree(_panel)


## Alpha and Beta enabled, Gamma disabled.
func _entries() -> Array[MenuEntry]:
	return [
		MenuEntry.make(&"a", "Alpha"),
		MenuEntry.make(&"b", "Beta"),
		MenuEntry.make(&"c", "Gamma", false),
	]


func _heading_label() -> Label:
	return _panel.get_node(HEADING_PATH)


func _body_label() -> Label:
	return _panel.get_node(BODY_PATH)


func _list() -> VBoxContainer:
	return _panel.get_node(BUTTONS_PATH)


func _buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _list().get_children():
		if not child.is_queued_for_deletion():
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
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)


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


## Records every event that reaches `_unhandled_input`, i.e. that nobody consumed.
func _spy_on_unhandled_input() -> InputSpy:
	var spy: InputSpy = InputSpy.new()
	add_child_autofree(spy)
	return spy


class InputSpy:
	extends Node
	var events: Array[InputEvent] = []

	func _unhandled_input(event: InputEvent) -> void:
		events.append(event)

	## Presses only: a release of a key the menu chose with is not the menu's to consume.
	func pressed_count() -> int:
		var count: int = 0
		for event: InputEvent in events:
			if event.is_pressed():
				count += 1
		return count
