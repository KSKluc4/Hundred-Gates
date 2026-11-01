extends GutTest
## F-003/C16, AC17: candidates, in order, with no state of their own.

var _resolver: HitResolver


func before_each() -> void:
	_resolver = HitResolver.new()


func test_a_live_hitbox_over_an_enemy_is_a_candidate() -> void:
	var attacker: StubCombatant = _player(&"p", Vector2.ZERO)
	var target: StubCombatant = _enemy(&"d", Vector2(0, 1))
	attacker.arm()
	var candidates: Array[HitCandidate] = _resolver.find_candidates([attacker, target])
	assert_eq(candidates.size(), 1)
	assert_eq(candidates[0].attacker, attacker)
	assert_eq(candidates[0].target, target)


func test_no_live_hitbox_means_no_candidates() -> void:
	var attacker: StubCombatant = _player(&"p", Vector2.ZERO)
	var target: StubCombatant = _enemy(&"d", Vector2(0, 1))
	assert_eq(_resolver.find_candidates([attacker, target]).size(), 0)


func test_c9_own_team_is_never_a_candidate() -> void:
	var attacker: StubCombatant = _player(&"p", Vector2.ZERO)
	var friend: StubCombatant = _player(&"q", Vector2(0, 1))
	attacker.arm()
	assert_eq(_resolver.find_candidates([attacker, friend]).size(), 0)


func test_ac17_a_hitbox_never_touches_its_owner() -> void:
	var attacker: StubCombatant = _player(&"p", Vector2.ZERO)
	attacker.arm()
	assert_eq(_resolver.find_candidates([attacker]).size(), 0)


func test_c8_a_marked_hurtbox_is_not_a_candidate() -> void:
	var attacker: StubCombatant = _player(&"p", Vector2.ZERO)
	var target: StubCombatant = _enemy(&"d", Vector2(0, 1))
	attacker.arm().mark_hit(&"d")
	assert_eq(_resolver.find_candidates([attacker, target]).size(), 0)


func test_out_of_range_is_not_a_candidate() -> void:
	var attacker: StubCombatant = _player(&"p", Vector2.ZERO)
	var target: StubCombatant = _enemy(&"d", Vector2(0, 5))
	attacker.arm()
	assert_eq(_resolver.find_candidates([attacker, target]).size(), 0)


func test_the_hurtbox_radius_counts() -> void:
	var attacker: StubCombatant = _player(&"p", Vector2.ZERO)
	var target: StubCombatant = _enemy(&"d", Vector2(0, 1.8))
	attacker.arm()
	assert_eq(_resolver.find_candidates([attacker, target]).size(), 1)
	target.hurtbox_radius = 0.1
	assert_eq(_resolver.find_candidates([attacker, target]).size(), 0)


func test_c16_order_is_attacker_then_target_registration_order() -> void:
	var first: StubCombatant = _player(&"p1", Vector2.ZERO)
	var second: StubCombatant = _player(&"p2", Vector2.ZERO)
	var near: StubCombatant = _enemy(&"d1", Vector2(0, 1))
	var far: StubCombatant = _enemy(&"d2", Vector2(0, 1.2))
	first.arm()
	second.arm()
	var candidates: Array[HitCandidate] = _resolver.find_candidates([first, second, far, near])
	var order: Array[StringName] = []
	for candidate: HitCandidate in candidates:
		order.append(candidate.attacker.get_combat_id())
		order.append(candidate.target.get_combat_id())
	assert_eq_deep(
		order, [&"p1", &"d2", &"p1", &"d1", &"p2", &"d2", &"p2", &"d1"] as Array[StringName]
	)


func test_the_resolver_marks_nothing_so_the_same_contact_repeats() -> void:
	var attacker: StubCombatant = _player(&"p", Vector2.ZERO)
	var target: StubCombatant = _enemy(&"d", Vector2(0, 1))
	attacker.arm()
	assert_eq(_resolver.find_candidates([attacker, target]).size(), 1)
	assert_eq(_resolver.find_candidates([attacker, target]).size(), 1)


func test_ac12_event_direction_is_attacker_to_target_center() -> void:
	var attacker: StubCombatant = _player(&"p", Vector2.ZERO)
	var target: StubCombatant = _enemy(&"d", Vector2(1, 1))
	attacker.arm(Vector2.RIGHT)
	var event: HitEvent = _event_for(attacker, target)
	assert_almost_eq(event.direction, Vector2(1, 1).normalized(), Vector2(0.0001, 0.0001))


func test_ac12_event_direction_falls_back_to_the_attack_when_centers_match() -> void:
	var attacker: StubCombatant = _player(&"p", Vector2.ZERO)
	var target: StubCombatant = _enemy(&"d", Vector2.ZERO)
	attacker.arm(Vector2.LEFT)
	assert_eq(_event_for(attacker, target).direction, Vector2.LEFT)


func test_ac12_a_fixed_direction_ignores_the_centers() -> void:
	var attacker: StubCombatant = _player(&"p", Vector2.ZERO)
	var target: StubCombatant = _enemy(&"d", Vector2(1, 0))
	attacker.arm(Vector2.DOWN).knockback_from_center = false
	var hitbox: Hitbox = attacker.live_hitbox
	hitbox.arc_angle_deg = 360.0
	assert_eq(_event_for(attacker, target).direction, Vector2.DOWN)


func test_event_carries_the_ids_and_hit_values() -> void:
	var attacker: StubCombatant = _player(&"p", Vector2.ZERO)
	var target: StubCombatant = _enemy(&"d", Vector2(0, 1))
	var hitbox: Hitbox = attacker.arm()
	hitbox.damage = 22
	hitbox.is_finisher = true
	hitbox.knockback_tiles = 1.2
	var event: HitEvent = _event_for(attacker, target, 0.5)
	assert_eq(event.attacker_id, &"p")
	assert_eq(event.target_id, &"d")
	assert_eq(event.damage, 22)
	assert_true(event.is_finisher)
	assert_almost_eq(event.knockback_tiles, 0.6, 0.00001, "the target's scale applies")


func _event_for(attacker: Combatant, target: Combatant, scale: float = 1.0) -> HitEvent:
	var candidates: Array[HitCandidate] = _resolver.find_candidates([attacker, target])
	return HitEvent.from_candidate(candidates[0], scale)


func _player(id: StringName, position: Vector2) -> StubCombatant:
	return StubCombatant.make(id, Combatant.Team.PLAYER, position)


func _enemy(id: StringName, position: Vector2) -> StubCombatant:
	return StubCombatant.make(id, Combatant.Team.ENEMY, position)
