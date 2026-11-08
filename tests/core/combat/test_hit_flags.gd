extends GutTest
## F-005 T1, C6: the plural hitbox getter, the resolver's order, and the two Hitbox flags,
## with stub hitboxes. AC16's "a sword still hits several targets" is here too.


## A stub that owns hitboxes after its own sector, like a projectile owner.
class MultiStub:
	extends StubCombatant
	var extra: Array[Hitbox] = []

	func _build_extra_hitboxes() -> Array[Hitbox]:
		return extra


var _sim: CombatSim
var _landed: Array[HitEvent] = []


func before_each() -> void:
	_sim = CombatSim.new()
	_sim.setup(120, Tunables.player_combat)
	_landed = []


func test_get_live_hitboxes_is_the_single_hitbox_or_nothing() -> void:
	var stub: StubCombatant = StubCombatant.make(&"a", Combatant.Team.ENEMY, Vector2.ZERO)
	assert_eq(stub.get_live_hitboxes().size(), 0, "no hitbox")
	var hitbox: Hitbox = stub.arm()
	assert_eq(stub.get_live_hitboxes(), [hitbox] as Array[Hitbox])


func test_get_live_hitboxes_keeps_the_hitstop_rule_for_the_own_sector_only() -> void:
	var stub: MultiStub = _multi(&"a", Vector2.ZERO)
	stub.arm()
	var bolt: Hitbox = _bolt(stub, Vector2(0, 3))
	stub.extra = [bolt]
	_give_hitstop(stub)
	assert_null(stub.get_live_hitbox(), "the sector pauses")
	assert_eq(stub.get_live_hitboxes(), [bolt] as Array[Hitbox], "the extra one never does")


func test_the_resolver_goes_attacker_then_its_hitboxes_then_targets() -> void:
	var first: MultiStub = _multi(&"first", Vector2(0, -1))
	var sector: Hitbox = first.arm(Vector2.DOWN, 3.0)
	var bolt: Hitbox = _bolt(first, Vector2(0, 0))
	first.extra = [bolt]
	var target_a: StubCombatant = _target(&"target_a", Vector2(0, 0))
	var target_b: StubCombatant = _target(&"target_b", Vector2(0.2, 0))
	var candidates: Array[HitCandidate] = HitResolver.new().find_candidates(
		[first, target_a, target_b] as Array[Combatant]
	)
	var order: Array = []
	for candidate: HitCandidate in candidates:
		order.append([candidate.hitbox == sector, candidate.target.get_combat_id()])
	assert_eq_deep(
		order,
		[[true, &"target_a"], [true, &"target_b"], [false, &"target_a"], [false, &"target_b"]]
	)


func test_single_target_lands_on_the_first_registered_only() -> void:
	for swap: bool in [false, true]:
		before_each()
		var owner: MultiStub = _multi(&"caster", Vector2(5, 5))
		owner.extra = [_bolt(owner, Vector2.ZERO)]
		_sim.register(owner)
		var ids: Array[StringName] = [&"p1", &"p2"]
		if swap:
			ids.reverse()
		var targets: Array[StubCombatant] = []
		for id: StringName in ids:
			var target: StubCombatant = _target(id, Vector2(0, 0.1))
			targets.append(target)
			_sim.register(target)
		_listen(owner)
		_sim.tick(1.0 / 120.0)
		assert_eq(_landed.size(), 1, "one hit")
		assert_eq(_landed[0].target_id, ids[0], "the first registered: %s" % ids[0])
		assert_eq(targets[1].get_combat_state().get_hitstop_remaining(), 0.0, "the other untouched")
		assert_eq_deep(owner.extra[0].hit_ids, [ids[0]] as Array[StringName])


func test_single_target_skips_only_after_a_hit_has_landed() -> void:
	var owner: MultiStub = _multi(&"caster", Vector2(5, 5))
	owner.extra = [_bolt(owner, Vector2.ZERO)]
	_sim.register(owner)
	var protected: StubCombatant = _target(&"p1", Vector2(0, 0.1))
	protected.get_combat_state().setup(100, true)
	protected.get_combat_state().apply_hit(_event(), Tunables.player_combat)  # Hurt i-frames.
	var open: StubCombatant = _target(&"p2", Vector2(0, -0.1))
	_sim.register(protected)
	_sim.register(open)
	_listen(owner)
	_sim.tick(1.0 / 120.0)
	assert_eq(_landed.size(), 1)
	assert_eq(_landed[0].target_id, &"p2", "the skipped one isn't a landed hit")
	assert_false(owner.extra[0].has_hit(&"p1"), "and isn't marked")


