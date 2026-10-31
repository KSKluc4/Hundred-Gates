---
id: F-002
title: Studio autopilot (tools/studio)
status: PLAN_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-10-31
updated: 2026-10-31
depends_on: [F-000, D-003, D-004]
pillars: []              # studio infrastructure
department: Direction      # infrastructure
---

# F-002 — Studio autopilot (tools/studio)

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Outcome (one sentence):**
Lucas approves a plan, walks away, and the next thing he hears is a notification that the
feature is ready to play — or that something needs him; every step between his two gates
runs by itself, safely and visibly.

**Why now:** F-000 and F-001 needed ~25 manual handoffs (copy a line to Codex, paste a
result here, run a sed block…). Each one is a chance for a mistake — F-001 already had an
unrelated whitespace change slip into a commit through `git add -A`. Automating before
more gameplay features multiplies everything after it.

**Out of scope (explicitly):**
- Automating Gate A or Gate B. Both stay human (Lucas's decision). Only *helper commands*
  that perform the Gate's git/file steps after Lucas runs them.
- Design conversations with departments (chat stays human).
- Cloud execution (GitHub Actions, remote runners). Local Mac only.
- Running several features in parallel. One agent at a time.
- Any change to game code under `src/`, `scenes/`, `data/`.

---

## 2. Context  ·  _Planner_

- The pipeline is a state machine already: each feature file's frontmatter has `status`
  and `owner_now`; `studio/STATUS.md` mirrors them. Roles and rules: `studio/README.md`,
  `CLAUDE.md` (Builder), `AGENTS.md` (Auditor), `studio/departments/`.
- Both agent CLIs are installed and logged in on Lucas's Mac and have non-interactive
  modes: Claude Code (`claude -p "<prompt>"`) and Codex (`codex exec "<prompt>"`). **Exact
  flags differ by version**: the Builder checks `claude --help` and `codex exec --help` on
  the machine, picks the least-privilege flags that let each role do its job, and records
  them in `README.md` (log as ASSUMPTION in §8).
- Python 3 is already required (D-004). The tool uses the **standard library only** (G4).
- Lessons from F-000/F-001 the tool must encode: commit only expected files; push a
  feature branch before deleting it; Godot needs to write to `~/Library/Application
  Support` when checks run; agents may run long (an F-001 build took ~40 min).

---

## 3. Options Considered  ·  _Planner_

### ✅ Chosen: Deterministic local orchestrator (`tools/studio`, Python stdlib)
- **How it works:** A script reads a feature's `status`/`owner_now`, maps it to exactly one
  action (table in C3), runs that agent non-interactively with a fixed prompt, then checks
  what changed (files, status, tests) before allowing the next step. It stops and notifies
  Lucas whenever `owner_now: Lucas`, something is off, or a limit is hit.
- **Why chosen:** Every decision is in code that the Auditor can review and tests can
  cover. Agents still do the creative work, but they can't skip a gate, loop forever, or
  commit something outside their lane.
- **Costs we're accepting:** Runs only while the Mac is awake with the CLIs logged in. Each
  automated step spends Claude/ChatGPT plan quota exactly as a manual one would.
- **Would revisit if:** Lucas regularly wants work to continue while the Mac is off.

### ❌ Rejected: One agent orchestrating the others (e.g. Claude Code calling `codex` itself)
- **Why rejected:** The orchestration rules would live in a prompt, not in code. An agent
  can improvise: skip a review, "fix" a gate, edit another role's section. Not testable.
- **Tempting because:** Almost no code to write.

### ❌ Rejected: GitHub Actions / cloud runners
- **Why rejected:** Needs API keys with separate billing, Godot on CI, secrets management,
  and loses Lucas's logged-in subscriptions. Large setup for a solo studio in phase 1.
- **Tempting because:** Works while the Mac sleeps.

### ❌ Rejected: Auto-approving Gate A when the Auditor approves
- **Why rejected:** Gate A is where Lucas catches a plan that is correct but not what he
  wanted. It takes a minute. Director's call: gates stay human.
- **Tempting because:** Fully hands-off pipeline.

---

## 4. Constraints  ·  _Planner_

| ID | Constraint | Reason |
|---|---|---|
| C1 | Python 3 standard library only; no new dependencies, no edits to `src/`, `scenes/`, `data/`, `addons/`. | G4, scope |
| C2 | Never sets `APPROVED` or `DONE` on its own. Those only happen inside `tools/studio approve` / `done`, which Lucas runs by hand. | Gates are human |
| C3 | **Action table** (the only actions `run` may take): `PLAN_REVIEW`+`Auditor` → Codex, Mode A. `PLAN_CHANGES`+`Planner` → Claude as **Direction** (structural findings) or **the feature's department** (gameplay findings), per `studio/departments/README.md` "Who to call"; one Claude call that reads the relevant brief(s). `APPROVED`+`Builder`, `IN_PROGRESS`+`Builder`, `CODE_CHANGES`+`Builder` → Claude Code as Builder. `CODE_REVIEW`+`Auditor` → Codex, Mode B. Anything with `owner_now: Lucas`, `DRAFT`, `DONE`, `PARKED`, or an unknown value → stop and notify. | Pipeline rules |
| C4 | **Lane allowlists**, checked after every step against `git status`: Auditor may change only the feature file and `studio/STATUS.md`. Planner/Direction may change only the feature file, `studio/STATUS.md`, `studio/DECISIONS.md` (new PROPOSED entries only), `studio/design/*.md`, `studio/GLOSSARY.md`. Builder: anything except `studio/departments/`, `studio/DECISIONS.md`, `AGENTS.md`. Any change outside the lane — **including whitespace-only changes** — stops the run, leaves the changes uncommitted, and the notification lists the files. The tool never auto-reverts. | F-001 whitespace incident |
| C5 | The tool commits Auditor and Planner steps itself, staging **only** allowlisted paths explicitly (never `git add -A`). Builder commits are the Builder's own (per `CLAUDE.md`); the tool only verifies the tree is clean afterwards. Commit messages: `F-XXX: Auditor plan review round N` etc. | Traceable history |
| C6 | **Progress check:** if a step ends with the same `status` and `owner_now` it started with, the run stops ("stuck"). | No silent loops |
| C7 | **Round caps:** max 3 plan-review rounds and 3 code-review rounds per feature (counted from the `**Round:** N` markers in §7/§9). Hitting a cap sets `owner_now: Lucas`, appends a §10 row explaining why, and notifies. | Cost + ping-pong guard |
| C8 | **Step cap:** `run` performs at most 8 agent steps per invocation (configurable with `--max-steps`). | Quota guard |
| C9 | After every Builder step that ends in `CODE_REVIEW`, the tool runs `tools/test`, `tools/lint`, `tools/check_core_purity` itself; any failure stops the run and notifies (status left as the Builder set it). | Trust but verify |
| C10 | One run at a time: lock file `.studio/lock` (with PID; a stale lock from a dead PID is cleared with a warning). | Two agents on one tree = chaos |
| C11 | Before any step the working tree must be clean (except `.studio/`); otherwise refuse to start and say which files are dirty. Runs on the branch the role expects: Auditor Mode A / Planner on `main`; Builder and Mode B on `feature/F-XXX-<slug>` (created by the Builder per `CLAUDE.md`). | Same-tree safety |
| C12 | Every agent call writes its full output to `.studio/logs/F-XXX/<UTC timestamp>-<role>.log`. `.studio/` is gitignored. Agent binaries come from `$STUDIO_CLAUDE_BIN` / `$STUDIO_CODEX_BIN` (default `claude` / `codex`) so tests can use fakes. | Debuggable, testable |
| C13 | Notifications: always macOS (`osascript` display notification) when available; additionally `ntfy.sh` push to the phone if `$STUDIO_NTFY_TOPIC` is set. Notification failure never fails the run. Message = feature, what happened, one exact next command for Lucas. | Lucas needs one clear next step |
| C14 | Agent prompts are fixed templates in `tools/studio_prompts/*.md` (one per role/mode), containing only the feature path and pointers to the role files — never a summary of the feature. | Core rule: hand off files, not summaries |

**Must not break:** `tools/test`, `tools/lint`, core purity, and every existing studio
file format.

---

## 5. Acceptance Criteria  ·  _Planner_

Automated tests live in `tools/tests/` (stdlib `unittest`), run by a new `tools/test_studio`,
using fake agent scripts (via C12 env vars) in a temporary git repo fixture.

- [ ] AC1 — `tools/studio status` prints every feature's id, title, status, owner_now and
      flags any mismatch with `studio/STATUS.md`.
- [ ] AC2 — `tools/studio next F-XXX` (dry run) prints the single action C3 would take,
      for every status/owner combination in C3, including the stop cases.
- [ ] AC3 — With fakes that move statuses correctly, `tools/studio run F-XXX` starting at
      `PLAN_REVIEW` performs Auditor → (Planner → Auditor) → stops at `owner_now: Lucas`,
      committing each non-Builder step with only allowlisted files, and sends one
      notification. Same for `APPROVED` → Builder → Auditor Mode B → stop.
- [ ] AC4 — Stuck step (C6), round cap (C7, including the §10 row), step cap (C8) each stop
      the run with the right notification.
- [ ] AC5 — Lane violation (C4): a fake Auditor that also edits `src/x.gd`, and one that
      only changes whitespace in `studio/DECISIONS.md`, both stop the run; nothing is
      committed; the notification lists the files.
- [ ] AC6 — Red checks after a Builder step (C9) stop the run.
- [ ] AC7 — Lock (C10): a second `run` exits non-zero while one is active; a stale lock is cleared.
- [ ] AC8 — Dirty tree / wrong branch (C11) refuses to start with a clear message.
- [ ] AC9 — `tools/studio approve F-XXX`: only allowed when `status: PLAN_REVIEW`,
      `owner_now: Lucas` and the latest §7 verdict is `APPROVE` or `APPROVE_WITH_NOTES`.
      Optional `--note "..."` appended to §11. Sets `APPROVED`/`Builder`, updates STATUS.md,
      commits only those two files, pulls with rebase, pushes.
- [ ] AC10 — `tools/studio done F-XXX`: only allowed when `status: CODE_REVIEW`,
      `owner_now: Lucas` and the latest §9 verdict is `APPROVE`/`APPROVE_WITH_NOTES`.
      Optional `--note`. Commits the Auditor's review if uncommitted (allowlisted files
      only), sets `DONE`, pushes the feature branch, merges `--no-ff` into `main`, pushes
      `main`, then deletes the local and remote feature branch. Never needs `-D`.
