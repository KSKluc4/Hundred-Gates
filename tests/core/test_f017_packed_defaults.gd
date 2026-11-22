extends GutTest
## F-017/C12 (AC11): no stored property of a packed-array type has an Array as its declared
## default. Godot 4.7.2's export converts a `.tres` to binary in the editor and drops such a
## property (the file's value is lost and the script's default is read back), though the game run
## from the project reads it: DEV-1, every room came out empty. What the export drops is whatever
## the engine itself reports as an Array default (`[]`, `Array()`, `["#"]`, over two lines, with the
## annotation on its own line, `@export_custom`...), so this test asks the engine, not the text:
## `get_property_default_value()` is an Array for those and Nil for a packed constructor, which the
## export keeps (CR-3, measured in 4.7.2: the dropped set and this set are the same twelve shapes).
## A `@tool` script with an Array default fails this test although the export keeps it (measured in
## review); the test errs on the safe side. Not seen: an inner class (the engine reports no default
## for its properties), which cannot be a `.tres`'s script anyway.

const SOURCE_ROOT: String = "res://src"
const FIRST_PACKED_TYPE: int = TYPE_PACKED_BYTE_ARRAY
const LAST_PACKED_TYPE: int = TYPE_PACKED_VECTOR4_ARRAY
## Where the shapes are written as scripts: a script made from text has no defaults to ask for,
## one loaded from a file has. Under a folder of this process (two runs share `user://`).
const SHAPE_FOLDER_FORMAT: String = "user://test_f017_packed_%d"

## Declarations whose default is an Array: the export drops these. `{type}` is the property's type.
const ARRAY_DEFAULT_SHAPES: Array[String] = [
	"@export var rows: {type} = []",
	"@export var rows: {type} = [ ]",
	"@export var rows: {type} = Array()",
	"@export var rows: {type} = [1]",
	"@export var rows: {type} = [\n\t1,\n\t2,\n]",
	"@export var rows: {type} = \\\n[]",
	"@export\nvar rows: {type} = []",
	'@export_custom(PROPERTY_HINT_NONE, "") var rows: {type} = []',
	"@export var rows: {type} = []  # why",
]
## Declarations whose default is not an Array: the export keeps these.
const OTHER_SHAPES: Array[String] = [
	"@export var rows: {type}",
	"@export var rows: {type} = {type}()",
	"@export var rows: {type} = {type}(Array())",
	"@export var rows: {type} = [] as {type}",
	"@export var rows: Array = []",
	"var rows: Array = []",
]
const PACKED_TYPE_NAMES: Array[String] = ["PackedStringArray", "PackedInt32Array"]
const OTHER_PACKED_TYPE_NAMES: Array[String] = [
	"PackedByteArray",
	"PackedFloat32Array",
	"PackedFloat64Array",
	"PackedVector2Array",
	"PackedColorArray",
]

var _shape_count: int = 0


func after_all() -> void:
	DirAccess.remove_absolute(SHAPE_FOLDER_FORMAT % OS.get_process_id())


func test_no_script_under_src_stores_a_packed_array_with_an_array_default() -> void:
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in _script_paths(SOURCE_ROOT):
		var script: Script = load(path)
		if script == null:
			offenders.append("%s: cannot be loaded" % path)
			continue
		offenders.append_array(offending_properties(script, path))
	assert_eq(offenders, PackedStringArray(), "a packed array property with an Array default")


func test_the_scan_reaches_the_script_that_had_the_defect() -> void:
	assert_has(_script_paths(SOURCE_ROOT), "res://src/core/floors/room_data.gd")


func test_every_shape_with_an_array_default_is_found() -> void:
	for type_name: String in PACKED_TYPE_NAMES:
		for shape: String in ARRAY_DEFAULT_SHAPES:
			var source: String = _script_source(shape, type_name)
			assert_eq(_offenders_of(source).size(), 1, "not found: %s" % _one_line(source))


func test_no_other_shape_is_found() -> void:
	for type_name: String in PACKED_TYPE_NAMES:
		for shape: String in OTHER_SHAPES:
			var source: String = _script_source(shape, type_name)
			assert_eq(_offenders_of(source).size(), 0, "found by mistake: %s" % _one_line(source))


func test_every_packed_type_is_found() -> void:
	for type_name: String in OTHER_PACKED_TYPE_NAMES:
		var source: String = _script_source("@export var rows: {type} = []", type_name)
		assert_eq(_offenders_of(source).size(), 1, "not found: %s" % type_name)


## One `<path>: <property>` line for every stored packed-array property of `script` whose default
## is an Array. A property the base script also has is its base's.
func offending_properties(script: Script, path: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var inherited: Array[String] = _property_names(script.get_base_script())
	for property: Dictionary in script.get_script_property_list():
		var property_name: String = property["name"]
		if property_name in inherited or not _is_stored_packed(property):
			continue
		if typeof(script.get_property_default_value(property_name)) == TYPE_ARRAY:
			found.append("%s: %s" % [path, property_name])
	return found


func _is_stored_packed(property: Dictionary) -> bool:
	var type: int = property["type"]
	var is_stored: bool = property["usage"] & PROPERTY_USAGE_STORAGE != 0
	return is_stored and type >= FIRST_PACKED_TYPE and type <= LAST_PACKED_TYPE


func _property_names(script: Script) -> Array[String]:
	var names: Array[String] = []
	if script != null:
		for property: Dictionary in script.get_script_property_list():
			names.append(property["name"])
	return names


func _script_source(shape: String, type_name: String) -> String:
	return "extends Resource\n%s\n" % shape.replace("{type}", type_name)


func _one_line(source: String) -> String:
	return source.replace("\n", "\\n")


## Writes `source` as a script file, loads it fresh, asks it, and removes the file.
func _offenders_of(source: String) -> PackedStringArray:
	var folder: String = SHAPE_FOLDER_FORMAT % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	_shape_count += 1
	var path: String = "%s/shape_%d.gd" % [folder, _shape_count]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	var script: Script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var found: PackedStringArray = PackedStringArray()
	assert_not_null(script, "the shape does not compile: %s" % _one_line(source))
	if script != null:
		found = offending_properties(script, "shape")
	DirAccess.remove_absolute(path)
	return found


func _script_paths(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for sub_directory: String in DirAccess.get_directories_at(directory):
		paths.append_array(_script_paths(directory.path_join(sub_directory)))
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.ends_with(".gd"):
			paths.append(directory.path_join(file_name))
	return paths
