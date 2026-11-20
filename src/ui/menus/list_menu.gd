class_name ListMenu
extends Control
## F-015/C9: a column of buttons that moves its own focus and answers the keys, the d-pad and the
## stick itself. It is the gate list's input (F-012/C10, AC23), moved here so the gate list and the
## menus of the shell (MenuPanel) feel the same and a fix is made once. It shows what its subclass
## puts in it and decides nothing.
##
## While open it moves the focus with `ui_up` / `ui_down` and `move_up` / `move_down`, chooses with
## `ui_accept` or `interact` (the focused button's own `pressed`, so a key and a click are one code
## path), and calls `_on_cancel_pressed()` on `ui_cancel`; left and right do nothing (one column).
## It handles `ui_cancel` and nothing of `pause`: an event that is only `pause` (pad Start) is
## neither handled nor consumed (F-015/C8). While closed it handles no input at all.
##
## What a subclass does: in `_ready`, set `_panel` and `_list` to its nodes and call `super()`;
## build its buttons with `_add_button()` after `_clear_buttons()`; call `_show_list()` and then
## `_set_focus()`; override `_on_cancel_pressed()`.

## Both action families move the focus and choose (F-012/AC23): the UI's and the game's.
const PREVIOUS_ACTIONS: Array[StringName] = [&"ui_up", &"move_up"]
const NEXT_ACTIONS: Array[StringName] = [&"ui_down", &"move_down"]
const CHOOSE_ACTIONS: Array[StringName] = [&"ui_accept", &"interact"]
const CANCEL_ACTION: StringName = &"ui_cancel"
## The list is one column and the menu moves it alone: while open, every event of these is consumed,
## so Godot's own focus navigation never adds a step or a sideways jump (F-012/CR-3).
const NAVIGATION_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]

@export var font_size: int = 8
@export var panel_min_width_px: float = 160.0
@export var button_separation_px: int = 2

var _buttons: Array[Button] = []
var _focus_index: int = 0
var _is_open: bool = false
## F-012/CR-3, CR-15, CR-16, CR-18: what the stick does. Only the stick itself speaks: the joypad
## motion events while the list is open, and the stick's own axes when it opens (keys and the d-pad
## never touch it). Per action: does the stick press it now. Per direction (up, down; the key is
## the family's first action): is a push going on. A push starts when every action of the direction
## is pressed (past the larger deadzone, 0.5) and ends when none is (back inside the smaller, 0.2);
## the band between is the hysteresis.
var _stick_pressed: Dictionary[StringName, bool] = {}
var _stick_pushing: Dictionary[StringName, bool] = {}
## The directions the event being handled started a push in.
var _fresh_pushes: Array[StringName] = []
## Set by the subclass before it calls `super._ready()`: the panel around everything (centred, and
## given its minimum width) and the box the buttons sit in.
var _panel: PanelContainer
var _list: VBoxContainer


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


## While open and nothing else has used the event, the keys are the menu's alone (F-012/AC23). Every
## outcome goes through the subclass's own choose and cancel, the same ones a click on a button
## reaches.
func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	_track_stick(event)
	var action: Callable = _action_for(event)
	if action.is_valid():
		get_viewport().set_input_as_handled()
		action.call()
	elif _is_navigation(event):
		get_viewport().set_input_as_handled()


## Hides the list. No signal: it is for whoever opened it and now has its own reasons to close.
func close() -> void:
	_is_open = false
	visible = false


func is_open() -> bool:
	return _is_open


## Which button has the focus: 0 for the first one.
func get_focus_index() -> int:
	return _focus_index


## What `ui_cancel` does while open. The subclass says; the base does nothing.
func _on_cancel_pressed() -> void:
	pass


## The part of opening every subclass shares, after its buttons are in: open, shown, and the stick
## read as it is (CR-18). The subclass then sets the focus, which hiding had dropped.
func _show_list() -> void:
	_is_open = true
	visible = true
	_seed_stick()


## The handler of the key `event` is, or an invalid Callable when it isn't one of the menu's.
func _action_for(event: InputEvent) -> Callable:
	if _is_pressed(event, PREVIOUS_ACTIONS):
		return _move_focus.bind(-1)
	if _is_pressed(event, NEXT_ACTIONS):
		return _move_focus.bind(1)
	if _is_pressed(event, CHOOSE_ACTIONS):
		return _press_focused
	if event.is_action_pressed(CANCEL_ACTION):
		return _on_cancel_pressed
	return Callable()


## Key repeat is not a press (is_action_pressed ignores echoes): a key held while walking into the
## gate does not choose. A stick event is a press only when it starts a push (CR-3, CR-16).
func _is_pressed(event: InputEvent, actions: Array[StringName]) -> bool:
	if event is InputEventJoypadMotion:
		return _fresh_pushes.has(actions[0])
	for action: StringName in actions:
		if event.is_action_pressed(action):
			return true
	return false


