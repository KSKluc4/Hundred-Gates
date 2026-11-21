# gdlint:disable=max-public-methods
extends GutTest
## F-015 T2 (AC7, C12): the UserSettings autoload and its file. Every file here is the test's own,
## under a folder of this process (`user://test_f015_t2_<process id>/`: two runs of the project at
## once share `user://`, and one run must not delete or count the other's files);
## user://settings.cfg is never read or written. The one shared GameSettings goes back to the
## defaults after each test.
##
## Round 2 (CR-10): load_from() reads the file as text and builds nothing from it (a `ConfigFile`
## would build an object from `Object(Node,...)` and run a script from `Object(RefCounted,
## "script":Resource(...))`). The tests that write objects check what must not happen: no node, no
## object, no script run (a marker file), and the other lines of the file still read. A `Logger`
## counts the warnings and the engine's own error lines of each load: GUT cannot count a
## `push_warning`, and fails a test on an engine error only when it is not expecting it.

const DIR_PREFIX: String = "user://test_f015_t2_"
const SOURCE_PATH: String = "res://src/autoload/user_settings.gd"
const GARBAGE_BYTES: int = 4096
const HUGE_FILE_BYTES: int = 16 * 1024 * 1024
## A load of the huge file must be this quick (it is not read at all).
const HUGE_LOAD_LIMIT_MSEC: int = 1000
const OBJECT_NODE: String = 'Object(Node,"name":&"planted")'
const OBJECT_PLAIN: String = 'Object(Object,"script":null)'

var _dir: String = ""
var _file: String = ""
var _missing: String = ""
var _no_folder: String = ""
var _marker: String = ""
var _script_file: String = ""
var _log: LogCounter = null


func before_each() -> void:
	_dir = "%s%d" % [DIR_PREFIX, OS.get_process_id()]
	_file = _dir.path_join("settings.cfg")
	_missing = _dir.path_join("missing.cfg")
	_no_folder = _dir.path_join("no_such_folder/settings.cfg")
	_marker = _dir.path_join("marker.txt")
	_script_file = _dir.path_join("planted.gd")
	DirAccess.make_dir_recursive_absolute(_dir)
	UserSettings.reset_to_defaults()
	_log = LogCounter.new()
	OS.add_logger(_log)


func after_each() -> void:
	OS.remove_logger(_log)
	UserSettings.reset_to_defaults()
	for file_name: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file_name))
	DirAccess.remove_absolute(_dir)  # Only succeeds when it is empty.


func _write_text(path: String, text: String) -> void:
	_write_bytes(path, text.to_utf8_buffer())


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _orphan_nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func _object_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


## Both settings away from what the tests below expect to read, so a default has to be put there.
func _set_away_from_the_defaults() -> void:
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true


## `[settings]`, then `lines`, one to a line.
func _settings_text(lines: PackedStringArray) -> String:
	return "[settings]\n" + "\n".join(lines) + "\n"


## Writes `text` and loads it with both settings away from the defaults. True when it was read.
func _load_text(text: String) -> bool:
	_write_text(_file, text)
	_set_away_from_the_defaults()
	return UserSettings.load_from(_file)


func _assert_settings(shake: bool, fullscreen: bool, message: String = "") -> void:
	assert_eq(UserSettings.settings.screen_shake_enabled, shake, "shake %s" % message)
	assert_eq(UserSettings.settings.fullscreen, fullscreen, "fullscreen %s" % message)


func _assert_defaults(message: String = "") -> void:
	_assert_settings(true, false, message)


## Nothing wrote a line of its own: no warning and no engine error.
func _assert_quiet() -> void:
	assert_eq(_log.warnings, 0, "no warning")
	assert_eq(_log.errors, 0, "no engine error line")


## The one warning C12 asks for and nothing else.
func _assert_one_warning() -> void:
	assert_eq(_log.warnings, 1, "one warning")
	assert_eq(_log.errors, 0, "and no engine error line")


