extends F011SceneTest
## F-011 T5 (AC22): an enemy with a wall between it and the player reaches the player in the
## real scene, with real physics, at 30, 60 and 120 ticks/s (D-007, G1).

const RATES: Array[int] = [30, 60, 120]
## 1.0 tile west of the pillar's face (x = 7), 5.5 tiles from the chaser at (11.5, 4.5): inside
## its 6-tile aggro, with the pillar on the straight line.
const PLAYER_AT: Vector2 = Vector2(6.0, 4.5)
const PILLAR: Rect2 = Rect2(7.0, 4.0, 2.0, 2.0)
const SECONDS: float = 8.0

## Ticks on which an enemy under test had its centre on a tile that is not walkable.
var _wall_ticks: int = 0


func test_ac22_a_chaser_walks_around_a_pillar_to_a_standing_player() -> void:
	for rate: int in RATES:
		Engine.physics_ticks_per_second = rate
		var label: String = "%d ticks/s" % rate
		await spawn_floor(_pillar_floor())
		put_player_at(PLAYER_AT)
		var target: Vector2 = player().motor.get_position_tiles()
		var chaser: EnemyLogic = enemy().logic
		var nav: NavGrid = room().get_runner().get_sim().get_nav()
		var radius: float = chaser.get_data().hurtbox_radius_tiles
		assert_false(
			nav.has_clear_line(chaser.get_position_tiles(), target, radius),
			"%s: the pillar is between them" % label
		)
		var reach: float = chaser.get_data().attacks[0].trigger_max_tiles
		var closest: Array[float] = [INF]
		var near: Callable = func() -> bool:
			closest[0] = minf(closest[0], chaser.get_position_tiles().distance_to(target))
			return chaser.get_position_tiles().distance_to(target) <= reach
		var reached: bool = await run_until(near, int(SECONDS * rate))
		assert_true(reached, "%s: within %.1f tiles (closest %.2f)" % [label, reach, closest[0]])
		_floor.queue_free()
		await get_tree().physics_frame


func test_ac22_the_enemy_never_ends_up_inside_the_pillar() -> void:
	await spawn_floor(_pillar_floor())
	put_player_at(PLAYER_AT)
	var chaser: EnemyLogic = enemy().logic
	for _i: int in int(3.0 * RATE):
		await run_ticks(1)
		var tiles: Vector2 = chaser.get_position_tiles()
		assert_false(PILLAR.grow(-0.01).has_point(tiles), "outside the pillar at %s" % tiles)
		if PILLAR.grow(-0.01).has_point(tiles):
			return


func test_ac22_an_open_room_is_still_a_straight_walk() -> void:
	await spawn_floor(FloorFixtures.floor_of([FloorFixtures.one_enemy_room()] as Array[RoomData]))
	var target: Vector2 = Vector2(6.5, 4.5)
	put_player_at(target)
	var chaser: EnemyLogic = enemy().logic
	var near: Callable = func() -> bool:
		return chaser.get_position_tiles().distance_to(target) <= 1.6
	assert_true(await run_until(near, 4 * RATE), "nothing in the way: straight at the player")
	assert_almost_eq(chaser.get_position_tiles().y, 4.5, 0.2, "no detour")


func _pillar_floor() -> FloorData:
	return FloorFixtures.floor_of([FloorFixtures.pillar_room()] as Array[RoomData])


## F-011/AC22, wide bodies. The brute (radius 0.6) picks its attack by distance only, so with
## the player 3 to 7 tiles away it charges the moment it can, wall or no wall: that first charge
## stops on the pillar and stuns it. The walk is what is under test, so success is either the
## stomp band (1.5 tiles), or a charge started with a clear line.
## Time limit, from the shipped brute: a blocked charge costs 0.8 windup + 1.5 stun + 1.0
## cooldown = 3.3 s; the walk round is about 6 tiles at 2 tiles/s = 3 s. Two blocked charges
## and the walk fit in 10 s; the pillar gets 12.
func test_ac22_a_brute_walks_around_a_pillar_to_a_standing_player() -> void:
	for rate: int in [30, 120]:
		Engine.physics_ticks_per_second = rate
		var data: RoomData = FloorFixtures.pillar_room(&"brute_pillar", RoomFixtures.brute())
		await spawn_floor(FloorFixtures.floor_of([data] as Array[RoomData]))
		put_player_at(PLAYER_AT)
		var label: String = "brute, pillar, %d ticks/s" % rate
		assert_true(await _brute_reaches_player(12.0), label)
		assert_eq(_wall_ticks, 0, "%s: the brute's centre never entered a wall tile" % label)
		_floor.queue_free()
		await get_tree().physics_frame


## The tightest layout C16 allows: a wall 2 tiles thick, one gap 2 tiles wide, and a body
## 1.2 tiles across. The brute starts east of the wall, the player west of it, 5 tiles apart.
## Limit: a blocked charge 3.3 s, a second one 3.3 s, the walk through the gap about 9 tiles at
## 2 tiles/s = 4.5 s, so 20 s.
func test_ac22_a_brute_passes_the_two_tile_gap_in_a_two_tile_wall() -> void:
	for rate: int in [30, 120]:
		Engine.physics_ticks_per_second = rate
		var data: RoomData = FloorFixtures.divider_room(RoomFixtures.brute())
		await spawn_floor(FloorFixtures.floor_of([data] as Array[RoomData]))
		put_player_at(Vector2(7.5, 2.5))
		var label: String = "brute, divider, %d ticks/s" % rate
		assert_true(await _brute_reaches_player(20.0), label)
		assert_eq(_wall_ticks, 0, "%s: the brute's centre never entered a wall tile" % label)
		_floor.queue_free()
		await get_tree().physics_frame


## The caster keeps 6 tiles away (stop distance) and 7 is the edge of its bolt band, so a
## player 8 tiles away, behind a wall, can only be approached by walking: the caster leaves
## the wall's east side and goes into the gap (x 9..10, y 4..5). It never enters a wall tile.
## What it does there is not asserted: see the F-011 report (it holds at 6.0 without a line).
func test_ac22_a_caster_walks_in_around_a_wall_to_the_gap() -> void:
	for rate: int in [30, 120]:
		Engine.physics_ticks_per_second = rate
		var data: RoomData = FloorFixtures.divider_room(RoomFixtures.caster())
		await spawn_floor(FloorFixtures.floor_of([data] as Array[RoomData]))
		put_player_at(Vector2(4.5, 2.5))
		var label: String = "caster, divider, %d ticks/s" % rate
		var caster: EnemyLogic = enemy().logic
		var at_gap: Callable = func() -> bool:
			return Rect2(9.0, 4.0, 2.0, 2.0).has_point(caster.get_position_tiles())
		assert_true(await _run_checked(at_gap, 5.0), "%s: reached the gap" % label)
		assert_eq(_wall_ticks, 0, "%s: the caster's centre never entered a wall tile" % label)
		_floor.queue_free()
		await get_tree().physics_frame


## Runs until the brute can hurt the player, or `seconds` pass.
func _brute_reaches_player(seconds: float) -> bool:
	var brute: EnemyLogic = enemy().logic
	var target: Vector2 = player().motor.get_position_tiles()
	var nav: NavGrid = room().get_runner().get_sim().get_nav()
	var stomp: float = brute.get_data().attacks[0].trigger_max_tiles
	var reached: Callable = func() -> bool:
		if brute.get_position_tiles().distance_to(target) <= stomp + 0.01:
			return true
		var attack: EnemyAttackData = brute.get_running_attack()
		return (
			attack != null
			and attack.id == &"brute_charge"
			and brute.get_state() == EnemyLogic.State.WINDUP
			and nav.has_clear_line(brute.get_position_tiles(), target, 0.6)
		)
	return await _run_checked(reached, seconds)


## run_until(), counting the ticks the enemy's centre was on a tile that isn't walkable.
func _run_checked(goal: Callable, seconds: float) -> bool:
	_wall_ticks = 0
	var logic: EnemyLogic = enemy().logic
	var data: RoomData = room().get_room_data()
	for _i: int in int(seconds * Engine.physics_ticks_per_second):
		if goal.call():
			return true
		await run_ticks(1)
		var tile: Vector2 = logic.get_position_tiles()
		if not data.is_walkable(Vector2i(floori(tile.x), floori(tile.y))):
			_wall_ticks += 1
	return goal.call()