## Any event of the four ui navigation actions: a repeat, a release, a stick event that is not a
## crossing, a push sideways.
func _is_navigation(event: InputEvent) -> bool:
	for action: StringName in NAVIGATION_ACTIONS:
		if event.is_action(action):
			return true
	return false


## F-012/CR-18: a stick held at one value sends no event, and a new town (so a new menu) is built on
## every return from a floor. So when the list opens the stick is read as it is: a direction it is
## past the smaller deadzone in counts as already pushed, and neither that nor letting go of it is a
## push. The axes come from the bindings of the list's own actions. Every connected pad is asked,
## and device 0, which is where an event with no device (a synthetic one, the first pad) lands; the
## axis's largest reading wins. The player's own input asks the connected pads only, but a test has
## none connected.
func _seed_stick() -> void:
	_stick_pressed.clear()
	_stick_pushing.clear()
	_fresh_pushes.clear()
	var devices: Array[int] = Input.get_connected_joypads()
	if not devices.has(0):
		devices.append(0)
	for axis: JoyAxis in _bound_axes():
		var reading: float = 0.0
		for device: int in devices:
			var value: float = Input.get_joy_axis(device, axis)
			if absf(value) > absf(reading):
				reading = value
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = reading
		_track_stick(motion)
	for actions: Array[StringName] in [PREVIOUS_ACTIONS, NEXT_ACTIONS]:
		var held: bool = false
		for action: StringName in actions:
			held = held or _stick_pressed.get(action, false)
		_stick_pushing[actions[0]] = held
	_fresh_pushes.clear()


## The axes the up and down actions have a stick binding on.
func _bound_axes() -> Array[JoyAxis]:
	var axes: Array[JoyAxis] = []
	for actions: Array[StringName] in [PREVIOUS_ACTIONS, NEXT_ACTIONS]:
		for action: StringName in actions:
			for bound: InputEvent in InputMap.action_get_events(action):
				var motion: InputEventJoypadMotion = bound as InputEventJoypadMotion
				if motion != null and not axes.has(motion.axis):
					axes.append(motion.axis)
	return axes


## Every joypad motion event past a deadzone says "pressed", not only the first, and
## Input.is_action_just_pressed is no help: it is true for every event of the same frame. So the
## stick's state is kept here, from the motion events, and `_fresh_pushes` says which directions
## this event started a push in. A motion event only speaks for the axes an action is bound to: one
## on another axis changes nothing, and one on the same axis pointing the other way releases.
func _track_stick(event: InputEvent) -> void:
	_fresh_pushes.clear()
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion == null:
		return
	for actions: Array[StringName] in [PREVIOUS_ACTIONS, NEXT_ACTIONS]:
		var any: bool = false
		var every: bool = true
		for action: StringName in actions:
			if _is_bound_to_axis(action, motion.axis):
				_stick_pressed[action] = motion.is_action_pressed(action)
			var pressed: bool = _stick_pressed.get(action, false)
			any = any or pressed
			every = every and pressed
		var direction: StringName = actions[0]
		var pushing: bool = _stick_pushing.get(direction, false)
		if pushing and not any:
			_stick_pushing[direction] = false
		elif not pushing and every:
			_stick_pushing[direction] = true
			_fresh_pushes.append(direction)


func _is_bound_to_axis(action: StringName, axis: JoyAxis) -> bool:
	for bound: InputEvent in InputMap.action_get_events(action):
		if bound is InputEventJoypadMotion and (bound as InputEventJoypadMotion).axis == axis:
			return true
	return false


## Clamped: the list doesn't wrap. A disabled button is not skipped (F-015/C9): it can hold the
## focus, so the player can read it.
func _move_focus(step: int) -> void:
	_set_focus(clampi(_focus_index + step, 0, _buttons.size() - 1))


## The focused button's own press, so a key and a click are the same code path. A disabled button
## does nothing (F-015/C9): `pressed.emit()` would call its handler all the same.
func _press_focused() -> void:
	if _buttons.is_empty():
		return
	var button: Button = _buttons[_focus_index]
	if button.disabled:
		return
	button.pressed.emit()


## Does nothing when there is no such button: a menu opened with no entries has nothing to focus.
func _set_focus(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	_focus_index = index
	_buttons[index].grab_focus()


## One more button at the end of the column; `on_pressed` is what a click, and so a key, calls.
func _add_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", font_size)
	button.pressed.connect(on_pressed)
	# Sideways has nowhere to go: a neighbour that is itself keeps the focus where it is.
	button.focus_neighbor_left = ^"."
	button.focus_neighbor_right = ^"."
	# Godot's own focus moves (Tab, the mouse) keep the focus index true.
	button.focus_entered.connect(_on_button_focused.bind(_buttons.size()))
	_buttons.append(button)
	_list.add_child(button)
	return button


func _clear_buttons() -> void:
	for button: Button in _buttons:
		_list.remove_child(button)
		button.queue_free()  # F-012/CR-22: not free() inside input or a physics tick (F-011 DEV-13).
	_buttons.clear()


func _on_button_focused(index: int) -> void:
	_focus_index = index
