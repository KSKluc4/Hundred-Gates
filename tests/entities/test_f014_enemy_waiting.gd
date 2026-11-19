extends F004SceneTest
## F-014 T2: how the Enemy node shows the waiting state (C11, node part: AC16, AC18, AC19). The
## real chaser scene, with Chaser2 held in reserve and the other two parked far from the player.
## Nothing here uses spawn_fresh(): its reset would take the enemy out of reserve.

const ENEMY_LAYER: int = 4
const ARRIVAL_TILES: Vector2 = Vector2(10, 6)
const WALK_TICKS: int = 30
const QUIET_TICKS: int = 60
const PROBE_RADIUS_PX: float = 4.0
const PROBE_RUN_PX: float = 48.0

var _probe: CharacterBody2D


func before_each() -> void:
	super()
	Engine.physics_ticks_per_second = 120


func after_each() -> void:
	super()


## Chaser2 in reserve at its scene position, the other two out of everyone's reach.
func _in_reserve() -> void:
	_chasers[0].position = FAR_WEST
	_chasers[2].position = FAR_EAST
	_chasers[1].starts_in_reserve = true


func _with_dying_pair() -> void:
	_chasers[0].position = CENTRE
	_chasers[0].hide_when_dead = true
	_chasers[1].position = FAR_WEST
	_chasers[2].position = CENTRE + Vector2(0, 64)
	_chasers[2].hide_when_dead = false


func _reserve_node() -> Enemy:
	return _chasers[1]


func _label_of(enemy: Enemy) -> Label:
	return enemy.get_node("DebugLabel") as Label


## A probe that can only collide with enemy bodies, started `PROBE_RUN_PX` left of `target`.
## Returns what move_and_collide() reports when it runs right through the target's place.
func _run_probe_through(target: Vector2) -> KinematicCollision2D:
	_probe = CharacterBody2D.new()
	_probe.collision_layer = 0
	_probe.collision_mask = ENEMY_LAYER
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = PROBE_RADIUS_PX
	shape.shape = circle
	_probe.add_child(shape)
	_probe.position = target - Vector2(PROBE_RUN_PX, 0)
	_scene.add_child(_probe)
	await get_tree().physics_frame
	var hit: KinematicCollision2D = _probe.move_and_collide(Vector2(2 * PROBE_RUN_PX, 0))
	_scene.remove_child(_probe)
	_probe.free()
	return hit


func _enemy_bodies_at(point: Vector2) -> int:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = ENEMY_LAYER
	return _scene.get_world_2d().direct_space_state.intersect_point(query).size()


func _body_and_logic_agree(enemy: Enemy) -> void:
	assert_eq(enemy.global_position, enemy.logic.get_position_px(), "the body is on the logic")


# --- starts_in_reserve ------------------------------------------------------------------------


func test_c11_a_node_that_starts_in_reserve_is_waiting_hidden_and_without_collision() -> void:
	await spawn(_in_reserve)
	var enemy: Enemy = _reserve_node()
	assert_true(enemy.logic.is_waiting())
	assert_false(enemy.is_body_drawn(), "no shape, bar or label")
	assert_false(_label_of(enemy).visible, "not even the label")
	assert_eq(enemy.collision_layer, 0)
	assert_eq(enemy.collision_mask, 0)
	assert_eq(enemy.logic.get_position_px(), enemy.global_position)
	await wait_process_frames(2)
	assert_false(enemy.did_draw_body(), "and its draw pass drew nothing")
	assert_true(_chasers[0].did_draw_body(), "the control: an enemy that is there is drawn")


func test_c11_the_other_nodes_are_drawn_and_solid_as_ever() -> void:
	await spawn(_in_reserve)
	for index: int in [0, 2]:
		var enemy: Enemy = _chasers[index]
		assert_false(enemy.starts_in_reserve, "false by default")
		assert_false(enemy.hide_when_dead, "false by default")
		assert_false(enemy.logic.is_waiting())
		assert_true(enemy.is_body_drawn())
		assert_true(_label_of(enemy).visible)
		assert_eq(enemy.collision_layer, ENEMY_LAYER)
		assert_eq(enemy.collision_mask, 5)


