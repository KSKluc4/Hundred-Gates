class_name GateMenu
extends Control
## F-012/C10, AC23: the tower gate's plain list. One button per TowerEntry, then a last "stay"
## button. It shows what TowerProgress.get_entries() says and decides nothing (C2, G6): the town
## scene opens it and forwards the choice. Hidden until open(). While open it moves the focus with
## `ui_up` / `ui_down` and `move_up` / `move_down`, chooses with `ui_accept` or `interact`, and
## cancels with `ui_cancel`. While closed it handles no input at all. The look → Art & Game Feel
## (§10 Q4).

## Once, with the floor and where to start it; the menu has closed by then. Not emitted by cancel().
signal entry_chosen(floor_number: int, at_boss: bool)
## Closed without a choice: the stay entry, or `ui_cancel`.
signal closed

## F-012/C16: every player-facing string of the list.
const FROM_START_FORMAT: String = "Floor %d — from the start"
const AT_BOSS_FORMAT: String = "Floor %d — at the boss"
const CLEARED_SUFFIX: String = " (cleared)"
const STAY_TEXT: String = "Stay in town"

## Both action families move the focus and choose (AC23): the UI's and the game's.
const PREVIOUS_ACTIONS: Array[StringName] = [&"ui_up", &"move_up"]
const NEXT_ACTIONS: Array[StringName] = [&"ui_down", &"move_down"]
const CHOOSE_ACTIONS: Array[StringName] = [&"ui_accept", &"interact"]
const CANCEL_ACTION: StringName = &"ui_cancel"

@export var font_size: int = 8
@export var panel_min_width_px: float = 160.0
@export var button_separation_px: int = 2

var _entries: Array[TowerEntry] = []
var _buttons: Array[Button] = []
var _focus_index: int = 0
var _is_open: bool = false

@onready var _panel: PanelContainer = $Panel
@onready var _list: VBoxContainer = $Panel/List


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Centred whatever the viewport is, so the 640 x 360 placeholder isn't assumed.
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(panel_min_width_px, 0.0)
	_list.add_theme_constant_override(&"separation", button_separation_px)
	visible = _is_open


## While open and nothing else has used the event, the keys are the menu's alone (AC23). Every
## outcome goes through choose() or cancel(), the same two a click on a button reaches.
func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	var action: Callable = _action_for(event)
	if not action.is_valid():
		return
	get_viewport().set_input_as_handled()
	action.call()


## One line of the list per entry: "Floor 2 — at the boss (cleared)".
static func entry_text(entry: TowerEntry) -> String:
	var text: String = (AT_BOSS_FORMAT if entry.at_boss else FROM_START_FORMAT) % entry.floor_number
	if entry.is_cleared:
		text += CLEARED_SUFFIX
	return text


## Shows the list again from the start: calling it while open rebuilds it. The focus starts on
## the last floor entry, or on the stay entry when there are none.
func open(entries: Array[TowerEntry]) -> void:
	_clear_buttons()
	_entries = entries.duplicate()
	for index: int in _entries.size():
		_add_button(entry_text(_entries[index]), choose.bind(index))
	_add_button(STAY_TEXT, cancel)
	_is_open = true
	visible = true
	_set_focus(maxi(_entries.size() - 1, 0))


## Hides the list. No signal: it is for whoever opened it and now has its own reasons to close.
func close() -> void:
	_is_open = false
	visible = false


func is_open() -> bool:
	return _is_open


## The floor entries, without the stay entry.
func get_entry_count() -> int:
	return _entries.size()


## Which button has the focus: 0 for the first entry, get_entry_count() for the stay entry.
func get_focus_index() -> int:
	return _focus_index


## What a click on entry `index` does. An index outside the floor entries (the stay entry
## included) does nothing; so does a call while closed.
func choose(index: int) -> void:
	if not _is_open or index < 0 or index >= _entries.size():
		return
	var entry: TowerEntry = _entries[index]
	close()
	entry_chosen.emit(entry.floor_number, entry.at_boss)


## What the stay entry and `ui_cancel` do. Nothing while closed.
func cancel() -> void:
	if not _is_open:
		return
	close()
	closed.emit()


## The handler of the key `event` is, or an invalid Callable when it isn't one of the menu's.
func _action_for(event: InputEvent) -> Callable:
	if _is_pressed(event, PREVIOUS_ACTIONS):
		return _move_focus.bind(-1)
	if _is_pressed(event, NEXT_ACTIONS):
		return _move_focus.bind(1)
	if _is_pressed(event, CHOOSE_ACTIONS):
		return _press_focused
	if event.is_action_pressed(CANCEL_ACTION):
		return cancel
	return Callable()


## Key repeat is not a press (is_action_pressed ignores echoes): a key held while walking into the
## gate does not choose.
func _is_pressed(event: InputEvent, actions: Array[StringName]) -> bool:
	for action: StringName in actions:
		if event.is_action_pressed(action):
			return true
	return false


## Clamped: the list doesn't wrap.
func _move_focus(step: int) -> void:
	_set_focus(clampi(_focus_index + step, 0, _buttons.size() - 1))


## The focused button's own press, so a key and a click are the same code path.
func _press_focused() -> void:
	_buttons[_focus_index].pressed.emit()


func _set_focus(index: int) -> void:
	_focus_index = index
	_buttons[index].grab_focus()


func _add_button(text: String, on_pressed: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", font_size)
	button.pressed.connect(on_pressed)
	# Godot's own focus moves (Tab, the mouse) keep the focus index true.
	button.focus_entered.connect(_on_button_focused.bind(_buttons.size()))
	_buttons.append(button)
	_list.add_child(button)


func _clear_buttons() -> void:
	for button: Button in _buttons:
		_list.remove_child(button)
		button.free()
	_buttons.clear()
	_entries.clear()


func _on_button_focused(index: int) -> void:
	_focus_index = index
