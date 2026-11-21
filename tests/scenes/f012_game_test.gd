# gdlint:disable=max-public-methods
class_name F012GameTest
extends F012SceneTest
## Shared by F-012's game tests (T7): spawn_game() runs the real game.tscn on a tower, spawn_main()
## the real scenes/main.tscn and chooses Start on its title screen (F-015/T7), both at 120 ticks/s
## with the player's input off. The helpers of F012SceneTest then work on whatever the game shows:
## player(), town() and menu() follow it, and floor_scene() / room() / enemy() read the floor. One
## tick per `await physics_frame`.
## Two tunables are changed for the test and restored after it: the banner stays long enough to be
## read in a slow test, and a test may shorten the death pause with set_death_delay().

const GAME_SCENE_PATH: String = "res://src/world/game.tscn"
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
## F-015/T7: the shell of the main scene, and where spawn_main() keeps its settings file (C12).
const MAIN_SHELL_NODE: NodePath = ^"Shell"
const MAIN_SETTINGS_DIR: String = "user://test_f015"
## Physics ticks spawn_main() lets the shell's input guard take before it calls it stuck.
const MAIN_GUARD_LIMIT_TICKS: int = 20
## Ticks a scripted walk may take before the test calls it stuck.
const WALK_LIMIT_TICKS: int = 600
## Banner time while a test runs: the tests are slow, the HUD counts real frames.
const TEST_BANNER_SECONDS: float = 60.0
## Tiles from the door's inner side where a scripted walk starts.
const DOOR_APPROACH_TILES: float = 1.0

var _game: Game
var _main: Node
var _death_delay_before: float
var _banner_duration_before: float
var _main_settings_file: String = ""
var _main_file_count: int = 0


func before_each() -> void:
	super.before_each()
	_death_delay_before = Tunables.tower.death_return_delay
	_banner_duration_before = Tunables.tower.banner_duration
	Tunables.tower.banner_duration = TEST_BANNER_SECONDS


func after_each() -> void:
	Tunables.tower.death_return_delay = _death_delay_before
	Tunables.tower.banner_duration = _banner_duration_before
	# F-015/C12: spawn_main()'s shell touched the global settings and the physics space.
	UserSettings.reset_to_defaults()
	if not _main_settings_file.is_empty() and FileAccess.file_exists(_main_settings_file):
		DirAccess.remove_absolute(_main_settings_file)
	_main_settings_file = ""
	DirAccess.remove_absolute(MAIN_SETTINGS_DIR)  # Only succeeds when it is empty.
	PhysicsServer2D.space_set_active(get_viewport().world_2d.space, true)
	await super.after_each()


## `prepare` runs before the game enters the tree (set exports, connect signals). The input is off
## unless `prepare` turns it on.
func spawn_game(tower: TowerData, prepare: Callable = Callable()) -> void:
	_game = (load(GAME_SCENE_PATH) as PackedScene).instantiate()
	_game.tower_data = tower
	_game.player_input_enabled = false
	if prepare.is_valid():
		prepare.call(_game)
	add_child_autofree(_game)
	await get_tree().physics_frame  # run_ticks must start just before a runner tick.


## The real main scene with the shipped tower, past its title screen: Start is chosen through the
## shell's panel and the helper waits for the shell's input guard and for the physics space to come
## back (one tick after the game, F-015/DEV-6), so the game is running when it returns. `prepare`
## gets the main scene's `Shell` before the main scene enters the tree; the shell is given a
## settings file of this test's own under `user://test_f015/`, a window applier and a quit handler
## that do nothing, and the player's input off (F-015/C12): no test touches the real settings or
## the real window.
func spawn_main(prepare: Callable = Callable()) -> void:
	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	var shell_node: Shell = _main.get_node(MAIN_SHELL_NODE)
	_main_file_count += 1
	var script_name: String = (get_script() as Script).resource_path.get_file().get_basename()
	_main_settings_file = (
		"%s/%s_main_%d_%d.cfg"
		% [MAIN_SETTINGS_DIR, script_name, OS.get_process_id(), _main_file_count]
	)
	DirAccess.make_dir_recursive_absolute(MAIN_SETTINGS_DIR)
	shell_node.settings_path = _main_settings_file
	shell_node.window_mode_applier = _main_window_applier_stub
	shell_node.quit_handler = _main_quit_stub
	shell_node.player_input_enabled = false
	if prepare.is_valid():
		prepare.call(shell_node)
	add_child_autofree(_main)
	shell_node.get_menu().choose(ShellMenus.START)
	_game = shell_node.get_game()
	assert_not_null(_game, "Start on the main scene's title screen built the game")
	for _i: int in MAIN_GUARD_LIMIT_TICKS:
		if not shell_node.is_guarding():
			break
		await get_tree().physics_frame
	assert_false(shell_node.is_guarding(), "the main scene's guard let the game run")
	await get_tree().physics_frame  # The physics space is back one tick after the game.


func main_scene() -> Node:
	return _main


func _main_window_applier_stub(_mode: DisplayServer.WindowMode) -> void:
	pass


func _main_quit_stub() -> void:
	pass


func game() -> Game:
	return _game


func session() -> TowerSession:
	return _game.get_session()


func hud() -> Hud:
	return _game.get_hud()


func floor_scene() -> FloorScene:
	return _game.get_floor_scene()


