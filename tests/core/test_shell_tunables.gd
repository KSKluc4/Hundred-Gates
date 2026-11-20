extends GutTest
## F-015 T2 (C11, C17): ShellTunables and the shipped data/tunables/shell.tres.


func test_the_class_defaults_are_the_design_values() -> void:
	var tunables: ShellTunables = ShellTunables.new()
	assert_true(tunables.default_screen_shake_enabled)
	assert_false(tunables.default_fullscreen)


func test_the_shipped_file_is_a_shell_tunables_with_the_design_values() -> void:
	var loaded: Resource = load(Tunables.SHELL_TUNABLES_PATH)
	assert_is(loaded, ShellTunables)
	assert_same(Tunables.shell, loaded, "the autoload exposes the shipped file")
	assert_true(Tunables.shell.default_screen_shake_enabled)
	assert_false(Tunables.shell.default_fullscreen)


func test_the_autoload_path_is_the_shipped_file() -> void:
	assert_eq(Tunables.SHELL_TUNABLES_PATH, "res://data/tunables/shell.tres")
	assert_true(FileAccess.file_exists(Tunables.SHELL_TUNABLES_PATH))
