# gdlint:disable=max-public-methods
class_name F016ShellTest
extends F015ShellTest
## Shared by F-016's shell tests (T6): the real shell on a fixture tower with a fixture catalog. The
## catalog goes on `Tunables.loot_catalog` BEFORE Start, because the shell builds the game then and
## the game reads it once in `_ready` (F012GameTest took the shipped one off, and puts it back after
## each test). The fixtures and the world helpers are F016LootTest's; they are static there and the
## few instance helpers a shell test needs are repeated here, as that class cannot be a second base.
## Nothing here depends on luck: use F016LootTest.quiet_catalog() (no regular drop ever comes) and
## give the character the swords the test needs.

## GUT's own layer is 128 and swallows clicks below it; a menu layer above it gets them.
const ABOVE_GUT_LAYER: int = 129
const MENU_LAYER_PATH: NodePath = ^"MenuLayer"
## The sword entries' texts are written out in the tests; these are the numbers behind them.
const CLASS_MAX_HP: int = 100
const VITALITY_MAX_HP: int = 108


## The shell on its title screen, a catalog given to the game it will build, input off unless asked.
func spawn_loot_shell(tower: TowerData, catalog: LootCatalog, input_enabled: bool = false) -> void:
	Tunables.loot_catalog = catalog
	await spawn_shell_on(tower, input_enabled)


## spawn_loot_shell(), then Start: the town is shown and the game runs.
func start_loot_game(tower: TowerData, catalog: LootCatalog, input_enabled: bool = false) -> void:
	await spawn_loot_shell(tower, catalog, input_enabled)
	await start_game()


func loot() -> CharacterLoot:
	return session().get_loot()


func inventory() -> Inventory:
	return loot().get_inventory()


## Gives the character a sword of the catalog (as a pickup would) and returns its id.
func give(sword_id: StringName) -> StringName:
	inventory().add(sword_id)
	return sword_id


## Turns the AI of every enemy of the shown room off: nobody moves, nobody hits.
func freeze_enemies() -> void:
	for target: Enemy in room().get_enemies():
		target.logic.set_ai_enabled(false)


## The town's gate, floor `floor_number`, and the enemies of its first room frozen.
func enter_frozen_floor(floor_number: int = 1, at_boss: bool = false) -> void:
	await enter_floor_through_gate(floor_number, at_boss)
	freeze_enemies()


## Kills every enemy of the room: the room is then cleared (and its door open).
func clear_here() -> void:
	kill_all()
	await run_ticks(2)
	assert_true(room().is_cleared(), "the room is cleared")


## Pauses with Escape and chooses `Equipment`: the Equipment menu is on screen.
func open_equipment() -> void:
	await pause_with_escape()
	choose(ShellMenus.EQUIPMENT_ID)
	assert_eq(flow().get_state(), ShellFlow.State.EQUIPMENT, "the Equipment menu is open")


## The text of every entry of the panel, in the order shown.
func entry_texts() -> Array[String]:
	var texts: Array[String] = []
	for id: StringName in panel().get_entry_ids():
		texts.append(panel().get_entry_text(id))
	return texts


## The ids of the sword entries of the panel, in order.
func sword_entry_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in panel().get_entry_ids():
		if not EquipmentMenu.sword_of(id).is_empty():
			ids.append(id)
	return ids


## Puts the menu layer above GUT's so that a real click reaches it, once per test.
func raise_menu_layer() -> void:
	(shell().get_node(MENU_LAYER_PATH) as CanvasLayer).layer = ABOVE_GUT_LAYER
	await get_tree().process_frame
	await get_tree().process_frame


## A real click at the centre of entry `id`'s live button: the pointer moves there, the left button
## goes down and up, a frame apart, through the engine's input path.
func click_entry(id: StringName) -> void:
	await raise_menu_layer()
	var at: Vector2 = entry_rect(id).get_center()
	var window_point: Vector2 = get_viewport().get_final_transform() * at
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = window_point
	motion.global_position = window_point
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = window_point
		event.global_position = window_point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame


## The rectangle of the live button of entry `id`, in the canvas's coordinates.
func entry_rect(id: StringName) -> Rect2:
	var buttons: Array[Button] = []
	for node: Node in panel().find_children("*", "Button", true, false):
		if not node.is_queued_for_deletion():
			buttons.append(node as Button)
	var index: int = panel().get_entry_ids().find(id)
	assert_gte(index, 0, "the menu has an entry %s" % id)
	assert_eq(buttons.size(), panel().get_entry_ids().size(), "one live button per entry")
	return buttons[index].get_global_rect()


## What a pause must not change: the sim's and the session's snapshots, the clock and the places of
## the player, the enemies and their projectiles.
func world_snapshot() -> Dictionary:
	var shown: Room = town().get_room() if town() != null else floor_scene().get_room()
	var sim: CombatSim = shown.get_runner().get_sim()
	var positions: Array = [player().global_position]
	for node: Enemy in shown.get_enemies():
		positions.append(node.global_position)
		for bolt: ProjectileSet.Projectile in node.logic.get_projectiles().get_projectiles():
			positions.append(bolt.position)
	return {
		"sim": JSON.stringify(sim.to_dict()),
		"session": JSON.stringify(session().to_dict()),
		"positions": positions,
		"time": sim.get_time(),
	}
