class_name F011SceneTest
extends GutTest
## Shared by F-011's scene tests: spawn_floor() runs the real floor_scene.tscn at 120 ticks/s
## with the player's input off, so scripted commands are the only ones. One tick per
## `await physics_frame`.

const FLOOR_SCENE_PATH: String = "res://src/world/floors/floor_scene.tscn"
const RATE: int = 120
const TIME: float = 0.000001
## Tiles from the door's inner side where a scripted walk starts.
const DOOR_APPROACH_TILES: float = 1.0
## Ticks between sword presses: longer than a swing, inside the combo window.
const SWING_PERIOD_TICKS: int = 30

var _floor: FloorScene
var _ticks_per_second_before: int


func before_each() -> void:
	_ticks_per_second_before = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = RATE


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks_per_second_before


## `prepare` runs before the scene enters the tree (set exports).
func spawn_floor(data: FloorData, start_room: int = 0, prepare: Callable = Callable()) -> void:
	_floor = (load(FLOOR_SCENE_PATH) as PackedScene).instantiate()
	_floor.floor_data = data
	_floor.start_room = start_room
	_floor.player_input_enabled = false
	if prepare.is_valid():
		prepare.call(_floor)
	add_child_autofree(_floor)
	await get_tree().physics_frame  # run_ticks must start just before a runner tick.


func room() -> Room:
	return _floor.get_room()


func player() -> Player:
	return _floor.get_room().get_player()


func enemy(index: int = 0) -> Enemy:
	return _floor.get_room().get_enemies()[index]


func hp() -> int:
	return player().motor.get_combat_state().get_hp()


func set_hp(value: int) -> void:
	player().motor.get_combat_state().set_hp(value)


## One tick per iteration. Presses fall on every `swing_every`-th tick when it is above 0.
func run_ticks(
	ticks: int, move: Vector2 = Vector2.ZERO, aim: Vector2 = Vector2.DOWN, swing_every: int = 0
) -> void:
	for index: int in ticks:
		var body: Player = player()
		body.motor.submit(MoveCommand.new(move))
		body.motor.submit(AimCommand.new(aim))
		if swing_every > 0 and index % swing_every == 0:
			body.motor.submit(AttackCommand.new())
		await get_tree().physics_frame


## Runs until `condition` holds, at most `limit` ticks. Returns whether it held.
func run_until(
	condition: Callable,
	limit: int = 600,
	move: Vector2 = Vector2.ZERO,
	aim: Vector2 = Vector2.DOWN,
	swing_every: int = 0
) -> bool:
	for _i: int in limit:
		if condition.call():
			return true
		await run_ticks(1, move, aim, swing_every)
	return condition.call()


## Between ticks: the logic first, then the body from it (F-001/C18's restore path).
func put_player_at(tiles: Vector2) -> void:
	player().motor.sync_position(Units.vector_tiles_to_px(tiles))
	player().sync_body_from_logic()


## The hit path every scene test uses: a HitEvent applied to the target's own CombatState.
func hit(combatant: Combatant, damage: int) -> void:
	var event: HitEvent = HitEvent.new()
	event.attacker_id = &"test"
	event.target_id = combatant.get_combat_id()
	event.damage = damage
	event.direction = Vector2.RIGHT
	combatant.get_combat_state().apply_hit(event, Tunables.player_combat)


func kill(target: Enemy) -> void:
	hit(target.logic, target.logic.get_combat_state().get_hp())


func kill_all() -> void:
	for target: Enemy in room().get_enemies():
		kill(target)


## Just inside the door of the current room, on its first exit tile, facing it, whatever side
## the exit is on.
func put_player_at_door() -> void:
	var exits: Array[Vector2i] = room().get_room_data().get_exit_tiles()
	var inward: Vector2 = -door_outward()
	put_player_at(Vector2(exits[0]) + Vector2(0.5, 0.5) + inward * DOOR_APPROACH_TILES)


## The direction out through the door: away from the room, at right angles to its border.
func door_outward() -> Vector2:
	var tile: Vector2i = room().get_room_data().get_exit_tiles()[0]
	var size: Vector2i = room().get_room_data().get_size()
	if tile.y == 0:
		return Vector2.UP
	if tile.y == size.y - 1:
		return Vector2.DOWN
	return Vector2.LEFT if tile.x == 0 else Vector2.RIGHT


func press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()
