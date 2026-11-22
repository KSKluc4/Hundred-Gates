# gdlint:disable=max-public-methods
extends GutTest
## F-016 T2 (C9, C23, AC13, AC14, AC26 core part): the loot's slot in CombatSim.tick(), and the loot
## on a real sim at 30, 60 and 120 physics ticks per second. Without loot the sim is what it was.

const SEED: int = 31337
const FLOOR: int = 1
const FAR: Vector2 = Vector2(30, 30)
const RATES: Array[int] = [30, 60, 120]
## 30 ticks per second are four combat steps of the sim's 120 per second.
const STEPS_PER_TICK_AT_30: int = 4

var _tower: TowerData
var _pool: Array[SwordData]
var _catalog: LootCatalog
var _character: CharacterLoot
var _radius: float


## Writes the moments of a step it takes part in, in the order the sim calls them, into one log.
class Tracer:
	extends Combatant

	var log: Array[String]

	func _init(id: StringName, shared_log: Array[String]) -> void:
		_combat_id = id
		_team = Team.ENEMY
		_position = Vector2(10000, 10000)
		log = shared_log

	func sense(_view: CombatView) -> void:
		log.append("sense %s" % _combat_id)

	func step(_duration: float) -> void:
		log.append("step %s" % _combat_id)

	func fire_due_actions() -> void:
		log.append("fire %s" % _combat_id)

	func get_live_hitbox() -> Hitbox:
		log.append("contact %s" % _combat_id)
		return null

	func end_step() -> void:
		log.append("end %s" % _combat_id)

	func finish_tick() -> void:
		log.append("finish %s" % _combat_id)


## Logs its call into the same log and counts it.
class SpyLoot:
	extends RoomLoot

	var log: Array[String]
	var calls: int = 0

	func end_step() -> void:
		calls += 1
		log.append("loot")


## A real RoomLoot that remembers the call in which it first took a drop.
class TakeProbe:
	extends RoomLoot

	var calls: int = 0
	## The call (end of step) in which something was first taken, 0 while nothing was.
	var taken_at: int = 0

	func end_step() -> void:
		calls += 1
		var before: int = _owned()
		super()
		if _owned() > before and taken_at == 0:
			taken_at = calls

	func _owned() -> int:
		var total: int = 0
		var inventory: Inventory = _character.get_inventory()
		for sword_id: StringName in inventory.get_ids():
			total += inventory.get_count(sword_id)
		return total


func before_each() -> void:
	_tower = TowerFixtures.tower_of(2, 2)
	_pool = ItemFixtures.valid_swords(5)
	_radius = ItemFixtures.rules().pickup_radius_tiles
	_catalog = _catalog_for(_tower)
	_character = LootFixtures.character(_catalog, SEED)


## Two kills a floor and two drops a run: a chance of 1.
func _catalog_for(tower: TowerData) -> LootCatalog:
	var boss: Array[SwordData] = [ItemFixtures.make_sword(&"boss_a", 45)]
	var tables: Array[FloorLoot] = []
	for _floor: int in tower.get_floor_count():
		tables.append(ItemFixtures.floor_loot(2.0, _pool, boss, PackedInt32Array([30])))
	return ItemFixtures.catalog_of(ItemFixtures.starter(), tables)


func _room(character: CharacterLoot, player: Combatant, enemies: Array[Combatant]) -> RoomLoot:
	var room: RoomLoot = LootFixtures.room_loot(character, _tower, FLOOR, 0)
	room.watch_player(player)
	for enemy: Combatant in enemies:
		room.watch_enemy(enemy)
	return room


func _all(player: Combatant, enemies: Array[Combatant]) -> Array[Combatant]:
	var all: Array[Combatant] = [player]
	all.append_array(enemies)
	return all


func _reference() -> RandomNumberGenerator:
	var reference: RandomNumberGenerator = RandomNumberGenerator.new()
	reference.seed = SEED
	return reference


# --- C9: the slot ---------------------------------------------------------------------------------


func test_c9_a_sim_has_no_loot_until_one_is_set() -> void:
	var sim: CombatSim = CombatSim.new()
	assert_null(sim.get_loot())
	var loot: RoomLoot = RoomLoot.new()
	sim.set_loot(loot)
	assert_same(sim.get_loot(), loot)
	sim.set_loot(null)
	assert_null(sim.get_loot(), "null detaches it")


