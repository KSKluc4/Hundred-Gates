---
id: F-010
title: Studio queue — chained features, auto-drafted specs, opt-in automatic Gate A
status: PLAN_REVIEW      # DRAFT | PLAN_REVIEW | PLAN_CHANGES | APPROVED | IN_PROGRESS | CODE_REVIEW | CODE_CHANGES | DONE | PARKED
owner_now: Auditor       # who must act next: Planner | Auditor | Builder | Lucas
created: 2026-11-16
updated: 2026-11-16
depends_on: [F-002, D-009]
pillars: []              # tooling: serves the phase 1 finish date, no pillar
department: Direction      # owning department (studio/departments/README.md)
---

# F-010 — Studio queue — chained features, auto-drafted specs, opt-in automatic Gate A

> **How to use this file.** This is the single source of truth for this feature.
> Every agent reads the WHOLE file before acting. Write only in the sections you own
> (see studio/README.md). Never delete another role's text — reply under it.

---

## 1. Goal  ·  _Planner_

**Player-facing outcome (one sentence):**
None in-game: after this ships, Lucas closes one feature with `tools/studio done` and the
next thing he hears from the studio is a notification that the next feature needs him
(its playtest, or its plan if he kept Gate A manual).

**Why now:** F-007 sat 2 days waiting for Gate A and F-008 sat 2 days after F-007 was DONE
because nobody ran the next command, and its spec file was an empty template nobody had
filled. About 8 phase 1 features remain; idle time between steps is now the biggest
schedule risk, larger than build time (F-006, F-007 and F-008 each built in about an hour).

**Out of scope (explicitly):**
- Automatic Gate B. The playtest is always Lucas. No flag, no code path.
- Running two features at once, or drafting feature N+1 while N waits for Gate B.
- Replacing Codex as the Auditor.
- Clock-based scheduling (cron, launchd). The queue advances on events, not on time.
- Writing or changing design docs. The draft step reads them; it never invents design.
- Creating departments. A queue row may only name a department that has a brief.
- Any change to what the Builder or Auditor steps do, or to the review round caps.

---

## 2. Context  ·  _Planner_

What the Builder needs to know that isn't obvious from the code:
- Existing systems this touches:
  - `tools/studio` (argparse commands), `tools/studio_lib/engine.py` (`STEPS`,
    `ACTION_TABLE`, `decide`, `transition_errors`, `_run_locked`, `approve`/`_gate_a`,
    `done`/`_publish`, lane checks), `tools/studio_lib/feature.py` (parsing, lanes),
    `tools/studio_lib/notify.py`, `tools/studio_prompts/`, `studio/prompts/`,
    `studio/new-feature.sh` (the logic to port), `tools/tests/` (fake agent harness).
  - Today `decide` stops on `DRAFT`; `run` handles one feature and returns when
    `owner_now` is Lucas; `approve` runs on `main`, needs a clean tree and pushes.
  - Agents can never output `APPROVED` or `DONE` (`GATE_STATUSES`, F-002/C2). That stays.
- Relevant prior decisions:
  - **D-009 (PROPOSED with this spec; Lucas agreed in chat 2026-11-16):** Gate A may be
    automatic for features Lucas marks `auto` in `studio/QUEUE.md`. The tool, not an
    agent, sets `APPROVED`. Gate B is always manual. Lucas accepts D-009 at Gate A of
    this feature.
  - D-010: one feature builds at a time; no parallel builds.
  - F-002/C2 (only gates write APPROVED/DONE and §11), C3/C7 (no remote or branch changes
    during a step), C20 (never stop without telling Lucas), C21 (clean tree).
- Relevant prior features: F-002 (autopilot). F-007's block on 2026-11-12 (a second
  session pushed to `main` during the build) is why this feature is strictly sequential.
- Proposed first queue (Lucas edits before use): every remaining phase 1 feature starts
  `manual`, because each is a new system. `auto` is for later features that follow an
  already approved design, as the three bosses did.
- `studio/PHASE1.md` is the human plan (order, dates, cut order). `studio/QUEUE.md` is
  what the tool reads (order, department, Gate A mode, brief). Direction keeps the two
  in the same order.

