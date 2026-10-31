extends RefCounted
## Scripted runs for PlayerMotor tests. Times are sampled at multiples of 1/30 s (§5).

const RATES: Array[int] = [30, 60, 120]
const THIRTIETH: float = 1.0 / 30.0
const TILE_TOLERANCE: float = 0.01
const WARRIOR_PATH: String = "res://data/classes/warrior.tres"


static func warrior() -> ClassData:
	return (load(WARRIOR_PATH) as ClassData).duplicate()


static func rules() -> PlayerCombatTunables:
	return Tunables.player_combat.duplicate()


static func motor_with(
	class_data: ClassData = null, tunables: PlayerCombatTunables = null
) -> PlayerMotor:
	var motor: PlayerMotor = PlayerMotor.new()
	motor.setup(
		class_data if class_data != null else warrior(),
		tunables if tunables != null else rules(),
		Vector2.ZERO
	)
	return motor


static func ticks_for(rate: int, seconds: float) -> int:
	return roundi(seconds * rate)


## One tick with these commands. Move and aim are submitted every tick, like the mapper.
static func step(
	motor: PlayerMotor,
	rate: int,
	move: Vector2 = Vector2.ZERO,
	aim: Vector2 = Vector2.ZERO,
	dash: bool = false
) -> void:
	motor.submit(MoveCommand.new(move))
	motor.submit(AimCommand.new(aim))
	if dash:
		motor.submit(DashCommand.new())
	motor.tick(1.0 / rate)


static func run(
	motor: PlayerMotor,
	rate: int,
	seconds: float,
	move: Vector2 = Vector2.ZERO,
	aim: Vector2 = Vector2.ZERO
) -> void:
	for _i: int in ticks_for(rate, seconds):
		step(motor, rate, move, aim)


## Presses dash at each given time (multiples of 1/30 s) and runs until total_seconds.
static func run_with_presses(
	motor: PlayerMotor,
	rate: int,
	total_seconds: float,
	presses: Array[float],
	move: Vector2 = Vector2.ZERO
) -> void:
	var press_ticks: Array[int] = []
	for press: float in presses:
		press_ticks.append(ticks_for(rate, press))
	for tick_index: int in ticks_for(rate, total_seconds):
		step(motor, rate, move, Vector2.ZERO, press_ticks.has(tick_index))


static func position_tiles(motor: PlayerMotor) -> Vector2:
	return Units.vector_px_to_tiles(motor.get_position_px())


static func velocity_tiles(motor: PlayerMotor) -> Vector2:
	return motor.to_dict()["velocity"]


## Records the motor-clock time of every dash the motor fires.
static func record_fire_times(motor: PlayerMotor) -> Array[float]:
	var fire_times: Array[float] = []
	# Weak: a lambda holding the motor from its own signal would never be freed.
	var motor_ref: WeakRef = weakref(motor)
	motor.dash_started.connect(
		func() -> void: fire_times.append(_motor_of(motor_ref).get_iframe_window()[0])
	)
	return fire_times


## Records the exact i-frame window of every dash the motor fires.
static func record_windows(motor: PlayerMotor) -> Array[PackedFloat64Array]:
	var windows: Array[PackedFloat64Array] = []
	var motor_ref: WeakRef = weakref(motor)
	motor.dash_started.connect(
		func() -> void: windows.append(_motor_of(motor_ref).get_iframe_window())
	)
	return windows


## Records the motor's velocity at every dash end.
static func record_end_velocities(motor: PlayerMotor) -> Array[Vector2]:
	var velocities: Array[Vector2] = []
	var motor_ref: WeakRef = weakref(motor)
	motor.dash_ended.connect(
		func() -> void: velocities.append(velocity_tiles(_motor_of(motor_ref)))
	)
	return velocities


static func _motor_of(motor_ref: WeakRef) -> PlayerMotor:
	return motor_ref.get_ref() as PlayerMotor