## A file that holds an object in `text` (the settings file's `fullscreen` is the object, or the
## text says otherwise): the load builds nothing, runs nothing, reads the rest and is true.
func _assert_object_text_builds_nothing(
	text: String, shake: bool, fullscreen: bool, read: bool = true
) -> void:
	_write_text(_file, text)
	_set_away_from_the_defaults()
	var orphans_before: int = _orphan_nodes()
	var objects_before: int = _object_count()
	assert_eq(UserSettings.load_from(_file), read, "was the file read")
	assert_eq(_orphan_nodes(), orphans_before, "no node built from the file is left")
	assert_eq(_object_count(), objects_before, "no object built from the file is left")
	assert_false(FileAccess.file_exists(_marker), "no script of the file ran")
	_assert_settings(shake, fullscreen)
	_assert_quiet()


func test_the_autoload_starts_at_the_shipped_defaults() -> void:
	assert_is(UserSettings.settings, GameSettings)
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)
	assert_eq(UserSettings.DEFAULT_PATH, "user://settings.cfg")


# --- the file the game writes ---


func test_save_then_load_gives_the_saved_values() -> void:
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true
	assert_true(UserSettings.save_to(_file))
	UserSettings.reset_to_defaults()
	_assert_defaults()
	assert_true(UserSettings.load_from(_file))
	_assert_settings(false, true)
	_assert_quiet()


## All four on and off combinations, through the file.
func test_every_combination_survives_a_save_and_a_load() -> void:
	for shake: bool in [true, false]:
		for fullscreen: bool in [true, false]:
			UserSettings.settings.screen_shake_enabled = shake
			UserSettings.settings.fullscreen = fullscreen
			assert_true(UserSettings.save_to(_file))
			_set_away_from_the_defaults()
			UserSettings.settings.screen_shake_enabled = not shake
			UserSettings.settings.fullscreen = not fullscreen
			assert_true(UserSettings.load_from(_file))
			_assert_settings(shake, fullscreen, "(saved %s, %s)" % [shake, fullscreen])
	_assert_quiet()


func test_the_file_is_a_config_file_with_a_settings_section() -> void:
	UserSettings.settings.fullscreen = true
	assert_true(UserSettings.save_to(_file))
	var file: ConfigFile = ConfigFile.new()
	assert_eq(file.load(_file), OK)
	assert_eq(file.get_sections(), PackedStringArray(["settings"]))
	assert_eq(file.get_value("settings", "fullscreen"), true)
	assert_eq(file.get_value("settings", "screen_shake_enabled"), true)


## What a person edits: a `[settings]` line, then one `key=value` line for each setting, as the
## reader understands them (and nothing else in the file).
func test_the_file_is_lines_a_person_can_edit() -> void:
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true
	assert_true(UserSettings.save_to(_file))
	var lines: PackedStringArray = []
	for line: String in FileAccess.get_file_as_string(_file).split("\n"):
		if not line.strip_edges().is_empty():
			lines.append(line)
	assert_eq(
		lines, PackedStringArray(["[settings]", "screen_shake_enabled=false", "fullscreen=true"])
	)


## Round 3 (CR-27): the writer is this script's own, not `ConfigFile`'s, so a later Godot cannot
## change what a saved file says. These are the bytes, for each of the four combinations: the
## section line, an empty line, the two keys in that order, each line ended by `\n`, no BOM.
func test_the_file_is_exactly_these_lines_for_every_combination() -> void:
	for shake: bool in [true, false]:
		for fullscreen: bool in [true, false]:
			UserSettings.settings.screen_shake_enabled = shake
			UserSettings.settings.fullscreen = fullscreen
			assert_true(UserSettings.save_to(_file))
			var expected: String = (
				"[settings]\n\nscreen_shake_enabled=%s\nfullscreen=%s\n"
				% ["true" if shake else "false", "true" if fullscreen else "false"]
			)
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_file)
			assert_eq(bytes.get_string_from_utf8(), expected, "saved %s, %s" % [shake, fullscreen])
			assert_eq(bytes.size(), expected.length(), "and no byte more: no BOM, no `\\r`")


