# gdlint:disable=max-public-methods
# F-014 T2: one test per behaviour of C5, each with its control.
extends GutTest
## F-014 T2: the waiting state (C5, AC4 to AC6). Real sims, real player motors. A test that
## expects "nothing happened" has a twin in which the same set-up does make it happen.

const RATE: int = 120
const FIVE_SECONDS_TICKS: int = 5 * RATE
const AWAY: Vector2 = Vector2(20, 0)


## A chaser held in reserve, with a player where the test says.
func _reserve_arena(player_at: Vector2, enemy_at: Vector2) -> EnemyArena:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(player_at)
	var enemy: EnemyLogic = arena.add_chaser(enemy_at)
	assert_true(enemy.hold_in_reserve())
	return arena


func _hit_event(damage: int, knockback_tiles: float = 0.0) -> HitEvent:
	var event: HitEvent = HitEvent.new()
	event.attacker_id = &"test"
	event.target_id = &"chaser_1"
	event.damage = damage
	event.direction = Vector2.RIGHT
	event.knockback_tiles = knockback_tiles
	return event


# --- AC4: a waiting enemy is not there --------------------------------------------------------


func test_ac4_a_waiting_enemy_is_not_alive_in_a_view_and_cannot_be_hit() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(0, 3))
	var enemy: EnemyLogic = arena.enemies[0]
	assert_true(enemy.is_waiting())
	assert_eq(enemy.get_state(), EnemyLogic.State.WAITING)
	assert_false(enemy.is_alive())
	assert_false(enemy.can_be_hit())
	var view: CombatView = CombatView.capture(arena.sim.get_combatants())
	assert_false(view.find(&"chaser_1").is_alive, "so no brain and no view reader picks it")
	assert_true(view.find(&"player_1").is_alive)


func test_ac4_an_enemy_that_is_not_waiting_is_alive_and_can_be_hit() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player()
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 3))
	assert_false(enemy.is_waiting())
	assert_true(enemy.is_alive())
	assert_true(enemy.can_be_hit())


func test_ac4_a_sword_arc_over_a_waiting_enemy_hits_nothing() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(0, 1))
	var enemy: EnemyLogic = arena.enemies[0]
	var before: Dictionary = enemy.to_dict()
	for index: int in RATE:
		arena.tick(RATE, Vector2.ZERO, false, index % 40 == 0, Vector2.DOWN)
	assert_eq(arena.sword_times.size(), 0, "the sword landed on nothing")
	assert_eq(enemy.get_combat_state().get_hp(), enemy.get_data().max_hp)
	assert_eq_deep(enemy.to_dict(), before)


func test_ac4_the_same_arc_hits_an_enemy_that_is_not_waiting() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2.ZERO)
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1))
	for index: int in RATE:
		arena.tick(RATE, Vector2.ZERO, false, index % 40 == 0, Vector2.DOWN)
	assert_gt(arena.sword_times.size(), 0, "the control: the sword does land")
	assert_lt(enemy.get_combat_state().get_hp(), enemy.get_data().max_hp)


func test_ac4_a_player_standing_on_a_waiting_enemy_does_not_wake_it() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2(3, 3), Vector2(3, 3))
	var enemy: EnemyLogic = arena.enemies[0]
	arena.ticks(FIVE_SECONDS_TICKS)
	assert_false(enemy.is_aggroed())
	assert_eq(enemy.get_state(), EnemyLogic.State.WAITING)
	assert_eq(enemy.get_target_id(), &"")
	assert_eq(arena.hurt_events.size(), 0, "and it never touched the player")


func test_ac4_the_same_player_wakes_an_enemy_that_is_not_waiting() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2(3, 3))
	var enemy: EnemyLogic = arena.add_chaser(Vector2(3, 3))
	arena.ticks(RATE)
	assert_true(enemy.is_aggroed(), "the control: it notices a player on top of it")


