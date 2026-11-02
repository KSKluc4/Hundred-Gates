class_name CombatView
extends RefCounted
## What every combatant may know about the others at a step start (F-004/C4): a read-only
## snapshot as of the previous contact. Everyone senses the same one before anyone advances,
## so registration order can't change what an enemy decides from it.


## One combatant, as it stood. In registration order, so C9's ties can go by it.
class Entry:
	extends RefCounted
	var combat_id: StringName
	var team: Combatant.Team
	var position: Vector2
	var is_alive: bool


var _entries: Array[Entry] = []


static func capture(combatants: Array[Combatant]) -> CombatView:
	var view: CombatView = CombatView.new()
	for combatant: Combatant in combatants:
		var entry: Entry = Entry.new()
		entry.combat_id = combatant.get_combat_id()
		entry.team = combatant.get_team()
		entry.position = combatant.get_position_tiles()
		entry.is_alive = combatant.is_alive()
		view._entries.append(entry)
	return view


func get_entries() -> Array[Entry]:
	return _entries


## Null if nobody has that id.
func find(combat_id: StringName) -> Entry:
	for entry: Entry in _entries:
		if entry.combat_id == combat_id:
			return entry
	return null
