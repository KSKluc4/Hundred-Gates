class_name ItemTunables
extends Resource
## The caps and sizes of swords and loot (F-016/C4, G2). The shipped file is
## data/tunables/items.tres; the numbers are Combat's breakpoints (items.md, "Caps").

## F-016/C3: the most damage one full chain with a sword may deal. A chaser (50 HP) still takes a
## full chain and one more hit.
@export var max_chain_damage: int = 49
## F-016/C3: the most damage the hits before the last may deal together. A caster (30 HP) still
## takes three hits.
@export var max_light_hits_damage: int = 29
## F-016/C3: the most damage the last hit may deal alone. It never kills a caster by itself.
@export var max_finisher_damage: int = 29
## F-016/C3: the most max HP a Vitality sword may add.
@export var max_hp_bonus_cap: int = 8
## F-016/C3, C7: seconds. The dash cooldown never goes below this.
@export var min_dash_cooldown: float = 0.2
## F-016/C9: tiles, centre to centre. A drop this near the player is taken.
@export var pickup_radius_tiles: float = 0.8
## F-016/C17: swords on one page of the Equipment list.
@export var equipment_page_size: int = 8


## F-016/C4. Empty result means valid.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not max_chain_damage >= 1:
		errors.append("max_chain_damage must be >= 1")
	if not max_light_hits_damage >= 1:
		errors.append("max_light_hits_damage must be >= 1")
	if not max_finisher_damage >= 1:
		errors.append("max_finisher_damage must be >= 1")
	if not max_hp_bonus_cap >= 1:
		errors.append("max_hp_bonus_cap must be >= 1")
	if not min_dash_cooldown >= 0.0:
		errors.append("min_dash_cooldown must be >= 0")
	if not pickup_radius_tiles > 0.0:
		errors.append("pickup_radius_tiles must be > 0")
	if not equipment_page_size >= 1:
		errors.append("equipment_page_size must be >= 1")
	return errors
