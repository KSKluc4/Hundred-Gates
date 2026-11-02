extends GutTest
## F-003 T4, AC25: the attack press through raw samples. No scene, no devices.

const DEADZONE: float = 0.2

var _mapper: PlayerInputMapper


func before_each() -> void:
	_mapper = PlayerInputMapper.new()


func test_an_attack_press_makes_exactly_one_attack_command() -> void:
	var sample: InputSample = InputSample.new()
	sample.attack_pressed = true
	assert_eq(_attack_commands(_mapper.map(sample, DEADZONE)), 1)


func test_no_press_makes_no_attack_command() -> void:
	assert_eq(_attack_commands(_mapper.map(InputSample.new(), DEADZONE)), 0)


func test_attack_and_dash_in_one_tick_both_come_through() -> void:
	var sample: InputSample = InputSample.new()
	sample.attack_pressed = true
	sample.dodge_pressed = true
	var commands: Array[Command] = _mapper.map(sample, DEADZONE)
	assert_eq(_attack_commands(commands), 1)
	assert_eq(commands.filter(func(c: Command) -> bool: return c is DashCommand).size(), 1)


func _attack_commands(commands: Array[Command]) -> int:
	return commands.filter(func(c: Command) -> bool: return c is AttackCommand).size()
