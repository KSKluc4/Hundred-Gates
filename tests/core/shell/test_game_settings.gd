extends GutTest
## F-015 T2 (AC6, C11): GameSettings. Defaults come from the ShellTunables it is given, a setter
## emits `changed` only when the value changes, and from_dict() never fails.

var _defaults: ShellTunables
var _settings: GameSettings


func before_each() -> void:
	_defaults = ShellTunables.new()
	_settings = GameSettings.new(_defaults)
	watch_signals(_settings)


func test_defaults_come_from_the_given_tunables() -> void:
	assert_true(_settings.screen_shake_enabled)
	assert_false(_settings.fullscreen)
	var other: ShellTunables = ShellTunables.new()
	other.default_screen_shake_enabled = false
	other.default_fullscreen = true
	var from_other: GameSettings = GameSettings.new(other)
	assert_false(from_other.screen_shake_enabled)
	assert_true(from_other.fullscreen)


func test_the_shipped_defaults_are_the_ones_given() -> void:
	var shipped: GameSettings = GameSettings.new(Tunables.shell)
	assert_eq(shipped.to_dict(), {"screen_shake_enabled": true, "fullscreen": false})


func test_a_setter_emits_changed_once_when_the_value_changes() -> void:
	_settings.screen_shake_enabled = false
	assert_signal_emit_count(_settings, "changed", 1)
	_settings.fullscreen = true
	assert_signal_emit_count(_settings, "changed", 2)


func test_a_setter_with_the_same_value_emits_nothing() -> void:
	_settings.screen_shake_enabled = true
	_settings.fullscreen = false
	assert_signal_not_emitted(_settings, "changed")
	_settings.screen_shake_enabled = false
	_settings.screen_shake_enabled = false
	assert_signal_emit_count(_settings, "changed", 1)


func test_reset_returns_to_the_defaults_and_emits_only_for_what_changed() -> void:
	_settings.reset()
	assert_signal_not_emitted(_settings, "changed")
	_settings.screen_shake_enabled = false
	_settings.fullscreen = true
	_settings.reset()
	assert_true(_settings.screen_shake_enabled)
	assert_false(_settings.fullscreen)
	assert_signal_emit_count(_settings, "changed", 4)


func test_to_dict_uses_the_key_constants() -> void:
	_settings.fullscreen = true
	var values: Dictionary = _settings.to_dict()
	assert_eq(values.size(), 2)
	assert_eq(values[GameSettings.KEY_SCREEN_SHAKE_ENABLED], true)
	assert_eq(values[GameSettings.KEY_FULLSCREEN], true)


func test_to_dict_then_from_dict_round_trips() -> void:
	for shake: bool in [true, false]:
		for fullscreen: bool in [true, false]:
			_settings.screen_shake_enabled = shake
			_settings.fullscreen = fullscreen
			var copy: GameSettings = GameSettings.new(_defaults)
			copy.from_dict(_settings.to_dict())
			assert_eq(copy.screen_shake_enabled, shake)
			assert_eq(copy.fullscreen, fullscreen)
			assert_eq(copy.to_dict(), _settings.to_dict())


func test_from_dict_emits_changed_only_for_what_changed() -> void:
	_settings.from_dict(_settings.to_dict())
	assert_signal_not_emitted(_settings, "changed")
	_settings.from_dict({"screen_shake_enabled": false, "fullscreen": false})
	assert_signal_emit_count(_settings, "changed", 1)
	_settings.from_dict({"screen_shake_enabled": false, "fullscreen": true})
	assert_signal_emit_count(_settings, "changed", 2)


func test_from_dict_of_an_empty_dictionary_keeps_the_defaults() -> void:
	_settings.from_dict({})
	assert_eq(_settings.to_dict(), {"screen_shake_enabled": true, "fullscreen": false})
	assert_signal_not_emitted(_settings, "changed")


func test_a_missing_key_is_that_settings_default() -> void:
	_settings.from_dict({"screen_shake_enabled": false})
	assert_false(_settings.screen_shake_enabled)
	assert_false(_settings.fullscreen, "its default")
	_settings.from_dict({"fullscreen": true})
	assert_true(_settings.screen_shake_enabled, "its default")
	assert_true(_settings.fullscreen)


func test_a_value_that_is_not_a_bool_is_that_settings_default() -> void:
	var not_bools: Array = [1, 0, 1.0, "true", "false", null, [], {}, Vector2.ONE, &"x"]
	for value: Variant in not_bools:
		_settings.screen_shake_enabled = false
		_settings.fullscreen = true
		_settings.from_dict({"screen_shake_enabled": value, "fullscreen": value})
		assert_true(_settings.screen_shake_enabled, "shake default for %s" % [value])
		assert_false(_settings.fullscreen, "fullscreen default for %s" % [value])


func test_unknown_keys_are_ignored() -> void:
	_settings.from_dict({"screen_shake_enabled": false, "volume": 3, 7: "x", "fullscreen": true})
	assert_false(_settings.screen_shake_enabled)
	assert_true(_settings.fullscreen)
	assert_eq(_settings.to_dict().size(), 2)


func test_from_dict_uses_the_given_defaults_for_what_it_cannot_read() -> void:
	var other: ShellTunables = ShellTunables.new()
	other.default_screen_shake_enabled = false
	other.default_fullscreen = true
	var settings: GameSettings = GameSettings.new(other)
	settings.screen_shake_enabled = true
	settings.fullscreen = false
	settings.from_dict({"fullscreen": "yes"})
	assert_false(settings.screen_shake_enabled)
	assert_true(settings.fullscreen)
