extends Node
## F-017/C1: the one switch of the developer tools (the debug overlay, the debug keys and the text
## under an enemy). It is on in a debug binary (the editor, and the game run from the project, tests
## included) and off in a release export; the user argument `--no-dev-tools` (after `--`) turns it
## off in a debug binary too, so the off state can be run and tested from the project. It is read
## where a tool lives, never passed down (F-017, section 3), and nothing in `src/core` reads it.

const NO_DEV_TOOLS_ARGUMENT: String = "--no-dev-tools"

## Set once in _init(). A test that sets it false puts the old value back in after_each().
var enabled: bool


func _init() -> void:
	enabled = is_enabled_for(OS.is_debug_build(), OS.get_cmdline_user_args())


## True for a debug build whose user arguments do not hold NO_DEV_TOOLS_ARGUMENT.
static func is_enabled_for(is_debug_build: bool, user_arguments: PackedStringArray) -> bool:
	return is_debug_build and not user_arguments.has(NO_DEV_TOOLS_ARGUMENT)
