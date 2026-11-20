class_name MenuPanel
extends ListMenu
## F-015/C10: the one panel every menu of the shell uses: a heading, a body text (hidden when it
## is empty) and a column of entries. It shows what it is told and decides nothing (G6): the shell
## opens it with what ShellMenus says for the flow's state and answers `entry_chosen` and
## `cancelled`. A key, a pad button and a click all end in `choose(id)` (a click is the button's
## own `pressed`). Neither signal closes the panel: the shell decides what is shown next. Hidden
## until open(), and while closed it handles no input. Keys, d-pad, stick and the disabled entry
## are ListMenu's.
## The look → Art & Game Feel (F-015 §10 Q5).

## Once per choice of an enabled entry, with its id. Not emitted by a disabled or unknown one.
signal entry_chosen(id: StringName)
## `ui_cancel` while open. What it means (back one step, nothing) is the shell's.
signal cancelled

@export var heading_font_size: int = 8
## The gap between the heading, the body and the entries.
@export var content_separation_px: int = 4

var _ids: Array[StringName] = []

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
