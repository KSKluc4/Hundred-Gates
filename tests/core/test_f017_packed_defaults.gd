extends GutTest
## F-017/C12 (AC11): no `@export` property of a packed-array type is declared with the default
## `[]`. Godot 4.7.2's export converts a `.tres` to binary in the editor and drops such a
## property, though the game run from the project reads it (DEV-1: every room came out empty).
## The constructor (`PackedStringArray()`) survives. This test reads the source text.

const SOURCE_ROOT: String = "res://src"
const ANNOTATION: String = "^\\s*@export\\w*(\\([^)]*\\))?\\s+var\\s+\\w+\\s*:\\s*"
const PACKED_TYPE: String = "Packed\\w+Array\\s*=\\s*\\[\\s*\\]"
const PATTERN: String = ANNOTATION + PACKED_TYPE

var _pattern: RegEx = RegEx.create_from_string(PATTERN)


func test_no_exported_packed_array_defaults_to_an_empty_literal() -> void:
	var offenders: PackedStringArray = offending_declarations(SOURCE_ROOT)
	assert_eq(offenders, PackedStringArray(), "an @export packed array declared with = []")


func test_the_scan_reaches_the_file_that_had_the_defect() -> void:
	assert_has(_script_paths(SOURCE_ROOT), "res://src/core/floors/room_data.gd")


func test_the_pattern_sees_the_shapes_it_must() -> void:
	assert_true(is_offending("@export var rows: PackedStringArray = []"))
	assert_true(is_offending("@export var rows : PackedStringArray=[ ]"))
	assert_true(is_offending("\t@export var ids: PackedInt32Array = []  # why"))
	assert_true(is_offending("@export_range(0, 9) var ids: PackedInt32Array = []"))


func test_the_pattern_passes_the_shapes_that_survive_the_export() -> void:
	assert_false(is_offending("@export var rows: PackedStringArray = PackedStringArray()"))
	assert_false(is_offending("@export var rows: PackedStringArray"))
	assert_false(is_offending("@export var rows: Array[String] = []"))
	assert_false(is_offending("@export var rows: Array = []"))
	assert_false(is_offending("var rows: PackedStringArray = []"))
	assert_false(is_offending("\tvar errors: PackedStringArray = []"))


func is_offending(line: String) -> bool:
	return _pattern.search(line) != null


## One `path:line: text` entry for every offending declaration under `root`, in file order.
func offending_declarations(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for path: String in _script_paths(root):
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in lines.size():
			if is_offending(lines[index]):
				found.append("%s:%d: %s" % [path, index + 1, lines[index].strip_edges()])
	return found


func _script_paths(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for sub_directory: String in DirAccess.get_directories_at(directory):
		paths.append_array(_script_paths(directory.path_join(sub_directory)))
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".gd"):
			paths.append(directory.path_join(file_name))
	return paths
