class_name ItemTexts
extends RefCounted
## F-016/C18, C19: every player-facing string of swords and loot (F-012/C16's rule: no item string
## anywhere else). Static functions and constants only; they take plain values (swords, numbers,
## names) and return plain values. The pause entry's text and id live in ShellMenus.

## The Equipment menu.
const EQUIPMENT_HEADING: String = "Equipment"
const CHOOSE_BODY: String = "Choose a sword to equip it."
const LOCKED_BODY: String = (
	"Swords can be changed in town, " + "or in the last room before a boss once it is cleared."
)
const NO_SWORDS_BODY: String = "No swords."
const NEXT_PAGE_TEXT: String = "Next page"
const PREVIOUS_PAGE_TEXT: String = "Previous page"

## The traits.
const NO_TRAIT_TEXT: String = "No trait"
const HEAVY_FINISHER_TEXT: String = "Heavy finisher"
const QUICK_CUTS_TEXT: String = "Quick cuts"
const VITALITY_FORMAT: String = "Max HP +%d"
const QUICKSTEP_FORMAT: String = "Dash cooldown -%.2f s"
const MENDING_FORMAT: String = "Room heal %d%% of max HP"

## A sword's entry: name, damage, the hits, the trait; then the count and the mark.
const SWORD_FORMAT: String = "%s — %d (%s) — %s"
const COUNT_FORMAT: String = " ×%d"
const EQUIPPED_MARK: String = " [equipped]"

## The pickup notice.
const FOUND_FORMAT: String = "Found: %s"
const FOUND_MORE_FORMAT: String = " +%d more"
## At most this many names are written out; the rest are counted.
const FOUND_NAMES_SHOWN: int = 2
## F-016/C20: what joins the `Found:` notice to the heal or the clear shown in the same moment
## (the other part first, `Found:` last).
const BANNER_JOIN: String = " · "

## The odds at the tower gate.
const BOSS_DROPS_HEADING: String = "Boss drops:"
const ODDS_LINE_FORMAT: String = "%d%% chance: %s"
const GUARANTEE_LINE: String = "Your next win is sure to drop one of these, in these proportions."
const NOTHING_FORMAT: String = "Nothing: %d%%"


## `<name> — <damage> (<h1>/<h2>/<h3>) — <trait>`, then ` ×<n>` when `count` is more
## than 1, then ` [equipped]`. `hits` is `sword.get_hit_damages(class_data)`.
static func sword_text(
	sword: SwordData, hits: PackedInt32Array, count: int, equipped: bool, base_heal_fraction: float
) -> String:
	var hit_parts: PackedStringArray = PackedStringArray()
	for hit: int in hits:
		hit_parts.append(str(hit))
	var text: String = (
		SWORD_FORMAT
		% [
			sword.display_name,
			sword.damage,
			"/".join(hit_parts),
			trait_text(sword, base_heal_fraction)
		]
	)
	if count > 1:
		text += COUNT_FORMAT % count
	if equipped:
		text += EQUIPPED_MARK
	return text


## What the sword's one trait does, for the player. Mending reads as the whole heal: the base
## fraction plus the bonus, at most 1, as a rounded percentage (30 % and 0.05 read 35).
static func trait_text(sword: SwordData, base_heal_fraction: float) -> String:
	match sword.kind:
		SwordData.Kind.HEAVY_FINISHER:
			return HEAVY_FINISHER_TEXT
		SwordData.Kind.QUICK_CUTS:
			return QUICK_CUTS_TEXT
		SwordData.Kind.VITALITY:
			return VITALITY_FORMAT % sword.max_hp_bonus
		SwordData.Kind.QUICKSTEP:
			return QUICKSTEP_FORMAT % sword.dash_cooldown_cut
		SwordData.Kind.MENDING:
			var fraction: float = minf(1.0, base_heal_fraction + sword.room_heal_bonus)
			return MENDING_FORMAT % roundi(fraction * 100.0)
		_:
			return NO_TRAIT_TEXT


## `Found: A, B`; with more than two names, the first two and ` +<n> more`. Empty for no names.
static func found_text(names: PackedStringArray) -> String:
	if names.is_empty():
		return ""
	var shown: PackedStringArray = names.slice(0, FOUND_NAMES_SHOWN)
	var text: String = FOUND_FORMAT % ", ".join(shown)
	if names.size() > FOUND_NAMES_SHOWN:
		text += FOUND_MORE_FORMAT % (names.size() - FOUND_NAMES_SHOWN)
	return text


## The gate's odds for one floor: `Boss drops:`, a line per boss sword, then the guarantee line
## (`guaranteed`) or what is left to 100 as `Nothing: <n>%` (no such line when it is 0). Empty for
## no floor loot or an empty boss table.
static func odds_text(
	floor_loot: FloorLoot, class_data: ClassData, base_heal_fraction: float, guaranteed: bool
) -> String:
	if floor_loot == null or floor_loot.boss_swords.is_empty():
		return ""
	var lines: PackedStringArray = PackedStringArray([BOSS_DROPS_HEADING])
	for index: int in floor_loot.boss_swords.size():
		var sword: SwordData = floor_loot.boss_swords[index]
		if sword == null:
			continue
		var percent: int = (
			floor_loot.boss_percents[index] if index < floor_loot.boss_percents.size() else 0
		)
		var entry: String = sword_text(
			sword, sword.get_hit_damages(class_data), 1, false, base_heal_fraction
		)
		lines.append(ODDS_LINE_FORMAT % [percent, entry])
	var missing: int = 100 - floor_loot.get_boss_percent_sum()
	if guaranteed:
		lines.append(GUARANTEE_LINE)
	elif missing > 0:
		lines.append(NOTHING_FORMAT % missing)
	return "\n".join(lines)
