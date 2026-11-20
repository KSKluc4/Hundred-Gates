extends GutTest
## F-011 AC11: CombatSim.set_nav() reaches every combatant's sense() through CombatView.nav, and
## a snapshot is the same with or without it.

const WALLED: PackedStringArray = [
	"############",
	"#....#.....#",
	"#....#.....#",
	"#....#.....#",
	"#....#.....#",
	"#..........#",
	"#..........#",
	"############",
]


## Remembers the NavGrid every view it senses carries.
class NavProbe:
	extends StubCombatant
	var seen: Array[NavGrid] = []

	func sense(view: CombatView) -> void:
		seen.append(view.nav)


func test_ac11_a_new_sim_has_no_nav() -> void:
	assert_null(CombatSim.new().get_nav())


func test_ac11_set_nav_reaches_every_combatants_sense_on_every_step() -> void:
	var sim: CombatSim = _sim()
	var first: NavProbe = _probe(&"first", Combatant.Team.PLAYER)
	var second: NavProbe = _probe(&"second", Combatant.Team.ENEMY)
	sim.register(first)
	sim.register(second)
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	sim.set_nav(grid)
	assert_eq(sim.get_nav(), grid)
	sim.tick(1.0 / 30.0)  # Four steps at 120 per second.
	assert_eq(first.seen.size(), 4)
	assert_eq(second.seen.size(), 4)
	for seen: NavGrid in first.seen + second.seen:
		assert_eq(seen, grid, "the one grid, for everyone")


func test_ac11_without_set_nav_every_view_has_none() -> void:
	var sim: CombatSim = _sim()
	var probe: NavProbe = _probe(&"only", Combatant.Team.PLAYER)
	sim.register(probe)
	sim.tick(1.0 / 60.0)
	assert_eq(probe.seen.size(), 2)
	for seen: NavGrid in probe.seen:
		assert_null(seen)


func test_ac11_set_nav_takes_effect_on_the_next_step_and_can_be_cleared() -> void:
	var sim: CombatSim = _sim()
	var probe: NavProbe = _probe(&"only", Combatant.Team.PLAYER)
	sim.register(probe)
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	sim.tick(1.0 / 120.0)
	sim.set_nav(grid)
	sim.tick(1.0 / 120.0)
	sim.set_nav(null)
	sim.tick(1.0 / 120.0)
	assert_eq(probe.seen.size(), 3)
	assert_null(probe.seen[0])
	assert_eq(probe.seen[1], grid)
	assert_null(probe.seen[2])


func test_ac11_a_real_enemy_senses_it_through_the_view() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	var arena: BruteArena = BruteArena.new()
	arena.add_player(Vector2(6.5, 2.5))
	var chaser: EnemyLogic = arena.add_chaser(Vector2(3.5, 2.5))
	chaser._aggroed = true
	arena.sim.set_nav(grid)
	arena.ticks(1)
	# Walls between: its first step is not the straight line east.
	assert_ne(chaser.get_position_tiles().y, 2.5, "it moved off the row, toward the gap")
	assert_lt(chaser.get_position_tiles().x, 3.5 + 0.025, "and not straight at the wall")


func test_ac11_to_dict_is_the_same_with_and_without_a_nav() -> void:
	var arena: BruteArena = BruteArena.new()
	arena.add_player(Vector2(6.5, 2.5))
	var chaser: EnemyLogic = arena.add_chaser(Vector2(3.5, 2.5))
	chaser._aggroed = true
	arena.ticks(5)
	var before: Dictionary = arena.sim.to_dict()
	arena.sim.set_nav(NavGrid.from_rows(WALLED))
	var after: Dictionary = arena.sim.to_dict()
	assert_eq(after, before)
	assert_eq(after.keys(), CombatSim.SNAPSHOT_KEYS, "no new key")
	assert_false(str(after).contains("nav"))


func test_ac11_from_dict_leaves_the_nav_alone() -> void:
	var arena: BruteArena = BruteArena.new()
	arena.add_player(Vector2(6.5, 2.5))
	arena.add_chaser(Vector2(3.5, 2.5))
	arena.ticks(3)
	var snapshot: Dictionary = arena.sim.to_dict()
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	arena.sim.set_nav(grid)
	arena.ticks(10)
	assert_true(arena.sim.from_dict(snapshot))
	assert_eq(arena.sim.get_nav(), grid, "the grid belongs to the room, not the snapshot")
	assert_eq(arena.sim.to_dict(), snapshot)


## AC6 through AC11 together: with the grid, a chaser behind a wall gets to the player and never
## stands in a wall tile. Without move_bodies, only the logic's own integration moves it.
func test_ac11_a_routed_chaser_walks_around_the_wall_to_the_player() -> void:
	var grid: NavGrid = NavGrid.from_rows(WALLED)
	var arena: BruteArena = BruteArena.new()
	arena.add_player(Vector2(6.5, 2.5))
	var chaser: EnemyLogic = arena.add_chaser(Vector2(3.5, 2.5))
	chaser._aggroed = true
	arena.sim.set_nav(grid)
	var closest: float = INF
	for _i: int in 1200:
		arena.ticks(1)
		var position: Vector2 = chaser.get_position_tiles()
		assert_true(grid.is_walkable(grid.tile_of(position)), "in a wall at %s" % position)
		closest = minf(closest, position.distance_to(arena.players[0].get_position_tiles()))
		if closest < 1.7:
			break
	assert_lt(closest, 1.7, "it got within swipe range")


func _sim() -> CombatSim:
	var sim: CombatSim = CombatSim.new()
	sim.setup(120, Tunables.player_combat)
	return sim


func _probe(id: StringName, team: Combatant.Team) -> NavProbe:
	var probe: NavProbe = NavProbe.new()
	probe._combat_id = id
	probe._team = team
	return probe
