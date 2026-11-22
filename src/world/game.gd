class_name Game
extends Node
## The game loop's glue (F-012, D-012): shows the town or a floor, whichever the TowerSession
## says, and the HUD. Every rule of the loop is the session's (C2): this node reports what
## happened to it (a floor chosen, a room entered, the floor cleared, the exit reached, the
## player dead) and shows what it answers. F-015: the death pause waits for `confirm_death()`, and
## `leave_floor()` leaves a floor by choice; both only pass the session's answer on, so this node
## works alone, with or without a shell (C5). It never frees or replaces the scene that emitted a
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
## F-016/C15: null takes Tunables.loot_catalog in `_ready`, once. With none the game has no loot:
## no sword, no drop, as before F-016.
@export var loot_catalog: LootCatalog
## F-016/C15: the seed of the character's drops. 0 draws a non-zero one in `_ready` (here, in the
## world, never in core) and keeps it in this property; any other seed is used as it is.
@export var loot_seed: int = 0

var _session: TowerSession
var _town: TownScene
var _floor: FloorScene
## F-012/C12: the session changed place; what is shown may not match it any more.
var _is_shown_stale: bool = false
var _setup_errors: PackedStringArray = []
## F-016/C20: the parts of the banner showing and the physics frame of the last one, so that a part
## that arrives in the same frame is joined to it. `_banner_other` is the heal or the clear.
var _banner_other: String = ""
var _banner_found: PackedStringArray = PackedStringArray()
var _banner_frame: int = -1

@onready var _hud: Hud = $Hud


func _ready() -> void:
	process_physics_priority = AFTER_SCENES_PRIORITY
	_hud.player_provider = get_player
	if tower_data == null:
		tower_data = load(Tunables.TOWER_PATH)  # G5
	if class_data == null:
		class_data = load(Tunables.WARRIOR_PATH)  # G5. F-016/C15: before the catalog is validated.
	if loot_catalog == null:
		loot_catalog = Tunables.loot_catalog  # F-016/C15: read once.
	_setup_errors = _collect_setup_errors()
	if not _setup_errors.is_empty():
		for error: String in _setup_errors:
			push_error("Game: %s" % error)
		set_physics_process(false)  # F-012/C9: nothing is built, so nothing steps.
		return
	_session = TowerSession.new()
	_session.setup(tower_data, Tunables.tower)
	if loot_seed == 0:
		loot_seed = _draw_loot_seed()
	_session.set_loot(loot_catalog, loot_seed)  # F-016/C15: after setup().
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
				# The floor stays on screen through the pause. The death screen says "You
				# died": no banner, and a "+30 HP" still showing must not sit under it
				# (F-015/C5).
				_hide_banner()
				_feed_kills(true)  # CR-11: once more, so a kill of the death tick counts.
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


## F-016/C15: the sword the character fights with, or null (a game without loot, or not built).
func get_equipped_sword() -> SwordData:
	if _session == null:
		return null
	return _session.get_loot().get_equipped_sword()


## F-016/C15: the class and the equipped sword as the numbers the world reads. Null when the game
## was not built.
func get_loadout() -> PlayerLoadout:
	if _session == null:
		return null
	return PlayerLoadout.of(class_data, get_equipped_sword(), Tunables.items)


## F-016/C19: what the gate shows for each floor, `{floor_number: text}`: the boss's table with its
## percents and either the guarantee line (no boss sword of that floor taken yet) or what is left to
## 100. No entry for a floor without a table or with an empty one; empty with no catalog. Worked
## out from the character's state each time it is asked, so the town's gate (which asks on every
## open) always shows what is true then.
func get_gate_odds() -> Dictionary:
	var odds: Dictionary = {}
	if _session == null or tower_data == null:
		return odds
	var loot: CharacterLoot = _session.get_loot()
	var catalog: LootCatalog = loot.get_catalog()
	if catalog == null:
		return odds
	for floor_number: int in range(1, tower_data.get_floor_count() + 1):
		var text: String = ItemTexts.odds_text(
			catalog.get_floor_loot(floor_number),
			class_data,
			Tunables.floors.room_clear_heal_fraction,
			not loot.is_boss_sword_taken(floor_number)
		)
		if not text.is_empty():
			odds[floor_number] = text
	return odds


## F-016/C14, C15: whether a sword may be changed now. The session decides; this only says whether
## the floor shown is in its cleared room before the boss (false with no floor).
func can_equip_sword() -> bool:
	return _session != null and _session.can_equip(_is_pre_boss_room_cleared())


## F-016/C14, C15: equips an owned sword where the session allows it. On a yes the player on screen
## (town or floor) fights with it at once, and the running floor's max HP and heal follow.
func equip_sword(sword_id: StringName) -> bool:
	if _session == null or not _session.equip_sword(sword_id, _is_pre_boss_room_cleared()):
		return false
	var sword: SwordData = get_equipped_sword()
	if is_instance_valid(_town):
		_town.set_sword(sword)
	if is_instance_valid(_floor):
		_floor.set_sword(sword)
	return true


## F-015/C5: the person confirmed the death screen. What the session answers; false when the game
## was not built. The town is shown on this node's next `_physics_process`, as for every change.
func confirm_death() -> bool:
	return _session != null and _session.confirm_death()