func test_c11_a_body_passes_through_the_place_of_a_waiting_enemy() -> void:
	await spawn(_in_reserve)
	var waiting_at: Vector2 = _reserve_node().global_position
	await get_tree().physics_frame
	assert_eq(_enemy_bodies_at(waiting_at), 0, "nothing solid stands there")
	assert_null(await _run_probe_through(waiting_at), "and a body runs right through")


func test_c11_the_same_probe_is_stopped_by_an_enemy_that_is_there() -> void:
	await spawn(_in_reserve)
	var standing_at: Vector2 = _chasers[2].global_position
	await get_tree().physics_frame
	assert_eq(_enemy_bodies_at(standing_at), 1, "the control: an enemy is solid")
	assert_not_null(await _run_probe_through(standing_at))


func test_c11_a_waiting_node_does_not_move_with_a_player_in_reach_of_nothing() -> void:
	await spawn(_in_reserve)
	var enemy: Enemy = _reserve_node()
	var start: Vector2 = enemy.global_position
	await run_ticks(QUIET_TICKS)
	assert_eq(enemy.global_position, start)
	assert_true(enemy.logic.is_waiting())
	assert_false(enemy.logic.is_aggroed())


# --- arriving ---------------------------------------------------------------------------------


func test_c11_on_arrival_the_body_is_on_the_logics_position_drawn_and_solid() -> void:
	await spawn(_in_reserve)
	var enemy: Enemy = _reserve_node()
	var waiting_at: Vector2 = enemy.global_position
	assert_true(enemy.logic.arrive(ARRIVAL_TILES))
	assert_eq(enemy.global_position, Units.vector_tiles_to_px(ARRIVAL_TILES))
	_body_and_logic_agree(enemy)
	assert_ne(enemy.global_position, waiting_at)
	assert_true(enemy.is_body_drawn())
	assert_true(_label_of(enemy).visible)
	assert_eq(enemy.collision_layer, ENEMY_LAYER)
	assert_eq(enemy.collision_mask, 5)
	await get_tree().physics_frame
	assert_eq(_enemy_bodies_at(Units.vector_tiles_to_px(ARRIVAL_TILES)), 1, "and it is solid")


func test_c11_after_arriving_the_runner_does_not_pull_it_back_to_where_it_waited() -> void:
	await spawn(_in_reserve)
	var enemy: Enemy = _reserve_node()
	enemy.logic.arrive(ARRIVAL_TILES)
	await run_ticks(WALK_TICKS)
	var from_arrival: float = enemy.logic.get_position_tiles().distance_to(ARRIVAL_TILES)
	assert_gt(from_arrival, 0.5, "it walked: it is aggroed and the player is near enough")
	assert_lt(from_arrival, 2.5, "and from where it arrived, not from where it waited")
	_body_and_logic_agree(enemy)


# --- snapshots, both ways ---------------------------------------------------------------------


func test_c11_a_restore_to_waiting_hides_it_again_and_its_body_does_not_move() -> void:
	await spawn(_in_reserve)
	var enemy: Enemy = _reserve_node()
	var waiting_snapshot: Dictionary = _runner.take_snapshot()
	var waiting_at: Vector2 = enemy.global_position
	enemy.logic.arrive(ARRIVAL_TILES)
	await run_ticks(WALK_TICKS)  # Walking when the restore comes.
	assert_true(enemy.is_body_drawn())
	assert_true(_runner.restore_snapshot(waiting_snapshot))
	assert_true(enemy.logic.is_waiting())
	assert_false(enemy.is_body_drawn())
	assert_false(_label_of(enemy).visible)
	assert_eq(enemy.collision_layer, 0)
	assert_eq(enemy.collision_mask, 0)
	assert_eq(enemy.global_position, waiting_at, "back where it waited")
	_body_and_logic_agree(enemy)
	await run_ticks(QUIET_TICKS)
	assert_eq(enemy.global_position, waiting_at, "and it does not move in the next 60 ticks")
	assert_eq(enemy.logic.get_position_px(), waiting_at)
	assert_true(enemy.logic.is_waiting())
	await get_tree().physics_frame
	assert_eq(_enemy_bodies_at(waiting_at), 0)
	assert_eq(_enemy_bodies_at(Units.vector_tiles_to_px(ARRIVAL_TILES)), 0)


