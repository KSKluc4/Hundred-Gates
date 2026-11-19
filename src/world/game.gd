class_name Game
extends Node
## The game loop's glue (F-012, D-012): shows the town or a floor, whichever the TowerSession
## says, and the HUD. Every rule of the loop is the session's (C2): this node reports what
## happened to it (a floor chosen, a room entered, the floor cleared, the exit reached, the
## player dead) and shows what it answers. It never frees or replaces the scene that emitted a
## signal (C12): `place_changed` only marks what is shown as possibly out of date, and the next
## `_physics_process`, which runs after the town's and the floor's, makes it match. Data that
## fails validation builds nothing (C9).

## F-012/C15, G5
const TOWN_SCENE_PATH: String = "res://src/world/town/town_scene.tscn"
const FLOOR_SCENE_PATH: String = "res://src/world/floors/floor_scene.tscn"
const TOWN_SCENE: PackedScene = preload(TOWN_SCENE_PATH)
const FLOOR_SCENE: PackedScene = preload(FLOOR_SCENE_PATH)
## F-012/C12: after FloorScene's and TownScene's 1, which come after the room's runner.
const AFTER_SCENES_PRIORITY: int = 2
## F-012/C16: every player-facing string this node adds to the HUD's own.
const DEATH_BANNER: String = "You died"
const CLEARED_UNLOCKED_FORMAT: String = "Floor %d cleared — floor %d unlocked"
const CLEARED_LAST_FORMAT: String = "Floor %d cleared — no floor above yet"
const CLEARED_REPLAY_FORMAT: String = "Floor %d cleared"
## F-012/AC33: HP that came back between fights.
const HEALED_FORMAT: String = "+%d HP"

## Null loads Tunables.TOWER_PATH.
@export var tower_data: TowerData
## Null takes the Warrior (Tunables.WARRIOR_PATH).
@export var class_data: ClassData
## Off for scripted runs: commands then come from whoever calls motor.submit().
@export var player_input_enabled: bool = true
## F-012/C17: only passed down. The town and the floor handle the keys, never this node.
@export var debug_keys_enabled: bool = true

var _session: TowerSession
var _town: TownScene
var _floor: FloorScene
## F-012/C12: the session changed place; what is shown may not match it any more.
var _is_shown_stale: bool = false
var _setup_errors: PackedStringArray = []

@onready var _hud: Hud = $Hud


func _ready() -> void:
	process_physics_priority = AFTER_SCENES_PRIORITY
	_hud.player_provider = get_player
	if tower_data == null:
		tower_data = load(Tunables.TOWER_PATH)  # G5
	_setup_errors = _collect_setup_errors()
	if not _setup_errors.is_empty():
		for error: String in _setup_errors:
			push_error("Game: %s" % error)
		set_physics_process(false)  # F-012/C9: nothing is built, so nothing steps.
		return
	if class_data == null:
		class_data = load(Tunables.WARRIOR_PATH)  # G5
	_session = TowerSession.new()
	_session.setup(tower_data, Tunables.tower)
	_session.place_changed.connect(_on_place_changed)
	_session.floor_cleared.connect(_on_session_floor_cleared)
	_show_town()  # F-012/AC26: the game starts in the town.


## F-012/C12: the session's clock first, then what is shown follows what it says.
func _physics_process(delta: float) -> void:
	_session.tick(delta)
	if _is_shown_stale:
		_is_shown_stale = false
		match _session.get_place():
			TowerSession.Place.TOWN:
				_show_town()
			TowerSession.Place.FLOOR:
				_show_floor()
			TowerSession.Place.DEATH_PAUSE:
				# The floor stays on screen through the pause.
				_hud.show_banner(DEATH_BANNER, Tunables.tower.death_return_delay)
	_feed_kills()


func get_session() -> TowerSession:
	return _session


## Null while a floor is shown, or after the town built nothing.
func get_town() -> TownScene:
	return _town


## Null while the town is shown.
func get_floor_scene() -> FloorScene:
	return _floor


func get_hud() -> Hud:
	return _hud


## F-012/C13: the HUD asks this every frame, so it is never a freed player. Null when nothing is
## shown or the shown room is gone.
func get_player() -> Player:
	var shown: Room = _get_shown_room()
	if shown == null or not is_instance_valid(shown.get_player()):
		return null
	return shown.get_player()


## F-012/C9: why nothing was built. Empty when the game is running.
func get_setup_errors() -> PackedStringArray:
	return _setup_errors


## The text of the banner a cleared floor shows (AC28): the floor it opened, or that there is none
## above the last floor, or only the clear for a replay. `newly_unlocked` is the session's.
static func cleared_banner_text(floor_number: int, newly_unlocked: int, floor_count: int) -> String:
	if newly_unlocked > 0:
		return CLEARED_UNLOCKED_FORMAT % [floor_number, newly_unlocked]
	if floor_number == floor_count:
		return CLEARED_LAST_FORMAT % floor_number
	return CLEARED_REPLAY_FORMAT % floor_number


