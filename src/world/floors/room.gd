class_name Room
extends Node2D
## One room of a floor, built in code from a RoomData (F-011/C6, C14, D-012). Walls, the door,
## the player, the enemies, then a new CombatRunner, last. Holds no game logic (G6): "cleared"
## is read from the enemies' logic on every call (C11), and the door is only a wall body that
## open_door() turns off. Call setup() before the node enters the tree.

const PLAYER_SCENE_PATH: String = "res://src/entities/player/player.tscn"  # G5
const ENEMY_SCENE_PATH: String = "res://src/entities/enemies/enemy.tscn"  # G5
const PLAYER_SCENE: PackedScene = preload(PLAYER_SCENE_PATH)
const ENEMY_SCENE: PackedScene = preload(ENEMY_SCENE_PATH)
## F-011/C10: walls and the door are layer 1 `world`, which the player and enemy bodies meet.
const WORLD_LAYER: int = 1
const PLAYER_NAME: StringName = &"Player"
const SHAKE_NAME: StringName = &"PlaceholderShake"
const RUNNER_NAME: StringName = &"CombatRunner"
const DOOR_NAME: StringName = &"Door"
const BOSS_LAYER_NAME: StringName = &"BossBarLayer"
const OUTSIDE_NAME: StringName = &"OutsideStrips"

@export var wall_color: Color = Color(0.2, 0.22, 0.28)
@export var door_locked_color: Color = Color(0.6, 0.3, 0.2)
@export var door_open_color: Color = Color(0.25, 0.5, 0.3, 0.35)
## The boss bar's place on screen, as in the debug scenes. Placeholder: → Art & Game Feel.
@export var boss_bar_position_px: Vector2 = Vector2(220, 340)
@export var boss_bar_size_px: Vector2 = Vector2(200, 6)
@export var boss_label_offset_px: Vector2 = Vector2(0, -12)
@export var boss_label_font_size: int = 8

## Set by the owner before the node enters the tree: off for scripted runs.
var player_input_enabled: bool = true

var _room_data: RoomData
var _entry_hp: int = 0
var _class_data: ClassData
var _player: Player
var _enemies: Array[Enemy] = []
var _runner: CombatRunner
var _door: StaticBody2D
var _door_shape: CollisionShape2D
var _door_visual: ColorRect
var _wall_bodies: Array[StaticBody2D] = []
var _camera: PlaceholderShake
var _outside_strips: Array[ColorRect] = []


## `class_data` null keeps the player scene's own (the Warrior).
func setup(room_data: RoomData, entry_hp: int, class_data: ClassData = null) -> void:
	_room_data = room_data
	_entry_hp = entry_hp
	_class_data = class_data


func _ready() -> void:
	_build_outside_strips()  # F-013/C5: first, so the room is drawn over it.
	_build_walls()
	_build_door()
	_build_player()
	_build_enemies()
	_build_debug_draw()
	_build_boss_bar()
	_build_runner()  # F-011/C14: last, so every body has run setup() first.


func get_room_data() -> RoomData:
	return _room_data


func get_player() -> Player:
	return _player


func get_enemies() -> Array[Enemy]:
	return _enemies


func get_runner() -> CombatRunner:
	return _runner


func get_door() -> StaticBody2D:
	return _door


func get_wall_bodies() -> Array[StaticBody2D]:
	return _wall_bodies


## The player's camera (a PlaceholderShake), set up by _build_player().
func get_camera() -> PlaceholderShake:
	return _camera


## F-013/C5: the four wall-coloured strips outside the room, north, south, west, east. Empty
## when `outside_margin_tiles` is 0.
func get_outside_strips() -> Array[ColorRect]:
	return _outside_strips


## F-013/C2: where a room's camera may look, in px. On an axis where the room is at least a view
## long the limits are the room's own edges; on one where it is shorter the range is one view
## long and centred on the room, so a small room sits in the middle of the screen. Static and
## side-effect free so one test pins it (fixtures and debug scenes stay usable).
static func camera_limits_px(room_size_tiles: Vector2i, view_size_px: Vector2i) -> Rect2i:
	var room_px: Vector2i = room_size_tiles * Units.TILE_SIZE_PX
	var origin: Vector2i = Vector2i.ZERO
	var extent: Vector2i = room_px
	for axis: int in 2:
		if room_px[axis] < view_size_px[axis]:
			origin[axis] = floori((room_px[axis] - view_size_px[axis]) / 2.0)
			extent[axis] = view_size_px[axis]
	return Rect2i(origin, extent)


