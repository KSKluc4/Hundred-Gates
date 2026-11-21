# gdlint:disable=max-public-methods,max-file-lines
extends GutTest
## F-015 T4 (AC11): the menu panel. Keys, the d-pad and the stick go through the engine's input
## path (Input.parse_input_event) so `_input` answers them, as in test_gate_menu. A positional mouse
## click cannot get under GUT's own layer, so a click is the button's own `pressed` (which reaches
## `choose`) or `choose(id)` itself; only the double-click tests put the panel on a layer above
## GUT's and click for real. Whatever a test presses, after_each lets go of.
##
## The choose guard (F-015 code review, fixes A) is OFF in the common fixture (`_spawn_panel()`:
## `choose_guard_seconds = 0.0`), so the tests that choose by key right after `open()` test what
## they test; the guard tests use `_spawn_guarded_panel()`, which keeps the default.

const PANEL_SCENE: PackedScene = preload("res://src/ui/menus/menu_panel.tscn")
const HEADING_PATH: NodePath = ^"Panel/Content/Heading"
const BODY_PATH: NodePath = ^"Panel/Content/Body"
const BUTTONS_PATH: NodePath = ^"Panel/Content/Buttons"
## A short choose guard for the tests that wait for it (the default is 0.3 s), in seconds. A change
## in place is made LATE_MSEC into it; a guard that ends before NOT_RESTARTED_MSEC was not started
## again by it (that would end at LATE_MSEC + the guard, 430 and more). And how long a wait for it
## may take before the test calls it stuck.
const GUARD_SECONDS: float = 0.25
## A guard far longer than any test: for what must come during it.
const LONG_GUARD_SECONDS: float = 30.0
## The menu layer's number in the tests that click: above GUT's own layer (128), which swallows
## every click below it.
const ABOVE_GUT_LAYER: int = 129
const LATE_MSEC: int = 180
const NOT_RESTARTED_MSEC: int = 350
const GUARD_WAIT_LIMIT_MSEC: int = 3000
## How much longer than the guard a stalled frame lasts, in milliseconds.
const STALL_EXTRA_MSEC: int = 70
## How long the presses of the restart test go on: more than twice the guard.
const RESTART_WATCH_MSEC: int = 700
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


# --- the choose guard (a second click, key or pad press must not act on the menu that opens) ---


func test_guard_the_default_is_a_third_of_a_second() -> void:
	_spawn_guarded_panel()
	assert_eq(_panel.choose_guard_seconds, 0.3)


func test_guard_the_entries_ignore_the_pointer_right_after_open() -> void:
	_spawn_guarded_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(_panel.is_choose_guarded())
	assert_eq(_buttons().size(), 3)
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_guard_the_entries_take_the_pointer_again_after_the_time() -> void:
	_spawn_guarded_panel()
	_panel.choose_guard_seconds = GUARD_SECONDS
	_panel.open("Paused", "", _entries(), &"a")
	var opened_at: int = Time.get_ticks_msec()
	assert_true(await _wait_until_unguarded(), "the guard ended")
	var elapsed_msec: int = Time.get_ticks_msec() - opened_at
	assert_gte(elapsed_msec, roundi(GUARD_SECONDS * 1000.0), "not before its time (real time)")
	assert_false(_panel.is_choose_guarded())
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_guard_a_guard_of_zero_is_no_guard() -> void:
	_spawn_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_false(_panel.is_choose_guarded())
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)
	_press(&"ui_accept")
	assert_eq(_chosen, [&"a"] as Array[StringName], "and a key chooses at once")


func test_guard_every_open_starts_it_again() -> void:
	_spawn_guarded_panel()
	_panel.choose_guard_seconds = GUARD_SECONDS
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(await _wait_until_unguarded())
	_panel.open("Other", "", _entries(), &"b")
	assert_true(_panel.is_choose_guarded(), "a new menu is guarded again")
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_press(&"ui_accept")
	assert_eq(_chosen, [] as Array[StringName], "and its keys too")
	assert_true(await _wait_until_unguarded())
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_guard_choose_by_code_works_during_the_guard() -> void:
	_spawn_guarded_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(_panel.is_choose_guarded())
	_panel.choose(&"b")
	assert_eq(_chosen, [&"b"] as Array[StringName])


