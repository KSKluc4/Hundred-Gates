extends GutTest
## AC6: the project's input map must match this table exactly.

const DEADZONE: float = 0.2


func test_defines_exactly_the_expected_actions() -> void:
	var actions: Array[String] = []
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			actions.append(String(action))
	actions.sort()
	var expected: Array[String] = []
	expected.assign(_expected_bindings().keys())
	expected.sort()
	assert_eq(actions, expected)


func test_each_action_has_the_expected_bindings() -> void:
	var bindings: Dictionary = _expected_bindings()
	for action: String in bindings:
		var actual: Array[String] = []
		for event: InputEvent in InputMap.action_get_events(action):
			actual.append(_describe(event))
		actual.sort()
		var expected: Array[String] = []
		expected.assign(bindings[action])
		expected.sort()
		assert_eq(actual, expected, action)


func test_each_action_uses_the_stick_deadzone() -> void:
	for action: String in _expected_bindings():
		assert_almost_eq(InputMap.action_get_deadzone(action), DEADZONE, 0.001, action)


func _expected_bindings() -> Dictionary:
	return {
		"move_up":
		[_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1), _pad(JOY_BUTTON_DPAD_UP)],
		"move_down":
		[_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1), _pad(JOY_BUTTON_DPAD_DOWN)],
		"move_left":
		[_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1), _pad(JOY_BUTTON_DPAD_LEFT)],
		"move_right":
		[_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1), _pad(JOY_BUTTON_DPAD_RIGHT)],
		"attack": [_key(KEY_J), _mouse(MOUSE_BUTTON_LEFT), _pad(JOY_BUTTON_X)],
		"dodge": [_key(KEY_SPACE), _pad(JOY_BUTTON_A)],
		"interact": [_key(KEY_E), _pad(JOY_BUTTON_Y)],
		"pause": [_key(KEY_ESCAPE), _pad(JOY_BUTTON_START)],
		"debug_toggle": [_key(KEY_F3)],
	}


func _describe(event: InputEvent) -> String:
	if event is InputEventKey:
		return _key((event as InputEventKey).physical_keycode)
	if event is InputEventMouseButton:
		return _mouse((event as InputEventMouseButton).button_index)
	if event is InputEventJoypadButton:
		return _pad((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		return _axis(motion.axis, int(signf(motion.axis_value)))
	return "unknown:%s" % event


func _key(keycode: Key) -> String:
	return "key:%d" % keycode


func _mouse(button: MouseButton) -> String:
	return "mouse:%d" % button


func _pad(button: JoyButton) -> String:
	return "pad:%d" % button


func _axis(axis: JoyAxis, direction: int) -> String:
	return "axis:%d:%d" % [axis, direction]
