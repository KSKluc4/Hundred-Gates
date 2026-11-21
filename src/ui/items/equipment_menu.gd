class_name EquipmentMenu
extends RefCounted
## F-016/C17: what the Equipment menu lists, built from plain values and nothing else: the entries
## of one page of the owned swords, the page that holds a sword, how many pages there are and the
## body text. Static functions and constants only. The shell opens a `MenuPanel` with what these
## say (the page shown is the one menu variable it keeps) and never rebuilds a menu to change one
## entry's text (F-015 DEV-11). Every player-facing string is `ItemTexts`', except `Back`, which is
## the shell menus' own.

## A sword's entry id is this prefix and the sword's id.
const SWORD_ENTRY_PREFIX: String = "sword:"
const NEXT_ID: StringName = &"equipment_next"
const PREVIOUS_ID: StringName = &"equipment_previous"


## The entry id of sword `sword_id`: `sword:<id>`.
static func sword_entry_id(sword_id: StringName) -> StringName:
	return StringName(SWORD_ENTRY_PREFIX + String(sword_id))


## The sword id an entry id names; `&""` for any other entry id (the page entries, `Back`) and for
## a sword entry with no id after the prefix.
static func sword_of(entry_id: StringName) -> StringName:
	var text: String = String(entry_id)
	if not text.begins_with(SWORD_ENTRY_PREFIX):
		return &""
	return StringName(text.trim_prefix(SWORD_ENTRY_PREFIX))


## How many pages the owned swords fill: at least 1, also for an empty inventory. A page size
## below 1 counts as 1.
static func page_count(inventory: Inventory, page_size: int) -> int:
	var size: int = maxi(page_size, 1)
	var owned: int = inventory.get_ids().size()
	return maxi(1, ceili(float(owned) / float(size)))


## The 0-based page that holds `sword_id`; 0 for a sword that is not owned.
static func page_of(inventory: Inventory, sword_id: StringName, page_size: int) -> int:
	var index: int = inventory.get_ids().find(sword_id)
	if index < 0:
		return 0
	return floori(float(index) / float(maxi(page_size, 1)))


## The entries of page `page` (0-based; out of range is clamped): the page's swords in the order
## they were first acquired, `Next page` when a later page exists, `Previous page` when an earlier
## one does, then `Back`. A sword's text carries its count and the equipped mark; every sword entry
## is disabled when `can_equip` is false, the page entries and `Back` never are. An owned id the
## catalog does not know is left out.
static func entries(
	inventory: Inventory,
	catalog: LootCatalog,
	class_data: ClassData,
	base_heal_fraction: float,
	can_equip: bool,
	page: int,
	page_size: int
) -> Array[MenuEntry]:
	var list: Array[MenuEntry] = []
	var size: int = maxi(page_size, 1)
	var pages: int = page_count(inventory, size)
	var shown: int = clampi(page, 0, pages - 1)
	var ids: Array[StringName] = inventory.get_ids()
	var first: int = shown * size
	var last: int = mini(first + size, ids.size())
	for index: int in range(first, last):
		var sword: SwordData = catalog.get_sword(ids[index]) if catalog != null else null
		if sword == null:
			continue
		var text: String = ItemTexts.sword_text(
			sword,
			sword.get_hit_damages(class_data),
			inventory.get_count(sword.id),
			sword.id == inventory.get_equipped_id(),
			base_heal_fraction
		)
		list.append(MenuEntry.make(sword_entry_id(sword.id), text, can_equip))
	if shown < pages - 1:
		list.append(MenuEntry.make(NEXT_ID, ItemTexts.NEXT_PAGE_TEXT))
	if shown > 0:
		list.append(MenuEntry.make(PREVIOUS_ID, ItemTexts.PREVIOUS_PAGE_TEXT))
	list.append(MenuEntry.make(ShellMenus.BACK, ShellMenus.BACK_TEXT))
	return list


## The line under the heading: where equipping is not allowed it says where it is (also with no
## swords); with no swords it says so; otherwise what choosing does.
static func body(inventory: Inventory, can_equip: bool) -> String:
	if not can_equip:
		return ItemTexts.LOCKED_BODY
	if inventory.get_ids().is_empty():
		return ItemTexts.NO_SWORDS_BODY
	return ItemTexts.CHOOSE_BODY