func test_guard_ui_accept_and_interact_choose_nothing_during_the_guard() -> void:
	_spawn_guarded_panel()
	_panel.open("Paused", "", _entries(), &"b")
	assert_true(_panel.is_choose_guarded())
	_press(&"ui_accept")
	_press(&"interact")
	assert_eq(_chosen, [] as Array[StringName], "neither chose")
	assert_eq(_cancelled, 0)
	assert_true(_panel.is_open())
	assert_eq(_panel.get_focus_id(), &"b", "and the focus stayed")


func test_guard_real_enter_space_e_and_pad_a_and_y_choose_nothing_during_the_guard() -> void:
	_spawn_guarded_panel()
	_panel.open("Paused", "", _entries(), &"b")
	for key: Key in [KEY_ENTER, KEY_SPACE, KEY_E]:
		_press_key(key)
	_press_pad_button(JOY_BUTTON_A)
	_press_pad_button(JOY_BUTTON_Y)
	assert_eq(_chosen, [] as Array[StringName])
	assert_eq(_cancelled, 0)


func test_guard_a_guarded_choose_key_is_still_consumed() -> void:
	_spawn_guarded_panel()
	var spy: InputSpy = _spy_on_unhandled_input()
	_panel.open("Paused", "", _entries(), &"b")
	_press(&"ui_accept")
	_press(&"interact")
	_press_key(KEY_ENTER)
	_press_pad_button(JOY_BUTTON_A)
	assert_eq(_chosen, [] as Array[StringName], "the premise: nothing was chosen")
	assert_eq(spy.pressed_count(), 0, "and nothing behind the panel saw the presses")


func test_guard_after_the_guard_the_keys_choose() -> void:
	_spawn_guarded_panel()
	_panel.choose_guard_seconds = GUARD_SECONDS
	_panel.open("Paused", "", _entries(), &"b")
	_press(&"ui_accept")
	assert_eq(_chosen.size(), 0, "during the guard: nothing")
	assert_true(await _wait_until_unguarded())
	_press(&"ui_accept")
	assert_eq(_chosen, [&"b"] as Array[StringName], "ui_accept")
	_press(&"interact")
	assert_eq(_chosen.size(), 2, "interact")
	_press_key(KEY_ENTER)
	assert_eq(_chosen.size(), 3, "enter")
	_press_pad_button(JOY_BUTTON_A)
	assert_eq(_chosen.size(), 4, "pad a")


func test_guard_the_focus_and_cancel_work_during_the_guard() -> void:
	_spawn_guarded_panel()
	var spy: InputSpy = _spy_on_unhandled_input()
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(_panel.is_choose_guarded())
	_press(&"ui_down")
	assert_eq(_panel.get_focus_id(), &"b", "the focus moves")
	_press_key(KEY_UP)
	assert_eq(_panel.get_focus_id(), &"a", "and again, by a real key")
	_press_pad_button(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_panel.get_focus_id(), &"b", "and by the d-pad")
	_press(&"ui_cancel")
	assert_eq(_cancelled, 1, "ui_cancel cancels")
	_press_key(KEY_ESCAPE)
	assert_eq(_cancelled, 2, "and so does a real Escape")
	assert_eq(spy.pressed_count(), 0, "all of it consumed")
	assert_true(_panel.is_choose_guarded(), "and the guard is still on")


func test_guard_a_click_on_the_button_itself_is_the_one_thing_it_stops() -> void:
	_spawn_guarded_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_eq(
		_buttons()[0].mouse_filter, Control.MOUSE_FILTER_IGNORE, "the pointer cannot reach it"
	)
	_buttons()[0].pressed.emit()
	assert_eq(_chosen, [&"a"] as Array[StringName], "but the button's own pressed still chooses")