## The same bytes the old writer gave (what `ConfigFile` writes today): files of earlier saves are
## read, and a file this writes could be handed to it.
func test_the_file_is_what_a_config_file_writes_and_a_config_file_made_file_is_read() -> void:
	for shake: bool in [true, false]:
		for fullscreen: bool in [true, false]:
			var old_file: ConfigFile = ConfigFile.new()
			old_file.set_value("settings", "screen_shake_enabled", shake)
			old_file.set_value("settings", "fullscreen", fullscreen)
			var old_path: String = _dir.path_join("old_writer.cfg")
			assert_eq(old_file.save(old_path), OK)
			UserSettings.settings.screen_shake_enabled = shake
			UserSettings.settings.fullscreen = fullscreen
			assert_true(UserSettings.save_to(_file))
			assert_eq(
				FileAccess.get_file_as_bytes(_file),
				FileAccess.get_file_as_bytes(old_path),
				"the bytes of the old writer, saved %s, %s" % [shake, fullscreen]
			)
			UserSettings.settings.screen_shake_enabled = not shake
			UserSettings.settings.fullscreen = not fullscreen
			assert_true(UserSettings.load_from(old_path), "the old writer's file is read")
			_assert_settings(shake, fullscreen, "(old file of %s, %s)" % [shake, fullscreen])
	_assert_quiet()


## A save rewrites the whole file, whatever was there (a longer older file leaves nothing behind).
func test_a_save_replaces_a_longer_older_file() -> void:
	_write_text(
		_file, "[settings]\n\nscreen_shake_enabled=true\nfullscreen=true\n; " + "x".repeat(300)
	)
	UserSettings.settings.fullscreen = false
	assert_true(UserSettings.save_to(_file))
	assert_eq(
		FileAccess.get_file_as_string(_file),
		"[settings]\n\nscreen_shake_enabled=true\nfullscreen=false\n"
	)


## A path that cannot be opened for writing (here a folder): false, one warning, and what was there
## is as it was.
func test_a_save_that_cannot_open_the_file_touches_nothing() -> void:
	_write_text(_marker, "kept")
	UserSettings.settings.fullscreen = true
	assert_false(UserSettings.save_to(_dir))
	assert_eq(_log.warnings, 1, "one warning")
	assert_true(DirAccess.dir_exists_absolute(_dir), "the folder is still a folder")
	assert_eq(FileAccess.get_file_as_string(_marker), "kept")
	assert_true(UserSettings.settings.fullscreen, "the value stays for this run")


## `ConfigFile` is not used by the script at all (comments apart): neither to write nor to read.
func test_the_script_does_not_use_config_file() -> void:
	var source: String = FileAccess.get_file_as_string(SOURCE_PATH)
	assert_false(source.is_empty(), "the script was read")
	for line: String in source.split("\n"):
		if not line.strip_edges().begins_with("#"):
			assert_false(line.contains("ConfigFile"), line)


# --- a file that is missing, empty, or not a settings file ---


func test_load_of_a_missing_file_is_the_defaults_and_false() -> void:
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true
	assert_false(UserSettings.load_from(_missing))
	_assert_defaults()
	assert_false(FileAccess.file_exists(_missing), "loading creates nothing")
	_assert_quiet()


func test_load_of_a_file_that_is_not_a_settings_file_is_the_defaults_and_false() -> void:
	assert_false(_load_text("this is [not a config {file\n=== garbage"))
	_assert_defaults()
	_assert_one_warning()


func test_load_of_an_empty_file_is_the_defaults_and_true() -> void:
	assert_true(_load_text(""))
	_assert_defaults()
	_assert_quiet()


func test_load_of_a_file_of_blank_lines_is_the_defaults_and_true() -> void:
	assert_true(_load_text("\n  \n\t\r\n"))
	_assert_defaults()
	_assert_quiet()


func test_load_of_the_section_alone_is_the_defaults_and_true() -> void:
	assert_true(_load_text("[settings]\n"))
	_assert_defaults()
	_assert_quiet()


## Comments with no `[settings]` line are content that is not a settings file.
func test_load_of_comments_with_no_section_is_the_defaults_and_false() -> void:
	assert_false(_load_text("; nothing here\n# nor here\n"))
	_assert_defaults()
	_assert_one_warning()


func test_load_of_a_file_without_the_section_is_the_defaults_and_false() -> void:
	assert_false(_load_text("[other]\nfullscreen=true\nscreen_shake_enabled=false\n"))
	_assert_defaults()
	_assert_one_warning()


## The section line is the whole line, `[settings]`, with nothing after it.
func test_a_section_line_with_text_after_it_is_not_the_section() -> void:
	assert_false(_load_text("[settings] ; mine\nfullscreen=true\n"))
	_assert_defaults()
	_assert_one_warning()


