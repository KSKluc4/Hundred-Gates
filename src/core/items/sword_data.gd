class_name SwordData
extends Resource
## One sword as data (F-016/C1, D-017, G9): a damage and exactly one trait. The damage is the
## damage of one full chain, split over the class's hits (SwordMath). A sword never changes a
## hit's windup, active, recovery, reach, arc or knockback.

enum Kind { NONE, HEAVY_FINISHER, QUICK_CUTS, VITALITY, QUICKSTEP, MENDING }

## Float slack for the dash cooldown limit: 0.35 - 0.15 is 0.19999999999999998 in a double.
const COOLDOWN_EPSILON: float = 0.000001
const UTILITY_KINDS: Array[Kind] = [Kind.VITALITY, Kind.QUICKSTEP, Kind.MENDING]

@export var id: StringName = &""
@export var display_name: String = ""
## The damage of one full chain with this sword.
@export var damage: int = 0
## Empty: the class chain's own damages are the weights. Heavy finisher and Quick cuts swords carry
## their hits here, one per hit of the chain.
@export var weights: PackedInt32Array = PackedInt32Array()
@export var kind: Kind = Kind.NONE
## Vitality: max HP added.
@export var max_hp_bonus: int = 0
## Quickstep: seconds taken off the dash cooldown.
@export var dash_cooldown_cut: float = 0.0
## Mending: added to the room-clear heal fraction.
@export var room_heal_bonus: float = 0.0


## F-016/C1: the damage of each hit of `class_data`'s chain with this sword. Empty when the class
## has no chain or SwordMath.split() refuses the weights.
func get_hit_damages(class_data: ClassData) -> PackedInt32Array:
	return SwordMath.split(damage, _own_or_class_weights(class_data))


## F-016/C3. Empty result means valid. All errors are returned, not the first. The caps and the
## limits are `rules`', the chain and the dash cooldown are `class_data`'s.
func validate(class_data: ClassData, rules: ItemTunables) -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"":
		errors.append("id must not be empty")
	if display_name.is_empty():
		errors.append("display_name must not be empty")
	if not damage >= 1:
		errors.append("damage must be >= 1")
	if class_data == null or class_data.attack_chain.is_empty():
		errors.append("the class has no attack chain")
		return errors
	_check_hits(class_data, rules, errors)
	_check_bonuses(errors)
	_check_trait(class_data, rules, errors)
	return errors


## The sword's own weights, or the class chain's damages.
func _own_or_class_weights(class_data: ClassData) -> PackedInt32Array:
	return weights if not weights.is_empty() else _class_weights(class_data)


## The standard split's weights: what the class's hits deal on their own.
func _class_weights(class_data: ClassData) -> PackedInt32Array:
	var chain_weights: PackedInt32Array = PackedInt32Array()
	for attack: AttackData in class_data.attack_chain:
		chain_weights.append(attack.damage if attack != null else 0)
	return chain_weights


## The weights, the hits that follow from them and the caps on those hits.
func _check_hits(class_data: ClassData, rules: ItemTunables, errors: PackedStringArray) -> void:
	var chain_size: int = class_data.attack_chain.size()
	if not weights.is_empty() and weights.size() != chain_size:
		errors.append(
			"weights has %d entries, the class chain has %d hits" % [weights.size(), chain_size]
		)
	for weight: int in weights:
		if weight < 1:
			errors.append("every weight must be >= 1, found %d" % weight)
	if damage > rules.max_chain_damage:
		errors.append("damage %d is above max_chain_damage %d" % [damage, rules.max_chain_damage])
	var hits: PackedInt32Array = get_hit_damages(class_data)
	if hits.size() != chain_size:
		return  # The weights or the damage are refused above: there are no hits to check.
	var light_total: int = 0
	for index: int in chain_size - 1:
		light_total += hits[index]
	for hit: int in hits:
		if hit < 1:
			errors.append("every hit must be >= 1, the hits are %s" % _hits_text(hits))
			break
	if light_total > rules.max_light_hits_damage:
		errors.append(
			(
				"the hits before the last add up to %d, above max_light_hits_damage %d"
				% [light_total, rules.max_light_hits_damage]
			)
		)
	if hits[chain_size - 1] > rules.max_finisher_damage:
		errors.append(
			(
				"the last hit is %d, above max_finisher_damage %d"
				% [hits[chain_size - 1], rules.max_finisher_damage]
			)
		)