## In-place changes are not a new menu: they do not start the guard again, so a click that toggles
## an entry (Fullscreen) works twice in a row.
func test_guard_changes_in_place_do_not_restart_it() -> void:
	_spawn_guarded_panel()
	_panel.choose_guard_seconds = GUARD_SECONDS
	_panel.open("Paused", "", _entries(), &"a")
	var opened_at: int = Time.get_ticks_msec()
	await _wait_msec(LATE_MSEC)
	assert_true(_panel.is_choose_guarded(), "the premise: late in the guard, not past it")
	_panel.set_entry_text(&"a", "Changed")
	_panel.set_entry_enabled(&"c", true)
	_panel.set_body("Something else")
	assert_true(await _wait_until_unguarded(), "the guard ended")
	var elapsed_msec: int = Time.get_ticks_msec() - opened_at
	assert_lt(elapsed_msec, NOT_RESTARTED_MSEC, "on its first time, not restarted")
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_guard_changes_in_place_after_the_guard_do_not_start_it() -> void:
	_spawn_guarded_panel()
	_panel.choose_guard_seconds = GUARD_SECONDS
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(await _wait_until_unguarded())
	_panel.set_entry_text(&"a", "Changed")
	_panel.set_entry_enabled(&"c", true)
	_panel.set_body("Something else")
	assert_false(_panel.is_choose_guarded())
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP)
	_press(&"ui_accept")
	assert_eq(_chosen, [&"a"] as Array[StringName], "and a key still chooses")


# --- a double click that opened something never chooses (real clicks, on a layer above GUT's) ---


func test_double_click_a_flagged_press_never_chooses_during_the_guard() -> void:
	_spawn_panel_on_a_layer_above_gut(LONG_GUARD_SECONDS)
	var seen: RawInput = _watch_raw_input_after_the_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(_panel.is_choose_guarded())
	await _post_clicks(_button_point(1), [true] as Array[bool])
	assert_eq(_chosen, [] as Array[StringName], "nothing chosen")
	assert_eq(seen.mouse_presses, 0, "and the panel consumed the press, nothing after it saw it")


func test_double_click_a_flagged_press_never_chooses_after_the_guard() -> void:
	_spawn_panel_on_a_layer_above_gut(GUARD_SECONDS)
	var seen: RawInput = _watch_raw_input_after_the_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(await _wait_until_unguarded())
	await _post_clicks(_button_point(1), [true] as Array[bool])
	assert_eq(_chosen, [] as Array[StringName], "the flagged press and its release chose nothing")
	assert_eq(_panel.get_focus_id(), &"a", "the press did not even take the focus")
	assert_eq(seen.mouse_presses, 0, "consumed: the menu had just opened")


func test_double_click_with_no_guard_at_all_it_still_never_chooses() -> void:
	_spawn_panel_on_a_layer_above_gut(0.0)
	_panel.open("Paused", "", _entries(), &"a")
	assert_false(_panel.is_choose_guarded())
	await _post_clicks(_button_point(1), [true] as Array[bool])
	assert_eq(_chosen, [] as Array[StringName])


func test_double_click_an_ordinary_click_after_the_guard_chooses_and_during_it_does_not() -> void:
	_spawn_panel_on_a_layer_above_gut(GUARD_SECONDS)
	_panel.open("Paused", "", _entries(), &"a")
	await _post_clicks(_button_point(1), [false] as Array[bool])
	assert_eq(_chosen, [] as Array[StringName], "during the guard: nothing")
	assert_true(await _wait_until_unguarded())
	await _post_clicks(_button_point(1), [false] as Array[bool])
	assert_eq(_chosen, [&"b"] as Array[StringName], "after it, an ordinary click chooses")