func test_load_of_binary_garbage_is_the_defaults_and_false_with_one_warning() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var bytes: PackedByteArray = []
	for _i: int in GARBAGE_BYTES:
		bytes.append(rng.randi_range(0, 255))
	assert_true(bytes.has(0), "the garbage has NUL bytes")
	_write_bytes(_file, bytes)
	_set_away_from_the_defaults()
	assert_false(UserSettings.load_from(_file))
	_assert_defaults()
	_assert_one_warning()  # The engine printed nothing for bytes that are not UTF-8.


## Bytes that are not UTF-8 and no NUL: the file is text with no section line.
func test_load_of_high_bytes_without_a_nul_is_the_defaults_and_false_with_one_warning() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var bytes: PackedByteArray = []
	for _i: int in GARBAGE_BYTES:
		bytes.append(rng.randi_range(1, 255))
	assert_false(bytes.has(0))
	_write_bytes(_file, bytes)
	_set_away_from_the_defaults()
	assert_false(UserSettings.load_from(_file))
	_assert_defaults()
	_assert_one_warning()


## A NUL anywhere is not a text file, also after a good section.
func test_a_nul_byte_makes_the_file_not_a_settings_file() -> void:
	var bytes: PackedByteArray = "[settings]\nfullscreen=true\n".to_utf8_buffer()
	bytes.append(0)
	bytes.append_array("screen_shake_enabled=false\n".to_utf8_buffer())
	_write_bytes(_file, bytes)
	_set_away_from_the_defaults()
	assert_false(UserSettings.load_from(_file))
	_assert_defaults()
	_assert_one_warning()


## Text that is not ASCII (a comment in a person's language) is only ignored.
func test_text_that_is_not_ascii_is_ignored() -> void:
	var lines: PackedStringArray = ["; configuração do jogo ç", "fullscreen=true", "nome=José"]
	assert_true(_load_text(_settings_text(lines)))
	_assert_settings(true, true)
	_assert_quiet()


# --- the lines that are read ---


func test_load_of_values_that_are_not_bools_is_the_defaults_for_them() -> void:
	assert_true(_load_text('[settings]\nscreen_shake_enabled="no"\nfullscreen=1\nvolume=3\n'))
	_assert_defaults()
	_assert_quiet()


## Only the exact words `true` and `false` are bools.
func test_other_spellings_of_true_are_not_true() -> void:
	for text: String in ["True", "TRUE", "1", '"true"', "yes", "on", "true;", "true # on", "t"]:
		assert_true(_load_text("[settings]\nfullscreen=%s\n" % text), text)
		assert_false(UserSettings.settings.fullscreen, "fullscreen=%s is the default" % text)
	for text: String in ["False", "FALSE", "0", '"false"', "no", "off", "false;", "f"]:
		assert_true(_load_text("[settings]\nscreen_shake_enabled=%s\n" % text), text)
		assert_true(UserSettings.settings.screen_shake_enabled, "shake=%s is the default" % text)
	_assert_quiet()


func test_a_file_with_windows_line_ends_is_read() -> void:
	assert_true(_load_text("[settings]\r\nscreen_shake_enabled=false\r\nfullscreen=true\r\n"))
	_assert_settings(false, true)
	_assert_quiet()


func test_spaces_and_tabs_around_the_equals_sign_and_the_line_are_allowed() -> void:
	var lines: PackedStringArray = ["  fullscreen = true  ", "\tscreen_shake_enabled\t=\tfalse\t"]
	assert_true(_load_text("  [settings]  \n" + "\n".join(lines) + "\n"))
	_assert_settings(false, true)
	_assert_quiet()


func test_comments_and_blank_lines_are_ignored() -> void:
	var lines: PackedStringArray = [
		"; screen_shake_enabled=false",
		"# fullscreen=false",
		"",
		"   ",
		"  ; fullscreen=false",
		"fullscreen=true",
		"#screen_shake_enabled=true",
		"screen_shake_enabled=false",
	]
	assert_true(_load_text(_settings_text(lines)))
	_assert_settings(false, true)
	_assert_quiet()


func test_a_comment_before_the_section_is_fine() -> void:
	assert_true(_load_text("; my settings\n[settings]\nfullscreen=true\n"))
	_assert_settings(true, true)
	_assert_quiet()