## The floor's current room.
func room() -> Room:
	return floor_scene().get_room()


## Whatever the game shows: the town's player or the floor's.
func player() -> Player:
	return _game.get_player()


func town() -> TownScene:
	return _game.get_town()


func menu() -> GateMenu:
	return town().get_gate_menu()


func enemy(index: int = 0) -> Enemy:
	return room().get_enemies()[index]


func hp() -> int:
	return player().motor.get_combat_state().get_hp()


func max_hp() -> int:
	return player().motor.get_combat_state().get_max_hp()


func set_hp(value: int) -> void:
	player().motor.get_combat_state().set_hp(value)


## Shortens (or lengthens) the death pause for this test; after_each() puts it back.
func set_death_delay(seconds: float) -> void:
	Tunables.tower.death_return_delay = seconds


## F-015/C3: the death pause no longer ends by itself. Ticks until the delay has passed, then
## confirms through the game (what the death screen's button does) and returns what the game said.
## The town is shown after the game's next tick: wait for it with run_until() or run_ticks().
func confirm_death_when_ready(limit: int = WALK_LIMIT_TICKS) -> bool:
	var ready: Callable = func() -> bool: return session().can_confirm_death()
	if not await run_until(ready, limit):
		return false
	return game().confirm_death()


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


## A boss room has one enemy, the boss.
func kill_boss() -> void:
	assert_true(room().get_room_data().is_boss_room, "kill_boss() is for the boss room")
	kill_all()


func kill_player() -> void:
	hit(player().motor, max_hp() * 10)


## Just inside the door of the floor's current room, on its first exit tile, facing it.
func put_player_at_door() -> void:
	var exits: Array[Vector2i] = room().get_room_data().get_exit_tiles()
	put_player_at(Vector2(exits[0]) + Vector2(0.5, 0.5) - door_outward() * DOOR_APPROACH_TILES)


## The direction out through the floor room's door: away from the room, at right angles to its
## border.
func door_outward() -> Vector2:
	var tile: Vector2i = room().get_room_data().get_exit_tiles()[0]
	var size: Vector2i = room().get_room_data().get_size()
	if tile.y == 0:
		return Vector2.UP
	if tile.y == size.y - 1:
		return Vector2.DOWN
	return Vector2.LEFT if tile.x == 0 else Vector2.RIGHT


## What the HUD's location line says.
func location() -> String:
	return hud().get_location()


## Walks the scripted player into the gate until the list is open.
func open_gate_menu() -> void:
	put_player_at_gate()
	var opened: Callable = func() -> bool: return menu().is_open()
	assert_true(await run_until(opened, WALK_LIMIT_TICKS, gate_outward()), "the gate opened")


## Opens the list and chooses the entry for `floor_number` (or the one at its boss).
func enter_floor_through_gate(floor_number: int, at_boss: bool = false) -> void:
	await open_gate_menu()
	await choose_entry(floor_number, at_boss)


## With the list open: chooses that entry, then lets the game swap on its next tick, so a floor is
## shown afterwards.
func choose_entry(floor_number: int, at_boss: bool = false) -> void:
	var entries: Array[TowerEntry] = session().get_progress().get_entries()
	for index: int in entries.size():
		if entries[index].floor_number == floor_number and entries[index].at_boss == at_boss:
			menu().choose(index)
			await run_ticks(2)
			return
	fail_test("the list has no entry for floor %d (at the boss: %s)" % [floor_number, at_boss])


## Kills the room's enemies, walks out of the opened door and waits for the next room.
func clear_room_and_advance() -> void:
	var index: int = floor_scene().get_run().get_room_index()
	kill_all()
	await run_ticks(2)
	put_player_at_door()
	var moved: Callable = func() -> bool: return floor_scene().get_run().get_room_index() != index
	assert_true(await run_until(moved, WALK_LIMIT_TICKS, door_outward()), "the next room")


## In the cleared boss room: walks out of the exit; afterwards the town is shown.
func leave_by_exit() -> void:
	put_player_at_door()  # A player on the exit of a still-locked door is pushed out: again.
	var gone: Callable = func() -> bool: return session().get_place() == TowerSession.Place.TOWN
	assert_true(await run_until(gone, WALK_LIMIT_TICKS, door_outward()), "the exit was reached")
	await run_ticks(2)  # The game swaps on its next tick.


## Kills the boss and walks out of the exit.
func clear_boss_and_leave() -> void:
	kill_boss()
	await run_ticks(2)
	await leave_by_exit()


## Debug skips (what N does) up to the boss room.
func skip_to_boss() -> void:
	var last: int = floor_scene().floor_data.get_room_count() - 1
	while floor_scene().get_run().get_room_index() < last:
		floor_scene().skip_room()


func button_texts() -> Array[String]:
	var texts: Array[String] = []
	for child: Node in menu().get_node("Panel/List").get_children():
		texts.append((child as Button).text)
	return texts


## The text of every entry of the progress, then the stay entry: what the open list must say.
func expected_list_texts() -> Array[String]:
	var texts: Array[String] = []
	for entry: TowerEntry in session().get_progress().get_entries():
		texts.append(GateMenu.entry_text(entry))
	texts.append(GateMenu.STAY_TEXT)
	return texts


## The player the health bar draws, through the provider the HUD was given.
func hud_player() -> Variant:
	return hud().player_provider.call()