func test_c11_a_restore_to_arrived_shows_it_on_the_logics_position() -> void:
	await spawn(_in_reserve)
	var enemy: Enemy = _reserve_node()
	var waiting_snapshot: Dictionary = _runner.take_snapshot()
	enemy.logic.arrive(ARRIVAL_TILES)
	await run_ticks(WALK_TICKS)
	var arrived_snapshot: Dictionary = _runner.take_snapshot()
	var arrived_at: Vector2 = enemy.logic.get_position_px()
	assert_true(_runner.restore_snapshot(waiting_snapshot))
	assert_false(enemy.is_body_drawn())
	watch_signals(enemy.logic)
	assert_true(_runner.restore_snapshot(arrived_snapshot))
	assert_signal_not_emitted(
		enemy.logic, "arrived", "a restore never says arrived: the state does"
	)
	assert_false(enemy.logic.is_waiting())
	assert_true(enemy.is_body_drawn())
	assert_true(_label_of(enemy).visible)
	assert_eq(enemy.collision_layer, ENEMY_LAYER)
	assert_eq(enemy.collision_mask, 5)
	assert_eq(enemy.global_position, arrived_at)
	_body_and_logic_agree(enemy)
	await get_tree().physics_frame
	assert_eq(_enemy_bodies_at(arrived_at), 1)


func test_c11_a_restore_made_on_the_sim_alone_is_still_right_after_one_tick() -> void:
	await spawn(_in_reserve)
	var enemy: Enemy = _reserve_node()
	var waiting_snapshot: Dictionary = _runner.take_snapshot()
	var waiting_at: Vector2 = enemy.global_position
	enemy.logic.arrive(ARRIVAL_TILES)
	await run_ticks(WALK_TICKS)
	assert_true(_runner.get_sim().from_dict(waiting_snapshot))  # The glue's half is not done.
	await run_ticks(QUIET_TICKS)
	assert_true(enemy.logic.is_waiting())
	assert_eq(enemy.logic.get_position_px(), waiting_at, "the hidden body never drags the logic")
	assert_eq(enemy.global_position, waiting_at)
	assert_eq(enemy.collision_layer, 0)


# --- hide_when_dead ---------------------------------------------------------------------------


func _kill(enemy: Enemy) -> void:
	var event: HitEvent = HitEvent.new()
	event.attacker_id = &"test"
	event.target_id = enemy.combat_id
	event.damage = enemy.logic.get_combat_state().get_hp()
	event.direction = Vector2.RIGHT
	enemy.logic.get_combat_state().apply_hit(event, Tunables.player_combat)


