extends GutTest
## F-015 T4 (AC10, C8, C9): what the base class gives the gate list. The gate list's own rules are
## in test_gate_menu (not edited); here only what the move to ListMenu adds: it is a ListMenu, it
## handles `ui_cancel` and nothing of `pause` (so pad Start with the gate list open reaches the
## shell and does nothing, and Escape closes the list and goes no further).

const MENU_SCENE: PackedScene = preload("res://src/ui/town/gate_menu.tscn")

var _menu: GateMenu
var _closed: int = 0
var _chosen: int = 0
var _held_keys: Array[Key] = []
var _held_pad_buttons: Array[JoyButton] = []


func before_each() -> void:
	_closed = 0
	_chosen = 0
	_held_keys = []
	_held_pad_buttons = []


func after_each() -> void:
	for key: Key in _held_keys:
		_send_key(key, false)
	for button: JoyButton in _held_pad_buttons:
		_send_pad_button(button, false)
	Input.flush_buffered_events()
	await get_tree().process_frame


func test_ac10_the_gate_list_is_a_list_menu() -> void:
	_spawn_menu()
	assert_true(_menu is ListMenu)


func test_ac10_the_gate_lists_exports_come_from_the_base_with_the_same_defaults() -> void:
	_spawn_menu()
	assert_eq(_menu.font_size, 8)
	assert_eq(_menu.panel_min_width_px, 160.0)
	assert_eq(_menu.button_separation_px, 2)


func test_c8_a_pause_only_event_does_nothing_to_an_open_gate_list_and_is_not_consumed() -> void:
	_spawn_menu()
	var spy: InputSpy = InputSpy.new()
	add_child_autofree(spy)
	_menu.open(_one_entry())
	assert_true(_pad_button_event(JOY_BUTTON_START, true).is_action(&"pause"))
	_press_pad_button(JOY_BUTTON_START)
	assert_true(_menu.is_open())
	assert_eq(_closed, 0)
	assert_eq(_chosen, 0)
	assert_eq(spy.pressed_count(), 1, "the press reached what is behind the list")


func test_c8_escape_closes_the_gate_list_once_and_is_consumed() -> void:
	_spawn_menu()
	var spy: InputSpy = InputSpy.new()
	add_child_autofree(spy)
	_menu.open(_one_entry())
	_send_key(KEY_ESCAPE, true)
	_send_key(KEY_ESCAPE, false)
	Input.flush_buffered_events()
	assert_eq(_closed, 1)
	assert_false(_menu.is_open())
	assert_eq(spy.pressed_count(), 0, "so the shell never sees the Escape")


# --- the disabled button (C9): the base checks it, whatever the subclass's handler does ---


func test_c9_the_focused_disabled_button_is_not_pressed_by_a_key_or_a_pad_button() -> void:
	var probe: Probe = _spawn_probe()
	probe.open_buttons([false, true, false], 1)  # The middle one is disabled and focused.
	assert_true(probe.get_button(1).has_focus(), "a disabled button holds the focus")
	for action: StringName in [&"ui_accept", &"interact"]:
		_press_action(action)
	_press_pad_button(JOY_BUTTON_A)
	_press_pad_button(JOY_BUTTON_Y)
	assert_eq(probe.pressed_indexes, [] as Array[int], "its handler does not run")


func test_c9_an_enabled_button_is_pressed_once_by_each_choose_key() -> void:
	var probe: Probe = _spawn_probe()
	probe.open_buttons([false, true, false], 0)
	_press_action(&"ui_accept")
	_press_action(&"interact")
	assert_eq(probe.pressed_indexes, [0, 0] as Array[int])


func test_c9_moving_does_not_skip_a_disabled_button() -> void:
	var probe: Probe = _spawn_probe()
	probe.open_buttons([false, true, false], 0)
	_press_action(&"ui_down")
	assert_eq(probe.get_focus_index(), 1)
	_press_action(&"ui_down")
	assert_eq(probe.get_focus_index(), 2)


func test_c9_ui_cancel_calls_the_hook_once_and_pause_does_not() -> void:
	var probe: Probe = _spawn_probe()
	probe.open_buttons([false], 0)
	_press_action(&"ui_cancel")
	assert_eq(probe.cancels, 1)
	_press_pad_button(JOY_BUTTON_START)
	assert_eq(probe.cancels, 1)


func test_c9_a_menu_opened_with_no_buttons_survives_keys() -> void:
	var probe: Probe = _spawn_probe()
	probe.open_buttons([], 0)
	_press_action(&"ui_down")
	_press_action(&"ui_up")
	_press_action(&"ui_accept")
	assert_eq(probe.pressed_indexes, [] as Array[int])
	assert_true(probe.is_open())


