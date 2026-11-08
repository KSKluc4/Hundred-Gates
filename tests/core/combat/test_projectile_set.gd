extends GutTest
## F-005 T2: ProjectileSet on its own (C4, C5, C9, C10, C11), and AC28's sampling limit.

const TIME: float = 0.000001
const STEP: float = 1.0 / 120.0


## A combatant that owns a ProjectileSet and nothing else, so AC28 can fly a projectile along
## any line. Steps it the way EnemyLogic does.
class Launcher:
	extends Combatant
	var projectiles: ProjectileSet = ProjectileSet.new()

	func _init(id: StringName) -> void:
		_combat_id = id
		_team = Team.ENEMY
		_position = Vector2(100, 100)

	func sense(_view: CombatView) -> void:
		projectiles.begin_step()

	func step(duration: float) -> void:
		projectiles.advance(duration)

	func _build_extra_hitboxes() -> Array[Hitbox]:
		return projectiles.get_hitboxes(_combat_id, _team)

	func _hurtbox_radius() -> float:
		return 0.1


var _set: ProjectileSet


func before_each() -> void:
	_set = ProjectileSet.new()


func test_launch_latches_values_and_takes_the_next_serial() -> void:
	assert_eq(_launch(), 0)
	assert_eq(_launch(Vector2(1, 1)), 1)
	var second: ProjectileSet.Projectile = _set.get_projectiles()[1]
	assert_eq(second.origin, Vector2(1, 1))
	assert_eq(second.position, Vector2(1, 1), "a flight time of 0 stays at the launch point")
	assert_eq(second.direction, Vector2.UP)
	assert_eq(second.speed, 6.0)
	assert_eq(second.max_distance, 10.0)
	assert_eq(second.radius, 0.25)
	assert_eq(second.damage, 18)
	assert_eq(second.knockback_tiles, 0.5)
	assert_true(second.launched_in_step)
	assert_eq(_set.get_next_serial(), 2)


func test_launch_flies_the_rest_of_the_step_exactly() -> void:
	_set.launch(Vector2.ZERO, Vector2.RIGHT, 6.0, 10.0, 0.25, 18, 0.5, 0.003)
	assert_almost_eq(_set.get_projectiles()[0].position.x, 0.018, TIME)
	assert_eq(_set.get_projectiles()[0].step_start, Vector2.ZERO, "the segment starts at launch")


func test_advance_is_speed_times_time() -> void:
	_launch()
	for _i: int in 30:
		_set.begin_step()
		_set.advance(STEP)
	assert_almost_eq(_set.get_projectiles()[0].position.y, -1.5, TIME)
	assert_almost_eq(_set.get_projectiles()[0].step_start.y, -1.45, TIME, "last step's start")


func test_max_distance_stops_it_exactly_mid_step_and_spends_it() -> void:
	_set.launch(Vector2.ZERO, Vector2.RIGHT, 6.0, 0.1, 0.25, 18, 0.5, 0.0)
	_set.advance(STEP)
	assert_false(_set.get_projectiles()[0].spent, "0.05")
	_set.begin_step()
	_set.advance(0.0123)
	var projectile: ProjectileSet.Projectile = _set.get_projectiles()[0]
	assert_true(projectile.spent)
	assert_eq(projectile.position, Vector2(0.1, 0), "exactly at max distance")
	_set.advance(STEP)
	assert_eq(projectile.position, Vector2(0.1, 0), "a spent one never moves")


func test_spent_and_landed_projectiles_go_at_the_next_step_start() -> void:
	_set.launch(Vector2.ZERO, Vector2.RIGHT, 6.0, 0.01, 0.25, 18, 0.5, STEP)
	_launch(Vector2(5, 5))
	_launch(Vector2(9, 9))
	assert_true(_set.get_projectiles()[0].spent)
	_set.get_hitboxes(&"o", Combatant.Team.ENEMY)[1].mark_hit(&"player_1")  # Shared hit set.
	assert_true(_set.get_projectiles()[1].has_landed())
	assert_eq(_set.get_projectiles().size(), 3, "all three until the next step start")
	_set.begin_step()
	assert_eq(_serials(), [2])


func test_begin_step_starts_the_segments_and_clears_the_launch_flag() -> void:
	_launch()
	_set.advance(STEP)
	_set.begin_step()
	var projectile: ProjectileSet.Projectile = _set.get_projectiles()[0]
	assert_false(projectile.launched_in_step)
	assert_eq(projectile.step_start, projectile.position)


