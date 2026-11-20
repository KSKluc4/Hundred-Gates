class_name MenuPanel
extends ListMenu
## F-015/C10: the one panel every menu of the shell uses: a heading, a body text (hidden when it
## is empty) and a column of entries. It shows what it is told and decides nothing (G6): the shell
## opens it with what ShellMenus says for the flow's state and answers `entry_chosen` and
## `cancelled`. A key, a pad button and a click all end in `choose(id)` (a click is the button's
## own `pressed`). Neither signal closes the panel: the shell decides what is shown next. Hidden
## until open(), and while closed it handles no input. Keys, d-pad, stick and the disabled entry
## are ListMenu's.
##
## The choose guard (F-015 code review, fixes A): a choice that opens the next menu often leaves an
## entry of it under the cursor or under the focus, and a second click, key or pad press that comes
## right after would act on whatever entry lies there ("Settings" opens a menu whose "Fullscreen" is
## where "Settings" was, and whose focus is on "Screen shake"). So for `choose_guard_seconds` of
## real time after `open()` the entries take no pointer input (`MOUSE_FILTER_IGNORE`) and a choice
## by `ui_accept` or `interact` (a key or the pad) does nothing, though the menu still consumes the
## key. Moving the focus, `ui_cancel` and `choose(id)` called by code are not guarded; the in-place
## changes (`set_body`, `set_entry_text`, `set_entry_enabled`) do not start it again.
## A double click never chooses, guard or no guard: a mouse button event the OS marks as a double
## click is consumed while the panel is open, so a second click that comes later than the guard
## (Windows allows 500 ms) or after a stalled frame is still not a choice. A deliberate second
## click, which the OS does not mark, acts once the guard has passed.
## The look → Art & Game Feel (F-015 §10 Q5).

## Once per choice of an enabled entry, with its id. Not emitted by a disabled or unknown one.
signal entry_chosen(id: StringName)
## `ui_cancel` while open. What it means (back one step, nothing) is the shell's.
signal cancelled

@export var heading_font_size: int = 8
## How long, in real seconds, the entries ignore the pointer and the choose keys after `open()`;
## 0 is no guard.
@export var choose_guard_seconds: float = 0.3
## The gap between the heading, the body and the entries.
@export var content_separation_px: int = 4

var _ids: Array[StringName] = []
## `Time.get_ticks_msec()` at which the choose guard ends (meaningful while `_choose_guarded`).
var _choose_guard_until_msec: int = 0
var _choose_guarded: bool = false

@onready var _content: VBoxContainer = $Panel/Content
@onready var _heading_label: Label = $Panel/Content/Heading
@onready var _body_label: Label = $Panel/Content/Body


func _ready() -> void:
	_panel = $Panel
	_list = $Panel/Content/Buttons
	super._ready()
	_content.add_theme_constant_override(&"separation", content_separation_px)
	_heading_label.add_theme_font_size_override(&"font_size", heading_font_size)
	_body_label.add_theme_font_size_override(&"font_size", font_size)
	_body_label.visible = not _body_label.text.is_empty()
	set_process(false)


## Real time, not frames: the guard ends the same at any frame rate.
func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _choose_guard_until_msec:
		_end_choose_guard()


## A double click is consumed before the buttons see it (and before the keys' handler: it is not
## one). Everything else is ListMenu's.
func _input(event: InputEvent) -> void:
	if _is_open and _is_double_click(event):
		get_viewport().set_input_as_handled()
		return
	super._input(event)


## Shows the menu from the start: calling it while open (or after it was hidden) rebuilds it and
## takes the focus again, onto `focus_id`, or onto the first entry when there is no such entry.
## The entries are read, not kept: the caller's stay its own.
func open(
	heading_text: String, body_text: String, entries: Array[MenuEntry], focus_id: StringName
) -> void:
	_clear_buttons()
	_ids.clear()
	_heading_label.text = heading_text
	set_body(body_text)
	for entry: MenuEntry in entries:
		var button: Button = _add_button(entry.text, choose.bind(entry.id))
		button.disabled = not entry.enabled
		_ids.append(entry.id)
	_show_list()
	_set_focus(maxi(_ids.find(focus_id), 0))
	_start_choose_guard()


## What a key, a pad button and a click on entry `id` do. Nothing for an unknown id, a disabled
## entry or while closed.
func choose(id: StringName) -> void:
	if not _is_open:
		return
	var index: int = _ids.find(id)
	if index < 0 or _buttons[index].disabled:
		return
	entry_chosen.emit(id)


## The three below change the menu in place: the focus stays where it is, also on a disabled entry.
func set_body(text: String) -> void:
	_body_label.text = text
	_body_label.visible = not text.is_empty()


## Nothing for an unknown id.
func set_entry_text(id: StringName, text: String) -> void:
	var index: int = _ids.find(id)
	if index >= 0:
		_buttons[index].text = text


## Nothing for an unknown id.
func set_entry_enabled(id: StringName, enabled: bool) -> void:
	var index: int = _ids.find(id)
	if index >= 0:
		_buttons[index].disabled = not enabled


## True from `open()` until `choose_guard_seconds` of real time have passed: the entries ignore the
## mouse and `ui_accept` / `interact` choose nothing.
func is_choose_guarded() -> bool:
	return _choose_guarded


func get_heading() -> String:
	return _heading_label.text


func get_body() -> String:
	return _body_label.text


## The entries' ids in the order shown.
func get_entry_ids() -> Array[StringName]:
	return _ids.duplicate()


## Empty for an unknown id.
func get_entry_text(id: StringName) -> String:
	var index: int = _ids.find(id)
	return _buttons[index].text if index >= 0 else ""


## False for an unknown id.
func is_entry_enabled(id: StringName) -> bool:
	var index: int = _ids.find(id)
	return index >= 0 and not _buttons[index].disabled


## The id of the focused entry; empty when the panel has none.
func get_focus_id() -> StringName:
	if _focus_index < 0 or _focus_index >= _ids.size():
		return &""
	return _ids[_focus_index]


func _on_cancel_pressed() -> void:
	cancelled.emit()


## ListMenu's question before a key or the pad chooses: not during the guard.
func _may_choose_by_key() -> bool:
	return not _choose_guarded


## A mouse button event the OS marked as the second press of a double click.
func _is_double_click(event: InputEvent) -> bool:
	var button: InputEventMouseButton = event as InputEventMouseButton
	return button != null and button.double_click


func _start_choose_guard() -> void:
	_choose_guarded = choose_guard_seconds > 0.0
	set_process(_choose_guarded)
	if not _choose_guarded:
		return
	_choose_guard_until_msec = Time.get_ticks_msec() + roundi(choose_guard_seconds * 1000.0)
	for button: Button in _buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _end_choose_guard() -> void:
	_choose_guarded = false
	set_process(false)
	for button: Button in _buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP
