extends Node
## The player's settings and their file (F-015/C12). `settings` is created once and never replaced,
## so a listener stays connected. Per machine and written at run time, so not part of `Tunables`.
## This node never touches a file by itself: no file access in _init, _ready or _enter_tree, and
## none when a setting changes. Only an explicit call to load_from() or save_to() does. The shell
## makes those calls; tests that change `settings` call reset_to_defaults() afterwards.

const DEFAULT_PATH: String = "user://settings.cfg"  # G5
const SECTION: String = "settings"

var settings: GameSettings = GameSettings.new(Tunables.shell)


## Reads the file into `settings`, in place. A missing file is the defaults and false, silently.
## A file that cannot be read or is not a ConfigFile is the defaults, false and one warning. True
## when the file was read; a value in it that is missing or not a bool is that setting's default.
func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		settings.reset()
		return false
	var file: ConfigFile = ConfigFile.new()
	var error: Error = file.load(path)
	if error != OK:
		push_warning("settings file %s could not be read (%s)" % [path, error_string(error)])
		settings.reset()
		return false
	var values: Dictionary = {}
	if file.has_section(SECTION):
		for key: String in file.get_section_keys(SECTION):
			values[key] = file.get_value(SECTION, key)
	settings.from_dict(values)
	return true


## Writes `settings` to `path`. A failed write is false and one warning; the setting keeps its
## value for this run.
func save_to(path: String) -> bool:
	var file: ConfigFile = ConfigFile.new()
	var values: Dictionary = settings.to_dict()
	for key: String in values:
		file.set_value(SECTION, key, values[key])
	var error: Error = file.save(path)
	if error != OK:
		push_warning("settings file %s could not be written (%s)" % [path, error_string(error)])
		return false
	return true


## Both settings back to the data's defaults, in place.
func reset_to_defaults() -> void:
	settings.reset()
