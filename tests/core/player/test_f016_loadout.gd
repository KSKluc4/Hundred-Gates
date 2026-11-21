# gdlint:disable=max-public-methods
extends GutTest
## F-016 T3 (C8, AC5-AC7 motor parts): the motor reads the loadout. The sword changes the damage of
## each hit, the max HP and the dash cooldown, and nothing else; it is setup data, never saved.

const Combat: GDScript = preload("res://tests/core/combat/combat_harness.gd")
const Harness: GDScript = preload("res://tests/core/player/motor_harness.gd")
const THIRTIETHS_PER_FIGHT: int = 75
## The shipped warrior's chain: 10/10/22.
const CLASS_HITS: Array[int] = [10, 10, 22]
## Hits that differ from the class's at every position (weights 9, 9, 28 at damage 46).
const SWORD_HITS: Array[int] = [9, 9, 28]

var _rules: ItemTunables
var _attack_presses: Array = []
var _dash_presses: Array = []
var _moves: Dictionary = {}


func before_each() -> void:
	_rules = ItemFixtures.rules()
	_attack_presses = range(0, 25) + range(45, 61)
	_dash_presses = [30, 50]
	_moves = {36: Vector2.RIGHT, 37: Vector2.RIGHT, 38: Vector2.RIGHT}


# --- AC5: no sword, a null sword and the starter sword are the same game -------------------------


func test_ac5_a_motor_with_no_sword_reads_the_classes_values() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	var loadout: PlayerLoadout = motor.get_loadout()
	assert_not_null(loadout)
	assert_null(loadout.get_sword())
	assert_eq(loadout.get_max_hp(), 100)
	assert_eq(motor.get_combat_state().get_max_hp(), 100)
	assert_eq(motor.get_combat_state().get_hp(), 100)
	for index: int in CLASS_HITS.size():
		assert_eq(loadout.get_hit_damage(index), CLASS_HITS[index], "hit %d" % index)


func test_ac5_three_fights_give_identical_snapshots_at_every_tick() -> void:
	for rate: int in Combat.RATES:
		var plain: CombatArena = CombatArena.new().build()
		var null_sword: CombatArena = CombatArena.new().build()
		null_sword.player.set_sword(null, _rules)
		var starter: CombatArena = CombatArena.new()
		starter.player.set_sword(ItemFixtures.starter(), _rules)  # before setup() (C8)
		starter.build()
		var arenas: Array[CombatArena] = [plain, null_sword, starter]
		for tick_index: int in THIRTIETHS_PER_FIGHT * (rate / 30):
			for arena: CombatArena in arenas:
				_tick(arena, rate, tick_index)
			var expected: Dictionary = plain.sim.to_dict()
			var motor_state: Dictionary = plain.player.to_dict()
			if null_sword.sim.to_dict() != expected or null_sword.player.to_dict() != motor_state:
				fail_test(
					"%d Hz tick %d: set_sword(null) differs from no call" % [rate, tick_index]
				)
				return
			if starter.sim.to_dict() != expected or starter.player.to_dict() != motor_state:
				fail_test("%d Hz tick %d: the starter sword differs" % [rate, tick_index])
				return
		assert_gte(plain.events.size(), 3, "%d Hz: the fight landed hits" % rate)
		assert_gte(plain.dash_times.size(), 1, "%d Hz: the fight had a dash" % rate)
		assert_eq(_event_damages(null_sword), _event_damages(plain))
		assert_eq(_event_damages(starter), _event_damages(plain))
		assert_eq(
			starter.dummy.get_combat_state().get_hp(), plain.dummy.get_combat_state().get_hp()
		)


# --- AC6: the sword's damages, and nothing else of the hit ---------------------------------------


func test_ac6_each_hit_takes_the_swords_damage_off_the_enemy() -> void:
	for rate: int in Combat.RATES:
		for before_setup: bool in [true, false]:
			var arena: CombatArena = _arena_with(_heavy_sword(), before_setup)
			var lost: Array[int] = _enemy_hp_lost_per_hit(arena, rate, 3)
			assert_eq(lost, SWORD_HITS, "%d Hz, set before setup: %s" % [rate, before_setup])
			assert_eq(
				_event_damages(arena).slice(0, 3),
				SWORD_HITS,
				"%d Hz events %s" % [rate, before_setup]
			)


