extends GutTest
## F-003 T5: step() and finish_tick(). tick() keeps F-001's behavior on top of them.

const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const STEP: float = 1.0 / 120.0


func test_held_commands_apply_to_every_step_of_a_tick() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	motor.submit(MoveCommand.new(Vector2.RIGHT))
	for _i: int in 4:
		motor.step(STEP)
	motor.finish_tick()
	var whole: PlayerMotor = Harness.motor_with()
	whole.submit(MoveCommand.new(Vector2.RIGHT))
	whole.tick(4.0 * STEP)
	assert_almost_eq(Harness.position_tiles(motor).x, Harness.position_tiles(whole).x, 0.00001)
	assert_almost_eq(Harness.velocity_tiles(motor).x, Harness.velocity_tiles(whole).x, 0.00001)


func test_finish_tick_clears_held_commands() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	motor.submit(MoveCommand.new(Vector2.RIGHT))
	motor.step(STEP)
	motor.finish_tick()
	motor.step(STEP)
	assert_lt(Harness.velocity_tiles(motor).x, 5.0 * STEP / 0.05, "decelerating, no input")


func test_step_does_not_clear_held_commands_by_itself() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	motor.submit(MoveCommand.new(Vector2.RIGHT))
	motor.step(STEP)
	var after_one: float = Harness.velocity_tiles(motor).x
	motor.step(STEP)
	assert_gt(Harness.velocity_tiles(motor).x, after_one)


func test_a_press_is_consumed_by_the_first_step_only() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	var fire_times: Array[float] = Harness.record_fire_times(motor)
	motor.submit(DashCommand.new())
	for _i: int in 80:
		motor.step(STEP)
	motor.finish_tick()
	assert_eq(fire_times.size(), 1, "the same press never fires twice")


func test_displacement_covers_the_last_step_only() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	motor.submit(MoveCommand.new(Vector2.RIGHT))
	motor.submit(DashCommand.new())
	motor.step(STEP)
	motor.step(STEP)
	var dash_speed_px: float = Units.tiles_to_px(3.0 / 0.15)
	assert_almost_eq(motor.get_tick_displacement_px().x, dash_speed_px * STEP, 0.001)


func test_invulnerable_flag_covers_the_last_step_only() -> void:
	var data: ClassData = Harness.warrior()
	var motor: PlayerMotor = Harness.motor_with(data)
	motor.submit(DashCommand.new())
	var steps_inside: int = ceili(data.dash_iframe_duration * 120.0)
	for _i: int in steps_inside:
		motor.step(STEP)
		assert_true(motor.is_invulnerable())
	motor.step(STEP)
	assert_false(motor.is_invulnerable(), "the step is past the window, the dash is not over")
	assert_eq(motor.get_state(), PlayerMotor.State.DASHING)


func test_velocity_getter_reads_the_motor_not_the_body() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	Harness.run(motor, 60, 0.2, Vector2.RIGHT)
	assert_eq(motor.get_velocity_tiles(), Harness.velocity_tiles(motor))


func test_step_on_an_unstarted_motor_does_nothing() -> void:
	var motor: PlayerMotor = PlayerMotor.new()
	motor.submit(MoveCommand.new(Vector2.RIGHT))
	motor.step(STEP)
	motor.finish_tick()
	assert_eq(motor.get_position_px(), Vector2.ZERO)


func test_the_motor_is_a_combatant_with_its_id_and_team() -> void:
	var motor: PlayerMotor = PlayerMotor.new()
	motor.setup(Harness.warrior(), Harness.rules(), Vector2.ZERO, Vector2.DOWN, &"player_2")
	assert_is(motor, Combatant)
	assert_eq(motor.get_combat_id(), &"player_2")
	assert_eq(motor.get_team(), Combatant.Team.PLAYER)