## A key counts only below `[settings]`: not above it, and not below another section.
func test_keys_outside_the_settings_section_are_ignored() -> void:
	var text: String = (
		"fullscreen=true\n"
		+ "[other]\nfullscreen=true\nscreen_shake_enabled=false\n"
		+ "[settings]\nscreen_shake_enabled=false\n"
		+ "[more]\nfullscreen=true\n"
	)
	assert_true(_load_text(text))
	_assert_settings(false, false)
	_assert_quiet()


func test_the_section_may_come_twice_and_both_are_read() -> void:
	var text: String = "[settings]\nfullscreen=true\n[other]\nx=1\n"
	text += "[settings]\nscreen_shake_enabled=false\n"
	assert_true(_load_text(text))
	_assert_settings(false, true)


func test_the_section_name_is_case_sensitive_and_so_are_the_keys() -> void:
	assert_false(_load_text("[Settings]\nfullscreen=true\n"))
	_assert_defaults()
	assert_true(_load_text("[settings]\nFullscreen=true\nSCREEN_SHAKE_ENABLED=false\n"))
	_assert_defaults()


func test_unknown_keys_and_lines_without_an_equals_sign_are_ignored() -> void:
	var lines: PackedStringArray = ["volume=11", "fullscreen", "=true", "fullscreen=true", "[[x]]"]
	assert_true(_load_text(_settings_text(lines)))
	_assert_settings(true, true)
	_assert_quiet()


## The last line for a key decides (a later one that is not a bool leaves the key at its default).
func test_a_key_given_twice_takes_the_last_line() -> void:
	assert_true(
		_load_text("[settings]\nfullscreen=true\nfullscreen=false\nscreen_shake_enabled=false\n")
	)
	_assert_settings(false, false)
	assert_true(_load_text("[settings]\nfullscreen=false\nfullscreen=true\n"))
	_assert_settings(true, true)
	assert_true(_load_text("[settings]\nfullscreen=true\nfullscreen=maybe\n"))
	_assert_settings(true, false, "(the later line is not a bool: the default)")


## The FIRST `=` splits a line into the key and the text (`find`, not `rfind`): a line with more
## `=` has the rest as its text, which is neither `true` nor `false`, so the key is at its default.
## Each case has an earlier good line for the same key, because the difference between the first
## and the last `=` shows only there: the first reads a known key with a bad text (the earlier line
## is undone, the default), the last reads an unknown key `fullscreen=a` and ignores the line (the
## earlier line stands).
func test_the_first_equals_sign_splits_the_line() -> void:
	var cases: Array[String] = ["fullscreen=a=b", "fullscreen=true=false", "fullscreen=a=true"]
	for bad: String in cases:
		var text: String = "[settings]\nfullscreen = true\n%s\n" % bad
		assert_true(_load_text(text), bad)
		_assert_settings(true, false, "(%s: the last line decides, and it is not a bool)" % bad)
	assert_true(_load_text("[settings]\nscreen_shake_enabled=false\nscreen_shake_enabled=x=y\n"))
	_assert_settings(true, false, "(the same for the other key)")
	_assert_quiet()


## And the same line before the good one: the good one is the last and decides.
func test_a_good_line_after_a_line_with_two_equals_signs_decides() -> void:
	assert_true(_load_text("[settings]\nfullscreen=a=b\nfullscreen=true\n"))
	_assert_settings(true, true)
	_assert_quiet()


## `a=fullscreen=true` is the key `a`: not a known one, so the line is ignored.
func test_a_known_key_after_the_first_equals_sign_is_not_a_key() -> void:
	assert_true(_load_text("[settings]\na=fullscreen=true\nb=screen_shake_enabled=false\n"))
	_assert_defaults()
	assert_true(_load_text("[settings]\nfullscreen=true\na=fullscreen=false\n"))
	_assert_settings(true, true, "(an unknown key leaves the earlier line alone)")
	_assert_quiet()


# --- the byte order mark ---


