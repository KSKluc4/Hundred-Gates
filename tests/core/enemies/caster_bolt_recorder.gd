extends RefCounted
## F-008 AC3: one scripted caster_bolt run, recorded as text: every projectile (serial,
## position, spent, hit ids) at every contact, every hit on the player, and the final HP. The
## golden file was recorded with the same script on the code before F-008 (f9c6f4e).
## Preloaded by path, not a class_name, so it runs on that older tree too.

const GOLDEN_PATH: String = "res://tests/fixtures/f008/caster_bolt_run.txt"
const START: Vector2 = Vector2(0, 6.52)
const THIRTIETHS: int = 150


static func record() -> String:
	var arena: CasterArena = CasterArena.new()
	var player: PlayerMotor = arena.add_player()
	var caster: EnemyLogic = arena.add_caster(START)
	var watch: CasterWatch = arena.watch_caster(caster)
	var moves: Dictionary = {}
	for thirtieth: int in range(20, 40):
		moves[thirtieth] = Vector2.RIGHT
	for thirtieth: int in range(70, 85):
		moves[thirtieth] = Vector2.LEFT
	arena.play(120, 0, THIRTIETHS, moves, [100])
	var lines: PackedStringArray = []
	var steps: Array = watch.contacts.keys()
	steps.sort()
	for step: int in steps:
		for entry: Dictionary in watch.at(step)["projectiles"]:
			(
				lines
				. append(
					(
						"%d %d %.12f %.12f %s"
						% [
							step,
							entry["serial"],
							entry["position"].x,
							entry["position"].y,
							entry["spent"],
						]
					)
				)
			)
	for event_time: float in arena.hurt_times:
		lines.append("hurt %d" % roundi(event_time * 120.0))
	lines.append(
		"hp %d %d" % [player.get_combat_state().get_hp(), caster.get_combat_state().get_hp()]
	)
	lines.append("serial %d" % caster.get_projectiles().get_next_serial())
	return "\n".join(lines) + "\n"
