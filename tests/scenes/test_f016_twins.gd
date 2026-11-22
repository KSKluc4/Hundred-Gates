extends F016LootTest
## F-016 T5 (AC26, and AC25's game part): the same scripted run through a fixture floor at 30, 60
## and 120 physics ticks per second gives the same drops, pickups, inventory and roller state,
## compared in game time (the combat step of the room's sim, 120 a second, is the clock).
## The script is in steps, and only the boundaries of a 30-ticks/s tick (every fourth step) change
## what the player is told, so every rate gives the same commands at the same game time:
## - E0 falls in step 1 where a dash will pass at 0.77 tiles; the dash starts at step 4, and the
##   steps in which the drop is in reach are asserted from the positions: there is at least one and
##   none is the last step of a 30-ticks/s tick, so a build that takes once per tick misses it;
## - E1 falls in the first step of a 30-ticks/s tick and the player in the third step of the same
##   tick (at 120 ticks/s they are different ticks, at 30 one): E1 is rolled at every rate, and the
##   dead player takes nothing, so its drop still lies at the end.
## The twins are built from fresh games, one after the other, on one fixture floor and one seed.

## Combat steps a second: the unit of the script.
const STEPS_PER_SECOND: int = 120
const TICK_RATES: Array[int] = [30, 60, 120]
## One 30-ticks/s tick, in steps.
const BLOCK: int = 4
## The commands and the kills of the script, in steps after the start (a multiple of BLOCK).
const E0_FALLS_AT: int = 1
const DASH_AT: int = 4
const E1_FALLS_AT: int = 33
const PLAYER_FALLS_AT: int = 35
const LENGTH: int = 52
const PLAYER_START: Vector2 = Vector2(3.0, 4.0)
## The dash runs along y = 4 towards +x, a sixth of a tile a step from step 5 on (x = 3 + (step - 4)
## / 6). E0 falls 0.77 tiles to its side, half way between where the player is at the end of step 14
## and of step 15: the drop is in reach (0.8 tiles) at those two steps and at no other, and neither
## is the last step of a 30-ticks/s tick.
const E0_AT: Vector2 = Vector2(4.75, 4.77)
const REACH_STEPS: Array[int] = [14, 15]
const E1_AT: Vector2 = Vector2(14.5, 6.5)
const DEATH_DELAY: float = 100000.0
const POSITION_TOLERANCE: float = 0.0001
const WAIT_LIMIT_TICKS: int = 40


## The probe of the script: far away on the enemy team (nothing sees it), it runs `on_contact`
## once in every combat step, at the contact of that step, and writes down where the player is at
## the end of it.
class Probe:
	extends SimProbe

	const FAR_AWAY: Vector2 = Vector2(10000, 10000)

	var player: Combatant
	## Step number (from 1) -> where the player was at its end.
	var positions: Dictionary[int, Vector2] = {}
	var _acted: Dictionary[int, bool] = {}

	func _init(watched: Combatant) -> void:
		super(&"loot_probe")
		_team = Team.ENEMY
		_position = FAR_AWAY
		player = watched

	## Once per step, whatever number of times the contact asks.
	func get_live_hitbox() -> Hitbox:
		if not _acted.has(steps):
			_acted[steps] = true
			if on_contact.is_valid():
				on_contact.call(steps)
		return null

	func end_step() -> void:
		positions[steps] = player.get_position_tiles()


var _results: Dictionary = {}


func _spawn() -> void:
	var tower: TowerData = loot_tower([3])
	await spawn_loot_game(tower, certain_catalog(tower, 3))
	await enter_frozen_floor()


func _clock() -> int:
	return roundi(room().get_runner().get_sim().get_time() * STEPS_PER_SECOND)


## One run of the script at `rate` ticks a second, from a fresh game. What it found is returned
## in game time; the game is gone when it comes back.
func _run(rate: int) -> Dictionary:
	Engine.physics_ticks_per_second = rate
	set_death_delay(DEATH_DELAY)
	await _spawn()
	var sword_rolls_before: Dictionary = loot().get_roller().to_dict()
	put_player_at(PLAYER_START)
	var first: Enemy = room().get_enemies()[0]
	var second: Enemy = room().get_enemies()[1]
	first.logic.sync_position(Units.vector_tiles_to_px(E0_AT))
	first.sync_body_from_logic()
	second.logic.sync_position(Units.vector_tiles_to_px(E1_AT))
	second.sync_body_from_logic()
	# The start of the script: the end of a 30-ticks/s tick, at every rate.
	while _clock() % BLOCK != 0:
		await run_ticks(1)
	var start: int = _clock()
	var probe: Probe = Probe.new(player().motor)
	var falls: Dictionary = {}
	probe.on_contact = func(step: int) -> void:
		if step == E0_FALLS_AT:
			hit(first.logic, first.logic.get_combat_state().get_hp())
			falls["e0"] = step
		if step == E1_FALLS_AT:
			hit(second.logic, second.logic.get_combat_state().get_hp())
			falls["e1"] = step
		if step == PLAYER_FALLS_AT:
			hit(player().motor, max_hp() * 10)
			falls["player"] = step
	room().get_runner().get_sim().register(probe)
	var pickups: Array[int] = []
	inventory().changed.connect(func() -> void: pickups.append(_clock() - start))
	var per_tick: int = STEPS_PER_SECOND / rate
	for _i: int in LENGTH / per_tick:
		var move: Vector2 = Vector2.ZERO
		if _clock() - start == DASH_AT:
			move = Vector2.RIGHT
			player().motor.submit(DashCommand.new())
		player().motor.submit(MoveCommand.new(move))
		player().motor.submit(AimCommand.new(Vector2.RIGHT))
		await get_tree().physics_frame
	var result: Dictionary = {
		"rate": rate,
		"steps": _clock() - start,
		"falls": falls,
		"pickups": pickups,
		"inventory": inventory().to_dict(),
		"roller": loot().get_roller().to_dict(),
		"roller_before": sword_rolls_before,
		"drops": room().get_loot().to_dict(),
		"positions": probe.positions.duplicate(),
		"place": session().get_place(),
	}
	game().queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return result