func test_ac4_a_waiting_enemy_has_no_hitbox_and_no_projectile_even_in_reach() -> void:
	var arena: CasterArena = CasterArena.new()
	arena.add_player(Vector2.ZERO)
	var caster: EnemyLogic = arena.add_caster(Vector2(0, 4))
	var chaser: EnemyLogic = arena.add_chaser(Vector2(0.5, 0.5), &"chaser_1")
	assert_true(caster.hold_in_reserve())
	assert_true(chaser.hold_in_reserve())
	for _i: int in FIVE_SECONDS_TICKS:
		arena.tick()
		assert_true(caster.get_live_hitboxes().is_empty())
		assert_true(chaser.get_live_hitboxes().is_empty())
		assert_true(caster.get_projectiles().get_projectiles().is_empty())
	assert_eq(arena.hurt_events.size(), 0, "a player in the middle of both was never hurt")


func test_ac4_a_caster_that_is_not_waiting_does_launch_here() -> void:
	var arena: CasterArena = CasterArena.new()
	arena.add_player(Vector2.ZERO)
	var caster: EnemyLogic = arena.add_caster(Vector2(0, 4))
	var launched: bool = false
	for _i: int in FIVE_SECONDS_TICKS:
		arena.tick()
		launched = launched or not caster.get_projectiles().get_projectiles().is_empty()
	assert_true(launched, "the control: the same caster in the same place shoots")


func test_ac4_after_five_seconds_a_waiting_enemy_is_exactly_what_it_was() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2(0, 0), Vector2(0, 2))
	var enemy: EnemyLogic = arena.enemies[0]
	var before: Dictionary = enemy.to_dict()
	var first_position: Vector2 = enemy.get_position_tiles()
	for index: int in FIVE_SECONDS_TICKS:
		arena.tick(RATE, Vector2.ZERO, false, index % 30 == 0, Vector2.DOWN)
		assert_eq(enemy.get_tick_displacement_px(), Vector2.ZERO, "its displacement is zero")
	assert_almost_eq(arena.sim.get_time(), 5.0, 0.0001)
	assert_eq_deep(enemy.to_dict(), before)
	assert_eq(enemy.get_position_tiles(), first_position)
	assert_eq(enemy.get_cooldown_remaining(), 0.0)
	assert_eq(enemy.get_combat_state().get_hp(), enemy.get_data().max_hp)
	assert_eq(enemy.get_state(), EnemyLogic.State.WAITING)


func test_ac4_a_waiting_enemys_cooldown_and_phase_time_do_not_advance() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2(50, 50))
	var enemy: EnemyLogic = arena.add_chaser(Vector2.ZERO)
	assert_true(enemy.hold_in_reserve())
	var carried: Dictionary = enemy.to_dict()
	carried["cooldown_remaining"] = 0.7  # What a restore could leave in it.
	carried["phase_elapsed"] = 0.25
	enemy.from_dict(carried)
	arena.ticks(RATE)
	assert_eq(enemy.get_cooldown_remaining(), 0.7, "no cooldown runs while it waits")
	assert_eq(enemy.to_dict()["phase_elapsed"], 0.25, "and no phase time")


func test_ac4_apply_hit_on_a_waiting_enemy_changes_nothing() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(0, 3))
	var enemy: EnemyLogic = arena.enemies[0]
	var before: Dictionary = enemy.to_dict()
	enemy.apply_hit(_hit_event(20, 2.0), arena.rules)
	assert_eq_deep(enemy.to_dict(), before)
	assert_eq(enemy.get_combat_state().get_hp(), enemy.get_data().max_hp)
	assert_false(enemy.is_aggroed())
	assert_true(enemy.is_waiting())


func test_ac4_apply_hit_on_an_awake_enemy_does_change_it() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2(50, 50))
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 3))
	enemy.apply_hit(_hit_event(20, 2.0), arena.rules)
	assert_true(enemy.is_aggroed(), "the control: a hit wakes it")
	assert_eq(enemy.get_combat_state().get_hp(), enemy.get_data().max_hp - 20)


func test_c5_an_enemy_killed_while_it_waits_is_dead_and_not_waiting() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(0, 3))
	var enemy: EnemyLogic = arena.enemies[0]
	var hp: int = enemy.get_combat_state().get_hp()
	enemy.get_combat_state().apply_hit(_hit_event(hp), arena.rules)  # What a test's kill() does.
	assert_eq(enemy.get_state(), EnemyLogic.State.DEAD)
	assert_false(enemy.is_waiting())
	assert_false(enemy.is_alive())
	assert_false(enemy.can_be_hit())
	arena.ticks(RATE)
	assert_eq(enemy.get_state(), EnemyLogic.State.DEAD)


func test_c5_setup_leaves_an_enemy_not_waiting() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(0, 3))
	var enemy: EnemyLogic = arena.enemies[0]
	assert_true(enemy.setup(arena.chaser_data, arena.enemy_rules, RATE, Vector2(0, 3), &"chaser_1"))
	assert_false(enemy.is_waiting())
	assert_eq(enemy.get_state(), EnemyLogic.State.IDLE)
	assert_true(enemy.is_alive())


# --- AC5: arriving ---------------------------------------------------------------------------


func test_ac5_arrive_puts_it_there_idle_aggroed_and_at_full_hp() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(9, 9))
	var enemy: EnemyLogic = arena.enemies[0]
	assert_true(enemy.arrive(Vector2(5.5, 6.5)))
	assert_eq(enemy.get_position_tiles(), Vector2(5.5, 6.5))
	assert_eq(enemy.get_state(), EnemyLogic.State.IDLE)
	assert_true(enemy.is_aggroed())
	assert_eq(enemy.get_combat_state().get_hp(), enemy.get_data().max_hp)
	assert_false(enemy.is_waiting())
	assert_true(enemy.is_alive())
	assert_true(enemy.can_be_hit())
	assert_eq(enemy.get_tick_displacement_px(), Vector2.ZERO)


func test_ac5_arrive_gives_a_fresh_combat_state() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(9, 9))
	var enemy: EnemyLogic = arena.enemies[0]
	var state: CombatState = enemy.get_combat_state()
	state.set_hp(7)  # What a test can do to a waiting enemy: hurt, short of dying.
	state.apply_hit(_hit_event(3, 2.0), arena.rules)  # Starts hitstop and a push, too.
	assert_lt(state.get_hp(), enemy.get_data().max_hp)
	assert_true(state.is_in_hitstop())
	assert_true(state.has_knockback())
	assert_true(enemy.is_waiting())
	assert_true(enemy.arrive(Vector2(1, 1)))
	assert_eq(state.get_hp(), enemy.get_data().max_hp)
	assert_false(state.is_in_hitstop())
	assert_false(state.has_knockback())


func test_ac5_arrive_emits_arrived_once_and_after_the_state_changed() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(9, 9))
	var enemy: EnemyLogic = arena.enemies[0]
	var seen: Array[EnemyLogic.State] = []
	# Weak: a lambda that held the enemy, connected to the enemy's own signal, is a cycle that
	# keeps the enemy, its sim and their resources alive past the end of the run.
	var weak_enemy: WeakRef = weakref(enemy)
	enemy.arrived.connect(
		func() -> void: seen.append((weak_enemy.get_ref() as EnemyLogic).get_state())
	)
	watch_signals(enemy)
	enemy.arrive(Vector2(1, 1))
	arena.ticks(RATE)
	assert_signal_emit_count(enemy, "arrived", 1)
	assert_eq(seen, [EnemyLogic.State.IDLE] as Array[EnemyLogic.State])


func test_ac5_from_the_next_step_it_walks_toward_a_player_20_tiles_away() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2.ZERO)
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 30))
	enemy.hold_in_reserve()
	arena.ticks(10)
	assert_eq(enemy.get_state(), EnemyLogic.State.WAITING)
	enemy.arrive(AWAY)
	assert_eq(enemy.get_state(), EnemyLogic.State.IDLE, "it senses at the next step start")
	assert_eq(enemy.get_position_tiles(), AWAY)
	arena.tick(RATE)
	assert_eq(enemy.get_state(), EnemyLogic.State.CHASE)
	assert_eq(enemy.get_target_id(), &"player_1")
	arena.ticks(RATE)
	assert_lt(enemy.get_position_tiles().x, AWAY.x - 2.5, "about 3 tiles a second")
	assert_almost_eq(enemy.get_position_tiles().y, 0.0, 0.0001)


func test_ac5_an_unaggroed_enemy_20_tiles_away_would_not_have_moved() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2.ZERO)
	var enemy: EnemyLogic = arena.add_chaser(AWAY)
	arena.ticks(RATE)
	assert_eq(
		enemy.get_position_tiles(), AWAY, "the control: arrive()'s aggro is what makes it walk"
	)


