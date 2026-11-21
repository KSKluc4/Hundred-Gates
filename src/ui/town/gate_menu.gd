class_name GateMenu
extends ListMenu
## F-012/C10, AC23: the tower gate's plain list. One button per TowerEntry, then a last "stay"
## button. It shows what TowerProgress.get_entries() says and decides nothing (C2, G6): the town
## scene opens it and forwards the choice. Hidden until open(). Its keys, d-pad and stick are
## ListMenu's (F-015/C9): while open it moves the focus with `ui_up` / `ui_down` and `move_up` /
## `move_down`, chooses with `ui_accept` or `interact`, and cancels with `ui_cancel`; left and right
## do nothing (one column). While closed it handles no input at all. The look → Art & Game Feel
## (§10 Q4).

## Once, with the floor and where to start it; the menu has closed by then. Not emitted by cancel().
signal entry_chosen(floor_number: int, at_boss: bool)
## Closed without a choice: the stay entry, or `ui_cancel`.
signal closed

## F-012/C16: every player-facing string of the list.
const FROM_START_FORMAT: String = "Floor %d — from the start"
const AT_BOSS_FORMAT: String = "Floor %d — at the boss"
const CLEARED_SUFFIX: String = " (cleared)"
const STAY_TEXT: String = "Stay in town"

var _entries: Array[TowerEntry] = []


func _ready() -> void:
	_panel = $Panel
	_list = $Panel/List
	super._ready()


## One line of the list per entry: "Floor 2 — at the boss (cleared)".
static func entry_text(entry: TowerEntry) -> String:
	var text: String = (AT_BOSS_FORMAT if entry.at_boss else FROM_START_FORMAT) % entry.floor_number
	if entry.is_cleared:
		text += CLEARED_SUFFIX
	return text


## Shows the list again from the start: calling it while open rebuilds it. The focus starts on
## the last floor entry, or on the stay entry when there are none.
func open(entries: Array[TowerEntry]) -> void:
	_clear_buttons()
	_entries = entries.duplicate()
	for index: int in _entries.size():
		_add_button(entry_text(_entries[index]), choose.bind(index))
	_add_button(STAY_TEXT, cancel)
	_show_list()
	_set_focus(maxi(_entries.size() - 1, 0))


## The floor entries, without the stay entry.
func get_entry_count() -> int:
	return _entries.size()


## What a click on entry `index` does. An index outside the floor entries (the stay entry
## included) does nothing; so does a call while closed.
func choose(index: int) -> void:
	if not _is_open or index < 0 or index >= _entries.size():
		return
	var entry: TowerEntry = _entries[index]
	close()
	entry_chosen.emit(entry.floor_number, entry.at_boss)


## What the stay entry and `ui_cancel` do. Nothing while closed.
func cancel() -> void:
	if not _is_open:
		return
	close()
	closed.emit()


func _on_cancel_pressed() -> void:
	cancel()