---

## 3. Options Considered  ·  _Planner_

> This section is what stops context loss. Be honest about trade-offs.
> The Builder MUST NOT implement anything listed under Rejected.

### ✅ Chosen: Queue file + draft step + tool-performed Gate A, strictly sequential
- **How it works:** `studio/QUEUE.md` lists features in order with department, a Gate A
  mode (`manual` or `auto`) and a short brief. `tools/studio queue run` takes the first
  row that isn't DONE, creates its file if missing, runs a new draft step (Planner agent
  writes §1–§6), then the existing audit/repair/build/review steps. When the plan audit
  approves and the row is `auto`, the tool performs Gate A itself. `done` continues into
  the next row. Everything stops the moment Lucas is needed.
- **Why chosen:** Removes every wait that isn't a real decision, reuses all F-002 safety
  checks unchanged, and keeps approval in the tool's gate code where it is auditable.
- **Costs we're accepting:** An auto-approved plan can be wrong and is only caught at the
  playtest (one wasted build). `APPROVE_WITH_NOTES` counts as approving for auto, so
  non-blocking notes can go unread. Auto-drafted specs may be weaker than chat-drafted ones.
- **Would revisit if:** An auto-approved feature fails Gate B because of its plan, or
  auto-drafted specs need more plan rounds on average than chat-drafted ones did (2).

### ❌ Rejected: Automatic Gate A for every feature
- **How it would work:** Drop the `manual` mode; any approving plan audit starts the build.
- **Why rejected:** Floors, progression, town and loot are new systems with open design
  choices. A wrong plan there costs a large build and reshapes later features; the
  Auditor checks consistency, not whether it is the game Lucas wants.
- **Tempting because:** It is simpler (no per-row mode) and gives the fewest stops.

### ❌ Rejected: Parallel pipeline (draft or build N+1 while N waits on Lucas)
- **How it would work:** A second run, or a look-ahead draft, works while a gate is open.
- **Why rejected:** The containment checks (C3/C7) reject any step during which `main` or
  the branch list changes, which is exactly what a second pipeline does; F-007 was blocked
  this way. Features also build on each other (bosses on the boss base), so a spec drafted
  before the previous merge describes code that isn't on `main`. See also D-010.
- **Tempting because:** Gate B waits are long and the machine is idle during them.

### ❌ Rejected: An agent sets APPROVED when it judges the plan good
- **How it would work:** The Auditor or Planner writes `status: APPROVED` on auto rows.
- **Why rejected:** It breaks F-002/C2 and makes approval depend on agent output that the
  lanes exist to distrust. An agent could also edit the queue to approve itself.
- **Tempting because:** It needs no new tool code, only a prompt change.

### ❌ Rejected: Time-based scheduler (cron/launchd starts runs)
- **How it would work:** A scheduled job runs `tools/studio queue run` every N minutes.
- **Why rejected:** Runs would start while Lucas has the repo open in another session and
  trip C3/C7/C21, and a sleeping Mac skips them anyway. Event chaining covers the need.
- **Tempting because:** "Scheduled" is the word Lucas used, and cron is one line.

---

## 4. Constraints  ·  _Planner_

Hard rules for this feature. Violating any of these = automatic `CODE_CHANGES`.