func test_ac6_the_chain_restarts_with_the_swords_first_hit() -> void:
	var arena: CombatArena = _arena_with(_heavy_sword(), false)
	var lost: Array[int] = _enemy_hp_lost_per_hit(arena, 30, 4)
	assert_eq(lost, [9, 9, 28, 9])


func test_ac6_the_live_hitbox_carries_the_swords_damage() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	motor.set_sword(_heavy_sword(), _rules)
	assert_eq(_hitbox_damages(motor, 3), SWORD_HITS)


func test_ac6_windup_active_recovery_arc_range_and_knockback_are_the_classes() -> void:
	var arena: CombatArena = _arena_with(_heavy_sword(), true)
	var latched: Dictionary = {}
	for thirtieth: int in 60:
		arena.play(30, thirtieth, thirtieth + 1, _attack_presses, [], {}, Vector2.DOWN)
		var attack: Dictionary = arena.player.get_attack_chain().to_dict()["attack"]
		if not attack.is_empty() and not latched.has(attack["id"]):
			latched[attack["id"]] = attack
	assert_eq(latched.size(), 3, "all three hits were latched")
	for index: int in arena.class_data.attack_chain.size():
		var own: AttackData = arena.class_data.attack_chain[index]
		var seen: Dictionary = latched[own.id]
		for key: String in AttackData.SNAPSHOT_KEYS:
			if key == "damage":
				assert_eq(seen[key], SWORD_HITS[index], "%s damage is the sword's" % own.id)
			else:
				assert_eq(seen[key], own.get(key), "%s %s is the class's" % [own.id, key])


func test_ac6_the_shared_class_and_attack_resources_are_never_written() -> void:
	var shared: ClassData = load(Tunables.WARRIOR_PATH)
	var before: Dictionary = _resource_state(shared)
	# Harness.warrior() copies the class but shares its three AttackData resources with `shared`.
	var motor: PlayerMotor = Harness.motor_with()
	motor.set_sword(_heavy_sword(), _rules)
	assert_eq(_hitbox_damages(motor, 3), SWORD_HITS)
	motor.set_sword(ItemFixtures.make_sword(&"vit", 40, SwordData.Kind.VITALITY, [], 8), _rules)
	assert_eq(motor.get_combat_state().get_max_hp(), 108)
	var arena: CombatArena = _arena_with(_heavy_sword(), true)
	var arena_class_before: Dictionary = _resource_state(arena.class_data)
	_enemy_hp_lost_per_hit(arena, 30, 3)
	assert_eq(_resource_state(shared), before, "the cached warrior")
	assert_eq(_resource_state(arena.class_data), arena_class_before, "the arena's class")
	assert_eq(shared.attack_chain[0].damage, 10)
	assert_eq(shared.attack_chain[2].damage, 22)
	assert_eq(shared.max_hp, 100)


func test_ac6_the_chain_start_writes_the_damage_into_its_own_copy_only() -> void:
	var chain: Array[AttackData] = _chain()
	var attacks: AttackChain = AttackChain.new()
	attacks.start(chain, Vector2.DOWN, 77)
	assert_eq(attacks.to_dict()["attack"]["damage"], 77)
	assert_eq(chain[0].damage, 10, "the shared hit is untouched")
	attacks.reset()
	attacks.start(chain, Vector2.DOWN)
	assert_eq(attacks.to_dict()["attack"]["damage"], 10, "no argument: the attack's own damage")
	attacks.reset()
	attacks.start(chain, Vector2.DOWN, -1)
	assert_eq(attacks.to_dict()["attack"]["damage"], 10, "negative: the attack's own damage")


func test_ac6_the_chain_says_which_hit_it_is_about_to_start() -> void:
	var chain: Array[AttackData] = _chain()
	var running: AttackChain = AttackChain.new()
	var order: Array[int] = []
	for _i: int in 5:
		var index: int = running.get_start_index(chain.size())
		order.append(index)
		running.start(chain, Vector2.DOWN)
		assert_eq(running.get_attack_id(), chain[index].id, "start() latches the hit it announced")
	assert_eq(order, [0, 1, 2, 0, 1], "the index follows the chain and wraps")
	assert_eq(running.get_start_index(1), 0, "an index past a shorter chain starts it over")
	running.reset()
	assert_eq(running.get_start_index(chain.size()), 0, "a reset chain starts at hit 0")


# --- AC7: Vitality, Quickstep, setup and apply_data ----------------------------------------------


