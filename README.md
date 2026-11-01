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

## Autopilot

`tools/studio` runs the pipeline between the Director's two gates (`studio/README.md`,
F-002): it reads a feature's `status` and `owner_now`, runs the one agent that state calls
for, checks everything that agent changed, and stops with a notification when Lucas is
needed. It runs locally, one agent at a time. `run` keeps an idle Mac awake with `caffeinate`;
closing the lid still puts it to sleep, and the run continues when it wakes.

### Setup

Needs Python 3 (standard library only), and `claude` and `codex` installed and logged in.
`.studio/` holds the lock, logs and blocked markers, and is gitignored.

| Env var | Default | Meaning |
|---|---|---|
| `STUDIO_CLAUDE_BIN` | `claude` | Claude Code binary |
| `STUDIO_CODEX_BIN` | `codex` | Codex binary |
| `STUDIO_NTFY_TOPIC` | unset | Also send notifications to this topic. **Topics on ntfy.sh are public: pick an unguessable name** |
| `STUDIO_NTFY_SERVER` | `https://ntfy.sh` | ntfy server |
| `STUDIO_KILL_GRACE_SECONDS` | `30` | Wait between SIGTERM and SIGKILL |

### Commands

| Command | What it does |
|---|---|
| `tools/studio status` | Every feature: state, blocked flag, mismatches |
| `tools/studio next F-XXX` | What `run` would do, and the next command |
| `tools/studio run F-XXX` | Runs agent steps until Lucas is needed. `--max-steps N` (8), `--timeout MINUTES` per call (90) |
| `tools/studio run --resume F-XXX` | Continues an `IN_PROGRESS` feature |
| `tools/studio approve F-XXX [--note TEXT]` | Gate A: Lucas only |
| `tools/studio done F-XXX [--note TEXT]` | Gate B: Lucas only. Merges, pushes, deletes the branches |
| `tools/studio unblock F-XXX` | Clears a blocked feature |
| `tools/studio notify-test` | Sends a test notification |
| `tools/test_studio` | The tool's own tests |

Only `approve` and `done` push. Every other command works locally.

### Agent flags

Chosen from `claude --help` (2.1.316) and `codex exec --help` (0.166.0), least privilege per
role:

| Role | Command |
|---|---|
| Builder | `claude -p <prompt> --allowedTools Bash Read Edit Write Glob Grep --disallowedTools "Bash(git push *)" "Bash(git checkout *)" "Bash(git switch *)" "Bash(git branch *)" "Bash(git rebase *)" "Bash(git reset *)" --permission-mode dontAsk --no-session-persistence` |
| Planner | `claude -p <prompt> --tools Read,Edit,Write,Glob,Grep --allowedTools Read,Edit,Write,Glob,Grep --permission-mode dontAsk --no-session-persistence` |
| Auditor | `codex exec --sandbox workspace-write -c sandbox_workspace_write.network_access=false --cd <repo> <prompt>` |

Every call also runs with `remote.origin.pushurl` overridden to an invalid URL through
`GIT_CONFIG_*`, and with `GIT_TERMINAL_PROMPT=0`.

### Recovery

Every stop prints one next command, and notifications carry the same command.

- **Blocked feature** (`tools/studio status` says `BLOCKED`): a step was rejected, or an agent
  failed, timed out or was interrupted. Nothing was committed by the tool and history isn't
  rewritten. The reason, commits, paths and log are in `.studio/blocked/F-XXX.json`. Fix the
  tree, then `tools/studio unblock F-XXX`. If the remote didn't change, the recovery is
  local: the notification's `git reset --hard <start> && git clean -fd && tools/studio unblock
  F-XXX`. It also restores any other local branch the agent created, moved or deleted, since a
  gate pushes whatever local `main` holds.
- **The remote changed during a step:** `git push` to `origin` is blocked inside agents, but a
  push to an explicit URL can only be detected, not prevented. This is the one case that
  needs a force-push, and the notification gives the exact command.
- **The remote couldn't be checked after a step:** the feature is blocked as if it may have
  changed. The recovery starts with `git ls-remote --refs origin | diff
  .studio/blocked/F-XXX.remote -`. That stops the rest while the remote is unreachable or
  differs from before the step, and any difference it prints is what to repair by hand.
- **`approve` or `done` failed partway:** run the same command again. Finished steps are
  skipped. `done` deletes branches only after `origin/main` is verified to hold the work.
- **Merge conflict in `done`:** `git merge --abort`, fix `main`, run `done` again.
- **`IN_PROGRESS` with `owner_now: Lucas`:** answer the blocking §10 row and commit it, then
  `tools/studio run --resume F-XXX`.
- **Review or readiness cap reached:** the feature stops at Lucas with a blocking §10 row, after
  3 review rounds or 3 consecutive red checks. Decide it there, finish the work by hand, and
  set the status yourself.