func test_double_click_a_flagged_press_and_the_release_after_it_press_nothing() -> void:
	_spawn_panel_on_a_layer_above_gut(0.0)
	_panel.open("Paused", "", _entries(), &"a")
	var at: Vector2 = _window_point(_button_point(1))
	_post_mouse(at, true, true)
	_post_mouse(at, false, false)
	await get_tree().process_frame
	assert_eq(_chosen, [] as Array[StringName], "the release alone presses nothing")
	assert_eq(_panel.get_focus_id(), &"a")


## Never opened and never closed: nothing to follow, so nothing to consume.
func test_double_click_while_the_panel_is_closed_is_not_consumed() -> void:
	_spawn_panel()
	var seen: RawInput = _watch_raw_input_after_the_panel()
	_post_mouse(Vector2(5.0, 5.0), true, true)
	_post_mouse(Vector2(5.0, 5.0), false, false)
	await get_tree().process_frame
	assert_eq(seen.mouse_presses, 1, "a panel that never opened has nothing to follow")
	assert_eq(_chosen, [] as Array[StringName])


# --- the flag: opened or closed since the last press (CR-23) ---


## `open()` sets it; the flagged press that follows is consumed, once and only then: the next
## flagged press, with no menu opened or closed in between, is an ordinary press and chooses.
func test_flag_open_sets_it_and_a_consumed_press_clears_it() -> void:
	_spawn_panel_on_a_layer_above_gut(0.0)
	var seen: RawInput = _watch_raw_input_after_the_panel()
	_panel.open("Paused", "", _entries(), &"a")
	await _post_clicks(_button_point(1), [true] as Array[bool])
	assert_eq(seen.mouse_presses, 0, "the first flagged press: consumed")
	assert_eq(_chosen, [] as Array[StringName])
	await _post_clicks(_button_point(1), [true] as Array[bool])
	assert_eq(seen.mouse_presses, 1, "the second: not consumed")
	assert_eq(_chosen, [&"b"] as Array[StringName], "and it chose")


## Every `open()` sets it again, also one that rebuilds the menu that is open.
func test_flag_every_open_sets_it_again() -> void:
	_spawn_panel_on_a_layer_above_gut(0.0)
	var seen: RawInput = _watch_raw_input_after_the_panel()
	_panel.open("Paused", "", _entries(), &"a")
	await _lay_out()
	await _post_clicks(_button_point(1), [false] as Array[bool])
	assert_eq(_chosen, [&"b"] as Array[StringName], "the premise: an ordinary click cleared it")
	_panel.open("Other", "", _entries(), &"a")
	await _lay_out()
	await _post_clicks(_button_point(1), [true] as Array[bool])
	assert_eq(seen.mouse_presses, 1, "only the ordinary click reached what is behind the panel")
	assert_eq(_chosen, [&"b"] as Array[StringName], "the flagged press after the new menu: lost")


## A closed panel looks at no mouse button at all: after open() and close(), flagged or not, every
## press reaches what is behind it. (A double click on an entry that closes the menu reaches the
## game as an ordinary click.) Opening it again sets the flag by that open.
func test_flag_a_closed_panel_consumes_nothing_and_the_next_open_sets_it() -> void:
	_spawn_panel()
	var seen: RawInput = _watch_raw_input_after_the_panel()
	_panel.open("Paused", "", _entries(), &"a")
	_panel.close()
	for flagged: bool in [true, true, false, true]:
		_post_mouse(Vector2(5.0, 5.0), true, flagged)
		_post_mouse(Vector2(5.0, 5.0), false, false)
	assert_eq(seen.mouse_presses, 4, "a closed panel consumes nothing, flagged or not")
	_panel.open("Paused", "", _entries(), &"a")
	_post_mouse(Vector2(5.0, 5.0), true, true)
	_post_mouse(Vector2(5.0, 5.0), false, false)
	assert_eq(
		seen.mouse_presses, 4, "the open after it set the flag: the flagged press is consumed"
	)