func test_ac15_a_report_short_by_more_than_epsilon_is_a_wall_stop() -> void:
	_launch()
	_set.begin_step()
	_set.advance(STEP * 10)
	var projectile: ProjectileSet.Projectile = _set.get_projectiles()[0]
	var reached: Vector2 = Vector2(0, -0.47)
	assert_true(_set.report_position(0, reached))
	assert_true(projectile.spent)
	assert_eq(projectile.position, reached)
	assert_almost_eq(projectile.travelled, 0.47, TIME)
	assert_eq(_set.get_hitboxes(&"o", Combatant.Team.ENEMY)[0].origin, reached, "contact there")
	_set.begin_step()
	assert_eq(_set.get_projectiles().size(), 0)


func test_ac15_a_report_equal_to_the_plan_or_within_epsilon_changes_nothing() -> void:
	for shortfall: float in [0.0, 0.000001, 0.0000005]:
		before_each()
		_launch()
		_set.begin_step()
		_set.advance(1.0)  # 6 tiles from 0: positions near the origin keep float32 exact.
		var projectile: ProjectileSet.Projectile = _set.get_projectiles()[0]
		var before: Dictionary = projectile.to_dict()
		var reached: Vector2 = projectile.position + Vector2(0, shortfall)
		assert_true(_set.report_position(0, reached))
		assert_eq_deep(projectile.to_dict(), before)


func test_a_report_for_an_unknown_serial_is_an_error_and_changes_nothing() -> void:
	_launch()
	var before: Dictionary = _set.to_dict()
	assert_false(_set.report_position(7, Vector2.ZERO))
	assert_push_error("unknown projectile 7")
	assert_eq_deep(_set.to_dict(), before)


func test_c5_a_blocked_launch_is_removed_and_its_serial_stays_used() -> void:
	_launch()
	assert_true(_set.report_blocked_launch(0))
	assert_eq(_set.get_projectiles().size(), 0)
	assert_eq(_set.get_hitboxes(&"o", Combatant.Team.ENEMY).size(), 0, "never a live hitbox")
	assert_eq(_launch(), 1, "the next launch takes the next serial")


func test_c5_a_blocked_report_for_one_not_launched_this_step_is_an_error() -> void:
	_launch()
	_set.advance(STEP)
	_set.begin_step()
	_launch()
	var before: Dictionary = _set.to_dict()
	assert_false(_set.report_blocked_launch(0))
	assert_push_error("not launched this step")
	assert_false(_set.report_blocked_launch(9))
	assert_push_error("not launched this step")
	assert_eq_deep(_set.to_dict(), before)
	assert_true(_set.report_blocked_launch(1), "the one launched this step can be")


func test_c4_hitboxes_are_single_target_circles_with_no_attacker_hitstop() -> void:
	_launch(Vector2(2, 3))
	_launch(Vector2(4, 5))
	var hitboxes: Array[Hitbox] = _set.get_hitboxes(&"caster_9", Combatant.Team.ENEMY)
	assert_eq(hitboxes.size(), 2)
	assert_eq(hitboxes[1].origin, Vector2(4, 5), "in serial order")
	var hitbox: Hitbox = hitboxes[0]
	assert_eq(hitbox.owner_id, &"caster_9")
	assert_eq(hitbox.team, Combatant.Team.ENEMY)
	assert_eq(hitbox.origin, Vector2(2, 3))
	assert_eq(hitbox.direction, Vector2.UP)
	assert_eq(hitbox.arc_angle_deg, 360.0)
	assert_eq(hitbox.range_tiles, 0.25)
	assert_eq(hitbox.damage, 18)
	assert_eq(hitbox.knockback_tiles, 0.5)
	assert_false(hitbox.is_finisher)
	assert_false(hitbox.knockback_from_center)
	assert_true(hitbox.single_target)
	assert_false(hitbox.attacker_hitstop)


func test_clear_keeps_the_serials_and_reset_restarts_them() -> void:
	_launch()
	_launch()
	_set.clear()
	assert_eq(_set.get_projectiles().size(), 0)
	assert_eq(_launch(), 2)
	_set.reset()
	assert_eq(_set.get_projectiles().size(), 0)
	assert_eq(_launch(), 0)