## A file that starts with a UTF-8 byte order mark (an editor on Windows may write one) is read.
func test_load_of_a_file_that_starts_with_a_bom_is_read() -> void:
	var bytes: PackedByteArray = PackedByteArray([0xEF, 0xBB, 0xBF])
	bytes.append_array("[settings]\nfullscreen=true\nscreen_shake_enabled=false\n".to_utf8_buffer())
	_write_bytes(_file, bytes)
	UserSettings.settings.fullscreen = false
	UserSettings.settings.screen_shake_enabled = true
	assert_true(UserSettings.load_from(_file), "load_from says the file was read")
	_assert_settings(false, true)
	_assert_quiet()


func test_a_file_of_a_bom_alone_is_empty() -> void:
	_write_bytes(_file, PackedByteArray([0xEF, 0xBB, 0xBF]))
	_set_away_from_the_defaults()
	assert_true(UserSettings.load_from(_file))
	_assert_defaults()
	_assert_quiet()


func test_a_bom_with_windows_line_ends_is_read() -> void:
	var bytes: PackedByteArray = PackedByteArray([0xEF, 0xBB, 0xBF])
	bytes.append_array("[settings]\r\nfullscreen=true\r\n".to_utf8_buffer())
	_write_bytes(_file, bytes)
	_set_away_from_the_defaults()
	assert_true(UserSettings.load_from(_file))
	_assert_settings(true, true, "(shake is the file's missing key: its default is on)")
	_assert_quiet()


## Only the first byte order mark is taken off. A second one is three bytes that are not whitespace
## (read as ASCII: three characters, none of them blank): they stay at the start of the first line,
## so that line is not `[settings]`. A file whose only section line is that first line is not a
## settings file (the defaults, false, one warning); a file with the section line on a line of its
## own is read, the second mark being a line that means nothing.
func test_a_second_bom_stays_in_the_first_line_and_is_not_whitespace() -> void:
	var marks: PackedByteArray = PackedByteArray([0xEF, 0xBB, 0xBF, 0xEF, 0xBB, 0xBF])
	var bytes: PackedByteArray = marks.duplicate()
	bytes.append_array("[settings]\nfullscreen=true\nscreen_shake_enabled=false\n".to_utf8_buffer())
	_write_bytes(_file, bytes)
	_set_away_from_the_defaults()
	assert_false(UserSettings.load_from(_file), "the first line is not the section line")
	_assert_defaults()
	_assert_one_warning()
	bytes = marks.duplicate()
	bytes.append_array(
		"\n[settings]\nfullscreen=true\nscreen_shake_enabled=false\n".to_utf8_buffer()
	)
	_write_bytes(_file, bytes)
	_set_away_from_the_defaults()
	assert_true(UserSettings.load_from(_file), "the section line on a line of its own is read")
	_assert_settings(false, true)


# --- objects, scripts and anything else the engine's own parser would build ---


func test_a_node_in_the_file_is_not_built() -> void:
	var lines: PackedStringArray = ["fullscreen=" + OBJECT_NODE, "screen_shake_enabled=false"]
	_assert_object_text_builds_nothing(_settings_text(lines), false, false)


func test_a_plain_object_in_the_file_is_not_built() -> void:
	var lines: PackedStringArray = ["fullscreen=Object(Object,)", "screen_shake_enabled=false"]
	_assert_object_text_builds_nothing(_settings_text(lines), false, false)
	lines = ["fullscreen=" + OBJECT_PLAIN, "screen_shake_enabled=false"]
	_assert_object_text_builds_nothing(_settings_text(lines), false, false)


func test_an_object_in_an_array_is_not_built() -> void:
	var value: String = "[true, %s, [%s, 3]]" % [OBJECT_NODE, OBJECT_PLAIN]
	var lines: PackedStringArray = ["fullscreen=" + value, "screen_shake_enabled=false"]
	_assert_object_text_builds_nothing(_settings_text(lines), false, false)


func test_an_object_in_a_dictionary_is_not_built() -> void:
	var value: String = '{"a": %s, "c": {"d": [%s]}}' % [OBJECT_NODE, OBJECT_PLAIN]
	var lines: PackedStringArray = ["fullscreen=" + value, "screen_shake_enabled=false"]
	_assert_object_text_builds_nothing(_settings_text(lines), false, false)


func test_an_object_as_a_dictionary_key_is_not_built() -> void:
	var lines: PackedStringArray = [
		"fullscreen={%s: true}" % OBJECT_NODE, "screen_shake_enabled=false"
	]
	_assert_object_text_builds_nothing(_settings_text(lines), false, false)


