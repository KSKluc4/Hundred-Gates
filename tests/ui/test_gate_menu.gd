# gdlint:disable=max-public-methods
extends GutTest
## F-012 T5 (AC23): the gate menu. The keys go through the engine's input path
## (Input.parse_input_event), so `_input` is what answers them. The town scene's use of the menu
## is tested in test_f012_town.

const MENU_SCENE: PackedScene = preload("res://src/ui/town/gate_menu.tscn")
const LIST_PATH: NodePath = ^"Panel/List"

var _menu: GateMenu
var _chosen: Array[Vector2i] = []
var _closed: int = 0


func before_each() -> void:
	_chosen = []
	_closed = 0


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
	for key: Key in [KEY_E, KEY_UP, KEY_ESCAPE]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		event.echo = true
		Input.parse_input_event(event)
	Input.flush_buffered_events()
	assert_true(_menu.is_open())
	assert_eq(_menu.get_focus_index(), 2)
	assert_eq(_chosen, [] as Array[Vector2i])
	assert_eq(_closed, 0)


func test_ac23_a_real_key_press_is_answered_too() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press_key(KEY_UP)  # ui_up and move_up at once: one step, not two.
	assert_eq(_menu.get_focus_index(), 1)
	_press_key(KEY_W)
	assert_eq(_menu.get_focus_index(), 0)
	_press_key(KEY_E)
	assert_eq(_chosen, [Vector2i(1, 0)] as Array[Vector2i])


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


## A press and a release of a physical key, which the project's input map turns into actions.
func _press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
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

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventAction and (event as InputEventAction).pressed:
			seen.append((event as InputEventAction).action)