## An ordinary press of any button clears it; a flagged press after that is an ordinary one.
func test_flag_an_unflagged_press_of_any_button_clears_it() -> void:
	for button_index: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		_spawn_panel()
		var seen: RawInput = _watch_raw_input_after_the_panel()
		_panel.open("Paused", "", _entries(), &"a")
		_post_mouse(Vector2(5.0, 5.0), true, false, button_index)
		_post_mouse(Vector2(5.0, 5.0), false, false, button_index)
		assert_eq(
			seen.mouse_presses, 1, "the premise: the press went by (button %d)" % button_index
		)
		_post_mouse(Vector2(5.0, 5.0), true, true)
		_post_mouse(Vector2(5.0, 5.0), false, false)
		assert_eq(
			seen.mouse_presses, 2, "the flagged press passed (after button %d)" % button_index
		)
		_panel.queue_free()
		await get_tree().process_frame


## A menu open for a long time and an ordinary click on it: a flagged press is a choice. It is
## pressed, not only left alone: the button chooses on its release.
func test_flag_a_flagged_press_on_a_menu_open_for_long_chooses_after_an_ordinary_click() -> void:
	_spawn_panel_on_a_layer_above_gut(GUARD_SECONDS)
	var seen: RawInput = _watch_raw_input_after_the_panel()
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(await _wait_until_unguarded())
	await _post_clicks(_button_point(0), [false] as Array[bool])
	assert_eq(_chosen, [&"a"] as Array[StringName], "the premise: the ordinary click chose")
	await _wait_msec(LATE_MSEC)
	await _post_clicks(_button_point(1), [true] as Array[bool])
	assert_eq(seen.mouse_presses, 2, "the flagged press reached what is behind the panel")
	assert_eq(_chosen, [&"a", &"b"] as Array[StringName], "and the button chose on it")


## A flagged press right after another menu opened is lost; the next ordinary click is not, and
## neither is a flagged one after it.
func test_flag_a_flagged_press_right_after_a_new_menu_is_the_only_one_lost() -> void:
	_spawn_panel_on_a_layer_above_gut(GUARD_SECONDS)
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(await _wait_until_unguarded())
	await _post_clicks(_button_point(1), [false] as Array[bool])
	assert_eq(_chosen, [&"b"] as Array[StringName], "the first click chose, as the shell would")
	_panel.open("Next", "", _entries(), &"a")  # What the shell does for that choice.
	assert_true(await _wait_until_unguarded())
	await _post_clicks(_button_point(1), [true] as Array[bool])
	assert_eq(_chosen, [&"b"] as Array[StringName], "the flagged press after the new menu is lost")
	assert_true(await _wait_until_unguarded(), "(it started the guard again: wait it out)")
	await _post_clicks(_button_point(1), [false, true] as Array[bool])
	assert_eq(
		_chosen,
		[&"b", &"b", &"b"] as Array[StringName],
		"the plain click after it chooses, and the flagged one after that too"
	)


# --- a press during the guard starts it again (CR-24) ---


## A press every frame for far longer than the guard: each one that comes less than a guard after
## the one before (every one but a frame stalled by a busy machine) finds the guard still running.
## Without the restart the guard would have ended 0.25 s after open(), and a press at 0.3 s would
## find it over. The presses are on a button: the guarded entries ignore them, nothing is chosen.
func test_restart_a_press_during_the_guard_starts_it_again() -> void:
	_spawn_panel_on_a_layer_above_gut(GUARD_SECONDS)
	_panel.open("Paused", "", _entries(), &"a")
	var at: Vector2 = _window_point(_button_point(1))
	var started: int = Time.get_ticks_msec()
	var last_press: int = started
	var checked: int = 0
	while Time.get_ticks_msec() < started + RESTART_WATCH_MSEC:
		var now: int = Time.get_ticks_msec()
		if now - last_press < roundi(GUARD_SECONDS * 1000.0):
			assert_true(_panel.is_choose_guarded(), "still guarded %d ms in" % (now - started))
			checked += 1
		last_press = now
		_post_mouse(at, true, false)
		_post_mouse(at, false, false)
		await get_tree().process_frame
	assert_gte(checked, 10, "the premise: enough presses came inside the guard's time")
	assert_eq(_chosen, [] as Array[StringName], "the guarded entries ignored every press")
	assert_true(await _wait_until_unguarded(), "and it ends")
	assert_gte(
		Time.get_ticks_msec() - last_press,
		roundi(GUARD_SECONDS * 1000.0),
		"a guard's time after the LAST press"
	)