func test_a_sword_still_hits_several_targets_at_one_contact() -> void:
	var sword: StubCombatant = StubCombatant.make(&"player", Combatant.Team.PLAYER, Vector2.ZERO)
	sword.arm(Vector2.DOWN, 1.4)
	_sim.register(sword)
	for id: StringName in [&"e1", &"e2", &"e3"]:
		var enemy: StubCombatant = StubCombatant.make(id, Combatant.Team.ENEMY, Vector2(0, 1))
		enemy.hurtbox_radius = 0.3
		_sim.register(enemy)
	_listen(sword)
	_sim.tick(1.0 / 120.0)
	assert_eq(_landed.size(), 3)
	assert_almost_eq(
		sword.get_combat_state().get_hitstop_remaining(), 0.05, 0.000001, "one hitstop"
	)


func test_attacker_hitstop_false_leaves_the_attacker_alone_and_still_signals() -> void:
	var owner: MultiStub = _multi(&"caster", Vector2(5, 5))
	owner.extra = [_bolt(owner, Vector2.ZERO)]
	_sim.register(owner)
	var target: StubCombatant = _target(&"p1", Vector2(0, 0.1))
	_sim.register(target)
	_listen(owner)
	watch_signals(owner.get_combat_state())
	_sim.tick(1.0 / 120.0)
	assert_signal_emit_count(owner.get_combat_state(), "hit_landed", 1)
	assert_eq(owner.get_combat_state().get_hitstop_remaining(), 0.0, "no hitstop for the owner")
	assert_almost_eq(target.get_combat_state().get_hitstop_remaining(), 0.05, 0.000001, "target")


func test_attacker_hitstop_false_never_shortens_a_running_hitstop() -> void:
	var owner: MultiStub = _multi(&"caster", Vector2(5, 5))
	owner.extra = [_bolt(owner, Vector2.ZERO)]
	_give_hitstop(owner)
	var before: float = owner.get_combat_state().get_hitstop_remaining()
	owner.get_combat_state().apply_landed(_event(), Tunables.player_combat, false)
	assert_eq(owner.get_combat_state().get_hitstop_remaining(), before)


func test_the_defaults_are_the_old_behavior() -> void:
	var hitbox: Hitbox = Hitbox.new()
	assert_false(hitbox.single_target)
	assert_true(hitbox.attacker_hitstop)


func test_knockback_along_the_direction_for_a_projectile_hitbox() -> void:
	var owner: MultiStub = _multi(&"caster", Vector2(5, 5))
	var bolt: Hitbox = _bolt(owner, Vector2.ZERO)
	bolt.direction = Vector2.UP
	var target: StubCombatant = _target(&"p1", Vector2(0.3, 0))
	var candidate: HitCandidate = HitCandidate.new(owner, target, bolt, target.get_hurtbox())
	assert_eq(HitEvent.from_candidate(candidate, 1.0).direction, Vector2.UP)


func _multi(id: StringName, position: Vector2) -> MultiStub:
	var stub: MultiStub = MultiStub.new()
	stub._combat_id = id
	stub._team = Combatant.Team.ENEMY
	stub._position = position
	return stub


func _target(id: StringName, position: Vector2) -> StubCombatant:
	var target: StubCombatant = StubCombatant.make(id, Combatant.Team.PLAYER, position)
	target.hurtbox_radius = 0.35
	return target


## A projectile-like hitbox: a 0.25-tile circle, single target, no attacker hitstop.
func _bolt(owner: Combatant, position: Vector2) -> Hitbox:
	var hitbox: Hitbox = Hitbox.new()
	hitbox.owner_id = owner.get_combat_id()
	hitbox.team = owner.get_team()
	hitbox.origin = position
	hitbox.direction = Vector2.DOWN
	hitbox.arc_angle_deg = 360.0
	hitbox.range_tiles = 0.25
	hitbox.damage = 18
	hitbox.knockback_tiles = 0.5
	hitbox.knockback_from_center = false
	hitbox.single_target = true
	hitbox.attacker_hitstop = false
	return hitbox


func _event() -> HitEvent:
	var event: HitEvent = HitEvent.new()
	event.damage = 1
	event.direction = Vector2.DOWN
	return event


func _give_hitstop(combatant: Combatant) -> void:
	combatant.get_combat_state().apply_landed(_event(), Tunables.player_combat)


func _listen(attacker: Combatant) -> void:
	attacker.get_combat_state().hit_landed.connect(func(e: HitEvent) -> void: _landed.append(e))
