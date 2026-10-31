# Hundred Gates

A top-down 2D action RPG where you climb a 100-floor tower. Built with Godot 4 and
GDScript. Vision, pillars and constraints live in [`studio/PROJECT.md`](studio/PROJECT.md);
how the project is run lives in [`studio/README.md`](studio/README.md).

## Requirements

| Tool | Version | Where it comes from |
|---|---|---|
| Godot | **4.7.2-stable** (standard build, not .NET) | Install it yourself: <https://godotengine.org/download/archive/4.7.2-stable/> |
| Python | 3 | Install it yourself. On macOS it comes with the Xcode Command Line Tools |
| git | any | Install it yourself |
| GUT | 9.7.1 | Vendored in `addons/gut/` (D-003), nothing to install |
| gdtoolkit | 4.5.0 | Installed into `.venv/` by `tools/setup` (D-004) |

### Finding Godot

The `tools/` scripts look for Godot in this order:

1. `$GODOT_BIN`
2. `godot` on your `PATH`
3. `/Applications/Godot.app/Contents/MacOS/Godot`

If Godot is anywhere else, point `GODOT_BIN` at it:

```sh
export GODOT_BIN=/path/to/godot
```

## Setup

```sh
git clone https://github.com/KSKluc4/Hundred-Gates.git
cd Hundred-Gates
tools/setup
```

`tools/setup` checks the Godot version, creates `.venv/`, installs gdtoolkit and builds
Godot's import cache. It is safe to run again.

## Running the game

Open the project in Godot and press F5, or run `godot --path .` from the repo root.
F3 shows or hides the debug overlay. Set `debug_overlay_visible_on_start` on
`data/tunables/game_tunables.tres` in the inspector to choose its starting state.

## Checks

Run these before every commit:

| Command | What it does |
|---|---|
| `tools/test` | Runs the GUT tests headless. Add GUT flags to narrow it: `tools/test -gtest=res://tests/core/test_game_tunables.gd` |
| `tools/lint` | Runs `gdlint` and `gdformat --check` on `src/` and `tests/` |
| `tools/check_core_purity` | Checks that `src/core/` stays free of scene and visual code (G6) |
| `tools/check_core_purity --self-test` | Proves the purity check trips on every rule, using `tests/fixtures/core_purity/` |

To fix formatting, run `.venv/bin/gdformat src tests`.