func test_ac7_vitality_adds_max_hp_and_setting_the_sword_does_not_heal() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	var vitality: SwordData = _vitality_sword()
	var state: CombatState = motor.get_combat_state()
	assert_eq(state.get_hp(), 100)
	motor.set_sword(vitality, _rules)
	assert_eq(state.get_max_hp(), 108, "class + 8")
	assert_eq(state.get_hp(), 100, "no heal")
	assert_eq(motor.get_loadout().get_max_hp(), 108)
	state.set_hp(108)
	motor.set_sword(ItemFixtures.starter(), _rules)
	assert_eq(state.get_max_hp(), 100)
	assert_eq(state.get_hp(), 100, "clamped to the class max")
	motor.set_sword(vitality, _rules)
	assert_eq(state.get_hp(), 100, "taking it back does not heal either")
	state.set_hp(60)
	motor.set_sword(null, _rules)
	assert_eq(state.get_hp(), 60, "below the new max: unchanged")
	assert_eq(state.get_max_hp(), 100)


func test_ac7_a_sword_set_before_setup_only_stores_it_and_setup_starts_at_its_max_hp() -> void:
	var motor: PlayerMotor = PlayerMotor.new()
	motor.set_sword(_vitality_sword(), _rules)
	motor.step(0.1)  # no class yet: nothing happens
	assert_true(motor.setup(Harness.warrior(), Harness.rules(), Vector2.ZERO))
	assert_eq(motor.get_combat_state().get_max_hp(), 108)
	assert_eq(motor.get_combat_state().get_hp(), 108, "setup() starts at the loadout's max HP")
	assert_not_null(motor.get_loadout())
	assert_eq(motor.get_loadout().get_sword().id, &"vit")


func test_ac7_a_refused_setup_changes_nothing() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	motor.set_sword(_vitality_sword(), _rules)
	var broken: ClassData = Harness.warrior()
	broken.max_hp = 0
	assert_false(motor.setup(broken, Harness.rules(), Vector2.ZERO))
	assert_push_error("data rejected")
	assert_eq(motor.get_combat_state().get_max_hp(), 108)
	assert_eq(motor.get_loadout().get_max_hp(), 108)
	assert_false(motor.apply_data(broken, Harness.rules()))
	assert_push_error("data rejected")
	assert_eq(motor.get_combat_state().get_max_hp(), 108)


func test_ac7_quickstep_takes_its_cut_off_the_dash_cooldown() -> void:
	var class_cooldown: float = Harness.warrior().dash_cooldown
	assert_almost_eq(class_cooldown, 0.35, 0.000001)
	var cut: SwordData = ItemFixtures.make_sword(&"qs", 40, SwordData.Kind.QUICKSTEP, [], 0, 0.1)
	assert_almost_eq(_cooldown_after_dash(cut), class_cooldown - 0.1, 0.000001)


func test_ac7_quickstep_never_goes_below_the_minimum_dash_cooldown() -> void:
	var shipped: SwordData = ItemFixtures.make_sword(
		&"qs", 40, SwordData.Kind.QUICKSTEP, [], 0, 0.15
	)
	assert_eq(_cooldown_after_dash(shipped), _rules.min_dash_cooldown, "0.35 - 0.15 is the floor")
	var deep: SwordData = ItemFixtures.make_sword(&"qs2", 40, SwordData.Kind.QUICKSTEP, [], 0, 0.3)
	assert_eq(_cooldown_after_dash(deep), _rules.min_dash_cooldown, "a bigger cut is held at it")


func test_ac7_with_no_cut_the_cooldown_is_the_classes_value_exactly() -> void:
	var class_cooldown: float = Harness.warrior().dash_cooldown
	assert_eq(_cooldown_after_dash(null), class_cooldown, "no sword")
	assert_eq(_cooldown_after_dash(ItemFixtures.starter()), class_cooldown, "no trait")
	assert_eq(_cooldown_after_dash(_vitality_sword()), class_cooldown, "another trait")
	var zero_cut: SwordData = ItemFixtures.make_sword(&"qs0", 40, SwordData.Kind.QUICKSTEP)
	assert_eq(_cooldown_after_dash(zero_cut), class_cooldown, "a cut of 0")


