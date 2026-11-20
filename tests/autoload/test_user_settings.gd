extends GutTest
## F-015 T2 (AC7, C12): the UserSettings autoload and its file. Every file here is the test's own,
## under a folder of this process (`user://test_f015_t2_<process id>/`: two runs of the project at
## once share `user://`, and one run must not delete or count the other's files);
## user://settings.cfg is never read or written. The one shared GameSettings goes back to the
## defaults after each test.

const DIR_PREFIX: String = "user://test_f015_t2_"
const SOURCE_PATH: String = "res://src/autoload/user_settings.gd"
const GARBAGE_BYTES: int = 4096

var _dir: String = ""
var _file: String = ""
var _missing: String = ""
var _no_folder: String = ""


func before_each() -> void:
	_dir = "%s%d" % [DIR_PREFIX, OS.get_process_id()]
	_file = _dir.path_join("settings.cfg")
	_missing = _dir.path_join("missing.cfg")
	_no_folder = _dir.path_join("no_such_folder/settings.cfg")
	DirAccess.make_dir_recursive_absolute(_dir)
	UserSettings.reset_to_defaults()


func after_each() -> void:
	UserSettings.reset_to_defaults()
	for file_name: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file_name))
	DirAccess.remove_absolute(_dir)  # Only succeeds when it is empty.


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _orphan_nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func _object_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


func test_the_autoload_starts_at_the_shipped_defaults() -> void:
	assert_is(UserSettings.settings, GameSettings)
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)
	assert_eq(UserSettings.DEFAULT_PATH, "user://settings.cfg")


func test_save_then_load_gives_the_saved_values() -> void:
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true
	assert_true(UserSettings.save_to(_file))
	UserSettings.reset_to_defaults()
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)
	assert_true(UserSettings.load_from(_file))
	assert_false(UserSettings.settings.screen_shake_enabled)
	assert_true(UserSettings.settings.fullscreen)


func test_the_file_is_a_config_file_with_a_settings_section() -> void:
	UserSettings.settings.fullscreen = true
	assert_true(UserSettings.save_to(_file))
	var file: ConfigFile = ConfigFile.new()
	assert_eq(file.load(_file), OK)
	assert_eq(file.get_sections(), PackedStringArray(["settings"]))
	assert_eq(file.get_value("settings", "fullscreen"), true)
	assert_eq(file.get_value("settings", "screen_shake_enabled"), true)


func test_load_of_a_missing_file_is_the_defaults_and_false() -> void:
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true
	assert_false(UserSettings.load_from(_missing))
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)
	assert_false(FileAccess.file_exists(_missing), "loading creates nothing")


func test_load_of_a_file_that_is_not_a_config_file_is_the_defaults_and_false() -> void:
	_write_text(_file, "this is [not a config {file\n=== garbage")
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true
	assert_false(UserSettings.load_from(_file))
	assert_engine_error("ConfigFile parse error", "the engine's own line, besides our warning")
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)


func test_load_of_an_empty_file_is_the_defaults() -> void:
	_write_text(_file, "")
	UserSettings.settings.fullscreen = true
	UserSettings.load_from(_file)
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)


func test_load_of_values_that_are_not_bools_is_the_defaults_for_them() -> void:
	_write_text(_file, '[settings]\nscreen_shake_enabled="no"\nfullscreen=1\nvolume=3\n')
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true
	assert_true(UserSettings.load_from(_file))
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)


## F-015 review round 1: `ConfigFile` reads Godot's text format, so a hand-written
## `Object(Node,...)` in the file makes it build that node. load_from() frees what it built.
func test_load_of_a_file_that_holds_objects_drops_and_frees_them() -> void:
	var lines: PackedStringArray = [
		"[settings]",
		'fullscreen=Object(Node,"name":"planted")',
		"screen_shake_enabled=false",
		"[other]",
		'extra=Object(Node,"name":"other")',
		'nested=[1, Object(Node,"name":"in_array"), {"k": Object(Node,"name":"in_dict")}]',
	]
	_write_text(_file, "\n".join(lines) + "\n")
	UserSettings.settings.fullscreen = true
	var orphans_before: int = _orphan_nodes()
	assert_true(UserSettings.load_from(_file), "the file was read")
	assert_false(UserSettings.settings.fullscreen, "the object is not a bool: the default")
	assert_false(UserSettings.settings.screen_shake_enabled, "the rest of the file is read")
	assert_eq(_orphan_nodes(), orphans_before, "no node built from the file is left")


func test_load_of_a_file_that_holds_a_plain_object_frees_it() -> void:
	_write_text(_file, "[settings]\nfullscreen=Object(Object,)\nscreen_shake_enabled=false\n")
	var objects_before: int = _object_count()
	assert_true(UserSettings.load_from(_file))
	assert_false(UserSettings.settings.fullscreen)
	assert_false(UserSettings.settings.screen_shake_enabled)
	assert_eq(_object_count(), objects_before, "no object built from the file is left")


## A file that starts with a UTF-8 byte order mark (an editor on Windows may write one): pinned as
## it is, which the lead accepts. Measured in 4.7.2: ConfigFile.load() says OK, but the BOM spoils
## the first line, `[settings]`, so its sections are [""] (the keys are filed under no name) and
## `[settings]` is not there: load_from() returns true and every setting is its default.
func test_load_of_a_file_that_starts_with_a_bom_is_the_defaults() -> void:
	var bytes: PackedByteArray = PackedByteArray([0xEF, 0xBB, 0xBF])
	bytes.append_array("[settings]\nfullscreen=true\nscreen_shake_enabled=false\n".to_utf8_buffer())
	_write_bytes(_file, bytes)
	UserSettings.settings.fullscreen = true
	UserSettings.settings.screen_shake_enabled = false
	assert_true(UserSettings.load_from(_file), "load_from says the file was read")
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)


func test_load_of_binary_garbage_is_the_defaults_and_false() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var bytes: PackedByteArray = []
	for _i: int in GARBAGE_BYTES:
		bytes.append(rng.randi_range(0, 255))
	_write_bytes(_file, bytes)
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true
	assert_false(UserSettings.load_from(_file))
	assert_engine_error("ConfigFile parse error", "the engine's own line, besides our warning")
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)


func test_load_of_a_file_without_the_section_is_the_defaults() -> void:
	_write_text(_file, "[other]\nfullscreen=true\n")
	assert_true(UserSettings.load_from(_file))
	assert_false(UserSettings.settings.fullscreen)


func test_save_to_a_path_that_cannot_be_written_is_false_and_the_value_stays() -> void:
	UserSettings.settings.screen_shake_enabled = false
	assert_false(UserSettings.save_to(_no_folder))
	assert_false(UserSettings.settings.screen_shake_enabled)
	assert_false(FileAccess.file_exists(_no_folder))


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