| ID | Constraint | Reason |
|---|---|---|
| C1 | No agent step may output `APPROVED` or `DONE`. Automatic Gate A is executed by the same gate code path as `approve` (`_gate_a`), never by an agent. | F-002/C2 |
| C2 | Gate B has no automatic path. `queue run` always stops at `(CODE_REVIEW, Lucas)`. | D-009 |
| C3 | Automatic Gate A happens only when ALL hold: the row's mode is exactly `auto`; state is `(PLAN_REVIEW, Lucas)`; the latest §7 round's verdict is approving (`APPROVE` or `APPROVE_WITH_NOTES`); §10 has no unanswered blocking row; `consistency_errors` is empty. Otherwise the tool stops and notifies as today. | D-009 |
| C4 | The Gate A mode is read from `studio/QUEUE.md` as committed on `main` at the start of the run. A missing, misspelled or empty mode is `manual`. | An uncommitted or mid-run edit must not approve anything |
| C5 | `studio/QUEUE.md` is outside every agent lane. A step that changes it is rejected and the feature blocked, like any lane violation (C12 of F-002). | No self-approval |
| C6 | An automatic approval is recorded: commit subject `Gate A: approve F-XXX (auto)` and a dated §11 note `Auto-approved per QUEUE.md (D-009)`. | Lucas must be able to see which gates he did not take |
| C7 | Strictly sequential: `queue run` works only on the first row whose feature is not DONE. If that feature stops for any reason, the queue stops. It never skips ahead. | F-007 block; features build on each other; D-010 |
| C8 | Every stop sends a notification with the feature, what happened and one exact next command. | F-002/C20 |
| C9 | The draft step's lane is the autopilot Planner lane (`studio/prompts/autopilot-planner.md`): feature file §1–§6 and §10 rows, the feature's STATUS row, PROPOSED decisions, design docs, glossary. Its only valid outputs are `(PLAN_REVIEW, Auditor)` or `(DRAFT, Lucas)` with a new blocking §10 row. | Same containment as plan repair |
| C10 | A draft that leaves any template placeholder (`<...>` text from `_TEMPLATE.md`) in §1–§6, or an empty §5 or §6, is rejected. | A half-filled spec must not reach the Auditor |
| C11 | The draft step must not invent design. Mechanics, numbers and patterns come from the row's brief and the department's design doc. If they are missing, it escalates with a blocking §10 row. | Department rule: design belongs to the owning department and Lucas |
| C12 | A row may name only a department that has a brief in `studio/departments/`. Otherwise `queue run` refuses before creating anything. | No invented departments |
| C13 | If the row's feature file already exists, it is used as is at its current state. It is never recreated or overwritten. | Specs drafted by hand must be safe |
| C14 | With no `studio/QUEUE.md`, or for a feature not in it, `run`, `next`, `approve`, `done`, `unblock` and `status` behave exactly as before this feature. | Must not break the working pipeline |
| C15 | Python standard library only. Same lock and keep-awake as `run`. | G4, F-002 |

**Must not break:** every existing `tools/tests` test passes unchanged; `approve` and `done`
stay idempotent; the F-002 round caps, step cap, readiness checks and containment checks
apply inside `queue run` exactly as inside `run`.

---

## 5. Acceptance Criteria  ·  _Planner_

Testable, observable. The Auditor checks each one. All use the fake agent harness.

- [ ] AC1: Given a queue whose first row is DONE and whose second row (F-B) has no file,
      when `queue run` runs, then `F-B-<slug>.md` is created from the template with the
      row's ID, title and department, a board row is added, and the draft step runs.
- [ ] AC2: Given F-B's row is `auto` and the plan audit approves with no blocking §10 row,
      when `queue run` continues, then the tool sets `(APPROVED, Builder)`, commits with
      subject `Gate A: approve F-B (auto)`, writes the §11 note, pushes `main`, and the
      build step starts with no human command.
- [ ] AC3: Given the same but the row is `manual`, misspelled or empty, then the run stops
      at `(PLAN_REVIEW, Lucas)` and the notification's next command is
      `tools/studio approve F-B`.
- [ ] AC4: Given an `auto` row and an unanswered blocking §10 row, then no approval
      happens and the run stops with a notification pointing at the feature file.
- [ ] AC5: Given any agent step that modifies `studio/QUEUE.md`, then the step is rejected
      and the feature is blocked.
- [ ] AC6: Given a draft step that leaves a template placeholder in §1–§6, or outputs any
      state other than the two allowed by C9, then the step is rejected.
- [ ] AC7: Given F-B reaches `(CODE_REVIEW, Lucas)`, then `queue run` stops and the
      notification's next command is `tools/studio done F-B`, for both gate modes.
- [ ] AC8: Given `tools/studio done F-A` succeeds and the queue has a next row, then the
      same command continues as `queue run` on that row; with `done F-A --stop` it does not.