func test_c10_a_round_trip_keeps_every_field() -> void:
	_launch()
	_set.advance(STEP)
	_launch(Vector2(3, 3))
	_set.get_hitboxes(&"o", Combatant.Team.ENEMY)[1].mark_hit(&"player_2")
	var snapshot: Dictionary = _set.to_dict()
	var fresh: ProjectileSet = ProjectileSet.new()
	fresh.from_dict(snapshot)
	assert_eq_deep(fresh.to_dict(), snapshot)
	assert_eq(fresh.get_next_serial(), 2)
	assert_true(fresh.get_projectiles()[1].has_landed())
	_set.get_projectiles()[0].hit_ids.append(&"x")
	assert_eq(fresh.get_projectiles()[0].hit_ids.size(), 0, "no shared hit set with the original")


func test_c9_sampling_limit_on_both_sides_with_the_exact_limit_passing() -> void:
	assert_eq(ProjectileSet.sampling_errors(30.0, 0.25, 120).size(), 0, "30/120 = 0.25")
	assert_eq(ProjectileSet.sampling_errors(30.01, 0.25, 120).size(), 1)
	assert_eq(ProjectileSet.sampling_errors(60.0, 0.25, 240).size(), 0, "60/240 = 0.25")
	assert_eq(ProjectileSet.sampling_errors(60.01, 0.25, 240).size(), 1)
	assert_eq(ProjectileSet.sampling_errors(6.0, 0.25, 0).size(), 1, "no rate")


func test_c11_rate_errors_name_the_serial_of_each_projectile_in_flight() -> void:
	_set.launch(Vector2.ZERO, Vector2.UP, 60.0, 10.0, 0.25, 18, 0.5, 0.0)
	_set.launch(Vector2.ZERO, Vector2.UP, 30.0, 10.0, 0.25, 18, 0.5, 0.0)
	assert_eq(_set.rate_errors(240).size(), 0)
	var errors: PackedStringArray = _set.rate_errors(120)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "projectile 0")
	_set.get_projectiles()[0].spent = true
	assert_eq(_set.rate_errors(120).size(), 0, "a spent one never moves again")


func test_ac28_a_graze_between_two_contacts_is_missed() -> void:
	var player: PlayerMotor = _ac28(Vector2(0, 0.599))
	assert_eq(player.get_combat_state().get_hp(), 100, "accepted under D-007")


func test_ac28_a_sampled_overlap_is_hit_at_the_first_contact_it_happens() -> void:
	var hit_at: Array[Vector2] = []
	var player: PlayerMotor = _ac28(Vector2(0, 0.5), hit_at)
	assert_eq(player.get_combat_state().get_hp(), 82)
	assert_eq(hit_at, [Vector2(-0.125, 0)] as Array[Vector2])


## Radius 0.25 at speed 30 and 120 steps/s, along (1, 0): contacts at -0.375, -0.125, 0.125
## and 0.375. Returns the stationary Warrior.
func _ac28(warrior_at: Vector2, hit_at: Array[Vector2] = []) -> PlayerMotor:
	var arena: EnemyArena = EnemyArena.new()
	var player: PlayerMotor = arena.add_player(warrior_at)
	var launcher: Launcher = Launcher.new(&"launcher")
	arena.sim.register(launcher)
	launcher.projectiles.launch(Vector2(-0.625, 0), Vector2.RIGHT, 30.0, 10.0, 0.25, 18, 0.5, 0.0)
	var separations: Array[float] = []
	player.get_combat_state().damaged.connect(
		func(_event: HitEvent) -> void:
			hit_at.append(launcher.projectiles.get_projectiles()[0].position)
	)
	for _i: int in 4:
		arena.ticks(1)
		if not launcher.projectiles.get_projectiles().is_empty():
			var bolt: Vector2 = launcher.projectiles.get_projectiles()[0].position
			separations.append(bolt.distance_to(warrior_at))
	if warrior_at.y > 0.59:
		assert_eq(separations.size(), 4)
		for separation: float in separations:
			assert_gt(separation, 0.6, "no candidate at %s" % separation)
	return player


func _launch(origin: Vector2 = Vector2.ZERO) -> int:
	return _set.launch(origin, Vector2.UP, 6.0, 10.0, 0.25, 18, 0.5, 0.0)


func _serials() -> Array:
	var serials: Array = []
	for projectile: ProjectileSet.Projectile in _set.get_projectiles():
		serials.append(projectile.serial)
	return serials