- [ ] AC11 — Logs written per C12; prompts loaded from `tools/studio_prompts/` (C14).
- [ ] AC12 — `tools/test`, `tools/lint`, core purity still pass; `tools/test_studio` passes.
- [ ] AC13 — Docs: `README.md` gets an "Autopilot" section (setup, env vars, the CLI flags
      chosen and why, commands); `studio/prompts/handoffs.md` points to the new commands.

**How to verify manually:**
1. `tools/studio status` and `tools/studio next F-002` on the real repo.
2. Send yourself a test notification: `tools/studio notify-test` (Mac; and phone if
   `STUDIO_NTFY_TOPIC` is set).
3. The real test is the next gameplay feature (F-003): after its spec is committed,
   run `tools/studio run F-003`, walk away, and come back to a notification.

---

## 6. Task Breakdown  ·  _Planner_

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Feature file parsing (frontmatter, §7/§9 round + verdict, §10 append, §11 append) and STATUS.md row update | `tools/studio_lib/feature.py` | Pure functions, fully unit-tested. |
| T2 | Git helpers: clean-tree check, changed files, allowlist check, explicit-path commit, branch checks, push/merge/delete | `tools/studio_lib/git.py` | Never `git add -A`. |
| T3 | Action table + run loop (C3, C6–C9) | `tools/studio_lib/engine.py` | Agent invocation via C12 env vars. |
| T4 | Agent prompt templates | `tools/studio_prompts/*.md` | auditor_plan, auditor_code, planner, builder. File pointers only (C14). |
| T5 | Notifications | `tools/studio_lib/notify.py` | C13 + `notify-test`. |
| T6 | CLI entry point | `tools/studio` | `status`, `next`, `run`, `approve`, `done`, `notify-test`; lock (C10); logs (C12). |
| T7 | Tests + runner | `tools/tests/`, `tools/test_studio` | Temp git repo fixture + fake agents. |
| T8 | Docs + gitignore | `README.md`, `studio/prompts/handoffs.md`, `.gitignore` | AC13; `.studio/` ignored. |

---

## 7. Plan Review  ·  _Auditor_

**Verdict:** `PENDING` <!-- APPROVE | APPROVE_WITH_NOTES | CHANGES_REQUESTED -->
**Reviewed:** YYYY-MM-DD

Findings (severity: 🔴 blocking · 🟡 should fix · 🔵 suggestion):

### PR-1 🔴 <title>
<What's wrong, where, why it matters, what you'd suggest.>
> **Planner reply:** <accepted / rejected + reason / changed §X>

---

## 8. Implementation Log  ·  _Builder_

**Started:** YYYY-MM-DD  ·  **Branch:** `feature/F-002-studio-autopilot`

### Progress
- [ ] T1 — <commit hash when done>
- [ ] T2

### Deviations from plan
<Every place the code differs from §3–§6, with reason. "None" if none.>
- DEV-1: <what changed> — **Why:** <reason> — **Impact:** <what else this affects>

### Assumptions made (small, reversible)
- ASSUMPTION-1: <the gap in the spec> → <what I chose> — **Why:** <reason>

### Things the Auditor should look at closely
- <tricky spots, edge cases you're unsure about>

### How to test
<exact steps / commands / scene to run>

---

## 9. Code Review  ·  _Auditor_

**Verdict:** `PENDING` <!-- APPROVE | APPROVE_WITH_NOTES | CHANGES_REQUESTED -->
**Reviewed commit:** <hash>  ·  **Round:** 1

### Checklist
- [ ] Every AC in §5 met (state evidence per AC below)
- [ ] No Rejected option from §3 implemented, even partially
- [ ] All constraints in §4 and PROJECT.md respected
- [ ] Every deviation in §8 is justified; no undocumented deviations
- [ ] Assumptions in §8 are sane

### AC evidence
- AC1: ✅/❌ <where in the code / how verified>

### Findings
### CR-1 🔴 <title>  ·  `path/to/file:line`
<problem, why it matters, suggested fix>
> **Builder reply:** <fixed in abc123 / disagree because …>

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | | | yes/no | |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
