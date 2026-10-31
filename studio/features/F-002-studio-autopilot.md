---
id: F-002
title: Studio autopilot (tools/studio)
status: PLAN_CHANGES      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Planner       # who must act next: Planner | Auditor | Builder | Lucas
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

**Verdict:** `CHANGES_REQUESTED`
**Reviewed:** 2026-10-31 · **Round:** 1 · **Reviewed revision:** `f5dc0a0`

The Director-facing infrastructure outcome and exclusions are clear. The chosen local
orchestrator and rejection reasons fit the studio's current scale. No conflict was found
with the accepted D-001–D-006 decisions or Direction's project/design ownership. Tasks
have concrete outputs, but the handoff contract and enforcement gaps below prevent the
specified unattended workflow from being reliable. Six blocking findings remain.

### PR-1 🔴 The first Builder call cannot pass the branch precondition
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

### PR-2 🔴 Automated Planner and resume calls conflict with the loaded role instructions
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

### PR-3 🔴 Dispatch rules do not validate the transition an agent produces
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

### PR-4 🔴 `git status` cannot enforce lanes for changes an agent commits
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

### PR-5 🔴 File allowlists do not enforce section ownership or proposed-only decisions
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

### PR-6 🔴 Readiness checks can be bypassed on restart or after code changes
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

### PR-7 🟡 Review-round counting lacks a shared schema and boundary rule
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

### PR-8 🟡 Gate helpers have no defined recovery after partial Git failure
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

### PR-9 🟡 Agent failure, interruption and timeout behavior is unspecified
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

### PR-10 🟡 The lock excludes other commands that mutate the same tree
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

**Handoff:** `status: PLAN_CHANGES`, `owner_now: Planner`. Resolve PR-1–PR-6 before
Gate A; reply beneath each finding and retain this review history.

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
