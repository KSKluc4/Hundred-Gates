extends Node
## The player's settings and their file (F-015/C12). `settings` is created once and never replaced,
## so a listener stays connected. Per machine and written at run time, so not part of `Tunables`.
## This node never touches a file by itself: no file access in _init, _ready or _enter_tree, and
## none when a setting changes. Only an explicit call to load_from() or save_to() does. The shell
## makes those calls; tests that change `settings` call reset_to_defaults() afterwards.
##
## The file is plain text both ways, read and written here by hand, and no `ConfigFile` is used
## (F-015 code review rounds 2 and 3, CR-10, CR-27). `ConfigFile.load()` reads Godot's variant text,
## which can build objects and run a script from a hand-written line; cleaning up after the parser
## cannot be made complete. So load_from() reads the bytes itself and understands only a
## `[settings]` line and, below it, `key=true` and `key=false` for the two known keys. Nothing else
## in the file is ever built from or looked at. And save_to() writes the same few lines itself, so
## a later Godot that writes a bool or a header differently cannot make saved settings read as the
## defaults. The lines are exactly what `ConfigFile` wrote until then, so a file of the old writer
## is still read.

const DEFAULT_PATH: String = "user://settings.cfg"  # G5
const SECTION: String = "settings"
## A settings file the game writes is about 60 bytes. A larger file is not one, and is not read: a
## file of any size cannot make load_from() slow.
const MAX_FILE_BYTES: int = 65536
const _TRUE_TEXT: String = "true"
const _FALSE_TEXT: String = "false"
## What an editor on Windows may put at the start of a UTF-8 file.
const _BOM: PackedByteArray = [0xEF, 0xBB, 0xBF]

var settings: GameSettings = GameSettings.new(Tunables.shell)


## Reads the file into `settings`, in place; true when it was read. A missing file is the defaults
## and false, silently. A file that cannot be opened or read, is larger than MAX_FILE_BYTES, holds
## a NUL byte, or has content but no `[settings]` line is the defaults, false and one warning. An
## empty file, or one with the section and no usable line, is the defaults and true. A key that is
## missing or whose text is not exactly `true` or `false` is that setting's default; the last line
## of a key decides. Godot prints no error line of its own in any of these cases.
func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		settings.reset()
		return false
	var values: Dictionary = {}
	var problem: String = _read_values(path, values)
	if not problem.is_empty():
		push_warning("settings file %s %s" % [path, problem])
		settings.reset()
		return false
	settings.from_dict(values)
	return true


## Fills `values` with the bools the file gives its two known keys. Returns what is wrong with the
## file, or an empty string when it is a settings file.
func _read_values(path: String, values: Dictionary) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "could not be opened (%s)" % error_string(FileAccess.get_open_error())
	var length: int = file.get_length()
	if length > MAX_FILE_BYTES:
		return "is larger than %d bytes" % MAX_FILE_BYTES
	var bytes: PackedByteArray = file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		return "could not be read"
	if bytes.has(0):
		return "is not a text file"
	if bytes.slice(0, _BOM.size()) == _BOM:
		bytes = bytes.slice(_BOM.size())
	# ASCII, not UTF-8: every byte becomes a character and the engine has nothing to report on
	# bytes that are not valid UTF-8. Only ASCII is looked at below.
	return _parse(bytes.get_string_from_ascii(), values)


## The lines of `text` (`\n` or `\r\n`). Blank lines and lines that start with `;` or `#` are
## skipped. A line that starts with `[` opens a section: only `[settings]` is the one read.
func _parse(text: String, values: Dictionary) -> String:
	var header: String = "[%s]" % SECTION
	var in_section: bool = false
	var found_section: bool = false
	var has_content: bool = false
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue
		has_content = true
		if line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("["):
			in_section = line == header
			found_section = found_section or in_section
			continue
		if in_section:
			_read_line(line, values)
	if has_content and not found_section:
		return "is not a settings file (no [%s] line)" % SECTION
	return ""


## `key=true` or `key=false`, for the two known keys. A later line for the key replaces an earlier
## one: one whose text is anything else leaves the key out, so it is the default.
func _read_line(line: String, values: Dictionary) -> void:
	var equals: int = line.find("=")
	if equals < 0:
		return
	var key: String = line.left(equals).strip_edges()
	if key != GameSettings.KEY_SCREEN_SHAKE_ENABLED and key != GameSettings.KEY_FULLSCREEN:
		return
	var text: String = line.substr(equals + 1).strip_edges()
	if text == _TRUE_TEXT:
		values[key] = true
	elif text == _FALSE_TEXT:
		values[key] = false
	else:
		values.erase(key)


## Writes `settings` to `path`: `[settings]`, an empty line, then `screen_shake_enabled=<bool>` and
## `fullscreen=<bool>`, each line ended by `\n`, no BOM. A failed write is false and one warning;
## the setting keeps its value for this run. The file is written to `path` itself, in one
## `store_string()` call. If the file cannot be opened nothing is touched (an older file stays as it
## was). If the write fails after the open (the disk is full), the file is removed rather than left
## half written, so the next load finds no file and gives the defaults; a half line could otherwise
## read as a setting (`screen_shake_enabled=fals` is the default, which is on).
func save_to(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_warn_not_written(path, FileAccess.get_open_error())
		return false
	var stored: bool = file.store_string(_file_text())
	var error: Error = file.get_error()
	file.close()
	if not stored or error != OK:
		DirAccess.remove_absolute(path)
		_warn_not_written(path, error if error != OK else ERR_FILE_CANT_WRITE)
		return false
	return true


## The whole file, as `ConfigFile` wrote it: the section line, an empty line, one line a setting.
func _file_text() -> String:
	var text: String = "[%s]\n\n" % SECTION
	var values: Dictionary = settings.to_dict()
	for key: String in values:
		text += "%s=%s\n" % [key, _TRUE_TEXT if values[key] else _FALSE_TEXT]
	return text


func _warn_not_written(path: String, error: Error) -> void:
	push_warning("settings file %s could not be written (%s)" % [path, error_string(error)])


## Both settings back to the data's defaults, in place.
func reset_to_defaults() -> void:
	settings.reset()
