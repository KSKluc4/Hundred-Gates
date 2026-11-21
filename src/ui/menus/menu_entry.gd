class_name MenuEntry
extends RefCounted
## F-015/C10: one line of a MenuPanel as plain values: which entry (the id the shell reacts to),
## what it says, and whether it can be chosen. ShellMenus makes them and the panel reads them; the
## panel keeps none of them (it copies what it needs), so a caller can reuse or change its own.

var id: StringName = &""
var text: String = ""
var enabled: bool = true


static func make(entry_id: StringName, entry_text: String, is_enabled: bool = true) -> MenuEntry:
	var entry: MenuEntry = MenuEntry.new()
	entry.id = entry_id
	entry.text = entry_text
	entry.enabled = is_enabled
	return entry
