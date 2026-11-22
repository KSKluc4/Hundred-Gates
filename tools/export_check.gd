extends SceneTree
## F-017/C11: what the build holds is the project's data, and a game starts from it. Run by
## `tools/export` with the EDITOR binary on the pack cut out of the exe (the exe takes no script):
##   godot --headless --main-pack <pack.pck> -s tools/export_check.gd
## with the source project's folder in the environment variable below.
##
## (f) Every `.tres` under `data/` as the pack has it is compared with the file on disk, property
## by property: every stored property, a resource kept in a file of its own by its path, a resource
## written inline recursively, arrays and dictionaries element by element, floats exactly. Godot's
## export converts these files in the editor and can drop a property silently (DEV-1: a packed
## array declared `= []` came out empty).
## (g) `scenes/main.tscn` from the pack is instanced, Start is chosen, the flow must reach
## PLAYING with no setup error, floor 1 is entered as the gate menu's choice does and runs for
## FLOOR_TICKS physics ticks; its first room's kill target must be the source room's.
##
## One line per problem (`problem: ...`), `info: ...` lines for what was seen, and a last line
## `export check: ...`. The exit code is 1 on any problem, 0 otherwise.
##
## This script names no project class: it is compiled before the project's autoloads exist, so
## everything is reached through load(), get(), call() and signals by name.

const SOURCE_ENVIRONMENT_VARIABLE: String = "EXPORT_CHECK_SOURCE"
const DATA_FOLDER: String = "data"
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const SHELL_PATH: NodePath = ^"Shell"
const START_ENTRY_ID: StringName = &"start"
const FLOOR_NUMBER: int = 1
const FIRST_ROOM_FILE: String = "data/floors/floor_1/room_1.tres"
## How many physics ticks the floor runs for before the first room is looked at.
const FLOOR_TICKS: int = 120
## A start that takes this many physics ticks has failed to start.
const GIVE_UP_TICKS: int = 1200
## Resources inside resources are followed this deep and no further (a cycle must end).
const MAX_DEPTH: int = 12
const MAX_PROBLEMS_PRINTED: int = 200
const SHOWN_VALUE_LENGTH: int = 70
## A resource inside a file has a path like `res://x.tres::Sub_1` (or none): it is inline.
const INLINE_MARK: String = "::"
const SKIPPED_PROPERTIES: Array[String] = ["resource_path"]
const FLOW_STATE_ENUM: String = "State"
const PLAYING_STATE: String = "PLAYING"

var _source_root: String = ""
var _problems: PackedStringArray = PackedStringArray()
var _files_equal: int = 0
var _frame: int = 0
var _is_done: bool = false
var _main: Node
var _shell: Node
var _game: Node
var _source_kill_target: int = -1
var _started_at_tick: int = 0
var _floor_entered_at_tick: int = -1


func _process(_delta: float) -> bool:
	if _is_done:
		return false
	_frame += 1
	if _frame == 1:
		_check_data()
	elif _frame == 2:
		_start_game()  # The autoloads are in the tree from the second frame on.
	elif _main != null:
		_follow_floor()
	return false


# ---- (f) the data ----


func _check_data() -> void:
	_source_root = OS.get_environment(SOURCE_ENVIRONMENT_VARIABLE)
	if not DirAccess.dir_exists_absolute(_source_root.path_join(DATA_FOLDER)):
		_problems.append(
			(
				"problem: (f) %s is not the project's folder: '%s'"
				% [SOURCE_ENVIRONMENT_VARIABLE, _source_root]
			)
		)
		_finish()
		return
	var files: PackedStringArray = _data_files(DATA_FOLDER)
	for relative: String in files:
		var before: int = _problems.size()
		_compare_file(relative)
		if _problems.size() == before:
			_files_equal += 1
	if files.is_empty():
		_problems.append("problem: (f) no .tres file under %s/ in the source" % DATA_FOLDER)