func test_c9_the_loot_is_told_after_every_combatants_end_step_and_before_finish_tick() -> void:
	var log: Array[String] = []
	var first: Tracer = Tracer.new(&"a", log)
	var second: Tracer = Tracer.new(&"b", log)
	var spy: SpyLoot = SpyLoot.new()
	spy.log = log
	var sim: CombatSim = LootFixtures.sim_of(spy, [first, second] as Array[Combatant])
	sim.tick(1.0 / 30.0)
	var one_step: Array[String] = [
		"sense a",
		"sense b",
		"step a",
		"step b",
		"fire a",
		"fire b",
		"contact a",
		"contact b",
		"end a",
		"end b",
		"loot",
	]  # gdlint:disable=max-line-length
	var expected: Array[String] = []
	for _step: int in STEPS_PER_TICK_AT_30:
		expected.append_array(one_step)
	expected.append_array(["finish a", "finish b"] as Array[String])
	assert_eq(log, expected)


func test_c9_the_loot_is_told_once_per_step_whatever_the_tick_rate() -> void:
	for rate: int in RATES:
		var spy: SpyLoot = SpyLoot.new()
		spy.log = []
		var sim: CombatSim = LootFixtures.sim_of(spy, [] as Array[Combatant])
		LootFixtures.run(sim, 1.0, rate)
		assert_eq(spy.calls, LootFixtures.STEP_RATE, "one second at %d ticks per second" % rate)


func test_c9_a_detached_loot_is_not_told() -> void:
	var spy: SpyLoot = SpyLoot.new()
	spy.log = []
	var sim: CombatSim = LootFixtures.sim_of(spy, [] as Array[Combatant])
	sim.tick(1.0 / 120.0)
	sim.set_loot(null)
	sim.tick(1.0 / 120.0)
	assert_eq(spy.calls, 1)


func test_c9_the_sims_snapshot_is_the_same_with_loot_and_without() -> void:
	var results: Array[Dictionary] = []
	for with_loot: bool in [false, true]:
		var player: LootFixtures.Actor = LootFixtures.player(Vector2(1, 1))
		player.velocity = Vector2(2, 0)
		var enemy: LootFixtures.Actor = LootFixtures.enemy(&"e", Vector2(4, 1))
		enemy.kill_in_step(10)
		var enemies: Array[Combatant] = [enemy]
		var loot: RoomLoot = _room(LootFixtures.character(_catalog, SEED), player, enemies)
		var sim: CombatSim = LootFixtures.sim_of(loot if with_loot else null, _all(player, enemies))
		LootFixtures.run(sim, 0.25, 60)
		results.append(sim.to_dict())
	assert_eq_deep(results[1], results[0])
	assert_eq(results[1].keys().size(), CombatSim.SNAPSHOT_KEYS.size())
	for key: String in CombatSim.SNAPSHOT_KEYS:
		assert_true(results[1].has(key), key)


func test_c9_a_sim_without_loot_does_not_roll() -> void:
	var player: LootFixtures.Actor = LootFixtures.player(FAR)
	var enemy: LootFixtures.Actor = LootFixtures.enemy(&"e", Vector2(5, 5))
	var enemies: Array[Combatant] = [enemy]
	var loot: RoomLoot = _room(_character, player, enemies)
	var sim: CombatSim = LootFixtures.sim_of(null, _all(player, enemies))
	enemy.kill_in_step(2)
	LootFixtures.run(sim, 0.1, 60)
	assert_true(loot.get_drops().is_empty(), "nobody told it a step ended")
	assert_eq(_character.get_roller().get_state(), _reference().state)


# --- AC14: the death of the player, at every rate -----------------------------------------------------


## Player dies in step 11, the enemy before it in step 9, one in the same step 11, one after it in
## step 12 and one in step 13. At 30 ticks per second steps 9 to 12 are one tick.
func _run_death_script(tick_rate: int, character: CharacterLoot) -> RoomLoot:
	var player: LootFixtures.Actor = LootFixtures.player(Vector2(5, 20))
	player.kill_in_step(11)
	var enemies: Array[Combatant] = []
	var death_steps: Array[int] = [9, 11, 12, 13]
	for index: int in death_steps.size():
		var enemy: LootFixtures.Actor = LootFixtures.enemy(
			StringName("e%d" % index), Vector2(5 + 2 * index, 5)
		)
		enemy.kill_in_step(death_steps[index])
		enemies.append(enemy)
	var loot: RoomLoot = _room(character, player, enemies)
	var sim: CombatSim = LootFixtures.sim_of(loot, _all(player, enemies))
	LootFixtures.run(sim, 0.2, tick_rate)  # 24 steps: past every death
	return loot


func test_ac14_the_script_puts_the_deaths_in_the_ticks_it_means_to() -> void:
	# At 30 ticks per second, step n is in tick (n - 1) / 4: 9, 11 and 12 share one, 13 is the next.
	var ticks: Array[int] = []
	for step: int in [9, 11, 12, 13]:
		ticks.append((step - 1) / STEPS_PER_TICK_AT_30)
	assert_eq(ticks, [2, 2, 2, 3] as Array[int])


