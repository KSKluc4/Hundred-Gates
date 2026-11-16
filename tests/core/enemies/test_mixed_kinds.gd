extends GutTest
## F-008 T1: C6 removes the brain kind rule (AC10). Any brain may use either kind of attack, a
## pattern may mix them, and each attack runs by its own kind: a melee attack has a sector and
## launches nothing, a projectile attack launches and has no sector.

const RATE: int = 120
## Ticks: far longer than any windup + active here.
const LIMIT: int = 240


func test_ac10_mixed_data_passes_validation() -> void:
	var caster: EnemyData = CasterArena.caster_values()
	caster.attacks = [EnemyArena.chaser_values().attacks[0]]
	assert_eq(caster.validate(RATE, Tunables.enemy_combat), PackedStringArray(), "caster melee")
	var chaser: EnemyData = EnemyArena.chaser_values()
	chaser.attacks = [CasterArena.caster_values().attacks[0]]
	assert_eq(chaser.validate(RATE, Tunables.enemy_combat), PackedStringArray(), "chaser bolt")
	var brute: EnemyData = BruteArena.brute_values()
	brute.attacks = [CasterArena.caster_values().attacks[0]]
	assert_eq(brute.validate(RATE, Tunables.enemy_combat), PackedStringArray(), "brute bolt")
	assert_eq(_melee_then_bolt().validate(RATE, Tunables.enemy_combat), PackedStringArray())


func test_ac10_a_caster_with_a_melee_attack_swings_and_launches_nothing() -> void:
	var arena: BruteArena = BruteArena.new()
	arena.caster_data.attacks = [EnemyArena.chaser_values().attacks[0]]
	arena.add_player()
	var caster: EnemyLogic = arena.add_caster(Vector2(0, 1.0))
	_tick_until_active(arena, caster)
	_assert_sector_landed(arena, caster)


func test_ac10_a_chaser_with_a_projectile_attack_launches_and_has_no_sector() -> void:
	var arena: BruteArena = BruteArena.new()
	arena.chaser_data.attacks = [CasterArena.caster_values().attacks[0]]
	arena.add_player()
	var chaser: EnemyLogic = arena.add_chaser(Vector2(0, 4.0))
	_assert_launches(arena, chaser)


func test_ac10_a_brute_with_a_projectile_attack_launches_and_has_no_sector() -> void:
	var arena: BruteArena = BruteArena.new()
	arena.brute_data.attacks = [CasterArena.caster_values().attacks[0]]
	arena.add_player()
	var brute: EnemyLogic = arena.add_brute(Vector2(0, 4.0))
	_assert_launches(arena, brute)


func test_ac10_a_pattern_melee_then_projectile_runs_each_by_its_kind() -> void:
	var arena: BruteArena = BruteArena.new()
	arena.chaser_data = _melee_then_bolt()
	arena.add_player()
	var boss: EnemyLogic = arena.add_chaser(Vector2(0, 1.0))
	_tick_until_active(arena, boss)
	assert_eq(boss.get_running_attack().id, &"root")
	_assert_sector_landed(arena, boss)
	_tick_until(arena, boss, func() -> bool: return boss.get_projectiles().get_next_serial() > 0)
	assert_eq(boss.get_running_attack().id, &"caster_bolt", "the follow-up launched")
	assert_eq(boss.get_projectiles().get_next_serial(), 1)
	assert_null(boss.get_live_hitbox(), "the projectile follow-up has no sector")


## BossValues.chaser_boss() with its root's follow-up swapped for the caster's bolt.
func _melee_then_bolt() -> EnemyData:
	var data: EnemyData = BossValues.chaser_boss()
	data.attacks[0].follow_up = CasterArena.caster_values().attacks[0]
	return data


## Its sector hit the player at the first active contact, and the attacker hitstop it took
## proves it: a bolt never gives its owner hitstop (F-005/C6). Nothing launched.
func _assert_sector_landed(arena: BruteArena, enemy: EnemyLogic) -> void:
	assert_false(enemy.get_running_attack().is_projectile())
	assert_eq(arena.hurt_events.size(), 1, "the sector hit the player")
	assert_true(enemy.get_combat_state().is_in_hitstop(), "attacker hitstop: a sector hit")
	assert_eq(enemy.get_projectiles().get_next_serial(), 0, "nothing launched")


func _assert_launches(arena: BruteArena, enemy: EnemyLogic) -> void:
	_tick_until_active(arena, enemy)
	assert_true(enemy.get_running_attack().is_projectile())
	assert_null(enemy.get_live_hitbox(), "no sector")
	assert_eq(enemy.get_projectiles().get_next_serial(), 1, "one bolt launched")


func _tick_until_active(arena: BruteArena, enemy: EnemyLogic) -> void:
	_tick_until(arena, enemy, func() -> bool: return enemy.get_state() == EnemyLogic.State.ACTIVE)


func _tick_until(arena: BruteArena, _enemy: EnemyLogic, done: Callable) -> void:
	for _i: int in LIMIT:
		arena.tick()
		if done.call():
			return
	fail_test("condition never held within %d ticks" % LIMIT)