## F-011/C11: computed from logic on every call, never stored, so a restore can't leave it stale.
func is_cleared() -> bool:
	return count_living_enemies() == 0


func count_living_enemies() -> int:
	var living: int = 0
	for enemy: Enemy in _enemies:
		if enemy.logic.is_alive():
			living += 1
	return living


## F-011/C10: collision off at once, so a player walking into it the same tick passes. Safe to
## call again.
func open_door() -> void:
	if _door == null:
		return
	_door.collision_layer = 0
	_door_shape.disabled = true
	_door_visual.color = door_open_color


func is_door_open() -> bool:
	return _door_shape != null and _door_shape.disabled


## F-011/AC16: one body per horizontal run of `#`, tile (x, y) at px (x * 16, y * 16).
func _build_walls() -> void:
	for y: int in _room_data.rows.size():
		var row: String = _room_data.rows[y]
		var x: int = 0
		while x < row.length():
			if row[x] != RoomData.WALL:
				x += 1
				continue
			var start: int = x
			while x < row.length() and row[x] == RoomData.WALL:
				x += 1
			var tiles: Rect2i = Rect2i(start, y, x - start, 1)
			var wall: StaticBody2D = _make_block(tiles, wall_color)
			wall.name = StringName("Wall_%d_%d" % [y, start])
			_wall_bodies.append(wall)
			add_child(wall)


## F-011/C10: one body over the whole `E` run, locked until open_door().
func _build_door() -> void:
	var exits: Array[Vector2i] = _room_data.get_exit_tiles()
	if exits.is_empty():
		return
	var low: Vector2i = exits[0]
	var high: Vector2i = exits[0]
	for tile: Vector2i in exits:
		low = Vector2i(mini(low.x, tile.x), mini(low.y, tile.y))
		high = Vector2i(maxi(high.x, tile.x), maxi(high.y, tile.y))
	_door = _make_block(Rect2i(low, high - low + Vector2i.ONE), door_locked_color)
	_door.name = DOOR_NAME
	_door_shape = _door.get_node("CollisionShape2D")
	_door_visual = _door.get_node("Visual")
	add_child(_door)


func _build_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.name = PLAYER_NAME
	_player.input_enabled = player_input_enabled
	if _class_data != null:
		_player.class_data = _class_data
	_player.position = Units.vector_tiles_to_px(_room_data.get_player_start_tiles())
	var shake: PlaceholderShake = PlaceholderShake.new()
	shake.name = SHAKE_NAME
	_configure_camera(shake)
	_player.add_child(shake)
	_camera = shake
	add_child(_player)


## F-013/C2, C3, C4: limits from the room, smoothing from camera.tres, set before the camera
## enters the tree, so there is no moment in which it is unlimited. The engine re-reads the limits
## whenever they are set, so the order is not observable from outside; C4 (never gliding in from
## another room's place) holds because every way into a room builds a new Room and a new camera.
## Physics callback: the player's body moves in _physics_process (PR-11). `limit_smoothed` stays
## off. The offset the shake adds is applied by the engine after the limits (C5 covers it).
func _configure_camera(shake: PlaceholderShake) -> void:
	var view: Vector2i = Vector2i(get_viewport().get_visible_rect().size)
	var limits: Rect2i = camera_limits_px(_room_data.get_size(), view)
	shake.limit_left = limits.position.x
	shake.limit_top = limits.position.y
	shake.limit_right = limits.end.x
	shake.limit_bottom = limits.end.y
	shake.limit_smoothed = false
	shake.position_smoothing_enabled = Tunables.camera.follow_smoothing_enabled
	shake.position_smoothing_speed = Tunables.camera.follow_smoothing_speed
	shake.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