## A press the panel consumes (a flagged one) starts it again too.
func test_restart_a_consumed_flagged_press_starts_it_again() -> void:
	_spawn_panel_on_a_layer_above_gut(GUARD_SECONDS)
	_panel.open("Paused", "", _entries(), &"a")
	await _wait_msec(LATE_MSEC)
	assert_true(_panel.is_choose_guarded(), "the premise: late in the guard, not past it")
	var at: Vector2 = _window_point(_button_point(1))
	var pressed_at: int = Time.get_ticks_msec()
	_post_mouse(at, true, true)
	_post_mouse(at, false, false)
	assert_true(await _wait_until_unguarded(), "it ends")
	assert_gte(
		Time.get_ticks_msec() - pressed_at, roundi(GUARD_SECONDS * 1000.0), "a guard's time from it"
	)
	assert_eq(_chosen, [] as Array[StringName])


## A press after the guard's time is over, before `_process` has noticed, is a press on entries
## that take the pointer: it is not ignored, and the guard does not start again for it.
func test_restart_a_press_after_the_guards_time_does_not() -> void:
	_spawn_panel_on_a_layer_above_gut(GUARD_SECONDS)
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(await _wait_until_unguarded())
	var at: Vector2 = _window_point(_button_point(1))
	_post_mouse(at, true, false)
	assert_false(_panel.is_choose_guarded(), "a press after the guard does not start it")
	_post_mouse(at, false, false)
	assert_eq(_chosen, [&"b"] as Array[StringName], "and it chooses")


## A press the panel consumes starts the guard again even when it had just ended: the click after a
## consumed one is still a quick click (CR round 4). The entries ignore the pointer again.
func test_restart_a_consumed_flagged_press_after_the_guard_ended_starts_it() -> void:
	_spawn_panel_on_a_layer_above_gut(GUARD_SECONDS)
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(await _wait_until_unguarded())
	var at: Vector2 = _window_point(_button_point(1))
	var pressed_at: int = Time.get_ticks_msec()
	_post_mouse(at, true, true)
	assert_true(_panel.is_choose_guarded(), "the consumed press started the guard again")
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_post_mouse(at, false, false)
	_post_mouse(at, true, false)
	_post_mouse(at, false, false)
	assert_eq(_chosen, [] as Array[StringName], "so the plain press right after it chose nothing")
	assert_true(await _wait_until_unguarded(), "and it ends")
	assert_gte(
		Time.get_ticks_msec() - pressed_at, roundi(GUARD_SECONDS * 1000.0), "a guard's time from it"
	)


## A flagged press that is NOT consumed (the flag was cleared by a plain click) after the guard
## ended is an ordinary click: it chooses and starts nothing.
func test_restart_a_flagged_press_that_is_not_consumed_after_the_guard_does_not() -> void:
	_spawn_panel_on_a_layer_above_gut(GUARD_SECONDS)
	_panel.open("Paused", "", _entries(), &"a")
	assert_true(await _wait_until_unguarded())
	var at: Vector2 = _window_point(_button_point(1))
	_post_mouse(at, true, false)
	_post_mouse(at, false, false)
	_post_mouse(at, true, true)
	assert_false(_panel.is_choose_guarded(), "nothing started the guard")
	_post_mouse(at, false, false)
	assert_eq(_chosen, [&"b", &"b"] as Array[StringName], "both chose")