func test_ac5_arrive_on_an_enemy_that_is_not_waiting_changes_nothing_and_reports() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2.ZERO)
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 8))
	var before: Dictionary = enemy.to_dict()
	watch_signals(enemy)
	assert_false(enemy.arrive(Vector2(1, 1)))
	assert_push_error("arrive refused")
	assert_eq_deep(enemy.to_dict(), before)
	assert_signal_not_emitted(enemy, "arrived")


func test_ac5_arrive_twice_is_refused_the_second_time() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(9, 9))
	var enemy: EnemyLogic = arena.enemies[0]
	watch_signals(enemy)
	assert_true(enemy.arrive(Vector2(1, 1)))
	assert_false(enemy.arrive(Vector2(2, 2)))
	assert_push_error("arrive refused")
	assert_eq(enemy.get_position_tiles(), Vector2(1, 1))
	assert_signal_emit_count(enemy, "arrived", 1)


func test_ac5_arrive_on_an_enemy_killed_while_waiting_is_refused() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(9, 9))
	var enemy: EnemyLogic = arena.enemies[0]
	enemy.get_combat_state().apply_hit(_hit_event(enemy.get_data().max_hp), arena.rules)
	assert_false(enemy.arrive(Vector2(1, 1)))
	assert_push_error("arrive refused")
	assert_eq(enemy.get_state(), EnemyLogic.State.DEAD)


func test_ac5_hold_in_reserve_on_an_aggroed_enemy_changes_nothing_and_reports() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2.ZERO)
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 4))
	arena.ticks(5)
	assert_true(enemy.is_aggroed())
	var before: Dictionary = enemy.to_dict()
	assert_false(enemy.hold_in_reserve())
	assert_push_error("hold_in_reserve refused")
	assert_eq_deep(enemy.to_dict(), before)
	assert_false(enemy.is_waiting())


func test_ac5_hold_in_reserve_on_an_enemy_in_an_attack_changes_nothing_and_reports() -> void:
	var arena: EnemyArena = EnemyArena.new()
	arena.add_player(Vector2.ZERO)
	var enemy: EnemyLogic = arena.add_chaser(Vector2(0, 1.2))
	for _i: int in 200:
		arena.tick()
		if enemy.get_state() == EnemyLogic.State.WINDUP:
			break
	assert_eq(enemy.get_state(), EnemyLogic.State.WINDUP)
	var before: Dictionary = enemy.to_dict()
	assert_false(enemy.hold_in_reserve())
	assert_push_error("hold_in_reserve refused")
	assert_eq_deep(enemy.to_dict(), before)


func test_ac5_hold_in_reserve_on_a_waiting_or_dead_enemy_is_refused_too() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(0, 3))
	var enemy: EnemyLogic = arena.enemies[0]
	assert_false(enemy.hold_in_reserve())
	assert_push_error("hold_in_reserve refused")
	assert_true(enemy.is_waiting())
	enemy.get_combat_state().apply_hit(_hit_event(enemy.get_data().max_hp), arena.rules)
	assert_false(enemy.hold_in_reserve())
	assert_push_error("hold_in_reserve refused")
	assert_eq(enemy.get_state(), EnemyLogic.State.DEAD)


func test_ac5_hold_in_reserve_without_data_reports_and_does_nothing() -> void:
	var enemy: EnemyLogic = EnemyLogic.new()
	assert_false(enemy.hold_in_reserve())
	assert_push_error("hold_in_reserve refused")
	assert_false(enemy.is_waiting())


# --- AC6: snapshots --------------------------------------------------------------------------


func test_ac6_a_snapshot_with_a_waiting_enemy_restores_it_waiting() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(0, 3))
	arena.ticks(30)
	var snapshot: Dictionary = arena.sim.to_dict()
	assert_eq(snapshot["combatants"][&"chaser_1"]["state"], EnemyLogic.State.WAITING)
	var fresh: EnemyArena = EnemyArena.new()
	fresh.add_player(Vector2.ZERO)
	var restored: EnemyLogic = fresh.add_chaser(Vector2(0, 3))  # Awake, as a new room builds it.
	assert_false(restored.is_waiting())
	watch_signals(restored)
	assert_true(fresh.sim.from_dict(snapshot))
	assert_true(restored.is_waiting())
	assert_false(restored.is_alive())
	assert_false(restored.can_be_hit())
	assert_signal_emit_count(restored, "state_restored", 1)
	assert_signal_not_emitted(restored, "arrived")
	assert_eq_deep(fresh.sim.to_dict(), snapshot)
	fresh.ticks(RATE)
	assert_eq(restored.get_state(), EnemyLogic.State.WAITING, "and it goes on waiting")