## F-013/C5: four wall-coloured strips just outside the room's outer rectangle, so a shake at an
## edge never uncovers empty space. The north and south ones take the corners. Visual only: no
## body, so no collision, and nothing in the nav grid.
func _build_outside_strips() -> void:
	var margin: float = Units.tiles_to_px(Tunables.camera.outside_margin_tiles)
	if margin <= 0.0:
		return
	var size_px: Vector2 = Units.vector_tiles_to_px(Vector2(_room_data.get_size()))
	var wide: float = size_px.x + 2.0 * margin
	var strips: Dictionary = {
		&"North": Rect2(-margin, -margin, wide, margin),
		&"South": Rect2(-margin, size_px.y, wide, margin),
		&"West": Rect2(-margin, 0.0, margin, size_px.y),
		&"East": Rect2(size_px.x, 0.0, margin, size_px.y),
	}
	var holder: Node2D = Node2D.new()
	holder.name = OUTSIDE_NAME
	for strip_name: StringName in strips:
		var area: Rect2 = strips[strip_name]
		var strip: ColorRect = ColorRect.new()
		strip.name = strip_name
		strip.position = area.position
		strip.size = area.size
		strip.color = wall_color
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(strip)
		_outside_strips.append(strip)
	add_child(holder)


## F-011/C7, C14: spawn order is the registration order.
func _build_enemies() -> void:
	for spawn: RoomSpawn in _room_data.get_spawns():
		var enemy: Enemy = ENEMY_SCENE.instantiate()
		enemy.name = spawn.combat_id
		enemy.combat_id = spawn.combat_id
		enemy.data = spawn.enemy
		enemy.position = Units.vector_tiles_to_px(spawn.position_tiles)
		_enemies.append(enemy)
		add_child(enemy)


func _build_debug_draw() -> void:
	_runner = CombatRunner.new()  # Not in the tree yet: the draw node only needs its sim.
	_runner.name = RUNNER_NAME
	var debug_draw: CombatDebugDraw = CombatDebugDraw.new()
	debug_draw.runner = _runner
	add_child(debug_draw)


## A boss room has exactly one spawn (C16): its enemy is the boss.
func _build_boss_bar() -> void:
	if not _room_data.is_boss_room or _enemies.size() != 1:
		return
	var label: Label = Label.new()
	label.name = &"Label"
	label.position = boss_label_offset_px
	label.size = Vector2(boss_bar_size_px.x, 0.0)
	label.add_theme_font_size_override(&"font_size", boss_label_font_size)
	var bar: BossBar = BossBar.new()
	bar.boss = _enemies[0]
	bar.bar_size_px = boss_bar_size_px
	bar.position = boss_bar_position_px
	bar.add_child(label)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = BOSS_LAYER_NAME
	layer.add_child(bar)
	add_child(layer)


## F-011/C14: a new runner every room. Player first, then the enemies in spawn order.
func _build_runner() -> void:
	var paths: Array[NodePath] = [NodePath("../%s" % PLAYER_NAME)]
	for enemy: Enemy in _enemies:
		paths.append(NodePath("../%s" % enemy.name))
	_runner.combatant_paths = paths
	_runner.shake_path = NodePath("../%s/%s" % [PLAYER_NAME, SHAKE_NAME])
	_runner.refill_player_on_died = false  # F-011/AC20: the floor scene restarts the room.
	add_child(_runner)
	# F-011/C2: the nav grid comes from the same rows as the walls. Not in any snapshot.
	_runner.get_sim().set_nav(NavGrid.from_rows(_room_data.rows))
	_player.motor.get_combat_state().set_hp(_entry_hp)


## A layer 1 static body over a rectangle of tiles, with a placeholder visual named `Visual`.
func _make_block(tiles: Rect2i, color: Color) -> StaticBody2D:
	var size_px: Vector2 = Units.vector_tiles_to_px(Vector2(tiles.size))
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = WORLD_LAYER
	body.position = Units.vector_tiles_to_px(Vector2(tiles.position)) + size_px / 2.0
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size_px
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = &"CollisionShape2D"
	collision.shape = shape
	body.add_child(collision)
	var visual: ColorRect = ColorRect.new()
	visual.name = &"Visual"
	visual.position = -size_px / 2.0
	visual.size = size_px
	visual.color = color
	body.add_child(visual)
	return body