- [ ] AC9: Given the first not-DONE feature is blocked or waiting on Lucas, then
      `queue run` does nothing to any later row and says which feature holds the queue.
- [ ] AC10: Given a row whose file already exists at `(PLAN_REVIEW, Auditor)`, then no
      draft step runs and the file's §1–§6 are byte-identical afterwards.
- [ ] AC11: Given a row naming a department with no brief, then `queue run` refuses before
      creating a file or a board row.
- [ ] AC12: `tools/studio queue` prints each row with its feature state, gate mode and
      which row is next.
- [ ] AC13: Given no `studio/QUEUE.md`, then the whole existing test suite passes with no
      test edited.

**How to verify manually:** Lucas writes `studio/QUEUE.md` with the next two features, the
second one marked `auto`. After the first one's playtest he runs `tools/studio done` on it
and walks away. The next message on his phone is "F-XXX: code review approved — Next:
tools/studio done F-XXX" for the second feature. He then checks `git log` for the
`Gate A: approve F-XXX (auto)` commit and reads the §11 note.

---

## 6. Task Breakdown  ·  _Planner_

Small, ordered, each independently committable.

| # | Task | Files likely touched | Notes |
|---|---|---|---|
| T1 | Queue file format, parser and `tools/studio queue` listing | `studio/QUEUE.md`, `tools/studio_lib/queue.py`, `tools/studio`, tests | Markdown table: Order, ID, Title, Department, Gate A, Brief. C4, C12, AC12 |
| T2 | Create a feature file from the template for a given ID | `tools/studio_lib/feature.py`, tests | Port of `studio/new-feature.sh`, explicit ID, never overwrites (C13) |
| T3 | Draft step: action for `(DRAFT, Planner)`, prompts, output and placeholder validation | `tools/studio_lib/engine.py`, `feature.py`, `tools/studio_prompts/draft.md`, `studio/prompts/autopilot-draft.md`, tests | C9–C11, AC1, AC6. Runs on `main` like the plan steps |
| T4 | `QUEUE.md` protected from every agent lane | `feature.py`, `engine.py`, tests | C5, AC5 |
| T5 | Tool-performed Gate A for `auto` rows | `engine.py`, tests | Reuses `_gate_a`; C1, C3, C4, C6; AC2–AC4 |
| T6 | `queue run`: first not-DONE row, sequential stop rule, notifications | `engine.py`, `tools/studio`, tests | C7, C8; AC7, AC9–AC11 |
| T7 | `done` continues into the queue; `--stop` | `engine.py`, `tools/studio`, tests | AC8. Continuation starts only after publish succeeds |
| T8 | Docs | `studio/README.md`, `studio/departments/direction.md`, `studio/DECISIONS.md` | Pipeline section; D-009 |

---

## 7. Plan Review  ·  _Auditor_

<Each completed round starts with its machine line (format in AGENTS.md), then its findings.
Severity: 🔴 blocking · 🟡 should fix · 🔵 suggestion. Example finding:>

### PR-1 🔴 <title>
<What's wrong, where, why it matters, what you'd suggest.>
> **Planner reply:** <accepted / rejected + reason / changed §X>

---

## 8. Implementation Log  ·  _Builder_

**Started:** YYYY-MM-DD  ·  **Branch:** `feature/F-010-studio-queue`

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

<Each completed round starts with its machine line (format in AGENTS.md), then
`**Reviewed commit:** <hash>`, AC evidence and findings. Example finding:>

### CR-1 🔴 <title>  ·  `path/to/file:line`
<problem, why it matters, suggested fix>
> **Builder reply:** <fixed in abc123 / disagree because …>

---

## 10. Open Questions  ·  _Anyone (append)_

| # | Raised by | Question | Blocking? | Answer (Lucas/Planner) |
|---|---|---|---|---|
| Q1 | Direction | Which rows start as `auto`? None proposed: every feature left in phase 1 is a new system. | no | Lucas sets this in `studio/QUEUE.md` before first use. |

---

## 11. Director Notes  ·  _Lucas_

<Overrides, priorities, gut calls. Everyone obeys these.>
