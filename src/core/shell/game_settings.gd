class_name GameSettings
extends RefCounted
## The player's settings (F-015/C11): screen shake and fullscreen. Plain values; the file work is
## the UserSettings autoload's (C12) and applying a value is the shell's and the camera's (C13,
## C14). A setter emits `changed` only when the value really changes.

signal changed

const KEY_SCREEN_SHAKE_ENABLED: String = "screen_shake_enabled"
const KEY_FULLSCREEN: String = "fullscreen"

var screen_shake_enabled: bool = true:
	set(value):
		if value == screen_shake_enabled:
			return
		screen_shake_enabled = value
		changed.emit()

var fullscreen: bool = false:
	set(value):
		if value == fullscreen:
			return
		fullscreen = value
		changed.emit()

var _defaults: ShellTunables


## F-015/C11: the settings start at `defaults`; core never reaches for the autoload.
func _init(defaults: ShellTunables) -> void:
	_defaults = defaults
	screen_shake_enabled = defaults.default_screen_shake_enabled
	fullscreen = defaults.default_fullscreen


## Both settings back to the defaults this object was given.
func reset() -> void:
	screen_shake_enabled = _defaults.default_screen_shake_enabled
	fullscreen = _defaults.default_fullscreen


func to_dict() -> Dictionary:
	return {
		KEY_SCREEN_SHAKE_ENABLED: screen_shake_enabled,
		KEY_FULLSCREEN: fullscreen,
	}


## F-015/C11: never fails. A key that is missing, or whose value is not a bool, puts that setting
## at its default; unknown keys are ignored. `changed` comes once for each setting that changed.
func from_dict(values: Dictionary) -> void:
	screen_shake_enabled = _read_bool(
		values, KEY_SCREEN_SHAKE_ENABLED, _defaults.default_screen_shake_enabled
	)
	fullscreen = _read_bool(values, KEY_FULLSCREEN, _defaults.default_fullscreen)


func _read_bool(values: Dictionary, key: String, fallback: bool) -> bool:
	if typeof(values.get(key)) == TYPE_BOOL:
		return values[key]
	return fallback
