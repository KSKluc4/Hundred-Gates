class_name F012SceneTest
extends GutTest
## Shared by F-012's scene tests: spawn_town() runs the real town_scene.tscn at 120 ticks/s with the
## player's input off, so scripted commands are the only ones. One tick per `await physics_frame`.
## The game tests of the next wave extend this class and add their own spawn function; the
## helpers below take whatever the town scene holds, and `run_ticks()` / `run_until()` /
## `put_player_at()` work on `player()`, which a subclass can point at another scene.

const TOWN_SCENE_PATH: String = "res://src/world/town/town_scene.tscn"
const RATE: int = 120
## Tiles from the gate's inner side where a scripted walk starts.
const GATE_APPROACH_TILES: float = 1.0

var _town: TownScene
var _ticks_per_second_before: int
var _held_keys: Array[Key] = []


func before_each() -> void:
	_ticks_per_second_before = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = RATE


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks_per_second_before
	release_held_keys()


## `progress` null leaves the town to make its own. `prepare` runs before the scene enters the
## tree (set exports, connect signals). The input is off unless `prepare` turns it on.
func spawn_town(
	room_data: RoomData, progress: TowerProgress = null, prepare: Callable = Callable()
) -> void:
	_town = (load(TOWN_SCENE_PATH) as PackedScene).instantiate()
	_town.town_room = room_data
	_town.player_input_enabled = false
	if progress != null:
		_town.set_progress(progress)
	if prepare.is_valid():
		prepare.call(_town)
	add_child_autofree(_town)
	await get_tree().physics_frame  # run_ticks must start just before a runner tick.


func town() -> TownScene:
	return _town


func player() -> Player:
	return _town.get_room().get_player()


func menu() -> GateMenu:
	return _town.get_gate_menu()


## One tick per iteration: a MoveCommand and an AimCommand for the player's motor.
func run_ticks(ticks: int, move: Vector2 = Vector2.ZERO, aim: Vector2 = Vector2.DOWN) -> void:
	for _i: int in ticks:
		var body: Player = player()
		body.motor.submit(MoveCommand.new(move))
		body.motor.submit(AimCommand.new(aim))
		await get_tree().physics_frame


## One tick that carries a dash press toward `direction`, as a DashCommand: the dash fires in this
## tick and runs for the next 0.15 s (18 ticks at RATE).
func dash_for_one_tick(direction: Vector2) -> void:
	var body: Player = player()
	body.motor.submit(MoveCommand.new(direction))
	body.motor.submit(AimCommand.new(direction))
	body.motor.submit(DashCommand.new())
	await get_tree().physics_frame


## Runs until `condition` holds, at most `limit` ticks. Returns whether it held.
func run_until(
	condition: Callable, limit: int = 600, move: Vector2 = Vector2.ZERO, aim: Vector2 = Vector2.DOWN
) -> bool:
	for _i: int in limit:
		if condition.call():
			return true
		await run_ticks(1, move, aim)
	return condition.call()


## Between ticks: the logic first, then the body from it (F-001/C18's restore path).
func put_player_at(tiles: Vector2) -> void:
	player().motor.sync_position(Units.vector_tiles_to_px(tiles))
	player().sync_body_from_logic()


## Just inside the room's first gate tile (its exit tile), facing it, on the walkable side.
func put_player_at_gate() -> void:
	var exits: Array[Vector2i] = town().get_room().get_room_data().get_exit_tiles()
	put_player_at(Vector2(exits[0]) + Vector2(0.5, 0.5) - gate_outward() * GATE_APPROACH_TILES)


## The direction out through the gate: away from the room, at right angles to its border.
func gate_outward() -> Vector2:
	var data: RoomData = town().get_room().get_room_data()
	var tile: Vector2i = data.get_exit_tiles()[0]
	var size: Vector2i = data.get_size()
	if tile.y == 0:
		return Vector2.UP
	if tile.y == size.y - 1:
		return Vector2.DOWN
	return Vector2.LEFT if tile.x == 0 else Vector2.RIGHT


## A press and a release of an input action, through the engine's input path (_input, the GUI,
## _unhandled_input). It sets the action itself: no key is pressed, so Input's polling
## (is_action_just_pressed, is_physical_key_pressed) doesn't see it. Use press_key() for that.
func press_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


## The key stays down for Input's polling (what the player's own input reads, as
## Input.is_physical_key_pressed) until release_held_keys(), which after_each() calls.
## Like the keyboard it sends both the key and the physical key, so it matches the game's actions
## (bound by physical key) and the built-in `ui_*` ones (bound by key): Space is `ui_accept` and
## `dodge`. With only one of them set, the other family never matched and F-012's CR-2 got through.
func hold_key(key: Key) -> void:
	_send_key(key, true)
	_held_keys.append(key)


func release_held_keys() -> void:
	for key: Key in _held_keys:
		_send_key(key, false)
	_held_keys.clear()


## F-012/CR-2: the key goes down between two physics ticks, where the OS delivers it, and stays
## down until release_held_keys(). Posted from inside a physics tick (as hold_key() after a
## `physics_frame`) Input counts the press for the tick after next, one later than the real
## thing, and a tap (press and release together) is never "just pressed" when a tick polls it.
func hold_key_between_ticks(key: Key) -> void:
	await get_tree().process_frame
	hold_key(key)


## A press and a release at once, as a tap.
func press_key(key: Key) -> void:
	_send_key(key, true)
	_send_key(key, false)


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
