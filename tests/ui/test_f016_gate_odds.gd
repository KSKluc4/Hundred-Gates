# gdlint:disable=max-public-methods
extends GutTest
## F-016 T4 (AC23's menu part, C19): the gate's `Odds` node and the `ListMenu` hook it hangs on. The
## texts are given to the menu, which only shows them: what they say is test_f016_item_texts'. The
## keys and the pad go through the engine's input path, as in test_gate_menu; a real click needs a
## layer above GUT's own (128), which swallows positional clicks, so that test raises the menu's.

const MENU_SCENE: PackedScene = preload("res://src/ui/town/gate_menu.tscn")
const SCREEN: Vector2 = Vector2(640.0, 360.0)
const ABOVE_GUT_LAYER: int = 129
const ODDS_PATH: NodePath = ^"Odds"
const PANEL_PATH: NodePath = ^"Panel"
const LIST_PATH: NodePath = ^"Panel/List"
const FLOOR_ONE_ODDS: String = "Boss drops:\n30% chance: One"
const FLOOR_TWO_ODDS: String = "Boss drops:\n30% chance: Two"
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


func before_each() -> void:
	_chosen = []
	_closed = 0
	_held_keys = []
	_held_pad_buttons = []


func after_each() -> void:
	for key: Key in _held_keys:
		_send_key(key, false)
	for button: JoyButton in _held_pad_buttons:
		_send_pad_button(button, false)
	Input.flush_buffered_events()
	for action: StringName in HANDLED_ACTIONS:
		assert_false(Input.is_action_pressed(action), "%s let go of" % action)
	# F-012/CR-22: the buttons a second open() replaced are queued, not gone, until the frame ends.
	await get_tree().process_frame


# --- the node ---


func test_ac23_the_odds_node_is_beside_the_panel_and_the_list_is_where_it_was() -> void:
	_spawn_menu()
	assert_true(_menu.get_node(ODDS_PATH) is PanelContainer)
	assert_eq(_menu.get_node(ODDS_PATH).get_parent(), _menu, "beside Panel, not inside it")
	assert_eq(_menu.get_node(ODDS_PATH).get_child_count(), 1)
	assert_true(_menu.get_node("Odds/Label") is Label)
	assert_true(_menu.get_node(PANEL_PATH) is PanelContainer)
	assert_true(_menu.get_node(LIST_PATH) is VBoxContainer)
	assert_eq(_menu.get_node(PANEL_PATH).get_child_count(), 1, "Panel holds the list alone")


func test_ac23_nothing_is_shown_before_the_menu_opens() -> void:
	_spawn_menu()
	assert_false(_menu.is_odds_visible())
	assert_eq(_menu.get_odds_text(), "")
	assert_false(_odds().visible)


# --- which entry shows which text ---


func test_ac23_opening_shows_the_text_of_the_floor_the_focus_starts_on() -> void:
	_spawn_menu()
	_menu.open(_three_entries(), _odds_by_floor())
	assert_eq(_menu.get_focus_index(), 2)
	assert_true(_menu.is_odds_visible())
	assert_eq(_menu.get_odds_text(), FLOOR_TWO_ODDS)
	assert_true(_odds().visible)
	assert_eq(_label().text, FLOOR_TWO_ODDS)


func test_ac23_both_entries_of_a_floor_show_that_floors_text() -> void:
	_spawn_menu()
	_menu.open(_three_entries(), _odds_by_floor())
	_press(&"ui_up")
	assert_eq(_menu.get_focus_index(), 1, "floor 1 at the boss")
	assert_eq(_menu.get_odds_text(), FLOOR_ONE_ODDS)
	_press(&"ui_up")
	assert_eq(_menu.get_focus_index(), 0, "floor 1 from the start")
	assert_eq(_menu.get_odds_text(), FLOOR_ONE_ODDS)
	_press(&"ui_down")
	_press(&"ui_down")
	assert_eq(_menu.get_odds_text(), FLOOR_TWO_ODDS, "and back to floor 2")


func test_ac23_stay_in_town_hides_the_odds_and_leaving_it_shows_them_again() -> void:
	_spawn_menu()
	_menu.open(_three_entries(), _odds_by_floor())
	_press(&"ui_down")
	assert_eq(_menu.get_focus_index(), 3, "the stay entry")
	assert_false(_menu.is_odds_visible())
	assert_eq(_menu.get_odds_text(), "")
	assert_false(_odds().visible)
	_press(&"ui_up")
	assert_true(_menu.is_odds_visible())
	assert_eq(_menu.get_odds_text(), FLOOR_TWO_ODDS)


func test_ac23_with_no_floor_entry_the_stay_entry_has_the_focus_and_nothing_shows() -> void:
	_spawn_menu()
	var none: Array[TowerEntry] = []
	_menu.open(none, _odds_by_floor())
	assert_eq(_menu.get_focus_index(), 0)
	assert_false(_menu.is_odds_visible())