func test_ac14_every_enemy_that_dies_around_the_players_death_is_rolled_at_every_rate() -> void:
	var results: Array[Dictionary] = []
	for rate: int in RATES:
		var character: CharacterLoot = LootFixtures.character(_catalog, SEED)
		var loot: RoomLoot = _run_death_script(rate, character)
		assert_eq(loot.get_drops().size(), 4, "%d ticks per second: all four rolled" % rate)
		results.append({"drops": loot.to_dict(), "loot": character.to_dict()})
	assert_eq_deep(results[1], results[0])
	assert_eq_deep(results[2], results[0])


func test_ac14_the_drops_follow_the_reference_in_the_order_of_the_deaths() -> void:
	var character: CharacterLoot = LootFixtures.character(_catalog, SEED)
	var loot: RoomLoot = _run_death_script(30, character)
	var reference: RandomNumberGenerator = _reference()
	var expected: Array[StringName] = []
	for _i: int in 4:
		reference.randf()
		expected.append(_pool[reference.randi_range(0, 4)].id)
	var got: Array[StringName] = []
	var xs: Array[float] = []
	for drop: LootDrop in loot.get_drops():
		got.append(drop.sword_id)
		xs.append(drop.position.x)
	assert_eq(got, expected)
	assert_eq(xs, [5.0, 7.0, 9.0, 11.0] as Array[float], "in the order the enemies died")
	assert_eq(character.get_roller().get_state(), reference.state)


func test_ac14_a_dead_player_takes_nothing_by_walking_or_by_take_all_and_the_drops_stay() -> void:
	for rate: int in RATES:
		var character: CharacterLoot = LootFixtures.character(_catalog, SEED)
		var loot: RoomLoot = _run_death_script(rate, character)
		loot.take_all()
		assert_eq(loot.get_drops().size(), 4, "%d: still lying" % rate)
		assert_eq(character.get_inventory().get_ids().size(), 1, "%d: the starter only" % rate)
		assert_true(loot.pop_taken().is_empty())


func test_ac14_a_drop_made_before_the_death_is_not_taken_by_a_player_who_dies_next_to_it() -> void:
	for rate: int in RATES:
		var player: LootFixtures.Actor = LootFixtures.player(Vector2(20, 20))
		var enemy: LootFixtures.Actor = LootFixtures.enemy(&"e", Vector2(5, 5))
		enemy.kill_in_step(2)
		player.kill_in_step(6)
		player.scripted[3] = player.place.bind(Vector2(5, 5))  # walks onto the drop... and takes it
		var enemies: Array[Combatant] = [enemy]
		var character: CharacterLoot = LootFixtures.character(_catalog, SEED)
		var loot: RoomLoot = _room(character, player, enemies)
		LootFixtures.run(LootFixtures.sim_of(loot, _all(player, enemies)), 0.1, rate)
		assert_true(loot.get_drops().is_empty(), "%d: taken while alive" % rate)
		assert_eq(character.get_inventory().get_ids().size(), 2, "%d: and kept" % rate)


# --- AC14: a death between ticks, an enemy that dies twice -----------------------------------------------


func test_ac14_a_death_fired_between_ticks_is_rolled_at_the_first_step_of_the_next_tick() -> void:
	for rate: int in RATES:
		var player: LootFixtures.Actor = LootFixtures.player(FAR)
		var enemy: LootFixtures.Actor = LootFixtures.enemy(&"e", Vector2(5, 5))
		enemy.velocity = Vector2(120, 0)  # a tile per step, so the step that rolled it shows
		var enemies: Array[Combatant] = [enemy]
		var character: CharacterLoot = LootFixtures.character(_catalog, SEED)
		var loot: RoomLoot = _room(character, player, enemies)
		var sim: CombatSim = LootFixtures.sim_of(loot, _all(player, enemies))
		enemy.kill()  # between ticks: nobody is stepping
		assert_true(loot.get_drops().is_empty())
		sim.tick(1.0 / rate)
		assert_eq(loot.get_drops().size(), 1, "%d: rolled in that tick" % rate)
		assert_almost_eq(
			loot.get_drops()[0].position.x, 6.0, 0.0001, "%d: in its first step" % rate
		)


