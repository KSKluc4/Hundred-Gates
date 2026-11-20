extends GutTest
## F-012/CR-17: the built-in `ui_*` actions the menus rely on. `ui_accept` and `ui_cancel` are
## overridden in project.godot to add a pad button (the engine's own lists have none), so every
## menu gets it. tests/test_input_map.gd pins the game's own actions and skips these.

const BUILT_IN_DEADZONE: float = 0.5
const MENU_ACTIONS: Array[StringName] = [&"ui_accept", &"ui_cancel"]


func test_ui_accept_is_enter_keypad_enter_space_and_pad_a() -> void:
	assert_eq(
		_bindings(&"ui_accept"),
		_sorted([_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE), _pad(JOY_BUTTON_A)])
	)


func test_ui_cancel_is_escape_and_pad_b() -> void:
	assert_eq(_bindings(&"ui_cancel"), _sorted([_key(KEY_ESCAPE), _pad(JOY_BUTTON_B)]))


func test_ui_up_and_ui_down_keep_their_key_dpad_and_stick() -> void:
	assert_eq(
		_bindings(&"ui_up"),
		_sorted([_key(KEY_UP), _pad(JOY_BUTTON_DPAD_UP), _axis(JOY_AXIS_LEFT_Y, -1)])
	)
	assert_eq(
		_bindings(&"ui_down"),
		_sorted([_key(KEY_DOWN), _pad(JOY_BUTTON_DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1)])
	)


func test_ui_left_and_ui_right_keep_their_key_dpad_and_stick() -> void:
	assert_eq(
		_bindings(&"ui_left"),
		_sorted([_key(KEY_LEFT), _pad(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1)])
	)
	assert_eq(
		_bindings(&"ui_right"),
		_sorted([_key(KEY_RIGHT), _pad(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1)])
	)


func test_the_ui_actions_keep_the_built_in_deadzone() -> void:
	for action: StringName in [
		&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"
	]:
		assert_almost_eq(InputMap.action_get_deadzone(action), BUILT_IN_DEADZONE, 0.001, action)


## Pad A is `dodge` too, and pad B is nothing else: the override added nothing to the game's own
## actions, and no pad button now answers two of the gate list's choose actions.
func test_pad_a_is_ui_accept_and_dodge_and_pad_b_is_only_ui_cancel() -> void:
	assert_eq(_actions_of(_pad_event(JOY_BUTTON_A)), [&"dodge", &"ui_accept"] as Array[StringName])
	assert_eq(_actions_of(_pad_event(JOY_BUTTON_B)), [&"ui_cancel"] as Array[StringName])
	assert_eq(_actions_of(_pad_event(JOY_BUTTON_Y)), [&"interact"] as Array[StringName])
	assert_eq(_actions_of(_pad_event(JOY_BUTTON_X)), [&"attack"] as Array[StringName])


func _bindings(action: StringName) -> Array[String]:
	var bindings: Array[String] = []
	for event: InputEvent in InputMap.action_get_events(action):
		bindings.append(_describe(event))
	bindings.sort()
	return bindings


func _sorted(bindings: Array[String]) -> Array[String]:
	bindings.sort()
	return bindings


## The actions of the game, and the menu's two, that an event matches, sorted. (The engine's own
## editor actions, `ui_select` on Y and the like, are not the game's business.)
func _actions_of(event: InputEvent) -> Array[StringName]:
	var actions: Array[StringName] = []
	for action: StringName in InputMap.get_actions():
		var ours: bool = not String(action).begins_with("ui_") or action in MENU_ACTIONS
		if ours and event.is_action(action):
			actions.append(action)
	actions.sort()
	return actions


func _pad_event(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


## The built-in keys are bound by `keycode`, the game's by `physical_keycode`: either says which.
func _describe(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event
		return _key(key.keycode if key.keycode != KEY_NONE else key.physical_keycode)
	if event is InputEventJoypadButton:
		return _pad((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		return _axis(motion.axis, int(signf(motion.axis_value)))
	return "unknown:%s" % event


func _key(keycode: Key) -> String:
	return "key:%d" % keycode


func _pad(button: JoyButton) -> String:
	return "pad:%d" % button


func _axis(axis: JoyAxis, direction: int) -> String:
	return "axis:%d:%d" % [axis, direction]