# --- the hook that asks before a key chooses (MenuPanel's choose guard uses it) ---


func test_guard_hook_the_base_says_yes() -> void:
	var probe: Probe = _spawn_probe()
	assert_true(probe._may_choose_by_key())
	_spawn_menu()
	assert_true(_menu._may_choose_by_key(), "and so does the gate list")


func test_guard_hook_a_bare_subclass_chooses_by_key_and_pad_at_once_after_opening() -> void:
	var probe: Probe = _spawn_probe()
	probe.open_buttons([false, false], 1)
	_press_action(&"ui_accept")
	_press_action(&"interact")
	_press_pad_button(JOY_BUTTON_A)
	assert_eq(probe.pressed_indexes, [1, 1, 1] as Array[int])


func test_guard_hook_the_gate_list_chooses_by_key_at_once_after_opening() -> void:
	_spawn_menu()
	_menu.open(_one_entry())
	_press_action(&"ui_accept")
	assert_eq(_chosen, 1, "ui_accept")
	_menu.open(_one_entry())
	_press_action(&"interact")
	assert_eq(_chosen, 2, "interact")
	_menu.open(_one_entry())
	_press_pad_button(JOY_BUTTON_A)
	assert_eq(_chosen, 3, "pad A")


## What a subclass that says no gets from the base: the choose keys press nothing and are still
## consumed; moving the focus and `ui_cancel` are not asked.
func test_guard_hook_a_subclass_that_says_no_chooses_nothing_but_still_consumes_the_key() -> void:
	var probe: RefusingProbe = RefusingProbe.new()
	add_child_autofree(probe)
	var spy: InputSpy = InputSpy.new()
	add_child_autofree(spy)
	probe.open_buttons([false, false], 0)
	_press_action(&"ui_accept")
	_press_action(&"interact")
	_press_pad_button(JOY_BUTTON_A)
	assert_eq(probe.pressed_indexes, [] as Array[int], "nothing was pressed")
	assert_eq(spy.pressed_count(), 0, "and nothing behind the list saw the presses")
	_press_action(&"ui_down")
	assert_eq(probe.get_focus_index(), 1, "the focus moves")
	_press_action(&"ui_cancel")
	assert_eq(probe.cancels, 1, "and ui_cancel cancels")


func _spawn_probe() -> Probe:
	var probe: Probe = Probe.new()
	add_child_autofree(probe)
	return probe


func _press_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _spawn_menu() -> void:
	_menu = MENU_SCENE.instantiate()
	_menu.entry_chosen.connect(func(_floor: int, _at_boss: bool) -> void: _chosen += 1)
	_menu.closed.connect(func() -> void: _closed += 1)
	add_child_autofree(_menu)


func _one_entry() -> Array[TowerEntry]:
	var entry: TowerEntry = TowerEntry.new()
	entry.floor_number = 1
	return [entry]


func _send_key(key: Key, pressed: bool) -> void:
	if pressed and not _held_keys.has(key):
		_held_keys.append(key)
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
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


## A bare ListMenu subclass whose button handler checks nothing, so only the base can keep a
## disabled button from acting.
class Probe:
	extends ListMenu
	var pressed_indexes: Array[int] = []
	var cancels: int = 0

	func _ready() -> void:
		_panel = PanelContainer.new()
		add_child(_panel)
		_list = VBoxContainer.new()
		_panel.add_child(_list)
		super._ready()

	## One button per flag (true: disabled); focus on `focus_index`.
	func open_buttons(disabled_flags: Array[bool], focus_index: int) -> void:
		_clear_buttons()
		for index: int in disabled_flags.size():
			var button: Button = _add_button("b%d" % index, _on_button.bind(index))
			button.disabled = disabled_flags[index]
		_show_list()
		_set_focus(focus_index)

	func get_button(index: int) -> Button:
		return _buttons[index]

	func _on_button(index: int) -> void:
		pressed_indexes.append(index)

	func _on_cancel_pressed() -> void:
		cancels += 1


## A subclass whose hook says no: what MenuPanel does during its choose guard.
class RefusingProbe:
	extends Probe

	func _may_choose_by_key() -> bool:
		return false


class InputSpy:
	extends Node
	var events: Array[InputEvent] = []

	func _unhandled_input(event: InputEvent) -> void:
		events.append(event)

	func pressed_count() -> int:
		var count: int = 0
		for event: InputEvent in events:
			if event.is_pressed():
				count += 1
		return count