func test_an_object_in_another_section_is_not_built() -> void:
	var text: String = (
		"[other]\nthing=%s\nlist=[%s]\n[settings]\nfullscreen=true\nscreen_shake_enabled=false\n"
		% [OBJECT_NODE, OBJECT_PLAIN]
	)
	_assert_object_text_builds_nothing(text, false, true)


func test_an_object_in_the_property_of_an_object_is_not_built() -> void:
	var inner: String = 'Object(Node,"name":&"inner")'
	var value: String = 'Object(Node,"name":&"outer","metadata/held":%s)' % inner
	var lines: PackedStringArray = ["fullscreen=" + value, "screen_shake_enabled=false"]
	_assert_object_text_builds_nothing(_settings_text(lines), false, false)


func test_an_object_with_no_property_list_is_not_built() -> void:
	var lines: PackedStringArray = ["fullscreen=Object(Node)", "screen_shake_enabled=false"]
	_assert_object_text_builds_nothing(_settings_text(lines), false, false)


## The engine's parser stops at the first line it refuses and the file is lost to it; this reader
## goes on, before and after.
func test_an_object_before_a_line_that_is_not_valid_is_not_built_and_the_rest_is_read() -> void:
	var lines: PackedStringArray = [
		'fullscreen=Object(Node,"name":&"x")', "screen_shake_enabled=??", "this is [not valid"
	]
	_assert_object_text_builds_nothing(_settings_text(lines), true, false)
	lines = ["fullscreen=" + OBJECT_NODE, "??", "screen_shake_enabled=false"]
	_assert_object_text_builds_nothing(_settings_text(lines), false, false)
	lines = ['fullscreen=[Object(Node,"name":&"inside"), ??]', "screen_shake_enabled=false"]
	_assert_object_text_builds_nothing(_settings_text(lines), false, false)


func test_many_objects_are_not_built() -> void:
	var lines: PackedStringArray = []
	for index: int in 300:
		lines.append('k%d=[Object(Node,"name":&"n%d"), {"x": %s}]' % [index, index, OBJECT_PLAIN])
	lines.append("fullscreen=true")
	_assert_object_text_builds_nothing(_settings_text(lines), true, true)


func test_resource_texts_are_not_loaded() -> void:
	var lines: PackedStringArray = [
		"fullscreen=SubResource(1)",
		'screen_shake_enabled=Resource("res://data/tunables/shell.tres")',
		'other=ExtResource("1")',
	]
	_assert_object_text_builds_nothing(_settings_text(lines), true, false)


## A script of the test's own folder that writes a marker file when it is run (its `_init`). A
## `ConfigFile` runs it while it loads the line below, before anything can clean up.
func test_a_script_named_in_the_file_is_not_run() -> void:
	var source: String = (
		"extends RefCounted\n\n\nfunc _init() -> void:\n"
		+ '\tvar file: FileAccess = FileAccess.open("%s", FileAccess.WRITE)\n' % _marker
		+ '\tfile.store_string("ran")\n\tfile.close()\n'
	)
	_write_text(_script_file, source)
	var value: String = 'Object(RefCounted,"script":Resource("%s"))' % _script_file
	var lines: PackedStringArray = ["fullscreen=" + value, "screen_shake_enabled=false"]
	assert_false(FileAccess.file_exists(_marker), "the marker is not there before")
	_assert_object_text_builds_nothing(_settings_text(lines), false, false)
	assert_true(FileAccess.file_exists(_script_file), "the script was there to be run")
	# The same script, held in a node and in another section.
	value = 'Object(Node,"script":Resource("%s"))' % _script_file
	_assert_object_text_builds_nothing(
		"[other]\nx=%s\n[settings]\nfullscreen=true\n" % value, true, true
	)


# --- size ---


func test_a_file_of_the_largest_size_is_read() -> void:
	var prefix: String = "[settings]\nfullscreen=true\n#"
	var text: String = prefix + "x".repeat(UserSettings.MAX_FILE_BYTES - prefix.length())
	assert_eq(text.length(), UserSettings.MAX_FILE_BYTES)
	assert_true(_load_text(text))
	_assert_settings(true, true)
	_assert_quiet()