func _reach_steps(result: Dictionary) -> Array[int]:
	var steps: Array[int] = []
	var reach: float = Tunables.items.pickup_radius_tiles + Geometry.DISTANCE_EPSILON
	for step: int in result["positions"]:
		if (result["positions"][step] as Vector2).distance_to(E0_AT) <= reach:
			steps.append(step)
	steps.sort()
	return steps


## What a reference roller does for the two deaths of the script, in order: both are rolled (the
## second one too, though the player dies in its 30-ticks/s tick), over a pool of three.
func _reference_picks() -> Dictionary:
	var reference: LootRoller = LootRoller.new()
	reference.seed_with(LOOT_SEED)
	var chance: float = 1.0
	var first: int = reference.roll_regular(chance, 3)
	var second: int = reference.roll_regular(chance, 3)
	return {"first": first, "second": second, "state": reference.to_dict()}


func test_ac26_the_same_run_at_30_60_and_120_ticks_a_second_gives_the_same_loot() -> void:
	var results: Array[Dictionary] = []
	for rate: int in TICK_RATES:
		results.append(await _run(rate))
	var reference: Dictionary = _reference_picks()
	var pool: Array[SwordData] = ItemFixtures.valid_swords(3)
	for result: Dictionary in results:
		var label: String = "at %d ticks/s" % result["rate"]
		assert_eq(result["steps"], LENGTH, "%s: the script ran its length" % label)
		assert_eq(
			result["falls"],
			{"e0": E0_FALLS_AT, "e1": E1_FALLS_AT, "player": PLAYER_FALLS_AT},
			"%s: everyone fell in the step the script says" % label
		)
		# The phase the script is built on, read from the positions of this very run.
		var reach: Array[int] = _reach_steps(result)
		assert_eq(reach, REACH_STEPS, "%s: the drop is in reach in two steps" % label)
		for step: int in reach:
			assert_ne(step % BLOCK, 0, "%s: step %d is not the last of a tick" % [label, step])
		assert_eq((E1_FALLS_AT - 1) / BLOCK, (PLAYER_FALLS_AT - 1) / BLOCK, "one 30/s tick")
		assert_lt(E1_FALLS_AT, PLAYER_FALLS_AT, "E1 fell in an earlier step of it")
		# What came of it.
		assert_eq(result["pickups"], [REACH_STEPS[0]] as Array[int], "%s: taken at once" % label)
		var taken: StringName = pool[reference["first"]].id
		var lying: StringName = pool[reference["second"]].id
		var owned_now: Dictionary = {
			"owned":
			[
				{"id": String(ItemFixtures.STARTER_ID), "count": 1},
				{"id": String(taken), "count": 1},
			],
			"equipped": String(ItemFixtures.STARTER_ID),
		}
		assert_eq(result["inventory"], owned_now, "%s: the starter and the first drop" % label)
		var lying_now: Dictionary = {
			"drops": [{"sword": String(lying), "position": E1_AT, "boss_floor": 0}]
		}
		assert_eq(result["drops"], lying_now, "%s: the second lies where E1 fell" % label)
		assert_eq(result["roller"], reference["state"], "%s: two rolls, as the reference" % label)
		assert_ne(result["roller"], result["roller_before"], "%s: the roller moved" % label)
		assert_eq(result["place"], TowerSession.Place.DEATH_PAUSE, "%s: the player died" % label)
	# The twins: the same everywhere, step for step.
	var base: Dictionary = results[-1]
	for result: Dictionary in results:
		var label: String = "%d against %d ticks/s" % [result["rate"], base["rate"]]
		for key: String in ["pickups", "inventory", "roller", "drops", "falls"]:
			assert_eq(result[key], base[key], "%s: %s" % [label, key])
		var positions: Dictionary = result["positions"]
		assert_eq(positions.size(), (base["positions"] as Dictionary).size(), label)
		for step: int in positions:
			var here: Vector2 = positions[step]
			var there: Vector2 = base["positions"][step]
			assert_true(
				here.distance_to(there) <= POSITION_TOLERANCE,
				"%s: the player at the end of step %d (%s, %s)" % [label, step, here, there]
			)


