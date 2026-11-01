---
id: F-002
title: Studio autopilot (tools/studio)
status: IN_PROGRESS   # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Builder       # who must act next: Planner | Auditor | Builder | Lucas
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
- (In scope, by exception: the role-instruction updates in T9 — `CLAUDE.md`, `AGENTS.md`,
  department briefs, feature template — needed so automated calls don't contradict them.)

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

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

### 4.1 General
| ID | Constraint | Reason |
|---|---|---|
| C1 | Python 3 standard library only; no new dependencies; no edits to `src/`, `scenes/`, `data/`, `addons/`. | G4, scope |
| C2 | **Nothing but a gate command ever produces `APPROVED` or `DONE`, or edits §11.** If an agent step produces either status or touches §11, the step is rejected (C5). | Gates are human (PR-3) |
| C3 | **No pushes outside gates.** `run` never pushes; only `approve` and `done` push. Agent children are prevented too (PR-14): each call runs with env `GIT_CONFIG_COUNT/KEY/VALUE` overriding `remote.origin.pushurl` to an invalid URL (so `git push` fails), `GIT_TERMINAL_PROMPT=0`, and the CLI's own denial (Claude: `git push` disallowed; Codex: sandbox without network, or equivalent — exact flags in `README.md`). **Detection backstop:** the tool records `git ls-remote origin` before the step and compares after; any remote change rejects the step, blocks the feature, and the notification gives the exact remote recovery (the only case that needs a force-push by Lucas). | Containment (PR-14) |
| C4 | **One shared lock** `.studio/lock` for every mutating command (`run`, `approve`, `done`, `unblock`), held from validation through completion or failure. It records the tool PID and the agent's process-group id. A lock is stale only if neither is alive; then it is cleared with a warning. `status`, `next`, `notify-test` take no lock. | PR-10, PR-9 |

### 4.2 Dispatch and transitions
| ID | Constraint | Reason |
|---|---|---|
| C5 | **Action table — input → agent → the only accepted outputs.** Any other output (status, owner, verdict, board row, branch) rejects the step: nothing is committed, no further agent runs, the feature is marked blocked (C11), Lucas is notified. <br>**A. Plan audit:** `PLAN_REVIEW`+`Auditor`, on `main` → Codex Mode A → (`PLAN_CHANGES`, `Planner`) with new round verdict `CHANGES_REQUESTED`, or (`PLAN_REVIEW`, `Lucas`) with `APPROVE`/`APPROVE_WITH_NOTES`. <br>**B. Plan repair:** `PLAN_CHANGES`+`Planner`, on `main` → Claude as Planner (C8) → (`PLAN_REVIEW`, `Auditor`), or escalation (`PLAN_CHANGES`, `Lucas`) with a new blocking §10 row. <br>**C. Build / fix:** `APPROVED`+`Builder` or `CODE_CHANGES`+`Builder` (or `IN_PROGRESS` via C22 only), on the feature branch (C7) → Claude Code as Builder → (`CODE_REVIEW`, `Auditor`), or escalation (`IN_PROGRESS`, `Lucas`) with a new blocking §10 row. <br>**D. Code audit:** `CODE_REVIEW`+`Auditor`, on the feature branch, **only after checks pass (C14)** → Codex Mode B → (`CODE_CHANGES`, `Builder`) with `CHANGES_REQUESTED`, or (`CODE_REVIEW`, `Lucas`) with `APPROVE`/`APPROVE_WITH_NOTES`; the new round's "Reviewed commit" must equal the branch HEAD the Auditor was given. <br>**Stop and notify (no agent):** `owner_now: Lucas`, `DRAFT`, `DONE`, `PARKED`, `IN_PROGRESS` (only `run --resume` continues it — C22, which takes precedence over this stop rule), unknown values, or a blocked feature. | PR-2, PR-3 |
| C6 | **Consistency check before and after every step:** frontmatter `status`/`owner_now` = the feature's row in `STATUS.md`; the latest round's verdict matches the status per C5; current branch as expected. A mismatch at start refuses to run. | PR-3 |
| C7 | **Branches.** Before the first action C of a feature, the tool creates `feature/F-XXX-<slug>` (slug = feature file name) from the current `main` HEAD and checks it out; if it exists, it checks it out. Actions C and D run there; A and B on `main`. Agents must not create, switch or delete branches; any branch change rejects the step. `CLAUDE.md` is updated to say the branch is provided (T9). | PR-1 |
| C8 | **Role entry points (PR-2).** Each call's prompt starts with a line `STUDIO-ROLE: <Builder|Planner:<Department>|Auditor:ModeA|Auditor:ModeB>` and points to the role files; nothing else about the feature (core rule: files, not summaries). `CLAUDE.md` gains a top section: when the prompt starts with `STUDIO-ROLE: Planner:…`, the session is that department, follows its brief and `studio/prompts/autopilot-planner.md`, **edits files in place**, and the Builder rules don't apply except "never set APPROVED/DONE". Department briefs gain the same in-place rule for automated sessions. Planner department for action B = the feature's `department:`; it answers structure findings too, signing replies `Planner reply (<Department>)` — Direction-specific routing stays a chat-time convention. | PR-2 |
| C9 | **Round convention (PR-7).** Each completed review round starts with a machine line `<!-- review-round: N verdict: <VERDICT> -->` in §7 (plan) or §9 (code), written by the Auditor; N = previous max in that section + 1, starting at 1. `PENDING` placeholders and `**Round:**` text are ignored. Files without markers have 0 completed rounds. The template and `AGENTS.md` are updated (T9). | PR-7 |
| C10 | **Caps.** (a) Plan rounds and code review rounds: max 3 completed each (C9 markers). When the 3rd completed round is `CHANGES_REQUESTED`, the tool doesn't dispatch the repair: sets `owner_now: Lucas`, appends a §10 row, notifies. A 3rd round that approves proceeds. (b) **Readiness failures (PR-12):** each red C14 result appends a tool-owned §10 row containing `<!-- readiness-fail: N sha: <sha> -->`; N counts failures since the last completed code review round (durable in the file, survives restarts). The 3rd consecutive failure escalates to Lucas instead of dispatching the Builder. The two counters are independent; review markers stay Auditor-owned. (c) `run` performs at most `--max-steps` agent steps (default 8). (d) Progress check: a step that leaves status and owner unchanged is rejected as stuck. | PR-7, PR-12, cost |

### 4.3 What an agent may change (checked after every step)
| ID | Constraint | Reason |
|---|---|---|
| C11 | **Change detection (PR-4).** The tool records branch + HEAD before the step. After it, the changed set = paths in all new commits (`start..HEAD`) ∪ staged ∪ unstaged ∪ untracked (except `.studio/`). New history must be a fast-forward of the start HEAD on the same branch. Violations — including **whitespace-only** and including changes the agent **already committed** — reject the step: the tool never rewrites or reverts history, writes `.studio/blocked/F-XXX.json` (reason, offending commits/paths), and every mutating command refuses that feature until Lucas fixes it and runs `tools/studio unblock F-XXX`. Since `run` never pushes (C3), a local `git reset` is always enough. | PR-4 |
| C12 | **Path lanes.** Auditor: the feature file, `STATUS.md`. Planner: the feature file, `STATUS.md`, `DECISIONS.md`, `studio/design/*.md`, `GLOSSARY.md`. Builder: anything except `studio/departments/`, `studio/design/`, `DECISIONS.md`, `AGENTS.md`, `CLAUDE.md`, other features' files. | Lanes |
| C13 | **Content lanes inside allowed files (PR-5).** Compared line by line with the file before the step ("preserved" = every earlier line still present, in order): <br>• Frontmatter: agents may change only `status`, `owner_now`, `updated`. <br>• Auditor: §7 (Mode A) or §9 (Mode B) preserved + additions; §10 preserved + new rows; all other sections identical. <br>• Planner: §1–§6 free; §7 preserved + additions (replies); §10 preserved, except filling empty Answer cells, + new rows; §8, §9, §11 identical. <br>• Builder: §8 free; §9 preserved + additions (replies); §10 preserved + new rows; §1–§7 and §11 identical. <br>• `STATUS.md`: only this feature's row, only Status and Next-actor columns. <br>• `DECISIONS.md` (Planner only): every existing `## D-` entry byte-identical; new entries allowed only with `Status: PROPOSED`. | PR-5 |

### 4.4 Checks, failures, gates
| ID | Constraint | Reason |
|---|---|---|
| C14 | **Readiness evidence (PR-6, PR-11).** Before every action D and inside `done`, the tool runs `tools/test`, `tools/lint`, `tools/check_core_purity` **on a clean tree (C21) whose HEAD is the feature HEAD**, so the files tested are exactly the committed revision. Red → no Auditor call: the tool sets (`CODE_CHANGES`, `Builder`), appends the C10(b) §10 row, commits it (C16), and the next step dispatches the Builder. A restart can't skip this because the check runs before D, not after C. | PR-6, PR-11 |
| C15 | **Agent process failures (PR-9).** Each call runs in its own process group with a timeout (default 90 min, `--timeout`). Non-zero exit, launch/auth failure, timeout (SIGTERM to the group, SIGKILL after 30 s, then wait) or Ctrl-C on the tool (forwarded to the group, waited for) → the step is rejected like C5: edits kept, nothing committed, no further dispatch, lock released, feature blocked, notification with the log path. | PR-9 |
| C16 | **Tool commits.** After an accepted Auditor or Planner step, and for its own writes (C10, C14), the tool stages explicit paths only (never `git add -A`) with messages like `F-XXX: Auditor plan review round N`. Builder commits are the Builder's. | Traceable history |
| C17 | **`approve F-XXX [--note]`** — preconditions: not blocked; status `PLAN_REVIEW`, owner `Lucas`, latest §7 round approves; on `main`; tree clean. Steps (each skipped if already done, so a rerun resumes): 1. set `APPROVED`/`Builder`, row, optional §11 note, commit those two files; 2. `git pull --rebase`; 3. push. On failure: stop with the exact error and the same command as the recovery (`tools/studio approve F-XXX`). A rerun accepts status `APPROVED` while `origin/main` lacks the commit. | PR-8 |
| C18 | **`done F-XXX [--note]`** — preconditions: not blocked; status `CODE_REVIEW`, owner `Lucas`, latest §9 round approves; its "Reviewed commit" = feature HEAD, except later commits that touch only the feature file / `STATUS.md`; C14 checks pass on that HEAD (run at step 1b). Allowed dirty state at start: **only** the Auditor's uncommitted edits to the feature file and `STATUS.md`, validated with the Auditor lanes (C12, C13); anything else refuses. Steps (each skipped if already done): 1. commit those review edits (explicit paths) — the tree is now clean (C21); 1b. run C14 checks; 2. set `DONE`, optional §11 note, commit; 3. push feature branch; 4. checkout `main`, `pull --rebase`, `merge --no-ff` (skip if `main` already contains the feature HEAD); 5. push `main`; 6. verify `origin/main` contains the feature HEAD; 7. only then delete remote and local branch (`-d`, never `-D`). Any failure stops with state untouched and prints the exact recovery (rerun, or for a merge conflict: the conflicting files and `git merge --abort`). A rerun accepts status `DONE` while step 6 isn't satisfied **or** the local/remote feature branch still exists (PR-8); a branch that is already gone counts as deleted, so cleanup always resumes to success. | PR-6, PR-8 |
| C19 | Logs: every agent call writes full output to `.studio/logs/F-XXX/<UTC>-<role>.log`; `.studio/` gitignored. Binaries from `$STUDIO_CLAUDE_BIN` / `$STUDIO_CODEX_BIN` (default `claude` / `codex`); exact non-interactive flags chosen by the Builder from `--help` and recorded in `README.md`. | Debuggable, testable |
| C20 | Notifications: macOS `osascript` when available; plus `ntfy.sh` if `$STUDIO_NTFY_TOPIC` is set; failure never fails the command. Message = feature, what happened, **one exact next command**. | One next step |
| C21 | **Clean tree (PR-11).** "Clean" = `git status --porcelain` empty except `.studio/` (gitignored files like `.godot/`, `.venv/` don't count). Required: before `run` starts, before every agent step, before every C14 check, and before `approve`; `done` only allows its narrow exception (C18). After an accepted **Builder** step the tree must be clean — the Builder commits its own work; leftovers reject the step (C11). After an Auditor/Planner step only lane-valid edits may be dirty, and the tool commits them (C16) before anything else runs. | PR-11 |
| C22 | **Resume (PR-13).** `run --resume F-XXX` is the only way to continue `IN_PROGRESS`. Preconditions: clean tree, on the feature branch, and either `owner_now: Builder` (crash recovery) or `owner_now: Lucas` with **every blocking §10 row answered** (non-empty Answer). Effect: the tool sets `owner_now: Builder` (tool commit), then runs action C; its accepted outputs are the same as action C. Plain `run` on `IN_PROGRESS` always stops. | PR-13 |

**Must not break:** `tools/test`, `tools/lint`, core purity, existing studio file formats,
F-000/F-001 files (they have no round markers and are `DONE`; the tool never acts on them).

---

## 5. Acceptance Criteria  ·  _Planner_

Tests in `tools/tests/` (stdlib `unittest`), run by `tools/test_studio`, using fake agent
scripts (C19 env vars) in temporary git repos **with a temporary bare remote**.

- [ ] AC1 — `status` prints every feature (id, title, status, owner, blocked flag) and flags
      C6 mismatches. `next F-XXX` prints the C5 action for every input combination,
      including every stop case.
- [ ] AC2 — **Full path from `main` (PR-1):** starting with `APPROVED`, on `main`, no feature
      branch → tool creates the branch → fake Builder → checks → fake Auditor B → stops at
      (`CODE_REVIEW`, `Lucas`) with one notification. Same from `PLAN_REVIEW` through A → B →
      A → stop at (`PLAN_REVIEW`, `Lucas`).
- [ ] AC3 — **Invalid transitions (PR-3):** fakes that write `APPROVED`, `DONE`, a wrong owner,
      a verdict that contradicts the status, a mismatched board row, or switch branches →
      step rejected, no commit, no next agent, feature blocked.
- [ ] AC4 — **Committed violations (PR-4):** fakes that *commit* an edit to `AGENTS.md`, or a
      whitespace-only edit to `DECISIONS.md`, ending with a clean tree → rejected, blocked,
      notification lists commits and paths; history not rewritten; `unblock` required.
- [ ] AC5 — **Content lanes (PR-5):** fakes that alter §1 as Auditor, delete an earlier §7
      finding, edit §11, change another frontmatter field, or change an existing
      decision's status inside allowed files → rejected. A Planner adding a PROPOSED entry
      and replying under findings → accepted.
- [ ] AC6 — **Readiness (PR-6, PR-11, PR-12):** red checks → no Auditor call, (`CODE_CHANGES`, `Builder`) +
      §10 row, Builder dispatched next. Restart after a red result can't reach the
      Auditor. Approved review + a later code commit → `done` refuses; + a later
      metadata-only commit → `done` proceeds. Pre-existing dirty edits refuse `run`; a Builder that leaves uncommitted files is rejected; dirty code/test files at `done` refuse (checks never run on uncommitted content). Three consecutive red checks (with a restart between) escalate to Lucas.
- [ ] AC7 — **Rounds (PR-7):** markers counted per C9; `PENDING` / `**Round:**` text ignored;
      3rd `CHANGES_REQUESTED` → escalation to Lucas; 3rd approval → proceeds.
- [ ] AC8 — **Gate recovery (PR-8):** `approve` with a rejected push → rerun completes;
      `done` with rejected feature push, rejected main push, a merge conflict, and a failure at each branch deletion (remote, local) →
      correct stop and message; reruns complete; branches deleted only after step 6.
- [ ] AC9b — **No child pushes (PR-14):** a fake agent that runs `git push` fails against the bare remote; a fake that pushes to an explicit URL is detected by the remote comparison, rejected and blocked with recovery instructions.
- [ ] AC9c — **Resume (PR-13):** Builder escalation (`IN_PROGRESS`, `Lucas`) → plain `run` stops → answer the §10 row → `run --resume` → owner set to Builder → action C. Unanswered blocking row → `--resume` refuses.
- [ ] AC9 — **Agent failures (PR-9):** fake exits non-zero after a valid-looking edit; fake
      hangs past `--timeout`; tool interrupted mid-call → no commit, no dispatch, child
      group gone, lock released, feature blocked, log kept.
- [ ] AC10 — **Lock (PR-10):** run vs run, run vs approve, done vs approve → second command
      refuses; read-only commands still work; stale lock (dead PIDs) cleared.
- [ ] AC11 — **Role contracts (PR-2):** prompts start with the right `STUDIO-ROLE` line and
      contain only file pointers; a test asserts `CLAUDE.md`, `AGENTS.md`, the template and
      every department brief contain the T9 sections.
- [ ] AC12 — `tools/test`, `tools/lint`, core purity, `tools/test_studio` all pass.
- [ ] AC13 — Docs: `README.md` "Autopilot" section (setup, env vars, chosen CLI flags,
      commands, recovery); `studio/prompts/handoffs.md` points to the commands.

**How to verify manually:** `tools/studio status`; `tools/studio next F-002`;
`tools/studio notify-test`. The real test is F-003: commit its spec, run
`tools/studio run F-003`, walk away, come back to a notification.

---

## 6. Task Breakdown  ·  _Planner_

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Feature/board parsing + content-lane diff (C6, C9, C13) | `tools/studio_lib/feature.py` | Pure functions; section splitter, round markers, preserved-lines check, DECISIONS entry diff. |
| T2 | Git layer (C3, C7, C11, C16–C18) | `tools/studio_lib/git.py` | Start/end snapshots, changed set incl. new commits, fast-forward check, explicit-path commits, branch create/checkout, push/merge/verify/delete. Never `add -A`, never `-D`. |
| T3 | Engine: action table, transition validation, caps, readiness (C5, C6, C10, C14) | `tools/studio_lib/engine.py` | |
| T4 | Process runner (C4, C15, C19) | `tools/studio_lib/proc.py` | Process groups, timeout, signal forwarding, lock. |
| T5 | Prompt templates (C8) | `tools/studio_prompts/{auditor_plan,auditor_code,planner,builder}.md`, `studio/prompts/autopilot-planner.md` | Role line + file pointers only. |
| T6 | Notifications (C20) | `tools/studio_lib/notify.py` | + `notify-test`. |
| T7 | CLI | `tools/studio` | `status`, `next`, `run [--resume] [--max-steps] [--timeout]`, `approve`, `done`, `unblock`, `notify-test`. |
| T8 | Tests + runner | `tools/tests/`, `tools/test_studio` | Fixtures per AC2–AC11, bare remote. |
| T9 | Role-contract updates (PR-2, PR-7, C7) | `CLAUDE.md` (STUDIO-ROLE section; branch provided by tool; `--resume` allows `IN_PROGRESS`), `AGENTS.md` (round marker, reviewed commit), `studio/features/_TEMPLATE.md` (no `**Round:** 1` placeholder), `studio/departments/*.md` (in-place editing when automated) | Builder may edit these for this feature only (Director exception, §1). |
| T10 | Docs + gitignore | `README.md`, `studio/prompts/handoffs.md`, `.gitignore` | AC13; `.studio/` ignored. |

---

## 7. Plan Review  ·  _Auditor_

**Verdict:** `APPROVE_WITH_NOTES`
**Reviewed:** 2026-10-31 · **Round:** 3 · **Reviewed revision:** `2296e96`

**Current result:** PR-1–PR-13 are `✔ resolved`. PR-14's push controls, detection and
acceptance coverage are specified; its remaining recovery wording is a 🟡 note below.
No blocking findings remain. Keep `status: PLAN_REVIEW`, set `owner_now: Lucas` for Gate A.

### Round 2 review (historical)

**Verdict:** `CHANGES_REQUESTED`
**Reviewed:** 2026-10-31 · **Round:** 2 · **Reviewed revision:** `129a026`

**Current result:** PR-1–PR-7 and PR-9–PR-10 are `✔ resolved`. PR-8 is partially
resolved and remains a should-fix note. New PR-11 is blocking; PR-12–PR-14 are
should-fix notes. See the Round 2 resolution check and findings below.

### Round 1 review (historical)

**Reviewed:** 2026-10-31 · **Round:** 1 · **Reviewed revision:** `f5dc0a0`

The Director-facing infrastructure outcome and exclusions are clear. The chosen local
orchestrator and rejection reasons fit the studio's current scale. No conflict was found
with the accepted D-001–D-006 decisions or Direction's project/design ownership. Tasks
have concrete outputs, but the handoff contract and enforcement gaps below prevent the
specified unattended workflow from being reliable. Six blocking findings remain.

### PR-1 🔴 The first Builder call cannot pass the branch precondition
**Round 2 status:** ✔ resolved — C7 gives branch creation/checkout to the tool;
AC2 starts on main without a feature branch.

- **Location:** §4 C11; §5 AC3/AC9; §6 T2–T3.
- **Problem:** `approve` commits, rebases and pushes on `main`. C11 then requires the
  feature branch before any Builder step, while explicitly assigning creation of that
  branch to the Builder. A newly approved feature has no feature branch, so `run` must
  refuse before it can invoke the agent that creates it.
- **Why it matters:** The advertised Gate A → Builder → Auditor path fails on its first
  normal invocation; a fake fixture with a pre-created branch would hide the failure.
- **Suggested fix:** Define who creates/checks out the branch and when. Either let the
  orchestrator create it before the first Builder call, or explicitly allow that first
  call from `main` and require the expected branch afterwards. Distinguish initial build
  from resume/fix calls. Add an AC3 fixture starting on `main`, with `APPROVED` and no
  feature branch, that exercises the complete transition.

> **Planner reply (Direction):** Accepted. C7: the tool creates/checks out `feature/F-XXX-<slug>` from `main` before the first action C; agents never switch branches. AC2 starts on `main` with `APPROVED` and no branch.

### PR-2 🔴 Automated Planner and resume calls conflict with the loaded role instructions
**Round 2 status:** ✔ resolved — C8 and T9 define role precedence, in-place Planner
editing and the explicit resume policy; AC11 covers the instruction updates. The
remaining resume dispatch ambiguity introduced by that policy is recorded in PR-13.

- **Location:** §4 C3/C14; §6 T4/T8; `CLAUDE.md` “Before any task” and “You must never”;
  `studio/departments/direction.md` “Output format”.
- **Problem:** C3 dispatches a Builder for `IN_PROGRESS`, but `CLAUDE.md:18–20` permits
  starting only from `APPROVED` or `CODE_CHANGES`. It also dispatches Claude Code as a
  Planner on `PLAN_CHANGES`, while the repository's automatically loaded `CLAUDE.md`
  declares that session the Builder and forbids editing §1–§7. Direction's brief asks
  for a Markdown block ready to paste, whereas this loop needs edits in the repository.
  The pointer-only templates and tasks do not define how those conflicting contracts
  are reconciled.
- **Why it matters:** A role following the existing instructions can refuse a required
  call or return a revised plan only in stdout, making the automated repair loop stop.
  These are unflagged contradictions with the workflow the feature must preserve.
- **Suggested fix:** Specify role-aware instruction entry points, the Planner's in-place
  editing contract, and an explicit `IN_PROGRESS` resume policy. Include the necessary
  instruction/documentation changes in scope, with clear precedence. Test the prompts
  against the repository role contracts as well as testing fake status transitions.

> **Planner reply (Direction):** Accepted. C8 adds a `STUDIO-ROLE` first line and a matching `CLAUDE.md` section so a Planner session isn't bound by Builder rules and edits files in place; briefs updated likewise (T9). `IN_PROGRESS` is never auto-resumed: it stops, and only `run --resume` (typed by Lucas) dispatches the Builder, which `CLAUDE.md` will allow. AC11 tests the role contracts.

### PR-3 🔴 Dispatch rules do not validate the transition an agent produces
**Round 2 status:** ✔ resolved — C2/C5/C6 define accepted output transitions and
consistency checks; AC3 rejects gate, owner, verdict, board and branch violations.

- **Location:** §3 Chosen; §4 C2–C3/C6; §5 AC3–AC5.
- **Problem:** C3 selects an agent from the input state, but no rule defines its allowed
  output states or validates status/owner/verdict/board consistency. For example, an
  Auditor can write `APPROVED`/`Builder` in the allowlisted feature and board files.
  The state has progressed under C6, and C3 then selects the Builder without Lucas
  running `approve`. C2 restricts the tool's own writes without specifying rejection
  of gate states written by its subprocesses.
- **Why it matters:** An implementation can satisfy the listed path checks and happy
  path ACs while bypassing the human gate that §3 explicitly rejects automating.
- **Suggested fix:** Add a per-action output-transition table and validate it before
  committing or dispatching again. Reject agent-produced `APPROVED`/`DONE`, mismatched
  owners, inconsistent verdicts and board rows, and unexpected branch changes. Define
  permitted escalation to Lucas. Add fakes that attempt each invalid transition and
  assert that no following agent or tool commit occurs.

> **Planner reply (Direction):** Accepted. C5 is now input → agent → the only accepted outputs; C6 checks board/verdict/branch consistency before and after each step; C2 rejects any agent-produced `APPROVED`/`DONE` or §11 edit. AC3 covers each invalid transition.

### PR-4 🔴 `git status` cannot enforce lanes for changes an agent commits
**Round 2 status:** ✔ resolved — C11 inspects new commits and all working-tree/index
changes, preserves rejected history and blocks the feature; AC4 covers clean-tree
committed violations. The new remote-containment claim is addressed separately in PR-14.

- **Location:** §4 C4–C5/C11; §5 AC5; §6 T2.
- **Problem:** C4 checks lanes against `git status`, while C5 expects the Builder to
  commit its own work and merely checks that the tree is clean. A Builder that commits
  an edit to `AGENTS.md` or `studio/DECISIONS.md` leaves a clean tree and passes that
  check. An Auditor/Planner that unexpectedly commits its own changes has the same
  blind spot. AC5 covers only violations left in the working tree.
- **Why it matters:** The exact class of accidental committed change cited in §1 is
  invisible after an agent commit; explicit-path staging by the orchestrator cannot
  remove it from history.
- **Suggested fix:** Record the starting branch/HEAD and inspect every new commit's
  changed paths, plus staged, unstaged and untracked paths, before accepting the step.
  Reject unexpected history/branch movement. Specify how a pre-existing violating
  agent commit is reported and preserved: C4's promise to leave all violations
  “uncommitted” cannot be met retroactively without rewriting history. Add fixtures
  with committed violations, including whitespace-only edits and a clean final tree.

> **Planner reply (Direction):** Accepted. C11 inspects all new commits since the recorded start HEAD plus staged/unstaged/untracked, requires a same-branch fast-forward, and rejects whitespace-only changes too. Since history can't be un-committed retroactively, the tool never rewrites it: C3 makes `run` push-free, and the feature is blocked until Lucas fixes it locally and runs `unblock`. AC4 uses committed violations with a clean final tree.

### PR-5 🔴 File allowlists do not enforce section ownership or proposed-only decisions
**Round 2 status:** ✔ resolved — C13 defines frontmatter, section, review-history,
board-column and decision-entry restrictions, with positive/negative cases in AC5.

- **Location:** §3 Chosen/Rejected; §4 C4; §6 T1–T2;
  `studio/README.md` “Section ownership”; `AGENTS.md` “Hard rules”.
- **Problem:** Both the feature and STATUS files are allowlisted for the Auditor, so
  changing §1–§6, §8 or Lucas's §11 passes C4. Builder access to the feature likewise
  permits changing approved requirements or deleting findings. Planner access to
  `DECISIONS.md` does not distinguish a new PROPOSED entry from rewriting an existing
  ACCEPTED decision. No task or AC specifies validation at these finer boundaries.
- **Why it matters:** The claimed protection against editing another role's section
  still depends on agent obedience, the weakness used to reject agent orchestration
  in §3. These edits can silently change what subsequent agents treat as authorized.
- **Suggested fix:** Define permitted frontmatter fields, section edits, inline replies
  and append-only regions per role, then validate protected content before accepting
  the step. Preserve §11 outside explicit human gate commands and existing decision
  entries outside authorized Director changes. Add fakes that alter protected sections,
  delete earlier findings, and change an existing decision's status within otherwise
  allowlisted files.

> **Planner reply (Direction):** Accepted. C13 defines content lanes inside allowed files: allowed frontmatter fields, per-role sections, preserved-lines rule for review/reply sections, §10 append/answer-only, §11 gate-only, STATUS row columns, and DECISIONS entries byte-identical with new entries PROPOSED only. AC5 covers each.

### PR-6 🔴 Readiness checks can be bypassed on restart or after code changes
**Round 2 status:** ✔ resolved — C14 checks before every code audit and in done;
C18/AC6 reject later code commits and cover restart after failed checks. The removed
clean-tree boundary creates a separate problem with which files are tested (PR-11).

- **Location:** §4 C3/C9; §5 AC6/AC10; §9 “Reviewed commit” convention.
- **Problem:** On a failed Builder check, C9 leaves `CODE_REVIEW` as written by the
  Builder. A second `run` starts directly with the Auditor under C3; C9 only runs
  after a Builder step, so the failed check is never revisited. AC10 also accepts an
  approving verdict without requiring passing checks for the code being merged or
  verifying that its code still matches the review's recorded commit.
- **Why it matters:** Restarting after a test failure, or adding a code commit after
  an approving review, can advance unverified code to Gate B with valid-looking
  status/owner/verdict fields.
- **Suggested fix:** Define readiness evidence tied to a specific code revision, or
  rerun required checks before every Mode B invocation and finalization. Require a
  fresh review when code differs from the reviewed revision, while allowing explicitly
  defined review/status metadata commits. Test failure → restart and approved review
  → additional code commit → `done`; neither may bypass the missing evidence.

> **Planner reply (Direction):** Accepted. C14 runs the checks before every Mode B call (and in `done`) on the exact HEAD; red results route back to the Builder via `CODE_CHANGES`, so a restart can't reach the Auditor. C18 binds `done` to the reviewed commit, allowing only metadata-only commits after it. AC6 covers restart and post-review code commits.

### PR-7 🟡 Review-round counting lacks a shared schema and boundary rule
**Round 2 status:** ✔ resolved — C9 defines authoritative markers, legacy/placeholder
handling and the incrementing role; C10/AC7 distinguish a third approval from a third
rejection. C14's additional counting rule is a separate ambiguity (PR-12).

- **Location:** §4 C7; §5 AC4; §6 T1; `studio/features/_TEMPLATE.md` §7/§9;
  `AGENTS.md` Mode A/Mode B.
- **Problem:** C7 counts `**Round:** N` markers in both reviews, but the shared plan
  review template has no such marker and Mode A does not require incrementing one.
  Conversely, the code template already contains Round 1 while its verdict is PENDING.
  Historical review text can retain additional markers. “Hitting” three rounds also
  leaves the timing of escalation relative to the third review's result unspecified.
- **Why it matters:** The cap can be ineffective, count an unperformed review, or
  override a successful final review depending on the parser and invocation order.
- **Suggested fix:** Specify an authoritative current-round convention, initialization,
  incrementing actor, treatment of PENDING/history and legacy files, and whether the
  cap stops a further review after the third completed result. Include any required
  role/template updates and tests for missing, historical and placeholder markers.
  This review adds a local Round marker; that alone does not establish the shared rule.

> **Planner reply (Direction):** Accepted. C9: machine marker `<!-- review-round: N verdict: X -->` written by the Auditor, numbered per section, PENDING/`**Round:**` ignored, legacy files = 0 rounds; C10: a 3rd `CHANGES_REQUESTED` escalates, a 3rd approval proceeds. Template and `AGENTS.md` updated in T9.

### PR-8 🟡 Gate helpers have no defined recovery after partial Git failure
**Round 2 status:** Partially resolved — C17/C18 add resumable gate steps and AC8
adds remote/conflict fixtures. The post-publication cleanup case remains open below.

- **Location:** §5 AC9–AC10; §4 C13; §6 T2/T6.
- **Problem:** `done` sets/commits DONE and pushes the feature before merging/pushing
  `main`. If the main push fails, the next `done` fails its CODE_REVIEW precondition,
  leaving publication and branch cleanup unfinished. `approve` can similarly leave
  its gate state committed before a rebase/push failure. No recovery contract or
  failure fixture covers these intermediate states.
- **Why it matters:** The tool cannot supply a reliable next command for ordinary Git
  failures, and a retry may refuse or repeat operations whose effects already landed.
- **Suggested fix:** Define preconditions and checkpoints for each gate command,
  checked failure ordering, preservation of conflict/dirty state, and an idempotent
  resume command or exact documented recovery path. Test rebase/merge conflicts and
  rejected feature/main pushes using a temporary bare remote; delete branches only
  after confirmed publication to main.

> **Planner reply (Direction):** Accepted. C17/C18 define checkpointed, idempotent gate steps (rerun resumes), branch deletion only after `origin/main` is verified, exact recovery messages for push rejections and merge conflicts. AC8 uses a bare remote.

**Round 2 remaining issue:**
- **Location:** Revised §4 C18 steps 6–7 and its rerun precondition; §5 AC8.
- **Problem:** A DONE rerun is accepted only while step 6 is unsatisfied. If publication
  is verified and remote or local branch deletion then fails in step 7, step 6 is
  already satisfied and the prescribed rerun is refused.
- **Why it matters:** Cleanup cannot resume after a normal deletion/network failure,
  despite the requirement that already completed gate steps be skipped on retry.
- **Suggested fix:** Allow an authenticated gate operation to resume through incomplete
  cleanup after publication, and define success when one or both branches are already
  absent. Extend AC8 with failures at each deletion and a successful retry.

> **Planner reply (Direction), round 2:** Accepted. C18: a `DONE` rerun is accepted while publication is unverified **or** either branch still exists; an already-missing branch counts as deleted. AC8 adds failures at each deletion.

**Round 3 status:** ✔ resolved — C18 now permits retries after publication while
either branch remains, treats missing branches as deleted, and AC8 covers both
deletion failures. This closes the Round 2 cleanup issue.

### PR-9 🟡 Agent failure, interruption and timeout behavior is unspecified
**Round 2 status:** ✔ resolved — C4/C15 specify process groups, timeout escalation,
interruption handling, blocked state and lock lifetime; AC9 exercises the failure paths.

- **Location:** §2 CLI invocation; §4 C6–C8/C10/C12–C13; §6 T3/T6–T7.
- **Problem:** The guards count returned steps, but there is no contract for a process
  that exits non-zero after editing files, cannot launch/authenticate, waits forever
  for permission, or is interrupted while its child remains alive. Logs are required,
  but the plan does not say whether partial output/state may be committed or advanced.
- **Why it matters:** A changed header can look like progress despite invocation failure;
  a hung child can hold the workflow indefinitely, and clearing its dead parent's PID
  lock could allow a second agent onto the same tree.
- **Suggested fix:** Define exit-code handling, a configurable timeout policy, child
  termination/waiting and lock cleanup. Failed/interrupted calls should preserve logs
  and edits, stop before committing/dispatching, and notify with the recovery action.
  Add fake-agent fixtures for non-zero exit after a valid-looking edit and for a hung
  or interrupted process. Record any deliberate absence of a timeout explicitly.

> **Planner reply (Direction):** Accepted. C15: process groups, 90-min default timeout with TERM→KILL, Ctrl-C forwarded and waited for; any failure keeps edits and logs, commits nothing, dispatches nothing, blocks the feature. Lock records both PIDs (C4). AC9 covers non-zero-after-edit, hang and interrupt.

### PR-10 🟡 The lock excludes other commands that mutate the same tree
**Round 2 status:** ✔ resolved — C4 applies the shared lock to run, approve, done and
unblock; AC10 covers run/gate and gate/gate exclusion with read-only commands available.

- **Location:** §4 C10; §5 AC7/AC9–AC10; §6 T6.
- **Problem:** C10 and AC7 specify exclusion between two `run` calls only. `approve`
  and `done` also edit, commit and change branches, but their participation in that
  lock is not defined. A clean-tree check cannot prevent a concurrent change between
  validation and mutation.
- **Why it matters:** A gate helper can race an active agent or another gate helper
  and invalidate the branch, state or files that the other operation just checked.
- **Suggested fix:** Require one shared lock across every mutating command, covering
  validation through completion/failure. Keep read-only commands available. Extend
  AC7 to exercise run-versus-gate and gate-versus-gate exclusion.

> **Planner reply (Direction):** Accepted. C4: one shared lock for `run`, `approve`, `done`, `unblock`, held from validation to completion; read-only commands lock-free. AC10 covers run/gate and gate/gate.

**Handoff:** `status: PLAN_CHANGES`, `owner_now: Planner`. Resolve PR-1–PR-6 before
Gate A; reply beneath each finding and retain this review history.

### Round 2 — Planner reply and resolution check

Checked all ten inline Planner replies first, then read the revised feature against
PROJECT.md, DECISIONS.md and the role/department documents. This review is of the
committed Planner revision `129a026`; the initial working tree was clean. The earlier
re-audit of an unchanged checkout is superseded by this review of the actual revisions.

| Finding | Reply and revised-plan evidence | Round 2 result |
|---|---|---|
| PR-1 | Accepted; C7 and AC2 provide the first feature branch before dispatch. | ✔ resolved |
| PR-2 | Accepted; C8/T9/AC11 specify role entry points and instruction changes, including explicit IN_PROGRESS continuation. | ✔ resolved |
| PR-3 | Accepted; C2/C5/C6 and AC3 enforce permitted outputs before the next dispatch. | ✔ resolved |
| PR-4 | Accepted; C11/AC4 inspect committed paths and preserve evidence rather than rewriting history. | ✔ resolved |
| PR-5 | Accepted; C13/AC5 add restrictions inside allowed files and preserve existing decisions. | ✔ resolved |
| PR-6 | Accepted; C14/C18/AC6 address restart bypass and subsequent code commits. | ✔ resolved |
| PR-7 | Accepted; C9/C10/T9/AC7 establish round markers and the third-result boundary. | ✔ resolved |
| PR-8 | Accepted; C17/C18/AC8 cover earlier Git failures, but C18 excludes retries after publication verification. | Partially resolved — 🟡 open |
| PR-9 | Accepted; C4/C15/AC9 define failure, timeout, interruption and child cleanup behavior. | ✔ resolved |
| PR-10 | Accepted; C4/AC10 extend exclusion to every mutating command. | ✔ resolved |

The goal, exclusions, alternatives and fit with the accepted project decisions remain
sound. The role-document exceptions are explicitly included in scope for T9 and can be
authorized at Gate A. The following findings concern the revised execution contract.

### PR-11 🔴 The revised plan drops the clean-tree boundary needed to test an exact HEAD
- **Location:** §4 C5–C7/C11/C14/C18; §5 AC2/AC6. The old clean-tree requirement and
  dirty-tree AC are absent; only C17 explicitly requires a clean tree.
- **Problem:** No rule now requires a clean tree before run/agent steps, a clean tree
  after an accepted Builder step, or a tree containing only validated review edits
  before done. C14 says checks run on the exact feature HEAD, but the existing check
  scripts execute the working-tree files. For example, after an approving review a
  dirty test/helper file can make checks pass in done while being excluded from its
  explicit-path commits; the code published to main does not include that file.
  C11's post-step path collection does not establish a clean baseline or make those
  checks execute committed content.
- **Why it matters:** The tool can report passing checks for a revision it never
  actually tested, and pre-existing local edits can be absorbed into Builder commits.
  This defeats the new readiness guarantee even when the reviewed commit is correct.
- **Suggested fix:** Restore clean-tree preconditions for run and each agent step,
  require accepted Builder work to be committed before checks, and define done's
  narrow exception for uncommitted, content-validated review/board edits. Refuse other
  dirty tracked/untracked paths before checking or committing. Alternatively run checks
  in a verified checkout of the recorded revision. Add fixtures for pre-existing edits,
  dirty Builder completion and dirty code/tests at done; none may be accepted or
  published as checks passing on HEAD.

> **Planner reply (Direction), round 2:** Accepted — my rewrite lost it. New C21 defines "clean" and requires it before `run`, every agent step, every check and `approve`; accepted Builder steps must end clean (the Builder commits its work). C14 runs checks only on a clean tree at the feature HEAD. C18 now commits the Auditor's validated edits **before** running the checks and refuses any other dirty path. AC6 covers pre-existing edits, dirty Builder completion and dirty code at `done`.

**Round 3 status:** ✔ resolved — C21 restores clean-tree boundaries and committed
Builder completion. C14 checks that committed tree; C18 validates and commits the
narrow review-edit exception before checks. AC6 covers the dirty-tree regressions.

### PR-12 🟡 Failed readiness checks have no defined representation in the round cap
- **Location:** §4 C9/C10/C14; §5 AC6–AC7.
- **Problem:** C9 counts completed Auditor rounds using markers written by the Auditor.
  C14 says a failed readiness check counts toward the code-round cap, but creates only
  a CODE_CHANGES transition and a question row, with no Auditor call or round marker.
  Three Builder/check failures before the first code audit therefore leave the C9
  round count at zero.
- **Why it matters:** The Builder must invent a second persistent counter or silently
  omit one of the promised limits; separate invocations can reset an inferred counter.
- **Suggested fix:** Define the readiness-failure event, its durable count and how it
  combines with completed reviews for escalation. Keep ownership of review markers
  explicit. Test repeated red checks before any audit, with a restart between attempts,
  and assert the chosen cap and Lucas handoff.

> **Planner reply (Direction), round 2:** Accepted. C10(b): each red check appends a tool-owned §10 row with `<!-- readiness-fail: N sha: … -->`; N counts consecutive failures since the last completed code review, durable in the file; the 3rd escalates to Lucas. Independent from the Auditor-owned review markers. AC6 covers repeated failures with a restart.

**Round 3 status:** ✔ resolved — C10(b) defines tool-owned durable failure events,
their reset boundary and third-failure escalation independently of Auditor rounds.
AC6 includes repeated failures across a restart.

### PR-13 🟡 `--resume` has conflicting behavior for the Builder's allowed escalation
- **Location:** §4 C5 action C and stop cases; C8; §6 T7/T9.
- **Problem:** The accepted Builder escalation is IN_PROGRESS with owner Lucas. The
  stop rule stops every owner Lucas state, while its IN_PROGRESS exception says
  `run --resume` selects action C; action C's listed input states omit IN_PROGRESS.
  The plan does not say which rule wins or whether resume transfers ownership after
  Lucas answers the blocking question.
- **Why it matters:** The documented continuation command can keep stopping on the
  normal escalation state, and a Builder cannot know whether to change ownership as
  an assumption without contradicting the action table.
- **Suggested fix:** Add an explicit resume input transition, its precedence over the
  Lucas stop rule, question/clean-tree preconditions and ownership effects. Test the
  accepted escalation → answered question → explicit resume → Builder path, as well as
  ordinary run continuing to stop at Lucas.

> **Planner reply (Direction), round 2:** Accepted. New C22: `run --resume` is the only continuation of `IN_PROGRESS` and takes precedence over the Lucas stop rule; preconditions (clean tree, feature branch, owner Builder, or owner Lucas with all blocking §10 rows answered); effect: the tool sets owner Builder, then action C with the same accepted outputs. AC9c covers escalation → answer → resume and the refusal case.

**Round 3 status:** ✔ resolved — C5 explicitly admits IN_PROGRESS through C22, which
defines precedence, branch/clean-tree/question preconditions and transfer to Builder.
AC9c tests answered and unanswered escalation paths.

### PR-14 🟡 The remote-containment promise lacks a child-process push policy
- **Location:** §4 C3/C8/C11/C19; §6 T4/T5/T9.
- **Problem:** C3 makes run itself push-free and C11 concludes that rejected agent work
  can always be fixed locally. Neither the role contract nor process permissions
  explicitly prevent an invoked agent from pushing before its output is validated.
  A fake child can commit an out-of-lane edit and push it to the temporary remote;
  rejecting its output afterwards leaves that rejected commit on the remote.
- **Why it matters:** The new guarantee that rejected steps never reach GitHub does
  not follow from the specified controls, and local reset alone would not repair it.
- **Suggested fix:** Specify and verify a no-push policy for child invocations, using
  CLI permissions/isolation if prevention is the intended guarantee. Otherwise state
  the limit of post-step detection and define remote-state recovery. Add a child-push
  fixture against the bare remote to validate the chosen policy.

> **Planner reply (Direction), round 2:** Accepted — chose prevention plus detection. C3: children run with a git config override that makes `git push` to origin fail, no terminal prompts, and the CLIs' own push/network denial; the tool also snapshots `git ls-remote origin` before/after each step and rejects + blocks on any remote change, with exact remote-recovery instructions (the documented limit: an explicit-URL push can only be detected, not prevented). AC9b tests both against the bare remote.

**Round 3 status:** Partially resolved — C3 and AC9b now specify the push controls,
remote comparison, blocked outcome and recovery notification. The reply explicitly
acknowledges the limit for explicit-URL pushes. Only the recovery wording below remains 🟡.

**Round 3 remaining note:**
- **Location:** §4 C3 and C11's final sentence; §5 AC9b/AC13.
- **Problem:** C11 still says a local reset is “always enough” because run never pushes,
  while C3 and the Round 2 reply now allow detection of a child push that has already
  changed the remote and requires remote recovery. The recovery guarantee was not
  qualified when the containment policy changed.
- **Why it matters:** The Builder and Director receive conflicting descriptions of
  what recovery involves after a rejected step. The specified detection behavior and
  tests are adequate, but the unconditional local-only promise is inaccurate.
- **Suggested fix:** Limit C11's local-reset statement to steps with an unchanged remote
  snapshot. State the explicit-URL detection limit and the separate remote-recovery
  path consistently in the Autopilot documentation required by AC13. Retain AC9b's
  distinct blocked-push and detected-push cases.

**Round 2 verdict:** `CHANGES_REQUESTED`. Nine previous findings are resolved; PR-8
remains 🟡. PR-11 is the blocking finding; PR-12–PR-14 are 🟡. Set
`status: PLAN_CHANGES`, `owner_now: Planner`; reply under the remaining findings.

### Round 3 — Round 2 Planner reply and resolution check

Checked the Round 2 replies under PR-8 and PR-11–PR-14 first, then read the whole
revised feature against PROJECT.md, DECISIONS.md and the relevant role/department
documents. Reviewed committed revision `2296e96` from a clean working tree. PR-1–PR-7
and PR-9–PR-10 remain resolved; their findings are not re-raised.

| Finding | Reply and revised-plan evidence | Round 3 result |
|---|---|---|
| PR-8 | Accepted; C18 permits post-publication cleanup retries and missing branches; AC8 covers each deletion failure. | ✔ resolved |
| PR-11 | Accepted; C21 restores clean starts and committed Builder completion; C14/C18 check the committed revision after validated review edits; AC6 covers dirty states. | ✔ resolved |
| PR-12 | Accepted; C10(b) adds persistent readiness-failure markers and independent escalation; AC6 verifies restart durability. | ✔ resolved |
| PR-13 | Accepted; C5/C22 define explicit resume precedence and ownership effects; AC9c exercises the escalation/answer/resume path. | ✔ resolved |
| PR-14 | Accepted; C3/AC9b specify child-push controls and remote-change detection. C11 retains an unconditional local-reset claim. | Partially resolved — 🟡 wording note |

The Director-facing outcome, explicit scope and local-orchestrator choice remain
coherent with the project's phase and accepted decisions. The role-document exceptions
are explicit in §1/T9. The revised ACs now cover the blocking clean-tree issue as well
as the new recovery, readiness-counter and resume contracts. No new findings are added.
This is plan approval evidence; implementation and runtime behavior remain for Mode B.

**Round 3 verdict:** `APPROVE_WITH_NOTES`. No 🔴 findings remain. PR-14 has the single
🟡 wording note above. Keep `status: PLAN_REVIEW`, set `owner_now: Lucas`; only Lucas
may approve Gate A and set `APPROVED`.

---

## 8. Implementation Log  ·  _Builder_

**Started:** 2026-10-31  ·  **Branch:** `feature/F-002-studio-autopilot`

### Progress
- [ ] T1
- [ ] T2
- [ ] T3
- [ ] T4
- [ ] T5
- [ ] T6
- [ ] T7
- [ ] T8
- [ ] T9
- [ ] T10

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
- **2026-10-31 (PR-14 note):** C11's "a local `git reset` is always enough" holds only when the remote did not change; if the C3 remote check detects a change, C3's remote-recovery path applies instead. T9 role-document edits are authorized. F-002 APPROVED.