## Every `.tres` under `relative` in the source, as paths relative to the project, sorted.
func _data_files(relative: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var folder: String = _source_root.path_join(relative)
	var sub_folders: PackedStringArray = DirAccess.get_directories_at(folder)
	sub_folders.sort()
	for sub_folder: String in sub_folders:
		found.append_array(_data_files(relative.path_join(sub_folder)))
	var names: PackedStringArray = DirAccess.get_files_at(folder)
	names.sort()
	for file_name: String in names:
		if file_name.ends_with(".tres"):
			found.append(relative.path_join(file_name))
	return found


func _compare_file(relative: String) -> void:
	var from_pack: Resource = load("res://" + relative)
	var from_source: Resource = ResourceLoader.load(
		_source_root.path_join(relative), "", ResourceLoader.CACHE_MODE_IGNORE
	)
	if from_pack == null or from_source == null:
		_problems.append(
			(
				"problem: (f) %s: cannot be loaded (pack: %s, source: %s)"
				% [relative, from_pack, from_source]
			)
		)
		return
	_compare_resources(relative, "", from_pack, from_source, 0)


## Every stored property of `source`, read from both. `where` is the property path so far.
func _compare_resources(
	file: String, where: String, packed: Resource, source: Resource, depth: int
) -> void:
	if depth > MAX_DEPTH:
		_problems.append("problem: (f) %s: %s: nested deeper than %d" % [file, where, MAX_DEPTH])
		return
	if packed.get_class() != source.get_class():
		_problems.append(
			(
				"problem: (f) %s: %s: class %s in the pack, %s in the source"
				% [file, where, packed.get_class(), source.get_class()]
			)
		)
		return
	for property: Dictionary in source.get_property_list():
		var property_name: String = property["name"]
		if not property["usage"] & PROPERTY_USAGE_STORAGE or property_name in SKIPPED_PROPERTIES:
			continue
		_compare_values(
			file,
			property_name if where.is_empty() else "%s.%s" % [where, property_name],
			packed.get(property_name),
			source.get(property_name),
			depth
		)


func _compare_values(
	file: String, where: String, packed: Variant, source: Variant, depth: int
) -> void:
	if typeof(packed) != typeof(source):
		_differs(file, where, packed, source)
	elif source is Resource:
		_compare_resource_values(file, where, packed, source, depth)
	elif source is Array:
		_compare_arrays(file, where, packed, source, depth)
	elif source is Dictionary:
		_compare_dictionaries(file, where, packed, source, depth)
	elif typeof(source) == TYPE_FLOAT:
		if not (packed == source or (is_nan(packed) and is_nan(source))):
			_differs(file, where, packed, source)
	elif packed != source:
		_differs(file, where, packed, source)


func _compare_resource_values(
	file: String, where: String, packed: Resource, source: Resource, depth: int
) -> void:
	if _is_inline(packed) != _is_inline(source):
		_differs(file, where, _describe(packed), _describe(source))
	elif _is_inline(source):
		_compare_resources(file, where, packed, source, depth + 1)
	elif packed.resource_path != source.resource_path:
		_differs(file, where, packed.resource_path, source.resource_path)


func _compare_arrays(file: String, where: String, packed: Array, source: Array, depth: int) -> void:
	if packed.size() != source.size():
		_problems.append(
			(
				"problem: (f) %s: %s: %d element(s) in the pack, %d in the source"
				% [file, where, packed.size(), source.size()]
			)
		)
		return
	for index: int in source.size():
		_compare_values(file, "%s[%d]" % [where, index], packed[index], source[index], depth)


func _compare_dictionaries(
	file: String, where: String, packed: Dictionary, source: Dictionary, depth: int
) -> void:
	if packed.size() != source.size():
		_problems.append(
			(
				"problem: (f) %s: %s: %d key(s) in the pack, %d in the source"
				% [file, where, packed.size(), source.size()]
			)
		)
		return
	for key: Variant in source:
		if not packed.has(key):
			_problems.append("problem: (f) %s: %s: the pack has no key %s" % [file, where, key])
		else:
			_compare_values(file, "%s[%s]" % [where, key], packed[key], source[key], depth)


func _is_inline(resource: Resource) -> bool:
	return resource.resource_path.is_empty() or INLINE_MARK in resource.resource_path


func _describe(resource: Resource) -> String:
	return "inline resource" if _is_inline(resource) else resource.resource_path


func _differs(file: String, where: String, packed: Variant, source: Variant) -> void:
	_problems.append(
		(
			"problem: (f) %s: %s: pack has %s, source has %s"
			% [file, where, _shown(packed), _shown(source)]
		)
	)


func _shown(value: Variant) -> String:
	return "%s (%s)" % [str(value).left(SHOWN_VALUE_LENGTH), type_string(typeof(value))]


# ---- (g) a game starts ----


func _start_game() -> void:
	var main_scene: PackedScene = load(MAIN_SCENE_PATH)
	if main_scene == null:
		_problems.append("problem: (g) %s cannot be loaded from the pack" % MAIN_SCENE_PATH)
		_finish()
		return
	_started_at_tick = Engine.get_physics_frames()
	var first_room: Resource = ResourceLoader.load(
		_source_root.path_join(FIRST_ROOM_FILE), "", ResourceLoader.CACHE_MODE_IGNORE
	)
	if first_room == null:
		_problems.append("problem: (g) %s cannot be loaded from the source" % FIRST_ROOM_FILE)
		_finish()
		return
	_source_kill_target = first_room.call("get_kill_target")
	_main = main_scene.instantiate()
	root.add_child(_main)
	_shell = _main.get_node(SHELL_PATH)
	_shell.call("get_menu").emit_signal("entry_chosen", START_ENTRY_ID)
	var flow: Object = _shell.call("get_flow")
	if _state_name(flow) != PLAYING_STATE:
		(
			_problems
			. append(
				(
					(
						"problem: (g) Start did not reach %s: the flow is in %s (the game's own errors are in "
						+ "the lines above)"
					)
					% [PLAYING_STATE, _state_name(flow)]
				)
			)
		)
		_finish()
		return
	_game = _shell.call("get_game")
	if _game == null:
		_problems.append("problem: (g) the flow is PLAYING but the shell holds no game")
		_finish()
		return
	for error: String in _game.call("get_setup_errors"):
		_problems.append("problem: (g) the game reports a setup error: %s" % error)
	var town: Object = _game.call("get_town")
	if town == null:
		_problems.append("problem: (g) the game started without the town")
		_finish()
		return
	town.emit_signal("floor_chosen", FLOOR_NUMBER, false)  # What the gate menu's choice emits.


func _follow_floor() -> void:
	var tick: int = Engine.get_physics_frames()
	if tick - _started_at_tick > GIVE_UP_TICKS:
		_problems.append(
			"problem: (g) no floor %d room after %d ticks" % [FLOOR_NUMBER, GIVE_UP_TICKS]
		)
		_finish()
		return
	if _floor_entered_at_tick < 0:
		var floor_scene: Object = _game.call("get_floor_scene")
		if is_instance_valid(floor_scene) and floor_scene.call("get_room") != null:
			_floor_entered_at_tick = tick
		return
	if tick - _floor_entered_at_tick >= FLOOR_TICKS:
		_check_first_room()
		_finish()


func _check_first_room() -> void:
	var flow: Object = _shell.call("get_flow")
	if _state_name(flow) != PLAYING_STATE:
		_problems.append(
			(
				"problem: (g) after %d ticks on floor %d the flow is in %s, not %s"
				% [FLOOR_TICKS, FLOOR_NUMBER, _state_name(flow), PLAYING_STATE]
			)
		)
	var room: Object = _game.call("get_floor_scene").call("get_room")
	var room_path: String = room.call("get_room_data").resource_path
	var target: int = room.call("get_kill_target")
	if room_path != "res://" + FIRST_ROOM_FILE:
		_problems.append(
			(
				"problem: (g) floor %d's first room is %s, not %s"
				% [FLOOR_NUMBER, room_path, FIRST_ROOM_FILE]
			)
		)
	if target != _source_kill_target:
		_problems.append(
			(
				"problem: (g) floor %d room 1 has kill target %d, the source's is %d"
				% [FLOOR_NUMBER, target, _source_kill_target]
			)
		)
	print(
		(
			"info: Start reached %s; floor %d, %s, kill target %d (source %d), after %d ticks"
			% [
				_state_name(flow),
				FLOOR_NUMBER,
				room_path.trim_prefix("res://"),
				target,
				_source_kill_target,
				FLOOR_TICKS
			]
		)
	)


## The name of the flow's state (`PLAYING`), from the enum the flow's script declares.
func _state_name(flow: Object) -> String:
	var script: Script = flow.get_script()
	var states: Dictionary = script.get_script_constant_map()[FLOW_STATE_ENUM]
	return str(states.find_key(flow.call("get_state")))


# ---- the end ----


func _finish() -> void:
	_is_done = true
	for index: int in mini(_problems.size(), MAX_PROBLEMS_PRINTED):
		print(_problems[index])
	if _problems.size() > MAX_PROBLEMS_PRINTED:
		print("problem: ... and %d more" % (_problems.size() - MAX_PROBLEMS_PRINTED))
	if _problems.is_empty():
		print("export check: %d data files equal, a game started" % _files_equal)
		quit(0)
	else:
		print("export check: %d problem(s)" % _problems.size())
		quit(1)