## F-015/C5: the person chose to leave the floor. What the session answers; false when the game
## was not built. The town is shown on this node's next `_physics_process`.
func leave_floor() -> bool:
	if _session == null:
		return false
	if _session.get_place() == TowerSession.Place.FLOOR and is_instance_valid(_floor):
		_floor.take_loot_here()  # F-016/C16: what lies in the room is taken before it is freed.
	var left: bool = _session.leave_floor()
	if left and is_instance_valid(_floor):
		# F-016/C16 (CR-1): the floor is gone from this moment, though it is freed on this node's
		# next tick. Stopping the whole subtree (the room's runner, the player, the enemies) keeps
		# its sim from stepping once more: a kill in that step would be rolled in a room already
		# emptied, and its sword lost or taken without a word. A refusal stops nothing.
		_floor.process_mode = Node.PROCESS_MODE_DISABLED
	return left


## F-015/C5: whether the pause menu may open now. It decides nothing about the game: it says the
## game was built, the character is in the town or on a floor, what is shown is what the session
## says (false between a place change and the tick that rebuilds), and the gate list is not open.
func is_pause_allowed() -> bool:
	if _session == null or not _setup_errors.is_empty() or _is_shown_stale:
		return false
	match _session.get_place():
		TowerSession.Place.TOWN:
			return not is_instance_valid(_town) or not _town.get_gate_menu().is_open()
		TowerSession.Place.FLOOR:
			return true
	return false


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
	if loot_catalog != null and tower_data != null and class_data != null:
		for error: String in Tunables.items.validate():
			errors.append("item tunables: %s" % error)
		for error: String in loot_catalog.validate(tower_data, class_data, Tunables.items):
			errors.append("loot catalog: %s" % error)
	return errors


## F-014/C13: what the HUD's kills line says, read from the shown room every physics frame (and
## when a room is entered, so it follows the location text): a combat room of a floor shows its
## count and target, the town and a boss room show nothing. The counts are the room's; nothing
## about waves is decided here. In the death pause it is left as it was (CR-4), after the one
## feed of the tick the pause began in (`at_death`, CR-11).
func _feed_kills(at_death: bool = false) -> void:
	if _session.get_place() == TowerSession.Place.DEATH_PAUSE and not at_death:
		return  # CR-4: the pause keeps what the line last said, as the location text does.
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
	town.set_sword(get_equipped_sword())  # F-016/C15
	town.set_odds_provider(get_gate_odds)  # F-016/C19
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
	scene.set_sword(get_equipped_sword())  # F-016/C15
	scene.set_loot(_session.get_loot())  # F-016/C9
	scene.player_input_enabled = player_input_enabled
	scene.death_restarts_room = false  # D-006: death returns to the town, the session says when.
	scene.debug_keys_enabled = debug_keys_enabled
	scene.debug_label_visible = false  # The HUD says where the player is.
	scene.room_entered.connect(_on_room_entered)
	scene.floor_cleared.connect(_on_floor_cleared)
	scene.floor_exited.connect(_on_floor_exited)
	scene.healed.connect(_on_healed)  # F-012/AC33
	scene.loot_taken.connect(_on_loot_taken)  # F-016/C20
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
		return  # A debug skip after a death: the session ignored it, and so do the HUD's two lines.
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
## "heals" a dead player into the boss room, and that must not put a banner under the death screen.
func _on_healed(amount: int) -> void:
	if _session.get_place() != TowerSession.Place.FLOOR:
		return
	_show_banner(HEALED_FORMAT % amount)


## What the session says about a clear; the banner is only how it is shown (AC28).
func _on_session_floor_cleared(floor_number: int, newly_unlocked: int) -> void:
	var count: int = _session.get_progress().get_floor_count()
	_show_banner(cleared_banner_text(floor_number, newly_unlocked, count))


## F-016/C20: what the player took. Shown as `Found: …`, behind the heal or the clear that was shown
## in the same physics frame. Not shown unless the session says the player is on the floor.
func _on_loot_taken(sword_ids: Array[StringName]) -> void:
	if _session.get_place() != TowerSession.Place.FLOOR:
		return
	var names: PackedStringArray = PackedStringArray()
	var catalog: LootCatalog = _session.get_loot().get_catalog()
	for sword_id: StringName in sword_ids:
		names.append(catalog.get_sword(sword_id).display_name)
	if Engine.get_physics_frames() == _banner_frame:
		_banner_found.append_array(names)  # Two takes in one frame are one notice.
	else:
		_banner_other = ""
		_banner_found = names
	_banner_frame = Engine.get_physics_frames()
	_render_banner()


## F-016/C20: a heal or a clear. It replaces what was showing, but keeps a `Found:` part that was
## shown in this very physics frame: the two are joined, this one first.
func _show_banner(text: String) -> void:
	if Engine.get_physics_frames() != _banner_frame:
		_banner_found = PackedStringArray()
	_banner_other = text
	_banner_frame = Engine.get_physics_frames()
	_render_banner()


func _render_banner() -> void:
	var parts: PackedStringArray = PackedStringArray()
	if not _banner_other.is_empty():
		parts.append(_banner_other)
	if not _banner_found.is_empty():
		parts.append(ItemTexts.found_text(_banner_found))
	_hud.show_banner(ItemTexts.BANNER_JOIN.join(parts), Tunables.tower.banner_duration)


func _hide_banner() -> void:
	_banner_other = ""
	_banner_found = PackedStringArray()
	_hud.hide_banner()


## F-016/C14: the fact `TowerSession.can_equip()` wants: the floor shown is in the cleared room
## before the boss. False with no floor.
func _is_pre_boss_room_cleared() -> bool:
	if not is_instance_valid(_floor) or _floor.get_run() == null:
		return false
	return _floor.get_run().is_pre_boss_room_cleared()


## F-016/C15: a non-zero seed, drawn here in the world. Core never draws from the clock.
func _draw_loot_seed() -> int:
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.randomize()
	var drawn: int = generator.randi()
	return drawn if drawn != 0 else 1