func test_ac7_a_dash_that_is_hit_starts_the_same_cooldown() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	motor.set_sword(
		ItemFixtures.make_sword(&"qs", 40, SwordData.Kind.QUICKSTEP, [], 0, 0.1), _rules
	)
	Harness.step(motor, 120, Vector2.ZERO, Vector2.ZERO, true)
	assert_eq(motor.get_state(), PlayerMotor.State.DASHING)
	var event: HitEvent = HitEvent.new()
	motor.apply_hit(event, Harness.rules())
	assert_almost_eq(motor.get_cooldown_remaining(), 0.25, 0.000001)


func test_ac7_the_sword_survives_setup_and_apply_data() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	var sword: SwordData = ItemFixtures.make_sword(
		&"all", 46, SwordData.Kind.VITALITY, [9, 9, 28], 8
	)
	motor.set_sword(sword, _rules)
	assert_true(motor.setup(Harness.warrior(), Harness.rules(), Vector2(2, 3)))
	assert_same(motor.get_loadout().get_sword(), sword, "kept through setup()")
	assert_eq(motor.get_combat_state().get_max_hp(), 108)
	assert_eq(motor.get_combat_state().get_hp(), 108)
	assert_eq(_hitbox_damages(motor, 3), SWORD_HITS)
	motor.get_combat_state().set_hp(70)
	assert_true(motor.apply_data(Harness.warrior(), Harness.rules()))
	assert_same(motor.get_loadout().get_sword(), sword, "kept through apply_data()")
	assert_eq(motor.get_combat_state().get_max_hp(), 108)
	assert_eq(motor.get_combat_state().get_hp(), 70, "apply_data() keeps state")


func test_ac7_after_apply_data_with_another_class_the_values_follow_that_resource() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	# No weights: the sword's 42 is split over whatever chain the class has.
	var sword: SwordData = ItemFixtures.make_sword(&"plain", 42, SwordData.Kind.VITALITY, [], 8)
	motor.set_sword(sword, _rules)
	var other: ClassData = Harness.warrior()
	other.max_hp = 120
	other.dash_cooldown = 0.5
	other.attack_chain = _chain([12, 14, 30])
	assert_true(motor.apply_data(other, Harness.rules()))
	assert_eq(motor.get_loadout().get_max_hp(), 128, "the new class's max HP + 8")
	assert_eq(motor.get_combat_state().get_max_hp(), 128)
	assert_eq(motor.get_combat_state().get_hp(), 100, "no heal")
	var expected: Array[int] = [9, 10, 23]  # 42 split 12:14:30, the leftover to the last hit
	assert_eq(_hitbox_damages(motor, 3), expected)
	Harness.run(motor, 120, 1.0)  # the finisher's recovery and the chain window are over
	assert_eq(_cooldown_after_dash_of(motor), 0.5, "no cut: the new class's cooldown")
	var quick: SwordData = ItemFixtures.make_sword(&"qs", 42, SwordData.Kind.QUICKSTEP, [], 0, 0.1)
	motor.set_sword(quick, _rules)
	assert_eq(motor.get_combat_state().get_max_hp(), 120, "Vitality is gone")
	assert_almost_eq(motor.get_loadout().get_dash_cooldown(), 0.4, 0.000001)


# --- C8: nothing new in a snapshot, and a restore sets the sword first ---------------------------


func test_c8_no_snapshot_key_is_added_or_removed() -> void:
	var motor: PlayerMotor = Harness.motor_with()
	motor.set_sword(_heavy_sword(), _rules)
	var keys: Array = motor.to_dict().keys()
	keys.sort()
	var pinned: Array = PlayerMotor.SNAPSHOT_KEYS.duplicate()
	pinned.sort()
	assert_eq(keys, pinned, "PlayerMotor")
	assert_eq(motor.to_dict()["combat"].keys().size(), CombatState.SNAPSHOT_KEYS.size())
	assert_eq(motor.get_attack_chain().to_dict().keys().size(), 7, "AttackChain")
	assert_eq(motor.get_combat_state().to_dict().keys().size(), 6, "CombatState")