func test_ac6_a_snapshot_taken_after_it_arrived_restores_it_arrived() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(0, 3))
	var enemy: EnemyLogic = arena.enemies[0]
	arena.ticks(10)
	enemy.arrive(Vector2(8, 0))
	arena.ticks(60)
	var snapshot: Dictionary = arena.sim.to_dict()
	assert_ne(snapshot["combatants"][&"chaser_1"]["state"], EnemyLogic.State.WAITING)
	var fresh: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(0, 3))  # Waiting, as built.
	var restored: EnemyLogic = fresh.enemies[0]
	assert_true(restored.is_waiting())
	assert_true(fresh.sim.from_dict(snapshot))
	assert_false(restored.is_waiting())
	assert_true(restored.is_alive())
	assert_true(restored.is_aggroed())
	assert_eq(restored.get_position_tiles(), enemy.get_position_tiles())
	assert_eq_deep(fresh.sim.to_dict(), snapshot)
	arena.ticks(60)
	fresh.ticks(60)
	assert_eq_deep(fresh.sim.to_dict(), arena.sim.to_dict())  # It plays on the same.


func test_ac6_a_restore_from_chasing_to_waiting_does_not_carry_its_last_step() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(0, 3))
	var waiting_snapshot: Dictionary = arena.sim.to_dict()
	var enemy: EnemyLogic = arena.enemies[0]
	enemy.arrive(Vector2(10, 0))
	arena.ticks(5)
	assert_ne(enemy.get_tick_displacement_px(), Vector2.ZERO, "it was walking")
	assert_true(arena.sim.from_dict(waiting_snapshot))
	var restored_at: Vector2 = enemy.get_position_tiles()
	arena.tick()
	assert_eq(enemy.get_tick_displacement_px(), Vector2.ZERO)
	assert_eq(enemy.get_position_tiles(), restored_at)
	assert_true(enemy.is_waiting())


func test_ac6_an_arrival_right_after_a_restore_from_chasing_carries_no_old_step() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(0, 3))
	var waiting_snapshot: Dictionary = arena.sim.to_dict()
	var enemy: EnemyLogic = arena.enemies[0]
	enemy.arrive(Vector2(10, 0))
	arena.ticks(5)
	assert_ne(enemy.get_tick_displacement_px(), Vector2.ZERO, "it was walking")
	assert_true(arena.sim.from_dict(waiting_snapshot))
	assert_true(enemy.arrive(Vector2(12, 0)))  # Before any tick: the director may do this.
	assert_eq(enemy.get_tick_displacement_px(), Vector2.ZERO)


func test_ac6_a_snapshot_with_an_unknown_state_or_a_waiting_aggroed_one_is_refused() -> void:
	var arena: EnemyArena = _reserve_arena(Vector2.ZERO, Vector2(0, 3))
	var enemy: EnemyLogic = arena.enemies[0]
	var before: Dictionary = enemy.to_dict()
	var unknown: Dictionary = before.duplicate()
	unknown["state"] = EnemyLogic.State.WAITING + 1
	assert_false(enemy.restore_errors(unknown).is_empty())
	var aggroed: Dictionary = before.duplicate()
	aggroed["aggroed"] = true
	assert_false(enemy.restore_errors(aggroed).is_empty())
	assert_true(enemy.restore_errors(before).is_empty())
	enemy.from_dict(unknown)
	assert_push_error("snapshot rejected")
	assert_eq_deep(enemy.to_dict(), before)


func test_ac6_the_new_state_is_appended_and_old_values_keep_their_numbers() -> void:
	assert_eq(EnemyLogic.State.IDLE, 0)
	assert_eq(EnemyLogic.State.DEAD, 6)
	assert_eq(EnemyLogic.State.STAGE_SHIFT, 7)
	assert_eq(EnemyLogic.State.WAITING, 8)