# --- AC25: the game part ----------------------------------------------------------------------


func test_ac25_a_catalog_with_an_error_is_a_setup_error_and_nothing_is_built() -> void:
	var tower: TowerData = loot_tower([1])
	var catalog: LootCatalog = certain_catalog(tower)
	catalog.starter_sword = ItemFixtures.make_sword(
		&"fixture_bad_starter", 42, SwordData.Kind.NONE, [1, 2]
	)
	await spawn_loot_game(tower, catalog)
	var errors: PackedStringArray = game().get_setup_errors()
	assert_false(errors.is_empty(), "the catalog was refused")
	assert_true(_any(errors, "loot catalog:"), str(errors))
	assert_true(_any(errors, "fixture_bad_starter"), "and it says which sword: %s" % str(errors))
	for error: String in errors:
		assert_push_error(error)
	assert_null(session())
	assert_null(town())
	assert_null(floor_scene())
	assert_null(game().get_player())
	assert_false(game().is_physics_processing(), "nothing steps")
	assert_eq(game().get_child_count(), 1, "only the HUD")
	assert_null(game().get_equipped_sword())
	assert_false(game().can_equip_sword())
	assert_false(game().equip_sword(&"fixture_bad_starter"))


func test_ac25_a_catalog_for_another_tower_is_refused_too() -> void:
	var catalog: LootCatalog = certain_catalog(loot_tower([1], 2))
	await spawn_loot_game(loot_tower([1]), catalog)
	assert_true(_any(game().get_setup_errors(), "floors:"), str(game().get_setup_errors()))
	for error: String in game().get_setup_errors():
		assert_push_error(error)
	assert_null(session())


func test_ac25_item_tunables_with_an_error_are_a_setup_error_too() -> void:
	var rules: ItemTunables = Tunables.items
	var before: float = rules.pickup_radius_tiles
	rules.pickup_radius_tiles = 0.0
	var tower: TowerData = loot_tower([1])
	await spawn_loot_game(tower, certain_catalog(tower))
	rules.pickup_radius_tiles = before
	assert_true(_any(game().get_setup_errors(), "item tunables:"), str(game().get_setup_errors()))
	for error: String in game().get_setup_errors():
		assert_push_error(error)
	assert_null(session())


func test_ac25_with_no_catalog_the_game_runs_as_before() -> void:
	assert_null(Tunables.loot_catalog, "F012GameTest took the shipped one off")
	await spawn_game(loot_tower([2]))
	assert_true(game().get_setup_errors().is_empty())
	assert_null(game().loot_catalog)
	assert_ne(game().loot_seed, 0, "a seed is drawn all the same")
	assert_null(loot().get_catalog())
	assert_null(game().get_equipped_sword())
	assert_true(inventory().get_ids().is_empty(), "nothing is owned")
	assert_eq(max_hp(), ItemFixtures.class_data().max_hp, "the town player is the class's")
	await enter_frozen_floor()
	assert_eq(max_hp(), ItemFixtures.class_data().max_hp)
	assert_null(room().get_loot(), "no loot in the room")
	assert_null(room().get_pickup_markers(), "and no markers")
	assert_null(room().get_runner().get_sim().get_loot(), "and none on the sim")
	kill_all()
	await run_ticks(3)
	assert_true(room().is_cleared())
	assert_eq(banner(), "", "nothing was found")
	assert_true(inventory().get_ids().is_empty())
	assert_false(game().equip_sword(ItemFixtures.STARTER_ID), "there is nothing to equip")


func test_ac25_the_shipped_catalog_starts_the_shipped_game_with_the_recruits_sword() -> void:
	Tunables.loot_catalog = load(Tunables.LOOT_CATALOG_PATH)  # F012GameTest puts the old one back.
	await spawn_game(null)  # No tower given: the game loads the shipped one.
	assert_true(game().get_setup_errors().is_empty(), str(game().get_setup_errors()))
	assert_eq(game().loot_catalog, Tunables.loot_catalog, "read from Tunables")
	assert_eq(inventory().get_ids(), [&"recruits_sword"] as Array[StringName])
	assert_eq(game().get_equipped_sword().id, &"recruits_sword")
	assert_eq(max_hp(), ItemFixtures.class_data().max_hp, "the starter has no trait")
	await enter_floor_through_gate(1)
	assert_not_null(room().get_loot(), "the first room of the shipped floor 1 has its loot")
	assert_not_null(room().get_pickup_markers())


func _any(errors: PackedStringArray, part: String) -> bool:
	for error: String in errors:
		if error.contains(part):
			return true
	return false