func test_ac23_a_floor_with_no_text_shows_nothing() -> void:
	_spawn_menu()
	_menu.open(_three_entries(), {1: FLOOR_ONE_ODDS})
	assert_false(_menu.is_odds_visible(), "floor 2 has no text")
	_press(&"ui_up")
	assert_true(_menu.is_odds_visible(), "floor 1 has one")
	assert_eq(_menu.get_odds_text(), FLOOR_ONE_ODDS)
	_press(&"ui_down")
	assert_false(_menu.is_odds_visible())


func test_ac23_an_empty_text_shows_nothing() -> void:
	_spawn_menu()
	_menu.open(_three_entries(), {1: "", 2: ""})
	assert_false(_menu.is_odds_visible())
	_press(&"ui_up")
	assert_false(_menu.is_odds_visible())
	assert_false(_odds().visible)


func test_ac23_no_dictionary_never_shows_the_area() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	for _i: int in 5:
		assert_false(_menu.is_odds_visible())
		assert_eq(_menu.get_odds_text(), "")
		_press(&"ui_up")
	for _i: int in 5:
		assert_false(_menu.is_odds_visible())
		_press(&"ui_down")


func test_ac23_closing_by_a_choice_hides_the_odds() -> void:
	_spawn_menu()
	_menu.open(_three_entries(), _odds_by_floor())
	_press(&"ui_accept")
	assert_eq(_chosen, [Vector2i(2, 0)] as Array[Vector2i])
	assert_false(_menu.is_open())
	assert_false(_menu.is_odds_visible())
	assert_false(_odds().visible)


func test_ac23_closing_by_cancel_and_by_close_hides_the_odds() -> void:
	_spawn_menu()
	_menu.open(_three_entries(), _odds_by_floor())
	_press(&"ui_cancel")
	assert_eq(_closed, 1)
	assert_false(_menu.is_odds_visible())
	_menu.open(_three_entries(), _odds_by_floor())
	assert_true(_menu.is_odds_visible())
	_menu.close()
	assert_false(_menu.is_odds_visible())
	assert_eq(_menu.get_odds_text(), "")


func test_ac23_reopening_with_other_texts_shows_the_new_ones() -> void:
	_spawn_menu()
	_menu.open(_three_entries(), _odds_by_floor())
	_menu.open(_three_entries(), {2: "Changed", 1: "Other"})
	assert_eq(_menu.get_odds_text(), "Changed")
	_menu.open(_three_entries())
	assert_false(_menu.is_odds_visible(), "no dictionary: the old texts are gone")


func test_ac23_the_menus_own_copy_is_not_changed_by_the_callers() -> void:
	_spawn_menu()
	var texts: Dictionary = _odds_by_floor()
	_menu.open(_three_entries(), texts)
	texts[2] = "Changed afterwards"
	_press(&"ui_up")
	_press(&"ui_down")
	assert_eq(_menu.get_odds_text(), FLOOR_TWO_ODDS)


func test_ac23_a_text_of_several_lines_keeps_its_lines() -> void:
	_spawn_menu()
	_menu.open(_three_entries(), {2: "a\nb\nc"})
	assert_eq(_menu.get_odds_text(), "a\nb\nc")


# --- where the panels are ---


func test_ac23_the_list_panel_is_where_it_was_whichever_entry_has_the_focus() -> void:
	_spawn_menu()
	_menu.open(_three_entries(), _odds_by_floor())
	await get_tree().process_frame
	var at_start: Rect2 = _list_panel().get_global_rect()
	var positions: Array[Rect2] = []
	for _i: int in 3:
		_press(&"ui_up")
		await get_tree().process_frame
		positions.append(_list_panel().get_global_rect())
	for _i: int in 4:
		_press(&"ui_down")
		await get_tree().process_frame
		positions.append(_list_panel().get_global_rect())
	for rect: Rect2 in positions:
		assert_eq(rect, at_start, "the list never moves")
	# And the same panel with no odds at all.
	var bare: Rect2 = _open_bare_and_measure()
	assert_eq(bare, at_start, "the same place as without any odds")


func test_ac23_the_odds_panel_is_at_the_bottom_centre_of_the_screen() -> void:
	_spawn_menu()
	_menu.open(_three_entries(), _odds_by_floor())
	await get_tree().process_frame
	var rect: Rect2 = _odds().get_global_rect()
	assert_almost_eq(rect.get_center().x, SCREEN.x / 2.0, 1.0, "centred")
	assert_true(rect.end.y <= SCREEN.y, "above the bottom edge")
	assert_true(rect.end.y > SCREEN.y - 40.0, "at the bottom")
	assert_true(rect.position.y > _list_panel().get_global_rect().end.y, "below the list")