func test_ac14_an_enemy_that_dies_twice_is_rolled_once_at_every_rate() -> void:
	for rate: int in RATES:
		var player: LootFixtures.Actor = LootFixtures.player(FAR)
		var enemy: LootFixtures.Actor = LootFixtures.enemy(&"e", Vector2(5, 5))
		enemy.kill_in_step(2)
		enemy.scripted[3] = enemy.revive
		enemy.scripted[4] = enemy.kill
		var enemies: Array[Combatant] = [enemy]
		var character: CharacterLoot = LootFixtures.character(_catalog, SEED)
		var loot: RoomLoot = _room(character, player, enemies)
		LootFixtures.run(LootFixtures.sim_of(loot, _all(player, enemies)), 0.1, rate)
		assert_eq(loot.get_drops().size(), 1, "%d: one drop" % rate)
		var reference: RandomNumberGenerator = _reference()
		reference.randf()
		reference.randi_range(0, 4)
		assert_eq(character.get_roller().get_state(), reference.state, "%d: one roll" % rate)


# --- AC13, AC26: the take is decided in every step, not once per tick ----------------------------------------


## A player running along +x at 72 tiles a second (0.6 a step) from x = 2 passes a drop at x = 5.9
## that an enemy left in step 2. Its end-of-step positions: 5.0, 5.6, 6.2, 6.8 for steps 5 to 8.
func _run_dash(tick_rate: int, character: CharacterLoot) -> Array:
	var player: LootFixtures.Actor = LootFixtures.player(Vector2(2, 5))
	player.velocity = Vector2(72, 0)
	var enemy: LootFixtures.Actor = LootFixtures.enemy(&"e", Vector2(5.9, 5))
	enemy.kill_in_step(2)
	var enemies: Array[Combatant] = [enemy]
	var probe: TakeProbe = TakeProbe.new()
	probe.setup(
		character, FLOOR, _tower.get_floor(FLOOR), 0, _catalog.get_floor_loot(FLOOR), _radius
	)
	probe.watch_player(player)
	probe.watch_enemy(enemy)
	LootFixtures.run(LootFixtures.sim_of(probe, _all(player, enemies)), 0.1, tick_rate)
	return [probe, player]


func test_ac26_the_dash_is_in_reach_only_in_steps_that_are_not_the_last_of_a_30_tick() -> void:
	var character: CharacterLoot = LootFixtures.character(_catalog, SEED)
	var run: Array = _run_dash(120, character)
	var player: LootFixtures.Actor = run[1]
	var drop_at: Vector2 = Vector2(5.9, 5)
	var in_reach: Array[int] = []
	for step: int in range(3, player.positions.size() + 1):  # the drop lies from step 2 on
		if player.positions[step - 1].distance_to(drop_at) <= _radius + Geometry.DISTANCE_EPSILON:
			in_reach.append(step)
	assert_eq(in_reach, [6, 7] as Array[int], "the drop is in reach in steps 6 and 7 only")
	for step: int in in_reach:
		assert_ne(step % STEPS_PER_TICK_AT_30, 0, "step %d ends no 30 ticks per second tick" % step)
	assert_gt(player.positions[1].distance_to(drop_at), _radius, "and not when it dropped")


func test_ac26_the_drop_is_taken_in_step_six_at_every_rate_with_the_same_state() -> void:
	var results: Array[Dictionary] = []
	for rate: int in RATES:
		var character: CharacterLoot = LootFixtures.character(_catalog, SEED)
		var run: Array = _run_dash(rate, character)
		var probe: TakeProbe = run[0]
		assert_eq(probe.taken_at, 6, "%d ticks per second: the sixth end of step" % rate)
		assert_true(probe.get_drops().is_empty())
		assert_eq(character.get_inventory().get_ids().size(), 2, "%d: owned" % rate)
		results.append({"loot": character.to_dict(), "taken": probe.pop_taken()})
	assert_eq_deep(results[1], results[0])
	assert_eq_deep(results[2], results[0])


func test_ac13_a_drop_made_in_a_step_is_taken_in_that_step_by_a_player_in_reach() -> void:
	for rate: int in RATES:
		var player: LootFixtures.Actor = LootFixtures.player(Vector2(5.5, 5))
		var enemy: LootFixtures.Actor = LootFixtures.enemy(&"e", Vector2(5, 5))
		enemy.kill_in_step(3)
		var enemies: Array[Combatant] = [enemy]
		var character: CharacterLoot = LootFixtures.character(_catalog, SEED)
		var probe: TakeProbe = TakeProbe.new()
		probe.setup(
			character, FLOOR, _tower.get_floor(FLOOR), 0, _catalog.get_floor_loot(FLOOR), _radius
		)
		probe.watch_player(player)
		probe.watch_enemy(enemy)
		LootFixtures.run(LootFixtures.sim_of(probe, _all(player, enemies)), 0.1, rate)
		assert_eq(probe.taken_at, 3, "%d: rolled and taken in the step of the death" % rate)