## A guard of 0 seconds set while a guard runs: the next press ends it properly, and the entries
## take the pointer again (they were left on IGNORE until the next open()).
func test_restart_with_a_guard_set_to_zero_during_one_gives_the_pointer_back() -> void:
	_spawn_panel_on_a_layer_above_gut(LONG_GUARD_SECONDS)
	_panel.open("Paused", "", _entries(), &"a")
	await _lay_out()
	assert_true(_panel.is_choose_guarded(), "the premise: a guard runs")
	_panel.choose_guard_seconds = 0.0
	var at: Vector2 = _window_point(_button_point(1))
	_post_mouse(at, true, false)
	_post_mouse(at, false, false)
	assert_false(_panel.is_choose_guarded(), "the press ended it")
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP, "the entries take the pointer")
	await _post_clicks(_button_point(1), [false] as Array[bool])
	assert_eq(_chosen, [&"b"] as Array[StringName], "and a click chooses")


## A frame stalled past the guard's time, then a plain press posted before any frame runs
## (`_process` has not noticed the end): the guard's real time is over, so the press ends it, does
## not start it again, and the entries take the pointer. (Whether that very press reaches a button
## depends on the viewport's hover, which the stall left as it was: not asserted.)
func test_restart_a_press_after_a_stall_that_ended_the_guard_does_not() -> void:
	_spawn_panel_on_a_layer_above_gut(GUARD_SECONDS)
	_panel.open("Paused", "", _entries(), &"a")
	await _lay_out()
	var at: Vector2 = _window_point(_button_point(1))
	assert_true(_panel.is_choose_guarded(), "the premise: the guard has not ended yet")
	OS.delay_msec(roundi(GUARD_SECONDS * 1000.0) + STALL_EXTRA_MSEC)
	assert_true(_panel.is_choose_guarded(), "no frame ran, so the panel has not noticed")
	_post_mouse(at, true, false)
	assert_false(
		_panel.is_choose_guarded(), "the press found the guard over and did not restart it"
	)
	for button: Button in _buttons():
		assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP, "the entries take the pointer")
	_post_mouse(at, false, false)


## A release is not a press: during the guard it does not start it again.
func test_restart_a_release_during_the_guard_does_not() -> void:
	_spawn_panel_on_a_layer_above_gut(GUARD_SECONDS)
	_panel.open("Paused", "", _entries(), &"a")
	var opened_at: int = Time.get_ticks_msec()
	await _wait_msec(LATE_MSEC)
	assert_true(_panel.is_choose_guarded(), "the premise: late in the guard, not past it")
	_post_mouse(_window_point(_button_point(1)), false, false)
	assert_true(await _wait_until_unguarded(), "the guard ended")
	assert_lt(Time.get_ticks_msec() - opened_at, NOT_RESTARTED_MSEC, "on its first time")


## And a release does not clear the double-click flag: the flagged press after it is consumed.
func test_flag_a_release_does_not_clear_it() -> void:
	_spawn_panel_on_a_layer_above_gut(0.0)
	var seen: RawInput = _watch_raw_input_after_the_panel()
	_panel.open("Paused", "", _entries(), &"a")
	await _lay_out()
	var at: Vector2 = _window_point(_button_point(1))
	_post_mouse(at, false, false)
	_post_mouse(at, true, true)
	_post_mouse(at, false, false)
	assert_eq(seen.mouse_presses, 0, "the flagged press was consumed: the release left the flag")
	assert_eq(_chosen, [] as Array[StringName])


## Keys, the pad and the stick, accepted or not, do not start it again: it ends on its first time.
func test_restart_a_key_during_the_guard_does_not() -> void:
	_spawn_guarded_panel()
	_panel.choose_guard_seconds = GUARD_SECONDS
	_panel.open("Paused", "", _entries(), &"a")
	var opened_at: int = Time.get_ticks_msec()
	await _wait_msec(LATE_MSEC)
	assert_true(_panel.is_choose_guarded(), "the premise: late in the guard, not past it")
	_press(&"ui_down")
	_press_key(KEY_ENTER)
	_press_key(KEY_UP)
	_press_pad_button(JOY_BUTTON_A)
	_press_pad_button(JOY_BUTTON_DPAD_DOWN)
	_press(&"ui_cancel")
	assert_true(await _wait_until_unguarded(), "the guard ended")
	var elapsed_msec: int = Time.get_ticks_msec() - opened_at
	assert_lt(elapsed_msec, NOT_RESTARTED_MSEC, "on its first time, not restarted by a key")
	assert_eq(_chosen, [] as Array[StringName], "(and the choose keys chose nothing in it)")


