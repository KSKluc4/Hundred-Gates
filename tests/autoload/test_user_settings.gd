extends GutTest
## F-015 T2 (AC7, C12): the UserSettings autoload and its file. Every file here is the test's own,
## under user://test_f015_t2/; user://settings.cfg is never read or written. The one shared
## GameSettings goes back to the defaults after each test.

const DIR: String = "user://test_f015_t2"
const FILE: String = "user://test_f015_t2/settings.cfg"
const MISSING: String = "user://test_f015_t2/missing.cfg"
const NO_FOLDER: String = "user://test_f015_t2/no_such_folder/settings.cfg"
const SOURCE_PATH: String = "res://src/autoload/user_settings.gd"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	UserSettings.reset_to_defaults()


func after_each() -> void:
	UserSettings.reset_to_defaults()
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_the_autoload_starts_at_the_shipped_defaults() -> void:
	assert_is(UserSettings.settings, GameSettings)
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)
	assert_eq(UserSettings.DEFAULT_PATH, "user://settings.cfg")


func test_save_then_load_gives_the_saved_values() -> void:
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true
	assert_true(UserSettings.save_to(FILE))
	UserSettings.reset_to_defaults()
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)
	assert_true(UserSettings.load_from(FILE))
	assert_false(UserSettings.settings.screen_shake_enabled)
	assert_true(UserSettings.settings.fullscreen)


func test_the_file_is_a_config_file_with_a_settings_section() -> void:
	UserSettings.settings.fullscreen = true
	assert_true(UserSettings.save_to(FILE))
	var file: ConfigFile = ConfigFile.new()
	assert_eq(file.load(FILE), OK)
	assert_eq(file.get_sections(), PackedStringArray(["settings"]))
	assert_eq(file.get_value("settings", "fullscreen"), true)
	assert_eq(file.get_value("settings", "screen_shake_enabled"), true)


func test_load_of_a_missing_file_is_the_defaults_and_false() -> void:
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true
	assert_false(UserSettings.load_from(MISSING))
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)
	assert_false(FileAccess.file_exists(MISSING), "loading creates nothing")


func test_load_of_a_file_that_is_not_a_config_file_is_the_defaults_and_false() -> void:
	_write_text(FILE, "this is [not a config {file\n=== garbage")
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true
	assert_false(UserSettings.load_from(FILE))
	assert_engine_error("ConfigFile parse error", "the engine's own line, besides our warning")
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)


func test_load_of_an_empty_file_is_the_defaults() -> void:
	_write_text(FILE, "")
	UserSettings.settings.fullscreen = true
	UserSettings.load_from(FILE)
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)


func test_load_of_values_that_are_not_bools_is_the_defaults_for_them() -> void:
	_write_text(FILE, '[settings]\nscreen_shake_enabled="no"\nfullscreen=1\nvolume=3\n')
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.settings.fullscreen = true
	assert_true(UserSettings.load_from(FILE))
	assert_true(UserSettings.settings.screen_shake_enabled)
	assert_false(UserSettings.settings.fullscreen)


func test_load_of_a_file_without_the_section_is_the_defaults() -> void:
	_write_text(FILE, "[other]\nfullscreen=true\n")
	assert_true(UserSettings.load_from(FILE))
	assert_false(UserSettings.settings.fullscreen)


func test_save_to_a_path_that_cannot_be_written_is_false_and_the_value_stays() -> void:
	UserSettings.settings.screen_shake_enabled = false
	assert_false(UserSettings.save_to(NO_FOLDER))
	assert_false(UserSettings.settings.screen_shake_enabled)
	assert_false(FileAccess.file_exists(NO_FOLDER))


func test_the_settings_object_is_never_replaced() -> void:
	var before: GameSettings = UserSettings.settings
	UserSettings.settings.fullscreen = true
	UserSettings.save_to(FILE)
	UserSettings.load_from(FILE)
	UserSettings.load_from(MISSING)
	UserSettings.reset_to_defaults()
	assert_same(UserSettings.settings, before)


func test_load_and_reset_emit_changed_only_for_what_changed() -> void:
	watch_signals(UserSettings.settings)
	UserSettings.save_to(FILE)  # the defaults
	UserSettings.load_from(FILE)
	UserSettings.load_from(MISSING)
	UserSettings.reset_to_defaults()
	assert_signal_not_emitted(UserSettings.settings, "changed")
	UserSettings.settings.fullscreen = true
	assert_signal_emit_count(UserSettings.settings, "changed", 1)
	UserSettings.reset_to_defaults()
	assert_signal_emit_count(UserSettings.settings, "changed", 2)
	UserSettings.settings.screen_shake_enabled = false
	UserSettings.save_to(FILE)
	UserSettings.settings.screen_shake_enabled = true
	UserSettings.load_from(FILE)
	assert_signal_emit_count(UserSettings.settings, "changed", 5)
	assert_false(UserSettings.settings.screen_shake_enabled)


func test_a_listener_stays_connected_through_a_load_and_a_reset() -> void:
	var seen: Array[int] = [0]
	var listener: Callable = func() -> void: seen[0] += 1
	UserSettings.settings.changed.connect(listener)
	UserSettings.settings.fullscreen = true
	UserSettings.save_to(FILE)
	UserSettings.reset_to_defaults()
	UserSettings.load_from(FILE)
	UserSettings.settings.changed.disconnect(listener)
	assert_eq(seen[0], 3)


func test_a_change_writes_no_file_by_itself() -> void:
	UserSettings.settings.fullscreen = true
	UserSettings.settings.screen_shake_enabled = false
	assert_eq(DirAccess.get_files_at(DIR).size(), 0, "nothing wrote to the test folder")


func test_the_script_has_no_ready_init_or_enter_tree() -> void:
	var source: String = FileAccess.get_file_as_string(SOURCE_PATH)
	assert_false(source.is_empty(), "the script was read")
	for hook: String in ["_ready", "_init", "_enter_tree", "_exit_tree", "_notification"]:
		assert_false(source.contains("func %s(" % hook), hook)