func test_a_file_one_byte_over_the_largest_size_is_not_read() -> void:
	var prefix: String = "[settings]\nfullscreen=true\n#"
	var text: String = prefix + "x".repeat(UserSettings.MAX_FILE_BYTES + 1 - prefix.length())
	assert_false(_load_text(text))
	_assert_defaults()
	_assert_one_warning()


func test_a_file_of_16_megabytes_is_not_read_and_is_quick() -> void:
	var bytes: PackedByteArray = "[settings]\nfullscreen=true\n".to_utf8_buffer()
	var head: int = bytes.size()
	bytes.resize(HUGE_FILE_BYTES)
	for index: int in range(head, mini(head + 64, HUGE_FILE_BYTES)):
		bytes[index] = 0x23  # `#`: the rest is zeros, which do not matter.
	_write_bytes(_file, bytes)
	_set_away_from_the_defaults()
	var started: int = Time.get_ticks_msec()
	assert_false(UserSettings.load_from(_file))
	assert_lt(Time.get_ticks_msec() - started, HUGE_LOAD_LIMIT_MSEC, "it does not hang")
	_assert_defaults()
	_assert_one_warning()


# --- the rest of the autoload ---


func test_save_to_a_path_that_cannot_be_written_is_false_and_the_value_stays() -> void:
	UserSettings.settings.screen_shake_enabled = false
	assert_false(UserSettings.save_to(_no_folder))
	assert_false(UserSettings.settings.screen_shake_enabled)
	assert_false(FileAccess.file_exists(_no_folder))
	assert_eq(_log.warnings, 1, "one warning")


func test_the_settings_object_is_never_replaced() -> void:
	var before: GameSettings = UserSettings.settings
	UserSettings.settings.fullscreen = true
	UserSettings.save_to(_file)
	UserSettings.load_from(_file)
	UserSettings.load_from(_missing)
	UserSettings.reset_to_defaults()
	assert_same(UserSettings.settings, before)


func test_load_and_reset_emit_changed_only_for_what_changed() -> void:
	watch_signals(UserSettings.settings)
	UserSettings.save_to(_file)  # the defaults
	UserSettings.load_from(_file)
	UserSettings.load_from(_missing)
	UserSettings.reset_to_defaults()
	assert_signal_not_emitted(UserSettings.settings, "changed")
	UserSettings.settings.fullscreen = true
	assert_signal_emit_count(UserSettings.settings, "changed", 1)
	UserSettings.reset_to_defaults()
	assert_signal_emit_count(UserSettings.settings, "changed", 2)
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.save_to(_file)
	UserSettings.settings.screen_shake_enabled = true
	UserSettings.load_from(_file)
	assert_signal_emit_count(UserSettings.settings, "changed", 5)
	assert_false(UserSettings.settings.screen_shake_enabled)


func test_a_listener_stays_connected_through_a_load_and_a_reset() -> void:
	var seen: Array[int] = [0]
	var listener: Callable = func() -> void: seen[0] += 1
	UserSettings.settings.changed.connect(listener)
	UserSettings.settings.fullscreen = true
	UserSettings.save_to(_file)
	UserSettings.reset_to_defaults()
	UserSettings.load_from(_file)
	UserSettings.settings.changed.disconnect(listener)
	assert_eq(seen[0], 3)


func test_a_change_writes_no_file_by_itself() -> void:
	UserSettings.settings.fullscreen = true
	UserSettings.settings.screen_shake_enabled = false
	assert_eq(DirAccess.get_files_at(_dir).size(), 0, "nothing wrote to the test folder")


func test_the_script_has_no_ready_init_or_enter_tree() -> void:
	var source: String = FileAccess.get_file_as_string(SOURCE_PATH)
	assert_false(source.is_empty(), "the script was read")
	for hook: String in ["_ready", "_init", "_enter_tree", "_exit_tree", "_notification"]:
		assert_false(source.contains("func %s(" % hook), hook)


## Counts the warnings (`push_warning`) and the engine's error lines (`push_error`, a failed call)
## of a test. Registered with the engine by before_each().
class LogCounter:
	extends Logger
	var warnings: int = 0
	var errors: int = 0

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		_code: String,
		_rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings += 1
		else:
			errors += 1
