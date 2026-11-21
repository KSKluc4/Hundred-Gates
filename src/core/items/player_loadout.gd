class_name PlayerLoadout
extends RefCounted
## F-016/C7: a class and the sword it carries, as the four numbers the motor and the floor run read
## (hit damages, max HP, dash cooldown, room heal bonus). One place for the arithmetic. With no
## sword every value is the class's own: a game without a sword behaves exactly as without loot.

var _class_data: ClassData
var _sword: SwordData
var _hits: PackedInt32Array = PackedInt32Array()
var _min_dash_cooldown: float = 0.0


## `sword` may be null. `rules` gives the dash cooldown's floor (null: no floor).
static func of(class_data: ClassData, sword: SwordData, rules: ItemTunables) -> PlayerLoadout:
	var loadout: PlayerLoadout = PlayerLoadout.new()
	loadout._class_data = class_data
	loadout._sword = sword
	loadout._min_dash_cooldown = rules.min_dash_cooldown if rules != null else 0.0
	if sword != null:
		var hits: PackedInt32Array = sword.get_hit_damages(class_data)
		# A sword whose hits do not fit the chain is not applied to the hits at all: every hit stays the
		# class attack's own. Only a reload to a class with another chain can show one (the sword was
		# validated against the class it was built for).
		if hits.size() == class_data.attack_chain.size():
			loadout._hits = hits
	return loadout


## The damage of hit `index` of the chain: the sword's split, or the class attack's own damage (also
## for every hit of a sword whose hits do not fit the chain). -1 for a hit the CLASS chain does not
## have, whatever the sword's weights (AttackChain.start() reads -1 as "the attack's own").
func get_hit_damage(index: int) -> int:
	if index < 0 or index >= _class_data.attack_chain.size():
		return -1
	if index < _hits.size():
		return _hits[index]
	return _class_data.attack_chain[index].damage


func get_max_hp() -> int:
	return _class_data.max_hp + (_sword.max_hp_bonus if _sword != null else 0)


## The class's cooldown less the sword's cut, never below the rules' minimum. With no cut it is the
## class's value as it is, even when that is below the minimum (a game without a sword is `main`).
func get_dash_cooldown() -> float:
	if _sword == null or _sword.dash_cooldown_cut == 0.0:
		return _class_data.dash_cooldown
	return maxf(_min_dash_cooldown, _class_data.dash_cooldown - _sword.dash_cooldown_cut)


## Added to the room-clear heal fraction.
func get_room_heal_bonus() -> float:
	return _sword.room_heal_bonus if _sword != null else 0.0


func get_sword() -> SwordData:
	return _sword
