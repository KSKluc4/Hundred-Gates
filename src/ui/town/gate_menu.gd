class_name GateMenu
extends ListMenu
## F-012/C10, AC23: the tower gate's plain list. One button per TowerEntry, then a last "stay"
## button. It shows what TowerProgress.get_entries() says and decides nothing (C2, G6): the town
## scene opens it and forwards the choice. Hidden until open(). Its keys, d-pad and stick are
## ListMenu's (F-015/C9): while open it moves the focus with `ui_up` / `ui_down` and `move_up` /
## `move_down`, chooses with `ui_accept` or `interact`, and cancels with `ui_cancel`; left and right
## do nothing (one column). While closed it handles no input at all. The look → Art & Game Feel
## (§10 Q4).
##
## F-016/C19: the `Odds` node, beside `Panel` and not in it, so the list never moves: a panel of its
## own with one label, at the bottom centre of the screen. It shows the text `open()` was given for
## the floor whose entry has the focus (the "Floor n" and the "Floor n — at the boss" entries of a
## floor alike), and is hidden for the stay entry, for a floor with no text or an empty one, and
## while the menu is closed. It shows what it is given and works out nothing.

## Once, with the floor and where to start it; the menu has closed by then. Not emitted by cancel().
signal entry_chosen(floor_number: int, at_boss: bool)
## Closed without a choice: the stay entry, or `ui_cancel`.
signal closed

## F-012/C16: every player-facing string of the list.
const FROM_START_FORMAT: String = "Floor %d — from the start"
const AT_BOSS_FORMAT: String = "Floor %d — at the boss"
const CLEARED_SUFFIX: String = " (cleared)"
const STAY_TEXT: String = "Stay in town"

## F-016/C19: the odds panel's width (the label wraps inside it) and its gap to the screen's bottom.
@export var odds_width_px: float = 400.0
@export var odds_bottom_margin_px: float = 8.0

var _entries: Array[TowerEntry] = []
## {floor_number: text} as the last open() was given it.
var _odds_by_floor: Dictionary = {}

@onready var _odds_panel: PanelContainer = $Odds
@onready var _odds_label: Label = $Odds/Label


func _ready() -> void:
	_panel = $Panel
	_list = $Panel/List
	super._ready()
	_odds_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_odds_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_odds_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_odds_panel.offset_bottom = -odds_bottom_margin_px
	_odds_panel.custom_minimum_size = Vector2(odds_width_px, 0.0)
	_odds_label.add_theme_font_size_override(&"font_size", font_size)
	_odds_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_odds_panel.visible = false


## One line of the list per entry: "Floor 2 — at the boss (cleared)".
static func entry_text(entry: TowerEntry) -> String:
	var text: String = (AT_BOSS_FORMAT if entry.at_boss else FROM_START_FORMAT) % entry.floor_number
	if entry.is_cleared:
		text += CLEARED_SUFFIX
	return text


## Shows the list again from the start: calling it while open rebuilds it. The focus starts on
## the last floor entry, or on the stay entry when there are none. `odds_by_floor` is
## `{floor_number: text}` (F-016/C19): what the `Odds` node shows while a floor's entry has the
## focus; none by default, and then nothing is ever shown.
func open(entries: Array[TowerEntry], odds_by_floor: Dictionary = {}) -> void:
	_clear_buttons()
	_entries = entries.duplicate()
	_odds_by_floor = odds_by_floor.duplicate()
	for index: int in _entries.size():
		_add_button(entry_text(_entries[index]), choose.bind(index))
	_add_button(STAY_TEXT, cancel)
	_show_list()
	_set_focus(maxi(_entries.size() - 1, 0))


## F-016/C19: hides the odds with the list.
func close() -> void:
	super.close()
	_show_odds("")


## What the odds panel says now; empty when it is hidden.
func get_odds_text() -> String:
	return _odds_label.text if is_odds_visible() else ""


## True while the menu is open and the focused entry has a text to show.
func is_odds_visible() -> bool:
	return _is_open and _odds_panel.visible


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


## F-016/C19: the odds of the focused entry's floor; nothing for the stay entry.
func _focus_moved(index: int) -> void:
	var text: String = ""
	if index >= 0 and index < _entries.size():
		text = String(_odds_by_floor.get(_entries[index].floor_number, ""))
	_show_odds(text)


func _show_odds(text: String) -> void:
	_odds_label.text = text
	_odds_panel.visible = not text.is_empty()