func test_ac23_seven_entries_and_five_lines_fit_the_screen_without_overlap() -> void:
	await _assert_every_shipped_floor_fits(7)


func test_ac23_six_entries_and_five_lines_also_fit() -> void:
	await _assert_every_shipped_floor_fits(6)


# --- the hook ---


func test_the_hook_is_empty_in_the_base_and_the_gate_still_works_without_a_dictionary() -> void:
	_spawn_menu()
	_menu.open(_three_entries())
	_press(&"ui_up")
	_press(&"ui_accept")
	assert_eq(_chosen, [Vector2i(1, 1)] as Array[Vector2i])


func test_the_hook_fires_once_for_the_focus_a_menu_opens_with() -> void:
	var hook: HookMenu = _spawn_hook_menu()
	hook.open_with(4, 2)
	assert_eq(hook.moves, [2] as Array[int])
	hook.open_with(4, 2)
	assert_eq(hook.moves, [2, 2] as Array[int], "an open with the same focus is still an open")


func test_the_hook_fires_for_the_keys() -> void:
	var hook: HookMenu = _spawn_hook_menu()
	hook.open_with(4, 0)
	hook.moves.clear()
	_press_key(KEY_DOWN)
	_press_key(KEY_DOWN)
	_press_key(KEY_UP)
	assert_eq(hook.moves, [1, 2, 1] as Array[int])
	_press(&"move_down")
	assert_eq(hook.moves, [1, 2, 1, 2] as Array[int], "the game's own actions move it as well")


func test_the_hook_fires_for_the_pad() -> void:
	var hook: HookMenu = _spawn_hook_menu()
	hook.open_with(4, 1)
	hook.moves.clear()
	_press_pad_button(JOY_BUTTON_DPAD_DOWN)
	_press_pad_button(JOY_BUTTON_DPAD_DOWN)
	_press_pad_button(JOY_BUTTON_DPAD_UP)
	assert_eq(hook.moves, [2, 3, 2] as Array[int])


func test_the_hook_does_not_fire_when_the_focus_cannot_move() -> void:
	var hook: HookMenu = _spawn_hook_menu()
	hook.open_with(3, 0)
	hook.moves.clear()
	_press_key(KEY_UP)
	assert_eq(hook.moves, [] as Array[int], "already at the top")
	_press_key(KEY_DOWN)
	_press_key(KEY_DOWN)
	_press_key(KEY_DOWN)
	_press_key(KEY_DOWN)
	assert_eq(hook.moves, [1, 2] as Array[int], "and again at the bottom")


func test_the_hook_fires_when_a_button_takes_the_focus_by_itself() -> void:
	var hook: HookMenu = _spawn_hook_menu()
	hook.open_with(4, 0)
	hook.moves.clear()
	hook.get_buttons()[3].grab_focus()
	assert_eq(hook.moves, [3] as Array[int], "what Tab and a click do")
	assert_eq(hook.get_focus_index(), 3)


func test_the_hook_fires_for_a_real_click() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = ABOVE_GUT_LAYER
	add_child_autofree(layer)
	var hook: HookMenu = HookMenu.new()
	layer.add_child(hook)
	hook.open_with(4, 0)
	await get_tree().process_frame
	hook.moves.clear()
	var at: Vector2 = hook.get_buttons()[2].get_global_rect().get_center()
	await _post_click(at)
	assert_eq(hook.get_focus_index(), 2, "the click took the focus")
	assert_eq(hook.moves, [2] as Array[int])


func test_the_gate_still_chooses_by_key_pad_and_click() -> void:
	_spawn_menu()
	_menu.open(_three_entries(), _odds_by_floor())
	_press_key(KEY_ENTER)
	assert_eq(_chosen, [Vector2i(2, 0)] as Array[Vector2i], "key")
	_menu.open(_three_entries(), _odds_by_floor())
	_press_pad_button(JOY_BUTTON_DPAD_UP)
	_press_pad_button(JOY_BUTTON_A)
	assert_eq(_chosen.back(), Vector2i(1, 1), "pad")
	_menu.open(_three_entries(), _odds_by_floor())
	((_menu.get_node(LIST_PATH) as VBoxContainer).get_child(0) as Button).pressed.emit()
	assert_eq(_chosen.back(), Vector2i(1, 0), "click")
	assert_eq(_chosen.size(), 3)
	assert_eq(_closed, 0)


# --- helpers ---


func _spawn_menu() -> void:
	_menu = MENU_SCENE.instantiate()
	_menu.entry_chosen.connect(
		func(floor_number: int, at_boss: bool) -> void:
			_chosen.append(Vector2i(floor_number, 1 if at_boss else 0))
	)
	_menu.closed.connect(func() -> void: _closed += 1)
	add_child_autofree(_menu)


