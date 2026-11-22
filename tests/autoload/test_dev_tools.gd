extends GutTest
## F-017/AC1 (C1): the switch of the developer tools. The test binary is a debug build, so the
## switch is on here; is_enabled_for() is tested for every combination of (debug build, the
## argument present). The tests that turn the switch off (test_f017_dev_tools.gd) put it back.

const OTHER_ARGUMENTS: PackedStringArray = ["--verbose", "level=3"]


func test_the_switch_is_on_in_the_test_binary() -> void:
	assert_true(OS.is_debug_build(), "the test binary is a debug build")
	assert_true(DevTools.enabled)


func test_the_switch_is_the_one_autoload_instance_and_is_set_from_the_process() -> void:
	var node: Node = get_tree().root.get_node_or_null("DevTools")
	assert_not_null(node, "an autoload named DevTools")
	assert_same(node, DevTools)
	assert_eq(
		DevTools.enabled,
		DevTools.is_enabled_for(OS.is_debug_build(), OS.get_cmdline_user_args()),
		"set from the build and the user arguments"
	)


func test_the_argument_is_the_one_the_spec_names() -> void:
	assert_eq(DevTools.NO_DEV_TOOLS_ARGUMENT, "--no-dev-tools")


func test_a_debug_build_without_the_argument_is_on() -> void:
	assert_true(DevTools.is_enabled_for(true, PackedStringArray()))


func test_a_debug_build_with_the_argument_is_off() -> void:
	assert_false(DevTools.is_enabled_for(true, PackedStringArray([DevTools.NO_DEV_TOOLS_ARGUMENT])))


func test_a_release_build_without_the_argument_is_off() -> void:
	assert_false(DevTools.is_enabled_for(false, PackedStringArray()))


func test_a_release_build_with_the_argument_is_off() -> void:
	assert_false(
		DevTools.is_enabled_for(false, PackedStringArray([DevTools.NO_DEV_TOOLS_ARGUMENT]))
	)


func test_a_debug_build_with_only_other_arguments_is_on() -> void:
	assert_true(DevTools.is_enabled_for(true, OTHER_ARGUMENTS))


func test_a_release_build_with_only_other_arguments_is_off() -> void:
	assert_false(DevTools.is_enabled_for(false, OTHER_ARGUMENTS))


func test_the_argument_among_other_arguments_turns_a_debug_build_off() -> void:
	var arguments: PackedStringArray = OTHER_ARGUMENTS.duplicate()
	arguments.insert(1, DevTools.NO_DEV_TOOLS_ARGUMENT)
	assert_false(DevTools.is_enabled_for(true, arguments))


func test_an_argument_that_only_looks_like_it_does_not_turn_it_off() -> void:
	var arguments: PackedStringArray = ["--no-dev-tools-please", "no-dev-tools", "--no-dev"]
	assert_true(DevTools.is_enabled_for(true, arguments))