func test_c8_a_snapshot_taken_mid_chain_continues_identically_with_the_same_sword() -> void:
	for rate: int in [30, 120]:
		var live: PlayerMotor = Harness.motor_with()
		live.set_sword(_heavy_sword(), _rules)
		var ticks_per_30th: int = rate / 30
		# Hit 1, then hit 2 latched at the first instant of recovery; stop in hit 2's active phase.
		for tick_index: int in 8 * ticks_per_30th:
			_press_tick(live, rate, tick_index)
		assert_eq(live.get_attack_chain().get_attack_id(), &"sword_hit_2", "%d Hz" % rate)
		assert_eq(live.get_attack_chain().get_phase(), AttackChain.Phase.ACTIVE)
		var snapshot: Dictionary = live.to_dict()
		assert_eq(snapshot["attack_chain"]["attack"]["damage"], 9, "hit 2 is latched at 9")
		var restored: PlayerMotor = PlayerMotor.new()
		restored.set_sword(_heavy_sword(), _rules)  # before setup(): C8's order
		assert_true(restored.setup(Harness.warrior(), Harness.rules(), Vector2.ZERO))
		restored.from_dict(snapshot)
		var without: PlayerMotor = PlayerMotor.new()
		assert_true(without.setup(Harness.warrior(), Harness.rules(), Vector2.ZERO))
		without.from_dict(snapshot)
		var live_hits: Array[int] = []
		var restored_hits: Array[int] = []
		var without_hits: Array[int] = []
		var live_seen: Dictionary = {}
		var restored_seen: Dictionary = {}
		var without_seen: Dictionary = {}
		for tick_index: int in range(8 * ticks_per_30th, 40 * ticks_per_30th):
			_press_tick(live, rate, tick_index)
			_press_tick(restored, rate, tick_index)
			_press_tick(without, rate, tick_index)
			if live.to_dict() != restored.to_dict():
				fail_test("%d Hz tick %d: the restored motor differs" % [rate, tick_index])
				return
			_note_hit(live, live_hits, live_seen)
			_note_hit(restored, restored_hits, restored_seen)
			_note_hit(without, without_hits, without_seen)
		assert_eq(restored_hits, live_hits, "%d Hz" % rate)
		assert_true(live_hits.has(28), "the chain reached the finisher: %s" % [live_hits])
		# The snapshot is taken at the end of hit 2's active phase (latched at 9, and part of the
		# compared state); after it come hit 3, then the chain's first hit again.
		assert_eq(live_hits.slice(0, 2), [28, 9], "hit 3 and hit 1 from the sword")
		assert_eq(without_hits.slice(0, 2), [22, 10], "no sword set: the class's")


func test_c8_the_sword_set_after_a_restore_is_read_by_the_next_hit() -> void:
	var live: PlayerMotor = Harness.motor_with()
	live.set_sword(_heavy_sword(), _rules)
	var snapshot: Dictionary = live.to_dict()
	var restored: PlayerMotor = Harness.motor_with()
	restored.from_dict(snapshot)
	restored.set_sword(_heavy_sword(), _rules)
	assert_eq(_hitbox_damages(restored, 3), SWORD_HITS)


# --- helpers ------------------------------------------------------------------------------------


## The shipped chain's hits, as copies a test may change, with these damages.
func _chain(damages: Array[int] = [10, 10, 22]) -> Array[AttackData]:
	var attacks: Array[AttackData] = []
	var source: ClassData = load(Tunables.WARRIOR_PATH)
	for index: int in damages.size():
		var attack: AttackData = source.attack_chain[mini(index, 2)].duplicate()
		attack.damage = damages[index]
		attack.id = StringName("sword_hit_%d" % (index + 1))
		attacks.append(attack)
	return attacks


## Weights 9, 9, 28 at damage 46: no hit equals the class's 10/10/22.
func _heavy_sword() -> SwordData:
	return ItemFixtures.make_sword(&"heavy", 46, SwordData.Kind.HEAVY_FINISHER, [9, 9, 28])


func _vitality_sword() -> SwordData:
	return ItemFixtures.make_sword(&"vit", 40, SwordData.Kind.VITALITY, [], 8)


func _arena_with(sword: SwordData, before_setup: bool) -> CombatArena:
	var arena: CombatArena = CombatArena.new()
	arena.class_data = CombatArena.warrior()
	if before_setup:
		arena.player.set_sword(sword, _rules)
	arena.build()
	if not before_setup:
		arena.player.set_sword(sword, _rules)
	return arena


## One tick of the scripted fight of AC5, the way CombatArena.play() runs it.
func _tick(arena: CombatArena, rate: int, tick_index: int) -> void:
	var ticks_per_30th: int = rate / 30
	var thirtieth: int = tick_index / ticks_per_30th
	var on_30th: bool = tick_index % ticks_per_30th == 0
	arena.player.submit(MoveCommand.new(_moves.get(thirtieth, Vector2.ZERO)))
	arena.player.submit(AimCommand.new(Vector2.DOWN))
	if on_30th and _dash_presses.has(thirtieth):
		arena.player.submit(DashCommand.new())
	if on_30th and _attack_presses.has(thirtieth):
		arena.player.submit(AttackCommand.new())
	arena.sim.tick(1.0 / rate)