func _check_bonuses(errors: PackedStringArray) -> void:
	if max_hp_bonus < 0:
		errors.append("max_hp_bonus must be >= 0")
	if dash_cooldown_cut < 0.0:
		errors.append("dash_cooldown_cut must be >= 0")
	if room_heal_bonus < 0.0:
		errors.append("room_heal_bonus must be >= 0")


## The kind against the weights and the bonuses: exactly one trait, as a data rule.
func _check_trait(class_data: ClassData, rules: ItemTunables, errors: PackedStringArray) -> void:
	if kind == Kind.NONE:
		if not weights.is_empty():
			errors.append("a sword with no trait must not have weights")
		if _has_bonus_other_than(Kind.NONE):
			errors.append("a sword with no trait must not have a bonus")
	elif kind == Kind.HEAVY_FINISHER or kind == Kind.QUICK_CUTS:
		_check_hit_shape(class_data, errors)
	else:
		_check_utility(class_data, rules, errors)


## Heavy finisher and Quick cuts: their own hits, a last hit on the right side of the standard
## split's, and no bonus (that would be a second trait).
func _check_hit_shape(class_data: ClassData, errors: PackedStringArray) -> void:
	var heavy: bool = kind == Kind.HEAVY_FINISHER
	var trait_name: String = "Heavy finisher" if heavy else "Quick cuts"
	if _has_bonus_other_than(Kind.NONE):
		errors.append("a %s sword must not have a bonus" % trait_name)
	if weights.is_empty():
		errors.append("a %s sword needs its own weights" % trait_name)
		return
	var hits: PackedInt32Array = get_hit_damages(class_data)
	var standard: PackedInt32Array = SwordMath.split(damage, _class_weights(class_data))
	if hits.is_empty() or hits.size() != standard.size():
		return  # Refused above.
	var last: int = hits.size() - 1
	if heavy and not hits[last] > standard[last]:
		errors.append(
			(
				"a Heavy finisher's last hit is %d, not above the standard split's %d"
				% [hits[last], standard[last]]
			)
		)
	if not heavy and not hits[last] < standard[last]:
		errors.append(
			(
				"a Quick cuts last hit is %d, not below the standard split's %d"
				% [hits[last], standard[last]]
			)
		)


## Vitality, Quickstep and Mending: no weights, their own bonus, no other kind's bonus.
func _check_utility(class_data: ClassData, rules: ItemTunables, errors: PackedStringArray) -> void:
	if not weights.is_empty():
		errors.append("a utility sword must not have weights")
	if not _has_own_bonus():
		errors.append("a utility sword needs its own bonus")
	if _has_bonus_other_than(kind):
		errors.append("a utility sword must not have another kind's bonus")
	if kind == Kind.VITALITY and max_hp_bonus > rules.max_hp_bonus_cap:
		errors.append(
			"max_hp_bonus %d is above max_hp_bonus_cap %d" % [max_hp_bonus, rules.max_hp_bonus_cap]
		)
	if kind == Kind.QUICKSTEP:
		var cooldown: float = class_data.dash_cooldown - dash_cooldown_cut
		if cooldown < rules.min_dash_cooldown - COOLDOWN_EPSILON:
			errors.append(
				(
					"the dash cooldown would be %.3f s, below min_dash_cooldown %.3f s"
					% [cooldown, rules.min_dash_cooldown]
				)
			)


func _has_own_bonus() -> bool:
	return _has_bonus(kind)


## True when a bonus other than `own_kind`'s is set. Kind.NONE has no bonus of its own, so any is.
func _has_bonus_other_than(own_kind: Kind) -> bool:
	for utility: Kind in UTILITY_KINDS:
		if utility != own_kind and _has_bonus(utility):
			return true
	return false


func _has_bonus(bonus_kind: Kind) -> bool:
	match bonus_kind:
		Kind.VITALITY:
			return max_hp_bonus != 0
		Kind.QUICKSTEP:
			return dash_cooldown_cut != 0.0
		Kind.MENDING:
			return room_heal_bonus != 0.0
		_:
			return false


func _hits_text(hits: PackedInt32Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for hit: int in hits:
		parts.append(str(hit))
	return "/".join(parts)
