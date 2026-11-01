extends RefCounted
## Scripted runs for F-003's core tests. Commands change and samples are taken only at
## multiples of 1/30 s (the §5 oracle), so times here are counts of thirtieths.

const MotorHarness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const RATES: Array[int] = [30, 60, 120]
const TIME_TOLERANCE: float = 0.000001


## Ticks the motor alone from one thirtieth to another. attacks and dashes hold press times.
static func play(
	motor: PlayerMotor,
	rate: int,
	from_30ths: int,
	to_30ths: int,
	attacks: Array = [],
	dashes: Array = [],
	move: Vector2 = Vector2.ZERO,
	aim: Vector2 = Vector2.ZERO
) -> void:
	var ticks_per_30th: int = rate / 30
	for tick_index: int in range(from_30ths * ticks_per_30th, to_30ths * ticks_per_30th):
		var on_30th: bool = tick_index % ticks_per_30th == 0
		var thirtieth: int = tick_index / ticks_per_30th
		submit_tick(
			motor, move, aim, on_30th and attacks.has(thirtieth), on_30th and dashes.has(thirtieth)
		)
		motor.tick(1.0 / rate)


## One tick's commands, like the mapper: move and aim always, presses when they happen.
static func submit_tick(
	motor: PlayerMotor, move: Vector2, aim: Vector2, attack: bool = false, dash: bool = false
) -> void:
	motor.submit(MoveCommand.new(move))
	motor.submit(AimCommand.new(aim))
	if dash:
		motor.submit(DashCommand.new())
	if attack:
		motor.submit(AttackCommand.new())


static func hit_name(motor: PlayerMotor) -> StringName:
	return motor.get_attack_chain().get_attack_id()


static func phase(motor: PlayerMotor) -> AttackChain.Phase:
	return motor.get_attack_chain().get_phase()