func test_c11_a_dead_enemy_with_hide_when_dead_has_no_shape_bar_or_label_but_its_number() -> void:
	await spawn(_with_dying_pair)
	var enemy: Enemy = _chasers[0]
	assert_true(enemy.hide_when_dead)
	assert_true(enemy.is_body_drawn(), "while it lives it is drawn")
	_kill(enemy)
	assert_eq(enemy.logic.get_state(), EnemyLogic.State.DEAD)
	assert_false(enemy.is_body_drawn(), "shape, bar and label are gone")
	assert_false(_label_of(enemy).visible)
	assert_eq(enemy.collision_layer, 0)
	var numbers: DamageNumbers = enemy.get_damage_numbers()
	assert_eq(numbers.get_labels().size(), 1, "the killing hit's number")
	assert_eq(numbers.get_labels()[0].text, "50")
	assert_true(enemy.is_visible_in_tree(), "the node is not hidden: its numbers are its children")
	assert_true(numbers.get_labels()[0].is_visible_in_tree())
	await wait_process_frames(2)
	assert_eq(numbers.get_labels().size(), 1, "and it is still there a frame later")
	assert_true(numbers.get_labels()[0].is_visible_in_tree(), "still shown a frame later")
	assert_true(enemy.is_visible_in_tree())
	assert_false(_label_of(enemy).visible, "nor does a refresh bring the label back")
	assert_false(enemy.did_draw_body(), "the draw pass drew no body")


func test_c11_a_dead_enemy_without_hide_when_dead_is_drawn_exactly_as_before() -> void:
	await spawn(_with_dying_pair)
	var enemy: Enemy = _chasers[2]
	assert_false(enemy.hide_when_dead)
	_kill(enemy)
	assert_eq(enemy.logic.get_state(), EnemyLogic.State.DEAD)
	assert_true(enemy.is_body_drawn(), "shape, bar and label, as today")
	assert_true(_label_of(enemy).visible)
	assert_eq(enemy.get_body_color(), enemy.dead_color)
	assert_eq(enemy.collision_layer, 0, "and its body is as passable as ever")
	await wait_process_frames(2)
	assert_true(_label_of(enemy).visible)
	assert_true(enemy.did_draw_body(), "the draw pass still draws the corpse")
	assert_eq(enemy.get_damage_numbers().get_labels().size(), 1)


func test_c11_hide_when_dead_alone_does_not_hide_a_living_enemy() -> void:
	await spawn(_with_dying_pair)
	var enemy: Enemy = _chasers[0]
	await wait_process_frames(2)
	assert_true(enemy.is_body_drawn())
	assert_true(_label_of(enemy).visible)


# --- the debug draw ---------------------------------------------------------------------------


func test_c11_the_debug_draw_has_no_ring_for_a_waiting_enemy() -> void:
	await spawn(_in_reserve)
	assert_eq(_debug_draw.get_hurtboxes().size(), 3, "the player and two enemies, not the third")
	var rings: Array[Vector2] = []
	for hurtbox: Hurtbox in _debug_draw.get_hurtboxes():
		rings.append(hurtbox.position)
	assert_false(rings.has(_reserve_node().logic.get_position_tiles()))


func test_c11_the_debug_draw_has_its_ring_again_once_it_arrives() -> void:
	await spawn(_in_reserve)
	_reserve_node().logic.arrive(ARRIVAL_TILES)
	assert_eq(_debug_draw.get_hurtboxes().size(), 4)


func test_c11_a_dead_enemys_ring_stays_where_there_is_no_director() -> void:
	await spawn(_with_dying_pair)
	_kill(_chasers[0])
	assert_false(CombatDebugDraw.has_director(_runner.get_sim()))
	assert_eq(_debug_draw.get_hurtboxes().size(), 4, "today: a corpse keeps its ring")


func test_c11_a_dead_enemys_ring_goes_in_a_sim_that_has_a_director() -> void:
	await spawn(_with_dying_pair)
	_kill(_chasers[0])
	var combatants: Array[Combatant] = _runner.get_sim().get_combatants()
	assert_eq(CombatDebugDraw.hurtboxes_for(combatants, false).size(), 4)
	assert_eq(CombatDebugDraw.hurtboxes_for(combatants, true).size(), 3, "four, less the dead")
	var ids: Array[StringName] = []
	for hurtbox: Hurtbox in CombatDebugDraw.hurtboxes_for(combatants, true):
		ids.append(hurtbox.owner_id)
	assert_false(ids.has(&"chaser_1"))
	assert_true(ids.has(&"player_1"), "the player's ring is never skipped")