func _spawn_hook_menu() -> HookMenu:
	var hook: HookMenu = HookMenu.new()
	add_child_autofree(hook)
	return hook


func _odds_by_floor() -> Dictionary:
	return {1: FLOOR_ONE_ODDS, 2: FLOOR_TWO_ODDS}


## Floor 1 from the start and at the boss, then floor 2 from the start.
func _three_entries() -> Array[TowerEntry]:
	return [_entry(1, false), _entry(1, true), _entry(2, false)]


## `count` entries: floor 1 from the start, floor 1 at the boss, floor 2 from the start, and so on.
func _entries_of_floors(count: int) -> Array[TowerEntry]:
	var entries: Array[TowerEntry] = []
	for index: int in count:
		entries.append(_entry(1 + floori(index / 2.0), index % 2 == 1))
	return entries


## The same text for every floor the `count` entries of `_entries_of_floors` name.
func _same_text_for(count: int, text: String) -> Dictionary:
	var texts: Dictionary = {}
	for entry: TowerEntry in _entries_of_floors(count):
		texts[entry.floor_number] = text
	return texts


func _entry(floor_number: int, at_boss: bool) -> TowerEntry:
	var entry: TowerEntry = TowerEntry.new()
	entry.floor_number = floor_number
	entry.at_boss = at_boss
	return entry


## For each shipped floor, with the guarantee line and with the percent left over: the menu with
## `entry_count` entries and the floor's real odds text on every floor, both panels measured.
func _assert_every_shipped_floor_fits(entry_count: int) -> void:
	var catalog: LootCatalog = load(Tunables.LOOT_CATALOG_PATH)
	var widest: Rect2 = Rect2()
	for floor_number: int in range(1, catalog.floors.size() + 1):
		for guaranteed: bool in [true, false]:
			var label: String = "floor %d, guaranteed %s" % [floor_number, guaranteed]
			var odds: String = ItemTexts.odds_text(
				catalog.get_floor_loot(floor_number), ItemFixtures.class_data(), 0.3, guaranteed
			)
			_spawn_menu()
			_menu.open(_entries_of_floors(entry_count), _same_text_for(entry_count, odds))
			await get_tree().process_frame
			var list_rect: Rect2 = _list_panel().get_global_rect()
			var odds_rect: Rect2 = _odds().get_global_rect()
			assert_eq(_label().get_line_count(), 5, "%s: five lines" % label)
			assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(list_rect), "%s: list" % label)
			assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(odds_rect), "%s: odds" % label)
			assert_false(list_rect.intersects(odds_rect), "%s: no overlap" % label)
			if odds_rect.size.y > widest.size.y:
				widest = odds_rect
			gut.p("%d entries, %s: list %s, odds %s" % [entry_count, label, list_rect, odds_rect])
			_menu.queue_free()
			await get_tree().process_frame
	assert_gt(widest.size.y, 0.0)


func _odds() -> PanelContainer:
	return _menu.get_node(ODDS_PATH)


func _label() -> Label:
	return _menu.get_node("Odds/Label")


func _list_panel() -> PanelContainer:
	return _menu.get_node(PANEL_PATH)


## Opens the same entries with no odds on a second menu and returns where its list panel is.
func _open_bare_and_measure() -> Rect2:
	var bare: GateMenu = MENU_SCENE.instantiate()
	add_child_autofree(bare)
	bare.open(_three_entries())
	return (bare.get_node(PANEL_PATH) as PanelContainer).get_global_rect()


## A press and a release of an input action through the engine's input path.
func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _press_key(key: Key) -> void:
	_send_key(key, true)
	_send_key(key, false)
	Input.flush_buffered_events()


## Both `keycode` and `physical_keycode` are set, so the event matches the built-in `ui_*` actions
## and the project's own alike.
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
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## A left click at canvas point `at`: the pointer moves there, then a press and a release a frame
## apart, through the window's final transform.
func _post_click(at: Vector2) -> void:
	var window_at: Vector2 = get_viewport().get_final_transform() * at
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = window_at
	motion.global_position = window_at
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = window_at
		event.global_position = window_at
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame


## A ListMenu with a column of plain buttons that records where its hook was called.
class HookMenu:
	extends ListMenu

	var moves: Array[int] = []

	func _ready() -> void:
		_panel = PanelContainer.new()
		add_child(_panel)
		_list = VBoxContainer.new()
		_panel.add_child(_list)
		super._ready()

	func open_with(count: int, focus: int) -> void:
		_clear_buttons()
		for index: int in count:
			_add_button("Entry %d" % index, _nothing)
		_show_list()
		_set_focus(focus)

	func get_buttons() -> Array[Button]:
		return _buttons

	func _nothing() -> void:
		pass

	func _focus_moved(index: int) -> void:
		moves.append(index)
