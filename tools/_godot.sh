#!/usr/bin/env bash
# Shared helpers for tools/*. Sourced by the other scripts, never run directly.

REQUIRED_GODOT_VERSION="4.7.2.stable"
MACOS_GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# F-000/C8: $GODOT_BIN, then `godot` on PATH, then the macOS app. Prints the path.
resolve_godot() {
	if [ -n "${GODOT_BIN:-}" ]; then
		if [ -x "$GODOT_BIN" ]; then
			echo "$GODOT_BIN"
			return 0
		fi
		echo "error: GODOT_BIN is set to '$GODOT_BIN', which is not an executable file." >&2
		return 1
	fi
	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return 0
	fi
	if [ -x "$MACOS_GODOT_BIN" ]; then
		echo "$MACOS_GODOT_BIN"
		return 0
	fi
	echo "error: Godot not found. Set GODOT_BIN to your Godot binary, e.g." >&2
	echo "  export GODOT_BIN=/path/to/godot" >&2
	return 1
}

# Refreshes Godot's import and class caches. `--import` restores the editor's open tabs and
# saves them on exit, which rewrites the indentation of any text file left open there
# (F-002 §8). So it runs with the tab list hidden, and the list comes back afterwards.
godot_import() {
	local godot="$1"
	local layout="$PROJECT_ROOT/.godot/editor/editor_layout.cfg"
	local hidden="$layout.hidden-for-import"
	local status=0
	if [ -f "$hidden" ]; then
		mv -f "$hidden" "$layout" # Left behind by an interrupted run.
	fi
	if [ -f "$layout" ]; then
		mv "$layout" "$hidden"
	fi
	"$godot" --headless --path "$PROJECT_ROOT" --import >/dev/null || status=$?
	if [ -f "$hidden" ]; then
		mv -f "$hidden" "$layout"
	fi
	return "$status"
}
