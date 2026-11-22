class_name Inventory
extends RefCounted
## F-016/C13: the swords a character owns and the one it fights with. A sword owned twice is a
## count of 2, nothing more (items.md, "Drops"). Pure logic, ids only: what an id means is the
## catalog's business.

## Emitted when the content or the equipped sword changes (also on a restore).
signal changed

const KEY_OWNED: String = "owned"
const KEY_ID: String = "id"
const KEY_COUNT: String = "count"
const KEY_EQUIPPED: String = "equipped"

## Count per id. A Dictionary keeps the order of first insertion: that is the order of
## `get_ids()`.
var _counts: Dictionary[StringName, int] = {}
var _equipped: StringName = &""


## One more of `sword_id`. An empty id is ignored.
func add(sword_id: StringName) -> void:
	if sword_id == &"":
		return
	_counts[sword_id] = get_count(sword_id) + 1
	changed.emit()


func get_count(sword_id: StringName) -> int:
	return _counts.get(sword_id, 0)


func has(sword_id: StringName) -> bool:
	return _counts.has(sword_id)


## Every owned id, in the order each was first acquired.
func get_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_counts.keys())
	return ids


## True for an owned sword (and for the one already equipped, which changes nothing); false and
## nothing changed for a sword that is not owned.
func equip(sword_id: StringName) -> bool:
	if not has(sword_id):
		return false
	if sword_id != _equipped:
		_equipped = sword_id
		changed.emit()
	return true


## `&""` when nothing is equipped.
func get_equipped_id() -> StringName:
	return _equipped


## G7. Ids are stored as Strings.
func to_dict() -> Dictionary:
	var owned: Array[Dictionary] = []
	for sword_id: StringName in _counts:
		owned.append({KEY_ID: String(sword_id), KEY_COUNT: _counts[sword_id]})
	return {KEY_OWNED: owned, KEY_EQUIPPED: String(_equipped)}


## Why `snapshot` can't be restored, empty when it can: wrong types, a missing key, an empty or
## repeated id, a count below 1, an equipped id that is not owned. The empty inventory with
## nothing equipped is valid.
func restore_errors(snapshot: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not snapshot.has_all([KEY_OWNED, KEY_EQUIPPED]):
		errors.append("inventory: missing keys")
		return errors
	if not snapshot[KEY_OWNED] is Array or not _is_text(snapshot[KEY_EQUIPPED]):
		errors.append("inventory: wrong types")
		return errors
	var seen: Dictionary[StringName, bool] = {}
	for entry: Variant in snapshot[KEY_OWNED]:
		var problem: String = _entry_error(entry, seen)
		if not problem.is_empty():
			errors.append(problem)
			return errors
		seen[StringName(entry[KEY_ID])] = true
	var equipped: StringName = StringName(snapshot[KEY_EQUIPPED])
	if equipped != &"" and not seen.has(equipped):
		errors.append("inventory: the equipped sword %s is not owned" % equipped)
	return errors


## Refuses what restore_errors() lists, and then changes nothing.
func from_dict(snapshot: Dictionary) -> bool:
	if not restore_errors(snapshot).is_empty():
		return false
	_counts = {}
	for entry: Dictionary in snapshot[KEY_OWNED]:
		_counts[StringName(entry[KEY_ID])] = entry[KEY_COUNT]
	_equipped = StringName(snapshot[KEY_EQUIPPED])
	changed.emit()
	return true


func _entry_error(entry: Variant, seen: Dictionary[StringName, bool]) -> String:
	if not (entry is Dictionary and entry.has_all([KEY_ID, KEY_COUNT])):
		return "inventory: an entry is not {id, count}"
	if not (_is_text(entry[KEY_ID]) and entry[KEY_COUNT] is int):
		return "inventory: an entry has wrong types"
	if StringName(entry[KEY_ID]) == &"":
		return "inventory: an entry has an empty id"
	if int(entry[KEY_COUNT]) < 1:
		return "inventory: %s has a count below 1" % entry[KEY_ID]
	if seen.has(StringName(entry[KEY_ID])):
		return "inventory: %s is listed twice" % entry[KEY_ID]
	return ""


## An id comes back as a String or a StringName.
func _is_text(value: Variant) -> bool:
	return value is String or value is StringName
