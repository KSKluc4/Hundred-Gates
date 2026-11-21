class_name ShellMenus
extends RefCounted
## F-015/C10: every text, entry id and default focus of every menu of the shell (F-012/C16's rule:
## no player-facing string anywhere else). Static functions and constants only: they take plain
## values (the state, the one before it, texts, bools), never nodes, and return plain values, so
## the shell hands them to the MenuPanel and decides nothing here. PLAYING has no menu: its
## heading, body and focus are empty and it has no entries.

## The entry ids. The shell reacts to these, never to a text.
const START: StringName = &"start"
const SETTINGS: StringName = &"settings"
const QUIT: StringName = &"quit"
const RESUME: StringName = &"resume"
const LEAVE: StringName = &"leave"
const QUIT_TO_TITLE: StringName = &"quit_to_title"
const SHAKE: StringName = &"shake"
const FULLSCREEN: StringName = &"fullscreen"
const BACK: StringName = &"back"
const CONFIRM: StringName = &"confirm"
const CANCEL: StringName = &"cancel"
const RETURN: StringName = &"return"

## Headings.
const TITLE_HEADING: String = "Hundred Gates"
const PAUSED_HEADING: String = "Paused"
const SETTINGS_HEADING: String = "Settings"
const CONFIRM_LEAVE_HEADING: String = "Return to town?"
const CONFIRM_QUIT_HEADING: String = "Quit to title?"
const DEAD_HEADING: String = "You died"

## Bodies. The title's is empty unless a Start failed (C16): one line, with the number of errors.
const START_FAILED_FORMAT: String = "Could not start: the game data has %d error(s). See the log."
const CONFIRM_LEAVE_BODY: String = (
	"This floor's rooms start over next time. " + "Floors you cleared and bosses you reached stay."
)
const CONFIRM_QUIT_BODY: String = "Progress is not saved yet. Everything you unlocked will be lost."
## The last line of the death screen, after the HUD's location line and its kills line.
const KEEP_LINE: String = "You keep everything you unlocked."

## Entry texts.
const START_TEXT: String = "Start"
const SETTINGS_TEXT: String = "Settings"
const QUIT_TEXT: String = "Quit"
const RESUME_TEXT: String = "Resume"
const LEAVE_TEXT: String = "Return to town"
const QUIT_TO_TITLE_TEXT: String = "Quit to title"
const SHAKE_ON_TEXT: String = "Screen shake: On"
const SHAKE_OFF_TEXT: String = "Screen shake: Off"
const FULLSCREEN_ON_TEXT: String = "Fullscreen: On"
const FULLSCREEN_OFF_TEXT: String = "Fullscreen: Off"
const BACK_TEXT: String = "Back"
const CONFIRM_LEAVE_TEXT: String = "Return to town"
const KEEP_FIGHTING_TEXT: String = "Keep fighting"
const CONFIRM_QUIT_TEXT: String = "Quit to title"
const CANCEL_TEXT: String = "Cancel"
const RETURN_TEXT: String = "Return to town"


## The heading of `state`'s menu; empty for PLAYING.
static func heading(state: ShellFlow.State) -> String:
	match state:
		ShellFlow.State.TITLE:
			return TITLE_HEADING
		ShellFlow.State.PAUSED:
			return PAUSED_HEADING
		ShellFlow.State.SETTINGS:
			return SETTINGS_HEADING
		ShellFlow.State.CONFIRM_LEAVE:
			return CONFIRM_LEAVE_HEADING
		ShellFlow.State.CONFIRM_QUIT:
			return CONFIRM_QUIT_HEADING
		ShellFlow.State.DEAD:
			return DEAD_HEADING
		_:
			return ""


