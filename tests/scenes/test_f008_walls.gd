extends F008SceneTest
## F-008 T6: AC7 over real physics in f008_hexer.tscn. One bolt of a volley breaks on a wall
## while the others fly on, and a volley born overlapping a wall is blocked whole.

const BOLT_RADIUS_PX: float = 0.25 * 16.0


## The Hexer 1.5 tiles under the north wall, the player 5 tiles to its left: fan A's +20° bolt
## climbs into the wall, the −20° one flies its full 10 tiles, the middle one hits the player.
func test_ac7_one_bolt_of_a_fan_breaks_on_a_wall_and_the_others_fly_on() -> void:
	await spawn_debug_scene(place.bind(Vector2(10, 1.5), Vector2(15, 1.5)))
	var watch: CasterWatch = watch_enemy()
	await run_ticks(360)  # 3 s: fan A launches at 0.7 s, its −20° bolt is spent at 2.37 s.
	assert_eq(watch.at(_first_step(watch, 0))["projectiles"].size(), 3, "a fan of three")
	var up: Dictionary = _last_sample(watch, 2)
	assert_true(up["spent"], "+20° stopped")
	var centre: Vector2 = Units.vector_tiles_to_px(up["position"])
	assert_almost_eq(centre.y, BOLT_RADIUS_PX, 0.5, "at the north wall's face")
	var start: Vector2 = Vector2(15, 1.5)
	assert_lt(start.distance_to(up["position"]), 5.0, "well short of its max distance")
	var down: Dictionary = _last_sample(watch, 0)
	assert_true(down["spent"])
	assert_almost_eq(start.distance_to(down["position"]), 10.0, 0.01, "−20° flew its 10 tiles")
	assert_eq(_player.motor.get_combat_state().get_hp(), 82, "the middle bolt hit, once")


## A caster copy with a 0.6-tile volley bolt (bigger than its 0.35-tile body) against the east
## wall: every bolt of its fan is born overlapping the wall.
func test_ac7_a_volley_born_in_a_wall_is_blocked_whole() -> void:
	var data: EnemyData = volley_caster(FAN)
	data.attacks[0].range_tiles = 0.6
	var prepare: Callable = func() -> void:
		_enemy.data = data
		place(Vector2(14.6, 6), Vector2(19.6, 6))
	await spawn_debug_scene(prepare)
	var watch: CasterWatch = watch_enemy()
	var drawn: Array[int] = []
	for _i: int in 100:
		await run_ticks(1)
		drawn.append(_enemy.get_bolts_px().size())
	assert_eq(_enemy.logic.get_projectiles().get_next_serial(), 3, "three launched, serials used")
	assert_eq(_enemy.logic.get_projectiles().get_projectiles().size(), 0)
	assert_true(watch.seen_at.is_empty(), "none ever reached a contact")
	assert_eq(drawn.max(), 0, "none ever drawn")
	assert_eq(_player.motor.get_combat_state().get_hp(), 100, "none ever hit")


func _first_step(watch: CasterWatch, serial: int) -> int:
	return watch.seen_at[serial][0]


func _last_sample(watch: CasterWatch, serial: int) -> Dictionary:
	return watch.projectile_at(watch.seen_at[serial][-1], serial)