func _collect_setup_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for error: String in Tunables.tower.validate():
		errors.append("tower tunables: %s" % error)
	for error: String in Tunables.floors.validate():
		errors.append("floor tunables: %s" % error)
	if tower_data == null:
		errors.append("tower_data: not set")
	else:
		errors.append_array(tower_data.validate(Tunables.floors))
	return errors


## F-014/C13: what the HUD's kills line says, read from the shown room every physics frame (and
## when a room is entered, so it follows the location text): a combat room of a floor shows its
## count and target, the town and a boss room show nothing. The counts are the room's; nothing
## about waves is decided here.
func _feed_kills() -> void:
	if is_instance_valid(_floor):
		var shown: Room = _floor.get_room()
		if is_instance_valid(shown) and not shown.get_room_data().is_boss_room:
			_hud.set_kills(shown.get_kill_count(), shown.get_kill_target())
			return
	_hud.hide_kills()


func _get_shown_room() -> Room:
	if is_instance_valid(_town):
		return _town.get_room()
	if is_instance_valid(_floor):
		return _floor.get_room()
	return null


## Takes whatever is shown out of the tree and frees it at the end of the frame (C12). Only called
## from `_ready` and `_physics_process`, never from a signal of the scene being removed.
func _remove_shown() -> void:
	var old: Node = _town if _town != null else _floor
	_town = null
	_floor = null
	if old == null:
		return
	remove_child(old)
	old.queue_free()


## Every export and signal is set before the node enters the tree (the town builds in `_ready`).
func _show_town() -> void:
	_remove_shown()
	var town: TownScene = TOWN_SCENE.instantiate()
	town.town_room = tower_data.town
	town.set_progress(_session.get_progress())
	town.class_data = class_data
	town.player_input_enabled = player_input_enabled
	town.debug_keys_enabled = debug_keys_enabled
	town.floor_chosen.connect(_on_floor_chosen)
	_town = town
	add_child(town)
	_hud.set_location(Hud.location_text(0, 0, 0, false))


## `room_entered` is emitted for the first room while the scene is being added, so every signal is
## connected before that.
func _show_floor() -> void:
	_remove_shown()
	var scene: FloorScene = FLOOR_SCENE.instantiate()
	scene.floor_data = _session.get_floor_data()
	scene.start_room = _session.get_start_room()
	scene.class_data = class_data
	scene.player_input_enabled = player_input_enabled
	scene.death_restarts_room = false  # D-006: death returns to the town, the session says when.
	scene.debug_keys_enabled = debug_keys_enabled
	scene.debug_label_visible = false  # The HUD says where the player is.
	scene.room_entered.connect(_on_room_entered)
	scene.floor_cleared.connect(_on_floor_cleared)
	scene.floor_exited.connect(_on_floor_exited)
	scene.healed.connect(_on_healed)  # F-012/AC33
	scene.player_died.connect(_on_player_died)
	_floor = scene
	add_child(scene)


func _on_place_changed(_place: TowerSession.Place) -> void:
	_is_shown_stale = true


func _on_floor_chosen(floor_number: int, at_boss: bool) -> void:
	_session.enter_floor(floor_number, at_boss)


## F-012/C13: the combat rooms are counted without the boss room, which has no number of its own.
func _on_room_entered(room_index: int) -> void:
	_session.report_room_entered(room_index)
	if _session.get_place() != TowerSession.Place.FLOOR:
		return  # A debug skip after a death: the session ignored it, so the HUD does too.
	var floor_data: FloorData = _session.get_floor_data()
	var room: RoomData = floor_data.rooms[room_index]
	_hud.set_location(
		Hud.location_text(
			_session.get_floor_number(),
			room_index,
			floor_data.get_room_count() - 1,
			room.is_boss_room
		)
	)
	_feed_kills()  # F-014/C13: in the same breath as the location text.


func _on_floor_cleared(_floor_number: int) -> void:
	_session.report_floor_cleared()


func _on_floor_exited(_floor_number: int) -> void:
	_session.report_floor_exited()


func _on_player_died() -> void:
	_session.report_player_died()


## F-012/AC33: only says how much came back; the amount is the floor scene's, from core. Not shown
## unless the session says the player is on the floor: a debug skip during the death pause also
## "heals" a dead player into the boss room, and that must not hide "You died".
func _on_healed(amount: int) -> void:
	if _session.get_place() != TowerSession.Place.FLOOR:
		return
	_hud.show_banner(HEALED_FORMAT % amount, Tunables.tower.banner_duration)


## What the session says about a clear; the banner is only how it is shown (AC28).
func _on_session_floor_cleared(floor_number: int, newly_unlocked: int) -> void:
	var count: int = _session.get_progress().get_floor_count()
	_hud.show_banner(
		cleared_banner_text(floor_number, newly_unlocked, count), Tunables.tower.banner_duration
	)