# --- helpers ---


## The frames in which the buttons of a menu that was just opened take their places: a rectangle
## read before them is the old menu's.
func _lay_out() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


## Real time, on process frames (the guard counts real time, not frames).
func _wait_msec(msec: int) -> void:
	var until: int = Time.get_ticks_msec() + msec
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


## Waits for the guard to end, for at most GUARD_WAIT_LIMIT_MSEC; true if it did.
func _wait_until_unguarded() -> bool:
	var until: int = Time.get_ticks_msec() + GUARD_WAIT_LIMIT_MSEC
	while _panel.is_choose_guarded() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	return not _panel.is_choose_guarded()


## The common fixture: the choose guard is off, so a test that chooses by key right after open()
## tests what it tests. The guard's own tests use `_spawn_guarded_panel()`.
func _spawn_panel() -> void:
	_spawn_guarded_panel()
	_panel.choose_guard_seconds = 0.0


## A panel as the scene gives it: the default guard.
func _spawn_guarded_panel() -> void:
	_panel = _new_panel()
	add_child_autofree(_panel)


func _new_panel() -> MenuPanel:
	var panel: MenuPanel = PANEL_SCENE.instantiate()
	panel.entry_chosen.connect(func(id: StringName) -> void: _chosen.append(id))
	panel.cancelled.connect(func() -> void: _cancelled += 1)
	return panel


## The panel on a canvas layer above GUT's, so a posted click reaches its buttons, with a guard of
## `guard_seconds`.
func _spawn_panel_on_a_layer_above_gut(guard_seconds: float) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = ABOVE_GUT_LAYER
	add_child_autofree(layer)
	_panel = _new_panel()
	_panel.choose_guard_seconds = guard_seconds
	layer.add_child(_panel)


## A node that sees every mouse button press that reaches it after the panel, so one the panel
## consumed does not count. It sits before the panel in the tree: `_input` goes in reverse order.
func _watch_raw_input_after_the_panel() -> RawInput:
	var watcher: RawInput = RawInput.new()
	_panel.get_parent().add_child(watcher)
	_panel.get_parent().move_child(watcher, 0)
	autofree(watcher)
	return watcher


## The middle of entry `index`, in the canvas.
func _button_point(index: int) -> Vector2:
	return _buttons()[index].get_global_rect().get_center()


## A canvas point in the window's coordinates, where the OS posts its events: through the
## viewport's final transform (the identity in the headless window, not elsewhere).
func _window_point(canvas_point: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * canvas_point


## One click per entry of `flags` (true: the press carries the OS's double-click mark), each a
## press and a release a frame apart, at canvas point `at`; the pointer moves there first.
func _post_clicks(at: Vector2, flags: Array[bool]) -> void:
	var window_at: Vector2 = _window_point(at)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = window_at
	motion.global_position = window_at
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame
	for flagged: bool in flags:
		_post_mouse(window_at, true, flagged)
		await get_tree().process_frame
		_post_mouse(window_at, false, false)
		await get_tree().process_frame


func _post_mouse(
	window_at: Vector2, pressed: bool, double: bool, button_index: MouseButton = MOUSE_BUTTON_LEFT
) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.double_click = double
	event.position = window_at
	event.global_position = window_at
	var left: bool = pressed and button_index == MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if left else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


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


## Counts the mouse button presses that reach `_input` behind the panel.
class RawInput:
	extends Node
	var mouse_presses: int = 0

	func _input(event: InputEvent) -> void:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button != null and button.pressed:
			mouse_presses += 1


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