## The body of `state`'s menu; empty when it has none. `location_text` and `kills_text` are the
## HUD's two lines (the death screen's; the kills one is empty in the town and in a boss room) and
## `start_error_count` is how many errors the last Start failed with (the title's; 0 for none).
static func body(
	state: ShellFlow.State, location_text: String, kills_text: String, start_error_count: int
) -> String:
	match state:
		ShellFlow.State.TITLE:
			return START_FAILED_FORMAT % start_error_count if start_error_count > 0 else ""
		ShellFlow.State.CONFIRM_LEAVE:
			return CONFIRM_LEAVE_BODY
		ShellFlow.State.CONFIRM_QUIT:
			return CONFIRM_QUIT_BODY
		ShellFlow.State.DEAD:
			var lines: Array[String] = [location_text]
			if not kills_text.is_empty():
				lines.append(kills_text)
			lines.append(KEEP_LINE)
			return "\n".join(lines)
		_:
			return ""


## The entries of `state`'s menu, in order, freshly made. `on_floor` is whether the session is on a
## floor (only then the pause menu offers the way back to town), `shake_enabled` and `fullscreen`
## are the settings the settings menu shows, `can_confirm_death` enables the death screen's entry.
static func entries(
	state: ShellFlow.State,
	on_floor: bool,
	shake_enabled: bool,
	fullscreen: bool,
	can_confirm_death: bool
) -> Array[MenuEntry]:
	var list: Array[MenuEntry] = []
	match state:
		ShellFlow.State.TITLE:
			list.append(MenuEntry.make(START, START_TEXT))
			list.append(MenuEntry.make(SETTINGS, SETTINGS_TEXT))
			list.append(MenuEntry.make(QUIT, QUIT_TEXT))
		ShellFlow.State.PAUSED:
			list.append(MenuEntry.make(RESUME, RESUME_TEXT))
			if on_floor:
				list.append(MenuEntry.make(LEAVE, LEAVE_TEXT))
			list.append(MenuEntry.make(SETTINGS, SETTINGS_TEXT))
			list.append(MenuEntry.make(QUIT_TO_TITLE, QUIT_TO_TITLE_TEXT))
		ShellFlow.State.SETTINGS:
			list.append(MenuEntry.make(SHAKE, shake_text(shake_enabled)))
			list.append(MenuEntry.make(FULLSCREEN, fullscreen_text(fullscreen)))
			list.append(MenuEntry.make(BACK, BACK_TEXT))
		ShellFlow.State.CONFIRM_LEAVE:
			list.append(MenuEntry.make(CONFIRM, CONFIRM_LEAVE_TEXT))
			list.append(MenuEntry.make(CANCEL, KEEP_FIGHTING_TEXT))
		ShellFlow.State.CONFIRM_QUIT:
			list.append(MenuEntry.make(CONFIRM, CONFIRM_QUIT_TEXT))
			list.append(MenuEntry.make(CANCEL, CANCEL_TEXT))
		ShellFlow.State.DEAD:
			list.append(MenuEntry.make(RETURN, RETURN_TEXT, can_confirm_death))
	return list


## The entry focused when `state`'s menu opens, having come from `previous` (what the flow's
## `state_changed` says). Forwards it is the table's default; on the way back it is the entry that
## led away from the menu, so the player lands where they left. Empty for PLAYING.
static func focus(state: ShellFlow.State, previous: ShellFlow.State) -> StringName:
	match state:
		ShellFlow.State.TITLE:
			return SETTINGS if previous == ShellFlow.State.SETTINGS else START
		ShellFlow.State.PAUSED:
			match previous:
				ShellFlow.State.SETTINGS:
					return SETTINGS
				ShellFlow.State.CONFIRM_LEAVE:
					return LEAVE
				ShellFlow.State.CONFIRM_QUIT:
					return QUIT_TO_TITLE
				_:
					return RESUME
		ShellFlow.State.SETTINGS:
			return SHAKE
		ShellFlow.State.CONFIRM_LEAVE, ShellFlow.State.CONFIRM_QUIT:
			return CANCEL
		ShellFlow.State.DEAD:
			return RETURN
		_:
			return &""


## The settings entry's text, for rewriting it in place after a choice.
static func shake_text(enabled: bool) -> String:
	return SHAKE_ON_TEXT if enabled else SHAKE_OFF_TEXT


static func fullscreen_text(enabled: bool) -> String:
	return FULLSCREEN_ON_TEXT if enabled else FULLSCREEN_OFF_TEXT