func _event_damages(arena: CombatArena) -> Array[int]:
	var damages: Array[int] = []
	for event: HitEvent in arena.events:
		damages.append(event.damage)
	return damages


## Presses attack on every thirtieth until `count` hits have landed, and returns what each took
## off the enemy's HP (read right after the tick the hit landed in).
func _enemy_hp_lost_per_hit(arena: CombatArena, rate: int, count: int) -> Array[int]:
	var lost: Array[int] = []
	var enemy: CombatState = arena.dummy.get_combat_state()
	var thirtieth: int = 0
	while lost.size() < count and thirtieth < 120:
		var hp_before: int = enemy.get_hp()
		var landed_before: int = arena.events.size()
		arena.play(rate, thirtieth, thirtieth + 1, range(0, 120), [], {}, Vector2.DOWN)
		if arena.events.size() > landed_before:
			lost.append(hp_before - enemy.get_hp())
		thirtieth += 1
	return lost


## Presses attack every thirtieth on a lone motor and returns the damage of the live hitbox the
## first `count` hits show in their active phase.
func _hitbox_damages(motor: PlayerMotor, count: int) -> Array[int]:
	var damages: Array[int] = []
	var seen: StringName = &""
	for tick_index: int in 400:
		_press_tick(motor, 120, tick_index)
		var hitbox: Hitbox = motor.get_live_hitbox()
		if hitbox != null and motor.get_attack_chain().get_attack_id() != seen:
			seen = motor.get_attack_chain().get_attack_id()
			damages.append(hitbox.damage)
			if damages.size() == count:
				break
	return damages


## Appends the damage of the live hitbox the first tick a hit of another id shows one. The hit the
## snapshot was taken in (hit 2) is left out: whether its end is seen depends on the tick rate.
func _note_hit(motor: PlayerMotor, hits: Array[int], seen: Dictionary) -> void:
	var hitbox: Hitbox = motor.get_live_hitbox()
	var attack_id: StringName = motor.get_attack_chain().get_attack_id()
	if hitbox != null and attack_id != &"sword_hit_2" and seen.get("id", &"") != attack_id:
		seen["id"] = attack_id
		hits.append(hitbox.damage)


## One tick of a lone motor that presses attack on every thirtieth.
func _press_tick(motor: PlayerMotor, rate: int, tick_index: int) -> void:
	var on_30th: bool = tick_index % (rate / 30) == 0
	Combat.submit_tick(motor, Vector2.ZERO, Vector2.DOWN, on_30th)
	motor.tick(1.0 / rate)


func _cooldown_after_dash(sword: SwordData) -> float:
	var motor: PlayerMotor = Harness.motor_with()
	motor.set_sword(sword, _rules)
	return _cooldown_after_dash_of(motor)


## The cooldown the motor starts at the instant its dash ends.
func _cooldown_after_dash_of(motor: PlayerMotor) -> float:
	var started: Array[float] = []
	var motor_ref: WeakRef = weakref(motor)
	motor.dash_ended.connect(
		func() -> void:
			started.append((motor_ref.get_ref() as PlayerMotor).get_cooldown_remaining())
	)
	Harness.step(motor, 120, Vector2.ZERO, Vector2.ZERO, true)
	Harness.run(motor, 120, 0.3)
	assert_eq(started.size(), 1, "the dash ended once")
	return started[0] if not started.is_empty() else -1.0


## Every field a write could change: the class's own and each hit of its chain.
func _resource_state(class_data: ClassData) -> Dictionary:
	var state: Dictionary = {
		"id": class_data.id,
		"max_hp": class_data.max_hp,
		"dash_cooldown": class_data.dash_cooldown,
		"dash_distance": class_data.dash_distance,
		"dash_duration": class_data.dash_duration,
		"window": class_data.attack_chain_window,
		"knockback_scale": class_data.knockback_scale,
	}
	var hits: Array[Dictionary] = []
	for attack: AttackData in class_data.attack_chain:
		hits.append(attack.to_dict())
	state["chain"] = hits
	return state
